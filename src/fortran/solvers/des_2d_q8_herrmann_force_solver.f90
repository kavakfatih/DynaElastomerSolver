module des_2d_q8_herrmann_force_solver
  use des_kinds, only : dp, i64
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONSTRAINT, &
      DES_ERROR_INVALID_PARAMETERS, DES_ERROR_NEWTON_DID_NOT_CONVERGE
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
  implicit none
  private

  public :: solve_2d_q8_herrmann_force_control

contains

  subroutine solve_2d_q8_herrmann_force_control( &
      mesh, layout, shear_modulus, pressure_compliance, fixed_equations, &
      external_load, n_increments, max_iterations, tolerance, state, residual, &
      report, linear_settings)
    ! Field-based 2D Q8/P1 Herrmann production-solver vertical slice.
    !
    ! Unknown vector doğrudan dof_layout_2d_t sırasını kullanır:
    !   [nodal kinematic DOF] + [generalized kinematic DOF] + [pressure DOF].
    ! Plane-strain, axisymmetric ve axisymmetric-with-torsion aynı sparse Newton
    ! lifecycle'ını paylaşır; element dispatch assembly katmanında yapılır.
    !
    ! Bu ilk production integration slice force-control ve sıfır kinematik
    ! Dirichlet koşullarını destekler. Pattern solve başında bir kez analyze/reorder
    ! edilir; her Newton iterasyonunda yalnız numeric factorization yenilenir.
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
    committed_state = state
    call enforce_zero_fixed_state(state,fixed_equations)
    committed_state = state

    call initialize_2d_q8_herrmann_csr_pattern(mesh,layout,tangent,status)
    if (status /= DES_STATUS_OK) then
      report%status = status
      report%last_failure_status = status
      return
    end if

    ! Dyna CSR/equation storage i64'tir; current production context capability
    ! flag'i end-to-end INT64 ilan edilmediği için backend class INT32 kalır.
    ! Backend sınırındaki range guard silent narrowing'i engeller.
    call create_sparse_solver_context( &
        sparse_context,active_linear_settings,DES_MATRIX_CLASS_SYMMETRIC_INDEFINITE, &
        DES_PROBLEM_CLASS_MIXED_U_P,DES_INDEX_CLASS_INT32,status)
    if (status /= DES_STATUS_OK) then
      report%status = status
      report%last_failure_status = status
      return
    end if
    context_active = .true.

    call analyze_sparse_pattern(sparse_context,tangent,status)
    if (status /= DES_STATUS_OK) then
      call fail_with_context(report,status,sparse_context,context_active)
      return
    end if
    call reorder_sparse_pattern(sparse_context,status)
    if (status /= DES_STATUS_OK) then
      call fail_with_context(report,status,sparse_context,context_active)
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
    call assemble_2d_q8_herrmann_csr( &
        mesh,layout,state,shear_modulus,pressure_compliance, &
        residual,tangent,status,min_j)
    report%min_j = min(report%min_j,min_j)
    if (status /= DES_STATUS_OK) then
      call fail_with_context(report,status,sparse_context,context_active)
      return
    end if

    residual = residual-external_load
    report%final_residual_norm = maxval(abs(residual(free_equations)))
    report%final_load_factor = 1.0_dp
    report%converged = report%final_residual_norm < tolerance
    if (report%converged) then
      report%status = DES_STATUS_OK
    else
      report%status = DES_ERROR_NEWTON_DID_NOT_CONVERGE
      report%last_failure_status = DES_ERROR_NEWTON_DID_NOT_CONVERGE
    end if

    if (context_active) then
      call release_sparse_solver_context(sparse_context)
      context_active = .false.
    end if
  end subroutine solve_2d_q8_herrmann_force_control

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
