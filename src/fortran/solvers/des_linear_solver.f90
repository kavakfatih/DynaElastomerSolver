module des_linear_solver
  use des_kinds, only : dp, i32, i64
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

  integer, parameter, public :: DES_DIRECT_ORDERING_AUTO = 0
  integer, parameter, public :: DES_DIRECT_ORDERING_AMD = 1
  integer, parameter, public :: DES_DIRECT_ORDERING_AMF = 2
  integer, parameter, public :: DES_DIRECT_ORDERING_QAMD = 3

  public :: linear_solver_settings_t, linear_solver_report_t
  public :: solve_linear_system, solve_sparse_linear_system, linear_backend_name
  public :: linear_backend_is_sparse, linear_fallback_reason_name
  public :: production_linear_solver_settings
  public :: stdlib_csr_index_range_supported

  type :: linear_solver_settings_t
    ! Dense LAPACK küçük doğrulama problemleri için reference/fallback olarak kalır.
    ! CSR GMRES yolu sparse mimariyi doğrulayan portable bootstrap backend'dir.
    ! MUMPS direct backend yalnız stateful sparse context arkasından çağrılır.
    ! Generic type default dense kalır; ürün kodu production_linear_solver_settings()
    ! ile AUTO => available MUMPS Direct politikasını açıkça ister.
    integer :: backend = DES_LINEAR_BACKEND_STDLIB_DENSE
    real(dp) :: relative_tolerance = 1.0e-10_dp
    real(dp) :: absolute_tolerance = 1.0e-12_dp
    integer :: max_iterations = 200
    integer :: krylov_dimension = 50
    logical :: compact_krylov = .true.

    ! Production sparse-direct kontrolleri vendor-bağımsız solver sözleşmesidir.
    ! GMRES/dense bu alanları görmezden gelir; MUMPS adapter bunları kendi
    ! ICNTL/CNTL parametrelerine çevirir.
    integer :: direct_ordering = DES_DIRECT_ORDERING_AUTO
    real(dp) :: direct_pivot_threshold = -1.0_dp
    integer :: direct_iterative_refinement_steps = 2
    real(dp) :: direct_refinement_tolerance = -1.0_dp
    integer :: direct_error_analysis = 2
    logical :: direct_out_of_core = .false.
    logical :: direct_null_pivot_detection = .true.
    real(dp) :: direct_null_pivot_tolerance = 0.0_dp
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

    ! B9.3 phase-level timing yalnız performans telemetrisidir. CPU süreleri
    ! correctness kararına girmez ve desteklenmeyen fazlar sıfır kalır.
    real(dp) :: pattern_analysis_cpu_seconds = 0.0_dp
    real(dp) :: reorder_cpu_seconds = 0.0_dp
    real(dp) :: backend_analysis_cpu_seconds = 0.0_dp
    real(dp) :: factorization_cpu_seconds = 0.0_dp
    real(dp) :: solve_cpu_seconds = 0.0_dp

    ! Vendor ham durum kodları generic raporda ayrı tutulur. Dyna status kodu
    ! kullanıcı-facing kontrol akışını yönetir; bu iki alan backend teşhisidir.
    integer :: backend_info_primary = 0
    integer :: backend_info_secondary = 0

    ! First-class sparse-direct telemetry. MUMPS INFOG/RINFOG verileri generic
    ! rapora taşınır; diğer backend'lerde nötr değerlerde kalır.
    integer :: direct_ordering_used = -1
    integer :: direct_negative_pivot_count = 0
    integer :: direct_delayed_pivot_count = 0
    integer :: direct_null_pivot_count = 0
    integer :: direct_internal_refinement_steps = 0
    logical :: direct_out_of_core = .false.
    real(dp) :: direct_scaled_residual = huge(1.0_dp)
    real(dp) :: direct_backward_error_1 = huge(1.0_dp)
    real(dp) :: direct_backward_error_2 = huge(1.0_dp)
  end type linear_solver_report_t

