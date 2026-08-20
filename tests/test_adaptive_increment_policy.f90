program test_adaptive_increment_policy
  use des_kinds, only : dp
  use, intrinsic :: ieee_arithmetic, only : ieee_value, ieee_quiet_nan, ieee_positive_inf
  use des_adaptive_increment, only : adaptive_increment_settings_t, &
      adaptive_increment_settings_valid, select_next_adaptive_increment
  implicit none

  type(adaptive_increment_settings_t) :: settings
  real(dp) :: next_increment
  logical :: growth_applied

  if (.not. adaptive_increment_settings_valid(settings)) then
    error stop 'Adaptive increment varsayilan ayarlari gecersiz.'
  end if

  call select_next_adaptive_increment( &
      0.2_dp,0.8_dp,2,.false.,settings,next_increment,growth_applied)
  if (abs(next_increment-0.2_dp) > 1.0e-14_dp .or. growth_applied) then
    error stop 'Default-disabled adaptive increment mevcut step davranisini korumadi.'
  end if

  settings%growth_enabled = .true.
  settings%growth_factor = 1.5_dp
  settings%growth_iteration_threshold = 3
  settings%maximum_increment = 0.5_dp

  call select_next_adaptive_increment( &
      0.2_dp,0.8_dp,2,.false.,settings,next_increment,growth_applied)
  if (abs(next_increment-0.3_dp) > 1.0e-14_dp .or. .not. growth_applied) then
    error stop 'Kolay yakinsayan temiz increment kontrollu buyutulmedi.'
  end if

  call select_next_adaptive_increment( &
      0.2_dp,0.8_dp,2,.true.,settings,next_increment,growth_applied)
  if (abs(next_increment-0.2_dp) > 1.0e-14_dp .or. growth_applied) then
    error stop 'Cutback sonrasi increment yanlis bicimde buyutuldu.'
  end if

  call select_next_adaptive_increment( &
      0.2_dp,0.8_dp,4,.false.,settings,next_increment,growth_applied)
  if (abs(next_increment-0.2_dp) > 1.0e-14_dp .or. growth_applied) then
    error stop 'Iteration threshold asildigi halde increment buyutuldu.'
  end if

  settings%growth_factor = 2.0_dp
  call select_next_adaptive_increment( &
      0.4_dp,0.6_dp,1,.false.,settings,next_increment,growth_applied)
  if (abs(next_increment-0.5_dp) > 1.0e-14_dp .or. .not. growth_applied) then
    error stop 'Maximum increment cap uygulanmadi.'
  end if

  call select_next_adaptive_increment( &
      0.04_dp,0.05_dp,1,.false.,settings,next_increment,growth_applied)
  if (abs(next_increment-0.05_dp) > 1.0e-14_dp .or. .not. growth_applied) then
    error stop 'Remaining-load cap kontrollu growth adayina uygulanmadi.'
  end if

  call select_next_adaptive_increment( &
      0.2_dp,0.1_dp,1,.false.,settings,next_increment,growth_applied)
  if (abs(next_increment-0.1_dp) > 1.0e-14_dp .or. growth_applied) then
    error stop 'Kalan yuk mevcut step altindayken overshoot engellenmedi.'
  end if

  settings = adaptive_increment_settings_t()
  settings%growth_factor = 1.0_dp
  if (adaptive_increment_settings_valid(settings)) then
    error stop 'growth_factor=1 gecersiz sayilmali.'
  end if

  settings = adaptive_increment_settings_t()
  settings%growth_iteration_threshold = -1
  if (adaptive_increment_settings_valid(settings)) then
    error stop 'Negatif growth iteration threshold reddedilmedi.'
  end if

  settings = adaptive_increment_settings_t()
  settings%maximum_increment = 1.1_dp
  if (adaptive_increment_settings_valid(settings)) then
    error stop 'maximum_increment>1 reddedilmedi.'
  end if

  settings = adaptive_increment_settings_t()
  settings%growth_factor = ieee_value(1.0_dp,ieee_quiet_nan)
  if (adaptive_increment_settings_valid(settings)) then
    error stop 'NaN growth factor reddedilmedi.'
  end if

  settings = adaptive_increment_settings_t()
  settings%maximum_increment = ieee_value(1.0_dp,ieee_positive_inf)
  if (adaptive_increment_settings_valid(settings)) then
    error stop 'Inf maximum increment reddedilmedi.'
  end if

  settings = adaptive_increment_settings_t()
  call select_next_adaptive_increment( &
      ieee_value(1.0_dp,ieee_quiet_nan),0.8_dp,1,.false.,settings, &
      next_increment,growth_applied)
  if (abs(next_increment) > 1.0e-14_dp .or. growth_applied) then
    error stop 'Non-finite current increment policy tarafindan reddedilmedi.'
  end if

  write(*,'(A)') 'Adaptive increment policy testi BASARILI.'
end program test_adaptive_increment_policy
