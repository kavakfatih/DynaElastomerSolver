module des_mixed_schur_operator
  use des_kinds, only : dp, i64
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONSTRAINT
  use des_csr_matrix, only : csr_matrix_t
  use des_mixed_block_system, only : mixed_block_partition_t, &
      apply_mixed_kup, apply_mixed_kpu, apply_mixed_kpp
  implicit none
  private

  ! Matrix-free Schur complement:
  !
  !   S p = Kpp p - Kpu (Kuu^{-1} (Kup p))
  !
  ! Kuu^{-1} burada explicit inverse değildir. Caller bir inverse-action/solve
  ! callback'i sağlar. Böylece aynı operator küçük reference solve, MUMPS factorized
  ! solve veya ileride AMG/ILU inner solve ile kullanılabilir. Schur matrisi hiçbir
  ! zaman explicit dense/sparse ürün olarak kurulmak zorunda değildir.
  abstract interface
    subroutine mixed_kuu_solve_action(rhs,solution,status)
      import dp
      real(dp), intent(in) :: rhs(:)
      real(dp), intent(out) :: solution(:)
      integer, intent(out) :: status
    end subroutine mixed_kuu_solve_action
  end interface

  public :: mixed_kuu_solve_action
  public :: apply_mixed_schur_operator

contains

  subroutine apply_mixed_schur_operator( &
      matrix,partition,pressure,schur_pressure,solve_kuu,status)
    class(csr_matrix_t), intent(in) :: matrix
    type(mixed_block_partition_t), intent(in) :: partition
    real(dp), intent(in) :: pressure(:)
    real(dp), intent(out) :: schur_pressure(:)
    procedure(mixed_kuu_solve_action) :: solve_kuu
    integer, intent(out) :: status

    real(dp), allocatable :: kup_pressure(:),kuu_solution(:)
    real(dp), allocatable :: kpu_solution(:),kpp_pressure(:)

    status = DES_ERROR_INVALID_CONSTRAINT
    schur_pressure = 0.0_dp

    if (.not. partition%is_valid()) return
    if (size(pressure,kind=i64) /= partition%n_pressure .or. &
        size(schur_pressure,kind=i64) /= partition%n_pressure) return

    allocate(kup_pressure(partition%n_kinematic))
    allocate(kuu_solution(partition%n_kinematic))
    allocate(kpu_solution(partition%n_pressure))
    allocate(kpp_pressure(partition%n_pressure))

    call apply_mixed_kup(matrix,partition,pressure,kup_pressure,status)
    if (status /= DES_STATUS_OK) return

    call solve_kuu(kup_pressure,kuu_solution,status)
    if (status /= DES_STATUS_OK) return
    if (size(kuu_solution,kind=i64) /= partition%n_kinematic) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    call apply_mixed_kpu(matrix,partition,kuu_solution,kpu_solution,status)
    if (status /= DES_STATUS_OK) return

    call apply_mixed_kpp(matrix,partition,pressure,kpp_pressure,status)
    if (status /= DES_STATUS_OK) return

    schur_pressure = kpp_pressure-kpu_solution
    status = DES_STATUS_OK
  end subroutine apply_mixed_schur_operator

end module des_mixed_schur_operator
