program test_q9_herrmann_fully_incompressible
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_internal_mesh, only : internal_mesh_t, initialize_q9_internal_mesh
  use des_linear_solver, only : linear_solver_settings_t, DES_LINEAR_BACKEND_STDLIB_DENSE
  use des_q4_plane_strain_newton_solver, only : newton_report_t
  use des_q9_internal_mesh_herrmann_assembly, only : assemble_q9_internal_mesh_herrmann
  use des_q9_plane_strain_herrmann_force_solver, only : &
      solve_q9_internal_mesh_herrmann_adaptive_force_control
  implicit none

  real(dp) :: X(9,2),u_target(9,2),u(9,2)
  real(dp) :: p_target(1,3),p(1,3)
  real(dp) :: residual_target(21),residual(21),K_target(21,21),external_force(18)
  integer :: connectivity(1,9)
  integer, parameter :: fixed_dofs(3) = [1,2,7]
  real(dp), parameter :: shear_modulus = 2.0_dp
  real(dp), parameter :: pressure_compliance = 0.0_dp
  real(dp), parameter :: alpha = 2.0e-2_dp
  real(dp), parameter :: beta = 1.0_dp/(1.0_dp+alpha)-1.0_dp
  real(dp), parameter :: p0 = 1.5e-1_dp
  real(dp) :: J_target,min_j
  integer :: status,a
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
  if (status /= DES_STATUS_OK) error stop 'Fully incompressible Q9 mesh oluşturulamadı.'

  do a = 1,9
    u_target(a,1) = alpha*X(a,1)
    u_target(a,2) = beta*X(a,2)
  end do
  J_target = (1.0_dp+alpha)*(1.0_dp+beta)
  if (abs(J_target-1.0_dp) > 5.0e-15_dp) then
    error stop 'Manufactured incompressible target J=1 değil.'
  end if

  p_target = 0.0_dp
  p_target(1,1) = p0

  ! c_p=0 olduğunda K_pp sıfır bloktur ve pressure denklemi doğrudan J-1=0
  ! kısıtını uygular. Hedef çözümden tutarlı traction/body nodal force üretilir.
  call assemble_q9_internal_mesh_herrmann( &
      mesh,u_target,p_target,shear_modulus,pressure_compliance, &
      residual_target,K_target,status,min_j)
  if (status /= DES_STATUS_OK) error stop 'Fully incompressible target assembly başarısız.'
  if (maxval(abs(residual_target(19:21))) > 2.0e-12_dp) then
    error stop 'Fully incompressible target pressure residual sıfır değil.'
  end if
  external_force = residual_target(1:18)
  dense_settings%backend = DES_LINEAR_BACKEND_STDLIB_DENSE

  u = 0.0_dp
  p = 0.0_dp
  call solve_q9_internal_mesh_herrmann_adaptive_force_control( &
      mesh,shear_modulus,pressure_compliance,fixed_dofs,external_force, &
      0.2_dp,0.0125_dp,0.5_dp,6,40,1.0e-10_dp, &
      u,p,residual,report,linear_settings=dense_settings)

  if (.not. report%converged .or. report%status /= DES_STATUS_OK) then
    error stop 'Fully incompressible Q9/P1 saddle-point solver yakınsamadı.'
  end if
  if (abs(report%final_load_factor-1.0_dp) > 1.0e-14_dp) then
    error stop 'Fully incompressible solver final load factor hatalı.'
  end if
  if (maxval(abs(u-u_target)) > 3.0e-8_dp) then
    error stop 'Fully incompressible displacement target state ile uyuşmuyor.'
  end if
  if (maxval(abs(p-p_target)) > 3.0e-8_dp) then
    error stop 'Fully incompressible pressure target state ile uyuşmuyor.'
  end if
  if (maxval(abs(residual(19:21))) > 1.0e-10_dp) then
    error stop 'Fully incompressible pressure/constraint residual tolerans dışı.'
  end if
  if (report%min_j <= 0.0_dp) error stop 'Fully incompressible çözümde J pozitif değil.'

  write(*,'(A,ES12.4)') 'Fully incompressible target J = ',J_target
  write(*,'(A,ES12.4)') 'Recovered pressure p0 = ',p(1,1)
  write(*,'(A,ES12.4)') 'Final combined residual = ',report%final_residual_norm
  write(*,'(A,I0)') 'Accepted increments = ',report%increments_converged
  write(*,'(A)') 'Q9/P1 fully incompressible saddle-point testi BASARILI.'
end program test_q9_herrmann_fully_incompressible
