program test_q9_plane_strain_herrmann_element
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_q9_plane_strain_herrmann_neo_hookean, only : &
      Q9_HERRMANN_U_DOF, Q9_HERRMANN_TOTAL_DOF, &
      Q9_HERRMANN_QUADRATURE_2X2, Q9_HERRMANN_QUADRATURE_3X3, &
      Q9_HERRMANN_QUADRATURE_4X4, q9_herrmann_reference_cache_t, &
      evaluate_q9_plane_strain_herrmann_element, &
      evaluate_q9_plane_strain_herrmann_element_with_quadrature, &
      initialize_q9_herrmann_reference_cache, &
      evaluate_q9_plane_strain_herrmann_element_with_cache
  implicit none

  real(dp), parameter :: mu = 2.5_dp
  real(dp), parameter :: compliance = 0.02_dp
  real(dp), parameter :: h = 1.0e-7_dp
  real(dp), parameter :: fd_tol = 5.0e-6_dp
  real(dp), parameter :: cache_tol = 1.0e-13_dp
  integer, parameter :: quadrature_orders(3) = [ &
      Q9_HERRMANN_QUADRATURE_2X2, &
      Q9_HERRMANN_QUADRATURE_3X3, &
      Q9_HERRMANN_QUADRATURE_4X4]
  real(dp) :: X(9,2), u(9,2), pressure_coefficients(3)
  real(dp) :: residual(Q9_HERRMANN_TOTAL_DOF)
  real(dp) :: tangent(Q9_HERRMANN_TOTAL_DOF,Q9_HERRMANN_TOTAL_DOF)
  real(dp) :: fd(Q9_HERRMANN_TOTAL_DOF,Q9_HERRMANN_TOTAL_DOF)
  real(dp) :: residual_plus(Q9_HERRMANN_TOTAL_DOF)
  real(dp) :: residual_minus(Q9_HERRMANN_TOTAL_DOF)
  real(dp) :: tangent_dummy(Q9_HERRMANN_TOTAL_DOF,Q9_HERRMANN_TOTAL_DOF)
  real(dp) :: xlocal(Q9_HERRMANN_TOTAL_DOF), xplus(Q9_HERRMANN_TOTAL_DOF)
  real(dp) :: xminus(Q9_HERRMANN_TOTAL_DOF)
  real(dp) :: u_work(9,2), p_work(3)
  real(dp) :: X_cache(9,2), u_cache(9,2), p_cache(3)
  real(dp) :: residual_direct(Q9_HERRMANN_TOTAL_DOF)
  real(dp) :: residual_cached(Q9_HERRMANN_TOTAL_DOF)
  real(dp) :: tangent_direct(Q9_HERRMANN_TOTAL_DOF,Q9_HERRMANN_TOTAL_DOF)
  real(dp) :: tangent_cached(Q9_HERRMANN_TOTAL_DOF,Q9_HERRMANN_TOTAL_DOF)
  real(dp) :: J_target, tangent_error, symmetry_error, scale
  real(dp) :: min_j, min_j_dummy, min_j_direct, min_j_cached
  real(dp) :: cache_residual_error, cache_tangent_error, cache_j_error
  integer :: status, status_plus, status_minus, cache_status, direct_status
  integer :: cached_status, quadrature_order
  integer :: a, i, j
  type(q9_herrmann_reference_cache_t) :: reference_cache

  call set_unit_q9(X)

  ! Homogeneous finite deformation:
  ! F2 = [[1.08, 0.12], [0.04, 0.95]], F33=1.
  do a = 1,9
    u(a,1) = 0.08_dp*X(a,1) + 0.12_dp*X(a,2)
    u(a,2) = 0.04_dp*X(a,1) - 0.05_dp*X(a,2)
  end do
  J_target = 1.08_dp*0.95_dp - 0.12_dp*0.04_dp

  pressure_coefficients = 0.0_dp
  pressure_coefficients(1) = -(J_target-1.0_dp)/compliance

  call evaluate_q9_plane_strain_herrmann_element( &
      X,u,pressure_coefficients,mu,compliance, &
      residual,tangent,status,min_j)

  if (status /= DES_STATUS_OK) error stop 'Q9/P1 Herrmann element degerlendirilemedi.'
  if (abs(min_j-J_target) > 3.0e-13_dp) then
    error stop 'Q9/P1 homogeneous deformation J degeri hatali.'
  end if
  if (maxval(abs(residual(Q9_HERRMANN_U_DOF+1:Q9_HERRMANN_TOTAL_DOF))) &
      > 3.0e-12_dp) then
    error stop 'Q9/P1 homogeneous pressure compatibility residual sifir degil.'
  end if

  call pack_local_state(u,pressure_coefficients,xlocal)
  fd = 0.0_dp
  do j = 1,Q9_HERRMANN_TOTAL_DOF
    xplus = xlocal
    xminus = xlocal
    xplus(j) = xplus(j)+h
    xminus(j) = xminus(j)-h

    call unpack_local_state(xplus,u_work,p_work)
    call evaluate_q9_plane_strain_herrmann_element( &
        X,u_work,p_work,mu,compliance,residual_plus,tangent_dummy, &
        status_plus,min_j_dummy)
    if (status_plus /= DES_STATUS_OK) then
      error stop 'Q9/P1 Herrmann pozitif FD perturbation basarisiz.'
    end if

    call unpack_local_state(xminus,u_work,p_work)
    call evaluate_q9_plane_strain_herrmann_element( &
        X,u_work,p_work,mu,compliance,residual_minus,tangent_dummy, &
        status_minus,min_j_dummy)
    if (status_minus /= DES_STATUS_OK) then
      error stop 'Q9/P1 Herrmann negatif FD perturbation basarisiz.'
    end if

    fd(:,j) = (residual_plus-residual_minus)/(2.0_dp*h)
  end do

  scale = max(1.0_dp,maxval(abs(fd)))
  tangent_error = maxval(abs(tangent-fd))/scale
  if (tangent_error > fd_tol) then
    error stop 'Q9/P1 Herrmann 21x21 analytic tangent FD ile uyusmuyor.'
  end if

  symmetry_error = maxval(abs(tangent-transpose(tangent))) &
                 / max(1.0_dp,maxval(abs(tangent)))
  if (symmetry_error > 2.0e-11_dp) then
    error stop 'Q9/P1 Herrmann element tangent symmetry kaybetti.'
  end if

  pressure_coefficients = [0.6_dp,0.08_dp,-0.05_dp]
  call evaluate_q9_plane_strain_herrmann_element( &
      X,u,pressure_coefficients,mu,0.0_dp, &
      residual,tangent,status,min_j)
  if (status /= DES_STATUS_OK) error stop 'Q9/P1 fully incompressible limit basarisiz.'
  if (maxval(abs(tangent(Q9_HERRMANN_U_DOF+1:Q9_HERRMANN_TOTAL_DOF, &
                         Q9_HERRMANN_U_DOF+1:Q9_HERRMANN_TOTAL_DOF))) &
      > 1.0e-14_dp) then
    error stop 'Q9/P1 fully incompressible K_pp blogu sifir degil.'
  end if

  do i = 1,Q9_HERRMANN_U_DOF
    do j = Q9_HERRMANN_U_DOF+1,Q9_HERRMANN_TOTAL_DOF
      if (abs(tangent(i,j)-tangent(j,i)) > 2.0e-11_dp) then
        error stop 'Q9/P1 K_up ve K_pu bloklari transpose uyumlu degil.'
      end if
    end do
  end do

  ! B9.4 reference-cache parity: direct geometri yolu ile cached yol ayni
  ! distorted Q9 elementte 2x2, 3x3 ve 4x4 icin ayni mixed operatoru vermeli.
  call set_distorted_q9(X_cache)
  do a = 1,9
    u_cache(a,1) = 0.06_dp*X_cache(a,1) + 0.09_dp*X_cache(a,2)
    u_cache(a,2) = -0.03_dp*X_cache(a,1) + 0.04_dp*X_cache(a,2)
  end do
  p_cache = [0.45_dp,0.07_dp,-0.035_dp]

  do i = 1,size(quadrature_orders)
    quadrature_order = quadrature_orders(i)
    call initialize_q9_herrmann_reference_cache( &
        X_cache,quadrature_order,reference_cache,cache_status)
    if (cache_status /= DES_STATUS_OK) then
      error stop 'Q9/P1 reference cache olusturulamadi.'
    end if
    if (.not. reference_cache%initialized .or. &
        reference_cache%quadrature_order /= quadrature_order .or. &
        reference_cache%point_count /= quadrature_order*quadrature_order) then
      error stop 'Q9/P1 reference cache metadata hatali.'
    end if

    call evaluate_q9_plane_strain_herrmann_element_with_quadrature( &
        X_cache,u_cache,p_cache,mu,compliance,quadrature_order, &
        residual_direct,tangent_direct,direct_status,min_j_direct)
    call evaluate_q9_plane_strain_herrmann_element_with_cache( &
        u_cache,p_cache,mu,compliance,reference_cache, &
        residual_cached,tangent_cached,cached_status,min_j_cached)

    if (direct_status /= DES_STATUS_OK .or. cached_status /= DES_STATUS_OK) then
      error stop 'Q9/P1 direct/cache parity degerlendirmesi basarisiz.'
    end if

    cache_residual_error = maxval(abs(residual_cached-residual_direct)) &
        / max(1.0_dp,maxval(abs(residual_direct)))
    cache_tangent_error = maxval(abs(tangent_cached-tangent_direct)) &
        / max(1.0_dp,maxval(abs(tangent_direct)))
    cache_j_error = abs(min_j_cached-min_j_direct)

    if (cache_residual_error > cache_tol .or. &
        cache_tangent_error > cache_tol .or. cache_j_error > cache_tol) then
      error stop 'Q9/P1 reference cache direct operator parity kaybetti.'
    end if
  end do

  write(*,'(A,ES14.6)') 'Q9/P1 Herrmann 21x21 tangent FD error = ',tangent_error
  write(*,'(A,ES14.6)') 'Q9/P1 Herrmann tangent symmetry = ',symmetry_error
  write(*,'(A,ES14.6)') 'Q9/P1 homogeneous J = ',J_target
  write(*,'(A,ES14.6)') 'Q9/P1 cache residual parity = ',cache_residual_error
  write(*,'(A,ES14.6)') 'Q9/P1 cache tangent parity = ',cache_tangent_error
  write(*,'(A)') 'Q9/P1 plane-strain Herrmann element testi BASARILI.'

