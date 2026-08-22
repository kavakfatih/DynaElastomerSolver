module des_mixed_block_system
  use des_kinds, only : dp, i64
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONSTRAINT
  use des_csr_matrix, only : csr_matrix_t
  use des_2d_dof_manager, only : dof_layout_2d_t
  implicit none
  private

  ! Mixed u-P global equation ordering contract:
  !
  !   [ bütün kinematik DOF'lar | bütün pressure DOF'lar ]
  !
  ! Kinematik blok nodal displacement/twist ve varsa generalized-plane-strain
  ! internal DOF'larını birlikte taşır. Pressure ayrı ikinci field'dır.
  !
  ! Bu katman monolitik CSR numeric storage'ı kopyalamaz. MUMPS Direct mevcut
  ! production yolu aynı monolitik matrisi kullanmaya devam ederken iterative
  ! Schur/FGMRES geliştirmesi Kuu/Kup/Kpu/Kpp operator görünümlerini bu sınıra
  ! dayanarak kullanabilir.
  type, public :: mixed_block_partition_t
    integer(i64) :: n_kinematic = 0_i64
    integer(i64) :: n_pressure = 0_i64
    integer(i64) :: n_total = 0_i64
  contains
    procedure :: is_valid => mixed_block_partition_is_valid
  end type mixed_block_partition_t

  public :: initialize_mixed_block_partition
  public :: initialize_mixed_block_partition_from_2d_layout
  public :: split_mixed_vector
  public :: join_mixed_vector
  public :: apply_mixed_block_operator
  public :: apply_mixed_kuu
  public :: apply_mixed_kup
  public :: apply_mixed_kpu
  public :: apply_mixed_kpp

