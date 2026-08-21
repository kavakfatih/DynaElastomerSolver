program test_q4_internal_mesh_solver
  use des_kinds, only : dp, i64
  use des_status, only : DES_STATUS_OK, DES_ERROR_UNSUPPORTED_LINEAR_BACKEND
  use des_material_types, only : neo_hookean_parameters_t
  use des_internal_mesh, only : internal_mesh_t, initialize_q4_internal_mesh
  use des_integration_point_results, only : integration_point_results_t
  use des_linear_solver, only : linear_solver_settings_t, DES_LINEAR_BACKEND_STDLIB_DENSE
  use des_q4_plane_strain_newton_solver, only : newton_report_t
  use des_q4_internal_mesh_solver, only : &
      solve_q4_internal_mesh_displacement_control, &
      solve_q4_internal_mesh_fbar_force_control, &
      solve_q4_internal_mesh_fbar_adaptive_force_control
  implicit none

  real(dp) :: X(6,2), u(6,2), residual(12)
  real(dp) :: external_force(12), u_fbar_fixed(6,2)
  integer :: connectivity(2,4), status, g
  integer, parameter :: prescribed_dofs(5) = [1,2,5,7,11]
  integer, parameter :: fbar_fixed_dofs(4) = [1,2,7,8]
  real(dp), parameter :: prescribed_values(5) = [0.0_dp,0.0_dp,0.5_dp,0.0_dp,0.5_dp]
  type(neo_hookean_parameters_t) :: parameters
  type(internal_mesh_t) :: mesh
  type(integration_point_results_t) :: integration_results
  type(newton_report_t) :: report
  type(linear_solver_settings_t) :: linear_settings

  X(1,:) = [0.0_dp,0.0_dp]
  X(2,:) = [1.0_dp,0.0_dp]
  X(3,:) = [2.0_dp,0.0_dp]
  X(4,:) = [0.0_dp,1.0_dp]
  X(5,:) = [1.0_dp,1.0_dp]
  X(6,:) = [2.0_dp,1.0_dp]
  connectivity(1,:) = [1,2,5,4]
  connectivity(2,:) = [2,3,6,5]

  call initialize_q4_internal_mesh(mesh, X, connectivity, status)
  if (status /= DES_STATUS_OK) error stop 'InternalMesh solver testi mesh olusturamadi.'

  parameters%mu = 2.5_dp
  parameters%lambda = 20.0_dp
  linear_settings%backend = DES_LINEAR_BACKEND_STDLIB_DENSE
  u = 0.0_dp

  call solve_q4_internal_mesh_displacement_control( &
    mesh, parameters, prescribed_dofs, prescribed_values, &
    5, 25, 2.0e-11_dp, u, residual, report, integration_results, linear_settings)

  if (.not. report%converged .or. report%status /= DES_STATUS_OK) then
    error stop 'InternalMesh solver adapteri yakinsamadi.'
  end if
  if (integration_results%count() /= 8) then
    error stop 'Iki Q4 eleman icin sekiz Gauss sonucu bekleniyordu.'
  end if

  if (report%linear_solve_count <= 0) then
    error stop 'Newton raporunda lineer solve sayisi kaydedilmedi.'
  end if
  if (report%last_linear_report%backend /= DES_LINEAR_BACKEND_STDLIB_DENSE) then
    error stop 'Newton raporunda lineer backend kimligi yanlis.'
  end if
  if (.not. report%last_linear_report%converged) then
    error stop 'Son lineer solve raporu basarili olmali.'
  end if
  if (kind(report%max_linear_equation_count) /= i64) then
    error stop 'Newton maksimum lineer denklem cardinality raporu int64 degil.'
  end if
  if (report%max_linear_equation_count /= 7_i64) then
    error stop 'Serbest DOF sayisi lineer denklem raporuyla uyusmuyor.'
  end if
  if (report%max_linear_residual_inf_norm > 1.0e-10_dp) then
    error stop 'Newton icindeki lineer residual beklenenden buyuk.'
  end if

  do g = 1,integration_results%count()
    if (.not. integration_results%points(g)%valid) then
      error stop 'Solver sonrasi ham Gauss sonucu gecersiz.'
    end if
    if (integration_results%points(g)%J <= 0.0_dp) then
      error stop 'Solver sonrasi Gauss J sonucu fiziksel degil.'
    end if
  end do

  if (integration_results%points(1)%element_id /= 1 .or. &
      integration_results%points(5)%element_id /= 2) then
    error stop 'Gauss element kimlikleri beklenen sirada degil.'
  end if

  ! Desteklenmeyen backend konfigürasyon hatasıdır; Newton bunu genel bir
  ! lineer-solve hatasına çevirmeden aynen yukarı taşımalıdır.
  u = 0.0_dp
  linear_settings%backend = 999
  call solve_q4_internal_mesh_displacement_control( &
    mesh, parameters, prescribed_dofs, prescribed_values, &
    5, 25, 2.0e-11_dp, u, residual, report, integration_results, linear_settings)

  if (report%converged) error stop 'Desteklenmeyen backend ile Newton yakınsamamalı.'
  if (report%status /= DES_ERROR_UNSUPPORTED_LINEAR_BACKEND) then
    error stop 'Newton lineer backend failure nedenini korumadi.'
  end if
  if (report%last_failure_status /= DES_ERROR_UNSUPPORTED_LINEAR_BACKEND) then
    error stop 'Newton last_failure_status backend nedenini korumadi.'
  end if
  if (report%linear_solve_count /= 1) then
    error stop 'Desteklenmeyen backend ilk lineer denemede terminal olmali.'
  end if
  if (report%last_linear_report%status /= DES_ERROR_UNSUPPORTED_LINEAR_BACKEND) then
    error stop 'Son lineer rapor unsupported backend statusunu tasimiyor.'
  end if
  if (integration_results%count() /= 0) then
    error stop 'Basarisiz Newton sonrasi Gauss sonucu uretilmemeli.'
  end if

  ! Production F-bar artık doğrudan InternalMesh üzerinden çağrılabilir.
  ! Sabit ve adaptive force-control aynı tam-yük çözümüne ulaşmalıdır.
  linear_settings%backend = DES_LINEAR_BACKEND_STDLIB_DENSE
  external_force = 0.0_dp
  external_force(6) = 5.0e-3_dp
  external_force(12) = 5.0e-3_dp

  u = 0.0_dp
  call solve_q4_internal_mesh_fbar_force_control( &
    mesh, parameters, fbar_fixed_dofs, external_force, &
    5, 30, 1.0e-9_dp, u, residual, report, integration_results, linear_settings)

  if (.not. report%converged .or. report%status /= DES_STATUS_OK) then
    error stop 'InternalMesh sabit F-bar force-control yakinsamadi.'
  end if
  if (integration_results%count() /= 8) then
    error stop 'InternalMesh F-bar final state sekiz Gauss sonucu uretmeli.'
  end if
  if (abs(report%final_load_factor-1.0_dp) > 1.0e-12_dp) then
    error stop 'InternalMesh F-bar sabit driver tam yuke ulasmadi.'
  end if
  do g = 1,integration_results%count()
    if (.not. integration_results%points(g)%valid) then
      error stop 'InternalMesh F-bar Gauss sonucu gecersiz.'
    end if
    if (integration_results%points(g)%J <= 0.0_dp) then
      error stop 'InternalMesh F-bar Gauss J pozitif olmali.'
    end if
  end do
  u_fbar_fixed = u

  u = 0.0_dp
  call solve_q4_internal_mesh_fbar_adaptive_force_control( &
    mesh, parameters, fbar_fixed_dofs, external_force, &
    0.5_dp, 0.0625_dp, 0.5_dp, 4, 30, 1.0e-9_dp, &
    u, residual, report, integration_results, linear_settings)

  if (.not. report%converged .or. report%status /= DES_STATUS_OK) then
    error stop 'InternalMesh adaptive F-bar force-control yakinsamadi.'
  end if
  if (integration_results%count() /= 8) then
    error stop 'InternalMesh adaptive F-bar sekiz Gauss sonucu uretmeli.'
  end if
  if (abs(report%final_load_factor-1.0_dp) > 1.0e-12_dp) then
    error stop 'InternalMesh adaptive F-bar tam yuke ulasmadi.'
  end if
  if (maxval(abs(u-u_fbar_fixed)) > 2.0e-7_dp) then
    error stop 'InternalMesh sabit ve adaptive F-bar cozumleri uyusmuyor.'
  end if

  write(*,'(A,I0)') 'InternalMesh F-bar adaptive commit count = ', report%state_commit_count
  write(*,'(A,ES14.6)') 'InternalMesh F-bar final residual = ', report%final_residual_norm
  write(*,'(A)') 'InternalMesh displacement ve F-bar production adapter testleri BASARILI.'
end program test_q4_internal_mesh_solver
