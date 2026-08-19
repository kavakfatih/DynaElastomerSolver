program test_q8_plane_strain_herrmann_element
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_q8_plane_strain_herrmann_neo_hookean, only : &
      Q8_HERRMANN_U_DOF, Q8_HERRMANN_TOTAL_DOF, &
      evaluate_q8_plane_strain_herrmann_element
  implicit none

  real(dp), parameter :: mu = 2.5_dp
  real(dp), parameter :: compliance = 0.02_dp
  real(dp), parameter :: h = 1.0e-7_dp
  real(dp), parameter :: fd_tol = 5.0e-6_dp
  real(dp) :: X(8,2), u(8,2), pressure_coefficients(3)
  real(dp) :: residual(Q8_HERRMANN_TOTAL_DOF)
  real(dp) :: tangent(Q8_HERRMANN_TOTAL_DOF,Q8_HERRMANN_TOTAL_DOF)
  real(dp) :: fd(Q8_HERRMANN_TOTAL_DOF,Q8_HERRMANN_TOTAL_DOF)
  real(dp) :: residual_plus(Q8_HERRMANN_TOTAL_DOF)
  real(dp) :: residual_minus(Q8_HERRMANN_TOTAL_DOF)
  real(dp) :: tangent_dummy(Q8_HERRMANN_TOTAL_DOF,Q8_HERRMANN_TOTAL_DOF)
  real(dp) :: xlocal(Q8_HERRMANN_TOTAL_DOF), xplus(Q8_HERRMANN_TOTAL_DOF)
  real(dp) :: xminus(Q8_HERRMANN_TOTAL_DOF)
  real(dp) :: u_work(8,2), p_work(3)
  real(dp) :: J_target, tangent_error, symmetry_error, scale
  real(dp) :: min_j, min_j_dummy
  integer :: status, status_plus, status_minus
  integer :: a, i, j

  call set_unit_q8(X)

  ! Homogeneous finite deformation:
  ! F2 = [[1.08, 0.12], [0.04, 0.95]], F33=1.
  do a = 1,8
    u(a,1) = 0.08_dp*X(a,1) + 0.12_dp*X(a,2)
    u(a,2) = 0.04_dp*X(a,1) - 0.05_dp*X(a,2)
  end do
  J_target = 1.08_dp*0.95_dp - 0.12_dp*0.04_dp

  ! Homogeneous J icin constant pressure mode compatibility constraint'i tam saglar.
  pressure_coefficients = 0.0_dp
  pressure_coefficients(1) = -(J_target-1.0_dp)/compliance

  call evaluate_q8_plane_strain_herrmann_element( &
      X,u,pressure_coefficients,mu,compliance, &
      residual,tangent,status,min_j)

  if (status /= DES_STATUS_OK) error stop 'Q8/P1 Herrmann element degerlendirilemedi.'
  if (abs(min_j-J_target) > 2.0e-13_dp) then
    error stop 'Q8/P1 homogeneous deformation J degeri hatali.'
  end if
  if (maxval(abs(residual(Q8_HERRMANN_U_DOF+1:Q8_HERRMANN_TOTAL_DOF))) &
      > 2.0e-12_dp) then
    error stop 'Q8/P1 homogeneous pressure compatibility residual sifir degil.'
  end if

  call pack_local_state(u,pressure_coefficients,xlocal)
  fd = 0.0_dp
  do j = 1,Q8_HERRMANN_TOTAL_DOF
    xplus = xlocal
    xminus = xlocal
    xplus(j) = xplus(j)+h
    xminus(j) = xminus(j)-h

    call unpack_local_state(xplus,u_work,p_work)
    call evaluate_q8_plane_strain_herrmann_element( &
        X,u_work,p_work,mu,compliance,residual_plus,tangent_dummy, &
        status_plus,min_j_dummy)
    if (status_plus /= DES_STATUS_OK) then
      error stop 'Q8/P1 Herrmann pozitif FD perturbation basarisiz.'
    end if

    call unpack_local_state(xminus,u_work,p_work)
    call evaluate_q8_plane_strain_herrmann_element( &
        X,u_work,p_work,mu,compliance,residual_minus,tangent_dummy, &
        status_minus,min_j_dummy)
    if (status_minus /= DES_STATUS_OK) then
      error stop 'Q8/P1 Herrmann negatif FD perturbation basarisiz.'
    end if

    fd(:,j) = (residual_plus-residual_minus)/(2.0_dp*h)
  end do

  scale = max(1.0_dp,maxval(abs(fd)))
  tangent_error = maxval(abs(tangent-fd))/scale
  if (tangent_error > fd_tol) then
    error stop 'Q8/P1 Herrmann 19x19 analytic tangent FD ile uyusmuyor.'
  end if

  symmetry_error = maxval(abs(tangent-transpose(tangent))) &
                 / max(1.0_dp,maxval(abs(tangent)))
  if (symmetry_error > 2.0e-11_dp) then
    error stop 'Q8/P1 Herrmann element tangent symmetry kaybetti.'
  end if

  ! Fully incompressible limit: c_p=0 -> K_pp tam sifir blok olmali.
  pressure_coefficients = [0.6_dp,0.08_dp,-0.05_dp]
  call evaluate_q8_plane_strain_herrmann_element( &
      X,u,pressure_coefficients,mu,0.0_dp, &
      residual,tangent,status,min_j)
  if (status /= DES_STATUS_OK) error stop 'Q8/P1 fully incompressible limit basarisiz.'
  if (maxval(abs(tangent(Q8_HERRMANN_U_DOF+1:Q8_HERRMANN_TOTAL_DOF, &
                         Q8_HERRMANN_U_DOF+1:Q8_HERRMANN_TOTAL_DOF))) &
      > 1.0e-14_dp) then
    error stop 'Q8/P1 fully incompressible K_pp blogu sifir degil.'
  end if

  ! Coupling bloklari variational formulation nedeniyle transpose uyumlu olmali.
  do i = 1,Q8_HERRMANN_U_DOF
    do j = Q8_HERRMANN_U_DOF+1,Q8_HERRMANN_TOTAL_DOF
      if (abs(tangent(i,j)-tangent(j,i)) > 2.0e-11_dp) then
        error stop 'Q8/P1 K_up ve K_pu bloklari transpose uyumlu degil.'
      end if
    end do
  end do

  write(*,'(A,ES14.6)') 'Q8/P1 Herrmann 19x19 tangent FD error = ',tangent_error
  write(*,'(A,ES14.6)') 'Q8/P1 Herrmann tangent symmetry = ',symmetry_error
  write(*,'(A,ES14.6)') 'Q8/P1 homogeneous J = ',J_target
  write(*,'(A)') 'Q8/P1 plane-strain Herrmann element testi BASARILI.'

