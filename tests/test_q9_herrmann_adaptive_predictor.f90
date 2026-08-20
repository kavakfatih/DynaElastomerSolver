program test_q9_herrmann_adaptive_predictor
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_internal_mesh, only : internal_mesh_t, initialize_q9_internal_mesh
  use des_adaptive_predictor, only : adaptive_predictor_settings_t
  use des_q9_internal_mesh_herrmann_assembly, only : assemble_q9_internal_mesh_herrmann
  use des_q9_herrmann_solver_report, only : herrmann_solver_report_t, &
      solve_q9_internal_mesh_herrmann_adaptive_reported
  implicit none

  integer, parameter :: fixed_dofs(3) = [1,2,7]
  real(dp), parameter :: shear_modulus = 2.0_dp
  real(dp), parameter :: pressure_compliance = 5.0e-2_dp
  real(dp), parameter :: alpha = 2.0e-2_dp
  real(dp), parameter :: beta = -1.0e-2_dp
  real(dp), parameter :: solve_tolerance = 1.0e-10_dp

  real(dp) :: X(9,2),J_target,min_j
  integer :: connectivity(1,9),status,a
  type(internal_mesh_t) :: mesh
  real(dp) :: u_target(9,2),p_target(1,3)
  real(dp) :: residual_target(21),K_target(21,21),external_force(18)
  real(dp) :: u_baseline(9,2),u_predictor(9,2)
  real(dp) :: p_baseline(1,3),p_predictor(1,3)
  real(dp) :: residual_baseline(21),residual_predictor(21)
  real(dp) :: u_gap,p_gap,residual_gap
  type(herrmann_solver_report_t) :: baseline_report,predictor_report
  type(adaptive_predictor_settings_t) :: predictor_settings

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
    error stop 'Adaptive predictor Q9 mesh kurulamadi.'
  end if

  do a = 1,9
    u_target(a,1) = alpha*mesh%coordinates(a,1)
    u_target(a,2) = beta*mesh%coordinates(a,2)
  end do
  J_target = (1.0_dp+alpha)*(1.0_dp+beta)
  p_target = 0.0_dp
  p_target(1,1) = -(J_target-1.0_dp)/pressure_compliance

  call assemble_q9_internal_mesh_herrmann( &
      mesh,u_target,p_target,shear_modulus,pressure_compliance, &
      residual_target,K_target,status,min_j)
  if (status /= DES_STATUS_OK) then
    error stop 'Adaptive predictor manufactured target assemble edilemedi.'
  end if
  if (maxval(abs(residual_target(19:21))) > 2.0e-12_dp) then
    error stop 'Adaptive predictor target pressure residual sifir degil.'
  end if
  external_force = residual_target(1:18)

  u_baseline = 0.0_dp
  p_baseline = 0.0_dp
  call solve_q9_internal_mesh_herrmann_adaptive_reported( &
      mesh,shear_modulus,pressure_compliance,fixed_dofs,external_force, &
      0.1_dp,0.0125_dp,0.5_dp,5,40,solve_tolerance, &
      u_baseline,p_baseline,residual_baseline,baseline_report)

  if (.not. baseline_report%nonlinear%converged .or. &
      baseline_report%nonlinear%status /= DES_STATUS_OK) then
    error stop 'Default-disabled adaptive predictor baseline yakinsamadi.'
  end if
  if (baseline_report%predictor_event_count /= 0) then
    error stop 'Default-disabled predictor olay raporladi.'
  end if
  if (abs(baseline_report%nonlinear%final_load_factor-1.0_dp) > 1.0e-14_dp) then
    error stop 'Predictor baseline final load factor 1 olmadi.'
  end if

  predictor_settings%enabled = .true.
  predictor_settings%maximum_scale = 1.0_dp

  u_predictor = 0.0_dp
  p_predictor = 0.0_dp
  call solve_q9_internal_mesh_herrmann_adaptive_reported( &
      mesh,shear_modulus,pressure_compliance,fixed_dofs,external_force, &
      0.1_dp,0.0125_dp,0.5_dp,5,40,solve_tolerance, &
      u_predictor,p_predictor,residual_predictor,predictor_report, &
      predictor_settings=predictor_settings)

  if (.not. predictor_report%nonlinear%converged .or. &
      predictor_report%nonlinear%status /= DES_STATUS_OK) then
    error stop 'Predictor-enabled adaptive Q9 solve yakinsamadi.'
  end if
  if (predictor_report%predictor_event_count < 1) then
    error stop 'Predictor-enabled solve predictor olayi raporlamadi.'
  end if
  if (predictor_report%maximum_predictor_scale <= 0.0_dp .or. &
      predictor_report%maximum_predictor_scale > 1.0_dp+1.0e-14_dp) then
    error stop 'Predictor scale configured cap disina cikti.'
  end if
  if (predictor_report%nonlinear%state_commit_count /= &
      predictor_report%nonlinear%increments_converged) then
    error stop 'Predictor mixed u-p commit sayisi increment sayisiyla uyusmuyor.'
  end if
  if (abs(predictor_report%nonlinear%final_load_factor-1.0_dp) > 1.0e-14_dp) then
    error stop 'Predictor-enabled adaptive solve final load factor 1 olmadi.'
  end if

  u_gap = maxval(abs(u_predictor-u_baseline))
  p_gap = maxval(abs(p_predictor-p_baseline))
  residual_gap = maxval(abs(residual_predictor-residual_baseline))
  if (u_gap > 5.0e-8_dp) then
    error stop 'Adaptive predictor displacement sonucu baseline ile uyusmuyor.'
  end if
  if (p_gap > 5.0e-8_dp) then
    error stop 'Adaptive predictor pressure sonucu baseline ile uyusmuyor.'
  end if
  if (residual_gap > 2.0e-8_dp) then
    error stop 'Adaptive predictor residual sonucu baseline ile uyusmuyor.'
  end if

  write(*,'(A,I0,A,ES12.4)') &
      'Adaptive predictor events = ',predictor_report%predictor_event_count, &
      ', max scale = ',predictor_report%maximum_predictor_scale
  write(*,'(A)') 'Q9/P1 adaptive mixed secant predictor testi BASARILI.'
end program test_q9_herrmann_adaptive_predictor
