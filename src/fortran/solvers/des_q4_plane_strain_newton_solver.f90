module des_q4_plane_strain_newton_solver
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONSTRAINT, &
                         DES_ERROR_LINEAR_SOLVE, DES_ERROR_NEWTON_DID_NOT_CONVERGE
  use des_dense_linear, only : solve_dense_system
  use des_material_types, only : neo_hookean_parameters_t
  use des_q4_plane_strain_mesh_neo_hookean, only : assemble_q4_plane_strain_mesh
  implicit none
  private
  public :: newton_report_t, solve_q4_plane_strain_displacement_control

  type :: newton_report_t
    integer :: status = DES_STATUS_OK
    integer :: increments_requested = 0
    integer :: increments_converged = 0
    integer :: total_iterations = 0
    integer :: max_iterations_used = 0
    real(dp) :: final_residual_norm = huge(1.0_dp)
    real(dp) :: min_j = huge(1.0_dp)
    logical :: converged = .false.
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
    real(dp) :: min_j, load_factor, residual_norm
    integer :: ndof, nnode, nfree, status
    integer :: increment, iteration, a, b, dof, node, comp
    logical :: ok, increment_converged

    report = newton_report_t()
    report%increments_requested = n_increments
    residual = 0.0_dp

    nnode = size(X,1)
    ndof = 2*nnode

    if (size(u,1) /= nnode .or. size(u,2) /= 2 .or. size(residual) /= ndof) then
      report%status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if
    if (size(prescribed_dofs) /= size(prescribed_final_values)) then
      report%status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if
    if (n_increments < 1 .or. max_iterations < 1 .or. tolerance <= 0.0_dp) then
      report%status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    allocate(is_prescribed(ndof))
    is_prescribed = .false.
    do a = 1,size(prescribed_dofs)
      dof = prescribed_dofs(a)
      if (dof < 1 .or. dof > ndof .or. is_prescribed(dof)) then
        report%status = DES_ERROR_INVALID_CONSTRAINT
        return
      end if
      is_prescribed(dof) = .true.
    end do

    nfree = count(.not. is_prescribed)
    if (nfree < 1) then
      report%status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    allocate(free_dofs(nfree), K(ndof,ndof), Kff(nfree,nfree), rhs(nfree), du(nfree))
    b = 0
    do dof = 1,ndof
      if (.not. is_prescribed(dof)) then
        b = b + 1
        free_dofs(b) = dof
      end if
    end do

    do increment = 1,n_increments
      load_factor = real(increment,dp)/real(n_increments,dp)

      do a = 1,size(prescribed_dofs)
        call set_global_dof(u, prescribed_dofs(a), load_factor*prescribed_final_values(a))
      end do

      increment_converged = .false.
      do iteration = 1,max_iterations
        call assemble_q4_plane_strain_mesh(X, connectivity, u, parameters, residual, K, status, min_j)
        report%min_j = min(report%min_j, min_j)
        if (status /= DES_STATUS_OK) then
          report%status = status
          return
        end if

        rhs = -residual(free_dofs)
        residual_norm = maxval(abs(rhs))
        report%final_residual_norm = residual_norm

        if (residual_norm < tolerance) then
          increment_converged = .true.
          report%increments_converged = increment
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
          report%status = DES_ERROR_LINEAR_SOLVE
          return
        end if

        do a = 1,nfree
          dof = free_dofs(a)
          node = (dof+1)/2
          comp = dof - 2*(node-1)
          u(node,comp) = u(node,comp) + du(a)
        end do
        report%total_iterations = report%total_iterations + 1
      end do

      if (.not. increment_converged) then
        report%status = DES_ERROR_NEWTON_DID_NOT_CONVERGE
        return
      end if
    end do

    ! Son durumda residual yeniden değerlendirilir; prescribed DOF reaksiyonları burada okunabilir.
    call assemble_q4_plane_strain_mesh(X, connectivity, u, parameters, residual, K, status, min_j)
    report%min_j = min(report%min_j, min_j)
    if (status /= DES_STATUS_OK) then
      report%status = status
      return
    end if

    report%status = DES_STATUS_OK
    report%converged = .true.
  end subroutine solve_q4_plane_strain_displacement_control

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
