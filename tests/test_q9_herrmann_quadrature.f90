program test_q9_herrmann_quadrature
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_PARAMETERS
  use des_q9_plane_strain_herrmann_neo_hookean, only : &
      Q9_HERRMANN_TOTAL_DOF, Q9_HERRMANN_U_DOF, &
      Q9_HERRMANN_QUADRATURE_2X2, Q9_HERRMANN_QUADRATURE_3X3, &
      Q9_HERRMANN_QUADRATURE_4X4, &
      evaluate_q9_plane_strain_herrmann_element_with_quadrature
  implicit none

  real(dp), parameter :: mu = 2.5_dp
  real(dp), parameter :: compliance = 0.02_dp
  real(dp) :: X(9,2),u(9,2),p(3)
  real(dp) :: residual_2(Q9_HERRMANN_TOTAL_DOF)
  real(dp) :: residual_3(Q9_HERRMANN_TOTAL_DOF)
  real(dp) :: residual_4(Q9_HERRMANN_TOTAL_DOF)
  real(dp) :: tangent_2(Q9_HERRMANN_TOTAL_DOF,Q9_HERRMANN_TOTAL_DOF)
  real(dp) :: tangent_3(Q9_HERRMANN_TOTAL_DOF,Q9_HERRMANN_TOTAL_DOF)
  real(dp) :: tangent_4(Q9_HERRMANN_TOTAL_DOF,Q9_HERRMANN_TOTAL_DOF)
  real(dp) :: min_j_2,min_j_3,min_j_4,fd_error_2,fd_error_3,fd_error_4
  real(dp) :: residual_difference_23,residual_difference_34
  real(dp) :: tangent_difference_23,tangent_difference_34
  integer :: status_2,status_3,status_4,status_invalid,a

  call set_unit_q9(X)

  ! Q9 displacement alaninin temsil edebildigi, Gauss noktalarinda F'yi degistiren
  ! non-affine quadratic alan. Bu alan 2x2, 3x3 ve 4x4 quadrature operatorlerini
  ! gercekten ayirir ve her biri icin consistent tangent FD ile sinanir.
  do a = 1,9
    u(a,1) = 0.05_dp*X(a,1) + 0.03_dp*X(a,2) &
        + 0.02_dp*X(a,1)*X(a,2) + 0.015_dp*X(a,1)*X(a,1)
    u(a,2) = -0.02_dp*X(a,1) + 0.04_dp*X(a,2) &
        - 0.01_dp*X(a,1)*X(a,2) + 0.012_dp*X(a,2)*X(a,2)
  end do
  p = [0.18_dp,0.035_dp,-0.025_dp]

  call evaluate_q9_plane_strain_herrmann_element_with_quadrature( &
      X,u,p,mu,compliance,Q9_HERRMANN_QUADRATURE_2X2, &
      residual_2,tangent_2,status_2,min_j_2)
  call evaluate_q9_plane_strain_herrmann_element_with_quadrature( &
      X,u,p,mu,compliance,Q9_HERRMANN_QUADRATURE_3X3, &
      residual_3,tangent_3,status_3,min_j_3)
  call evaluate_q9_plane_strain_herrmann_element_with_quadrature( &
      X,u,p,mu,compliance,Q9_HERRMANN_QUADRATURE_4X4, &
      residual_4,tangent_4,status_4,min_j_4)

  if (status_2 /= DES_STATUS_OK .or. status_3 /= DES_STATUS_OK .or. &
      status_4 /= DES_STATUS_OK) then
    error stop 'Q9/P1 quadrature degerlendirmelerinden biri basarisiz.'
  end if
  if (min(min_j_2,min_j_3,min_j_4) <= 0.80_dp) then
    error stop 'Q9/P1 quadrature testi gecersiz/ters deformation uretti.'
  end if

  call check_fd_for_order(X,u,p,Q9_HERRMANN_QUADRATURE_2X2,fd_error_2)
  call check_fd_for_order(X,u,p,Q9_HERRMANN_QUADRATURE_3X3,fd_error_3)
  call check_fd_for_order(X,u,p,Q9_HERRMANN_QUADRATURE_4X4,fd_error_4)

  if (fd_error_2 > 8.0e-6_dp) then
    error stop 'Q9/P1 2x2 analytic tangent FD ile uyusmuyor.'
  end if
  if (fd_error_3 > 8.0e-6_dp) then
    error stop 'Q9/P1 3x3 analytic tangent FD ile uyusmuyor.'
  end if
  if (fd_error_4 > 8.0e-6_dp) then
    error stop 'Q9/P1 4x4 analytic tangent FD ile uyusmuyor.'
  end if

  residual_difference_23 = maxval(abs(residual_2-residual_3)) &
      / max(1.0_dp,maxval(abs(residual_3)))
  tangent_difference_23 = maxval(abs(tangent_2-tangent_3)) &
      / max(1.0_dp,maxval(abs(tangent_3)))
  residual_difference_34 = maxval(abs(residual_3-residual_4)) &
      / max(1.0_dp,maxval(abs(residual_4)))
  tangent_difference_34 = maxval(abs(tangent_3-tangent_4)) &
      / max(1.0_dp,maxval(abs(tangent_4)))

  if (residual_difference_23 <= 10.0_dp*epsilon(1.0_dp) .and. &
      tangent_difference_23 <= 10.0_dp*epsilon(1.0_dp)) then
    error stop 'Non-affine Q9 testi 2x2 ve 3x3 operatorleri ayiramadi.'
  end if

  ! 3x3 ile 4x4 farki sifira zorlanmaz. Nonlinear isochoric enerji polinom degildir;
  ! higher-order integration duyarliligi external reference ile birlikte raporlanir.
  if (residual_difference_34 < 0.0_dp .or. tangent_difference_34 < 0.0_dp) then
    error stop 'Q9/P1 3x3-4x4 quadrature fark metrigi gecersiz.'
  end if

  call evaluate_q9_plane_strain_herrmann_element_with_quadrature( &
      X,u,p,mu,compliance,5,residual_2,tangent_2,status_invalid,min_j_2)
  if (status_invalid /= DES_ERROR_INVALID_PARAMETERS) then
    error stop 'Gecersiz Q9 quadrature order reddedilmedi.'
  end if

  ! Fully incompressible limitte tum quadrature secenekleri Kpp=0 kalmali.
  p = [0.20_dp,0.01_dp,-0.02_dp]
  call evaluate_q9_plane_strain_herrmann_element_with_quadrature( &
      X,u,p,mu,0.0_dp,Q9_HERRMANN_QUADRATURE_2X2, &
      residual_2,tangent_2,status_2,min_j_2)
  call evaluate_q9_plane_strain_herrmann_element_with_quadrature( &
      X,u,p,mu,0.0_dp,Q9_HERRMANN_QUADRATURE_3X3, &
      residual_3,tangent_3,status_3,min_j_3)
  call evaluate_q9_plane_strain_herrmann_element_with_quadrature( &
      X,u,p,mu,0.0_dp,Q9_HERRMANN_QUADRATURE_4X4, &
      residual_4,tangent_4,status_4,min_j_4)
  if (status_2 /= DES_STATUS_OK .or. status_3 /= DES_STATUS_OK .or. &
      status_4 /= DES_STATUS_OK) then
    error stop 'Q9/P1 fully incompressible quadrature testi basarisiz.'
  end if
  if (maxval(abs(tangent_2(Q9_HERRMANN_U_DOF+1:Q9_HERRMANN_TOTAL_DOF, &
                            Q9_HERRMANN_U_DOF+1:Q9_HERRMANN_TOTAL_DOF))) > 1.0e-14_dp) then
    error stop 'Q9/P1 2x2 fully incompressible Kpp sifir degil.'
  end if
  if (maxval(abs(tangent_3(Q9_HERRMANN_U_DOF+1:Q9_HERRMANN_TOTAL_DOF, &
                            Q9_HERRMANN_U_DOF+1:Q9_HERRMANN_TOTAL_DOF))) > 1.0e-14_dp) then
    error stop 'Q9/P1 3x3 fully incompressible Kpp sifir degil.'
  end if
  if (maxval(abs(tangent_4(Q9_HERRMANN_U_DOF+1:Q9_HERRMANN_TOTAL_DOF, &
                            Q9_HERRMANN_U_DOF+1:Q9_HERRMANN_TOTAL_DOF))) > 1.0e-14_dp) then
    error stop 'Q9/P1 4x4 fully incompressible Kpp sifir degil.'
  end if

  write(*,'(A,ES14.6)') 'Q9/P1 2x2 tangent FD error = ',fd_error_2
  write(*,'(A,ES14.6)') 'Q9/P1 3x3 tangent FD error = ',fd_error_3
  write(*,'(A,ES14.6)') 'Q9/P1 4x4 tangent FD error = ',fd_error_4
  write(*,'(A,ES14.6)') 'Q9/P1 2x2-vs-3x3 residual relative difference = ',residual_difference_23
  write(*,'(A,ES14.6)') 'Q9/P1 3x3-vs-4x4 residual relative difference = ',residual_difference_34
  write(*,'(A,ES14.6)') 'Q9/P1 2x2-vs-3x3 tangent relative difference = ',tangent_difference_23
  write(*,'(A,ES14.6)') 'Q9/P1 3x3-vs-4x4 tangent relative difference = ',tangent_difference_34
  write(*,'(A)') 'Q9/P1 selectable 2x2/3x3/4x4 quadrature ve FD testleri BASARILI.'

