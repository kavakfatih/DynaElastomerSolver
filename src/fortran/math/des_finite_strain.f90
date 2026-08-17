module des_finite_strain
  use des_kinds, only : dp
  use des_tensor3, only : determinant3
  implicit none
  private
  public :: right_cauchy_green, left_cauchy_green, first_invariant_from_F, invariants3
contains

  pure function right_cauchy_green(F) result(C)
    real(dp), intent(in) :: F(3,3)
    real(dp) :: C(3,3)
    C = matmul(transpose(F), F)
  end function right_cauchy_green

  pure function left_cauchy_green(F) result(b)
    real(dp), intent(in) :: F(3,3)
    real(dp) :: b(3,3)
    b = matmul(F, transpose(F))
  end function left_cauchy_green

  pure function first_invariant_from_F(F) result(I1)
    real(dp), intent(in) :: F(3,3)
    real(dp) :: I1
    ! I1(C) = tr(F^T F) = F:F.
    I1 = sum(F*F)
  end function first_invariant_from_F

  pure subroutine invariants3(A, I1, I2, I3)
    real(dp), intent(in) :: A(3,3)
    real(dp), intent(out) :: I1, I2, I3
    real(dp) :: A2(3,3), trA2

    I1 = A(1,1) + A(2,2) + A(3,3)
    A2 = matmul(A, A)
    trA2 = A2(1,1) + A2(2,2) + A2(3,3)
    I2 = 0.5_dp*(I1*I1 - trA2)
    I3 = determinant3(A)
  end subroutine invariants3
end module des_finite_strain
