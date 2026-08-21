module des_2d_q8_herrmann_force_solver
  use des_kinds, only : dp, i64
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONSTRAINT, &
      DES_ERROR_INVALID_PARAMETERS, DES_ERROR_NEWTON_DID_NOT_CONVERGE, &
      DES_ERROR_CUTBACK_EXHAUSTED, DES_ERROR_UNSUPPORTED_LINEAR_BACKEND, &
      DES_ERROR_LINE_SEARCH_FAILED, DES_ERROR_NONLINEAR_DIVERGENCE, &
      DES_ERROR_NONFINITE_NONLINEAR
  use des_2d_mesh_database, only : mesh_database_2d_t, validate_2d_mesh_database
  use des_2d_dof_manager, only : dof_layout_2d_t
  use des_2d_q8_herrmann_assembly, only : initialize_2d_q8_herrmann_csr_pattern, &
      assemble_2d_q8_herrmann_csr
  use des_csr_matrix, only : csr_matrix_t, csr_apply_zero_dirichlet_i64
  use des_linear_solver, only : linear_solver_settings_t, linear_solver_report_t, &
      production_linear_solver_settings
  use des_sparse_solver_context, only : sparse_solver_context_t, &
      create_sparse_solver_context, analyze_sparse_pattern, reorder_sparse_pattern, &
      factorize_sparse_matrix, solve_sparse_with_context, release_sparse_solver_context, &
      DES_MATRIX_CLASS_SYMMETRIC_INDEFINITE, DES_PROBLEM_CLASS_MIXED_U_P, &
      DES_INDEX_CLASS_INT32
  use des_q4_plane_strain_newton_solver, only : newton_report_t
  use des_solver_history, only : convergence_record_t, append_convergence_record
  use des_nonlinear_solver, only : nonlinear_solver_settings_t, &
      nonlinear_solver_settings_valid, line_search_residual_accepted, &
      next_residual_growth_streak, nonlinear_values_finite, &
      DES_NONFINITE_STAGE_NONE, DES_NONFINITE_STAGE_RESIDUAL, &
      DES_NONFINITE_STAGE_CORRECTION, DES_NONFINITE_STAGE_TRIAL_STATE
  implicit none
  private

  public :: solve_2d_q8_herrmann_force_control
  public :: solve_2d_q8_herrmann_adaptive_force_control

