module des_q4_plane_strain_newton_solver
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONSTRAINT, &
                         DES_ERROR_LINEAR_SOLVE, DES_ERROR_NEWTON_DID_NOT_CONVERGE, &
                         DES_ERROR_CUTBACK_EXHAUSTED
  use des_dense_linear, only : solve_dense_system
  use des_solution_state, only : solution_state_t, initialize_solution_state, &
                                 begin_solution_trial, commit_solution_state, &
                                 revert_solution_state
  use des_solver_history, only : convergence_record_t, convergence_history_t, &
                                 clear_convergence_history, append_convergence_record, &
                                 mark_last_convergence_status
  use des_material_types, only : neo_hookean_parameters_t
  use des_q4_plane_strain_mesh_neo_hookean, only : assemble_q4_plane_strain_mesh
  implicit none
  private

  public :: newton_report_t
  public :: solve_q4_plane_strain_displacement_control
  public :: solve_q4_plane_strain_adaptive_displacement_control

  type :: newton_report_t
    integer :: status = DES_STATUS_OK
    integer :: increments_requested = 0
    integer :: increments_attempted = 0
    integer :: increments_converged = 0
    integer :: total_iterations = 0
    integer :: max_iterations_used = 0
    integer :: cutback_count = 0
    integer :: last_failure_status = DES_STATUS_OK
    integer :: state_commit_count = 0
    integer :: state_revert_count = 0
    real(dp) :: final_residual_norm = huge(1.0_dp)
    real(dp) :: min_j = huge(1.0_dp)
    real(dp) :: final_load_factor = 0.0_dp
    real(dp) :: last_accepted_increment = 0.0_dp
    logical :: converged = .false.
    type(convergence_history_t) :: history
  end type newton_report_t