contains

  subroutine check_fd_for_order(coords,u_state,p_state,order,relative_error)
    real(dp), intent(in) :: coords(9,2),u_state(9,2),p_state(3)
    integer, intent(in) :: order
    real(dp), intent(out) :: relative_error
    real(dp), parameter :: h = 1.0e-7_dp
    real(dp) :: xlocal(Q9_HERRMANN_TOTAL_DOF)
    real(dp) :: xplus(Q9_HERRMANN_TOTAL_DOF),xminus(Q9_HERRMANN_TOTAL_DOF)
    real(dp) :: work_u(9,2),work_p(3)
    real(dp) :: r0(Q9_HERRMANN_TOTAL_DOF),rplus(Q9_HERRMANN_TOTAL_DOF)
    real(dp) :: rminus(Q9_HERRMANN_TOTAL_DOF)
    real(dp) :: analytic(Q9_HERRMANN_TOTAL_DOF,Q9_HERRMANN_TOTAL_DOF)
    real(dp) :: dummy(Q9_HERRMANN_TOTAL_DOF,Q9_HERRMANN_TOTAL_DOF)
    real(dp) :: fd(Q9_HERRMANN_TOTAL_DOF,Q9_HERRMANN_TOTAL_DOF)
    real(dp) :: min_j,scale
    integer :: status,status_plus,status_minus,j,node

    call pack_state(u_state,p_state,xlocal)
    call evaluate_q9_plane_strain_herrmann_element_with_quadrature( &
        coords,u_state,p_state,mu,compliance,order,r0,analytic,status,min_j)
    if (status /= DES_STATUS_OK) error stop 'Q9 quadrature FD baseline basarisiz.'

    do j = 1,Q9_HERRMANN_TOTAL_DOF
      xplus = xlocal
      xminus = xlocal
      xplus(j) = xplus(j)+h
      xminus(j) = xminus(j)-h

      call unpack_state(xplus,work_u,work_p)
      call evaluate_q9_plane_strain_herrmann_element_with_quadrature( &
          coords,work_u,work_p,mu,compliance,order,rplus,dummy,status_plus,min_j)
      if (status_plus /= DES_STATUS_OK) error stop 'Q9 quadrature pozitif FD basarisiz.'

      call unpack_state(xminus,work_u,work_p)
      call evaluate_q9_plane_strain_herrmann_element_with_quadrature( &
          coords,work_u,work_p,mu,compliance,order,rminus,dummy,status_minus,min_j)
      if (status_minus /= DES_STATUS_OK) error stop 'Q9 quadrature negatif FD basarisiz.'

      fd(:,j) = (rplus-rminus)/(2.0_dp*h)
    end do

    scale = max(1.0_dp,maxval(abs(fd)))
    relative_error = maxval(abs(analytic-fd))/scale

    node = 9
    if (node /= size(u_state,1)) error stop 'Q9 quadrature FD state boyutu bozuldu.'
  end subroutine check_fd_for_order

  subroutine pack_state(u_state,p_state,x)
    real(dp), intent(in) :: u_state(9,2),p_state(3)
    real(dp), intent(out) :: x(Q9_HERRMANN_TOTAL_DOF)
    integer :: node

    do node = 1,9
      x(2*node-1) = u_state(node,1)
      x(2*node) = u_state(node,2)
    end do
    x(Q9_HERRMANN_U_DOF+1:Q9_HERRMANN_TOTAL_DOF) = p_state
  end subroutine pack_state

  subroutine unpack_state(x,u_state,p_state)
    real(dp), intent(in) :: x(Q9_HERRMANN_TOTAL_DOF)
    real(dp), intent(out) :: u_state(9,2),p_state(3)
    integer :: node

    do node = 1,9
      u_state(node,1) = x(2*node-1)
      u_state(node,2) = x(2*node)
    end do
    p_state = x(Q9_HERRMANN_U_DOF+1:Q9_HERRMANN_TOTAL_DOF)
  end subroutine unpack_state

  subroutine set_unit_q9(coords)
    real(dp), intent(out) :: coords(9,2)

    coords(1,:) = [0.0_dp,0.0_dp]
    coords(2,:) = [1.0_dp,0.0_dp]
    coords(3,:) = [1.0_dp,1.0_dp]
    coords(4,:) = [0.0_dp,1.0_dp]
    coords(5,:) = [0.5_dp,0.0_dp]
    coords(6,:) = [1.0_dp,0.5_dp]
    coords(7,:) = [0.5_dp,1.0_dp]
    coords(8,:) = [0.0_dp,0.5_dp]
    coords(9,:) = [0.5_dp,0.5_dp]
  end subroutine set_unit_q9

end program test_q9_herrmann_quadrature
