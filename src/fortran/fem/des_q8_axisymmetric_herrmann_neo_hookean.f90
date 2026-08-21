module des_q8_axisymmetric_herrmann_neo_hookean
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_PARAMETERS, &
      DES_ERROR_INVALID_ELEMENT_JACOBIAN
  use des_material_types, only : material_kinematics_t, material_response_t
  use des_neo_hookean_isochoric, only : evaluate_neo_hookean_isochoric
  use des_herrmann_pressure_constraint, only : herrmann_constraint_response_t, &
      evaluate_herrmann_pressure_constraint
  use des_q8_herrmann_interpolation, only : herrmann_p1_pressure_basis
  use des_q8_herrmann_geometry, only : q8_reference_gradient
  implicit none
  private

  integer, parameter, public :: Q8_AXISYM_HERRMANN_U_DOF = 16
  integer, parameter, public :: Q8_AXISYM_HERRMANN_P_DOF = 3
  integer, parameter, public :: Q8_AXISYM_HERRMANN_TOTAL_DOF = 19

  public :: evaluate_q8_axisymmetric_herrmann_reduced_element

contains

  pure subroutine evaluate_q8_axisymmetric_herrmann_reduced_element( &
      X, u, pressure_coefficients, shear_modulus, pressure_compliance, &
      residual, tangent, status, min_j)
    ! Q8 axisymmetric finite-strain Herrmann candidate.
    ! Coordinates: X(:,1)=reference radius R, X(:,2)=reference axial Z.
    ! DOF/node: u_r, u_z. Pressure: element P1 [1,xi,eta].
    ! Integration: 2x2 uniform reduced, full 360-degree reference volume.
    real(dp), intent(in) :: X(8,2), u(8,2), pressure_coefficients(3)
    real(dp), intent(in) :: shear_modulus, pressure_compliance
    real(dp), intent(out) :: residual(Q8_AXISYM_HERRMANN_TOTAL_DOF)
    real(dp), intent(out) :: tangent(Q8_AXISYM_HERRMANN_TOTAL_DOF, &
                                      Q8_AXISYM_HERRMANN_TOTAL_DOF)
    integer, intent(out) :: status
    real(dp), intent(out) :: min_j

    real(dp), parameter :: gp = 0.57735026918962576451_dp
    real(dp), parameter :: gauss_coordinate(2) = [-gp,gp]
    real(dp), parameter :: pi = acos(-1.0_dp)

    type(material_kinematics_t) :: kinematics
    type(material_response_t) :: iso_response
    type(herrmann_constraint_response_t) :: pressure_response
    real(dp) :: N(8), dN_parent(8,2), dN_dX(8,2), Np(3)
    real(dp) :: x_point(2), Jmap(2,2), det_jac
    real(dp) :: F(3,3), P_total(3,3), A_total(3,3,3,3)
    real(dp) :: B(3,3,Q8_AXISYM_HERRMANN_U_DOF)
    real(dp) :: pressure, reference_radius, current_radius, weight, radial_tol
    integer :: gx, gy, a, q, r, row, col, i, j, k, l, point_status
    integer :: prow, pcol

    residual = 0.0_dp
    tangent = 0.0_dp
    status = DES_STATUS_OK
    min_j = huge(1.0_dp)

    if (shear_modulus <= 0.0_dp .or. pressure_compliance < 0.0_dp) then
      status = DES_ERROR_INVALID_PARAMETERS
      return
    end if

    do gy = 1,2
      do gx = 1,2
        call q8_reference_gradient( &
            X,gauss_coordinate(gx),gauss_coordinate(gy), &
            N,dN_parent,dN_dX,x_point,Jmap,det_jac,point_status)
        if (point_status /= DES_STATUS_OK) then
          status = point_status
          return
        end if

        reference_radius = x_point(1)
        radial_tol = 100.0_dp*epsilon(1.0_dp)*max(1.0_dp,maxval(abs(X(:,1))))
        if (reference_radius <= radial_tol) then
          status = DES_ERROR_INVALID_ELEMENT_JACOBIAN
          return
        end if

        current_radius = reference_radius + dot_product(N,u(:,1))

        F = 0.0_dp
        F(1,1) = 1.0_dp
        F(2,2) = current_radius/reference_radius
        F(3,3) = 1.0_dp
        do a = 1,8
          F(1,1) = F(1,1) + u(a,1)*dN_dX(a,1)
          F(1,3) = F(1,3) + u(a,1)*dN_dX(a,2)
          F(3,1) = F(3,1) + u(a,2)*dN_dX(a,1)
          F(3,3) = F(3,3) + u(a,2)*dN_dX(a,2)
        end do

        call herrmann_p1_pressure_basis( &
            gauss_coordinate(gx),gauss_coordinate(gy),Np)
        pressure = dot_product(Np,pressure_coefficients)

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
        P_total = iso_response%P + pressure_response%P
        A_total = iso_response%tangent + pressure_response%tangent_F
        weight = 2.0_dp*pi*reference_radius*det_jac

        B = 0.0_dp
        do a = 1,8
          row = 2*(a-1)+1
          B(1,1,row) = dN_dX(a,1)
          B(1,3,row) = dN_dX(a,2)
          B(2,2,row) = N(a)/reference_radius

          row = 2*(a-1)+2
          B(3,1,row) = dN_dX(a,1)
          B(3,3,row) = dN_dX(a,2)
        end do

        do row = 1,Q8_AXISYM_HERRMANN_U_DOF
          residual(row) = residual(row) + sum(P_total*B(:,:,row))*weight

          do col = 1,Q8_AXISYM_HERRMANN_U_DOF
            do i = 1,3
              do j = 1,3
                do k = 1,3
                  do l = 1,3
                    tangent(row,col) = tangent(row,col) + &
                        B(i,j,row)*A_total(i,j,k,l)*B(k,l,col)*weight
                  end do
                end do
              end do
            end do
          end do

          do r = 1,3
            pcol = Q8_AXISYM_HERRMANN_U_DOF+r
            tangent(row,pcol) = tangent(row,pcol) + &
                sum(B(:,:,row)*pressure_response%dP_dp)*Np(r)*weight
          end do
        end do

        do q = 1,3
          prow = Q8_AXISYM_HERRMANN_U_DOF+q
          residual(prow) = residual(prow) + &
              Np(q)*pressure_response%constraint*weight

          do col = 1,Q8_AXISYM_HERRMANN_U_DOF
            tangent(prow,col) = tangent(prow,col) + &
                Np(q)*sum(pressure_response%dconstraint_dF*B(:,:,col))*weight
          end do

          do r = 1,3
            pcol = Q8_AXISYM_HERRMANN_U_DOF+r
            tangent(prow,pcol) = tangent(prow,pcol) + &
                Np(q)*pressure_response%dconstraint_dp*Np(r)*weight
          end do
        end do
      end do
    end do
  end subroutine evaluate_q8_axisymmetric_herrmann_reduced_element

end module des_q8_axisymmetric_herrmann_neo_hookean