contains

  pure logical function mixed_block_partition_is_valid(this) result(is_valid)
    class(mixed_block_partition_t), intent(in) :: this

    is_valid = .false.
    if (this%n_kinematic < 1_i64 .or. this%n_pressure < 1_i64) return
    if (this%n_kinematic > huge(0_i64)-this%n_pressure) return
    is_valid = this%n_total == this%n_kinematic+this%n_pressure
  end function mixed_block_partition_is_valid

  subroutine initialize_mixed_block_partition(n_kinematic,n_pressure,partition,status)
    integer(i64), intent(in) :: n_kinematic,n_pressure
    type(mixed_block_partition_t), intent(out) :: partition
    integer, intent(out) :: status

    partition = mixed_block_partition_t()
    status = DES_ERROR_INVALID_CONSTRAINT

    if (n_kinematic < 1_i64 .or. n_pressure < 1_i64) return
    if (n_kinematic > huge(0_i64)-n_pressure) return

    partition%n_kinematic = n_kinematic
    partition%n_pressure = n_pressure
    partition%n_total = n_kinematic+n_pressure
    status = DES_STATUS_OK
  end subroutine initialize_mixed_block_partition

  subroutine initialize_mixed_block_partition_from_2d_layout(layout,partition,status)
    type(dof_layout_2d_t), intent(in) :: layout
    type(mixed_block_partition_t), intent(out) :: partition
    integer, intent(out) :: status
    integer(i64) :: n_kinematic

    partition = mixed_block_partition_t()
    status = DES_ERROR_INVALID_CONSTRAINT

    if (layout%nodal_equation_count < 0_i64 .or. &
        layout%generalized_equation_count < 0_i64 .or. &
        layout%pressure_equation_count < 1_i64) return
    if (layout%nodal_equation_count > &
        huge(0_i64)-layout%generalized_equation_count) return

    n_kinematic = layout%nodal_equation_count+layout%generalized_equation_count
    call initialize_mixed_block_partition( &
        n_kinematic,layout%pressure_equation_count,partition,status)
    if (status /= DES_STATUS_OK) return

    if (partition%n_total /= layout%total_equation_count) then
      partition = mixed_block_partition_t()
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    status = DES_STATUS_OK
  end subroutine initialize_mixed_block_partition_from_2d_layout

  subroutine split_mixed_vector(partition,full_vector,kinematic,pressure,status)
    type(mixed_block_partition_t), intent(in) :: partition
    real(dp), intent(in) :: full_vector(:)
    real(dp), intent(out) :: kinematic(:),pressure(:)
    integer, intent(out) :: status
    integer(i64) :: pressure_first

    status = DES_ERROR_INVALID_CONSTRAINT
    kinematic = 0.0_dp
    pressure = 0.0_dp

    if (.not. partition%is_valid()) return
    if (size(full_vector,kind=i64) /= partition%n_total .or. &
        size(kinematic,kind=i64) /= partition%n_kinematic .or. &
        size(pressure,kind=i64) /= partition%n_pressure) return

    pressure_first = partition%n_kinematic+1_i64
    kinematic = full_vector(1:partition%n_kinematic)
    pressure = full_vector(pressure_first:partition%n_total)
    status = DES_STATUS_OK
  end subroutine split_mixed_vector

  subroutine join_mixed_vector(partition,kinematic,pressure,full_vector,status)
    type(mixed_block_partition_t), intent(in) :: partition
    real(dp), intent(in) :: kinematic(:),pressure(:)
    real(dp), intent(out) :: full_vector(:)
    integer, intent(out) :: status
    integer(i64) :: pressure_first

    status = DES_ERROR_INVALID_CONSTRAINT
    full_vector = 0.0_dp

    if (.not. partition%is_valid()) return
    if (size(full_vector,kind=i64) /= partition%n_total .or. &
        size(kinematic,kind=i64) /= partition%n_kinematic .or. &
        size(pressure,kind=i64) /= partition%n_pressure) return

    pressure_first = partition%n_kinematic+1_i64
    full_vector(1:partition%n_kinematic) = kinematic
    full_vector(pressure_first:partition%n_total) = pressure
    status = DES_STATUS_OK
  end subroutine join_mixed_vector

  subroutine apply_mixed_block_operator( &
      matrix,partition,x_kinematic,x_pressure,y_kinematic,y_pressure,status)
    class(csr_matrix_t), intent(in) :: matrix
    type(mixed_block_partition_t), intent(in) :: partition
    real(dp), intent(in) :: x_kinematic(:),x_pressure(:)
    real(dp), intent(out) :: y_kinematic(:),y_pressure(:)
    integer, intent(out) :: status

    integer(i64) :: row,entry,col,pressure_first

    y_kinematic = 0.0_dp
    y_pressure = 0.0_dp
    call validate_operator_inputs( &
        matrix,partition,x_kinematic,x_pressure,y_kinematic,y_pressure,status)
    if (status /= DES_STATUS_OK) return

    pressure_first = partition%n_kinematic+1_i64
    do row = 1_i64,matrix%nrows
      do entry = matrix%row_ptr(row),matrix%row_ptr(row+1_i64)-1_i64
        col = matrix%col_ind(entry)
        if (row <= partition%n_kinematic) then
          if (col <= partition%n_kinematic) then
            y_kinematic(row) = y_kinematic(row)+ &
                matrix%values(entry)*x_kinematic(col)
          else
            y_kinematic(row) = y_kinematic(row)+ &
                matrix%values(entry)*x_pressure(col-pressure_first+1_i64)
          end if
        else
          if (col <= partition%n_kinematic) then
            y_pressure(row-pressure_first+1_i64) = &
                y_pressure(row-pressure_first+1_i64)+ &
                matrix%values(entry)*x_kinematic(col)
          else
            y_pressure(row-pressure_first+1_i64) = &
                y_pressure(row-pressure_first+1_i64)+ &
                matrix%values(entry)*x_pressure(col-pressure_first+1_i64)
          end if
        end if
      end do
    end do

    status = DES_STATUS_OK
  end subroutine apply_mixed_block_operator

  subroutine apply_mixed_kuu(matrix,partition,x,y,status)
    class(csr_matrix_t), intent(in) :: matrix
    type(mixed_block_partition_t), intent(in) :: partition
    real(dp), intent(in) :: x(:)
    real(dp), intent(out) :: y(:)
    integer, intent(out) :: status

    call apply_csr_block(matrix,partition,1_i64,partition%n_kinematic, &
        1_i64,partition%n_kinematic,x,y,status)
  end subroutine apply_mixed_kuu

  subroutine apply_mixed_kup(matrix,partition,x,y,status)
    class(csr_matrix_t), intent(in) :: matrix
    type(mixed_block_partition_t), intent(in) :: partition
    real(dp), intent(in) :: x(:)
    real(dp), intent(out) :: y(:)
    integer, intent(out) :: status
    integer(i64) :: first_pressure

    first_pressure = partition%n_kinematic+1_i64
    call apply_csr_block(matrix,partition,1_i64,partition%n_kinematic, &
        first_pressure,partition%n_total,x,y,status)
  end subroutine apply_mixed_kup

  subroutine apply_mixed_kpu(matrix,partition,x,y,status)
    class(csr_matrix_t), intent(in) :: matrix
    type(mixed_block_partition_t), intent(in) :: partition
    real(dp), intent(in) :: x(:)
    real(dp), intent(out) :: y(:)
    integer, intent(out) :: status
    integer(i64) :: first_pressure

    first_pressure = partition%n_kinematic+1_i64
    call apply_csr_block(matrix,partition,first_pressure,partition%n_total, &
        1_i64,partition%n_kinematic,x,y,status)
  end subroutine apply_mixed_kpu

  subroutine apply_mixed_kpp(matrix,partition,x,y,status)
    class(csr_matrix_t), intent(in) :: matrix
    type(mixed_block_partition_t), intent(in) :: partition
    real(dp), intent(in) :: x(:)
    real(dp), intent(out) :: y(:)
    integer, intent(out) :: status
    integer(i64) :: first_pressure

    first_pressure = partition%n_kinematic+1_i64
    call apply_csr_block(matrix,partition,first_pressure,partition%n_total, &
        first_pressure,partition%n_total,x,y,status)
  end subroutine apply_mixed_kpp

  subroutine apply_csr_block( &
      matrix,partition,row_first,row_last,col_first,col_last,x,y,status)
    class(csr_matrix_t), intent(in) :: matrix
    type(mixed_block_partition_t), intent(in) :: partition
    integer(i64), intent(in) :: row_first,row_last,col_first,col_last
    real(dp), intent(in) :: x(:)
    real(dp), intent(out) :: y(:)
    integer, intent(out) :: status

    integer(i64) :: row,entry,col,local_row,local_col

    y = 0.0_dp
    status = DES_ERROR_INVALID_CONSTRAINT
    if (.not. matrix_matches_partition(matrix,partition)) return
    if (row_first < 1_i64 .or. row_last > partition%n_total .or. &
        col_first < 1_i64 .or. col_last > partition%n_total .or. &
        row_last < row_first .or. col_last < col_first) return
    if (size(x,kind=i64) /= col_last-col_first+1_i64 .or. &
        size(y,kind=i64) /= row_last-row_first+1_i64) return

    do row = row_first,row_last
      local_row = row-row_first+1_i64
      do entry = matrix%row_ptr(row),matrix%row_ptr(row+1_i64)-1_i64
        col = matrix%col_ind(entry)
        if (col < col_first .or. col > col_last) cycle
        local_col = col-col_first+1_i64
        y(local_row) = y(local_row)+matrix%values(entry)*x(local_col)
      end do
    end do

    status = DES_STATUS_OK
  end subroutine apply_csr_block

  subroutine validate_operator_inputs( &
      matrix,partition,x_kinematic,x_pressure,y_kinematic,y_pressure,status)
    class(csr_matrix_t), intent(in) :: matrix
    type(mixed_block_partition_t), intent(in) :: partition
    real(dp), intent(in) :: x_kinematic(:),x_pressure(:)
    real(dp), intent(in) :: y_kinematic(:),y_pressure(:)
    integer, intent(out) :: status

    status = DES_ERROR_INVALID_CONSTRAINT
    if (.not. matrix_matches_partition(matrix,partition)) return
    if (size(x_kinematic,kind=i64) /= partition%n_kinematic .or. &
        size(y_kinematic,kind=i64) /= partition%n_kinematic .or. &
        size(x_pressure,kind=i64) /= partition%n_pressure .or. &
        size(y_pressure,kind=i64) /= partition%n_pressure) return
    status = DES_STATUS_OK
  end subroutine validate_operator_inputs

  logical function matrix_matches_partition(matrix,partition) result(matches)
    class(csr_matrix_t), intent(in) :: matrix
    type(mixed_block_partition_t), intent(in) :: partition

    matches = .false.
    if (.not. partition%is_valid()) return
    if (matrix%nrows /= partition%n_total .or. matrix%ncols /= partition%n_total) return
    if (.not. allocated(matrix%row_ptr) .or. .not. allocated(matrix%col_ind) .or. &
        .not. allocated(matrix%values)) return
    matches = .true.
  end function matrix_matches_partition

end module des_mixed_block_system
