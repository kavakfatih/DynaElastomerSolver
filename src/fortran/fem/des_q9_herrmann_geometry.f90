module des_q9_herrmann_geometry
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_ELEMENT_JACOBIAN
  use des_q9_herrmann_interpolation, only : q9_shape_functions
  implicit none
  private

  public :: q9_reference_gradient

contains

  pure subroutine q9_reference_gradient( &
      X, xi, eta, N, dN_parent, dN_dX, x_point, Jmap, det_jac, status)
    ! Q9 isoparametric geometri ve reference-gradient donusumu.
    ! Q8 ve Q9 adaylarinin ayni geometry contract ile karsilastirilabilmesi icin
    ! cikislar q8_reference_gradient ile ayni semantigi izler.
    real(dp), intent(in) :: X(9,2), xi, eta
    real(dp), intent(out) :: N(9), dN_parent(9,2), dN_dX(9,2)
    real(dp), intent(out) :: x_point(2), Jmap(2,2), det_jac
    integer, intent(out) :: status

    real(dp) :: inv_jac(2,2), jac_scale, jac_tol
    integer :: a

    call q9_shape_functions(xi, eta, N, dN_parent)

    x_point = 0.0_dp
    Jmap = 0.0_dp
    do a = 1,9
      x_point(1) = x_point(1) + N(a)*X(a,1)
      x_point(2) = x_point(2) + N(a)*X(a,2)

      Jmap(1,1) = Jmap(1,1) + dN_parent(a,1)*X(a,1)
      Jmap(1,2) = Jmap(1,2) + dN_parent(a,1)*X(a,2)
      Jmap(2,1) = Jmap(2,1) + dN_parent(a,2)*X(a,1)
      Jmap(2,2) = Jmap(2,2) + dN_parent(a,2)*X(a,2)
    end do

    det_jac = Jmap(1,1)*Jmap(2,2) - Jmap(1,2)*Jmap(2,1)
    jac_scale = max(1.0_dp,maxval(abs(Jmap)))
    jac_tol = 100.0_dp*epsilon(1.0_dp)*jac_scale*jac_scale

    if (det_jac <= jac_tol) then
      dN_dX = 0.0_dp
      status = DES_ERROR_INVALID_ELEMENT_JACOBIAN
      return
    end if

    inv_jac(1,1) =  Jmap(2,2)/det_jac
    inv_jac(1,2) = -Jmap(1,2)/det_jac
    inv_jac(2,1) = -Jmap(2,1)/det_jac
    inv_jac(2,2) =  Jmap(1,1)/det_jac

    do a = 1,9
      dN_dX(a,1) = inv_jac(1,1)*dN_parent(a,1) &
                  + inv_jac(1,2)*dN_parent(a,2)
      dN_dX(a,2) = inv_jac(2,1)*dN_parent(a,1) &
                  + inv_jac(2,2)*dN_parent(a,2)
    end do

    status = DES_STATUS_OK
  end subroutine q9_reference_gradient

end module des_q9_herrmann_geometry
