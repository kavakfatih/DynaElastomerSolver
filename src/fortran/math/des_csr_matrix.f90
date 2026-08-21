module des_csr_matrix
  use des_kinds, only : dp, i64
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONSTRAINT
  implicit none
  private

  public :: csr_matrix_t
  public :: initialize_csr_from_element_dof_maps
  public :: initialize_csr_from_element_dof_maps_i64
  public :: csr_add_local_matrix
  public :: csr_add_local_matrix_i64
  public :: csr_to_dense
  public :: csr_matvec
  public :: csr_apply_zero_dirichlet
  public :: csr_apply_zero_dirichlet_i64

  type :: csr_matrix_t
    ! 1-based Compressed Sparse Row (CSR) depolama.
    ! Structural dimensions, row pointers ve column indices canonical i64'tir.
    ! Legacy default-integer APIs compatibility wrapper olarak korunur; yeni 2D
    ! FEM/database yolu i64-native constructor/scatter/Dirichlet girişlerini kullanır.
    integer(i64) :: nrows = 0_i64
    integer(i64) :: ncols = 0_i64
    integer(i64), allocatable :: row_ptr(:)
    integer(i64), allocatable :: col_ind(:)
    real(dp), allocatable :: values(:)
  contains
    procedure :: nrows_i64 => csr_nrows_i64
    procedure :: ncols_i64 => csr_ncols_i64
    procedure :: nnz => csr_nnz
    procedure :: nnz_i64 => csr_nnz_i64
    procedure :: zero_values => csr_zero_values
    procedure :: get_value => csr_get_value
  end type csr_matrix_t

