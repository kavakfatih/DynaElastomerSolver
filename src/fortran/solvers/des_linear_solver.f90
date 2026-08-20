module des_linear_solver
  use des_kinds, only : dp, i32
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONSTRAINT, &
                         DES_ERROR_LINEAR_SOLVE, DES_ERROR_UNSUPPORTED_LINEAR_BACKEND
  use des_csr_matrix, only : csr_matrix_t, csr_matvec
  use stdlib_linalg, only : solve
  use stdlib_linalg_state, only : linalg_state_type
  use stdlib_sparse, only : CSR_dp_type
  use stdlib_linalg_iterative_solvers, only : stdlib_solve_gmres, pc_none
  implicit none
  private

  integer, parameter, public :: DES_LINEAR_BACKEND_AUTO = 0
  integer, parameter, public :: DES_LINEAR_BACKEND_STDLIB_DENSE = 1
  integer, parameter, public :: DES_LINEAR_BACKEND_STDLIB_CSR_GMRES = 2
  integer, parameter, public :: DES_LINEAR_BACKEND_MUMPS_DIRECT = 3

  integer, parameter, public :: DES_LINEAR_FALLBACK_NONE = 0
  integer, parameter, public :: DES_LINEAR_FALLBACK_MUMPS_UNAVAILABLE = 1

  public :: linear_solver_settings_t, linear_solver_report_t
  public :: solve_linear_system, solve_sparse_linear_system, linear_backend_name
  public :: linear_backend_is_sparse, linear_fallback_reason_name

  type :: linear_solver_settings_t
    ! Dense LAPACK küçük doğrulama problemleri için reference/fallback olarak kalır.
    ! CSR GMRES yolu sparse mimariyi doğrulayan portable bootstrap backend'dir.
    ! MUMPS direct backend yalnız stateful sparse context arkasından çağrılır.
    ! AUTO explicit seçilirse karar SparseSolverContext içinde verilir; varsayılan
    ! dense davranış B7'de geriye uyumluluk için bilinçli olarak değiştirilmez.
    integer :: backend = DES_LINEAR_BACKEND_STDLIB_DENSE
    real(dp) :: relative_tolerance = 1.0e-10_dp
    real(dp) :: absolute_tolerance = 1.0e-12_dp
    integer :: max_iterations = 200
    integer :: krylov_dimension = 50
    logical :: compact_krylov = .true.
  end type linear_solver_settings_t

  type :: linear_solver_report_t
    integer :: status = DES_STATUS_OK
    integer :: requested_backend = DES_LINEAR_BACKEND_STDLIB_DENSE
    integer :: backend = DES_LINEAR_BACKEND_STDLIB_DENSE
    logical :: fallback_used = .false.
    integer :: fallback_reason = DES_LINEAR_FALLBACK_NONE
    integer :: equation_count = 0
    real(dp) :: residual_inf_norm = huge(1.0_dp)
    logical :: converged = .false.

    ! Stateful sparse context sayaçları additive metadata'dır. Stateless
    ! dense/sparse çağrılarda sıfır kalır.
    integer :: pattern_analysis_count = 0
    integer :: reorder_count = 0
    integer :: factorization_count = 0
    integer :: context_solve_count = 0
    integer :: iterative_refinement_count = 0
    integer :: symbolic_reuse_count = 0
    logical :: direct_factorization_performed = .false.

    ! Vendor ham durum kodları generic raporda ayrı tutulur. Dyna status kodu
    ! kullanıcı-facing kontrol akışını yönetir; bu iki alan backend teşhisidir.
    integer :: backend_info_primary = 0
    integer :: backend_info_secondary = 0
  end type linear_solver_report_t

