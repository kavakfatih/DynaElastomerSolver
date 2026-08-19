module des_q9_plane_strain_herrmann_neo_hookean
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_PARAMETERS
  use des_material_types, only : material_kinematics_t, material_response_t
  use des_neo_hookean_isochoric, only : evaluate_neo_hookean_isochoric
  use des_herrmann_pressure_constraint, only : herrmann_constraint_response_t, &
                                                evaluate_herrmann_pressure_constraint
  use des_herrmann_pressure_interpolation, only : herrmann_p1_pressure_basis
  use des_q9_herrmann_geometry, only : q9_reference_gradient
  implicit none
  private

  integer, parameter, public :: Q9_HERRMANN_U_DOF = 18
  integer, parameter, public :: Q9_HERRMANN_P_DOF = 3
  integer, parameter, public :: Q9_HERRMANN_TOTAL_DOF = 21
  integer, parameter, public :: Q9_HERRMANN_QUADRATURE_2X2 = 2
  integer, parameter, public :: Q9_HERRMANN_QUADRATURE_3X3 = 3
  integer, parameter, public :: Q9_HERRMANN_QUADRATURE_4X4 = 4

  public :: evaluate_q9_plane_strain_herrmann_element
  public :: evaluate_q9_plane_strain_herrmann_element_with_quadrature

