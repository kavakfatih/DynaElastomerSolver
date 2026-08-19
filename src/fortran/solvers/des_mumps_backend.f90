module des_mumps_backend
  use, intrinsic :: iso_c_binding, only : c_associated, c_double, c_int, &
                                         c_null_ptr, c_ptr
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONSTRAINT, &
                         DES_ERROR_LINEAR_SOLVE
  use des_csr_matrix, only : csr_matrix_t
  implicit none
  private

  logical, parameter, public :: DES_MUMPS_AVAILABLE = .true.

  type, public :: mumps_backend_handle_t
    type(c_ptr) :: ptr = c_null_ptr
  end type mumps_backend_handle_t

  public :: mumps_backend_create
  public :: mumps_backend_set_pattern
  public :: mumps_backend_analyze
  public :: mumps_backend_factorize
  public :: mumps_backend_solve
  public :: mumps_backend_destroy

  interface
    function des_mumps_c_create(symmetry_mode,info_primary,info_secondary) &
        bind(C,name='des_mumps_c_create') result(handle)
      import :: c_int, c_ptr
      integer(c_int), value :: symmetry_mode
      integer(c_int), intent(out) :: info_primary, info_secondary
      type(c_ptr) :: handle
    end function des_mumps_c_create

    function des_mumps_c_set_pattern( &
        handle,n,nnz,row_ptr,col_ind,info_primary,info_secondary) &
        bind(C,name='des_mumps_c_set_pattern') result(rc)
      import :: c_int, c_ptr
      type(c_ptr), value :: handle
      integer(c_int), value :: n, nnz
      integer(c_int), intent(in) :: row_ptr(*), col_ind(*)
      integer(c_int), intent(out) :: info_primary, info_secondary
      integer(c_int) :: rc
    end function des_mumps_c_set_pattern

    function des_mumps_c_analyze( &
        handle,nnz,values,info_primary,info_secondary) &
        bind(C,name='des_mumps_c_analyze') result(rc)
      import :: c_double, c_int, c_ptr
      type(c_ptr), value :: handle
      integer(c_int), value :: nnz
      real(c_double), intent(in) :: values(*)
      integer(c_int), intent(out) :: info_primary, info_secondary
      integer(c_int) :: rc
    end function des_mumps_c_analyze

    function des_mumps_c_factorize( &
        handle,nnz,values,info_primary,info_secondary) &
        bind(C,name='des_mumps_c_factorize') result(rc)
      import :: c_double, c_int, c_ptr
      type(c_ptr), value :: handle
      integer(c_int), value :: nnz
      real(c_double), intent(in) :: values(*)
      integer(c_int), intent(out) :: info_primary, info_secondary
      integer(c_int) :: rc
    end function des_mumps_c_factorize

    function des_mumps_c_solve( &
        handle,n,rhs,x,info_primary,info_secondary) &
        bind(C,name='des_mumps_c_solve') result(rc)
      import :: c_double, c_int, c_ptr
      type(c_ptr), value :: handle
      integer(c_int), value :: n
      real(c_double), intent(in) :: rhs(*)
      real(c_double), intent(out) :: x(*)
      integer(c_int), intent(out) :: info_primary, info_secondary
      integer(c_int) :: rc
    end function des_mumps_c_solve

    subroutine des_mumps_c_destroy(handle) bind(C,name='des_mumps_c_destroy')
      import :: c_ptr
      type(c_ptr), value :: handle
    end subroutine des_mumps_c_destroy
  end interface

