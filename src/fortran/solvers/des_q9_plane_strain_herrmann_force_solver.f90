module des_q9_plane_strain_herrmann_force_solver
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_PARAMETERS, &
                         DES_ERROR_INVALID_CONNECTIVITY, DES_ERROR_INVALID_CONSTRAINT, &
                         DES_ERROR_NEWTON_DID_NOT_CONVERGE, &
                         DES_ERROR_CUTBACK_EXHAUSTED, &
                         DES_ERROR_UNSUPPORTED_LINEAR_BACKEND, &
                         DES_ERROR_LINE_SEARCH_FAILED, &
                         DES_ERROR_NONLINEAR_DIVERGENCE, &
                         DES_ERROR_NONFINITE_NONLINEAR
  use des_internal_mesh, only : internal_mesh_t, validate_internal_mesh
  use des_csr_matrix, only : csr_matrix_t, csr_apply_zero_dirichlet
  use des_linear_solver, only : linear_solver_settings_t, linear_solver_report_t, &
                                solve_linear_system, linear_backend_is_sparse, &
                                production_linear_solver_settings
  use des_sparse_solver_context, only : sparse_solver_context_t, &
      create_sparse_solver_context, analyze_sparse_pattern, &
      reorder_sparse_pattern, factorize_sparse_matrix, &
      solve_sparse_with_context, release_sparse_solver_context, &
      DES_MATRIX_CLASS_SYMMETRIC_INDEFINITE, DES_PROBLEM_CLASS_MIXED_U_P, &
      DES_INDEX_CLASS_INT32
  use des_solution_state, only : solution_state_t, initialize_solution_state, &
                                 begin_solution_trial, commit_solution_state, &
                                 revert_solution_state
  use des_solver_history, only : convergence_record_t, clear_convergence_history, &
                                 append_convergence_record, mark_last_convergence_status
  use des_nonlinear_solver, only : nonlinear_solver_settings_t, &
      nonlinear_solver_settings_valid, line_search_residual_accepted, &
      next_residual_growth_streak, nonlinear_values_finite, &
      DES_NONFINITE_STAGE_NONE, DES_NONFINITE_STAGE_RESIDUAL, &
      DES_NONFINITE_STAGE_CORRECTION, DES_NONFINITE_STAGE_TRIAL_STATE
  use des_adaptive_increment, only : adaptive_increment_settings_t, &
      adaptive_increment_settings_valid, select_next_adaptive_increment
  use des_adaptive_predictor, only : adaptive_predictor_settings_t, &
      adaptive_predictor_settings_valid, select_secant_predictor_scale, &
      build_mixed_secant_predictor
  use des_q4_plane_strain_newton_solver, only : newton_report_t
  use des_q9_plane_strain_herrmann_neo_hookean, only : &
      Q9_HERRMANN_P_DOF, Q9_HERRMANN_QUADRATURE_3X3
  use des_q9_internal_mesh_herrmann_assembly, only : &
      assemble_q9_internal_mesh_herrmann_with_quadrature
  use des_q9_plane_strain_herrmann_sparse_mesh, only : &
      initialize_q9_plane_strain_herrmann_csr_pattern, &
      assemble_q9_plane_strain_herrmann_mesh_csr_with_quadrature
  implicit none
  private

  public :: solve_q9_internal_mesh_herrmann_force_control
  public :: solve_q9_internal_mesh_herrmann_adaptive_force_control