contains

  subroutine set_unit_q8(coords)
    real(dp), intent(out) :: coords(8,2)

    coords(1,:) = [0.0_dp,0.0_dp]
    coords(2,:) = [1.0_dp,0.0_dp]
    coords(3,:) = [1.0_dp,1.0_dp]
    coords(4,:) = [0.0_dp,1.0_dp]
    coords(5,:) = [0.5_dp,0.0_dp]
    coords(6,:) = [1.0_dp,0.5_dp]
    coords(7,:) = [0.5_dp,1.0_dp]
    coords(8,:) = [0.0_dp,0.5_dp]
  end subroutine set_unit_q8

  subroutine pack_local_state(u_state,p_state,x)
    real(dp), intent(in) :: u_state(8,2),p_state(3)
    real(dp), intent(out) :: x(Q8_HERRMANN_TOTAL_DOF)
    integer :: node

    do node = 1,8
      x(2*node-1) = u_state(node,1)
      x(2*node) = u_state(node,2)
    end do
    x(Q8_HERRMANN_U_DOF+1:Q8_HERRMANN_TOTAL_DOF) = p_state
  end subroutine pack_local_state

  subroutine unpack_local_state(x,u_state,p_state)
    real(dp), intent(in) :: x(Q8_HERRMANN_TOTAL_DOF)
    real(dp), intent(out) :: u_state(8,2),p_state(3)
    integer :: node

    do node = 1,8
      u_state(node,1) = x(2*node-1)
      u_state(node,2) = x(2*node)
    end do
    p_state = x(Q8_HERRMANN_U_DOF+1:Q8_HERRMANN_TOTAL_DOF)
  end subroutine unpack_local_state

end program test_q8_plane_strain_herrmann_element