contains

  subroutine solve_linear_system(A, b, x, settings, report)
    real(dp), intent(in) :: A(:,:), b(:)
    real(dp), intent(out) :: x(:)
    type(linear_solver_settings_t), intent(in), optional :: settings
    type(linear_solver_report_t), intent(out) :: report

    type(linear_solver_settings_t) :: active_settings

    active_settings = linear_solver_settings_t()
    if (present(settings)) active_settings = settings

    report = linear_solver_report_t()
    report%requested_backend = active_settings%backend
    report%backend = active_settings%backend
    report%equation_count = size(b)
    x = 0.0_dp

    if (size(A,1) /= size(b) .or. size(A,2) /= size(b) .or. &
        size(x) /= size(b) .or. size(b) < 1) then
      report%status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    select case (active_settings%backend)
    case (DES_LINEAR_BACKEND_STDLIB_DENSE)
      call solve_stdlib_dense(A, b, x, report)
    case default
      report%status = DES_ERROR_UNSUPPORTED_LINEAR_BACKEND
    end select
  end subroutine solve_linear_system

  subroutine solve_sparse_linear_system(A, b, x, settings, report)
    ! Stateless sparse sözleşme bugün yalnız portable GMRES bootstrap yoludur.
    ! Production MUMPS lifecycle'ı pattern/symbolic reuse gerektirdiği için
    ! des_sparse_solver_context üzerinden çağrılır.
    type(csr_matrix_t), intent(in) :: A
    real(dp), intent(in) :: b(:)
    real(dp), intent(out) :: x(:)
    type(linear_solver_settings_t), intent(in), optional :: settings
    type(linear_solver_report_t), intent(out) :: report

    type(linear_solver_settings_t) :: active_settings

    active_settings = linear_solver_settings_t()
    if (present(settings)) active_settings = settings

    report = linear_solver_report_t()
    report%requested_backend = active_settings%backend
    report%backend = active_settings%backend
    report%equation_count = size(b)
    x = 0.0_dp

    if (A%nrows /= A%ncols .or. A%nrows /= size(b) .or. &
        size(x) /= size(b) .or. size(b) < 1 .or. &
        .not. allocated(A%row_ptr) .or. .not. allocated(A%col_ind) .or. &
        .not. allocated(A%values)) then
      report%status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    if (active_settings%relative_tolerance <= 0.0_dp .or. &
        active_settings%absolute_tolerance <= 0.0_dp .or. &
        active_settings%max_iterations < 1 .or. &
        active_settings%krylov_dimension < 1) then
      report%status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    select case (active_settings%backend)
    case (DES_LINEAR_BACKEND_STDLIB_CSR_GMRES)
      call solve_stdlib_csr_gmres(A,b,x,active_settings,report)
    case default
      report%status = DES_ERROR_UNSUPPORTED_LINEAR_BACKEND
    end select
  end subroutine solve_sparse_linear_system

  subroutine solve_stdlib_dense(A, b, x, report)
    real(dp), intent(in) :: A(:,:), b(:)
    real(dp), intent(out) :: x(:)
    type(linear_solver_report_t), intent(inout) :: report

    real(dp), allocatable, target :: Awork(:,:)
    real(dp), allocatable :: solution(:)
    type(linalg_state_type) :: state

    allocate(Awork(size(A,1), size(A,2)))
    Awork = A

    solution = solve(Awork, b, overwrite_a=.true., err=state)

    if (.not. state%ok()) then
      report%status = DES_ERROR_LINEAR_SOLVE
      return
    end if
    if (size(solution) /= size(b)) then
      report%status = DES_ERROR_LINEAR_SOLVE
      return
    end if

    x = solution
    report%residual_inf_norm = maxval(abs(matmul(A, x) - b))
    report%status = DES_STATUS_OK
    report%converged = .true.
  end subroutine solve_stdlib_dense

  subroutine solve_stdlib_csr_gmres(A, b, x, settings, report)
    type(csr_matrix_t), intent(in) :: A
    real(dp), intent(in) :: b(:)
    real(dp), intent(out) :: x(:)
    type(linear_solver_settings_t), intent(in) :: settings
    type(linear_solver_report_t), intent(inout) :: report

    type(CSR_dp_type) :: A_stdlib
    real(dp), allocatable :: Ax(:)
    real(dp) :: residual_limit, rhs_scale
    integer :: matvec_status, kdim

    call A_stdlib%malloc( &
        int(A%nrows,i32),int(A%ncols,i32),int(A%nnz(),i32))
    A_stdlib%rowptr = int(A%row_ptr,i32)
    A_stdlib%col = int(A%col_ind,i32)
    A_stdlib%data = A%values

    x = 0.0_dp
    kdim = min(settings%krylov_dimension,size(b))

    ! Herrmann fully-incompressible limitinde pressure diagonal blokları sıfır
    ! olabilir. Bootstrap aşamasında Jacobi preconditioner bu yüzden seçilmez.
    call stdlib_solve_gmres( &
        A_stdlib,b,x, &
        rtol=settings%relative_tolerance, &
        atol=settings%absolute_tolerance, &
        maxiter=settings%max_iterations, &
        restart=.true., &
        kdim=kdim, &
        precond=pc_none, &
        compact=settings%compact_krylov)

    allocate(Ax(size(b)))
    call csr_matvec(A,x,Ax,matvec_status)
    if (matvec_status /= DES_STATUS_OK) then
      report%status = matvec_status
      return
    end if

    report%residual_inf_norm = maxval(abs(Ax-b))
    rhs_scale = max(1.0_dp,maxval(abs(b)))
    residual_limit = max( &
        settings%absolute_tolerance,settings%relative_tolerance*rhs_scale)

    if (report%residual_inf_norm <= residual_limit) then
      report%status = DES_STATUS_OK
      report%converged = .true.
    else
      report%status = DES_ERROR_LINEAR_SOLVE
      report%converged = .false.
    end if
  end subroutine solve_stdlib_csr_gmres

  pure logical function linear_backend_is_sparse(backend)
    integer, intent(in) :: backend

    linear_backend_is_sparse = &
        backend == DES_LINEAR_BACKEND_AUTO .or. &
        backend == DES_LINEAR_BACKEND_STDLIB_CSR_GMRES .or. &
        backend == DES_LINEAR_BACKEND_MUMPS_DIRECT
  end function linear_backend_is_sparse

  pure function linear_backend_name(backend) result(name)
    integer, intent(in) :: backend
    character(len=48) :: name

    select case (backend)
    case (DES_LINEAR_BACKEND_AUTO)
      name = 'AUTO sparse policy'
    case (DES_LINEAR_BACKEND_STDLIB_DENSE)
      name = 'stdlib/LAPACK dense'
    case (DES_LINEAR_BACKEND_STDLIB_CSR_GMRES)
      name = 'stdlib CSR GMRES (bootstrap)'
    case (DES_LINEAR_BACKEND_MUMPS_DIRECT)
      name = 'MUMPS sparse direct'
    case default
      name = 'desteklenmeyen lineer solver backend'
    end select
  end function linear_backend_name

  pure function linear_fallback_reason_name(reason) result(name)
    integer, intent(in) :: reason
    character(len=64) :: name

    select case (reason)
    case (DES_LINEAR_FALLBACK_NONE)
      name = 'fallback yok'
    case (DES_LINEAR_FALLBACK_MUMPS_UNAVAILABLE)
      name = 'MUMPS kullanilabilir degil; portable GMRES secildi'
    case default
      name = 'bilinmeyen fallback nedeni'
    end select
  end function linear_fallback_reason_name

end module des_linear_solver