contains

  subroutine solve_q4_plane_strain_displacement_control( &
      X, connectivity, parameters, prescribed_dofs, prescribed_final_values, &
      n_increments, max_iterations, tolerance, u, residual, report)
    real(dp), intent(in) :: X(:,:)
    integer, intent(in) :: connectivity(:,:)
    type(neo_hookean_parameters_t), intent(in) :: parameters
    integer, intent(in) :: prescribed_dofs(:)
    real(dp), intent(in) :: prescribed_final_values(:)
    integer, intent(in) :: n_increments, max_iterations
    real(dp), intent(in) :: tolerance
    real(dp), intent(inout) :: u(:,:)
    real(dp), intent(out) :: residual(:)
    type(newton_report_t), intent(out) :: report

    logical, allocatable :: is_prescribed(:)
    integer, allocatable :: free_dofs(:)
    real(dp), allocatable :: K(:,:), Kff(:,:), rhs(:), du(:)
    real(dp) :: min_j, load_factor, residual_norm, increment_size
    integer :: ndof, nnode, nfree, status
    integer :: increment, iteration, a, b, dof, node, comp, attempt
    logical :: ok, increment_converged

    report = newton_report_t()
    call clear_convergence_history(report%history)
    report%increments_requested = n_increments
    residual = 0.0_dp

    call prepare_constraints(X, u, residual, prescribed_dofs, prescribed_final_values, &
                             n_increments, max_iterations, tolerance, is_prescribed, &
                             free_dofs, report%status)
    if (report%status /= DES_STATUS_OK) return

    nnode = size(X,1)
    ndof = 2*nnode
    nfree = size(free_dofs)
    increment_size = 1.0_dp/real(n_increments,dp)
    allocate(K(ndof,ndof), Kff(nfree,nfree), rhs(nfree), du(nfree))

    do increment = 1,n_increments
      report%increments_attempted = report%increments_attempted + 1
      attempt = report%increments_attempted
      load_factor = real(increment,dp)/real(n_increments,dp)

      do a = 1,size(prescribed_dofs)
        call set_global_dof(u, prescribed_dofs(a), &
                            load_factor*prescribed_final_values(a))
      end do

      increment_converged = .false.
      do iteration = 1,max_iterations
        call assemble_q4_plane_strain_mesh(X, connectivity, u, parameters, &
                                           residual, K, status, min_j)
        report%min_j = min(report%min_j, min_j)
        if (status /= DES_STATUS_OK) then
          call add_history(report, attempt, iteration, load_factor, increment_size, &
                           huge(1.0_dp), min_j, status, .false.)
          report%status = status
          report%last_failure_status = status
          return
        end if

        rhs = -residual(free_dofs)
        residual_norm = maxval(abs(rhs))
        report%final_residual_norm = residual_norm

        if (residual_norm < tolerance) then
          call add_history(report, attempt, iteration, load_factor, increment_size, &
                           residual_norm, min_j, DES_STATUS_OK, .true.)
          increment_converged = .true.
          report%increments_converged = increment
          report%final_load_factor = load_factor
          report%last_accepted_increment = increment_size
          report%max_iterations_used = max(report%max_iterations_used, iteration-1)
          exit
        end if

        do a = 1,nfree
          do b = 1,nfree
            Kff(a,b) = K(free_dofs(a), free_dofs(b))
          end do
        end do

        call solve_dense_system(Kff, rhs, du, ok)
        if (.not. ok) then
          call add_history(report, attempt, iteration, load_factor, increment_size, &
                           residual_norm, min_j, DES_ERROR_LINEAR_SOLVE, .false.)
          report%status = DES_ERROR_LINEAR_SOLVE
          report%last_failure_status = DES_ERROR_LINEAR_SOLVE
          return
        end if

        call add_history(report, attempt, iteration, load_factor, increment_size, &
                         residual_norm, min_j, DES_STATUS_OK, .false.)

        do a = 1,nfree
          dof = free_dofs(a)
          node = (dof+1)/2
          comp = dof - 2*(node-1)
          u(node,comp) = u(node,comp) + du(a)
        end do
        report%total_iterations = report%total_iterations + 1
      end do

      if (.not. increment_converged) then
        call mark_last_convergence_status(report%history, &
                                          DES_ERROR_NEWTON_DID_NOT_CONVERGE)
        report%status = DES_ERROR_NEWTON_DID_NOT_CONVERGE
        report%last_failure_status = DES_ERROR_NEWTON_DID_NOT_CONVERGE
        return
      end if
    end do

    call finalize_solution(X, connectivity, u, parameters, residual, K, report)
  end subroutine solve_q4_plane_strain_displacement_control

  subroutine solve_q4_plane_strain_adaptive_displacement_control( &
      X, connectivity, parameters, prescribed_dofs, prescribed_final_values, &
      initial_increment, min_increment, cutback_factor, max_cutbacks, &
      max_iterations, tolerance, u, residual, report)
    real(dp), intent(in) :: X(:,:)
    integer, intent(in) :: connectivity(:,:)
    type(neo_hookean_parameters_t), intent(in) :: parameters
    integer, intent(in) :: prescribed_dofs(:)
    real(dp), intent(in) :: prescribed_final_values(:)
    real(dp), intent(in) :: initial_increment, min_increment, cutback_factor
    integer, intent(in) :: max_cutbacks, max_iterations
    real(dp), intent(in) :: tolerance
    real(dp), intent(inout) :: u(:,:)
    real(dp), intent(out) :: residual(:)
    type(newton_report_t), intent(out) :: report

    logical, allocatable :: is_prescribed(:)
    integer, allocatable :: free_dofs(:)
    real(dp), allocatable :: K(:,:), Kff(:,:), rhs(:), du(:)
    type(solution_state_t) :: state
    real(dp) :: min_j, load_factor, target_factor, step
    real(dp) :: residual_norm, accepted_step
    integer :: ndof, nnode, nfree, status, failure_status
    integer :: iteration, a, b, dof, node, comp, attempt
    logical :: ok, increment_converged
    real(dp), parameter :: load_tol = 100.0_dp*epsilon(1.0_dp)

    report = newton_report_t()
    call clear_convergence_history(report%history)
    residual = 0.0_dp

    if (initial_increment <= 0.0_dp .or. initial_increment > 1.0_dp .or. &
        min_increment <= 0.0_dp .or. min_increment > initial_increment .or. &
        cutback_factor <= 0.0_dp .or. cutback_factor >= 1.0_dp .or. &
        max_cutbacks < 0) then
      report%status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    call prepare_constraints(X, u, residual, prescribed_dofs, prescribed_final_values, &
                             1, max_iterations, tolerance, is_prescribed, free_dofs, &
                             report%status)
    if (report%status /= DES_STATUS_OK) return

    nnode = size(X,1)
    ndof = 2*nnode
    nfree = size(free_dofs)
    allocate(K(ndof,ndof), Kff(nfree,nfree), rhs(nfree), du(nfree))

    call initialize_solution_state(state, u)
    load_factor = 0.0_dp
    step = initial_increment
    report%increments_requested = ceiling(1.0_dp/initial_increment)

    do while (load_factor < 1.0_dp-load_tol)
      report%increments_attempted = report%increments_attempted + 1
      attempt = report%increments_attempted
      target_factor = min(1.0_dp, load_factor + step)
      accepted_step = target_factor - load_factor
      call begin_solution_trial(state)

      do a = 1,size(prescribed_dofs)
        call set_global_dof(state%trial, prescribed_dofs(a), &
                            target_factor*prescribed_final_values(a))
      end do

      increment_converged = .false.
      failure_status = DES_ERROR_NEWTON_DID_NOT_CONVERGE

      do iteration = 1,max_iterations
        call assemble_q4_plane_strain_mesh(X, connectivity, state%trial, parameters, &
                                           residual, K, status, min_j)
        report%min_j = min(report%min_j, min_j)
        if (status /= DES_STATUS_OK) then
          call add_history(report, attempt, iteration, target_factor, accepted_step, &
                           huge(1.0_dp), min_j, status, .false.)
          failure_status = status
          exit
        end if

        rhs = -residual(free_dofs)
        residual_norm = maxval(abs(rhs))
        report%final_residual_norm = residual_norm

        if (residual_norm < tolerance) then
          call add_history(report, attempt, iteration, target_factor, accepted_step, &
                           residual_norm, min_j, DES_STATUS_OK, .true.)
          increment_converged = .true.
          report%max_iterations_used = max(report%max_iterations_used, iteration-1)
          exit
        end if

        do a = 1,nfree
          do b = 1,nfree
            Kff(a,b) = K(free_dofs(a), free_dofs(b))
          end do
        end do

        call solve_dense_system(Kff, rhs, du, ok)
        if (.not. ok) then
          call add_history(report, attempt, iteration, target_factor, accepted_step, &
                           residual_norm, min_j, DES_ERROR_LINEAR_SOLVE, .false.)
          failure_status = DES_ERROR_LINEAR_SOLVE
          exit
        end if

        call add_history(report, attempt, iteration, target_factor, accepted_step, &
                         residual_norm, min_j, DES_STATUS_OK, .false.)

        do a = 1,nfree
          dof = free_dofs(a)
          node = (dof+1)/2
          comp = dof - 2*(node-1)
          state%trial(node,comp) = state%trial(node,comp) + du(a)
        end do
        report%total_iterations = report%total_iterations + 1
      end do

      if (increment_converged) then
        call commit_solution_state(state)
        load_factor = target_factor
        report%increments_converged = report%increments_converged + 1
        report%final_load_factor = load_factor
        report%last_accepted_increment = accepted_step
      else
        if (failure_status == DES_ERROR_NEWTON_DID_NOT_CONVERGE) then
          call mark_last_convergence_status(report%history, failure_status)
        end if

        report%last_failure_status = failure_status
        report%cutback_count = report%cutback_count + 1
        call revert_solution_state(state)

        if (report%cutback_count > max_cutbacks) then
          u = state%committed
          call copy_state_counters(state, report)
          report%status = DES_ERROR_CUTBACK_EXHAUSTED
          return
        end if

        step = step*cutback_factor
        if (step < min_increment-load_tol) then
          u = state%committed
          call copy_state_counters(state, report)
          report%status = DES_ERROR_CUTBACK_EXHAUSTED
          return
        end if
      end if

      call copy_state_counters(state, report)
    end do

    u = state%committed
    call copy_state_counters(state, report)
    call finalize_solution(X, connectivity, u, parameters, residual, K, report)
  end subroutine solve_q4_plane_strain_adaptive_displacement_control

  subroutine prepare_constraints(X, u, residual, prescribed_dofs, &
                                 prescribed_final_values, n_increments, &
                                 max_iterations, tolerance, is_prescribed, &
                                 free_dofs, status)
    real(dp), intent(in) :: X(:,:), u(:,:), prescribed_final_values(:), tolerance
    real(dp), intent(in) :: residual(:)
    integer, intent(in) :: prescribed_dofs(:), n_increments, max_iterations
    logical, allocatable, intent(out) :: is_prescribed(:)
    integer, allocatable, intent(out) :: free_dofs(:)
    integer, intent(out) :: status
    integer :: nnode, ndof, nfree, a, b, dof

    status = DES_STATUS_OK
    nnode = size(X,1)
    ndof = 2*nnode

    if (size(X,2) /= 2 .or. size(u,1) /= nnode .or. size(u,2) /= 2 .or. &
        size(residual) /= ndof) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if
    if (size(prescribed_dofs) /= size(prescribed_final_values)) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if
    if (n_increments < 1 .or. max_iterations < 1 .or. tolerance <= 0.0_dp) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    allocate(is_prescribed(ndof))
    is_prescribed = .false.
    do a = 1,size(prescribed_dofs)
      dof = prescribed_dofs(a)
      if (dof < 1 .or. dof > ndof .or. is_prescribed(dof)) then
        status = DES_ERROR_INVALID_CONSTRAINT
        return
      end if
      is_prescribed(dof) = .true.
    end do

    nfree = count(.not. is_prescribed)
    if (nfree < 1) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    allocate(free_dofs(nfree))
    b = 0
    do dof = 1,ndof
      if (.not. is_prescribed(dof)) then
        b = b + 1
        free_dofs(b) = dof
      end if
    end do
  end subroutine prepare_constraints

  subroutine finalize_solution(X, connectivity, u, parameters, residual, K, report)
    real(dp), intent(in) :: X(:,:), u(:,:)
    integer, intent(in) :: connectivity(:,:)
    type(neo_hookean_parameters_t), intent(in) :: parameters
    real(dp), intent(out) :: residual(:)
    real(dp), intent(inout) :: K(:,:)
    type(newton_report_t), intent(inout) :: report
    real(dp) :: min_j
    integer :: status

    call assemble_q4_plane_strain_mesh(X, connectivity, u, parameters, &
                                       residual, K, status, min_j)
    report%min_j = min(report%min_j, min_j)
    if (status /= DES_STATUS_OK) then
      report%status = status
      report%last_failure_status = status
      return
    end if

    report%status = DES_STATUS_OK
    report%converged = .true.
    report%final_load_factor = 1.0_dp
  end subroutine finalize_solution

  subroutine add_history(report, attempt, iteration, load_factor, increment_size, &
                         residual_norm, min_j, status, accepted)
    type(newton_report_t), intent(inout) :: report
    integer, intent(in) :: attempt, iteration, status
    real(dp), intent(in) :: load_factor, increment_size, residual_norm, min_j
    logical, intent(in) :: accepted
    type(convergence_record_t) :: record

    record%attempt = attempt
    record%iteration = iteration
    record%status = status
    record%load_factor = load_factor
    record%increment_size = increment_size
    record%residual_norm = residual_norm
    record%min_j = min_j
    record%accepted = accepted
    call append_convergence_record(report%history, record)
  end subroutine add_history

  subroutine copy_state_counters(state, report)
    type(solution_state_t), intent(in) :: state
    type(newton_report_t), intent(inout) :: report

    report%state_commit_count = state%commit_count
    report%state_revert_count = state%revert_count
  end subroutine copy_state_counters

  subroutine set_global_dof(u, dof, value)
    real(dp), intent(inout) :: u(:,:)
    integer, intent(in) :: dof
    real(dp), intent(in) :: value
    integer :: node, comp

    node = (dof+1)/2
    comp = dof - 2*(node-1)
    u(node,comp) = value
  end subroutine set_global_dof

end module des_q4_plane_strain_newton_solver
