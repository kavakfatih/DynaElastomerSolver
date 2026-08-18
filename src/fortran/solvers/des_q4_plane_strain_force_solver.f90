module des_q4_plane_strain_force_solver
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONSTRAINT, &
                         DES_ERROR_NEWTON_DID_NOT_CONVERGE
  use des_material_types, only : neo_hookean_parameters_t
  use des_linear_solver, only : linear_solver_settings_t, linear_solver_report_t, &
                                solve_linear_system
  use des_solver_history, only : convergence_record_t, clear_convergence_history, &
                                 append_convergence_record, mark_last_convergence_status
  use des_q4_plane_strain_mesh_neo_hookean, only : assemble_q4_plane_strain_mesh
  use des_q4_plane_strain_newton_solver, only : newton_report_t
  implicit none
  private

  public :: solve_q4_plane_strain_force_control
contains

  subroutine solve_q4_plane_strain_force_control( &
      X, connectivity, parameters, fixed_dofs, external_force, &
      n_increments, max_iterations, tolerance, u, residual, report, linear_settings)
    ! V0.3 locking benchmarkları için minimal force-control Full Newton driverı.
    ! external_force tam referans yük vektörüdür ve increment load factor ile ölçeklenir.
    ! fixed_dofs yalnız sıfır displacement sınır şartlarını temsil eder.
    real(dp), intent(in) :: X(:,:)
    integer, intent(in) :: connectivity(:,:)
    type(neo_hookean_parameters_t), intent(in) :: parameters
    integer, intent(in) :: fixed_dofs(:)
    real(dp), intent(in) :: external_force(:)
    integer, intent(in) :: n_increments, max_iterations
    real(dp), intent(in) :: tolerance
    real(dp), intent(inout) :: u(:,:)
    real(dp), intent(out) :: residual(:)
    type(newton_report_t), intent(out) :: report
    type(linear_solver_settings_t), intent(in), optional :: linear_settings

    logical, allocatable :: is_fixed(:)
    integer, allocatable :: free_dofs(:)
    real(dp), allocatable :: K(:,:), Kff(:,:), rhs(:), du(:)
    real(dp) :: min_j, load_factor, residual_norm, increment_size
    integer :: nnode, ndof, nfree, status
    integer :: increment, iteration, a, b, dof, node, comp
    logical :: increment_converged
    type(linear_solver_settings_t) :: active_linear_settings
    type(linear_solver_report_t) :: linear_report

    active_linear_settings = linear_solver_settings_t()
    if (present(linear_settings)) active_linear_settings = linear_settings

    report = newton_report_t()
    report%last_linear_report%backend = active_linear_settings%backend
    call clear_convergence_history(report%history)
    residual = 0.0_dp

    call prepare_force_control_problem( &
        X, u, residual, fixed_dofs, external_force, n_increments, &
        max_iterations, tolerance, is_fixed, free_dofs, report%status)
    if (report%status /= DES_STATUS_OK) return

    nnode = size(X,1)
    ndof = 2*nnode
    nfree = size(free_dofs)
    increment_size = 1.0_dp/real(n_increments,dp)
    report%increments_requested = n_increments

    allocate(K(ndof,ndof), Kff(nfree,nfree), rhs(nfree), du(nfree))
    call enforce_zero_dofs(u, fixed_dofs)

    do increment = 1,n_increments
      report%increments_attempted = report%increments_attempted + 1
      load_factor = real(increment,dp)/real(n_increments,dp)
      increment_converged = .false.

      do iteration = 1,max_iterations
        call assemble_q4_plane_strain_mesh( &
            X, connectivity, u, parameters, residual, K, status, min_j)
        report%min_j = min(report%min_j, min_j)

        if (status /= DES_STATUS_OK) then
          call add_force_history(report, increment, iteration, load_factor, &
                                 increment_size, huge(1.0_dp), min_j, status, .false.)
          report%status = status
          report%last_failure_status = status
          return
        end if

        residual = residual - load_factor*external_force
        rhs = -residual(free_dofs)
        residual_norm = maxval(abs(rhs))
        report%final_residual_norm = residual_norm

        if (residual_norm < tolerance) then
          call add_force_history(report, increment, iteration, load_factor, &
                                 increment_size, residual_norm, min_j, DES_STATUS_OK, .true.)
          increment_converged = .true.
          report%increments_converged = increment
          report%final_load_factor = load_factor
          report%last_accepted_increment = increment_size
          report%max_iterations_used = max(report%max_iterations_used, iteration-1)
          exit
        end if

        do a = 1,nfree
          do b = 1,nfree
            Kff(a,b) = K(free_dofs(a),free_dofs(b))
          end do
        end do

        call solve_linear_system(Kff, rhs, du, active_linear_settings, linear_report)
        call record_force_linear_solve(report, linear_report)
        if (.not. linear_report%converged) then
          call add_force_history(report, increment, iteration, load_factor, &
                                 increment_size, residual_norm, min_j, &
                                 linear_report%status, .false.)
          report%status = linear_report%status
          report%last_failure_status = linear_report%status
          return
        end if

        call add_force_history(report, increment, iteration, load_factor, &
                               increment_size, residual_norm, min_j, DES_STATUS_OK, .false.)

        do a = 1,nfree
          dof = free_dofs(a)
          node = (dof+1)/2
          comp = dof - 2*(node-1)
          u(node,comp) = u(node,comp) + du(a)
        end do
        call enforce_zero_dofs(u, fixed_dofs)
        report%total_iterations = report%total_iterations + 1
      end do

      if (.not. increment_converged) then
        call mark_last_convergence_status(report%history, DES_ERROR_NEWTON_DID_NOT_CONVERGE)
        report%status = DES_ERROR_NEWTON_DID_NOT_CONVERGE
        report%last_failure_status = DES_ERROR_NEWTON_DID_NOT_CONVERGE
        return
      end if
    end do

    call assemble_q4_plane_strain_mesh( &
        X, connectivity, u, parameters, residual, K, status, min_j)
    report%min_j = min(report%min_j, min_j)
    if (status /= DES_STATUS_OK) then
      report%status = status
      report%last_failure_status = status
      return
    end if

    residual = residual - external_force
    report%final_residual_norm = maxval(abs(residual(free_dofs)))
    report%final_load_factor = 1.0_dp
    report%status = DES_STATUS_OK
    report%converged = report%final_residual_norm < tolerance
    if (.not. report%converged) then
      report%status = DES_ERROR_NEWTON_DID_NOT_CONVERGE
      report%last_failure_status = DES_ERROR_NEWTON_DID_NOT_CONVERGE
    end if
  end subroutine solve_q4_plane_strain_force_control

  subroutine prepare_force_control_problem( &
      X, u, residual, fixed_dofs, external_force, n_increments, &
      max_iterations, tolerance, is_fixed, free_dofs, status)
    real(dp), intent(in) :: X(:,:), u(:,:), residual(:), external_force(:), tolerance
    integer, intent(in) :: fixed_dofs(:), n_increments, max_iterations
    logical, allocatable, intent(out) :: is_fixed(:)
    integer, allocatable, intent(out) :: free_dofs(:)
    integer, intent(out) :: status

    integer :: nnode, ndof, nfree
    integer :: a, dof, cursor

    status = DES_STATUS_OK
    nnode = size(X,1)
    ndof = 2*nnode

    if (size(X,2) /= 2 .or. size(u,1) /= nnode .or. size(u,2) /= 2 .or. &
        size(residual) /= ndof .or. size(external_force) /= ndof) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    if (size(fixed_dofs) < 1 .or. n_increments < 1 .or. max_iterations < 1 .or. &
        tolerance <= 0.0_dp) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    allocate(is_fixed(ndof))
    is_fixed = .false.

    do a = 1,size(fixed_dofs)
      dof = fixed_dofs(a)
      if (dof < 1 .or. dof > ndof) then
        status = DES_ERROR_INVALID_CONSTRAINT
        return
      end if
      if (is_fixed(dof)) then
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
    do dof = 1,ndof
      if (.not. is_fixed(dof)) then
        cursor = cursor + 1
        free_dofs(cursor) = dof
      end if
    end do
  end subroutine prepare_force_control_problem

  subroutine enforce_zero_dofs(u, fixed_dofs)
    real(dp), intent(inout) :: u(:,:)
    integer, intent(in) :: fixed_dofs(:)
    integer :: a, dof, node, comp

    do a = 1,size(fixed_dofs)
      dof = fixed_dofs(a)
      node = (dof+1)/2
      comp = dof - 2*(node-1)
      u(node,comp) = 0.0_dp
    end do
  end subroutine enforce_zero_dofs

  subroutine record_force_linear_solve(report, linear_report)
    type(newton_report_t), intent(inout) :: report
    type(linear_solver_report_t), intent(in) :: linear_report

    report%linear_solve_count = report%linear_solve_count + 1
    report%last_linear_report = linear_report
    report%max_linear_equation_count = max( &
        report%max_linear_equation_count, linear_report%equation_count)
    if (linear_report%converged) then
      report%max_linear_residual_inf_norm = max( &
          report%max_linear_residual_inf_norm, linear_report%residual_inf_norm)
    end if
  end subroutine record_force_linear_solve

  subroutine add_force_history( &
      report, attempt, iteration, load_factor, increment_size, residual_norm, &
      min_j, status, accepted)
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
    call append_convergence_record(report%history, record)
  end subroutine add_force_history

end module des_q4_plane_strain_force_solver
