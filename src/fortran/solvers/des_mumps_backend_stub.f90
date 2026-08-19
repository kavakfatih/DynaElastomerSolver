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

  public :: mumps_backend_create
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
