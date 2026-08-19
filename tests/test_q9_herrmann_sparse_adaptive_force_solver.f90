program test_q9_herrmann_sparse_adaptive_force_solver
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_CUTBACK_EXHAUSTED
  use des_internal_mesh, only : internal_mesh_t, initialize_q9_internal_mesh
  use des_q4_plane_strain_newton_solver, only : newton_report_t
  use des_linear_solver, only : linear_solver_settings_t, &
                                DES_LINEAR_BACKEND_STDLIB_CSR_GMRES, &
                                DES_LINEAR_BACKEND_MUMPS_DIRECT
  use des_q9_internal_mesh_herrmann_assembly, only : assemble_q9_internal_mesh_herrmann
  use des_q9_plane_strain_herrmann_force_solver, only : &
      solve_q9_internal_mesh_herrmann_adaptive_force_control
  implicit none

  real(dp) :: X(9,2)
  integer :: connectivity(1,9), status, sparse_backend
  character(len=32) :: backend_argument
  type(internal_mesh_t) :: mesh

  sparse_backend = DES_LINEAR_BACKEND_STDLIB_CSR_GMRES
  if (command_argument_count() > 0) then
    call get_command_argument(1,backend_argument)
    select case (trim(backend_argument))
    case ('mumps')
      sparse_backend = DES_LINEAR_BACKEND_MUMPS_DIRECT
    case default
      error stop 'Q9 adaptive sparse parity bilinmeyen backend argumani.'
    end select
  end if

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
    error stop 'Sparse adaptive Q9 nonlinear parity mesh kurulamadi.'
  end if

  call run_adaptive_parity_case(mesh,5.0e-2_dp,.false.,sparse_backend)
  call run_adaptive_parity_case(mesh,0.0_dp,.true.,sparse_backend)
  call run_cutback_exhaustion_parity(mesh,sparse_backend)

  write(*,'(A)') 'Q9/P1 Herrmann sparse adaptive parity testi BASARILI.'

