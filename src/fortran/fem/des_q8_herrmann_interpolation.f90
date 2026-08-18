module des_q8_herrmann_interpolation
  use des_kinds, only : dp
  implicit none
  private

  public :: q8_shape_functions
  public :: herrmann_p1_pressure_basis

contains

  pure subroutine q8_shape_functions(xi, eta, N, dN_parent)
    ! Sekiz düğümlü serendipity quadrilateral displacement interpolasyonu.
    ! Düğüm sırası:
    ! 1=(-1,-1), 2=(1,-1), 3=(1,1), 4=(-1,1),
    ! 5=(0,-1),  6=(1,0),  7=(0,1), 8=(-1,0).
    real(dp), intent(in) :: xi, eta
    real(dp), intent(out) :: N(8), dN_parent(8,2)

    N(1) = -0.25_dp*(1.0_dp-xi)*(1.0_dp-eta)*(1.0_dp+xi+eta)
    N(2) = -0.25_dp*(1.0_dp+xi)*(1.0_dp-eta)*(1.0_dp-xi+eta)
    N(3) = -0.25_dp*(1.0_dp+xi)*(1.0_dp+eta)*(1.0_dp-xi-eta)
    N(4) = -0.25_dp*(1.0_dp-xi)*(1.0_dp+eta)*(1.0_dp+xi-eta)
    N(5) =  0.50_dp*(1.0_dp-xi*xi)*(1.0_dp-eta)
    N(6) =  0.50_dp*(1.0_dp+xi)*(1.0_dp-eta*eta)
    N(7) =  0.50_dp*(1.0_dp-xi*xi)*(1.0_dp+eta)
    N(8) =  0.50_dp*(1.0_dp-xi)*(1.0_dp-eta*eta)

    dN_parent(1,1) = -0.25_dp*(eta-1.0_dp)*(eta+2.0_dp*xi)
    dN_parent(1,2) = -0.25_dp*(2.0_dp*eta+xi)*(xi-1.0_dp)

    dN_parent(2,1) =  0.25_dp*(eta-1.0_dp)*(eta-2.0_dp*xi)
    dN_parent(2,2) =  0.25_dp*(2.0_dp*eta-xi)*(xi+1.0_dp)

    dN_parent(3,1) =  0.25_dp*(eta+1.0_dp)*(eta+2.0_dp*xi)
    dN_parent(3,2) =  0.25_dp*(2.0_dp*eta+xi)*(xi+1.0_dp)

    dN_parent(4,1) = -0.25_dp*(eta+1.0_dp)*(eta-2.0_dp*xi)
    dN_parent(4,2) = -0.25_dp*(2.0_dp*eta-xi)*(xi-1.0_dp)

    dN_parent(5,1) = xi*(eta-1.0_dp)
    dN_parent(5,2) = 0.50_dp*(xi-1.0_dp)*(xi+1.0_dp)

    dN_parent(6,1) = -0.50_dp*(eta-1.0_dp)*(eta+1.0_dp)
    dN_parent(6,2) = -eta*(xi+1.0_dp)

    dN_parent(7,1) = -xi*(eta+1.0_dp)
    dN_parent(7,2) = -0.50_dp*(xi-1.0_dp)*(xi+1.0_dp)

    dN_parent(8,1) = 0.50_dp*(eta-1.0_dp)*(eta+1.0_dp)
    dN_parent(8,2) = eta*(xi-1.0_dp)
  end subroutine q8_shape_functions

  pure subroutine herrmann_p1_pressure_basis(xi, eta, Np)
    ! Q8 displacement alanına eşlik edecek ilk 3-DOF lineer pressure-space adayı.
    ! Bu basis henüz production kabulü değildir; inf-sup/rank/checkerboard ve
    ! distorted-element testleri tamamlanmadan element formulasyonu sabitlenmez.
    real(dp), intent(in) :: xi, eta
    real(dp), intent(out) :: Np(3)

    Np = [1.0_dp, xi, eta]
  end subroutine herrmann_p1_pressure_basis

end module des_q8_herrmann_interpolation
