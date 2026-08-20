program test_adaptive_predictor_policy
  use des_kinds, only : dp
  use, intrinsic :: ieee_arithmetic, only : ieee_value, ieee_quiet_nan
  use des_adaptive_predictor, only : adaptive_predictor_settings_t, &
      adaptive_predictor_settings_valid, select_secant_predictor_scale, &
      build_mixed_secant_predictor
  implicit none

  type(adaptive_predictor_settings_t) :: settings
  real(dp) :: scale
  logical :: applied, valid
  real(dp) :: previous_u(2,2), current_u(2,2), trial_u(2,2)
  real(dp) :: previous_p(1,3), current_p(1,3), trial_p(1,3)

  if (.not. adaptive_predictor_settings_valid(settings)) then
    error stop 'Adaptive predictor varsayilan ayarlari gecersiz.'
  end if

  call select_secant_predictor_scale( &
      0.2_dp,0.1_dp,.true.,.false.,settings,scale,applied)
  if (applied .or. abs(scale) > 1.0e-14_dp) then
    error stop 'Default-disabled predictor no-op davranisini korumadi.'
  end if

  settings%enabled = .true.
  call select_secant_predictor_scale( &
      0.2_dp,0.1_dp,.false.,.false.,settings,scale,applied)
  if (applied .or. abs(scale) > 1.0e-14_dp) then
    error stop 'History yetersizken predictor uygulanmamalidir.'
  end if

  call select_secant_predictor_scale( &
      0.2_dp,0.1_dp,.true.,.true.,settings,scale,applied)
  if (applied .or. abs(scale) > 1.0e-14_dp) then
    error stop 'Cutback retry denemesinde predictor uygulanmamalidir.'
  end if

  settings%maximum_scale = 1.5_dp
  call select_secant_predictor_scale( &
      0.2_dp,0.1_dp,.true.,.false.,settings,scale,applied)
  if (.not. applied .or. abs(scale-1.5_dp) > 1.0e-14_dp) then
    error stop 'Predictor scale upper cap uygulanmadi.'
  end if

  call select_secant_predictor_scale( &
      ieee_value(1.0_dp,ieee_quiet_nan),0.1_dp,.true.,.false., &
      settings,scale,applied)
  if (applied .or. abs(scale) > 1.0e-14_dp) then
    error stop 'NaN next increment predictor tarafindan reddedilmedi.'
  end if

  call select_secant_predictor_scale( &
      0.2_dp,ieee_value(1.0_dp,ieee_quiet_nan),.true.,.false., &
      settings,scale,applied)
  if (applied .or. abs(scale) > 1.0e-14_dp) then
    error stop 'NaN previous increment predictor tarafindan reddedilmedi.'
  end if

  call select_secant_predictor_scale( &
      0.2_dp,-0.1_dp,.true.,.false.,settings,scale,applied)
  if (applied .or. abs(scale) > 1.0e-14_dp) then
    error stop 'Negatif previous increment predictor tarafindan reddedilmedi.'
  end if

  previous_u = reshape([0.0_dp,0.0_dp,0.0_dp,0.0_dp],[2,2])
  current_u = reshape([1.0_dp,2.0_dp,3.0_dp,4.0_dp],[2,2])
  previous_p = reshape([1.0_dp,2.0_dp,3.0_dp],[1,3])
  current_p = reshape([3.0_dp,4.0_dp,5.0_dp],[1,3])

  call build_mixed_secant_predictor( &
      previous_u,current_u,previous_p,current_p,0.5_dp, &
      trial_u,trial_p,valid)
  if (.not. valid) then
    error stop 'Finite mixed secant predictor adayi gecersiz sayildi.'
  end if
  if (maxval(abs(trial_u-(current_u+0.5_dp*(current_u-previous_u)))) > 1.0e-14_dp) then
    error stop 'Displacement predictor secant olcegini korumadi.'
  end if
  if (maxval(abs(trial_p-(current_p+0.5_dp*(current_p-previous_p)))) > 1.0e-14_dp) then
    error stop 'Pressure predictor displacement ile ayni scale kullanmadi.'
  end if

  previous_u(1,1) = ieee_value(1.0_dp,ieee_quiet_nan)
  call build_mixed_secant_predictor( &
      previous_u,current_u,previous_p,current_p,0.5_dp, &
      trial_u,trial_p,valid)
  if (valid) then
    error stop 'Non-finite predictor state reddedilmedi.'
  end if
  if (maxval(abs(trial_u-current_u)) > 1.0e-14_dp .or. &
      maxval(abs(trial_p-current_p)) > 1.0e-14_dp) then
    error stop 'Gecersiz predictor adayi current committed state fallbackini bozdu.'
  end if

  settings = adaptive_predictor_settings_t()
  settings%maximum_scale = 0.0_dp
  if (adaptive_predictor_settings_valid(settings)) then
    error stop 'maximum_scale=0 gecersiz sayilmali.'
  end if

  settings = adaptive_predictor_settings_t()
  settings%maximum_scale = ieee_value(1.0_dp,ieee_quiet_nan)
  if (adaptive_predictor_settings_valid(settings)) then
    error stop 'NaN maximum predictor scale reddedilmedi.'
  end if

  write(*,'(A)') 'Adaptive mixed secant predictor policy testi BASARILI.'
end program test_adaptive_predictor_policy