contains

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

  subroutine set_distorted_q9(coords)
    real(dp), intent(out) :: coords(9,2)

    coords(1,:) = [ 0.00_dp, 0.00_dp]
    coords(2,:) = [ 1.15_dp,-0.05_dp]
    coords(3,:) = [ 1.05_dp, 1.10_dp]
    coords(4,:) = [-0.08_dp, 0.95_dp]
    coords(5,:) = [ 0.56_dp,-0.04_dp]
    coords(6,:) = [ 1.12_dp, 0.52_dp]
    coords(7,:) = [ 0.48_dp, 1.04_dp]
    coords(8,:) = [-0.05_dp, 0.46_dp]
    coords(9,:) = [ 0.53_dp, 0.50_dp]
  end subroutine set_distorted_q9

  subroutine pack_local_state(u_state,p_state,x)
    real(dp), intent(in) :: u_state(9,2),p_state(3)
    real(dp), intent(out) :: x(Q9_HERRMANN_TOTAL_DOF)
    integer :: node

    do node = 1,9
      x(2*node-1) = u_state(node,1)
      x(2*node) = u_state(node,2)
    end do
    x(Q9_HERRMANN_U_DOF+1:Q9_HERRMANN_TOTAL_DOF) = p_state
  end subroutine pack_local_state

  subroutine unpack_local_state(x,u_state,p_state)
    real(dp), intent(in) :: x(Q9_HERRMANN_TOTAL_DOF)
    real(dp), intent(out) :: u_state(9,2),p_state(3)
    integer :: node

    do node = 1,9
      u_state(node,1) = x(2*node-1)
      u_state(node,2) = x(2*node)
    end do
    p_state = x(Q9_HERRMANN_U_DOF+1:Q9_HERRMANN_TOTAL_DOF)
  end subroutine unpack_local_state

end program test_q9_plane_strain_herrmann_element
