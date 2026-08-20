program test_auto_sparse_solver_policy
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_UNSUPPORTED_LINEAR_BACKEND
  use des_csr_matrix, only : csr_matrix_t, &
      initialize_csr_from_element_dof_maps, csr_add_local_matrix
  use des_internal_mesh, only : internal_mesh_t, initialize_q9_internal_mesh
  use des_linear_solver, only : linear_solver_settings_t, linear_solver_report_t, &
      production_linear_solver_settings, &
      DES_LINEAR_BACKEND_AUTO, DES_LINEAR_BACKEND_STDLIB_CSR_GMRES, &
      DES_LINEAR_BACKEND_MUMPS_DIRECT, DES_LINEAR_FALLBACK_NONE, &
      DES_LINEAR_FALLBACK_MUMPS_UNAVAILABLE
  use des_mumps_backend, only : DES_MUMPS_AVAILABLE
  use des_q4_plane_strain_newton_solver, only : newton_report_t
  use des_q9_internal_mesh_herrmann_assembly, only : assemble_q9_internal_mesh_herrmann
  use des_q9_plane_strain_herrmann_force_solver, only : &
      solve_q9_internal_mesh_herrmann_force_control, &
      solve_q9_internal_mesh_herrmann_adaptive_force_control
  use des_sparse_solver_context, only : sparse_solver_context_t, &
      sparse_solver_diagnostics_t, create_sparse_solver_context, &
      analyze_sparse_pattern, reorder_sparse_pattern, factorize_sparse_matrix, &
      solve_sparse_with_context, get_sparse_solver_diagnostics, &
      release_sparse_solver_context, DES_MATRIX_CLASS_SYMMETRIC_INDEFINITE, &
      DES_PROBLEM_CLASS_MIXED_U_P, DES_INDEX_CLASS_INT32
  implicit none

  ! B7/B7b kabul kapısı aynı testi iki build profilinde çalıştırır:
  ! MUMPS-enabled -> gerçek sparse direct; MUMPS-disabled -> portable GMRES fallback.
  ! Explicit MUMPS isteği ise unavailable durumda sessiz fallback yapamaz.
  ! Bu dosya B7b final dört-platform acceptance matrisinin ortak policy gate'idir.
  type(csr_matrix_t) :: A
  type(linear_solver_settings_t) :: settings
  type(linear_solver_report_t) :: report
  type(sparse_solver_context_t) :: context
  type(sparse_solver_diagnostics_t) :: diagnostics
  integer :: maps(1,3), status, expected_backend
  real(dp) :: A_dense(3,3), b(3), x(3), expected(3)

  maps(1,:) = [1,2,3]
  call initialize_csr_from_element_dof_maps(A,3,3,maps,status)
  if (status /= DES_STATUS_OK) error stop 'AUTO policy CSR graph kuramadi.'

  A_dense = reshape([ &
      2.0_dp,0.0_dp,1.0_dp, &
      0.0_dp,3.0_dp,1.0_dp, &
      1.0_dp,1.0_dp,0.0_dp],shape(A_dense))
  expected = [1.0_dp,-2.0_dp,0.5_dp]
  b = matmul(A_dense,expected)
  call csr_add_local_matrix(A,maps(1,:),A_dense,status)
  if (status /= DES_STATUS_OK) error stop 'AUTO policy CSR values assemble edemedi.'

  settings = production_linear_solver_settings()
  if (settings%backend /= DES_LINEAR_BACKEND_AUTO .or. &
      settings%direct_iterative_refinement_steps < 1 .or. &
      settings%direct_error_analysis /= 2 .or. &
      .not. settings%direct_null_pivot_detection) then
    error stop 'Production solver profili direct-first kontrolleri tasimiyor.'
  end if
  settings%relative_tolerance = 1.0e-11_dp
  settings%absolute_tolerance = 1.0e-12_dp
  settings%max_iterations = 30
  settings%krylov_dimension = 3

  call create_sparse_solver_context( &
      context,settings,DES_MATRIX_CLASS_SYMMETRIC_INDEFINITE, &
      DES_PROBLEM_CLASS_MIXED_U_P,DES_INDEX_CLASS_INT32,status)
  if (status /= DES_STATUS_OK) error stop 'AUTO sparse context olusturulamadi.'

  call get_sparse_solver_diagnostics(context,diagnostics)
  if (diagnostics%requested_backend /= DES_LINEAR_BACKEND_AUTO) then
    error stop 'AUTO policy requested backend bilgisini korumadi.'
  end if

  if (DES_MUMPS_AVAILABLE) then
    expected_backend = DES_LINEAR_BACKEND_MUMPS_DIRECT
    if (diagnostics%fallback_used) then
      error stop 'MUMPS varken AUTO gereksiz fallback raporladi.'
    end if
    if (diagnostics%fallback_reason /= DES_LINEAR_FALLBACK_NONE) then
      error stop 'MUMPS varken AUTO fallback nedeni sifir olmaliydi.'
    end if
  else
    expected_backend = DES_LINEAR_BACKEND_STDLIB_CSR_GMRES
    if (.not. diagnostics%fallback_used) then
      error stop 'MUMPS yokken AUTO GMRES fallback raporlamadi.'
    end if
    if (diagnostics%fallback_reason /= DES_LINEAR_FALLBACK_MUMPS_UNAVAILABLE) then
      error stop 'AUTO GMRES fallback nedeni yanlis.'
    end if
  end if

  if (diagnostics%backend /= expected_backend) then
    error stop 'AUTO policy beklenen sparse backend secimini yapmadi.'
  end if

  call analyze_sparse_pattern(context,A,status)
  if (status /= DES_STATUS_OK) error stop 'AUTO policy pattern analysis basarisiz.'
  call reorder_sparse_pattern(context,status)
  if (status /= DES_STATUS_OK) error stop 'AUTO policy reorder basarisiz.'
  call factorize_sparse_matrix(context,A,status)
  if (status /= DES_STATUS_OK) error stop 'AUTO policy factorization basarisiz.'
  call solve_sparse_with_context(context,A,b,x,report)
  if (.not. report%converged .or. report%status /= DES_STATUS_OK) then
    error stop 'AUTO policy sparse solve yakinsamadi.'
  end if
  if (maxval(abs(x-expected)) > 1.0e-10_dp) then
    error stop 'AUTO policy sparse solve beklenen cozumle uyusmuyor.'
  end if
  if (report%requested_backend /= DES_LINEAR_BACKEND_AUTO) then
    error stop 'AUTO solve report requested backend bilgisini kaybetti.'
  end if
  if (report%backend /= expected_backend) then
    error stop 'AUTO solve report selected backend bilgisini kaybetti.'
  end if
  if (report%fallback_used .neqv. diagnostics%fallback_used) then
    error stop 'AUTO solve report fallback flag diagnostics ile uyusmuyor.'
  end if
  if (report%fallback_reason /= diagnostics%fallback_reason) then
    error stop 'AUTO solve report fallback nedeni diagnostics ile uyusmuyor.'
  end if

  if (DES_MUMPS_AVAILABLE) then
    if (.not. report%direct_factorization_performed) then
      error stop 'AUTO MUMPS direct factorization flag raporlanmadi.'
    end if
    if (report%direct_null_pivot_count /= 0) then
      error stop 'AUTO MUMPS nonsingular testte null pivot raporladi.'
    end if
  else
    if (report%direct_factorization_performed) then
      error stop 'AUTO GMRES direct factorization yapmis gibi raporlandi.'
    end if
  end if

  call release_sparse_solver_context(context)

  if (.not. DES_MUMPS_AVAILABLE) then
    settings = production_linear_solver_settings()
    settings%backend = DES_LINEAR_BACKEND_MUMPS_DIRECT
    call create_sparse_solver_context( &
        context,settings,DES_MATRIX_CLASS_SYMMETRIC_INDEFINITE, &
        DES_PROBLEM_CLASS_MIXED_U_P,DES_INDEX_CLASS_INT32,status)
    if (status /= DES_ERROR_UNSUPPORTED_LINEAR_BACKEND) then
      error stop 'Explicit MUMPS unavailable durumda fail-fast yapmadi.'
    end if
    if (context%fallback_used) then
      error stop 'Explicit MUMPS istegi sessiz GMRES fallback yapti.'
    end if
  end if

  call verify_q9_production_default(expected_backend)

  write(*,'(A,I0)') 'AUTO requested backend = ',DES_LINEAR_BACKEND_AUTO
  write(*,'(A,I0)') 'AUTO selected backend = ',expected_backend
  write(*,'(A,L1)') 'AUTO fallback used = ',diagnostics%fallback_used
  write(*,'(A)') 'B7b AUTO/production sparse solver policy testi BASARILI.'

