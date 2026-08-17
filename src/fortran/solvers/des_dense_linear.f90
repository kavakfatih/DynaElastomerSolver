module des_dense_linear
  use des_kinds, only : dp
  use stdlib_linalg, only : solve
  use stdlib_linalg_state, only : linalg_state_type
  implicit none
  private
  public :: solve_dense_system
contains

  subroutine solve_dense_system(A, b, x, ok)
    real(dp), intent(in) :: A(:,:), b(:)
    real(dp), intent(out) :: x(:)
    logical, intent(out) :: ok

    real(dp), allocatable, target :: Awork(:,:)
    real(dp), allocatable :: solution(:)
    type(linalg_state_type) :: state
    integer :: n

    n = size(b)
    ok = .false.
    x = 0.0_dp

    if (size(A,1) /= n .or. size(A,2) /= n .or. size(x) /= n) return
    if (n < 1) return

    ! Dyna'nın küçük/dense doğrulama yolu artık Fortran stdlib'in kararlı
    ! solve arayüzünü kullanır. stdlib bu işlemi LAPACK *GESV tabanı ile yapar.
    ! A'nın kullanıcı girdisini bozmamak için yalnız çalışma kopyası overwrite edilir.
    allocate(Awork(n,n))
    Awork = A

    solution = solve(Awork, b, overwrite_a=.true., err=state)
    if (.not. state%ok()) return
    if (size(solution) /= n) return

    x = solution
    ok = .true.
  end subroutine solve_dense_system
end module des_dense_linear