contains

  pure function production_linear_solver_settings() result(settings)
    ! Ürün çözümleri için canonical profil. Generic type default'unun dense
    ! kalması legacy/reference API uyumluluğu içindir.
    type(linear_solver_settings_t) :: settings

    settings = linear_solver_settings_t()
    settings%backend = DES_LINEAR_BACKEND_AUTO
    settings%direct_ordering = DES_DIRECT_ORDERING_AUTO
    settings%direct_pivot_threshold = -1.0_dp
    settings%direct_iterative_refinement_steps = 2
    settings%direct_refinement_tolerance = -1.0_dp
    settings%direct_error_analysis = 2
    settings%direct_out_of_core = .false.
    settings%direct_null_pivot_detection = .true.
    settings%direct_null_pivot_tolerance = 0.0_dp
  end function production_linear_solver_settings

  subroutine solve_linear_system(A, b, x, settings, report)
    real(dp), intent(in) :: A(:,:), b(:)
    real(dp), intent(out) :: x(:)
    type(linear_solver_settings_t), intent(in), optional :: settings
    type(linear_solver_report_t), intent(out) :: report

    type(linear_solver_settings_t) :: active_settings
    real(dp) :: solve_cpu_start, solve_cpu_end

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
      call cpu_time(solve_cpu_start)
      call solve_stdlib_dense(A, b, x, report)
      call cpu_time(solve_cpu_end)
      report%solve_cpu_seconds = max(0.0_dp,solve_cpu_end-solve_cpu_start)
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
    real(dp) :: solve_cpu_start, solve_cpu_end

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
      call cpu_time(solve_cpu_start)
      call solve_stdlib_csr_gmres(A,b,x,active_settings,report)
      call cpu_time(solve_cpu_end)
      report%solve_cpu_seconds = max(0.0_dp,solve_cpu_end-solve_cpu_start)
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
    real(dp), allocatable :: Ax(:), b_scaled(:)
    real(dp) :: residual_limit, rhs_scale, row_max, inverse_row_scale
    integer :: matvec_status, kdim, row, first_entry, last_entry

    if (.not. stdlib_csr_index_range_supported( &
        int(A%nrows,i64),A%nnz_i64()) .or. &
        .not. csr_pattern_values_fit_i32(A)) then
      ! stdlib_sparse CSR bugün i32 rowptr/column depolaması kullanır. Büyük
      ! problemde sessiz int(...,i32) narrowing yerine capability failure ver.
      report%status = DES_ERROR_UNSUPPORTED_LINEAR_BACKEND
      return
    end if

    call A_stdlib%malloc( &
        int(A%nrows,i32),int(A%ncols,i32),int(A%nnz_i64(),i32))
    A_stdlib%rowptr = int(A%row_ptr,i32)
    A_stdlib%col = int(A%col_ind,i32)

    ! Mixed u-P saddle-point sisteminde pressure diagonal'i cp=0 limitinde
    ! sıfır olabilir. Bu nedenle diagonal/Jacobi yerine her denklemi kendi
    ! satırındaki en büyük katsayı ile ölçekleyen güvenli bir sol-dengeleme
    ! uygulanır. D*A*x = D*b sistemi exact arithmetic'te aynı x çözümünü verir.
    ! Boş veya sayısal olarak sıfır satırlar 1.0 katsayısı ile değiştirilmeden
    ! bırakılır; final kabul her zaman orijinal A*x-b residual'i ile yapılır.
    allocate(b_scaled(size(b)))
    do row = 1,A%nrows
      first_entry = A%row_ptr(row)
      last_entry = A%row_ptr(row+1)-1
      row_max = 0.0_dp
      if (last_entry >= first_entry) then
        row_max = maxval(abs(A%values(first_entry:last_entry)))
      end if

      inverse_row_scale = 1.0_dp
      if (row_max > tiny(1.0_dp)) inverse_row_scale = 1.0_dp/row_max

      if (last_entry >= first_entry) then
        A_stdlib%data(first_entry:last_entry) = &
            A%values(first_entry:last_entry)*inverse_row_scale
      end if
      b_scaled(row) = b(row)*inverse_row_scale
    end do

    x = 0.0_dp
    kdim = min(settings%krylov_dimension,size(b))

    call stdlib_solve_gmres( &
        A_stdlib,b_scaled,x, &
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

  pure logical function stdlib_csr_index_range_supported(n,nnz) result(supported)
    ! stdlib CSR köprüsü Dyna'nın i64 cardinality bilgisini bugün i32'ye
    ! dönüştürür. 1-based CSR rowptr son girdisi nnz+1 olduğu için nnz değeri
    ! i32 maximumundan bir küçük veya daha az olmalıdır.
    integer(i64), intent(in) :: n, nnz
    integer(i64) :: i32_max

    i32_max = int(huge(0_i32),i64)
    supported = n >= 1_i64 .and. nnz >= 1_i64 .and. &
                n <= i32_max .and. nnz < i32_max
  end function stdlib_csr_index_range_supported

  logical function csr_pattern_values_fit_i32(A) result(fits)
    type(csr_matrix_t), intent(in) :: A
    integer(i64) :: i32_max

    fits = .false.
    if (.not. allocated(A%row_ptr) .or. .not. allocated(A%col_ind)) return
    if (size(A%row_ptr) < 2 .or. size(A%col_ind) < 1) return

    i32_max = int(huge(0_i32),i64)
    if (minval(A%row_ptr) < 1 .or. minval(A%col_ind) < 1) return
    if (int(maxval(A%row_ptr),i64) > i32_max) return
    if (int(maxval(A%col_ind),i64) > i32_max) return
    fits = .true.
  end function csr_pattern_values_fit_i32

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
