program test_q4_mixed_up_element
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_PARAMETERS
  use des_material_types, only : neo_hookean_parameters_t
  use des_q4_plane_strain_neo_hookean, only : evaluate_q4_plane_strain_element
  use des_q4_plane_strain_mixed_up_neo_hookean, only : &
      evaluate_q4_plane_strain_mixed_up_element
  implicit none

  real(dp), parameter :: h = 1.0e-7_dp
  real(dp), parameter :: tangent_tol = 2.0e-7_dp
  real(dp), parameter :: residual_tol = 5.0e-12_dp
  real(dp) :: X(4,2), u(4,2), pressure
  real(dp) :: residual(9), tangent(9,9), tangent_fd(9,9)
  real(dp) :: rp(9), rm(9), Kdummy(9,9), min_j, min_j_dummy
  real(dp) :: q(9), qp(9), qm(9)
  real(dp) :: old_residual(8), old_tangent(8,8), old_min_j
  real(dp) :: F11, F22, J, relative_error
  integer :: status, status_dummy, col
  type(neo_hookean_parameters_t) :: p

  X(1,:) = [0.0_dp,0.0_dp]
  X(2,:) = [1.0_dp,0.0_dp]
  X(3,:) = [1.0_dp,1.0_dp]
  X(4,:) = [0.0_dp,1.0_dp]

  p%mu = 2.3_dp
  p%lambda = 19.0_dp

  ! Non-affine küçük deformation + bağımsız pressure ile tam 9x9 tangent FD kontrolü.
  u(1,:) = [ 0.00_dp, 0.00_dp]
  u(2,:) = [ 0.08_dp,-0.01_dp]
  u(3,:) = [ 0.11_dp, 0.04_dp]
  u(4,:) = [-0.02_dp, 0.03_dp]
  pressure = 0.7_dp

  call evaluate_q4_plane_strain_mixed_up_element( &
      X, u, pressure, p%mu, p%lambda, residual, tangent, status, min_j)
  if (status /= DES_STATUS_OK) error stop 'Mixed u-p element değerlendirilemedi.'
  if (min_j <= 0.0_dp) error stop 'Mixed u-p elementte J pozitif değil.'

  call pack_state(u, pressure, q)
  do col = 1,9
    qp = q
    qm = q
    qp(col) = qp(col) + h
    qm(col) = qm(col) - h

    call evaluate_from_state(qp, rp, Kdummy, status_dummy, min_j_dummy)
    if (status_dummy /= DES_STATUS_OK) error stop 'Pozitif FD perturbasyonu başarısız.'
    call evaluate_from_state(qm, rm, Kdummy, status_dummy, min_j_dummy)
    if (status_dummy /= DES_STATUS_OK) error stop 'Negatif FD perturbasyonu başarısız.'

    tangent_fd(:,col) = (rp-rm)/(2.0_dp*h)
  end do

  relative_error = maxval(abs(tangent-tangent_fd)) &
    / max(1.0_dp,maxval(abs(tangent_fd)))
  if (relative_error > tangent_tol) then
    write(*,'(A,ES14.6)') 'Mixed u-p tangent relative error = ', relative_error
    error stop 'Mixed u-p consistent tangent FD ile uyuşmuyor.'
  end if

  ! Homojen durumda p=lambda*ln(J) seçildiğinde mixed displacement residualı,
  ! mevcut compressible Neo-Hookean Q4 residualını birebir geri üretmelidir.
  F11 = 1.10_dp
  F22 = 0.95_dp
  J = F11*F22
  pressure = p%lambda*log(J)

  u(1,:) = [0.0_dp,0.0_dp]
  u(2,:) = [F11-1.0_dp,0.0_dp]
  u(3,:) = [F11-1.0_dp,F22-1.0_dp]
  u(4,:) = [0.0_dp,F22-1.0_dp]

  call evaluate_q4_plane_strain_mixed_up_element( &
      X, u, pressure, p%mu, p%lambda, residual, tangent, status, min_j)
  if (status /= DES_STATUS_OK) error stop 'Homojen mixed u-p değerlendirmesi başarısız.'
  if (abs(residual(9)) > residual_tol) then
    error stop 'Homojen durumda pressure stationarity sağlanmadı.'
  end if

  call evaluate_q4_plane_strain_element( &
      X, u, p, old_residual, old_tangent, status, old_min_j)
  if (status /= DES_STATUS_OK) error stop 'Mevcut displacement Q4 referansı başarısız.'
  if (maxval(abs(residual(1:8)-old_residual)) > residual_tol) then
    error stop 'Mixed u-p homojen displacement residualı mevcut modelle eşleşmiyor.'
  end if

  call evaluate_q4_plane_strain_mixed_up_element( &
      X, u, pressure, p%mu, 0.0_dp, residual, tangent, status, min_j)
  if (status /= DES_ERROR_INVALID_PARAMETERS) then
    error stop 'Mixed u-p lambda<=0 parametresini reddetmedi.'
  end if

  write(*,'(A,ES14.6)') 'Mixed u-p 9x9 tangent FD relative error = ', relative_error
  write(*,'(A)') 'Q4-P0 mixed u-p element testi BASARILI.'

contains

  subroutine pack_state(u_value, pressure_value, state)
    real(dp), intent(in) :: u_value(4,2), pressure_value
    real(dp), intent(out) :: state(9)
    integer :: a

    do a = 1,4
      state(2*a-1) = u_value(a,1)
      state(2*a) = u_value(a,2)
    end do
    state(9) = pressure_value
  end subroutine pack_state

  subroutine unpack_state(state, u_value, pressure_value)
    real(dp), intent(in) :: state(9)
    real(dp), intent(out) :: u_value(4,2), pressure_value
    integer :: a

    do a = 1,4
      u_value(a,1) = state(2*a-1)
      u_value(a,2) = state(2*a)
    end do
    pressure_value = state(9)
  end subroutine unpack_state

  subroutine evaluate_from_state(state, r, K, local_status, local_min_j)
    real(dp), intent(in) :: state(9)
    real(dp), intent(out) :: r(9), K(9,9), local_min_j
    integer, intent(out) :: local_status
    real(dp) :: local_u(4,2), local_pressure

    call unpack_state(state, local_u, local_pressure)
    call evaluate_q4_plane_strain_mixed_up_element( &
        X, local_u, local_pressure, p%mu, p%lambda, &
        r, K, local_status, local_min_j)
  end subroutine evaluate_from_state

end program test_q4_mixed_up_element
