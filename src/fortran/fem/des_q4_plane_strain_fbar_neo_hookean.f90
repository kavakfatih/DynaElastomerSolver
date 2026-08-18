module des_q4_plane_strain_fbar_neo_hookean
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_ELEMENT_JACOBIAN, &
                         DES_ERROR_SINGULAR_F, DES_ERROR_NONPOSITIVE_J
  use des_tensor3, only : inverse3
  use des_material_types, only : material_kinematics_t, material_response_t, &
                                 neo_hookean_parameters_t
  use des_neo_hookean, only : evaluate_neo_hookean
  use des_q4_shape, only : q4_shape_functions
  implicit none
  private

  public :: evaluate_q4_plane_strain_fbar_element

contains

  subroutine evaluate_q4_plane_strain_fbar_element( &
      X, u, parameters, residual, tangent, status, min_j, j_bar)
    ! V0.3 finite-strain F-bar Q4 formulation.
    !
    ! F_bar_g = alpha_g F_g
    ! alpha_g = (J_bar/J_g)^(1/3)
    ! J_bar   = integral(J dV0) / integral(dV0)
    !
    ! Residual, E = sum_g W(F_bar_g) w_g enerjisinin ilk varyasyonudur.
    ! Tangent ise aynı enerjinin ikinci varyasyonundan analitik hesaplanır.
    real(dp), intent(in) :: X(4,2), u(4,2)
    type(neo_hookean_parameters_t), intent(in) :: parameters
    real(dp), intent(out) :: residual(8), tangent(8,8)
    integer, intent(out) :: status
    real(dp), intent(out) :: min_j
    real(dp), intent(out), optional :: j_bar

    real(dp) :: jbar_local

    call evaluate_fbar_residual( &
        X, u, parameters, residual, status, min_j, jbar_local)
    tangent = 0.0_dp
    if (present(j_bar)) j_bar = jbar_local
    if (status /= DES_STATUS_OK) return

    call evaluate_fbar_analytic_tangent( &
        X, u, parameters, tangent, status)
  end subroutine evaluate_q4_plane_strain_fbar_element

  subroutine evaluate_fbar_residual( &
      X, u, parameters, residual, status, min_j, j_bar)
    real(dp), intent(in) :: X(4,2), u(4,2)
    type(neo_hookean_parameters_t), intent(in) :: parameters
    real(dp), intent(out) :: residual(8)
    integer, intent(out) :: status
    real(dp), intent(out) :: min_j, j_bar

    real(dp), parameter :: gp = 0.57735026918962576451_dp
    real(dp), parameter :: gauss_xi(4) = [-gp, gp, gp, -gp]
    real(dp), parameter :: gauss_eta(4) = [-gp, -gp, gp, gp]
    real(dp), parameter :: jac_tol = 100.0_dp*epsilon(1.0_dp)

    real(dp) :: N(4), dN_parent(4,2)
    real(dp) :: dN_dX(4,2,4), weight(4)
    real(dp) :: F(3,3,4), FinvT(3,3,4), J(4)
    real(dp) :: alpha(4), Pbar(3,3,4), Fbar(3,3)
    real(dp) :: p_dot_fbar(4), volume, dJbar, dJ_over_J
    real(dp) :: local_term, coupling_term
    real(dp) :: Jmap(2,2), invJmap(2,2), detJmap, Finv(3,3)
    integer :: g, a, i, Jdir, hgp
    logical :: inverse_ok
    type(material_kinematics_t) :: kin
    type(material_response_t) :: response

    residual = 0.0_dp
    status = DES_STATUS_OK
    min_j = huge(1.0_dp)
    j_bar = 0.0_dp
    volume = 0.0_dp

    do g = 1,4
      call q4_shape_functions(gauss_xi(g),gauss_eta(g),N,dN_parent)
      call reference_gradient(X,dN_parent,Jmap,invJmap,detJmap,dN_dX(:,:,g))
      if (detJmap <= jac_tol) then
        status = DES_ERROR_INVALID_ELEMENT_JACOBIAN
        return
      end if

      weight(g) = detJmap
      volume = volume + weight(g)

      F(:,:,g) = 0.0_dp
      F(1,1,g) = 1.0_dp
      F(2,2,g) = 1.0_dp
      F(3,3,g) = 1.0_dp
      do a = 1,4
        do i = 1,2
          do Jdir = 1,2
            F(i,Jdir,g) = F(i,Jdir,g) + u(a,i)*dN_dX(a,Jdir,g)
          end do
        end do
      end do

      call inverse3(F(:,:,g),Finv,J(g),inverse_ok)
      min_j = min(min_j,J(g))
      if (.not. inverse_ok) then
        status = DES_ERROR_SINGULAR_F
        return
      end if
      if (J(g) <= 0.0_dp) then
        status = DES_ERROR_NONPOSITIVE_J
        return
      end if
      FinvT(:,:,g) = transpose(Finv)
      j_bar = j_bar + weight(g)*J(g)
    end do

    j_bar = j_bar/volume
    if (j_bar <= 0.0_dp) then
      status = DES_ERROR_NONPOSITIVE_J
      return
    end if

    do g = 1,4
      alpha(g) = (j_bar/J(g))**(1.0_dp/3.0_dp)
      Fbar = alpha(g)*F(:,:,g)
      kin%F = Fbar
      call evaluate_neo_hookean(kin,parameters,response)
      if (.not. response%valid) then
        status = response%status
        return
      end if
      Pbar(:,:,g) = response%P
      p_dot_fbar(g) = sum(Pbar(:,:,g)*Fbar)
    end do

    do a = 1,4
      do i = 1,2
        dJbar = 0.0_dp
        do hgp = 1,4
          dJ_over_J = 0.0_dp
          do Jdir = 1,2
            dJ_over_J = dJ_over_J &
              + FinvT(i,Jdir,hgp)*dN_dX(a,Jdir,hgp)
          end do
          dJbar = dJbar + weight(hgp)*J(hgp)*dJ_over_J
        end do
        dJbar = dJbar/volume

        do g = 1,4
          local_term = 0.0_dp
          dJ_over_J = 0.0_dp
          do Jdir = 1,2
            local_term = local_term &
              + Pbar(i,Jdir,g)*dN_dX(a,Jdir,g)
            dJ_over_J = dJ_over_J &
              + FinvT(i,Jdir,g)*dN_dX(a,Jdir,g)
          end do

          coupling_term = (p_dot_fbar(g)/3.0_dp) &
            * (dJbar/j_bar - dJ_over_J)

          residual(2*a-2+i) = residual(2*a-2+i) &
            + weight(g)*(alpha(g)*local_term + coupling_term)
        end do
      end do
    end do
  end subroutine evaluate_fbar_residual

  subroutine evaluate_fbar_analytic_tangent( &
      X, u, parameters, tangent, status)
    ! Zincir kuralı:
    !
    !   H_q = dF_bar/dq = alpha * (B_q + beta_q F)
    !
    !   beta_q = 1/3 * [ (J_bar,q/J_bar) - (J,q/J) ]
    !
    ! Consistent tangent:
    !
    !   K_qr = sum_g w_g [ H_q : A_bar : H_r + P_bar : H_qr ]
    !
    ! H_qr; alpha, J ve J_bar'ın ikinci türevlerini içerir. Bu nedenle
    ! Gauss noktaları arasındaki volumetrik F-bar coupling tangentte korunur.
    real(dp), intent(in) :: X(4,2), u(4,2)
    type(neo_hookean_parameters_t), intent(in) :: parameters
    real(dp), intent(out) :: tangent(8,8)
    integer, intent(out) :: status

    real(dp), parameter :: gp = 0.57735026918962576451_dp
    real(dp), parameter :: gauss_xi(4) = [-gp, gp, gp, -gp]
    real(dp), parameter :: gauss_eta(4) = [-gp, -gp, gp, gp]
    real(dp), parameter :: jac_tol = 100.0_dp*epsilon(1.0_dp)

    real(dp) :: N(4), dN_parent(4,2), dN_dX(4,2,4)
    real(dp) :: weight(4), volume, j_bar
    real(dp) :: F(3,3,4), Finv(3,3,4), FinvT(3,3,4), J(4)
    real(dp) :: alpha(4), Pbar(3,3,4), Abar(3,3,3,3,4)
    real(dp) :: Fbar(3,3), Jmap(2,2), invJmap(2,2), detJmap
    real(dp) :: B(3,3,8,4), s(8,4), ds(8,8,4)
    real(dp) :: jbar_prime(8), jbar_second(8,8)
    real(dp) :: beta(8,4), beta_second(8,8,4)
    real(dp) :: H(3,3,8,4), H2(3,3)
    real(dp) :: tmp1(3,3), tmp2(3,3), tmp3(3,3)
    real(dp) :: material_term, geometric_term
    integer :: g, a, i, Jdir, q, r, node, comp
    integer :: ii, jj, kk, ll
    logical :: inverse_ok
    type(material_kinematics_t) :: kin
    type(material_response_t) :: response

    tangent = 0.0_dp
    status = DES_STATUS_OK
    volume = 0.0_dp
    j_bar = 0.0_dp

    do g = 1,4
      call q4_shape_functions(gauss_xi(g),gauss_eta(g),N,dN_parent)
      call reference_gradient(X,dN_parent,Jmap,invJmap,detJmap,dN_dX(:,:,g))
      if (detJmap <= jac_tol) then
        status = DES_ERROR_INVALID_ELEMENT_JACOBIAN
        return
      end if

      weight(g) = detJmap
      volume = volume + weight(g)

      F(:,:,g) = 0.0_dp
      F(1,1,g) = 1.0_dp
      F(2,2,g) = 1.0_dp
      F(3,3,g) = 1.0_dp
      do a = 1,4
        do i = 1,2
          do Jdir = 1,2
            F(i,Jdir,g) = F(i,Jdir,g) + u(a,i)*dN_dX(a,Jdir,g)
          end do
        end do
      end do

      call inverse3(F(:,:,g),Finv(:,:,g),J(g),inverse_ok)
      if (.not. inverse_ok) then
        status = DES_ERROR_SINGULAR_F
        return
      end if
      if (J(g) <= 0.0_dp) then
        status = DES_ERROR_NONPOSITIVE_J
        return
      end if

      FinvT(:,:,g) = transpose(Finv(:,:,g))
      j_bar = j_bar + weight(g)*J(g)
    end do

    j_bar = j_bar/volume
    if (j_bar <= 0.0_dp) then
      status = DES_ERROR_NONPOSITIVE_J
      return
    end if

    do g = 1,4
      alpha(g) = (j_bar/J(g))**(1.0_dp/3.0_dp)
      Fbar = alpha(g)*F(:,:,g)
      kin%F = Fbar
      call evaluate_neo_hookean(kin,parameters,response)
      if (.not. response%valid) then
        status = response%status
        return
      end if
      Pbar(:,:,g) = response%P
      Abar(:,:,:,:,g) = response%tangent
    end do

    B = 0.0_dp
    s = 0.0_dp
    do g = 1,4
      do q = 1,8
        node = (q+1)/2
        comp = q - 2*(node-1)
        do Jdir = 1,2
          B(comp,Jdir,q,g) = dN_dX(node,Jdir,g)
        end do
        s(q,g) = sum(FinvT(:,:,g)*B(:,:,q,g))
      end do
    end do

    jbar_prime = 0.0_dp
    do q = 1,8
      do g = 1,4
        jbar_prime(q) = jbar_prime(q) &
          + weight(g)*J(g)*s(q,g)/volume
      end do
    end do

    ds = 0.0_dp
    do g = 1,4
      do q = 1,8
        do r = 1,8
          tmp1 = matmul(Finv(:,:,g),B(:,:,r,g))
          tmp2 = matmul(tmp1,Finv(:,:,g))
          tmp3 = matmul(tmp2,B(:,:,q,g))
          ds(q,r,g) = -(tmp3(1,1) + tmp3(2,2) + tmp3(3,3))
        end do
      end do
    end do

    jbar_second = 0.0_dp
    do q = 1,8
      do r = 1,8
        do g = 1,4
          jbar_second(q,r) = jbar_second(q,r) &
            + weight(g)*J(g)*(s(q,g)*s(r,g)+ds(q,r,g))/volume
        end do
      end do
    end do

    do g = 1,4
      do q = 1,8
        beta(q,g) = (jbar_prime(q)/j_bar - s(q,g))/3.0_dp
        H(:,:,q,g) = alpha(g)*(B(:,:,q,g)+beta(q,g)*F(:,:,g))
        do r = 1,8
          beta_second(q,r,g) = ( &
              jbar_second(q,r)/j_bar &
              - jbar_prime(q)*jbar_prime(r)/(j_bar*j_bar) &
              - ds(q,r,g))/3.0_dp
        end do
      end do
    end do

    do q = 1,8
      do r = 1,8
        do g = 1,4
          material_term = 0.0_dp
          do ii = 1,3
            do jj = 1,3
              do kk = 1,3
                do ll = 1,3
                  material_term = material_term &
                    + H(ii,jj,q,g)*Abar(ii,jj,kk,ll,g)*H(kk,ll,r,g)
                end do
              end do
            end do
          end do

          H2 = alpha(g)*( &
              beta(r,g)*B(:,:,q,g) &
              + beta(q,g)*B(:,:,r,g) &
              + (beta(q,g)*beta(r,g)+beta_second(q,r,g))*F(:,:,g))
          geometric_term = sum(Pbar(:,:,g)*H2)

          tangent(q,r) = tangent(q,r) &
            + weight(g)*(material_term+geometric_term)
        end do
      end do
    end do
  end subroutine evaluate_fbar_analytic_tangent

  pure subroutine reference_gradient( &
      X, dN_parent, Jmap, invJmap, detJmap, dN_dX)
    real(dp), intent(in) :: X(4,2), dN_parent(4,2)
    real(dp), intent(out) :: Jmap(2,2), invJmap(2,2), detJmap
    real(dp), intent(out) :: dN_dX(4,2)
    integer :: a

    Jmap = 0.0_dp
    do a = 1,4
      Jmap(1,1) = Jmap(1,1) + dN_parent(a,1)*X(a,1)
      Jmap(1,2) = Jmap(1,2) + dN_parent(a,1)*X(a,2)
      Jmap(2,1) = Jmap(2,1) + dN_parent(a,2)*X(a,1)
      Jmap(2,2) = Jmap(2,2) + dN_parent(a,2)*X(a,2)
    end do

    detJmap = Jmap(1,1)*Jmap(2,2) - Jmap(1,2)*Jmap(2,1)
    if (abs(detJmap) <= 100.0_dp*epsilon(1.0_dp)) then
      invJmap = 0.0_dp
      dN_dX = 0.0_dp
      return
    end if

    invJmap(1,1) =  Jmap(2,2)/detJmap
    invJmap(1,2) = -Jmap(1,2)/detJmap
    invJmap(2,1) = -Jmap(2,1)/detJmap
    invJmap(2,2) =  Jmap(1,1)/detJmap

    do a = 1,4
      dN_dX(a,1) = invJmap(1,1)*dN_parent(a,1) &
                  + invJmap(1,2)*dN_parent(a,2)
      dN_dX(a,2) = invJmap(2,1)*dN_parent(a,1) &
                  + invJmap(2,2)*dN_parent(a,2)
    end do
  end subroutine reference_gradient

end module des_q4_plane_strain_fbar_neo_hookean
