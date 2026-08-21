module des_q8_plane_strain_herrmann_neo_hookean
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_PARAMETERS
  use des_material_types, only : material_kinematics_t, material_response_t
  use des_neo_hookean_isochoric, only : evaluate_neo_hookean_isochoric
  use des_herrmann_pressure_constraint, only : herrmann_constraint_response_t, &
                                                evaluate_herrmann_pressure_constraint
  use des_q8_herrmann_interpolation, only : herrmann_p1_pressure_basis
  use des_q8_herrmann_geometry, only : q8_reference_gradient
  implicit none
  private

  integer, parameter, public :: Q8_HERRMANN_U_DOF = 16
  integer, parameter, public :: Q8_HERRMANN_P_DOF = 3
  integer, parameter, public :: Q8_HERRMANN_TOTAL_DOF = 19
  integer, parameter, public :: Q8_HERRMANN_REDUCED_ORDER = 2
  integer, parameter, public :: Q8_HERRMANN_REFERENCE_ORDER = 3

  public :: evaluate_q8_plane_strain_herrmann_element
  public :: evaluate_q8_plane_strain_herrmann_reduced_element

contains

  pure subroutine evaluate_q8_plane_strain_herrmann_element( &
      X, u, pressure_coefficients, shear_modulus, pressure_compliance, &
      residual, tangent, status, min_j)
    ! Legacy/research Q8/P1 baseline. Bu wrapper 3x3 full integration davranışını
    ! bilinçli olarak korur; mevcut regression sonuçları değişmeden kalır.
    real(dp), intent(in) :: X(8,2), u(8,2), pressure_coefficients(3)
    real(dp), intent(in) :: shear_modulus, pressure_compliance
    real(dp), intent(out) :: residual(Q8_HERRMANN_TOTAL_DOF)
    real(dp), intent(out) :: tangent(Q8_HERRMANN_TOTAL_DOF,Q8_HERRMANN_TOTAL_DOF)
    integer, intent(out) :: status
    real(dp), intent(out) :: min_j

    call evaluate_q8_plane_strain_herrmann_with_quadrature( &
        X,u,pressure_coefficients,shear_modulus,pressure_compliance, &
        Q8_HERRMANN_REFERENCE_ORDER,residual,tangent,status,min_j)
  end subroutine evaluate_q8_plane_strain_herrmann_element

  pure subroutine evaluate_q8_plane_strain_herrmann_reduced_element( &
      X, u, pressure_coefficients, shear_modulus, pressure_compliance, &
      residual, tangent, status, min_j)
    ! C2 production-aday technology: 8-node Q8 displacement + complete-linear
    ! P1 pressure alanı, 2x2 uniform reduced integration. Bu rutin tek başına
    ! "production validated" anlamına gelmez; pressure-stability/refinement
    ! kapıları ayrıca geçilmelidir.
    real(dp), intent(in) :: X(8,2), u(8,2), pressure_coefficients(3)
    real(dp), intent(in) :: shear_modulus, pressure_compliance
    real(dp), intent(out) :: residual(Q8_HERRMANN_TOTAL_DOF)
    real(dp), intent(out) :: tangent(Q8_HERRMANN_TOTAL_DOF,Q8_HERRMANN_TOTAL_DOF)
    integer, intent(out) :: status
    real(dp), intent(out) :: min_j

    call evaluate_q8_plane_strain_herrmann_with_quadrature( &
        X,u,pressure_coefficients,shear_modulus,pressure_compliance, &
        Q8_HERRMANN_REDUCED_ORDER,residual,tangent,status,min_j)
  end subroutine evaluate_q8_plane_strain_herrmann_reduced_element

  pure subroutine evaluate_q8_plane_strain_herrmann_with_quadrature( &
      X, u, pressure_coefficients, shear_modulus, pressure_compliance, &
      quadrature_order, residual, tangent, status, min_j)
    ! Ortak Q8/P1 Herrmann kernel'i. Quadrature seçimi wrapper seviyesinde explicit
    ! tutulur; constitutive model, pressure constraint, residual ve consistent
    ! tangent matematiği reduced/reference yollarında aynıdır.
    real(dp), intent(in) :: X(8,2), u(8,2), pressure_coefficients(3)
    real(dp), intent(in) :: shear_modulus, pressure_compliance
    integer, intent(in) :: quadrature_order
    real(dp), intent(out) :: residual(Q8_HERRMANN_TOTAL_DOF)
    real(dp), intent(out) :: tangent(Q8_HERRMANN_TOTAL_DOF,Q8_HERRMANN_TOTAL_DOF)
    integer, intent(out) :: status
    real(dp), intent(out) :: min_j

    real(dp), parameter :: gp2 = 0.57735026918962576451_dp
    real(dp), parameter :: gp3 = 0.77459666924148337704_dp
    real(dp) :: gauss_coordinate(3), gauss_weight(3)
    integer :: ngauss

    type(material_kinematics_t) :: kinematics
    type(material_response_t) :: iso_response
    type(herrmann_constraint_response_t) :: pressure_response
    real(dp) :: N(8), dN_parent(8,2), dN_dX(8,2)
    real(dp) :: x_point(2), Jmap(2,2), det_jac
    real(dp) :: Np(3), F(3,3), P_total(3,3)
    real(dp) :: A_total(3,3,3,3), pressure, weight
    integer :: gx, gy, a, b, i, k, jdir, ldir, q, r
    integer :: row, col, prow, pcol, point_status

    residual = 0.0_dp
    tangent = 0.0_dp
    status = DES_STATUS_OK
    min_j = huge(1.0_dp)
    gauss_coordinate = 0.0_dp
    gauss_weight = 0.0_dp

    if (shear_modulus <= 0.0_dp .or. pressure_compliance < 0.0_dp) then
      status = DES_ERROR_INVALID_PARAMETERS
      return
    end if

    select case (quadrature_order)
    case (Q8_HERRMANN_REDUCED_ORDER)
      ngauss = 2
      gauss_coordinate(1:2) = [-gp2,gp2]
      gauss_weight(1:2) = [1.0_dp,1.0_dp]
    case (Q8_HERRMANN_REFERENCE_ORDER)
      ngauss = 3
      gauss_coordinate = [-gp3,0.0_dp,gp3]
      gauss_weight = [5.0_dp/9.0_dp,8.0_dp/9.0_dp,5.0_dp/9.0_dp]
    case default
      status = DES_ERROR_INVALID_PARAMETERS
      return
    end select

    do gy = 1,ngauss
      do gx = 1,ngauss
        call q8_reference_gradient( &
            X,gauss_coordinate(gx),gauss_coordinate(gy), &
            N,dN_parent,dN_dX,x_point,Jmap,det_jac,point_status)
        if (point_status /= DES_STATUS_OK) then
          status = point_status
          return
        end if

        call herrmann_p1_pressure_basis( &
            gauss_coordinate(gx),gauss_coordinate(gy),Np)
        pressure = dot_product(Np,pressure_coefficients)

        F = 0.0_dp
        F(1,1) = 1.0_dp
        F(2,2) = 1.0_dp
        F(3,3) = 1.0_dp
        do a = 1,8
          do i = 1,2
            do jdir = 1,2
              F(i,jdir) = F(i,jdir) + u(a,i)*dN_dX(a,jdir)
            end do
          end do
        end do

        kinematics%F = F
        call evaluate_neo_hookean_isochoric(kinematics,shear_modulus,iso_response)
        if (.not. iso_response%valid) then
          status = iso_response%status
          return
        end if

        call evaluate_herrmann_pressure_constraint( &
            F,pressure,pressure_compliance,pressure_response)
        if (.not. pressure_response%valid) then
          status = pressure_response%status
          return
        end if

        min_j = min(min_j,iso_response%J)
        weight = det_jac*gauss_weight(gx)*gauss_weight(gy)
        P_total = iso_response%P + pressure_response%P
        A_total = iso_response%tangent + pressure_response%tangent_F

        ! Displacement residual ve K_uu.
        do a = 1,8
          do i = 1,2
            row = 2*(a-1)+i
            do jdir = 1,2
              residual(row) = residual(row) &
                  + P_total(i,jdir)*dN_dX(a,jdir)*weight
            end do

            do b = 1,8
              do k = 1,2
                col = 2*(b-1)+k
                do jdir = 1,2
                  do ldir = 1,2
                    tangent(row,col) = tangent(row,col) &
                        + A_total(i,jdir,k,ldir) &
                        * dN_dX(a,jdir)*dN_dX(b,ldir)*weight
                  end do
                end do
              end do
            end do

            ! K_up: pressure coefficient -> displacement residual.
            do r = 1,3
              pcol = Q8_HERRMANN_U_DOF+r
              do jdir = 1,2
                tangent(row,pcol) = tangent(row,pcol) &
                    + pressure_response%dP_dp(i,jdir) &
                    * dN_dX(a,jdir)*Np(r)*weight
              end do
            end do
          end do
        end do

        ! Pressure residual, K_pu ve K_pp.
        do q = 1,3
          prow = Q8_HERRMANN_U_DOF+q
          residual(prow) = residual(prow) &
              + Np(q)*pressure_response%constraint*weight

          do b = 1,8
            do k = 1,2
              col = 2*(b-1)+k
              do ldir = 1,2
                tangent(prow,col) = tangent(prow,col) &
                    + Np(q)*pressure_response%dconstraint_dF(k,ldir) &
                    * dN_dX(b,ldir)*weight
              end do
            end do
          end do

          do r = 1,3
            pcol = Q8_HERRMANN_U_DOF+r
            tangent(prow,pcol) = tangent(prow,pcol) &
                + Np(q)*pressure_response%dconstraint_dp*Np(r)*weight
          end do
        end do
      end do
    end do
  end subroutine evaluate_q8_plane_strain_herrmann_with_quadrature

end module des_q8_plane_strain_herrmann_neo_hookean
