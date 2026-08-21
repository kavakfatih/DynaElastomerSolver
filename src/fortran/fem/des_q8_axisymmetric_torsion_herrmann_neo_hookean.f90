module des_q8_axisymmetric_torsion_herrmann_neo_hookean
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

  integer, parameter, public :: Q8_TORSION_HERRMANN_U_DOF = 24
  integer, parameter, public :: Q8_TORSION_HERRMANN_P_DOF = 3
  integer, parameter, public :: Q8_TORSION_HERRMANN_TOTAL_DOF = 27

  public :: evaluate_q8_axisymmetric_torsion_herrmann_reduced_element

contains

  pure subroutine evaluate_q8_axisymmetric_torsion_herrmann_reduced_element( &
      X, u, pressure_coefficients, shear_modulus, pressure_compliance, &
      residual, tangent, status, min_j)
    ! Q8 axisymmetric-with-torsion finite-strain Herrmann candidate.
    !
    ! X(:,1)=reference radius R, X(:,2)=reference axial Z.
    ! u(:,1)=u_r, u(:,2)=u_z, u(:,3)=ROTY/twist angle phi [rad].
    ! Deformation map: r=R+u_r, theta=Theta+phi(R,Z), z=Z+u_z.
    ! F, orthonormal cylindrical bases [r,theta,z] <- [R,Theta,Z]:
    !   [ r_R       0      r_Z ]
    !   [ r*phi_R   r/R    r*phi_Z ]
    !   [ z_R       0      z_Z ]
    !
    ! ROTY conjugate residual has torque units because phi is dimensionless.
    ! Reference-volume integration is full 360 degrees: 2*pi*R*dR*dZ.
    real(dp), intent(in) :: X(8,2), u(8,3), pressure_coefficients(3)
    real(dp), intent(in) :: shear_modulus, pressure_compliance
    real(dp), intent(out) :: residual(Q8_TORSION_HERRMANN_TOTAL_DOF)
    real(dp), intent(out) :: tangent(Q8_TORSION_HERRMANN_TOTAL_DOF, &
                                      Q8_TORSION_HERRMANN_TOTAL_DOF)
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
    real(dp) :: B(3,3,Q8_TORSION_HERRMANN_U_DOF)
    real(dp) :: pressure, reference_radius, current_radius, weight, radial_tol
    real(dp) :: phi_R, phi_Z, geometric_term
    integer :: gx, gy, a, b, q, r, row, col, i, j, k, l, point_status
    integer :: ur_row, uz_row, phi_row, ur_col, phi_col, prow, pcol

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
        phi_R = dot_product(u(:,3),dN_dX(:,1))
        phi_Z = dot_product(u(:,3),dN_dX(:,2))

        F = 0.0_dp
        F(1,1) = 1.0_dp
        F(2,1) = current_radius*phi_R
        F(2,2) = current_radius/reference_radius
        F(2,3) = current_radius*phi_Z
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
          ur_row = 3*(a-1)+1
          uz_row = 3*(a-1)+2
          phi_row = 3*(a-1)+3

          B(1,1,ur_row) = dN_dX(a,1)
          B(1,3,ur_row) = dN_dX(a,2)
          B(2,1,ur_row) = N(a)*phi_R
          B(2,2,ur_row) = N(a)/reference_radius
          B(2,3,ur_row) = N(a)*phi_Z

          B(3,1,uz_row) = dN_dX(a,1)
          B(3,3,uz_row) = dN_dX(a,2)

          B(2,1,phi_row) = current_radius*dN_dX(a,1)
          B(2,3,phi_row) = current_radius*dN_dX(a,2)
        end do

        do row = 1,Q8_TORSION_HERRMANN_U_DOF
          residual(row) = residual(row) + sum(P_total*B(:,:,row))*weight

          do col = 1,Q8_TORSION_HERRMANN_U_DOF
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
            pcol = Q8_TORSION_HERRMANN_U_DOF+r
            tangent(row,pcol) = tangent(row,pcol) + &
                sum(B(:,:,row)*pressure_response%dP_dp)*Np(r)*weight
          end do
        end do

        ! F_thetaR=r*phi_R ve F_thetaZ=r*phi_Z nedeniyle B matrisi state'e
        ! bağlıdır. Bu ikinci türev terimleri geometric part'ın eksik kalmasını
        ! engeller ve ROTY <-> radial tangent simetrisini korur.
        do a = 1,8
          ur_row = 3*(a-1)+1
          phi_row = 3*(a-1)+3
          do b = 1,8
            ur_col = 3*(b-1)+1
            phi_col = 3*(b-1)+3

            geometric_term = P_total(2,1)*N(a)*dN_dX(b,1) + &
                             P_total(2,3)*N(a)*dN_dX(b,2)
            tangent(ur_row,phi_col) = tangent(ur_row,phi_col) + &
                geometric_term*weight

            geometric_term = P_total(2,1)*N(b)*dN_dX(a,1) + &
                             P_total(2,3)*N(b)*dN_dX(a,2)
            tangent(phi_row,ur_col) = tangent(phi_row,ur_col) + &
                geometric_term*weight
          end do
        end do

        do q = 1,3
          prow = Q8_TORSION_HERRMANN_U_DOF+q
          residual(prow) = residual(prow) + &
              Np(q)*pressure_response%constraint*weight

          do col = 1,Q8_TORSION_HERRMANN_U_DOF
            tangent(prow,col) = tangent(prow,col) + &
                Np(q)*sum(pressure_response%dconstraint_dF*B(:,:,col))*weight
          end do

          do r = 1,3
            pcol = Q8_TORSION_HERRMANN_U_DOF+r
            tangent(prow,pcol) = tangent(prow,pcol) + &
                Np(q)*pressure_response%dconstraint_dp*Np(r)*weight
          end do
        end do
      end do
    end do
  end subroutine evaluate_q8_axisymmetric_torsion_herrmann_reduced_element

end module des_q8_axisymmetric_torsion_herrmann_neo_hookean