contains

  pure subroutine evaluate_q9_plane_strain_herrmann_element( &
      X, u, pressure_coefficients, shear_modulus, pressure_compliance, &
      residual, tangent, status, min_j)
    ! Varsayilan Q9/P1 Herrmann plane-strain element degerlendirmesi.
    !
    ! Production adayi 3x3 Gauss ile korunur. 2x2 ve 4x4 secenekleri ayni
    ! formulation operatorunun under/full/higher-order integration duyarliligini
    ! olcmek icin explicit diagnostic API uzerinden kullanilir. Quadrature karari
    ! external mixed reference ve mesh-convergence kaniti olmadan degistirilmez.
    real(dp), intent(in) :: X(9,2), u(9,2), pressure_coefficients(3)
    real(dp), intent(in) :: shear_modulus, pressure_compliance
    real(dp), intent(out) :: residual(Q9_HERRMANN_TOTAL_DOF)
    real(dp), intent(out) :: tangent(Q9_HERRMANN_TOTAL_DOF,Q9_HERRMANN_TOTAL_DOF)
    integer, intent(out) :: status
    real(dp), intent(out) :: min_j

    call evaluate_q9_plane_strain_herrmann_element_with_quadrature( &
        X,u,pressure_coefficients,shear_modulus,pressure_compliance, &
        Q9_HERRMANN_QUADRATURE_3X3,residual,tangent,status,min_j)
  end subroutine evaluate_q9_plane_strain_herrmann_element

  pure subroutine evaluate_q9_plane_strain_herrmann_element_with_quadrature( &
      X, u, pressure_coefficients, shear_modulus, pressure_compliance, &
      quadrature_order, residual, tangent, status, min_j)
    ! Stability-first Herrmann/mixed u-p plane-strain element adayi.
    !
    ! Displacement : Q9 biquadratic Lagrange, 18 DOF
    ! Pressure     : element-internal P1 modal alan [1, xi, eta], 3 DOF
    ! Local system : 21 x 21
    ! Integration  : secilebilir 2x2, 3x3 veya 4x4 Gauss
    !
    ! 4x4 secenegi production default degildir. Bagimsiz FEniCSx mixed referans
    ! ile gorulen farkin quadrature kaynakli olup olmadigini ayirmak icin eklenen
    ! higher-order diagnostic'tir.
    real(dp), intent(in) :: X(9,2), u(9,2), pressure_coefficients(3)
    real(dp), intent(in) :: shear_modulus, pressure_compliance
    integer, intent(in) :: quadrature_order
    real(dp), intent(out) :: residual(Q9_HERRMANN_TOTAL_DOF)
    real(dp), intent(out) :: tangent(Q9_HERRMANN_TOTAL_DOF,Q9_HERRMANN_TOTAL_DOF)
    integer, intent(out) :: status
    real(dp), intent(out) :: min_j

    type(material_kinematics_t) :: kinematics
    type(material_response_t) :: iso_response
    type(herrmann_constraint_response_t) :: pressure_response
    real(dp) :: gauss_coordinate(4), gauss_weight(4)
    real(dp) :: N(9), dN_parent(9,2), dN_dX(9,2)
    real(dp) :: x_point(2), Jmap(2,2), det_jac
    real(dp) :: Np(3), F(3,3), P_total(3,3)
    real(dp) :: A_total(3,3,3,3), pressure, weight
    integer :: n_gauss
    integer :: gx, gy, a, b, i, k, jdir, ldir, q, r
    integer :: row, col, prow, pcol, point_status

    residual = 0.0_dp
    tangent = 0.0_dp
    status = DES_STATUS_OK
    min_j = huge(1.0_dp)

    if (shear_modulus <= 0.0_dp .or. pressure_compliance < 0.0_dp) then
      status = DES_ERROR_INVALID_PARAMETERS
      return
    end if

    call set_gauss_rule(quadrature_order,n_gauss,gauss_coordinate,gauss_weight,status)
    if (status /= DES_STATUS_OK) return

    do gy = 1,n_gauss
      do gx = 1,n_gauss
        call q9_reference_gradient( &
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
        do a = 1,9
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

        do a = 1,9
          do i = 1,2
            row = 2*(a-1)+i
            do jdir = 1,2
              residual(row) = residual(row) &
                  + P_total(i,jdir)*dN_dX(a,jdir)*weight
            end do

            do b = 1,9
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

            do r = 1,3
              pcol = Q9_HERRMANN_U_DOF+r
              do jdir = 1,2
                tangent(row,pcol) = tangent(row,pcol) &
                    + pressure_response%dP_dp(i,jdir) &
                    * dN_dX(a,jdir)*Np(r)*weight
              end do
            end do
          end do
        end do

        do q = 1,3
          prow = Q9_HERRMANN_U_DOF+q
          residual(prow) = residual(prow) &
              + Np(q)*pressure_response%constraint*weight

          do b = 1,9
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
            pcol = Q9_HERRMANN_U_DOF+r
            tangent(prow,pcol) = tangent(prow,pcol) &
                + Np(q)*pressure_response%dconstraint_dp*Np(r)*weight
          end do
        end do
      end do
    end do
  end subroutine evaluate_q9_plane_strain_herrmann_element_with_quadrature

  pure subroutine set_gauss_rule(order,n_gauss,coordinate,weight,status)
    integer, intent(in) :: order
    integer, intent(out) :: n_gauss,status
    real(dp), intent(out) :: coordinate(4),weight(4)
    real(dp), parameter :: gp3 = 0.77459666924148337704_dp
    real(dp), parameter :: gp2 = 0.57735026918962576451_dp
    real(dp), parameter :: gp4_outer = 0.86113631159405257522_dp
    real(dp), parameter :: gp4_inner = 0.33998104358485626480_dp
    real(dp), parameter :: gw4_outer = 0.34785484513745385737_dp
    real(dp), parameter :: gw4_inner = 0.65214515486254614263_dp

    coordinate = 0.0_dp
    weight = 0.0_dp
    status = DES_STATUS_OK

    select case (order)
    case (Q9_HERRMANN_QUADRATURE_2X2)
      n_gauss = 2
      coordinate(1:2) = [-gp2,gp2]
      weight(1:2) = [1.0_dp,1.0_dp]
    case (Q9_HERRMANN_QUADRATURE_3X3)
      n_gauss = 3
      coordinate(1:3) = [-gp3,0.0_dp,gp3]
      weight(1:3) = [5.0_dp/9.0_dp,8.0_dp/9.0_dp,5.0_dp/9.0_dp]
    case (Q9_HERRMANN_QUADRATURE_4X4)
      n_gauss = 4
      coordinate = [-gp4_outer,-gp4_inner,gp4_inner,gp4_outer]
      weight = [gw4_outer,gw4_inner,gw4_inner,gw4_outer]
    case default
      n_gauss = 0
      status = DES_ERROR_INVALID_PARAMETERS
    end select
  end subroutine set_gauss_rule

end module des_q9_plane_strain_herrmann_neo_hookean
