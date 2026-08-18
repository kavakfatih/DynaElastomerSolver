program test_v03_fbar_pressure_result_contract
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_material_types, only : neo_hookean_parameters_t
  use des_integration_point_results, only : integration_point_result_t, &
      DES_PRESSURE_SOURCE_DERIVED_CONSTITUTIVE, &
      DES_PRESSURE_SOURCE_INDEPENDENT_UNKNOWN, &
      DES_PRESSURE_MEASURE_LOGJ_CONJUGATE, &
      set_independent_logj_pressure
  use des_q4_plane_strain_fbar_neo_hookean, only : &
      evaluate_q4_plane_strain_fbar_element
  implicit none

  real(dp), parameter :: tol = 2.0e-12_dp
  real(dp), parameter :: separation_floor = 1.0e-4_dp
  real(dp) :: X(4,2), u(4,2), residual(8), tangent(8,8)
  real(dp) :: min_j, j_bar, expected_pressure
  real(dp) :: local_j_min, local_j_max, constitutive_det
  real(dp) :: max_state_separation
  integer :: status, g
  type(neo_hookean_parameters_t) :: parameters
  type(integration_point_result_t) :: results(4), independent_pressure

  X(1,:) = [0.0_dp,0.0_dp]
  X(2,:) = [1.0_dp,0.0_dp]
  X(3,:) = [1.0_dp,1.0_dp]
  X(4,:) = [0.0_dp,1.0_dp]

  ! Bilerek non-affine deformation: Gauss noktalarında gerçek J_g değişir.
  ! F-bar constitutive state ise her Gauss noktasında aynı J_bar'ı kullanır.
  u(1,:) = [ 0.00_dp, 0.00_dp]
  u(2,:) = [ 0.08_dp,-0.01_dp]
  u(3,:) = [ 0.11_dp, 0.04_dp]
  u(4,:) = [-0.02_dp, 0.03_dp]

  parameters%mu = 2.3_dp
  parameters%lambda = 19.0_dp

  call evaluate_q4_plane_strain_fbar_element( &
      X,u,parameters,residual,tangent,status,min_j,j_bar,results)

  if (status /= DES_STATUS_OK) then
    error stop 'F-bar pressure result contract elementi değerlendirilemedi.'
  end if
  if (j_bar <= 0.0_dp .or. min_j <= 0.0_dp) then
    error stop 'F-bar pressure contract testinde J/J_bar pozitif değil.'
  end if

  expected_pressure = parameters%lambda*log(j_bar)
  local_j_min = huge(1.0_dp)
  local_j_max = -huge(1.0_dp)
  max_state_separation = 0.0_dp

  do g = 1,4
    if (.not. results(g)%valid) error stop 'F-bar Gauss sonucu geçersiz.'
    if (.not. results(g)%pressure_valid) error stop 'F-bar derived pressure geçersiz.'
    if (results(g)%pressure_source /= DES_PRESSURE_SOURCE_DERIVED_CONSTITUTIVE) then
      error stop 'F-bar pressure source derived constitutive olmalı.'
    end if
    if (results(g)%pressure_measure /= DES_PRESSURE_MEASURE_LOGJ_CONJUGATE) then
      error stop 'F-bar pressure measure logJ-conjugate olmalı.'
    end if

    local_j_min = min(local_j_min,results(g)%J)
    local_j_max = max(local_j_max,results(g)%J)
    max_state_separation = max( &
        max_state_separation,abs(results(g)%J-results(g)%constitutive_J))

    if (abs(results(g)%constitutive_J-j_bar) > tol) then
      error stop 'F-bar constitutive_J element J_bar ile eşleşmiyor.'
    end if
    if (abs(results(g)%pressure_value-expected_pressure) > 5.0_dp*tol) then
      error stop 'F-bar derived pressure lambda*ln(J_bar) ile eşleşmiyor.'
    end if

    constitutive_det = det3(results(g)%constitutive_F)
    if (abs(constitutive_det-j_bar) > 5.0_dp*tol) then
      error stop 'F-bar constitutive_F determinantı J_bar ile eşleşmiyor.'
    end if
  end do

  if (local_j_max-local_j_min < separation_floor) then
    error stop 'Test non-affine local J değişimini yeterince üretmedi.'
  end if
  if (max_state_separation < separation_floor) then
    error stop 'Test kinematic J ile constitutive J ayrımını yeterince üretmedi.'
  end if

  ! Aynı scalar ölçü mixed formulationda bağımsız pressure unknown olarak da
  ! taşınabilir. Source enum bu iki semantiğin UI/Results katmanında karışmasını
  ! engelleyen contractın zorunlu parçasıdır.
  call set_independent_logj_pressure(independent_pressure,0.7_dp)
  if (.not. independent_pressure%pressure_valid) then
    error stop 'Independent pressure setter geçerli sonuç üretmedi.'
  end if
  if (independent_pressure%pressure_source /= DES_PRESSURE_SOURCE_INDEPENDENT_UNKNOWN) then
    error stop 'Independent pressure source enum yanlış.'
  end if
  if (independent_pressure%pressure_measure /= DES_PRESSURE_MEASURE_LOGJ_CONJUGATE) then
    error stop 'Independent pressure measure enum yanlış.'
  end if
  if (abs(independent_pressure%pressure_value-0.7_dp) > tol) then
    error stop 'Independent pressure değeri korunmadı.'
  end if

  write(*,'(A,ES14.6)') 'F-bar local J range          = ',local_j_max-local_j_min
  write(*,'(A,ES14.6)') 'F-bar J vs constitutive J   = ',max_state_separation
  write(*,'(A,ES14.6)') 'F-bar J_bar                 = ',j_bar
  write(*,'(A,ES14.6)') 'Derived p_logJ              = ',expected_pressure
  write(*,'(A)') 'F-bar pressure result contract testi BASARILI.'

contains

  pure function det3(A) result(value)
    real(dp), intent(in) :: A(3,3)
    real(dp) :: value

    value = A(1,1)*(A(2,2)*A(3,3)-A(2,3)*A(3,2)) &
          - A(1,2)*(A(2,1)*A(3,3)-A(2,3)*A(3,1)) &
          + A(1,3)*(A(2,1)*A(3,2)-A(2,2)*A(3,1))
  end function det3

end program test_v03_fbar_pressure_result_contract
