module des_q9_plane_strain_herrmann_force_solver
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_PARAMETERS, &
                         DES_ERROR_INVALID_CONNECTIVITY, DES_ERROR_INVALID_CONSTRAINT, &
                         DES_ERROR_NEWTON_DID_NOT_CONVERGE, &
                         DES_ERROR_CUTBACK_EXHAUSTED, &
                         DES_ERROR_UNSUPPORTED_LINEAR_BACKEND
  use des_internal_mesh, only : internal_mesh_t, validate_internal_mesh
  use des_csr_matrix, only : csr_matrix_t, csr_apply_zero_dirichlet
  use des_linear_solver, only : linear_solver_settings_t, linear_solver_report_t, &
                                solve_linear_system, linear_backend_is_sparse
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

    active_linear_settings = linear_solver_settings_t()
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
      linear_settings, quadrature_order)
    ! Q9/P1 Herrmann için adaptive production yolu.
    ! Displacement ve pressure trial state'leri aynı increment transaction'ının
    ! parçasıdır. Bir Newton denemesi başarısız olursa ikisi de committed state'e döner.
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

    logical, allocatable :: is_fixed(:)
    integer, allocatable :: free_dofs(:)
    real(dp), allocatable :: K(:,:), Kff(:,:), rhs(:), delta(:)
    real(dp), allocatable :: rhs_full(:), delta_full(:)
    type(csr_matrix_t) :: K_csr
    type(sparse_solver_context_t) :: sparse_context
    type(solution_state_t) :: displacement_state, pressure_state
    real(dp) :: min_j, load_factor, target_factor, step
    real(dp) :: residual_norm, accepted_step
    integer :: ndisp, ntotal, nfree, status, failure_status, active_quadrature
    integer :: iteration, a, b, attempt
    logical :: increment_converged, use_sparse_backend
    real(dp), parameter :: load_tol = 100.0_dp*epsilon(1.0_dp)
    type(linear_solver_settings_t) :: active_linear_settings
    type(linear_solver_report_t) :: linear_report

    active_linear_settings = linear_solver_settings_t()
    if (present(linear_settings)) active_linear_settings = linear_settings
    active_quadrature = Q9_HERRMANN_QUADRATURE_3X3
    if (present(quadrature_order)) active_quadrature = quadrature_order
    use_sparse_backend = linear_backend_is_sparse(active_linear_settings%backend)

    report = newton_report_t()
    report%last_linear_report%backend = active_linear_settings%backend
    call clear_convergence_history(report%history)
    residual = 0.0_dp

    if (initial_increment <= 0.0_dp .or. initial_increment > 1.0_dp .or. &
        min_increment <= 0.0_dp .or. min_increment > initial_increment .or. &
        cutback_factor <= 0.0_dp .or. cutback_factor >= 1.0_dp .or. &
        max_cutbacks < 0) then
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

    load_factor = 0.0_dp
    step = initial_increment
    report%increments_requested = ceiling(1.0_dp/initial_increment)

    do while (load_factor < 1.0_dp-load_tol)
      report%increments_attempted = report%increments_attempted + 1
      attempt = report%increments_attempted
      target_factor = min(1.0_dp,load_factor+step)
      accepted_step = target_factor-load_factor

      call begin_solution_trial(displacement_state)
      call begin_solution_trial(pressure_state)
      call enforce_zero_displacement_dofs(displacement_state%trial,fixed_dofs)

      increment_converged = .false.
      failure_status = DES_ERROR_NEWTON_DID_NOT_CONVERGE

      do iteration = 1,max_iterations
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
        residual_norm = maxval(abs(residual(free_dofs)))
        report%final_residual_norm = residual_norm

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

        call add_herrmann_history(report,attempt,iteration,target_factor, &
            accepted_step,residual_norm,min_j,DES_STATUS_OK,.false.)

        if (use_sparse_backend) then
          call add_mixed_increment( &
              displacement_state%trial,pressure_state%trial,ndisp,free_dofs, &
              delta_full(free_dofs))
        else
          call add_mixed_increment( &
              displacement_state%trial,pressure_state%trial,ndisp,free_dofs,delta)
        end if
        call enforce_zero_displacement_dofs(displacement_state%trial,fixed_dofs)
        report%total_iterations = report%total_iterations + 1
      end do

      if (increment_converged) then
        call commit_solution_state(displacement_state)
        call commit_solution_state(pressure_state)
        load_factor = target_factor
        report%increments_converged = report%increments_converged + 1
        report%final_load_factor = load_factor
        report%last_accepted_increment = accepted_step
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
      min_j,status,accepted)
    type(newton_report_t), intent(inout) :: report
    integer, intent(in) :: attempt, iteration, status
    real(dp), intent(in) :: load_factor, increment_size, residual_norm, min_j
    logical, intent(in) :: accepted
    type(convergence_record_t) :: record

    record%attempt = attempt
    record%iteration = iteration
    record%load_factor = load_factor
    record%increment_size = increment_size
    record%residual_norm = residual_norm
    record%min_j = min_j
    record%status = status
    record%accepted = accepted
    call append_convergence_record(report%history,record)
  end subroutine add_herrmann_history

end module des_q9_plane_strain_herrmann_force_solver