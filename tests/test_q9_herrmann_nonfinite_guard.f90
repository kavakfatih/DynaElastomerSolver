program test_q9_herrmann_nonfinite_guard
  use des_kinds, only : dp
  use, intrinsic :: ieee_arithmetic, only : ieee_value, ieee_quiet_nan
  use des_status, only : DES_STATUS_OK, DES_ERROR_NONFINITE_NONLINEAR
  use des_internal_mesh, only : internal_mesh_t, initialize_q9_internal_mesh
  use des_linear_solver, only : linear_solver_settings_t, DES_LINEAR_BACKEND_STDLIB_DENSE
  use des_q4_plane_strain_newton_solver, only : newton_report_t
  use des_q9_plane_strain_herrmann_force_solver, only : &
      solve_q9_internal_mesh_herrmann_adaptive_force_control
  implicit none

  real(dp) :: X(9,2),u(9,2),p(1,3),external_force(18),residual(21)
  integer :: connectivity(1,9),status
  integer, parameter :: fixed_dofs(3) = [1,2,7]
  type(internal_mesh_t) :: mesh
  type(newton_report_t) :: report
  type(linear_solver_settings_t) :: dense_settings

  X(1,:) = [0.0_dp,0.0_dp]
  X(2,:) = [1.0_dp,0.0_dp]
  X(3,:) = [1.0_dp,1.0_dp]
  X(4,:) = [0.0_dp,1.0_dp]
  X(5,:) = [0.5_dp,0.0_dp]
  X(6,:) = [1.0_dp,0.5_dp]
  X(7,:) = [0.5_dp,1.0_dp]
  X(8,:) = [0.0_dp,0.5_dp]
  X(9,:) = [0.5_dp,0.5_dp]
  connectivity(1,:) = [1,2,3,4,5,6,7,8,9]

  call initialize_q9_internal_mesh(mesh,X,connectivity,status)
  if (status /= DES_STATUS_OK) then
    error stop 'Q9 non-finite guard mesh kurulamadi.'
  end if

  dense_settings%backend = DES_LINEAR_BACKEND_STDLIB_DENSE
  u = 0.0_dp
  p = 0.0_dp
  external_force = 0.0_dp
  external_force(4) = ieee_value(0.0_dp,ieee_quiet_nan)

  ! B8.2 input guard: NaN load Newton/assembly katmanina girmeden deterministic
  ! status ile reddedilmelidir. Bad input icin cutback anlamsizdir; state transaction
  ! daha baslamadigi icin commit/revert sayaclari da sifir kalmalidir.
  call solve_q9_internal_mesh_herrmann_adaptive_force_control( &
      mesh,2.0_dp,5.0e-2_dp,fixed_dofs,external_force, &
      0.5_dp,0.0625_dp,0.5_dp,3,20,1.0e-10_dp, &
      u,p,residual,report,linear_settings=dense_settings)

  if (report%status /= DES_ERROR_NONFINITE_NONLINEAR) then
    error stop 'NaN external load beklenen nonlinear non-finite statusunu vermedi.'
  end if
  if (report%last_failure_status /= DES_ERROR_NONFINITE_NONLINEAR) then
    error stop 'NaN external load last_failure_status alanina tasinmadi.'
  end if
  if (report%increments_attempted /= 0) then
    error stop 'NaN external load ile Newton increment denemesi baslatildi.'
  end if
  if (report%cutback_count /= 0) then
    error stop 'NaN input physics failure gibi cutback zincirine sokuldu.'
  end if
  if (report%state_commit_count /= 0 .or. report%state_revert_count /= 0) then
    error stop 'NaN input state transaction sayaclarini degistirdi.'
  end if
  if (report%history%count /= 0) then
    error stop 'Fail-fast NaN input convergence history olusturdu.'
  end if
  if (maxval(abs(u)) > 0.0_dp .or. maxval(abs(p)) > 0.0_dp) then
    error stop 'NaN input committed mixed state'i degistirdi.'
  end if

  write(*,'(A)') 'Q9/P1 adaptive NaN/Inf input guard testi BASARILI.'
end program test_q9_herrmann_nonfinite_guard