contains

  subroutine solve_q9_internal_mesh_herrmann_force_control( &
      mesh, shear_modulus, pressure_compliance, fixed_dofs, external_force, &
      n_increments, max_iterations, tolerance, u, pressure_coefficients, &
      residual, report, linear_settings, quadrature_order)
    ! Q9/P1 Herrmann için sabit artımlı Full Newton sürücüsü.
    ! Global unknown sırası [u, p] olarak korunur; pressure katsayıları gerçek
    ! global Newton bilinmeyenleridir ve displacement ile aynı lineer sistemde çözülür.
    !
    ! Dense backend küçük doğrulama problemleri için free-free alt sistem yolunu
    ! korur. CSR backend seçildiğinde ise global tangent dense NxN matrise hiç
    ! dönüştürülmeden assemble edilir ve sıfır Dirichlet increment koşulları CSR
    ! üzerinde uygulanarak tam mixed sistem çözülür.
    type(internal_mesh_t), intent(in) :: mesh
    real(dp), intent(in) :: shear_modulus, pressure_compliance
    integer, intent(in) :: fixed_dofs(:)
    real(dp), intent(in) :: external_force(:)
    integer, intent(in) :: n_increments, max_iterations
    real(dp), intent(in) :: tolerance
    real(dp), intent(inout) :: u(:,:), pressure_coefficients(:,:)
    real(dp), intent(out) :: residual(:)
    type(newton_report_t), intent(out) :: report
    type(linear_solver_settings_t), intent(in), optional :: linear_settings
    integer, intent(in), optional :: quadrature_order

    logical, allocatable :: is_fixed(:)
    integer, allocatable :: free_dofs(:)
    real(dp), allocatable :: K(:,:), Kff(:,:), rhs(:), delta(:)
    real(dp), allocatable :: rhs_full(:), delta_full(:)
    type(csr_matrix_t) :: K_csr
    type(sparse_solver_context_t) :: sparse_context
    real(dp) :: min_j, load_factor, residual_norm, increment_size
    integer :: ndisp, ntotal, nfree, status, active_quadrature
    integer :: increment, iteration, a, b
    logical :: increment_converged, use_sparse_backend
    type(linear_solver_settings_t) :: active_linear_settings
    type(linear_solver_report_t) :: linear_report

    active_linear_settings = production_linear_solver_settings()
    if (present(linear_settings)) active_linear_settings = linear_settings
    active_quadrature = Q9_HERRMANN_QUADRATURE_3X3
    if (present(quadrature_order)) active_quadrature = quadrature_order
    use_sparse_backend = linear_backend_is_sparse(active_linear_settings%backend)

    report = newton_report_t()
    report%last_linear_report%backend = active_linear_settings%backend
    call clear_convergence_history(report%history)
    residual = 0.0_dp

    call prepare_q9_herrmann_problem( &
        mesh,u,pressure_coefficients,residual,fixed_dofs,external_force, &
        shear_modulus,pressure_compliance,n_increments,max_iterations,tolerance, &
        is_fixed,free_dofs,report%status)
    if (report%status /= DES_STATUS_OK) return

    ndisp = 2*mesh%node_count()
    ntotal = ndisp + Q9_HERRMANN_P_DOF*mesh%element_count()
    nfree = size(free_dofs)
    increment_size = 1.0_dp/real(n_increments,dp)
    report%increments_requested = n_increments

    if (use_sparse_backend) then
      allocate(rhs_full(ntotal),delta_full(ntotal))
      call initialize_q9_plane_strain_herrmann_csr_pattern( &
          mesh%node_count(),mesh%q9_connectivity,K_csr,status)
      if (status /= DES_STATUS_OK) then
        report%status = status
        report%last_failure_status = status
        return
      end if
      call initialize_q9_herrmann_sparse_context( &
          K_csr,active_linear_settings,sparse_context,status)
      if (status /= DES_STATUS_OK) then
        report%status = status
        report%last_failure_status = status
        return
      end if
    else
      allocate(K(ntotal,ntotal),Kff(nfree,nfree),rhs(nfree),delta(nfree))
    end if

    call enforce_zero_displacement_dofs(u,fixed_dofs)

    do increment = 1,n_increments
      report%increments_attempted = report%increments_attempted + 1
      load_factor = real(increment,dp)/real(n_increments,dp)
      increment_converged = .false.

      do iteration = 1,max_iterations
        if (use_sparse_backend) then
          call assemble_q9_plane_strain_herrmann_mesh_csr_with_quadrature( &
              mesh%coordinates,mesh%q9_connectivity,u,pressure_coefficients, &
              shear_modulus,pressure_compliance,active_quadrature, &
              residual,K_csr,status,min_j)
        else
          call assemble_q9_internal_mesh_herrmann_with_quadrature( &
              mesh,u,pressure_coefficients,shear_modulus,pressure_compliance, &
              active_quadrature,residual,K,status,min_j)
        end if
        report%min_j = min(report%min_j,min_j)

        if (status /= DES_STATUS_OK) then
          call add_herrmann_history(report,increment,iteration,load_factor, &
              increment_size,huge(1.0_dp),min_j,status,.false.)
          report%status = status
          report%last_failure_status = status
          return
        end if

        residual(1:ndisp) = residual(1:ndisp) - load_factor*external_force
        residual_norm = maxval(abs(residual(free_dofs)))
        report%final_residual_norm = residual_norm

        if (residual_norm < tolerance) then
          call add_herrmann_history(report,increment,iteration,load_factor, &
              increment_size,residual_norm,min_j,DES_STATUS_OK,.true.)
          increment_converged = .true.
          report%increments_converged = increment
          report%final_load_factor = load_factor
          report%last_accepted_increment = increment_size
          report%max_iterations_used = max(report%max_iterations_used,iteration-1)
          exit
        end if

        if (use_sparse_backend) then
          rhs_full = -residual
          call csr_apply_zero_dirichlet(K_csr,rhs_full,fixed_dofs,status)
          if (status /= DES_STATUS_OK) then
            call add_herrmann_history(report,increment,iteration,load_factor, &
                increment_size,residual_norm,min_j,status,.false.)
            report%status = status
            report%last_failure_status = status
            return
          end if

          call factorize_sparse_matrix(sparse_context,K_csr,status)
          if (status /= DES_STATUS_OK) then
            call add_herrmann_history(report,increment,iteration,load_factor, &
                increment_size,residual_norm,min_j,status,.false.)
            report%status = status
            report%last_failure_status = status
            return
          end if
          call solve_sparse_with_context( &
              sparse_context,K_csr,rhs_full,delta_full,linear_report)
        else
          rhs = -residual(free_dofs)
          do a = 1,nfree
            do b = 1,nfree
              Kff(a,b) = K(free_dofs(a),free_dofs(b))
            end do
          end do

          call solve_linear_system( &
              Kff,rhs,delta,active_linear_settings,linear_report)
        end if

        call record_herrmann_linear_solve(report,linear_report)
        if (.not. linear_report%converged) then
          call add_herrmann_history(report,increment,iteration,load_factor, &
              increment_size,residual_norm,min_j,linear_report%status,.false.)
          report%status = linear_report%status
          report%last_failure_status = linear_report%status
          return
        end if

        call add_herrmann_history(report,increment,iteration,load_factor, &
            increment_size,residual_norm,min_j,DES_STATUS_OK,.false.)

        if (use_sparse_backend) then
          call add_mixed_increment( &
              u,pressure_coefficients,ndisp,free_dofs,delta_full(free_dofs))
        else
          call add_mixed_increment( &
              u,pressure_coefficients,ndisp,free_dofs,delta)
        end if
        call enforce_zero_displacement_dofs(u,fixed_dofs)
        report%total_iterations = report%total_iterations + 1
      end do

      if (.not. increment_converged) then
        call mark_last_convergence_status( &
            report%history,DES_ERROR_NEWTON_DID_NOT_CONVERGE)
        report%status = DES_ERROR_NEWTON_DID_NOT_CONVERGE
        report%last_failure_status = DES_ERROR_NEWTON_DID_NOT_CONVERGE
        return
      end if
    end do

    if (use_sparse_backend) then
      call finalize_q9_herrmann_solution_sparse( &
          mesh,shear_modulus,pressure_compliance,fixed_dofs,free_dofs,external_force, &
          tolerance,active_quadrature,u,pressure_coefficients,residual,K_csr,report)
      call release_sparse_solver_context(sparse_context)
    else
      call finalize_q9_herrmann_solution( &
          mesh,shear_modulus,pressure_compliance,fixed_dofs,free_dofs,external_force, &
          tolerance,active_quadrature,u,pressure_coefficients,residual,K,report)
    end if
  end subroutine solve_q9_internal_mesh_herrmann_force_control

  subroutine solve_q9_internal_mesh_herrmann_adaptive_force_control( &
      mesh, shear_modulus, pressure_compliance, fixed_dofs, external_force, &
      initial_increment, min_increment, cutback_factor, max_cutbacks, &
      max_iterations, tolerance, u, pressure_coefficients, residual, report, &
      linear_settings, quadrature_order, nonlinear_settings, adaptive_increment_settings, &
      growth_event_count, maximum_accepted_increment, predictor_settings, &
      predictor_event_count, maximum_predictor_scale)
    ! Q9/P1 Herrmann için adaptive production yolu.
    ! Displacement ve pressure trial state'leri aynı increment transaction'ının
    ! parçasıdır. Bir Newton denemesi başarısız olursa ikisi de committed state'e döner.
    !
    ! B8.1 ile her mixed [du,dp] Newton correction aynı damping katsayısı ile
    ! ölçeklenir. Full Newton alpha=1 ilk adaydır; residual yeterince azalmazsa
    ! backtracking yapılır. Line-search başarısızlığı increment cutback zincirine
    ! kontrollü nonlinear failure olarak aktarılır.
    !
    ! B8.2 ile residual, Newton correction ve mixed trial state üzerinde NaN/Inf
    ! değerleri explicit olarak reddedilir. Internal non-finite failure normal
    ! adaptive rollback/cutback zincirine girer; non-finite girişler fail-fast olur.
    !
    ! B8.3 growth policy yalnız başarılı mixed u-p commit'inden sonra çalışır.
    ! Aynı load increment'i içinde cutback görülmüşse veya Newton correction sayısı
    ! configured threshold'u aşıyorsa bir sonraki step büyütülmez.
    !
    ! B8.4 secant predictor iki ardışık committed mixed state farkını kullanır.
    ! u ve p aynı load-step oranıyla birlikte extrapolate edilir. Predictor yalnız
    ! trial state'i değiştirir ve cutback retry denemelerinde tekrar uygulanmaz.
    !
    ! Sparse backend seçildiğinde CSR graph yalnız bir kez kurulur. B4 context
    ! symbolic analysis ve ordering'i bu graph için bir kez yapar; Newton boyunca
    ! yalnız numeric values aşaması ve solve tekrarlanır.
    type(internal_mesh_t), intent(in) :: mesh
    real(dp), intent(in) :: shear_modulus, pressure_compliance
    integer, intent(in) :: fixed_dofs(:)
    real(dp), intent(in) :: external_force(:)
    real(dp), intent(in) :: initial_increment, min_increment, cutback_factor
    integer, intent(in) :: max_cutbacks, max_iterations
    real(dp), intent(in) :: tolerance
    real(dp), intent(inout) :: u(:,:), pressure_coefficients(:,:)
    real(dp), intent(out) :: residual(:)
    type(newton_report_t), intent(out) :: report
    type(linear_solver_settings_t), intent(in), optional :: linear_settings
    integer, intent(in), optional :: quadrature_order
    type(nonlinear_solver_settings_t), intent(in), optional :: nonlinear_settings
    type(adaptive_increment_settings_t), intent(in), optional :: adaptive_increment_settings
    integer, intent(out), optional :: growth_event_count
    real(dp), intent(out), optional :: maximum_accepted_increment
    type(adaptive_predictor_settings_t), intent(in), optional :: predictor_settings
    integer, intent(out), optional :: predictor_event_count
    real(dp), intent(out), optional :: maximum_predictor_scale

    logical, allocatable :: is_fixed(:)
    integer, allocatable :: free_dofs(:)
    real(dp), allocatable :: K(:,:), Kff(:,:), rhs(:), delta(:)
    real(dp), allocatable :: rhs_full(:), delta_full(:), correction(:)
    real(dp), allocatable :: base_u(:,:), base_pressure(:,:)
    real(dp), allocatable :: previous_committed_u(:,:), previous_committed_pressure(:,:)
    type(csr_matrix_t) :: K_csr
    type(sparse_solver_context_t) :: sparse_context
    type(solution_state_t) :: displacement_state, pressure_state
    real(dp) :: min_j, load_factor, target_factor, step, next_step, remaining_load
    real(dp) :: residual_norm, accepted_step, previous_residual_norm
    real(dp) :: correction_scale, candidate_residual_norm, candidate_min_j
    real(dp) :: predictor_scale, previous_accepted_step
    integer :: ndisp, ntotal, nfree, status, failure_status, active_quadrature
    integer :: iteration, a, b, attempt, line_search_trial, line_search_trials
    integer :: residual_growth_streak, nonfinite_stage
    logical :: increment_converged, use_sparse_backend, line_search_accepted
    logical :: finite_candidate_seen, nonfinite_candidate_seen
    logical :: increment_had_cutback, growth_applied
    logical :: have_previous_committed_state, predictor_applied, predictor_candidate_valid
    real(dp), parameter :: load_tol = 100.0_dp*epsilon(1.0_dp)
    type(linear_solver_settings_t) :: active_linear_settings
    type(linear_solver_report_t) :: linear_report
    type(nonlinear_solver_settings_t) :: active_nonlinear_settings
    type(adaptive_increment_settings_t) :: active_adaptive_settings
    type(adaptive_predictor_settings_t) :: active_predictor_settings

    active_linear_settings = production_linear_solver_settings()
    if (present(linear_settings)) active_linear_settings = linear_settings
    active_nonlinear_settings = nonlinear_solver_settings_t()
    if (present(nonlinear_settings)) active_nonlinear_settings = nonlinear_settings
    active_adaptive_settings = adaptive_increment_settings_t()
    if (present(adaptive_increment_settings)) then
      active_adaptive_settings = adaptive_increment_settings
    end if
    active_predictor_settings = adaptive_predictor_settings_t()
    if (present(predictor_settings)) active_predictor_settings = predictor_settings
    if (present(growth_event_count)) growth_event_count = 0
    if (present(maximum_accepted_increment)) maximum_accepted_increment = 0.0_dp
    if (present(predictor_event_count)) predictor_event_count = 0
    if (present(maximum_predictor_scale)) maximum_predictor_scale = 0.0_dp
    active_quadrature = Q9_HERRMANN_QUADRATURE_3X3
    if (present(quadrature_order)) active_quadrature = quadrature_order
    use_sparse_backend = linear_backend_is_sparse(active_linear_settings%backend)

    report = newton_report_t()
    report%last_linear_report%backend = active_linear_settings%backend
    call clear_convergence_history(report%history)
    residual = 0.0_dp

    if (.not. nonlinear_values_finite(initial_increment) .or. &
        .not. nonlinear_values_finite(min_increment) .or. &
        .not. nonlinear_values_finite(cutback_factor) .or. &
        .not. nonlinear_values_finite(tolerance) .or. &
        .not. nonlinear_values_finite(shear_modulus) .or. &
        .not. nonlinear_values_finite(pressure_compliance) .or. &
        .not. nonlinear_values_finite(external_force) .or. &
        .not. nonlinear_values_finite(u) .or. &
        .not. nonlinear_values_finite(pressure_coefficients)) then
      report%status = DES_ERROR_NONFINITE_NONLINEAR
      report%last_failure_status = DES_ERROR_NONFINITE_NONLINEAR
      return
    end if

    if (initial_increment <= 0.0_dp .or. initial_increment > 1.0_dp .or. &
        min_increment <= 0.0_dp .or. min_increment > initial_increment .or. &
        cutback_factor <= 0.0_dp .or. cutback_factor >= 1.0_dp .or. &
        max_cutbacks < 0 .or. &
        .not. nonlinear_solver_settings_valid(active_nonlinear_settings) .or. &
        .not. adaptive_increment_settings_valid(active_adaptive_settings) .or. &
        .not. adaptive_predictor_settings_valid(active_predictor_settings) .or. &
        (active_adaptive_settings%growth_enabled .and. &
         initial_increment > active_adaptive_settings%maximum_increment+load_tol)) then
      report%status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    call prepare_q9_herrmann_problem( &
        mesh,u,pressure_coefficients,residual,fixed_dofs,external_force, &
        shear_modulus,pressure_compliance,1,max_iterations,tolerance, &
        is_fixed,free_dofs,report%status)
    if (report%status /= DES_STATUS_OK) return

    ndisp = 2*mesh%node_count()
    ntotal = ndisp + Q9_HERRMANN_P_DOF*mesh%element_count()
    nfree = size(free_dofs)
    allocate(correction(nfree))
    allocate(base_u(size(u,1),size(u,2)))
    allocate(base_pressure(size(pressure_coefficients,1),size(pressure_coefficients,2)))
    allocate(previous_committed_u(size(u,1),size(u,2)))
    allocate(previous_committed_pressure( &
        size(pressure_coefficients,1),size(pressure_coefficients,2)))

    if (use_sparse_backend) then
      allocate(rhs_full(ntotal),delta_full(ntotal))
      call initialize_q9_plane_strain_herrmann_csr_pattern( &
          mesh%node_count(),mesh%q9_connectivity,K_csr,status)
      if (status /= DES_STATUS_OK) then
        report%status = status
        report%last_failure_status = status
        return
      end if
      call initialize_q9_herrmann_sparse_context( &
          K_csr,active_linear_settings,sparse_context,status)
      if (status /= DES_STATUS_OK) then
        report%status = status
        report%last_failure_status = status
        return
      end if
    else
      allocate(K(ntotal,ntotal),Kff(nfree,nfree),rhs(nfree),delta(nfree))
    end if

    call enforce_zero_displacement_dofs(u,fixed_dofs)
    call initialize_solution_state(displacement_state,u)
    call initialize_solution_state(pressure_state,pressure_coefficients)
    previous_committed_u = displacement_state%committed
    previous_committed_pressure = pressure_state%committed

    load_factor = 0.0_dp
    step = initial_increment
    previous_accepted_step = 0.0_dp
    increment_had_cutback = .false.
    have_previous_committed_state = .false.
    report%increments_requested = ceiling(1.0_dp/initial_increment)

    do while (load_factor < 1.0_dp-load_tol)
      report%increments_attempted = report%increments_attempted + 1
      attempt = report%increments_attempted
      target_factor = min(1.0_dp,load_factor+step)
      accepted_step = target_factor-load_factor

      call begin_solution_trial(displacement_state)
      call begin_solution_trial(pressure_state)
      call enforce_zero_displacement_dofs(displacement_state%trial,fixed_dofs)

      call select_secant_predictor_scale( &
          accepted_step,previous_accepted_step,have_previous_committed_state, &
          increment_had_cutback,active_predictor_settings,predictor_scale, &
          predictor_applied)
      if (predictor_applied) then
        call build_mixed_secant_predictor( &
            previous_committed_u,displacement_state%committed, &
            previous_committed_pressure,pressure_state%committed,predictor_scale, &
            displacement_state%trial,pressure_state%trial,predictor_candidate_valid)
        predictor_applied = predictor_candidate_valid
        call enforce_zero_displacement_dofs(displacement_state%trial,fixed_dofs)
        if (predictor_applied) then
          if (present(predictor_event_count)) predictor_event_count = predictor_event_count + 1
          if (present(maximum_predictor_scale)) then
            maximum_predictor_scale = max(maximum_predictor_scale,predictor_scale)
          end if
        end if
      end if

      increment_converged = .false.
      failure_status = DES_ERROR_NEWTON_DID_NOT_CONVERGE
      previous_residual_norm = huge(1.0_dp)
      residual_growth_streak = 0
      nonfinite_stage = DES_NONFINITE_STAGE_NONE
      min_j = huge(1.0_dp)

      do iteration = 1,max_iterations
        if (.not. nonlinear_values_finite(displacement_state%trial) .or. &
            .not. nonlinear_values_finite(pressure_state%trial)) then
          nonfinite_stage = DES_NONFINITE_STAGE_TRIAL_STATE
          call add_herrmann_history(report,attempt,iteration,target_factor, &
              accepted_step,huge(1.0_dp),min_j,DES_ERROR_NONFINITE_NONLINEAR,.false., &
              nonfinite_stage=nonfinite_stage)
          failure_status = DES_ERROR_NONFINITE_NONLINEAR
          exit
        end if

        if (use_sparse_backend) then
          call assemble_q9_plane_strain_herrmann_mesh_csr_with_quadrature( &
              mesh%coordinates,mesh%q9_connectivity,displacement_state%trial, &
              pressure_state%trial,shear_modulus,pressure_compliance, &
              active_quadrature,residual,K_csr,status,min_j)
        else
          call assemble_q9_internal_mesh_herrmann_with_quadrature( &
              mesh,displacement_state%trial,pressure_state%trial, &
              shear_modulus,pressure_compliance,active_quadrature, &
              residual,K,status,min_j)
        end if
        report%min_j = min(report%min_j,min_j)

        if (status /= DES_STATUS_OK) then
          call add_herrmann_history(report,attempt,iteration,target_factor, &
              accepted_step,huge(1.0_dp),min_j,status,.false.)
          failure_status = status
          exit
        end if

        residual(1:ndisp) = residual(1:ndisp) - target_factor*external_force
        if (.not. nonlinear_values_finite(residual) .or. &
            .not. nonlinear_values_finite(min_j)) then
          nonfinite_stage = DES_NONFINITE_STAGE_RESIDUAL
          call add_herrmann_history(report,attempt,iteration,target_factor, &
              accepted_step,huge(1.0_dp),min_j,DES_ERROR_NONFINITE_NONLINEAR,.false., &
              nonfinite_stage=nonfinite_stage)
          failure_status = DES_ERROR_NONFINITE_NONLINEAR
          exit
        end if

        residual_norm = maxval(abs(residual(free_dofs)))
        report%final_residual_norm = residual_norm

        if (iteration > 1) then
          residual_growth_streak = next_residual_growth_streak( &
              previous_residual_norm,residual_norm,residual_growth_streak, &
              active_nonlinear_settings)
          if (residual_growth_streak >= &
              active_nonlinear_settings%residual_growth_patience) then
            call add_herrmann_history(report,attempt,iteration,target_factor, &
                accepted_step,residual_norm,min_j,DES_ERROR_NONLINEAR_DIVERGENCE,.false.)
            failure_status = DES_ERROR_NONLINEAR_DIVERGENCE
            exit
          end if
        end if
        previous_residual_norm = residual_norm

        if (residual_norm < tolerance) then
          call add_herrmann_history(report,attempt,iteration,target_factor, &
              accepted_step,residual_norm,min_j,DES_STATUS_OK,.true.)
          increment_converged = .true.
          report%max_iterations_used = max(report%max_iterations_used,iteration-1)
          exit
        end if

        if (use_sparse_backend) then
          rhs_full = -residual
          call csr_apply_zero_dirichlet(K_csr,rhs_full,fixed_dofs,status)
          if (status /= DES_STATUS_OK) then
            call add_herrmann_history(report,attempt,iteration,target_factor, &
                accepted_step,residual_norm,min_j,status,.false.)
            failure_status = status
            exit
          end if

          call factorize_sparse_matrix(sparse_context,K_csr,status)
          if (status /= DES_STATUS_OK) then
            call add_herrmann_history(report,attempt,iteration,target_factor, &
                accepted_step,residual_norm,min_j,status,.false.)
            failure_status = status
            exit
          end if
          call solve_sparse_with_context( &
              sparse_context,K_csr,rhs_full,delta_full,linear_report)
        else
          rhs = -residual(free_dofs)
          do a = 1,nfree
            do b = 1,nfree
              Kff(a,b) = K(free_dofs(a),free_dofs(b))
            end do
          end do

          call solve_linear_system( &
              Kff,rhs,delta,active_linear_settings,linear_report)
        end if
        call record_herrmann_linear_solve(report,linear_report)
        if (.not. linear_report%converged) then
          call add_herrmann_history(report,attempt,iteration,target_factor, &
              accepted_step,residual_norm,min_j,linear_report%status,.false.)
          failure_status = linear_report%status
          exit
        end if

        if (use_sparse_backend) then
          correction = delta_full(free_dofs)
        else
          correction = delta
        end if
        if (.not. nonlinear_values_finite(correction)) then
          nonfinite_stage = DES_NONFINITE_STAGE_CORRECTION
          call add_herrmann_history(report,attempt,iteration,target_factor, &
              accepted_step,residual_norm,min_j,DES_ERROR_NONFINITE_NONLINEAR,.false., &
              nonfinite_stage=nonfinite_stage)
          failure_status = DES_ERROR_NONFINITE_NONLINEAR
          exit
        end if

        if (.not. active_nonlinear_settings%line_search_enabled) then
          correction_scale = 1.0_dp
          line_search_trials = 0
          call add_mixed_increment( &
              displacement_state%trial,pressure_state%trial,ndisp,free_dofs,correction)
          call enforce_zero_displacement_dofs(displacement_state%trial,fixed_dofs)
          if (.not. nonlinear_values_finite(displacement_state%trial) .or. &
              .not. nonlinear_values_finite(pressure_state%trial)) then
            nonfinite_stage = DES_NONFINITE_STAGE_TRIAL_STATE
            call add_herrmann_history(report,attempt,iteration,target_factor, &
                accepted_step,residual_norm,min_j,DES_ERROR_NONFINITE_NONLINEAR,.false., &
                correction_scale,line_search_trials,nonfinite_stage)
            failure_status = DES_ERROR_NONFINITE_NONLINEAR
            exit
          end if
          call add_herrmann_history(report,attempt,iteration,target_factor, &
              accepted_step,residual_norm,min_j,DES_STATUS_OK,.false., &
              correction_scale,line_search_trials)
        else
          base_u = displacement_state%trial
          base_pressure = pressure_state%trial
          correction_scale = 1.0_dp
          line_search_trials = 0
          line_search_accepted = .false.
          finite_candidate_seen = .false.
          nonfinite_candidate_seen = .false.
          nonfinite_stage = DES_NONFINITE_STAGE_NONE
          candidate_residual_norm = huge(1.0_dp)
          candidate_min_j = min_j

          do line_search_trial = 1,active_nonlinear_settings%line_search_max_trials
            if (correction_scale < &
                active_nonlinear_settings%line_search_min_scale-load_tol) exit

            line_search_trials = line_search_trial
            displacement_state%trial = base_u
            pressure_state%trial = base_pressure
            call add_mixed_increment( &
                displacement_state%trial,pressure_state%trial,ndisp,free_dofs, &
                correction_scale*correction)
            call enforce_zero_displacement_dofs(displacement_state%trial,fixed_dofs)

            if (.not. nonlinear_values_finite(displacement_state%trial) .or. &
                .not. nonlinear_values_finite(pressure_state%trial)) then
              nonfinite_candidate_seen = .true.
              nonfinite_stage = DES_NONFINITE_STAGE_TRIAL_STATE
              correction_scale = correction_scale* &
                  active_nonlinear_settings%line_search_reduction
              cycle
            end if

            if (use_sparse_backend) then
              call assemble_q9_plane_strain_herrmann_mesh_csr_with_quadrature( &
                  mesh%coordinates,mesh%q9_connectivity,displacement_state%trial, &
                  pressure_state%trial,shear_modulus,pressure_compliance, &
                  active_quadrature,residual,K_csr,status,candidate_min_j)
            else
              call assemble_q9_internal_mesh_herrmann_with_quadrature( &
                  mesh,displacement_state%trial,pressure_state%trial, &
                  shear_modulus,pressure_compliance,active_quadrature, &
                  residual,K,status,candidate_min_j)
            end if
            report%min_j = min(report%min_j,candidate_min_j)

            if (status == DES_STATUS_OK) then
              residual(1:ndisp) = residual(1:ndisp) - target_factor*external_force
              if (nonlinear_values_finite(residual) .and. &
                  nonlinear_values_finite(candidate_min_j)) then
                finite_candidate_seen = .true.
                candidate_residual_norm = maxval(abs(residual(free_dofs)))
                if (candidate_residual_norm < tolerance .or. &
                    line_search_residual_accepted( &
                        residual_norm,candidate_residual_norm,correction_scale, &
                        active_nonlinear_settings)) then
                  line_search_accepted = .true.
                  exit
                end if
              else
                nonfinite_candidate_seen = .true.
                nonfinite_stage = DES_NONFINITE_STAGE_RESIDUAL
              end if
            end if

            correction_scale = correction_scale* &
                active_nonlinear_settings%line_search_reduction
          end do

          if (.not. line_search_accepted) then
            displacement_state%trial = base_u
            pressure_state%trial = base_pressure
            call enforce_zero_displacement_dofs(displacement_state%trial,fixed_dofs)
            if (nonfinite_candidate_seen .and. .not. finite_candidate_seen) then
              call add_herrmann_history(report,attempt,iteration,target_factor, &
                  accepted_step,residual_norm,candidate_min_j, &
                  DES_ERROR_NONFINITE_NONLINEAR,.false., &
                  correction_scale,line_search_trials,nonfinite_stage)
              failure_status = DES_ERROR_NONFINITE_NONLINEAR
            else
              call add_herrmann_history(report,attempt,iteration,target_factor, &
                  accepted_step,residual_norm,candidate_min_j, &
                  DES_ERROR_LINE_SEARCH_FAILED,.false., &
                  correction_scale,line_search_trials)
              failure_status = DES_ERROR_LINE_SEARCH_FAILED
            end if
            exit
          end if

          call add_herrmann_history(report,attempt,iteration,target_factor, &
              accepted_step,residual_norm,candidate_min_j,DES_STATUS_OK,.false., &
              correction_scale,line_search_trials)
        end if

        report%total_iterations = report%total_iterations + 1
      end do

      if (increment_converged) then
        previous_committed_u = displacement_state%committed
        previous_committed_pressure = pressure_state%committed
        call commit_solution_state(displacement_state)
        call commit_solution_state(pressure_state)
        load_factor = target_factor
        report%increments_converged = report%increments_converged + 1
        report%final_load_factor = load_factor
        report%last_accepted_increment = accepted_step
        previous_accepted_step = accepted_step
        have_previous_committed_state = .true.
        if (present(maximum_accepted_increment)) then
          maximum_accepted_increment = max(maximum_accepted_increment,accepted_step)
        end if

        remaining_load = max(0.0_dp,1.0_dp-load_factor)
        call select_next_adaptive_increment( &
            step,remaining_load,max(0,iteration-1),increment_had_cutback, &
            active_adaptive_settings,next_step,growth_applied)
        if (growth_applied .and. present(growth_event_count)) then
          growth_event_count = growth_event_count + 1
        end if
        step = next_step
        increment_had_cutback = .false.
      else
        if (failure_status == DES_ERROR_NEWTON_DID_NOT_CONVERGE) then
          call mark_last_convergence_status(report%history,failure_status)
        end if

        report%last_failure_status = failure_status
        call revert_solution_state(displacement_state)
        call revert_solution_state(pressure_state)
        call copy_mixed_state_counters(displacement_state,pressure_state,report)

        if (failure_status == DES_ERROR_UNSUPPORTED_LINEAR_BACKEND) then
          u = displacement_state%committed
          pressure_coefficients = pressure_state%committed
          report%status = failure_status
          return
        end if

        report%cutback_count = report%cutback_count + 1
        if (report%cutback_count > max_cutbacks) then
          u = displacement_state%committed
          pressure_coefficients = pressure_state%committed
          report%final_load_factor = load_factor
          report%status = DES_ERROR_CUTBACK_EXHAUSTED
          return
        end if

        step = step*cutback_factor
        if (step < min_increment-load_tol) then
          u = displacement_state%committed
          pressure_coefficients = pressure_state%committed
          report%final_load_factor = load_factor
          report%status = DES_ERROR_CUTBACK_EXHAUSTED
          return
        end if
        increment_had_cutback = .true.
      end if

      call copy_mixed_state_counters(displacement_state,pressure_state,report)
    end do

    u = displacement_state%committed
    pressure_coefficients = pressure_state%committed
    call copy_mixed_state_counters(displacement_state,pressure_state,report)

    if (use_sparse_backend) then
      call finalize_q9_herrmann_solution_sparse( &
          mesh,shear_modulus,pressure_compliance,fixed_dofs,free_dofs,external_force, &
          tolerance,active_quadrature,u,pressure_coefficients,residual,K_csr,report)
      call release_sparse_solver_context(sparse_context)
    else
      call finalize_q9_herrmann_solution( &
          mesh,shear_modulus,pressure_compliance,fixed_dofs,free_dofs,external_force, &
          tolerance,active_quadrature,u,pressure_coefficients,residual,K,report)
    end if
  end subroutine solve_q9_internal_mesh_herrmann_adaptive_force_control

  subroutine finalize_q9_herrmann_solution( &
      mesh,shear_modulus,pressure_compliance,fixed_dofs,free_dofs,external_force, &
      tolerance,quadrature_order,u,pressure_coefficients,residual,K,report)
    type(internal_mesh_t), intent(in) :: mesh
    real(dp), intent(in) :: shear_modulus, pressure_compliance
    integer, intent(in) :: fixed_dofs(:), free_dofs(:), quadrature_order
    real(dp), intent(in) :: external_force(:), tolerance
    real(dp), intent(inout) :: u(:,:), pressure_coefficients(:,:)
    real(dp), intent(out) :: residual(:)
    real(dp), intent(inout) :: K(:,:)
    type(newton_report_t), intent(inout) :: report

    real(dp) :: min_j
    integer :: ndisp, status

    ndisp = 2*mesh%node_count()
    call enforce_zero_displacement_dofs(u,fixed_dofs)
    call assemble_q9_internal_mesh_herrmann_with_quadrature( &
        mesh,u,pressure_coefficients,shear_modulus,pressure_compliance, &
        quadrature_order,residual,K,status,min_j)
    report%min_j = min(report%min_j,min_j)
    if (status /= DES_STATUS_OK) then
      report%status = status
      report%last_failure_status = status
      report%converged = .false.
      return
    end if

    residual(1:ndisp) = residual(1:ndisp) - external_force
    report%final_residual_norm = maxval(abs(residual(free_dofs)))
    report%final_load_factor = 1.0_dp
    report%status = DES_STATUS_OK
    report%converged = report%final_residual_norm < tolerance
    if (.not. report%converged) then
      report%status = DES_ERROR_NEWTON_DID_NOT_CONVERGE
      report%last_failure_status = DES_ERROR_NEWTON_DID_NOT_CONVERGE
    end if
  end subroutine finalize_q9_herrmann_solution

  subroutine finalize_q9_herrmann_solution_sparse( &
      mesh,shear_modulus,pressure_compliance,fixed_dofs,free_dofs,external_force, &
      tolerance,quadrature_order,u,pressure_coefficients,residual,K,report)
    ! Sparse finalization yalnız residual ve min(J) için yeniden assemble eder;
    ! final rapor üretmek amacıyla dense global tangent materialize edilmez.
    type(internal_mesh_t), intent(in) :: mesh
    real(dp), intent(in) :: shear_modulus, pressure_compliance
    integer, intent(in) :: fixed_dofs(:), free_dofs(:), quadrature_order
    real(dp), intent(in) :: external_force(:), tolerance
    real(dp), intent(inout) :: u(:,:), pressure_coefficients(:,:)
    real(dp), intent(out) :: residual(:)
    type(csr_matrix_t), intent(inout) :: K
    type(newton_report_t), intent(inout) :: report

    real(dp) :: min_j
    integer :: ndisp, status

    ndisp = 2*mesh%node_count()
    call enforce_zero_displacement_dofs(u,fixed_dofs)
    call assemble_q9_plane_strain_herrmann_mesh_csr_with_quadrature( &
        mesh%coordinates,mesh%q9_connectivity,u,pressure_coefficients, &
        shear_modulus,pressure_compliance,quadrature_order,residual,K,status,min_j)
    report%min_j = min(report%min_j,min_j)
    if (status /= DES_STATUS_OK) then
      report%status = status
      report%last_failure_status = status
      report%converged = .false.
      return
    end if

    residual(1:ndisp) = residual(1:ndisp) - external_force
    report%final_residual_norm = maxval(abs(residual(free_dofs)))
    report%final_load_factor = 1.0_dp
    report%status = DES_STATUS_OK
    report%converged = report%final_residual_norm < tolerance
    if (.not. report%converged) then
      report%status = DES_ERROR_NEWTON_DID_NOT_CONVERGE
      report%last_failure_status = DES_ERROR_NEWTON_DID_NOT_CONVERGE
    end if
  end subroutine finalize_q9_herrmann_solution_sparse

  subroutine initialize_q9_herrmann_sparse_context( &
      matrix,settings,context,status)
    type(csr_matrix_t), intent(in) :: matrix
    type(linear_solver_settings_t), intent(in) :: settings
    type(sparse_solver_context_t), intent(out) :: context
    integer, intent(out) :: status

    call create_sparse_solver_context( &
        context,settings,DES_MATRIX_CLASS_SYMMETRIC_INDEFINITE, &
        DES_PROBLEM_CLASS_MIXED_U_P,DES_INDEX_CLASS_INT32,status)
    if (status /= DES_STATUS_OK) return

    call analyze_sparse_pattern(context,matrix,status)
    if (status /= DES_STATUS_OK) return

    call reorder_sparse_pattern(context,status)
  end subroutine initialize_q9_herrmann_sparse_context

  subroutine prepare_q9_herrmann_problem( &
      mesh,u,pressure_coefficients,residual,fixed_dofs,external_force, &
      shear_modulus,pressure_compliance,n_increments,max_iterations,tolerance, &
      is_fixed,free_dofs,status)
    type(internal_mesh_t), intent(in) :: mesh
    real(dp), intent(in) :: u(:,:), pressure_coefficients(:,:), residual(:)
    integer, intent(in) :: fixed_dofs(:), n_increments, max_iterations
    real(dp), intent(in) :: external_force(:), shear_modulus, pressure_compliance
    real(dp), intent(in) :: tolerance
    logical, allocatable, intent(out) :: is_fixed(:)
    integer, allocatable, intent(out) :: free_dofs(:)
    integer, intent(out) :: status

    integer :: nnode, nelem, ndisp, ntotal, nfree
    integer :: a, dof, cursor, mesh_status

    status = DES_STATUS_OK
    call validate_internal_mesh(mesh,mesh_status)
    if (mesh_status /= DES_STATUS_OK) then
      status = mesh_status
      return
    end if
    if (.not. mesh%is_q9()) then
      status = DES_ERROR_INVALID_CONNECTIVITY
      return
    end if

    nnode = mesh%node_count()
    nelem = mesh%element_count()
    ndisp = 2*nnode
    ntotal = ndisp + Q9_HERRMANN_P_DOF*nelem

    if (shear_modulus <= 0.0_dp .or. pressure_compliance < 0.0_dp) then
      status = DES_ERROR_INVALID_PARAMETERS
      return
    end if
    if (size(u,1) /= nnode .or. size(u,2) /= 2) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if
    if (size(pressure_coefficients,1) /= nelem .or. &
        size(pressure_coefficients,2) /= Q9_HERRMANN_P_DOF) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if
    if (size(residual) /= ntotal .or. size(external_force) /= ndisp) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if
    if (size(fixed_dofs) < 1 .or. n_increments < 1 .or. &
        max_iterations < 1 .or. tolerance <= 0.0_dp) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    allocate(is_fixed(ntotal))
    is_fixed = .false.
    do a = 1,size(fixed_dofs)
      dof = fixed_dofs(a)
      if (dof < 1 .or. dof > ndisp .or. is_fixed(dof)) then
        status = DES_ERROR_INVALID_CONSTRAINT
        return
      end if
      is_fixed(dof) = .true.
    end do

    nfree = count(.not. is_fixed)
    if (nfree < 1) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    allocate(free_dofs(nfree))
    cursor = 0
    do dof = 1,ntotal
      if (.not. is_fixed(dof)) then
        cursor = cursor + 1
        free_dofs(cursor) = dof
      end if
    end do
  end subroutine prepare_q9_herrmann_problem

  subroutine add_mixed_increment( &
      u,pressure_coefficients,ndisp,free_dofs,delta)
    real(dp), intent(inout) :: u(:,:), pressure_coefficients(:,:)
    integer, intent(in) :: ndisp, free_dofs(:)
    real(dp), intent(in) :: delta(:)

    integer :: a, dof, node, comp, pressure_index, element_id, pressure_mode

    do a = 1,size(free_dofs)
      dof = free_dofs(a)
      if (dof <= ndisp) then
        node = (dof+1)/2
        comp = dof-2*(node-1)
        u(node,comp) = u(node,comp) + delta(a)
      else
        pressure_index = dof-ndisp
        element_id = (pressure_index-1)/Q9_HERRMANN_P_DOF + 1
        pressure_mode = mod(pressure_index-1,Q9_HERRMANN_P_DOF) + 1
        pressure_coefficients(element_id,pressure_mode) = &
            pressure_coefficients(element_id,pressure_mode) + delta(a)
      end if
    end do
  end subroutine add_mixed_increment

  subroutine enforce_zero_displacement_dofs(u,fixed_dofs)
    real(dp), intent(inout) :: u(:,:)
    integer, intent(in) :: fixed_dofs(:)
    integer :: a, dof, node, comp

    do a = 1,size(fixed_dofs)
      dof = fixed_dofs(a)
      node = (dof+1)/2
      comp = dof-2*(node-1)
      u(node,comp) = 0.0_dp
    end do
  end subroutine enforce_zero_displacement_dofs

  subroutine record_herrmann_linear_solve(report,linear_report)
    type(newton_report_t), intent(inout) :: report
    type(linear_solver_report_t), intent(in) :: linear_report

    report%linear_solve_count = report%linear_solve_count + 1
    report%last_linear_report = linear_report
    report%max_linear_equation_count = max( &
        report%max_linear_equation_count,linear_report%equation_count)
    if (linear_report%converged) then
      report%max_linear_residual_inf_norm = max( &
          report%max_linear_residual_inf_norm,linear_report%residual_inf_norm)
    end if
  end subroutine record_herrmann_linear_solve

  subroutine copy_mixed_state_counters(displacement_state,pressure_state,report)
    type(solution_state_t), intent(in) :: displacement_state, pressure_state
    type(newton_report_t), intent(inout) :: report

    ! Her increment transaction'ında iki state birlikte commit/revert edilir.
    ! Report counter tek logical transaction sayısını displacement state üzerinden taşır.
    report%state_commit_count = displacement_state%commit_count
    report%state_revert_count = displacement_state%revert_count

    ! Bu iki karşılaştırma bir assertion yerine dokümantasyon amaçlıdır; aynı işlem
    ! sırası korunarak iki state counter'ının eşit kalması solver invariantıdır.
    if (pressure_state%commit_count < 0 .or. pressure_state%revert_count < 0) return
  end subroutine copy_mixed_state_counters

  subroutine add_herrmann_history( &
      report,attempt,iteration,load_factor,increment_size,residual_norm, &
      min_j,status,accepted,correction_scale,line_search_trials,nonfinite_stage)
    type(newton_report_t), intent(inout) :: report
    integer, intent(in) :: attempt, iteration, status
    real(dp), intent(in) :: load_factor, increment_size, residual_norm, min_j
    logical, intent(in) :: accepted
    real(dp), intent(in), optional :: correction_scale
    integer, intent(in), optional :: line_search_trials, nonfinite_stage
    type(convergence_record_t) :: record

    record%attempt = attempt
    record%iteration = iteration
    record%load_factor = load_factor
    record%increment_size = increment_size
    record%residual_norm = residual_norm
    record%min_j = min_j
    record%status = status
    record%accepted = accepted
    record%cutback_index = report%cutback_count
    if (present(correction_scale)) record%correction_scale = correction_scale
    if (present(line_search_trials)) record%line_search_trials = line_search_trials
    if (present(nonfinite_stage)) record%nonfinite_stage = nonfinite_stage
    call append_convergence_record(report%history,record)
  end subroutine add_herrmann_history

end module des_q9_plane_strain_herrmann_force_solver
