program test_nonlinear_solver_policy
  use des_kinds, only : dp
  use des_nonlinear_solver, only : nonlinear_solver_settings_t, &
      nonlinear_solver_settings_valid, line_search_residual_accepted, &
      next_residual_growth_streak
  implicit none

  type(nonlinear_solver_settings_t) :: settings
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

  settings%line_search_reduction = 1.0_dp
  if (nonlinear_solver_settings_valid(settings)) then
    error stop 'Gecersiz line-search reduction ayari kabul edildi.'
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

  write(*,'(A)') 'Nonlinear solver line-search policy testi BASARILI.'
end program test_nonlinear_solver_policy