contains

  subroutine verify_q9_production_default(expected_backend)
    integer, intent(in) :: expected_backend

    integer, parameter :: fixed_dofs(3) = [1,2,7]
    real(dp), parameter :: shear_modulus = 2.0_dp
    real(dp), parameter :: pressure_compliance = 5.0e-2_dp
    real(dp), parameter :: alpha = 2.0e-2_dp
    real(dp), parameter :: beta = -1.0e-2_dp
    real(dp) :: X(9,2),u_target(9,2),u(9,2),u_fail(9,2)
    real(dp) :: p_target(1,3),p(1,3),p_fail(1,3)
    real(dp) :: residual_target(21),residual(21),residual_fail(21)
    real(dp) :: K_target(21,21),external_force(18),J_target,min_j
    integer :: connectivity(1,9), local_status, a
    type(internal_mesh_t) :: mesh
    type(newton_report_t) :: fixed_report,adaptive_report,unsupported_report
    type(linear_solver_settings_t) :: explicit_mumps

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

    call initialize_q9_internal_mesh(mesh,X,connectivity,local_status)
    if (local_status /= DES_STATUS_OK) then
      error stop 'Q9 production-default regression mesh kuramadi.'
    end if

    do a = 1,9
      u_target(a,1) = alpha*X(a,1)
      u_target(a,2) = beta*X(a,2)
    end do
    J_target = (1.0_dp+alpha)*(1.0_dp+beta)
    p_target = 0.0_dp
    p_target(1,1) = -(J_target-1.0_dp)/pressure_compliance

    call assemble_q9_internal_mesh_herrmann( &
        mesh,u_target,p_target,shear_modulus,pressure_compliance, &
        residual_target,K_target,local_status,min_j)
    if (local_status /= DES_STATUS_OK) then
      error stop 'Q9 production-default target assembly basarisiz.'
    end if
    external_force = residual_target(1:18)

    ! Settings verilmez: production Q9 yolu generic dense defaultu degil AUTO'yu kullanmali.
    u = 0.0_dp
    p = 0.0_dp
    call solve_q9_internal_mesh_herrmann_force_control( &
        mesh,shear_modulus,pressure_compliance,fixed_dofs,external_force, &
        5,40,1.0e-10_dp,u,p,residual,fixed_report)
    if (.not. fixed_report%converged .or. fixed_report%status /= DES_STATUS_OK) then
      error stop 'Q9 fixed production-default regression yakinsamadi.'
    end if
    call require_q9_auto_report(fixed_report,expected_backend,'fixed')

    u = 0.0_dp
    p = 0.0_dp
    call solve_q9_internal_mesh_herrmann_adaptive_force_control( &
        mesh,shear_modulus,pressure_compliance,fixed_dofs,external_force, &
        0.2_dp,0.025_dp,0.5_dp,4,40,1.0e-10_dp, &
        u,p,residual,adaptive_report)
    if (.not. adaptive_report%converged .or. adaptive_report%status /= DES_STATUS_OK) then
      error stop 'Q9 adaptive production-default regression yakinsamadi.'
    end if
    call require_q9_auto_report(adaptive_report,expected_backend,'adaptive')

    if (.not. DES_MUMPS_AVAILABLE) then
      ! Explicit MUMPS yoksa unsupported backend nonlinear fizik failure gibi cutback'e
      ! cevrilmemeli; trial state baslamadan fail-fast edilmeli.
      explicit_mumps = production_linear_solver_settings()
      explicit_mumps%backend = DES_LINEAR_BACKEND_MUMPS_DIRECT
      u_fail = 0.0_dp
      p_fail = 0.0_dp
      call solve_q9_internal_mesh_herrmann_adaptive_force_control( &
          mesh,shear_modulus,pressure_compliance,fixed_dofs,external_force, &
          1.0_dp,0.125_dp,0.5_dp,2,10,1.0e-10_dp, &
          u_fail,p_fail,residual_fail,unsupported_report, &
          linear_settings=explicit_mumps)
      if (unsupported_report%status /= DES_ERROR_UNSUPPORTED_LINEAR_BACKEND) then
        error stop 'Q9 explicit MUMPS unavailable fail-fast statusu yanlis.'
      end if
      if (unsupported_report%cutback_count /= 0 .or. &
          unsupported_report%state_commit_count /= 0 .or. &
          unsupported_report%state_revert_count /= 0) then
        error stop 'Q9 unsupported backend gereksiz cutback/state transaction yapti.'
      end if
      if (maxval(abs(u_fail)) > 1.0e-14_dp .or. maxval(abs(p_fail)) > 1.0e-14_dp) then
        error stop 'Q9 unsupported backend committed statei bozdu.'
      end if
    end if
  end subroutine verify_q9_production_default

  subroutine require_q9_auto_report(nonlinear_report,expected_backend,label)
    type(newton_report_t), intent(in) :: nonlinear_report
    integer, intent(in) :: expected_backend
    character(len=*), intent(in) :: label

    if (nonlinear_report%last_linear_report%requested_backend /= DES_LINEAR_BACKEND_AUTO) then
      error stop 'Q9 production-default requested backend AUTO degil.'
    end if
    if (nonlinear_report%last_linear_report%backend /= expected_backend) then
      error stop 'Q9 production-default selected backend build policy ile uyusmuyor.'
    end if

    if (DES_MUMPS_AVAILABLE) then
      if (nonlinear_report%last_linear_report%fallback_used) then
        error stop 'Q9 production-default MUMPS varken fallback raporladi.'
      end if
      if (nonlinear_report%last_linear_report%fallback_reason /= DES_LINEAR_FALLBACK_NONE) then
        error stop 'Q9 production-default MUMPS fallback nedeni sifir degil.'
      end if
      if (.not. nonlinear_report%last_linear_report%direct_factorization_performed) then
        error stop 'Q9 production-default MUMPS direct factorization yapmadi.'
      end if
    else
      if (.not. nonlinear_report%last_linear_report%fallback_used) then
        error stop 'Q9 production-default MUMPS yokken GMRES fallback raporlamadi.'
      end if
      if (nonlinear_report%last_linear_report%fallback_reason /= &
          DES_LINEAR_FALLBACK_MUMPS_UNAVAILABLE) then
        error stop 'Q9 production-default fallback nedeni MUMPS_UNAVAILABLE degil.'
      end if
      if (nonlinear_report%last_linear_report%direct_factorization_performed) then
        error stop 'Q9 production-default GMRES direct factorization iddia etti.'
      end if
    end if

    write(*,'(A,A,A,I0)') 'Q9 ',trim(label),' production backend = ',expected_backend
  end subroutine require_q9_auto_report

end program test_auto_sparse_solver_policy
