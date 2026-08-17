module des_linear_solver
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONSTRAINT, &
                         DES_ERROR_LINEAR_SOLVE, DES_ERROR_UNSUPPORTED_LINEAR_BACKEND
  use stdlib_linalg, only : solve
  use stdlib_linalg_state, only : linalg_state_type
  implicit none
  private

  integer, parameter, public :: DES_LINEAR_BACKEND_STDLIB_DENSE = 1

  public :: linear_solver_settings_t, linear_solver_report_t
  public :: solve_linear_system, linear_backend_name

  type :: linear_solver_settings_t
    ! V0.2'de tek production-aday backend stdlib/LAPACK dense yoludur.
    ! Aynı sözleşme ileride MUMPS ve iterative backend'ler için genişletilecektir.
    integer :: backend = DES_LINEAR_BACKEND_STDLIB_DENSE
  end type linear_solver_settings_t

  type :: linear_solver_report_t
    integer :: status = DES_STATUS_OK
    integer :: backend = DES_LINEAR_BACKEND_STDLIB_DENSE
    integer :: equation_count = 0
    real(dp) :: residual_inf_norm = huge(1.0_dp)
    logical :: converged = .false.
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

  subroutine solve_stdlib_dense(A, b, x, report)
    real(dp), intent(in) :: A(:,:), b(:)
    real(dp), intent(out) :: x(:)
    type(linear_solver_report_t), intent(inout) :: report

    real(dp), allocatable, target :: Awork(:,:)
    real(dp), allocatable :: solution(:)
    type(linalg_state_type) :: state

    allocate(Awork(size(A,1), size(A,2)))
    Awork = A

    ! Dyna'nın lineer solver sınırının ilk backend'i stdlib_linalg::solve'dur.
    ! stdlib bu dense sistemi LAPACK *GESV ailesi üzerinden çözer.
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

  pure function linear_backend_name(backend) result(name)
    integer, intent(in) :: backend
    character(len=48) :: name

    select case (backend)
    case (DES_LINEAR_BACKEND_STDLIB_DENSE)
      name = 'stdlib/LAPACK dense'
    case default
      name = 'desteklenmeyen lineer solver backend'
    end select
  end function linear_backend_name

end module des_linear_solver
