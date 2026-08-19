module des_q4_plane_strain_mixed_up_force_solver
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONSTRAINT, &
                         DES_ERROR_NEWTON_DID_NOT_CONVERGE
  use des_material_types, only : neo_hookean_parameters_t
  use des_linear_solver, only : linear_solver_settings_t, linear_solver_report_t, &
                                solve_linear_system
  use des_solver_history, only : convergence_record_t, clear_convergence_history, &
                                 append_convergence_record, mark_last_convergence_status
  use des_q4_plane_strain_newton_solver, only : newton_report_t
  use des_q4_plane_strain_mixed_up_mesh, only : &
      assemble_q4_plane_strain_mixed_up_mesh
  implicit none
  private

  public :: solve_q4_plane_strain_mixed_up_force_control

contains

  subroutine solve_q4_plane_strain_mixed_up_force_control( &
      X, connectivity, parameters, fixed_dofs, external_force, &
      n_increments, max_iterations, tolerance, u, pressure, &
      residual, report, linear_settings)
    ! Q4-P0 mixed u-p için ilk global Full Newton driverı.
    ! Displacement DOF'ları önce, eleman-pressure DOF'ları sonra sıralanır.
    real(dp), intent(in) :: X(:,:)
    integer, intent(in) :: connectivity(:,:)
    type(neo_hookean_parameters_t), intent(in) :: parameters
    integer, intent(in) :: fixed_dofs(:)
    real(dp), intent(in) :: external_force(:)
    integer, intent(in) :: n_increments, max_iterations
    real(dp), intent(in) :: tolerance
    real(dp), intent(inout) :: u(:,:), pressure(:)
    real(dp), intent(out) :: residual(:)
    type(newton_report_t), intent(out) :: report
    type(linear_solver_settings_t), intent(in), optional :: linear_settings

    logical, allocatable :: is_fixed(:)
    integer, allocatable :: free_dofs(:)
    real(dp), allocatable :: K(:,:), Kff(:,:), rhs(:), delta(:)
    real(dp) :: min_j, load_factor, residual_norm, increment_size
    integer :: nnode, nelem, ndisp, ntotal, nfree, status
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

    call prepare_mixed_problem( &
        X, connectivity, u, pressure, residual, fixed_dofs, external_force, &
        n_increments, max_iterations, tolerance, is_fixed, free_dofs, &
        report%status)
    if (report%status /= DES_STATUS_OK) return

    nnode = size(X,1)
    nelem = size(connectivity,1)
    ndisp = 2*nnode
    ntotal = ndisp + nelem
    nfree = size(free_dofs)
    increment_size = 1.0_dp/real(n_increments,dp)
    report%increments_requested = n_increments

    allocate(K(ntotal,ntotal), Kff(nfree,nfree), rhs(nfree), delta(nfree))
    call enforce_zero_displacement_dofs(u, fixed_dofs)

    do increment = 1,n_increments
      report%increments_attempted = report%increments_attempted + 1
      load_factor = real(increment,dp)/real(n_increments,dp)
      increment_converged = .false.

      do iteration = 1,max_iterations
        call assemble_q4_plane_strain_mixed_up_mesh( &
            X, connectivity, u, pressure, parameters, residual, K, status, min_j)
        report%min_j = min(report%min_j, min_j)
        if (status /= DES_STATUS_OK) then
          call add_mixed_history(report, increment, iteration, load_factor, &
                                 increment_size, huge(1.0_dp), min_j, status, .false.)
          report%status = status
          report%last_failure_status = status
          return
        end if

        residual(1:ndisp) = residual(1:ndisp) &
          - load_factor*external_force
        rhs = -residual(free_dofs)
        residual_norm = maxval(abs(rhs))
        report%final_residual_norm = residual_norm

        if (residual_norm < tolerance) then
          call add_mixed_history(report, increment, iteration, load_factor, &
                                 increment_size, residual_norm, min_j, &
                                 DES_STATUS_OK, .true.)
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

        call solve_linear_system( &
            Kff, rhs, delta, active_linear_settings, linear_report)
        call record_mixed_linear_solve(report, linear_report)
        if (.not. linear_report%converged) then
          call add_mixed_history(report, increment, iteration, load_factor, &
                                 increment_size, residual_norm, min_j, &
                                 linear_report%status, .false.)
          report%status = linear_report%status
          report%last_failure_status = linear_report%status
          return
        end if

        call add_mixed_history(report, increment, iteration, load_factor, &
                               increment_size, residual_norm, min_j, &
                               DES_STATUS_OK, .false.)

        do a = 1,nfree
          dof = free_dofs(a)
          if (dof <= ndisp) then
            node = (dof+1)/2
            comp = dof - 2*(node-1)
            u(node,comp) = u(node,comp) + delta(a)
          else
            pressure(dof-ndisp) = pressure(dof-ndisp) + delta(a)
          end if
        end do
        call enforce_zero_displacement_dofs(u, fixed_dofs)
        report%total_iterations = report%total_iterations + 1
      end do

      if (.not. increment_converged) then
        call mark_last_convergence_status( &
            report%history, DES_ERROR_NEWTON_DID_NOT_CONVERGE)
        report%status = DES_ERROR_NEWTON_DID_NOT_CONVERGE
        report%last_failure_status = DES_ERROR_NEWTON_DID_NOT_CONVERGE
        return
      end if
    end do

    call assemble_q4_plane_strain_mixed_up_mesh( &
        X, connectivity, u, pressure, parameters, residual, K, status, min_j)
    report%min_j = min(report%min_j, min_j)
    if (status /= DES_STATUS_OK) then
      report%status = status
      report%last_failure_status = status
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
  end subroutine solve_q4_plane_strain_mixed_up_force_control

  subroutine prepare_mixed_problem( &
      X, connectivity, u, pressure, residual, fixed_dofs, external_force, &
      n_increments, max_iterations, tolerance, is_fixed, free_dofs, status)
    real(dp), intent(in) :: X(:,:), u(:,:), pressure(:), residual(:)
    real(dp), intent(in) :: external_force(:), tolerance
    integer, intent(in) :: connectivity(:,:), fixed_dofs(:)
    integer, intent(in) :: n_increments, max_iterations
    logical, allocatable, intent(out) :: is_fixed(:)
    integer, allocatable, intent(out) :: free_dofs(:)
    integer, intent(out) :: status

    integer :: nnode, nelem, ndisp, ntotal, nfree
    integer :: a, dof, cursor

    status = DES_STATUS_OK
    nnode = size(X,1)
    nelem = size(connectivity,1)
    ndisp = 2*nnode
    ntotal = ndisp + nelem

    if (size(X,2) /= 2 .or. size(u,1) /= nnode .or. size(u,2) /= 2) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if
    if (size(connectivity,2) /= 4 .or. nelem < 1) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if
    if (size(pressure) /= nelem .or. size(residual) /= ntotal) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if
    if (size(external_force) /= ndisp .or. size(fixed_dofs) < 1) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if
    if (n_increments < 1 .or. max_iterations < 1 .or. tolerance <= 0.0_dp) then
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
  end subroutine prepare_mixed_problem

  subroutine enforce_zero_displacement_dofs(u, fixed_dofs)
    real(dp), intent(inout) :: u(:,:)
    integer, intent(in) :: fixed_dofs(:)
    integer :: a, dof, node, comp

    do a = 1,size(fixed_dofs)
      dof = fixed_dofs(a)
      node = (dof+1)/2
      comp = dof - 2*(node-1)
      u(node,comp) = 0.0_dp
    end do
  end subroutine enforce_zero_displacement_dofs

  subroutine record_mixed_linear_solve(report, linear_report)
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
  end subroutine record_mixed_linear_solve

  subroutine add_mixed_history( &
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
  end subroutine add_mixed_history

end module des_q4_plane_strain_mixed_up_force_solver
