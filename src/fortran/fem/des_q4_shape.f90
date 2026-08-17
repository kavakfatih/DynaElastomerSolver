module des_q4_shape
  use des_kinds, only : dp
  implicit none
  private
  public :: q4_shape_functions
contains

  pure subroutine q4_shape_functions(xi, eta, N, dN_parent)
    real(dp), intent(in) :: xi, eta
    real(dp), intent(out) :: N(4)
    real(dp), intent(out) :: dN_parent(4,2)

    N(1) = 0.25_dp*(1.0_dp-xi)*(1.0_dp-eta)
    N(2) = 0.25_dp*(1.0_dp+xi)*(1.0_dp-eta)
    N(3) = 0.25_dp*(1.0_dp+xi)*(1.0_dp+eta)
    N(4) = 0.25_dp*(1.0_dp-xi)*(1.0_dp+eta)

    ! Sütun 1: dN/dxi, sütun 2: dN/deta.
    dN_parent(1,1) = -0.25_dp*(1.0_dp-eta)
    dN_parent(2,1) =  0.25_dp*(1.0_dp-eta)
    dN_parent(3,1) =  0.25_dp*(1.0_dp+eta)
    dN_parent(4,1) = -0.25_dp*(1.0_dp+eta)

    dN_parent(1,2) = -0.25_dp*(1.0_dp-xi)
    dN_parent(2,2) = -0.25_dp*(1.0_dp+xi)
    dN_parent(3,2) =  0.25_dp*(1.0_dp+xi)
    dN_parent(4,2) =  0.25_dp*(1.0_dp-xi)
  end subroutine q4_shape_functions
end module des_q4_shape