contains

  subroutine initialize_csr_from_element_dof_maps( &
      matrix, nrows, ncols, element_dof_maps, status)
    ! Legacy wrapper. Bütün graph aritmetiği canonical i64 implementation'a gider.
    type(csr_matrix_t), intent(out) :: matrix
    integer, intent(in) :: nrows, ncols
    integer, intent(in) :: element_dof_maps(:,:)
    integer, intent(out) :: status
    integer(i64), allocatable :: maps_i64(:,:)

    if (nrows < 1 .or. ncols < 1) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    allocate(maps_i64(size(element_dof_maps,1),size(element_dof_maps,2)))
    maps_i64 = int(element_dof_maps,i64)
    call initialize_csr_from_element_dof_maps_i64( &
        matrix,int(nrows,i64),int(ncols,i64),maps_i64,status)
  end subroutine initialize_csr_from_element_dof_maps

  subroutine initialize_csr_from_element_dof_maps_i64( &
      matrix, nrows, ncols, element_dof_maps, status)
    ! C4 canonical i64 CSR graph constructor.
    ! Element-local equation map'lerinden tekrar etmeyen global CSR graph kurar.
    ! Dense adjacency kullanılmaz; cardinality/pointer/index aritmetiği i64'tir.
    type(csr_matrix_t), intent(out) :: matrix
    integer(i64), intent(in) :: nrows, ncols
    integer(i64), intent(in) :: element_dof_maps(:,:)
    integer, intent(out) :: status

    integer(i64), allocatable :: candidate_counts(:), candidate_ptr(:)
    integer(i64), allocatable :: candidates(:), next_position(:), row_counts(:)
    integer(i64) :: nelem, nlocal, e, lr, lc, row, i
    integer(i64) :: k, first, last, previous, total_candidates, total_nnz

    status = DES_STATUS_OK
    matrix%nrows = 0_i64
    matrix%ncols = 0_i64

    if (nrows < 1_i64 .or. ncols < 1_i64) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if
    if (nrows == huge(0_i64)) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    nelem = size(element_dof_maps,1,kind=i64)
    nlocal = size(element_dof_maps,2,kind=i64)
    if (nelem < 1_i64 .or. nlocal < 1_i64) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    if (any(element_dof_maps < 1_i64) .or. any(element_dof_maps > nrows) .or. &
        any(element_dof_maps > ncols)) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    matrix%nrows = nrows
    matrix%ncols = ncols
    allocate(candidate_counts(nrows),candidate_ptr(nrows+1_i64), &
             next_position(nrows),row_counts(nrows))
    candidate_counts = 0_i64

    ! Her local row, aynı elementin tüm local kolonlarını structural aday yapar.
    do e = 1_i64,nelem
      do lr = 1_i64,nlocal
        row = element_dof_maps(e,lr)
        if (candidate_counts(row) > huge(0_i64)-nlocal) then
          status = DES_ERROR_INVALID_CONSTRAINT
          return
        end if
        candidate_counts(row) = candidate_counts(row)+nlocal
      end do
    end do

    candidate_ptr(1) = 1_i64
    do row = 1_i64,nrows
      if (candidate_ptr(row) > huge(0_i64)-candidate_counts(row)) then
        status = DES_ERROR_INVALID_CONSTRAINT
        return
      end if
      candidate_ptr(row+1_i64) = candidate_ptr(row)+candidate_counts(row)
    end do
    total_candidates = candidate_ptr(nrows+1_i64)-1_i64
    if (total_candidates < 1_i64) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    allocate(candidates(total_candidates))
    candidates = 0_i64
    next_position = candidate_ptr(1:nrows)

    do e = 1_i64,nelem
      do lr = 1_i64,nlocal
        row = element_dof_maps(e,lr)
        do lc = 1_i64,nlocal
          candidates(next_position(row)) = element_dof_maps(e,lc)
          next_position(row) = next_position(row)+1_i64
        end do
      end do
    end do

    ! Aynı global row komşu elementlerden birden çok kez gelebilir. Sort+unique
    ! duplicate structural entry yaratılmasını engeller.
    row_counts = 0_i64
    do row = 1_i64,nrows
      first = candidate_ptr(row)
      last = candidate_ptr(row+1_i64)-1_i64
      call sort_integer_range(candidates,first,last)
      if (last < first) cycle

      previous = 0_i64
      do k = first,last
        if (k == first .or. candidates(k) /= previous) then
          if (row_counts(row) == huge(0_i64)) then
            status = DES_ERROR_INVALID_CONSTRAINT
            return
          end if
          row_counts(row) = row_counts(row)+1_i64
          previous = candidates(k)
        end if
      end do
    end do

    allocate(matrix%row_ptr(nrows+1_i64))
    matrix%row_ptr(1) = 1_i64
    do i = 1_i64,nrows
      if (matrix%row_ptr(i) > huge(0_i64)-row_counts(i)) then
        status = DES_ERROR_INVALID_CONSTRAINT
        return
      end if
      matrix%row_ptr(i+1_i64) = matrix%row_ptr(i)+row_counts(i)
    end do

    total_nnz = matrix%row_ptr(nrows+1_i64)-1_i64
    if (total_nnz < 1_i64) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    allocate(matrix%col_ind(total_nnz),matrix%values(total_nnz))
    matrix%col_ind = 0_i64
    matrix%values = 0.0_dp

    next_position = matrix%row_ptr(1:nrows)
    do row = 1_i64,nrows
      first = candidate_ptr(row)
      last = candidate_ptr(row+1_i64)-1_i64
      if (last < first) cycle

      previous = 0_i64
      do k = first,last
        if (k == first .or. candidates(k) /= previous) then
          matrix%col_ind(next_position(row)) = candidates(k)
          next_position(row) = next_position(row)+1_i64
          previous = candidates(k)
        end if
      end do
    end do

    if (any(matrix%col_ind < 1_i64) .or. &
        any(matrix%col_ind > matrix%ncols)) then
      status = DES_ERROR_INVALID_CONSTRAINT
    end if
  end subroutine initialize_csr_from_element_dof_maps_i64

  subroutine csr_add_local_matrix(matrix, dof_map, local_matrix, status)
    ! Legacy default-integer scatter wrapper.
    class(csr_matrix_t), intent(inout) :: matrix
    integer, intent(in) :: dof_map(:)
    real(dp), intent(in) :: local_matrix(:,:)
    integer, intent(out) :: status
    integer(i64) :: map_i64(size(dof_map))

    map_i64 = int(dof_map,i64)
    call csr_add_local_matrix_i64(matrix,map_i64,local_matrix,status)
  end subroutine csr_add_local_matrix

  subroutine csr_add_local_matrix_i64(matrix, dof_map, local_matrix, status)
    ! C4 canonical i64 local-to-global sparse scatter.
    class(csr_matrix_t), intent(inout) :: matrix
    integer(i64), intent(in) :: dof_map(:)
    real(dp), intent(in) :: local_matrix(:,:)
    integer, intent(out) :: status

    integer :: nlocal, lr, lc
    integer(i64) :: row, col, position

    status = DES_STATUS_OK
    nlocal = size(dof_map)

    if (.not. allocated(matrix%row_ptr) .or. .not. allocated(matrix%col_ind) .or. &
        .not. allocated(matrix%values)) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if
    if (size(local_matrix,1) /= nlocal .or. size(local_matrix,2) /= nlocal) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if
    if (any(dof_map < 1_i64) .or. any(dof_map > matrix%nrows) .or. &
        any(dof_map > matrix%ncols)) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    do lr = 1,nlocal
      row = dof_map(lr)
      do lc = 1,nlocal
        col = dof_map(lc)
        position = find_csr_position_i64(matrix,row,col)
        if (position == 0_i64) then
          status = DES_ERROR_INVALID_CONSTRAINT
          return
        end if
        matrix%values(position) = matrix%values(position)+local_matrix(lr,lc)
      end do
    end do
  end subroutine csr_add_local_matrix_i64

  subroutine csr_to_dense(matrix, dense, status)
    class(csr_matrix_t), intent(in) :: matrix
    real(dp), intent(out) :: dense(:,:)
    integer, intent(out) :: status

    integer(i64) :: row, entry

    status = DES_STATUS_OK
    dense = 0.0_dp

    if (.not. allocated(matrix%row_ptr) .or. .not. allocated(matrix%col_ind) .or. &
        .not. allocated(matrix%values)) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if
    if (size(dense,1,kind=i64) /= matrix%nrows .or. &
        size(dense,2,kind=i64) /= matrix%ncols) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    do row = 1_i64,matrix%nrows
      do entry = matrix%row_ptr(row),matrix%row_ptr(row+1_i64)-1_i64
        dense(row,matrix%col_ind(entry)) = matrix%values(entry)
      end do
    end do
  end subroutine csr_to_dense

  subroutine csr_matvec(matrix, x, y, status)
    class(csr_matrix_t), intent(in) :: matrix
    real(dp), intent(in) :: x(:)
    real(dp), intent(out) :: y(:)
    integer, intent(out) :: status

    integer(i64) :: row, entry

    status = DES_STATUS_OK
    y = 0.0_dp

    if (.not. allocated(matrix%row_ptr) .or. .not. allocated(matrix%col_ind) .or. &
        .not. allocated(matrix%values)) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if
    if (matrix%nrows < 1_i64 .or. matrix%ncols < 1_i64 .or. &
        size(x,kind=i64) /= matrix%ncols .or. size(y,kind=i64) /= matrix%nrows) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    do row = 1_i64,matrix%nrows
      do entry = matrix%row_ptr(row),matrix%row_ptr(row+1_i64)-1_i64
        y(row) = y(row)+matrix%values(entry)*x(matrix%col_ind(entry))
      end do
    end do
  end subroutine csr_matvec

  subroutine csr_apply_zero_dirichlet(matrix, rhs, fixed_dofs, status)
    ! Legacy default-integer wrapper.
    class(csr_matrix_t), intent(inout) :: matrix
    real(dp), intent(inout) :: rhs(:)
    integer, intent(in) :: fixed_dofs(:)
    integer, intent(out) :: status
    integer(i64) :: fixed_i64(size(fixed_dofs))

    fixed_i64 = int(fixed_dofs,i64)
    call csr_apply_zero_dirichlet_i64(matrix,rhs,fixed_i64,status)
  end subroutine csr_apply_zero_dirichlet

  subroutine csr_apply_zero_dirichlet_i64(matrix, rhs, fixed_dofs, status)
    ! C4 i64-native zero Dirichlet elimination. Structural graph değişmez;
    ! fixed row/column values sıfırlanır, diagonal 1 ve RHS 0 yapılır.
    class(csr_matrix_t), intent(inout) :: matrix
    real(dp), intent(inout) :: rhs(:)
    integer(i64), intent(in) :: fixed_dofs(:)
    integer, intent(out) :: status

    logical, allocatable :: is_fixed(:)
    integer :: fixed_index
    integer(i64) :: row, dof, entry, diagonal_position, col

    status = DES_STATUS_OK

    if (.not. allocated(matrix%row_ptr) .or. .not. allocated(matrix%col_ind) .or. &
        .not. allocated(matrix%values)) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if
    if (matrix%nrows /= matrix%ncols .or. size(rhs,kind=i64) /= matrix%nrows) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if
    if (size(fixed_dofs) == 0) return
    if (any(fixed_dofs < 1_i64) .or. any(fixed_dofs > matrix%nrows)) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    allocate(is_fixed(matrix%nrows))
    is_fixed = .false.
    do fixed_index = 1,size(fixed_dofs)
      is_fixed(fixed_dofs(fixed_index)) = .true.
    end do

    do row = 1_i64,matrix%nrows
      do entry = matrix%row_ptr(row),matrix%row_ptr(row+1_i64)-1_i64
        col = matrix%col_ind(entry)
        if (is_fixed(row) .or. is_fixed(col)) matrix%values(entry) = 0.0_dp
      end do
    end do

    do fixed_index = 1,size(fixed_dofs)
      dof = fixed_dofs(fixed_index)
      diagonal_position = find_csr_position_i64(matrix,dof,dof)
      if (diagonal_position == 0_i64) then
        status = DES_ERROR_INVALID_CONSTRAINT
        return
      end if
      matrix%values(diagonal_position) = 1.0_dp
      rhs(dof) = 0.0_dp
    end do
  end subroutine csr_apply_zero_dirichlet_i64

  integer(i64) function csr_nrows_i64(this) result(nrows)
    class(csr_matrix_t), intent(in) :: this
    nrows = this%nrows
  end function csr_nrows_i64

  integer(i64) function csr_ncols_i64(this) result(ncols)
    class(csr_matrix_t), intent(in) :: this
    ncols = this%ncols
  end function csr_ncols_i64

  integer function csr_nnz(this) result(nnz)
    class(csr_matrix_t), intent(in) :: this
    integer(i64) :: nnz64

    if (allocated(this%values)) then
      nnz64 = size(this%values,kind=i64)
      if (nnz64 > int(huge(0),i64)) then
        error stop 'csr_nnz default integer kapasitesi asildi; nnz_i64 kullanin.'
      end if
      nnz = int(nnz64)
    else
      nnz = 0
    end if
  end function csr_nnz

  integer(i64) function csr_nnz_i64(this) result(nnz)
    class(csr_matrix_t), intent(in) :: this
    if (allocated(this%values)) then
      nnz = size(this%values,kind=i64)
    else
      nnz = 0_i64
    end if
  end function csr_nnz_i64

  subroutine csr_zero_values(this)
    class(csr_matrix_t), intent(inout) :: this
    if (allocated(this%values)) this%values = 0.0_dp
  end subroutine csr_zero_values

  real(dp) function csr_get_value(this, row, col) result(value)
    class(csr_matrix_t), intent(in) :: this
    integer, intent(in) :: row, col
    integer(i64) :: position

    value = 0.0_dp
    if (row < 1 .or. int(row,i64) > this%nrows .or. &
        col < 1 .or. int(col,i64) > this%ncols) return
    if (.not. allocated(this%row_ptr) .or. .not. allocated(this%col_ind) .or. &
        .not. allocated(this%values)) return

    position = find_csr_position_i64(this,int(row,i64),int(col,i64))
    if (position > 0_i64) value = this%values(position)
  end function csr_get_value

  integer(i64) function find_csr_position_i64(matrix, row, col) result(position)
    class(csr_matrix_t), intent(in) :: matrix
    integer(i64), intent(in) :: row, col
    integer(i64) :: lo, hi, mid, candidate

    position = 0_i64
    if (row < 1_i64 .or. row > matrix%nrows .or. &
        col < 1_i64 .or. col > matrix%ncols) return

    lo = matrix%row_ptr(row)
    hi = matrix%row_ptr(row+1_i64)-1_i64
    do while (lo <= hi)
      mid = lo+(hi-lo)/2_i64
      candidate = matrix%col_ind(mid)
      if (candidate == col) then
        position = mid
        return
      elseif (candidate < col) then
        lo = mid+1_i64
      else
        hi = mid-1_i64
      end if
    end do
  end function find_csr_position_i64

  subroutine sort_integer_range(values, first, last)
    integer(i64), intent(inout) :: values(:)
    integer(i64), intent(in) :: first, last
    integer(i64) :: i, j, key

    if (last <= first) return

    do i = first+1_i64,last
      key = values(i)
      j = i-1_i64
      do while (j >= first)
        if (values(j) <= key) exit
        values(j+1_i64) = values(j)
        j = j-1_i64
      end do
      values(j+1_i64) = key
    end do
  end subroutine sort_integer_range

end module des_csr_matrix
