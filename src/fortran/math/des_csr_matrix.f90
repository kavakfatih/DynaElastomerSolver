module des_csr_matrix
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONSTRAINT
  implicit none
  private

  public :: csr_matrix_t
  public :: initialize_csr_from_element_dof_maps
  public :: csr_add_local_matrix
  public :: csr_to_dense

  type :: csr_matrix_t
    ! 1-based Compressed Sparse Row (CSR) depolama.
    !
    ! Bu tip bilincli olarak lineer solver backend'inden bagimsizdir. Amac FEM
    ! assembly katmaninin dense NxN matris zorunlulugunu kaldirmak ve ileride
    ! sparse-indefinite direct / block preconditioned backend'lere stabil bir
    ! veri siniri vermektir.
    integer :: nrows = 0
    integer :: ncols = 0
    integer, allocatable :: row_ptr(:)
    integer, allocatable :: col_ind(:)
    real(dp), allocatable :: values(:)
  contains
    procedure :: nnz => csr_nnz
    procedure :: zero_values => csr_zero_values
    procedure :: get_value => csr_get_value
  end type csr_matrix_t

contains

  subroutine initialize_csr_from_element_dof_maps( &
      matrix, nrows, ncols, element_dof_maps, status)
    ! Element-local equation map'lerinden tekrar etmeyen global CSR graph kurar.
    !
    ! Dense logical adjacency matrisi kullanilmaz. Once her global satirin element
    ! contribution adaylari compact scratch dizide toplanir; satir icinde sort +
    ! unique yapildiktan sonra yalniz gercek structural nonzero'lar CSR'a yazilir.
    ! Final matrix belleği O(nrow+nnz)'dir. Pattern-build scratch'i gecici olarak
    ! O(nelem*nlocal^2) integer tutar ve graph tamamlaninca serbest birakilir.
    type(csr_matrix_t), intent(out) :: matrix
    integer, intent(in) :: nrows, ncols
    integer, intent(in) :: element_dof_maps(:,:)
    integer, intent(out) :: status

    integer, allocatable :: candidate_counts(:), candidate_ptr(:), candidates(:)
    integer, allocatable :: next_position(:), row_counts(:)
    integer :: nelem, nlocal, e, lr, lc, row, col
    integer :: i, k, first, last, previous, total_candidates, total_nnz

    status = DES_STATUS_OK

    if (nrows < 1 .or. ncols < 1) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    nelem = size(element_dof_maps,1)
    nlocal = size(element_dof_maps,2)
    if (nelem < 1 .or. nlocal < 1) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    if (any(element_dof_maps < 1) .or. any(element_dof_maps > nrows) .or. &
        any(element_dof_maps > ncols)) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    matrix%nrows = nrows
    matrix%ncols = ncols
    allocate(candidate_counts(nrows),candidate_ptr(nrows+1), &
             next_position(nrows),row_counts(nrows))
    candidate_counts = 0

    ! Her local row, ayni elementin tum local kolonlarini structural aday yapar.
    do e = 1,nelem
      do lr = 1,nlocal
        row = element_dof_maps(e,lr)
        candidate_counts(row) = candidate_counts(row)+nlocal
      end do
    end do

    candidate_ptr(1) = 1
    do row = 1,nrows
      candidate_ptr(row+1) = candidate_ptr(row)+candidate_counts(row)
    end do
    total_candidates = candidate_ptr(nrows+1)-1
    if (total_candidates < 1) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    allocate(candidates(total_candidates))
    candidates = 0
    next_position = candidate_ptr(1:nrows)

    do e = 1,nelem
      do lr = 1,nlocal
        row = element_dof_maps(e,lr)
        do lc = 1,nlocal
          candidates(next_position(row)) = element_dof_maps(e,lc)
          next_position(row) = next_position(row)+1
        end do
      end do
    end do

    ! Aynı global row komsu elementlerden birden cok kez gelebilir. Sort+unique
    ! bu tekrarlarin CSR graph'ta duplicate structural entry yaratmasini engeller.
    row_counts = 0
    do row = 1,nrows
      first = candidate_ptr(row)
      last = candidate_ptr(row+1)-1
      call sort_integer_range(candidates,first,last)
      if (last < first) cycle

      previous = 0
      do k = first,last
        col = candidates(k)
        if (k == first .or. col /= previous) then
          row_counts(row) = row_counts(row)+1
          previous = col
        end if
      end do
    end do

    allocate(matrix%row_ptr(nrows+1))
    matrix%row_ptr(1) = 1
    do i = 1,nrows
      matrix%row_ptr(i+1) = matrix%row_ptr(i)+row_counts(i)
    end do

    total_nnz = matrix%row_ptr(nrows+1)-1
    if (total_nnz < 1) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    allocate(matrix%col_ind(total_nnz),matrix%values(total_nnz))
    matrix%col_ind = 0
    matrix%values = 0.0_dp

    next_position = matrix%row_ptr(1:nrows)
    do row = 1,nrows
      first = candidate_ptr(row)
      last = candidate_ptr(row+1)-1
      if (last < first) cycle

      previous = 0
      do k = first,last
        col = candidates(k)
        if (k == first .or. col /= previous) then
          matrix%col_ind(next_position(row)) = col
          next_position(row) = next_position(row)+1
          previous = col
        end if
      end do
    end do

    if (any(matrix%col_ind < 1) .or. any(matrix%col_ind > ncols)) then
      status = DES_ERROR_INVALID_CONSTRAINT
    end if
  end subroutine initialize_csr_from_element_dof_maps

  subroutine csr_add_local_matrix(matrix, dof_map, local_matrix, status)
    class(csr_matrix_t), intent(inout) :: matrix
    integer, intent(in) :: dof_map(:)
    real(dp), intent(in) :: local_matrix(:,:)
    integer, intent(out) :: status

    integer :: nlocal, lr, lc, row, col, position

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
    if (any(dof_map < 1) .or. any(dof_map > matrix%nrows) .or. &
        any(dof_map > matrix%ncols)) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    do lr = 1,nlocal
      row = dof_map(lr)
      do lc = 1,nlocal
        col = dof_map(lc)
        position = find_csr_position(matrix,row,col)
        if (position == 0) then
          ! Graph ile element topology arasinda uyumsuzluk varsa sessizce yeni
          ! nonzero yaratmak yerine fail-fast yapilir. Production sparse assembly
          ! icin structural graph'in degismezligi kritik bir sozlesmedir.
          status = DES_ERROR_INVALID_CONSTRAINT
          return
        end if
        matrix%values(position) = matrix%values(position)+local_matrix(lr,lc)
      end do
    end do
  end subroutine csr_add_local_matrix

  subroutine csr_to_dense(matrix, dense, status)
    class(csr_matrix_t), intent(in) :: matrix
    real(dp), intent(out) :: dense(:,:)
    integer, intent(out) :: status

    integer :: row, k

    status = DES_STATUS_OK
    dense = 0.0_dp

    if (.not. allocated(matrix%row_ptr) .or. .not. allocated(matrix%col_ind) .or. &
        .not. allocated(matrix%values)) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if
    if (size(dense,1) /= matrix%nrows .or. size(dense,2) /= matrix%ncols) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    do row = 1,matrix%nrows
      do k = matrix%row_ptr(row),matrix%row_ptr(row+1)-1
        dense(row,matrix%col_ind(k)) = matrix%values(k)
      end do
    end do
  end subroutine csr_to_dense

  integer function csr_nnz(this) result(nnz)
    class(csr_matrix_t), intent(in) :: this

    if (allocated(this%values)) then
      nnz = size(this%values)
    else
      nnz = 0
    end if
  end function csr_nnz

  subroutine csr_zero_values(this)
    class(csr_matrix_t), intent(inout) :: this
    if (allocated(this%values)) this%values = 0.0_dp
  end subroutine csr_zero_values

  real(dp) function csr_get_value(this, row, col) result(value)
    class(csr_matrix_t), intent(in) :: this
    integer, intent(in) :: row, col
    integer :: position

    value = 0.0_dp
    if (row < 1 .or. row > this%nrows .or. col < 1 .or. col > this%ncols) return
    if (.not. allocated(this%row_ptr) .or. .not. allocated(this%col_ind) .or. &
        .not. allocated(this%values)) return

    position = find_csr_position(this,row,col)
    if (position > 0) value = this%values(position)
  end function csr_get_value

  integer function find_csr_position(matrix, row, col) result(position)
    class(csr_matrix_t), intent(in) :: matrix
    integer, intent(in) :: row, col
    integer :: lo, hi, mid, candidate

    position = 0
    if (row < 1 .or. row > matrix%nrows) return

    lo = matrix%row_ptr(row)
    hi = matrix%row_ptr(row+1)-1
    do while (lo <= hi)
      mid = lo+(hi-lo)/2
      candidate = matrix%col_ind(mid)
      if (candidate == col) then
        position = mid
        return
      elseif (candidate < col) then
        lo = mid+1
      else
        hi = mid-1
      end if
    end do
  end function find_csr_position

  subroutine sort_integer_range(values, first, last)
    integer, intent(inout) :: values(:)
    integer, intent(in) :: first, last
    integer :: i, j, key

    if (last <= first) return

    do i = first+1,last
      key = values(i)
      j = i-1
      do while (j >= first)
        if (values(j) <= key) exit
        values(j+1) = values(j)
        j = j-1
      end do
      values(j+1) = key
    end do
  end subroutine sort_integer_range

end module des_csr_matrix
