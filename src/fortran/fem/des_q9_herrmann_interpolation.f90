module des_q9_herrmann_interpolation
  use des_kinds, only : dp
  implicit none
  private

  public :: q9_shape_functions

contains

  pure subroutine q9_shape_functions(xi, eta, N, dN_parent)
    ! Dokuz dugumlu tensor-product quadratic Lagrange quadrilateral.
    ! Dugum sirasi Q8 ailesi ile ayni dis dugumleri korur ve merkeze 9. dugumu ekler:
    ! 1=(-1,-1), 2=(1,-1), 3=(1,1), 4=(-1,1),
    ! 5=(0,-1),  6=(1,0),  7=(0,1), 8=(-1,0), 9=(0,0).
    !
    ! Q9/P1 Herrmann adayi stability-first arastirma hattidir. Bu rutin yalniz
    ! displacement interpolationini tanimlar; pressure alani formulation katmaninda
    ! ayri tutulacaktir.
    real(dp), intent(in) :: xi, eta
    real(dp), intent(out) :: N(9), dN_parent(9,2)

    real(dp) :: lx_minus, lx_plus, lx_zero
    real(dp) :: ly_minus, ly_plus, ly_zero
    real(dp) :: dlx_minus, dlx_plus, dlx_zero
    real(dp) :: dly_minus, dly_plus, dly_zero

    lx_minus = 0.5_dp*xi*(xi-1.0_dp)
    lx_plus  = 0.5_dp*xi*(xi+1.0_dp)
    lx_zero  = 1.0_dp-xi*xi

    ly_minus = 0.5_dp*eta*(eta-1.0_dp)
    ly_plus  = 0.5_dp*eta*(eta+1.0_dp)
    ly_zero  = 1.0_dp-eta*eta

    dlx_minus = xi-0.5_dp
    dlx_plus  = xi+0.5_dp
    dlx_zero  = -2.0_dp*xi

    dly_minus = eta-0.5_dp
    dly_plus  = eta+0.5_dp
    dly_zero  = -2.0_dp*eta

    N(1) = lx_minus*ly_minus
    N(2) = lx_plus *ly_minus
    N(3) = lx_plus *ly_plus
    N(4) = lx_minus*ly_plus
    N(5) = lx_zero *ly_minus
    N(6) = lx_plus *ly_zero
    N(7) = lx_zero *ly_plus
    N(8) = lx_minus*ly_zero
    N(9) = lx_zero *ly_zero

    dN_parent(1,:) = [dlx_minus*ly_minus, lx_minus*dly_minus]
    dN_parent(2,:) = [dlx_plus *ly_minus, lx_plus *dly_minus]
    dN_parent(3,:) = [dlx_plus *ly_plus,  lx_plus *dly_plus]
    dN_parent(4,:) = [dlx_minus*ly_plus,  lx_minus*dly_plus]
    dN_parent(5,:) = [dlx_zero *ly_minus, lx_zero *dly_minus]
    dN_parent(6,:) = [dlx_plus *ly_zero,  lx_plus *dly_zero]
    dN_parent(7,:) = [dlx_zero *ly_plus,  lx_zero *dly_plus]
    dN_parent(8,:) = [dlx_minus*ly_zero,  lx_minus*dly_zero]
    dN_parent(9,:) = [dlx_zero *ly_zero,  lx_zero *dly_zero]
  end subroutine q9_shape_functions

end module des_q9_herrmann_interpolation
