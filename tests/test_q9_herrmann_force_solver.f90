program test_q9_herrmann_force_solver
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_CUTBACK_EXHAUSTED
  use des_internal_mesh, only : internal_mesh_t, initialize_q9_internal_mesh
  use des_q4_plane_strain_newton_solver, only : newton_report_t
  use des_q9_internal_mesh_herrmann_assembly, only : assemble_q9_internal_mesh_herrmann
  use des_q9_plane_strain_herrmann_force_solver, only : &
      solve_q9_internal_mesh_herrmann_force_control, &
      solve_q9_internal_mesh_herrmann_adaptive_force_control
  implicit none

  real(dp) :: X(9,2),u_target(9,2),u_fixed(9,2),u_adaptive(9,2),u_fail(9,2)
  real(dp) :: p_target(1,3),p_fixed(1,3),p_adaptive(1,3),p_fail(1,3)
  real(dp) :: residual_target(21),residual_fixed(21),residual_adaptive(21)
  real(dp) :: residual_fail(21),K_target(21,21),external_force(18)
  integer :: connectivity(1,9)
  integer, parameter :: fixed_dofs(3) = [1,2,7]
  real(dp), parameter :: shear_modulus = 2.0_dp
  real(dp), parameter :: pressure_compliance = 5.0e-2_dp
  real(dp), parameter :: alpha = 2.0e-2_dp
  real(dp), parameter :: beta = -1.0e-2_dp
  real(dp) :: J_target,min_j
  integer :: status,a
  type(internal_mesh_t) :: mesh
  type(newton_report_t) :: report_fixed,report_adaptive,report_fail

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
  if (status /= DES_STATUS_OK) error stop 'Q9 Herrmann solver mesh oluşturulamadı.'

  do a = 1,9
    u_target(a,1) = alpha*X(a,1)
    u_target(a,2) = beta*X(a,2)
  end do
  J_target = (1.0_dp+alpha)*(1.0_dp+beta)
  p_target = 0.0_dp
  p_target(1,1) = -(J_target-1.0_dp)/pressure_compliance

  ! Tam çözümden tutarlı dış yük üretilir. Element/assembly tangent doğruluğu ayrı
  ! testlerde sınandığı için burada amaç nonlinear global solution orchestration'dır.
  call assemble_q9_internal_mesh_herrmann( &
      mesh,u_target,p_target,shear_modulus,pressure_compliance, &
      residual_target,K_target,status,min_j)
  if (status /= DES_STATUS_OK) error stop 'Q9 target state assembly başarısız.'
  if (maxval(abs(residual_target(19:21))) > 2.0e-12_dp) then
    error stop 'Q9 target pressure constraint residual sıfır değil.'
  end if
  external_force = residual_target(1:18)

  u_fixed = 0.0_dp
  p_fixed = 0.0_dp
  call solve_q9_internal_mesh_herrmann_force_control( &
      mesh,shear_modulus,pressure_compliance,fixed_dofs,external_force, &
      5,30,1.0e-10_dp,u_fixed,p_fixed,residual_fixed,report_fixed)

  if (.not. report_fixed%converged .or. report_fixed%status /= DES_STATUS_OK) then
    error stop 'Q9/P1 sabit artımlı Herrmann solver yakınsamadı.'
  end if
  if (abs(report_fixed%final_load_factor-1.0_dp) > 1.0e-14_dp) then
    error stop 'Q9/P1 sabit solver final load factor hatalı.'
  end if
  if (maxval(abs(u_fixed-u_target)) > 2.0e-8_dp) then
    error stop 'Q9/P1 sabit solver displacement hedef state ile uyuşmuyor.'
  end if
  if (maxval(abs(p_fixed-p_target)) > 2.0e-8_dp) then
    error stop 'Q9/P1 sabit solver pressure hedef state ile uyuşmuyor.'
  end if

  u_adaptive = 0.0_dp
  p_adaptive = 0.0_dp
  call solve_q9_internal_mesh_herrmann_adaptive_force_control( &
      mesh,shear_modulus,pressure_compliance,fixed_dofs,external_force, &
      0.2_dp,0.025_dp,0.5_dp,4,30,1.0e-10_dp, &
      u_adaptive,p_adaptive,residual_adaptive,report_adaptive)

  if (.not. report_adaptive%converged .or. &
      report_adaptive%status /= DES_STATUS_OK) then
    error stop 'Q9/P1 adaptive Herrmann solver yakınsamadı.'
  end if
  if (report_adaptive%state_commit_count /= report_adaptive%increments_converged) then
    error stop 'Q9/P1 adaptive commit sayısı increment sayısıyla uyumsuz.'
  end if
  if (maxval(abs(u_adaptive-u_fixed)) > 2.0e-8_dp) then
    error stop 'Q9/P1 adaptive ve sabit displacement sonuçları farklı.'
  end if
  if (maxval(abs(p_adaptive-p_fixed)) > 2.0e-8_dp) then
    error stop 'Q9/P1 adaptive ve sabit pressure sonuçları farklı.'
  end if

  ! Bir Newton iterasyonu kasıtlı olarak yetersizdir. Her başarısız denemede hem
  ! displacement hem pressure trial state revert edilmeli, committed state bozulmamalıdır.
  u_fail = 0.0_dp
  p_fail = 0.0_dp
  call solve_q9_internal_mesh_herrmann_adaptive_force_control( &
      mesh,shear_modulus,pressure_compliance,fixed_dofs,external_force, &
      1.0_dp,0.125_dp,0.5_dp,2,1,1.0e-12_dp, &
      u_fail,p_fail,residual_fail,report_fail)

  if (report_fail%status /= DES_ERROR_CUTBACK_EXHAUSTED) then
    error stop 'Q9/P1 cutback exhaustion status hatalı.'
  end if
  if (report_fail%converged) error stop 'Q9/P1 exhausted çözüm yakınsamış görünüyor.'
  if (report_fail%cutback_count /= 3) error stop 'Q9/P1 cutback sayısı hatalı.'
  if (report_fail%state_commit_count /= 0) error stop 'Başarısız Q9 trial commit edildi.'
  if (report_fail%state_revert_count /= 3) error stop 'Q9 trial revert sayısı hatalı.'
  if (maxval(abs(u_fail)) > 1.0e-14_dp) then
    error stop 'Q9 cutback exhaustion committed displacement stateini bozdu.'
  end if
  if (maxval(abs(p_fail)) > 1.0e-14_dp) then
    error stop 'Q9 cutback exhaustion committed pressure stateini bozdu.'
  end if

  write(*,'(A,ES12.4)') 'Q9/P1 fixed final residual = ',report_fixed%final_residual_norm
  write(*,'(A,ES12.4)') 'Q9/P1 adaptive final residual = ',report_adaptive%final_residual_norm
  write(*,'(A,I0)') 'Q9/P1 adaptive commit count = ',report_adaptive%state_commit_count
  write(*,'(A,I0)') 'Q9/P1 exhaustion revert count = ',report_fail%state_revert_count
  write(*,'(A)') 'Q9/P1 Herrmann nonlinear force solver testi BASARILI.'
end program test_q9_herrmann_force_solver