contains

  subroutine solve_2d_q8_herrmann_force_control( &
      mesh, layout, shear_modulus, pressure_compliance, fixed_equations, &
      external_load, n_increments, max_iterations, tolerance, state, residual, &
      report, linear_settings)
    ! Field-based 2D Q8/P1 Herrmann fixed-increment sparse Newton slice.
    !
    ! Unknown vector doğrudan dof_layout_2d_t sırasını kullanır:
    !   [nodal kinematic DOF] + [generalized kinematic DOF] + [pressure DOF].
    ! Plane-strain, axisymmetric ve axisymmetric-with-torsion aynı sparse Newton
    ! lifecycle'ını paylaşır; element dispatch assembly katmanında yapılır.
    type(mesh_database_2d_t), intent(in) :: mesh
    type(dof_layout_2d_t), intent(in) :: layout
    real(dp), intent(in) :: shear_modulus, pressure_compliance
    integer(i64), intent(in) :: fixed_equations(:)
    real(dp), intent(in) :: external_load(:)
    integer, intent(in) :: n_increments, max_iterations
    real(dp), intent(in) :: tolerance
    real(dp), intent(inout) :: state(:)
    real(dp), intent(out) :: residual(:)
    type(newton_report_t), intent(out) :: report
    type(linear_solver_settings_t), intent(in), optional :: linear_settings

    type(csr_matrix_t) :: tangent
    type(sparse_solver_context_t) :: sparse_context
    type(linear_solver_settings_t) :: active_linear_settings
    type(linear_solver_report_t) :: linear_report
    logical, allocatable :: is_fixed(:)
    integer(i64), allocatable :: free_equations(:)
    real(dp), allocatable :: rhs(:), correction(:), committed_state(:)
    real(dp) :: load_factor, increment_size, residual_norm, min_j
    integer :: increment, iteration, status
    logical :: increment_converged, context_active

    report = newton_report_t()
    residual = 0.0_dp
    context_active = .false.

    active_linear_settings = production_linear_solver_settings()
    if (present(linear_settings)) active_linear_settings = linear_settings
    report%last_linear_report%requested_backend = active_linear_settings%backend
    report%last_linear_report%backend = active_linear_settings%backend

    call prepare_2d_q8_force_problem( &
        mesh,layout,fixed_equations,external_load,n_increments,max_iterations, &
        tolerance,shear_modulus,pressure_compliance,state,residual, &
        is_fixed,free_equations,status)
    if (status /= DES_STATUS_OK) then
      report%status = status
      report%last_failure_status = status
      return
    end if

    allocate(rhs(size(state)),correction(size(state)),committed_state(size(state)))
    call enforce_zero_fixed_state(state,fixed_equations)
    committed_state = state

    call initialize_2d_q8_sparse_context( &
        mesh,layout,active_linear_settings,tangent,sparse_context,context_active,status)
    if (status /= DES_STATUS_OK) then
      report%status = status
      report%last_failure_status = status
      return
    end if

    increment_size = 1.0_dp/real(n_increments,dp)
    report%increments_requested = n_increments

    do increment = 1,n_increments
      report%increments_attempted = report%increments_attempted + 1
      load_factor = real(increment,dp)/real(n_increments,dp)
      state = committed_state
      increment_converged = .false.

      do iteration = 1,max_iterations
        call assemble_2d_q8_herrmann_csr( &
            mesh,layout,state,shear_modulus,pressure_compliance, &
            residual,tangent,status,min_j)
        report%min_j = min(report%min_j,min_j)
        if (status /= DES_STATUS_OK) then
          state = committed_state
          report%state_revert_count = report%state_revert_count + 1
          call fail_with_context(report,status,sparse_context,context_active)
          return
        end if

        residual = residual-load_factor*external_load
        residual_norm = maxval(abs(residual(free_equations)))
        report%final_residual_norm = residual_norm

        if (residual_norm < tolerance) then
          increment_converged = .true.
          committed_state = state
          report%state_commit_count = report%state_commit_count + 1
          report%increments_converged = increment
          report%final_load_factor = load_factor
          report%last_accepted_increment = increment_size
          report%max_iterations_used = max(report%max_iterations_used,iteration-1)
          call append_q8_history(report,report%increments_attempted,iteration, &
              load_factor,increment_size,residual_norm,min_j,DES_STATUS_OK,.true., &
              0,1.0_dp,DES_NONFINITE_STAGE_NONE)
          exit
        end if

        rhs = -residual
        call csr_apply_zero_dirichlet_i64(tangent,rhs,fixed_equations,status)
        if (status /= DES_STATUS_OK) then
          state = committed_state
          report%state_revert_count = report%state_revert_count + 1
          call fail_with_context(report,status,sparse_context,context_active)
          return
        end if

        call factorize_sparse_matrix(sparse_context,tangent,status)
        if (status /= DES_STATUS_OK) then
          state = committed_state
          report%state_revert_count = report%state_revert_count + 1
          call fail_with_context(report,status,sparse_context,context_active)
          return
        end if

        call solve_sparse_with_context( &
            sparse_context,tangent,rhs,correction,linear_report)
        call record_linear_solve(report,linear_report)
        if (.not. linear_report%converged) then
          state = committed_state
          report%state_revert_count = report%state_revert_count + 1
          call fail_with_context( &
              report,linear_report%status,sparse_context,context_active)
          return
        end if

        state(free_equations) = state(free_equations)+correction(free_equations)
        call enforce_zero_fixed_state(state,fixed_equations)
        call append_q8_history(report,report%increments_attempted,iteration, &
            load_factor,increment_size,residual_norm,min_j,DES_STATUS_OK,.false., &
            0,1.0_dp,DES_NONFINITE_STAGE_NONE)
        report%total_iterations = report%total_iterations + 1
      end do

      if (.not. increment_converged) then
        state = committed_state
        report%state_revert_count = report%state_revert_count + 1
        call fail_with_context( &
            report,DES_ERROR_NEWTON_DID_NOT_CONVERGE,sparse_context,context_active)
        return
      end if
    end do

    state = committed_state
    call finalize_2d_q8_force_solution( &
        mesh,layout,shear_modulus,pressure_compliance,external_load,free_equations, &
        tolerance,state,residual,tangent,report,status)
    if (status /= DES_STATUS_OK) then
      call fail_with_context(report,status,sparse_context,context_active)
      return
    end if

    if (context_active) then
      call release_sparse_solver_context(sparse_context)
      context_active = .false.
    end if
  end subroutine solve_2d_q8_herrmann_force_control

  subroutine solve_2d_q8_herrmann_adaptive_force_control( &
      mesh, layout, shear_modulus, pressure_compliance, fixed_equations, &
      external_load, initial_increment, min_increment, cutback_factor, max_cutbacks, &
      max_iterations, tolerance, state, residual, report, linear_settings, &
      nonlinear_settings)
    ! C4 adaptive production integration.
    !
    ! Her load attempt'i committed flat mixed state'ten başlar. State vector hem
    ! displacement/twist hem pressure bilinmeyenlerini taşıdığı için rollback tek
    ! transaction ile bütün mixed alanları birlikte geri alır.
    !
    ! Full Newton correction ilk line-search adayıdır. Yeterli residual azalması
    ! yoksa aynı correction ölçeklenir. Element/linear/nonfinite/line-search failure
    ! cutback ile yeniden denenir; unsupported backend load-step failure sayılmaz ve
    ! doğrudan fail-fast döner. CSR graph/context bütün retry'lar boyunca korunur.
    type(mesh_database_2d_t), intent(in) :: mesh
    type(dof_layout_2d_t), intent(in) :: layout
    real(dp), intent(in) :: shear_modulus, pressure_compliance
    integer(i64), intent(in) :: fixed_equations(:)
    real(dp), intent(in) :: external_load(:)
    real(dp), intent(in) :: initial_increment, min_increment, cutback_factor
    integer, intent(in) :: max_cutbacks, max_iterations
    real(dp), intent(in) :: tolerance
    real(dp), intent(inout) :: state(:)
    real(dp), intent(out) :: residual(:)
    type(newton_report_t), intent(out) :: report
    type(linear_solver_settings_t), intent(in), optional :: linear_settings
    type(nonlinear_solver_settings_t), intent(in), optional :: nonlinear_settings

    type(csr_matrix_t) :: tangent
    type(sparse_solver_context_t) :: sparse_context
    type(linear_solver_settings_t) :: active_linear_settings
    type(nonlinear_solver_settings_t) :: active_nonlinear_settings
    type(linear_solver_report_t) :: linear_report
    logical, allocatable :: is_fixed(:)
    integer(i64), allocatable :: free_equations(:)
    real(dp), allocatable :: rhs(:), correction(:), committed_state(:), base_state(:)
    real(dp) :: load_factor,target_factor,step,accepted_step,min_j
    real(dp) :: residual_norm,previous_residual_norm,correction_scale
    real(dp) :: candidate_residual_norm,candidate_min_j
    integer :: status,failure_status,iteration,line_search_trial,line_search_trials
    integer :: residual_growth_streak,nonfinite_stage,attempt
    logical :: increment_converged,context_active,line_search_accepted
    logical :: finite_candidate_seen,nonfinite_candidate_seen
    real(dp), parameter :: load_tol = 100.0_dp*epsilon(1.0_dp)

    report = newton_report_t()
    residual = 0.0_dp
    context_active = .false.

    active_linear_settings = production_linear_solver_settings()
    if (present(linear_settings)) active_linear_settings = linear_settings
    active_nonlinear_settings = nonlinear_solver_settings_t()
    if (present(nonlinear_settings)) active_nonlinear_settings = nonlinear_settings
    report%last_linear_report%requested_backend = active_linear_settings%backend
    report%last_linear_report%backend = active_linear_settings%backend

    if (.not. nonlinear_values_finite(initial_increment) .or. &
        .not. nonlinear_values_finite(min_increment) .or. &
        .not. nonlinear_values_finite(cutback_factor) .or. &
        .not. nonlinear_values_finite(tolerance) .or. &
        .not. nonlinear_values_finite(shear_modulus) .or. &
        .not. nonlinear_values_finite(pressure_compliance) .or. &
        .not. nonlinear_values_finite(external_load) .or. &
        .not. nonlinear_values_finite(state)) then
      report%status = DES_ERROR_NONFINITE_NONLINEAR
      report%last_failure_status = DES_ERROR_NONFINITE_NONLINEAR
      return
    end if

    if (initial_increment <= 0.0_dp .or. initial_increment > 1.0_dp .or. &
        min_increment <= 0.0_dp .or. min_increment > initial_increment .or. &
        cutback_factor <= 0.0_dp .or. cutback_factor >= 1.0_dp .or. &
        max_cutbacks < 0 .or. .not. nonlinear_solver_settings_valid(active_nonlinear_settings)) then
      report%status = DES_ERROR_INVALID_CONSTRAINT
      report%last_failure_status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    call prepare_2d_q8_force_problem( &
        mesh,layout,fixed_equations,external_load,1,max_iterations, &
        tolerance,shear_modulus,pressure_compliance,state,residual, &
        is_fixed,free_equations,status)
    if (status /= DES_STATUS_OK) then
      report%status = status
      report%last_failure_status = status
      return
    end if

    allocate(rhs(size(state)),correction(size(state)),committed_state(size(state)), &
             base_state(size(state)))
    call enforce_zero_fixed_state(state,fixed_equations)
    committed_state = state

    call initialize_2d_q8_sparse_context( &
        mesh,layout,active_linear_settings,tangent,sparse_context,context_active,status)
    if (status /= DES_STATUS_OK) then
      report%status = status
      report%last_failure_status = status
      return
    end if

    load_factor = 0.0_dp
    step = initial_increment
    report%increments_requested = ceiling(1.0_dp/initial_increment)

    do while (load_factor < 1.0_dp-load_tol)
      report%increments_attempted = report%increments_attempted+1
      attempt = report%increments_attempted
      target_factor = min(1.0_dp,load_factor+step)
      accepted_step = target_factor-load_factor
      state = committed_state
      increment_converged = .false.
      failure_status = DES_ERROR_NEWTON_DID_NOT_CONVERGE
      previous_residual_norm = huge(1.0_dp)
      residual_growth_streak = 0
      nonfinite_stage = DES_NONFINITE_STAGE_NONE
      min_j = huge(1.0_dp)

      do iteration = 1,max_iterations
        if (.not. nonlinear_values_finite(state)) then
          nonfinite_stage = DES_NONFINITE_STAGE_TRIAL_STATE
          failure_status = DES_ERROR_NONFINITE_NONLINEAR
          call append_q8_history(report,attempt,iteration,target_factor,accepted_step, &
              huge(1.0_dp),min_j,failure_status,.false.,0,0.0_dp,nonfinite_stage)
          exit
        end if

        call assemble_2d_q8_herrmann_csr( &
            mesh,layout,state,shear_modulus,pressure_compliance, &
            residual,tangent,status,min_j)
        report%min_j = min(report%min_j,min_j)
        if (status /= DES_STATUS_OK) then
          failure_status = status
          call append_q8_history(report,attempt,iteration,target_factor,accepted_step, &
              huge(1.0_dp),min_j,status,.false.,0,0.0_dp,DES_NONFINITE_STAGE_NONE)
          exit
        end if

        residual = residual-target_factor*external_load
        if (.not. nonlinear_values_finite(residual) .or. &
            .not. nonlinear_values_finite(min_j)) then
          nonfinite_stage = DES_NONFINITE_STAGE_RESIDUAL
          failure_status = DES_ERROR_NONFINITE_NONLINEAR
          call append_q8_history(report,attempt,iteration,target_factor,accepted_step, &
              huge(1.0_dp),min_j,failure_status,.false.,0,0.0_dp,nonfinite_stage)
          exit
        end if

        residual_norm = maxval(abs(residual(free_equations)))
        report%final_residual_norm = residual_norm

        if (iteration > 1) then
          residual_growth_streak = next_residual_growth_streak( &
              previous_residual_norm,residual_norm,residual_growth_streak, &
              active_nonlinear_settings)
          if (residual_growth_streak >= active_nonlinear_settings%residual_growth_patience) then
            failure_status = DES_ERROR_NONLINEAR_DIVERGENCE
            call append_q8_history(report,attempt,iteration,target_factor,accepted_step, &
                residual_norm,min_j,failure_status,.false.,0,0.0_dp, &
                DES_NONFINITE_STAGE_NONE)
            exit
          end if
        end if
        previous_residual_norm = residual_norm

        if (residual_norm < tolerance) then
          increment_converged = .true.
          call append_q8_history(report,attempt,iteration,target_factor,accepted_step, &
              residual_norm,min_j,DES_STATUS_OK,.true.,0,1.0_dp, &
              DES_NONFINITE_STAGE_NONE)
          report%max_iterations_used = max(report%max_iterations_used,iteration-1)
          exit
        end if

        rhs = -residual
        call csr_apply_zero_dirichlet_i64(tangent,rhs,fixed_equations,status)
        if (status /= DES_STATUS_OK) then
          failure_status = status
          call append_q8_history(report,attempt,iteration,target_factor,accepted_step, &
              residual_norm,min_j,status,.false.,0,0.0_dp,DES_NONFINITE_STAGE_NONE)
          exit
        end if

        call factorize_sparse_matrix(sparse_context,tangent,status)
        if (status /= DES_STATUS_OK) then
          failure_status = status
          call append_q8_history(report,attempt,iteration,target_factor,accepted_step, &
              residual_norm,min_j,status,.false.,0,0.0_dp,DES_NONFINITE_STAGE_NONE)
          exit
        end if

        call solve_sparse_with_context( &
            sparse_context,tangent,rhs,correction,linear_report)
        call record_linear_solve(report,linear_report)
        if (.not. linear_report%converged) then
          failure_status = linear_report%status
          call append_q8_history(report,attempt,iteration,target_factor,accepted_step, &
              residual_norm,min_j,failure_status,.false.,0,0.0_dp, &
              DES_NONFINITE_STAGE_NONE)
          exit
        end if

        if (.not. nonlinear_values_finite(correction)) then
          nonfinite_stage = DES_NONFINITE_STAGE_CORRECTION
          failure_status = DES_ERROR_NONFINITE_NONLINEAR
          call append_q8_history(report,attempt,iteration,target_factor,accepted_step, &
              residual_norm,min_j,failure_status,.false.,0,0.0_dp,nonfinite_stage)
          exit
        end if

        if (.not. active_nonlinear_settings%line_search_enabled) then
          state(free_equations) = state(free_equations)+correction(free_equations)
          call enforce_zero_fixed_state(state,fixed_equations)
          if (.not. nonlinear_values_finite(state)) then
            nonfinite_stage = DES_NONFINITE_STAGE_TRIAL_STATE
            failure_status = DES_ERROR_NONFINITE_NONLINEAR
            call append_q8_history(report,attempt,iteration,target_factor,accepted_step, &
                residual_norm,min_j,failure_status,.false.,0,1.0_dp,nonfinite_stage)
            exit
          end if
          call append_q8_history(report,attempt,iteration,target_factor,accepted_step, &
              residual_norm,min_j,DES_STATUS_OK,.false.,0,1.0_dp, &
              DES_NONFINITE_STAGE_NONE)
        else
          base_state = state
          correction_scale = 1.0_dp
          line_search_trials = 0
          line_search_accepted = .false.
          finite_candidate_seen = .false.
          nonfinite_candidate_seen = .false.
          nonfinite_stage = DES_NONFINITE_STAGE_NONE
          candidate_residual_norm = huge(1.0_dp)
          candidate_min_j = min_j

          do line_search_trial = 1,active_nonlinear_settings%line_search_max_trials
            if (correction_scale < active_nonlinear_settings%line_search_min_scale-load_tol) exit
            line_search_trials = line_search_trial
            state = base_state
            state(free_equations) = state(free_equations) + &
                correction_scale*correction(free_equations)
            call enforce_zero_fixed_state(state,fixed_equations)

            if (.not. nonlinear_values_finite(state)) then
              nonfinite_candidate_seen = .true.
              nonfinite_stage = DES_NONFINITE_STAGE_TRIAL_STATE
              correction_scale = correction_scale*active_nonlinear_settings%line_search_reduction
              cycle
            end if

            call assemble_2d_q8_herrmann_csr( &
                mesh,layout,state,shear_modulus,pressure_compliance, &
                residual,tangent,status,candidate_min_j)
            report%min_j = min(report%min_j,candidate_min_j)

            if (status == DES_STATUS_OK) then
              residual = residual-target_factor*external_load
              if (nonlinear_values_finite(residual) .and. &
                  nonlinear_values_finite(candidate_min_j)) then
                finite_candidate_seen = .true.
                candidate_residual_norm = maxval(abs(residual(free_equations)))
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

            correction_scale = correction_scale*active_nonlinear_settings%line_search_reduction
          end do

          if (.not. line_search_accepted) then
            state = base_state
            call enforce_zero_fixed_state(state,fixed_equations)
            if (nonfinite_candidate_seen .and. .not. finite_candidate_seen) then
              failure_status = DES_ERROR_NONFINITE_NONLINEAR
            else
              failure_status = DES_ERROR_LINE_SEARCH_FAILED
              nonfinite_stage = DES_NONFINITE_STAGE_NONE
            end if
            call append_q8_history(report,attempt,iteration,target_factor,accepted_step, &
                residual_norm,candidate_min_j,failure_status,.false.,line_search_trials, &
                correction_scale,nonfinite_stage)
            exit
          end if

          call append_q8_history(report,attempt,iteration,target_factor,accepted_step, &
              candidate_residual_norm,candidate_min_j,DES_STATUS_OK,.false., &
              line_search_trials,correction_scale,DES_NONFINITE_STAGE_NONE)
        end if

        report%total_iterations = report%total_iterations+1
      end do

      if (increment_converged) then
        committed_state = state
        load_factor = target_factor
        report%state_commit_count = report%state_commit_count+1
        report%increments_converged = report%increments_converged+1
        report%final_load_factor = load_factor
        report%last_accepted_increment = accepted_step
      else
        state = committed_state
        report%state_revert_count = report%state_revert_count+1
        report%last_failure_status = failure_status

        if (failure_status == DES_ERROR_UNSUPPORTED_LINEAR_BACKEND) then
          call fail_with_context(report,failure_status,sparse_context,context_active)
          return
        end if

        report%cutback_count = report%cutback_count+1
        if (report%cutback_count > max_cutbacks) then
          call fail_with_context( &
              report,DES_ERROR_CUTBACK_EXHAUSTED,sparse_context,context_active)
          return
        end if

        step = step*cutback_factor
        if (step < min_increment-load_tol) then
          call fail_with_context( &
              report,DES_ERROR_CUTBACK_EXHAUSTED,sparse_context,context_active)
          return
        end if
      end if
    end do

    state = committed_state
    call finalize_2d_q8_force_solution( &
        mesh,layout,shear_modulus,pressure_compliance,external_load,free_equations, &
        tolerance,state,residual,tangent,report,status)
    if (status /= DES_STATUS_OK) then
      call fail_with_context(report,status,sparse_context,context_active)
      return
    end if

    if (context_active) then
      call release_sparse_solver_context(sparse_context)
      context_active = .false.
    end if
  end subroutine solve_2d_q8_herrmann_adaptive_force_control

  subroutine initialize_2d_q8_sparse_context( &
      mesh,layout,settings,tangent,context,context_active,status)
    type(mesh_database_2d_t), intent(in) :: mesh
    type(dof_layout_2d_t), intent(in) :: layout
    type(linear_solver_settings_t), intent(in) :: settings
    type(csr_matrix_t), intent(out) :: tangent
    type(sparse_solver_context_t), intent(out) :: context
    logical, intent(out) :: context_active
    integer, intent(out) :: status

    context_active = .false.
    call initialize_2d_q8_herrmann_csr_pattern(mesh,layout,tangent,status)
    if (status /= DES_STATUS_OK) return

    ! Dyna CSR/equation storage i64'tir. Full solver/backend capability henüz
    ! end-to-end ilan edilmediği için context index class INT32 kalır. MUMPS/stdlib
    ! sınırındaki range guard silent narrowing'i engeller.
    call create_sparse_solver_context( &
        context,settings,DES_MATRIX_CLASS_SYMMETRIC_INDEFINITE, &
        DES_PROBLEM_CLASS_MIXED_U_P,DES_INDEX_CLASS_INT32,status)
    if (status /= DES_STATUS_OK) return
    context_active = .true.

    call analyze_sparse_pattern(context,tangent,status)
    if (status /= DES_STATUS_OK) then
      call release_sparse_solver_context(context)
      context_active = .false.
      return
    end if

    call reorder_sparse_pattern(context,status)
    if (status /= DES_STATUS_OK) then
      call release_sparse_solver_context(context)
      context_active = .false.
    end if
  end subroutine initialize_2d_q8_sparse_context

  subroutine prepare_2d_q8_force_problem( &
      mesh,layout,fixed_equations,external_load,n_increments,max_iterations, &
      tolerance,shear_modulus,pressure_compliance,state,residual, &
      is_fixed,free_equations,status)
    type(mesh_database_2d_t), intent(in) :: mesh
    type(dof_layout_2d_t), intent(in) :: layout
    integer(i64), intent(in) :: fixed_equations(:)
    real(dp), intent(in) :: external_load(:),state(:),residual(:)
    integer, intent(in) :: n_increments,max_iterations
    real(dp), intent(in) :: tolerance,shear_modulus,pressure_compliance
    logical, allocatable, intent(out) :: is_fixed(:)
    integer(i64), allocatable, intent(out) :: free_equations(:)
    integer, intent(out) :: status

    integer(i64) :: ntotal,kinematic_equations,dof,cursor
    integer :: a,mesh_status

    status = DES_STATUS_OK
    call validate_2d_mesh_database(mesh,mesh_status)
    if (mesh_status /= DES_STATUS_OK) then
      status = mesh_status
      return
    end if

    ntotal = layout%total_equation_count
    kinematic_equations = layout%nodal_equation_count+layout%generalized_equation_count
    if (ntotal < 1_i64 .or. size(state,kind=i64) /= ntotal .or. &
        size(residual,kind=i64) /= ntotal .or. size(external_load,kind=i64) /= ntotal) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if
    if (layout%analysis_mode /= mesh%elements(1)%analysis_mode) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if
    if (shear_modulus <= 0.0_dp .or. pressure_compliance < 0.0_dp .or. &
        n_increments < 1 .or. max_iterations < 1 .or. tolerance <= 0.0_dp) then
      status = DES_ERROR_INVALID_PARAMETERS
      return
    end if
    if (size(fixed_equations) < 1) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    allocate(is_fixed(ntotal))
    is_fixed = .false.
    do a = 1,size(fixed_equations)
      dof = fixed_equations(a)
      if (dof < 1_i64 .or. dof > kinematic_equations .or. is_fixed(dof)) then
        status = DES_ERROR_INVALID_CONSTRAINT
        return
      end if
      is_fixed(dof) = .true.
    end do

    allocate(free_equations(count(.not.is_fixed)))
    cursor = 0_i64
    do dof = 1_i64,ntotal
      if (.not. is_fixed(dof)) then
        cursor = cursor+1_i64
        free_equations(cursor) = dof
      end if
    end do
    if (cursor < 1_i64) status = DES_ERROR_INVALID_CONSTRAINT
  end subroutine prepare_2d_q8_force_problem

  subroutine finalize_2d_q8_force_solution( &
      mesh,layout,shear_modulus,pressure_compliance,external_load,free_equations, &
      tolerance,state,residual,tangent,report,status)
    type(mesh_database_2d_t), intent(in) :: mesh
    type(dof_layout_2d_t), intent(in) :: layout
    real(dp), intent(in) :: shear_modulus,pressure_compliance,external_load(:),tolerance
    integer(i64), intent(in) :: free_equations(:)
    real(dp), intent(in) :: state(:)
    real(dp), intent(out) :: residual(:)
    type(csr_matrix_t), intent(inout) :: tangent
    type(newton_report_t), intent(inout) :: report
    integer, intent(out) :: status
    real(dp) :: min_j

    call assemble_2d_q8_herrmann_csr( &
        mesh,layout,state,shear_modulus,pressure_compliance, &
        residual,tangent,status,min_j)
    report%min_j = min(report%min_j,min_j)
    if (status /= DES_STATUS_OK) return

    residual = residual-external_load
    report%final_residual_norm = maxval(abs(residual(free_equations)))
    report%final_load_factor = 1.0_dp
    report%converged = report%final_residual_norm < tolerance
    if (report%converged) then
      report%status = DES_STATUS_OK
      status = DES_STATUS_OK
    else
      report%status = DES_ERROR_NEWTON_DID_NOT_CONVERGE
      report%last_failure_status = DES_ERROR_NEWTON_DID_NOT_CONVERGE
      status = DES_ERROR_NEWTON_DID_NOT_CONVERGE
    end if
  end subroutine finalize_2d_q8_force_solution

  subroutine enforce_zero_fixed_state(state,fixed_equations)
    real(dp), intent(inout) :: state(:)
    integer(i64), intent(in) :: fixed_equations(:)

    state(fixed_equations) = 0.0_dp
  end subroutine enforce_zero_fixed_state

  subroutine record_linear_solve(report,linear_report)
    type(newton_report_t), intent(inout) :: report
    type(linear_solver_report_t), intent(in) :: linear_report

    report%linear_solve_count = report%linear_solve_count+1
    report%last_linear_report = linear_report
    report%max_linear_equation_count = max( &
        report%max_linear_equation_count,linear_report%equation_count)
    if (linear_report%converged) then
      report%max_linear_residual_inf_norm = max( &
          report%max_linear_residual_inf_norm,linear_report%residual_inf_norm)
    end if
  end subroutine record_linear_solve

  subroutine append_q8_history( &
      report,attempt,iteration,load_factor,increment_size,residual_norm,min_j,status, &
      accepted,line_search_trials,correction_scale,nonfinite_stage)
    type(newton_report_t), intent(inout) :: report
    integer, intent(in) :: attempt,iteration,status,line_search_trials,nonfinite_stage
    real(dp), intent(in) :: load_factor,increment_size,residual_norm,min_j,correction_scale
    logical, intent(in) :: accepted
    type(convergence_record_t) :: record

    record = convergence_record_t()
    record%attempt = attempt
    record%iteration = iteration
    record%status = status
    record%line_search_trials = line_search_trials
    record%cutback_index = report%cutback_count
    record%nonfinite_stage = nonfinite_stage
    record%load_factor = load_factor
    record%increment_size = increment_size
    record%residual_norm = residual_norm
    record%min_j = min_j
    record%correction_scale = correction_scale
    record%accepted = accepted
    call append_convergence_record(report%history,record)
  end subroutine append_q8_history

  subroutine fail_with_context(report,failure_status,context,context_active)
    type(newton_report_t), intent(inout) :: report
    integer, intent(in) :: failure_status
    type(sparse_solver_context_t), intent(inout) :: context
    logical, intent(inout) :: context_active

    report%status = failure_status
    report%last_failure_status = failure_status
    report%converged = .false.
    if (context_active) then
      call release_sparse_solver_context(context)
      context_active = .false.
    end if
  end subroutine fail_with_context

end module des_2d_q8_herrmann_force_solver
