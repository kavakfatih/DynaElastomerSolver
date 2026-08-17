module des_tensor3
  use des_kinds, only : dp
  implicit none
  private
  public :: determinant3, inverse3, identity3
contains

  pure function identity3() result(I)
    real(dp) :: I(3,3)

    I = 0.0_dp
    I(1,1) = 1.0_dp
    I(2,2) = 1.0_dp
    I(3,3) = 1.0_dp
  end function identity3

  pure function determinant3(A) result(detA)
    real(dp), intent(in) :: A(3,3)
    real(dp) :: detA

    detA = A(1,1)*(A(2,2)*A(3,3)-A(2,3)*A(3,2)) &
         - A(1,2)*(A(2,1)*A(3,3)-A(2,3)*A(3,1)) &
         + A(1,3)*(A(2,1)*A(3,2)-A(2,2)*A(3,1))
  end function determinant3

  pure subroutine inverse3(A, Ainv, detA, ok)
    real(dp), intent(in)  :: A(3,3)
    real(dp), intent(out) :: Ainv(3,3)
    real(dp), intent(out) :: detA
    logical, intent(out) :: ok

    real(dp), parameter :: tiny_det = 100.0_dp * epsilon(1.0_dp)

    detA = determinant3(A)
    ok = abs(detA) > tiny_det

    if (.not. ok) then
      Ainv = 0.0_dp
      return
    end if

    Ainv(1,1) =  (A(2,2)*A(3,3)-A(2,3)*A(3,2))/detA
    Ainv(1,2) = -(A(1,2)*A(3,3)-A(1,3)*A(3,2))/detA
    Ainv(1,3) =  (A(1,2)*A(2,3)-A(1,3)*A(2,2))/detA
    Ainv(2,1) = -(A(2,1)*A(3,3)-A(2,3)*A(3,1))/detA
    Ainv(2,2) =  (A(1,1)*A(3,3)-A(1,3)*A(3,1))/detA
    Ainv(2,3) = -(A(1,1)*A(2,3)-A(1,3)*A(2,1))/detA
    Ainv(3,1) =  (A(2,1)*A(3,2)-A(2,2)*A(3,1))/detA
    Ainv(3,2) = -(A(1,1)*A(3,2)-A(1,2)*A(3,1))/detA
    Ainv(3,3) =  (A(1,1)*A(2,2)-A(1,2)*A(2,1))/detA
  end subroutine inverse3

end module des_tensor3