contains

  subroutine run_adaptive_parity_case( &
      mesh,pressure_compliance,fully_incompressible,sparse_backend)
    type(internal_mesh_t), intent(in) :: mesh
    real(dp), intent(in) :: pressure_compliance
    logical, intent(in) :: fully_incompressible
    integer, intent(in) :: sparse_backend

    integer, parameter :: fixed_dofs(3) = [1,2,7]
    real(dp), parameter :: shear_modulus = 2.0_dp
    real(dp), parameter :: alpha = 2.0e-2_dp
    real(dp) :: beta
    real(dp) :: u_target(9,2),u_dense(9,2),u_sparse(9,2)
    real(dp) :: p_target(1,3),p_dense(1,3),p_sparse(1,3)
    real(dp) :: residual_target(21),residual_dense(21),residual_sparse(21)
    real(dp) :: K_target(21,21),external_force(18)
    real(dp) :: min_j,J_target,u_gap,p_gap,residual_gap
    integer :: a,local_status
    type(newton_report_t) :: dense_report,sparse_report
    type(linear_solver_settings_t) :: sparse_settings

    if (fully_incompressible) then
      ! J=1 hedefi Kpp=0 saddle-point yolunu zorlar.
      beta = 1.0_dp/(1.0_dp+alpha)-1.0_dp
    else
      beta = -1.0e-2_dp
    end if

    do a = 1,9
      u_target(a,1) = alpha*mesh%coordinates(a,1)
      u_target(a,2) = beta*mesh%coordinates(a,2)
    end do

    J_target = (1.0_dp+alpha)*(1.0_dp+beta)
    p_target = 0.0_dp
    if (fully_incompressible) then
      p_target(1,1) = 3.0e-2_dp
    else
      p_target(1,1) = -(J_target-1.0_dp)/pressure_compliance
    end if

    call assemble_q9_internal_mesh_herrmann( &
        mesh,u_target,p_target,shear_modulus,pressure_compliance, &
        residual_target,K_target,local_status,min_j)
    if (local_status /= DES_STATUS_OK) then
      error stop 'Sparse adaptive Q9 parity target assembly basarisiz.'
    end if
    if (maxval(abs(residual_target(19:21))) > 2.0e-12_dp) then
      error stop 'Sparse adaptive Q9 target pressure residual sifir degil.'
    end if
    external_force = residual_target(1:18)

    u_dense = 0.0_dp
    p_dense = 0.0_dp
    call solve_q9_internal_mesh_herrmann_adaptive_force_control( &
        mesh,shear_modulus,pressure_compliance,fixed_dofs,external_force, &
        0.2_dp,0.025_dp,0.5_dp,4,40,1.0e-10_dp, &
        u_dense,p_dense,residual_dense,dense_report)

    if (.not. dense_report%converged .or. dense_report%status /= DES_STATUS_OK) then
      error stop 'Q9 dense adaptive parity referansi yakinsamadi.'
    end if

    call configure_sparse_settings(sparse_settings,sparse_backend)

    u_sparse = 0.0_dp
    p_sparse = 0.0_dp
    call solve_q9_internal_mesh_herrmann_adaptive_force_control( &
        mesh,shear_modulus,pressure_compliance,fixed_dofs,external_force, &
        0.2_dp,0.025_dp,0.5_dp,4,40,1.0e-10_dp, &
        u_sparse,p_sparse,residual_sparse,sparse_report, &
        linear_settings=sparse_settings)

    if (.not. sparse_report%converged .or. sparse_report%status /= DES_STATUS_OK) then
      error stop 'Q9 CSR-GMRES adaptive solver yakinsamadi.'
    end if

    u_gap = maxval(abs(u_sparse-u_dense))
    p_gap = maxval(abs(p_sparse-p_dense))
    residual_gap = maxval(abs(residual_sparse-residual_dense))

    if (u_gap > 5.0e-8_dp) then
      error stop 'Q9 adaptive dense-sparse displacement parity toleransi asildi.'
    end if
    if (p_gap > 5.0e-8_dp) then
      error stop 'Q9 adaptive dense-sparse pressure parity toleransi asildi.'
    end if
    if (residual_gap > 2.0e-8_dp) then
      error stop 'Q9 adaptive dense-sparse residual parity toleransi asildi.'
    end if
    if (sparse_report%max_linear_equation_count /= 21) then
      error stop 'Q9 sparse adaptive solve tam mixed equation count raporlamadi.'
    end if
    if (sparse_report%linear_solve_count < 1) then
      error stop 'Q9 sparse adaptive parity lineer solve calistirmadi.'
    end if
    if (sparse_report%max_linear_residual_inf_norm > 2.0e-10_dp) then
      error stop 'Q9 sparse adaptive lineer true residual toleransi asildi.'
    end if
    if (sparse_report%state_commit_count /= dense_report%state_commit_count) then
      error stop 'Q9 adaptive dense-sparse commit sayisi parity bozuldu.'
    end if
    if (sparse_report%state_revert_count /= dense_report%state_revert_count) then
      error stop 'Q9 adaptive dense-sparse revert sayisi parity bozuldu.'
    end if
    if (sparse_report%cutback_count /= dense_report%cutback_count) then
      error stop 'Q9 adaptive dense-sparse cutback sayisi parity bozuldu.'
    end if
    if (abs(sparse_report%final_load_factor-dense_report%final_load_factor) > 1.0e-14_dp) then
      error stop 'Q9 adaptive dense-sparse final load factor parity bozuldu.'
    end if

    ! B4 lifecycle: adaptive increment ve Newton iterasyonları aynı context'i
    ! paylaşır. CSR graph değişmediği sürece symbolic analysis ve ordering tekrarlanmaz.
    if (sparse_report%last_linear_report%pattern_analysis_count /= 1) then
      error stop 'Q9 adaptive sparse context pattern analysis tekrarlandi.'
    end if
    if (sparse_report%last_linear_report%reorder_count /= 1) then
      error stop 'Q9 adaptive sparse context ordering tekrarlandi.'
    end if
    if (sparse_report%last_linear_report%factorization_count /= &
        sparse_report%linear_solve_count) then
      error stop 'Q9 adaptive numeric lifecycle solve sayisiyla uyusmuyor.'
    end if
    if (sparse_report%last_linear_report%context_solve_count /= &
        sparse_report%linear_solve_count) then
      error stop 'Q9 adaptive context solve sayaci Newton sayaciyla uyusmuyor.'
    end if
    if (sparse_report%last_linear_report%backend /= sparse_backend) then
      error stop 'Q9 adaptive sparse backend raporu secimle uyusmuyor.'
    end if
    if (sparse_backend == DES_LINEAR_BACKEND_MUMPS_DIRECT) then
      if (.not. sparse_report%last_linear_report%direct_factorization_performed) then
        error stop 'Q9 adaptive MUMPS direct factorization raporlanmadi.'
      end if
    else
      if (sparse_report%last_linear_report%direct_factorization_performed) then
        error stop 'Q9 adaptive GMRES direct factorization iddia etti.'
      end if
    end if

    if (fully_incompressible) then
      if (maxval(abs(u_sparse-u_target)) > 5.0e-8_dp) then
        error stop 'Q9 fully-incompressible sparse adaptive displacement hedefi kurtarilamadi.'
      end if
      if (maxval(abs(p_sparse-p_target)) > 5.0e-8_dp) then
        error stop 'Q9 fully-incompressible sparse adaptive pressure hedefi kurtarilamadi.'
      end if
      write(*,'(A,ES12.4,A,ES12.4,A,ES12.4)') &
          'Adaptive cp=0 u/p/res gap = ',u_gap,' / ',p_gap,' / ',residual_gap
    else
      write(*,'(A,ES12.4,A,ES12.4,A,ES12.4)') &
          'Adaptive finite cp u/p/res gap = ',u_gap,' / ',p_gap,' / ',residual_gap
    end if
  end subroutine run_adaptive_parity_case

  subroutine run_cutback_exhaustion_parity(mesh,sparse_backend)
    type(internal_mesh_t), intent(in) :: mesh
    integer, intent(in) :: sparse_backend

    integer, parameter :: fixed_dofs(3) = [1,2,7]
    integer, parameter :: max_cutbacks = 2
    real(dp), parameter :: shear_modulus = 2.0_dp
    real(dp), parameter :: pressure_compliance = 5.0e-2_dp
    real(dp), parameter :: alpha = 2.0e-2_dp
    real(dp), parameter :: beta = -1.0e-2_dp
    real(dp) :: J_target,min_j
    real(dp) :: u_target(9,2),u_dense(9,2),u_sparse(9,2)
    real(dp) :: p_target(1,3),p_dense(1,3),p_sparse(1,3)
    real(dp) :: residual_target(21),residual_dense(21),residual_sparse(21)
    real(dp) :: K_target(21,21),external_force(18)
    integer :: a,local_status
    type(newton_report_t) :: dense_report,sparse_report
    type(linear_solver_settings_t) :: sparse_settings

    do a = 1,9
      u_target(a,1) = alpha*mesh%coordinates(a,1)
      u_target(a,2) = beta*mesh%coordinates(a,2)
    end do
    J_target = (1.0_dp+alpha)*(1.0_dp+beta)
    p_target = 0.0_dp
    p_target(1,1) = -(J_target-1.0_dp)/pressure_compliance

    call assemble_q9_internal_mesh_herrmann( &
        mesh,u_target,p_target,shear_modulus,pressure_compliance, &
        residual_target,K_target,local_status,min_j)
    if (local_status /= DES_STATUS_OK) then
      error stop 'Q9 adaptive exhaustion target assembly basarisiz.'
    end if
    external_force = residual_target(1:18)

    u_dense = 0.0_dp
    p_dense = 0.0_dp
    call solve_q9_internal_mesh_herrmann_adaptive_force_control( &
        mesh,shear_modulus,pressure_compliance,fixed_dofs,external_force, &
        1.0_dp,0.125_dp,0.5_dp,max_cutbacks,1,1.0e-12_dp, &
        u_dense,p_dense,residual_dense,dense_report)

    call configure_sparse_settings(sparse_settings,sparse_backend)
    u_sparse = 0.0_dp
    p_sparse = 0.0_dp
    call solve_q9_internal_mesh_herrmann_adaptive_force_control( &
        mesh,shear_modulus,pressure_compliance,fixed_dofs,external_force, &
        1.0_dp,0.125_dp,0.5_dp,max_cutbacks,1,1.0e-12_dp, &
        u_sparse,p_sparse,residual_sparse,sparse_report, &
        linear_settings=sparse_settings)

    if (dense_report%status /= DES_ERROR_CUTBACK_EXHAUSTED .or. &
        sparse_report%status /= DES_ERROR_CUTBACK_EXHAUSTED) then
      error stop 'Q9 adaptive deliberate exhaustion status parity bozuldu.'
    end if
    if (dense_report%converged .or. sparse_report%converged) then
      error stop 'Q9 adaptive deliberate exhaustion yakinsamamis olmali.'
    end if
    if (dense_report%state_commit_count /= 0 .or. sparse_report%state_commit_count /= 0) then
      error stop 'Q9 adaptive failed trial commit edildi.'
    end if
    if (dense_report%state_revert_count /= max_cutbacks+1 .or. &
        sparse_report%state_revert_count /= max_cutbacks+1) then
      error stop 'Q9 adaptive deliberate exhaustion revert sayisi hatali.'
    end if
    if (dense_report%cutback_count /= max_cutbacks+1 .or. &
        sparse_report%cutback_count /= max_cutbacks+1) then
      error stop 'Q9 adaptive deliberate exhaustion cutback sayisi hatali.'
    end if
    if (maxval(abs(u_dense)) > 1.0e-14_dp .or. maxval(abs(u_sparse)) > 1.0e-14_dp) then
      error stop 'Q9 adaptive exhaustion committed displacement stateini bozdu.'
    end if
    if (maxval(abs(p_dense)) > 1.0e-14_dp .or. maxval(abs(p_sparse)) > 1.0e-14_dp) then
      error stop 'Q9 adaptive exhaustion committed pressure stateini bozdu.'
    end if
    if (maxval(abs(residual_sparse-residual_dense)) > 2.0e-10_dp) then
      error stop 'Q9 adaptive exhaustion dense-sparse residual parity bozuldu.'
    end if
    if (sparse_report%linear_solve_count /= dense_report%linear_solve_count) then
      error stop 'Q9 adaptive exhaustion lineer solve count parity bozuldu.'
    end if
    if (sparse_report%last_linear_report%pattern_analysis_count /= 1) then
      error stop 'Q9 exhaustion sparse context symbolic analysis tekrarlandi.'
    end if
    if (sparse_report%last_linear_report%reorder_count /= 1) then
      error stop 'Q9 exhaustion sparse context ordering tekrarlandi.'
    end if
    if (sparse_report%last_linear_report%backend /= sparse_backend) then
      error stop 'Q9 exhaustion sparse backend raporu secimle uyusmuyor.'
    end if
    if (sparse_backend == DES_LINEAR_BACKEND_MUMPS_DIRECT .and. &
        .not. sparse_report%last_linear_report%direct_factorization_performed) then
      error stop 'Q9 exhaustion MUMPS direct factorization raporlanmadi.'
    end if

    write(*,'(A,I0,A,I0,A,I0)') &
        'Adaptive exhaustion cutback/commit/revert = ',sparse_report%cutback_count, &
        ' / ',sparse_report%state_commit_count,' / ',sparse_report%state_revert_count
  end subroutine run_cutback_exhaustion_parity

  subroutine configure_sparse_settings(settings,sparse_backend)
    type(linear_solver_settings_t), intent(out) :: settings
    integer, intent(in) :: sparse_backend

    settings = linear_solver_settings_t()
    settings%backend = sparse_backend
    settings%relative_tolerance = 1.0e-11_dp
    settings%absolute_tolerance = 1.0e-12_dp
    settings%max_iterations = 100
    settings%krylov_dimension = 21
    settings%compact_krylov = .true.
  end subroutine configure_sparse_settings

end program test_q9_herrmann_sparse_adaptive_force_solver