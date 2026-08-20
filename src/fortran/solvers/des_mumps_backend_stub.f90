module des_mumps_backend
  use des_kinds, only : dp
  use des_status, only : DES_ERROR_UNSUPPORTED_LINEAR_BACKEND
  use des_csr_matrix, only : csr_matrix_t
  implicit none
  private

  logical, parameter, public :: DES_MUMPS_AVAILABLE = .false.

  type, public :: mumps_backend_handle_t
    integer :: placeholder = 0
  end type mumps_backend_handle_t

  type, public :: mumps_backend_diagnostics_t
    integer :: ordering_used = -1
    integer :: negative_pivot_count = 0
    integer :: delayed_pivot_count = 0
    integer :: null_pivot_count = 0
    integer :: internal_refinement_steps = 0
    logical :: out_of_core = .false.
    real(dp) :: scaled_residual = huge(1.0_dp)
    real(dp) :: backward_error_1 = huge(1.0_dp)
    real(dp) :: backward_error_2 = huge(1.0_dp)
  end type mumps_backend_diagnostics_t

  public :: mumps_backend_create
  public :: mumps_backend_configure
  public :: mumps_backend_get_diagnostics
  public :: mumps_backend_set_pattern
  public :: mumps_backend_analyze
  public :: mumps_backend_factorize
  public :: mumps_backend_solve
  public :: mumps_backend_destroy

contains

  subroutine mumps_backend_create(handle,symmetry_mode,status,info_primary,info_secondary)
    type(mumps_backend_handle_t), intent(out) :: handle
    integer, intent(in) :: symmetry_mode
    integer, intent(out) :: status, info_primary, info_secondary

    handle%placeholder = symmetry_mode
    info_primary = 0
    info_secondary = 0
    status = DES_ERROR_UNSUPPORTED_LINEAR_BACKEND
  end subroutine mumps_backend_create

  subroutine mumps_backend_configure( &
      handle,ordering,pivot_threshold,refinement_steps,refinement_tolerance, &
      error_analysis,out_of_core,null_pivot_detection,null_pivot_tolerance, &
      status,info_primary,info_secondary)
    type(mumps_backend_handle_t), intent(inout) :: handle
    integer, intent(in) :: ordering, refinement_steps, error_analysis
    real(dp), intent(in) :: pivot_threshold, refinement_tolerance
    logical, intent(in) :: out_of_core, null_pivot_detection
    real(dp), intent(in) :: null_pivot_tolerance
    integer, intent(out) :: status, info_primary, info_secondary

    handle%placeholder = handle%placeholder + ordering + 0*refinement_steps + &
        0*error_analysis + 0*int(pivot_threshold+refinement_tolerance+ &
        null_pivot_tolerance) + 0*merge(1,0,out_of_core) + &
        0*merge(1,0,null_pivot_detection)
    info_primary = 0
    info_secondary = 0
    status = DES_ERROR_UNSUPPORTED_LINEAR_BACKEND
  end subroutine mumps_backend_configure

  subroutine mumps_backend_get_diagnostics(handle,diagnostics,status)
    type(mumps_backend_handle_t), intent(in) :: handle
    type(mumps_backend_diagnostics_t), intent(out) :: diagnostics
    integer, intent(out) :: status

    diagnostics = mumps_backend_diagnostics_t()
    diagnostics%ordering_used = handle%placeholder-handle%placeholder-1
    status = DES_ERROR_UNSUPPORTED_LINEAR_BACKEND
  end subroutine mumps_backend_get_diagnostics

  subroutine mumps_backend_set_pattern(handle,matrix,status,info_primary,info_secondary)
    type(mumps_backend_handle_t), intent(inout) :: handle
    type(csr_matrix_t), intent(in) :: matrix
    integer, intent(out) :: status, info_primary, info_secondary

    handle%placeholder = handle%placeholder + 0*matrix%nrows
    info_primary = 0
    info_secondary = 0
    status = DES_ERROR_UNSUPPORTED_LINEAR_BACKEND
  end subroutine mumps_backend_set_pattern

  subroutine mumps_backend_analyze(handle,matrix,status,info_primary,info_secondary)
    type(mumps_backend_handle_t), intent(inout) :: handle
    type(csr_matrix_t), intent(in) :: matrix
    integer, intent(out) :: status, info_primary, info_secondary

    handle%placeholder = handle%placeholder + 0*matrix%nrows
    info_primary = 0
    info_secondary = 0
    status = DES_ERROR_UNSUPPORTED_LINEAR_BACKEND
  end subroutine mumps_backend_analyze

  subroutine mumps_backend_factorize(handle,matrix,status,info_primary,info_secondary)
    type(mumps_backend_handle_t), intent(inout) :: handle
    type(csr_matrix_t), intent(in) :: matrix
    integer, intent(out) :: status, info_primary, info_secondary

    handle%placeholder = handle%placeholder + 0*matrix%nrows
    info_primary = 0
    info_secondary = 0
    status = DES_ERROR_UNSUPPORTED_LINEAR_BACKEND
  end subroutine mumps_backend_factorize

  subroutine mumps_backend_solve( &
      handle,b,x,status,info_primary,info_secondary)
    type(mumps_backend_handle_t), intent(inout) :: handle
    real(dp), intent(in) :: b(:)
    real(dp), intent(out) :: x(:)
    integer, intent(out) :: status, info_primary, info_secondary

    handle%placeholder = handle%placeholder + 0*size(b)
    x = 0.0_dp
    info_primary = 0
    info_secondary = 0
    status = DES_ERROR_UNSUPPORTED_LINEAR_BACKEND
  end subroutine mumps_backend_solve

  subroutine mumps_backend_destroy(handle)
    type(mumps_backend_handle_t), intent(inout) :: handle

    handle%placeholder = 0
  end subroutine mumps_backend_destroy

end module des_mumps_backend