contains

  subroutine mumps_backend_create(handle,symmetry_mode,status,info_primary,info_secondary)
    type(mumps_backend_handle_t), intent(out) :: handle
    integer, intent(in) :: symmetry_mode
    integer, intent(out) :: status, info_primary, info_secondary

    integer(c_int) :: c_info_primary, c_info_secondary

    status = DES_STATUS_OK
    info_primary = 0
    info_secondary = 0

    if (symmetry_mode < 0 .or. symmetry_mode > 2) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    handle%ptr = des_mumps_c_create( &
        int(symmetry_mode,c_int),c_info_primary,c_info_secondary)
    info_primary = int(c_info_primary)
    info_secondary = int(c_info_secondary)

    if (.not. c_associated(handle%ptr)) then
      status = DES_ERROR_LINEAR_SOLVE
    end if
  end subroutine mumps_backend_create

  subroutine mumps_backend_set_pattern(handle,matrix,status,info_primary,info_secondary)
    type(mumps_backend_handle_t), intent(inout) :: handle
    type(csr_matrix_t), intent(in) :: matrix
    integer, intent(out) :: status, info_primary, info_secondary

    integer(c_int), allocatable :: row_ptr(:), col_ind(:)
    integer(c_int) :: rc, c_info_primary, c_info_secondary

    status = DES_STATUS_OK
    info_primary = 0
    info_secondary = 0

    if (.not. c_associated(handle%ptr) .or. &
        .not. allocated(matrix%row_ptr) .or. &
        .not. allocated(matrix%col_ind)) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    allocate(row_ptr(size(matrix%row_ptr)),col_ind(size(matrix%col_ind)))
    row_ptr = int(matrix%row_ptr,c_int)
    col_ind = int(matrix%col_ind,c_int)

    rc = des_mumps_c_set_pattern( &
        handle%ptr,int(matrix%nrows,c_int),int(size(matrix%col_ind),c_int), &
        row_ptr,col_ind,c_info_primary,c_info_secondary)
    info_primary = int(c_info_primary)
    info_secondary = int(c_info_secondary)

    if (rc /= 0_c_int) status = DES_ERROR_LINEAR_SOLVE
  end subroutine mumps_backend_set_pattern

  subroutine mumps_backend_analyze(handle,matrix,status,info_primary,info_secondary)
    type(mumps_backend_handle_t), intent(inout) :: handle
    type(csr_matrix_t), intent(in) :: matrix
    integer, intent(out) :: status, info_primary, info_secondary

    real(c_double), allocatable :: values(:)
    integer(c_int) :: rc, c_info_primary, c_info_secondary

    call validate_numeric_input(handle,matrix,status)
    info_primary = 0
    info_secondary = 0
    if (status /= DES_STATUS_OK) return

    allocate(values(size(matrix%values)))
    values = real(matrix%values,c_double)

    rc = des_mumps_c_analyze( &
        handle%ptr,int(size(values),c_int),values, &
        c_info_primary,c_info_secondary)
    info_primary = int(c_info_primary)
    info_secondary = int(c_info_secondary)
    if (rc /= 0_c_int) status = DES_ERROR_LINEAR_SOLVE
  end subroutine mumps_backend_analyze

  subroutine mumps_backend_factorize(handle,matrix,status,info_primary,info_secondary)
    type(mumps_backend_handle_t), intent(inout) :: handle
    type(csr_matrix_t), intent(in) :: matrix
    integer, intent(out) :: status, info_primary, info_secondary

    real(c_double), allocatable :: values(:)
    integer(c_int) :: rc, c_info_primary, c_info_secondary

    call validate_numeric_input(handle,matrix,status)
    info_primary = 0
    info_secondary = 0
    if (status /= DES_STATUS_OK) return

    allocate(values(size(matrix%values)))
    values = real(matrix%values,c_double)

    rc = des_mumps_c_factorize( &
        handle%ptr,int(size(values),c_int),values, &
        c_info_primary,c_info_secondary)
    info_primary = int(c_info_primary)
    info_secondary = int(c_info_secondary)
    if (rc /= 0_c_int) status = DES_ERROR_LINEAR_SOLVE
  end subroutine mumps_backend_factorize

  subroutine mumps_backend_solve( &
      handle,b,x,status,info_primary,info_secondary)
    type(mumps_backend_handle_t), intent(inout) :: handle
    real(dp), intent(in) :: b(:)
    real(dp), intent(out) :: x(:)
    integer, intent(out) :: status, info_primary, info_secondary

    real(c_double), allocatable :: rhs(:), solution(:)
    integer(c_int) :: rc, c_info_primary, c_info_secondary

    status = DES_STATUS_OK
    info_primary = 0
    info_secondary = 0
    x = 0.0_dp

    if (.not. c_associated(handle%ptr) .or. size(b) < 1 .or. &
        size(x) /= size(b)) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    allocate(rhs(size(b)),solution(size(b)))
    rhs = real(b,c_double)
    solution = 0.0_c_double

    rc = des_mumps_c_solve( &
        handle%ptr,int(size(b),c_int),rhs,solution, &
        c_info_primary,c_info_secondary)
    info_primary = int(c_info_primary)
    info_secondary = int(c_info_secondary)

    if (rc /= 0_c_int) then
      status = DES_ERROR_LINEAR_SOLVE
      return
    end if

    x = real(solution,dp)
  end subroutine mumps_backend_solve

  subroutine mumps_backend_destroy(handle)
    type(mumps_backend_handle_t), intent(inout) :: handle

    if (c_associated(handle%ptr)) call des_mumps_c_destroy(handle%ptr)
    handle%ptr = c_null_ptr
  end subroutine mumps_backend_destroy

  subroutine validate_numeric_input(handle,matrix,status)
    type(mumps_backend_handle_t), intent(in) :: handle
    type(csr_matrix_t), intent(in) :: matrix
    integer, intent(out) :: status

    status = DES_STATUS_OK
    if (.not. c_associated(handle%ptr) .or. &
        .not. allocated(matrix%values) .or. size(matrix%values) < 1) then
      status = DES_ERROR_INVALID_CONSTRAINT
    end if
  end subroutine validate_numeric_input

end module des_mumps_backend
