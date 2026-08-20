program test_nonlinear_solver_policy
  use des_kinds, only : dp
  use, intrinsic :: ieee_arithmetic, only : ieee_value, ieee_quiet_nan, ieee_positive_inf
  use des_nonlinear_solver, only : nonlinear_solver_settings_t, &
      nonlinear_solver_settings_valid, line_search_residual_accepted, &
      next_residual_growth_streak, nonlinear_values_finite
  implicit none

  type(nonlinear_solver_settings_t) :: settings
  real(dp) :: values(3), matrix_values(2,2), nan_value, inf_value
  integer :: streak

  settings = nonlinear_solver_settings_t()
  if (.not. nonlinear_solver_settings_valid(settings)) then
    error stop 'Varsayilan nonlinear solver ayarlari gecersiz.'
  end if

  if (.not. line_search_residual_accepted(10.0_dp,9.0_dp,1.0_dp,settings)) then
    error stop 'Azalan residual full Newton adimi kabul edilmedi.'
  end if
  if (line_search_residual_accepted(10.0_dp,10.1_dp,1.0_dp,settings)) then
    error stop 'Buyuyen residual line-search tarafindan kabul edildi.'
  end if
  if (.not. line_search_residual_accepted(10.0_dp,4.0_dp,0.5_dp,settings)) then
    error stop 'Backtracking adimi yeterli residual azalmasina ragmen reddedildi.'
  end if
  if (line_search_residual_accepted(10.0_dp,1.0_dp,0.0_dp,settings)) then
    error stop 'Sifir correction scale line-search tarafindan kabul edildi.'
  end if

  settings%line_search_reduction = 1.0_dp
  if (nonlinear_solver_settings_valid(settings)) then
    error stop 'Gecersiz line-search reduction ayari kabul edildi.'
  end if

  settings = nonlinear_solver_settings_t()
  settings%residual_growth_factor = 1.0_dp
  if (nonlinear_solver_settings_valid(settings)) then
    error stop 'Gecersiz residual growth factor ayari kabul edildi.'
  end if

  settings = nonlinear_solver_settings_t()
  settings%residual_growth_factor = 2.0_dp
  settings%residual_growth_patience = 2

  streak = next_residual_growth_streak(1.0_dp,3.0_dp,0,settings)
  if (streak /= 1) then
    error stop 'Ilk residual growth olayi sayaca eklenmedi.'
  end if

  streak = next_residual_growth_streak(3.0_dp,7.0_dp,streak,settings)
  if (streak /= 2) then
    error stop 'Ardisik residual growth olayi korunmadi.'
  end if
  if (streak < settings%residual_growth_patience) then
    error stop 'Residual divergence patience esigi tetiklenmedi.'
  end if

  streak = next_residual_growth_streak(7.0_dp,8.0_dp,streak,settings)
  if (streak /= 0) then
    error stop 'Residual growth kesilince streak sifirlanmadi.'
  end if

  settings%residual_growth_detection_enabled = .false.
  streak = next_residual_growth_streak(1.0_dp,100.0_dp,1,settings)
  if (streak /= 0) then
    error stop 'Kapali residual growth detection sayac uretmeye devam etti.'
  end if

  ! B8.2: IEEE finite policy scalar, vector ve matrix girdilerinde ayni semantigi
  ! korumalidir. NaN/Inf, residual normu veya Newton state'ine ulasmadan reddedilir.
  values = [1.0_dp,-2.0_dp,3.0_dp]
  matrix_values = reshape([1.0_dp,2.0_dp,3.0_dp,4.0_dp],[2,2])
  if (.not. nonlinear_values_finite(1.0_dp)) then
    error stop 'Finite scalar non-finite olarak isaretlendi.'
  end if
  if (.not. nonlinear_values_finite(values)) then
    error stop 'Finite vector non-finite olarak isaretlendi.'
  end if
  if (.not. nonlinear_values_finite(matrix_values)) then
    error stop 'Finite matrix non-finite olarak isaretlendi.'
  end if

  nan_value = ieee_value(0.0_dp,ieee_quiet_nan)
  inf_value = ieee_value(0.0_dp,ieee_positive_inf)
  if (nonlinear_values_finite(nan_value)) then
    error stop 'NaN scalar finite olarak kabul edildi.'
  end if
  values(2) = inf_value
  if (nonlinear_values_finite(values)) then
    error stop 'Inf iceren vector finite olarak kabul edildi.'
  end if
  matrix_values(2,1) = nan_value
  if (nonlinear_values_finite(matrix_values)) then
    error stop 'NaN iceren matrix finite olarak kabul edildi.'
  end if

  write(*,'(A)') 'Nonlinear solver line-search ve finite policy testi BASARILI.'
end program test_nonlinear_solver_policy
