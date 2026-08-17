module des_dense_linear
  use des_kinds, only : dp
  implicit none
  private
  public :: solve_dense_system
contains

  subroutine solve_dense_system(A, b, x, ok)
    real(dp), intent(in) :: A(:,:), b(:)
    real(dp), intent(out) :: x(:)
    logical, intent(out) :: ok

    real(dp), allocatable :: M(:,:), rhs(:), rowtmp(:)
    real(dp) :: factor, pivot_tol, tmp
    integer :: n, i, k, pivot, relpivot

    n = size(b)
    ok = .false.
    x = 0.0_dp

    if (size(A,1) /= n .or. size(A,2) /= n .or. size(x) /= n) return

    allocate(M(n,n), rhs(n), rowtmp(n))
    M = A
    rhs = b
    pivot_tol = 100.0_dp*epsilon(1.0_dp)*max(1.0_dp, maxval(abs(M)))

    do k = 1,n-1
      relpivot = maxloc(abs(M(k:n,k)), dim=1)
      pivot = k + relpivot - 1
      if (abs(M(pivot,k)) <= pivot_tol) return

      if (pivot /= k) then
        rowtmp = M(k,:)
        M(k,:) = M(pivot,:)
        M(pivot,:) = rowtmp
        tmp = rhs(k)
        rhs(k) = rhs(pivot)
        rhs(pivot) = tmp
      end if

      do i = k+1,n
        factor = M(i,k)/M(k,k)
        M(i,k:n) = M(i,k:n) - factor*M(k,k:n)
        rhs(i) = rhs(i) - factor*rhs(k)
      end do
    end do

    if (abs(M(n,n)) <= pivot_tol) return

    x(n) = rhs(n)/M(n,n)
    do i = n-1,1,-1
      if (abs(M(i,i)) <= pivot_tol) return
      x(i) = (rhs(i)-dot_product(M(i,i+1:n),x(i+1:n)))/M(i,i)
    end do

    ok = .true.
  end subroutine solve_dense_system
end module des_dense_linear
