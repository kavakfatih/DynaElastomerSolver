module des_q4_plane_strain_neo_hookean
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_ELEMENT_JACOBIAN
  use des_material_types, only : material_kinematics_t, material_response_t, neo_hookean_parameters_t
  use des_neo_hookean, only : evaluate_neo_hookean
  use des_q4_shape, only : q4_shape_functions
  use des_integration_point_results, only : integration_point_result_t
  implicit none
  private
  public :: evaluate_q4_plane_strain_element
contains

  pure subroutine evaluate_q4_plane_strain_element( &
      X, u, parameters, residual, tangent, status, min_j, integration_results)
    real(dp), intent(in) :: X(4,2)
    real(dp), intent(in) :: u(4,2)
    type(neo_hookean_parameters_t), intent(in) :: parameters
    real(dp), intent(out) :: residual(8)
    real(dp), intent(out) :: tangent(8,8)
    integer, intent(out) :: status
    real(dp), intent(out) :: min_j
    type(integration_point_result_t), intent(out), optional :: integration_results(4)

    real(dp), parameter :: gp = 0.57735026918962576451_dp
    real(dp), parameter :: gauss_xi(4)  = [-gp, gp, gp, -gp]
    real(dp), parameter :: gauss_eta(4) = [-gp, -gp, gp, gp]
    real(dp), parameter :: jac_tol = 100.0_dp*epsilon(1.0_dp)

    real(dp) :: N(4), dN_parent(4,2), dN_dX(4,2)
    real(dp) :: Jmap(2,2), invJmap(2,2), detJmap
    real(dp) :: F(3,3), weight
    type(material_kinematics_t) :: kin
    type(material_response_t) :: response
    integer :: g, a, b, i, k, Jdir, Ldir, row, col

    residual = 0.0_dp
    tangent = 0.0_dp
    status = DES_STATUS_OK
    min_j = huge(1.0_dp)

    do g = 1,4
      if (present(integration_results)) then
        integration_results(g) = integration_point_result_t()
        integration_results(g)%point_id = g
        integration_results(g)%xi = gauss_xi(g)
        integration_results(g)%eta = gauss_eta(g)
      end if

      call q4_shape_functions(gauss_xi(g), gauss_eta(g), N, dN_parent)
      call reference_gradient(X, dN_parent, Jmap, invJmap, detJmap, dN_dX)

      if (present(integration_results)) then
        integration_results(g)%reference_weight = detJmap
      end if

      if (detJmap <= jac_tol) then
        status = DES_ERROR_INVALID_ELEMENT_JACOBIAN
        if (present(integration_results)) integration_results(g)%status = status
        return
      end if

      F = 0.0_dp
      F(1,1) = 1.0_dp
      F(2,2) = 1.0_dp
      F(3,3) = 1.0_dp

      do a = 1,4
        do i = 1,2
          do Jdir = 1,2
            F(i,Jdir) = F(i,Jdir) + u(a,i)*dN_dX(a,Jdir)
          end do
        end do
      end do

      kin%F = F
      call evaluate_neo_hookean(kin, parameters, response)
      min_j = min(min_j, response%J)

      if (present(integration_results)) then
        integration_results(g)%F = F
        integration_results(g)%J = response%J
        integration_results(g)%P = response%P
        integration_results(g)%cauchy = response%cauchy
        integration_results(g)%strain_energy_density = response%energy
        integration_results(g)%status = response%status
        integration_results(g)%valid = response%valid
      end if

      if (.not. response%valid) then
        ! Material-point katmanındaki gerçek neden korunur; örneğin non-positive J.
        status = response%status
        return
      end if

      ! Total-Lagrangian iç kuvvet: r_ai = integral(P_iJ * N_a,J dV0).
      weight = detJmap
      do a = 1,4
        do i = 1,2
          row = 2*(a-1) + i
          do Jdir = 1,2
            residual(row) = residual(row) + response%P(i,Jdir)*dN_dX(a,Jdir)*weight
          end do
        end do
      end do

      ! Tutarlı element tangent:
      ! K_ai,bk = integral(A_iJkL * N_a,J * N_b,L dV0), A=dP/dF.
      do a = 1,4
        do i = 1,2
          row = 2*(a-1) + i
          do b = 1,4
            do k = 1,2
              col = 2*(b-1) + k
              do Jdir = 1,2
                do Ldir = 1,2
                  tangent(row,col) = tangent(row,col) &
                    + response%tangent(i,Jdir,k,Ldir) &
                    * dN_dX(a,Jdir)*dN_dX(b,Ldir)*weight
                end do
              end do
            end do
          end do
        end do
      end do
    end do
  end subroutine evaluate_q4_plane_strain_element

  pure subroutine reference_gradient(X, dN_parent, Jmap, invJmap, detJmap, dN_dX)
    real(dp), intent(in) :: X(4,2), dN_parent(4,2)
    real(dp), intent(out) :: Jmap(2,2), invJmap(2,2), detJmap, dN_dX(4,2)
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
      dN_dX(a,1) = invJmap(1,1)*dN_parent(a,1) + invJmap(1,2)*dN_parent(a,2)
      dN_dX(a,2) = invJmap(2,1)*dN_parent(a,1) + invJmap(2,2)*dN_parent(a,2)
    end do
  end subroutine reference_gradient
end module des_q4_plane_strain_neo_hookean
