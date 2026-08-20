module des_q9_herrmann_solver_report
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_STATUS_NOT_EVALUATED, &
                         DES_ERROR_INVALID_PARAMETERS, DES_ERROR_INVALID_CONNECTIVITY, &
                         DES_ERROR_INVALID_CONSTRAINT, DES_ERROR_NONFINITE_NONLINEAR
  use des_internal_mesh, only : internal_mesh_t, validate_internal_mesh
  use des_linear_solver, only : linear_solver_settings_t
  use des_nonlinear_solver, only : nonlinear_solver_settings_t
  use des_q4_plane_strain_newton_solver, only : newton_report_t
  use des_q9_plane_strain_herrmann_neo_hookean, only : &
      Q9_HERRMANN_P_DOF, Q9_HERRMANN_QUADRATURE_2X2, &
      Q9_HERRMANN_QUADRATURE_3X3, Q9_HERRMANN_QUADRATURE_4X4
  use des_q9_plane_strain_herrmann_force_solver, only : &
      solve_q9_internal_mesh_herrmann_adaptive_force_control
  use des_q9_herrmann_geometry, only : q9_reference_gradient
  use des_herrmann_pressure_interpolation, only : herrmann_p1_pressure_basis
  use des_herrmann_pressure_constraint, only : herrmann_constraint_response_t, &
                                                evaluate_herrmann_pressure_constraint
  implicit none
  private

  type, public :: herrmann_solver_report_t
    type(newton_report_t) :: nonlinear
    real(dp) :: displacement_residual_inf_norm = huge(1.0_dp)
    real(dp) :: pressure_residual_inf_norm = huge(1.0_dp)
    real(dp) :: volumetric_constraint_inf_norm = huge(1.0_dp)
    integer :: metrics_status = DES_STATUS_NOT_EVALUATED
    integer :: nonfinite_event_count = 0
    integer :: last_nonfinite_stage = 0
    logical :: metrics_valid = .false.
  end type herrmann_solver_report_t

  public :: solve_q9_internal_mesh_herrmann_adaptive_reported
  public :: evaluate_q9_herrmann_solution_metrics

contains

  subroutine solve_q9_internal_mesh_herrmann_adaptive_reported( &
      mesh, shear_modulus, pressure_compliance, fixed_dofs, external_force, &
      initial_increment, min_increment, cutback_factor, max_cutbacks, &
      max_iterations, tolerance, u, pressure_coefficients, residual, report, &
      linear_settings, quadrature_order, nonlinear_settings)
    ! Production-facing Herrmann wrapper. Nonlinear orchestration mevcut solver'da
    ! kalır; bu katman mixed formulationa özgü convergence metriklerini ekler.
    ! B8.1 nonlinear settings optional olarak bu sınırdan da geçirildi; mevcut
    ! çağrılar son argüman optional olduğu için geriye uyumludur.
    ! B8.2 non-finite olay sayısı ve son yakalama aşamasını history/status
    ! üzerinden özetleyerek production-facing raporda doğrudan görünür kılar.
    type(internal_mesh_t), intent(in) :: mesh
    real(dp), intent(in) :: shear_modulus, pressure_compliance
    integer, intent(in) :: fixed_dofs(:)
    real(dp), intent(in) :: external_force(:)
    real(dp), intent(in) :: initial_increment, min_increment, cutback_factor
    integer, intent(in) :: max_cutbacks, max_iterations
    real(dp), intent(in) :: tolerance
    real(dp), intent(inout) :: u(:,:), pressure_coefficients(:,:)
    real(dp), intent(out) :: residual(:)
    type(herrmann_solver_report_t), intent(out) :: report
    type(linear_solver_settings_t), intent(in), optional :: linear_settings
    integer, intent(in), optional :: quadrature_order
    type(nonlinear_solver_settings_t), intent(in), optional :: nonlinear_settings

    integer :: active_quadrature
    type(nonlinear_solver_settings_t) :: active_nonlinear_settings

    report = herrmann_solver_report_t()
    active_quadrature = Q9_HERRMANN_QUADRATURE_3X3
    if (present(quadrature_order)) active_quadrature = quadrature_order
    active_nonlinear_settings = nonlinear_solver_settings_t()
    if (present(nonlinear_settings)) active_nonlinear_settings = nonlinear_settings

    if (present(linear_settings)) then
      if (present(quadrature_order)) then
        call solve_q9_internal_mesh_herrmann_adaptive_force_control( &
            mesh,shear_modulus,pressure_compliance,fixed_dofs,external_force, &
            initial_increment,min_increment,cutback_factor,max_cutbacks, &
            max_iterations,tolerance,u,pressure_coefficients,residual, &
            report%nonlinear,linear_settings,quadrature_order, &
            nonlinear_settings=active_nonlinear_settings)
      else
        call solve_q9_internal_mesh_herrmann_adaptive_force_control( &
            mesh,shear_modulus,pressure_compliance,fixed_dofs,external_force, &
            initial_increment,min_increment,cutback_factor,max_cutbacks, &
            max_iterations,tolerance,u,pressure_coefficients,residual, &
            report%nonlinear,linear_settings=linear_settings, &
            nonlinear_settings=active_nonlinear_settings)
      end if
    else
      if (present(quadrature_order)) then
        call solve_q9_internal_mesh_herrmann_adaptive_force_control( &
            mesh,shear_modulus,pressure_compliance,fixed_dofs,external_force, &
            initial_increment,min_increment,cutback_factor,max_cutbacks, &
            max_iterations,tolerance,u,pressure_coefficients,residual, &
            report%nonlinear,quadrature_order=quadrature_order, &
            nonlinear_settings=active_nonlinear_settings)
      else
        call solve_q9_internal_mesh_herrmann_adaptive_force_control( &
            mesh,shear_modulus,pressure_compliance,fixed_dofs,external_force, &
            initial_increment,min_increment,cutback_factor,max_cutbacks, &
            max_iterations,tolerance,u,pressure_coefficients,residual, &
            report%nonlinear,nonlinear_settings=active_nonlinear_settings)
      end if
    end if

    call summarize_nonfinite_diagnostics(report)
    if (.not. report%nonlinear%converged) return

    call evaluate_q9_herrmann_solution_metrics( &
        mesh,u,pressure_coefficients,pressure_compliance,fixed_dofs,residual, &
        active_quadrature,report%displacement_residual_inf_norm, &
        report%pressure_residual_inf_norm,report%volumetric_constraint_inf_norm, &
        report%metrics_status)
    report%metrics_valid = report%metrics_status == DES_STATUS_OK
  end subroutine solve_q9_internal_mesh_herrmann_adaptive_reported

  subroutine summarize_nonfinite_diagnostics(report)
    type(herrmann_solver_report_t), intent(inout) :: report
    integer :: h

    report%nonfinite_event_count = 0
    report%last_nonfinite_stage = 0

    do h = 1,report%nonlinear%history%count
      if (report%nonlinear%history%records(h)%status == DES_ERROR_NONFINITE_NONLINEAR) then
        report%nonfinite_event_count = report%nonfinite_event_count + 1
        report%last_nonfinite_stage = &
            report%nonlinear%history%records(h)%nonfinite_stage
      end if
    end do

    ! Non-finite caller inputlari state transaction baslamadan fail-fast olur ve
    ! bu nedenle history kaydi olusturmaz. Production raporda olay yine kaybolmaz.
    if (report%nonfinite_event_count == 0 .and. &
        report%nonlinear%last_failure_status == DES_ERROR_NONFINITE_NONLINEAR) then
      report%nonfinite_event_count = 1
    end if
  end subroutine summarize_nonfinite_diagnostics

  subroutine evaluate_q9_herrmann_solution_metrics( &
      mesh,u,pressure_coefficients,pressure_compliance,fixed_dofs,residual, &
      quadrature_order,displacement_norm,pressure_norm,volumetric_norm,status)
    type(internal_mesh_t), intent(in) :: mesh
    real(dp), intent(in) :: u(:,:), pressure_coefficients(:,:), pressure_compliance
    integer, intent(in) :: fixed_dofs(:), quadrature_order
    real(dp), intent(in) :: residual(:)
    real(dp), intent(out) :: displacement_norm, pressure_norm, volumetric_norm
    integer, intent(out) :: status

    logical, allocatable :: fixed(:)
    integer :: nnode, nelem, ndisp, ntotal, a, dof, mesh_status

    displacement_norm = huge(1.0_dp)
    pressure_norm = huge(1.0_dp)
    volumetric_norm = huge(1.0_dp)
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

    if (size(u,1) /= nnode .or. size(u,2) /= 2 .or. &
        size(pressure_coefficients,1) /= nelem .or. &
        size(pressure_coefficients,2) /= Q9_HERRMANN_P_DOF .or. &
        size(residual) /= ntotal .or. pressure_compliance < 0.0_dp) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    allocate(fixed(ndisp))
    fixed = .false.
    do a = 1,size(fixed_dofs)
      dof = fixed_dofs(a)
      if (dof < 1 .or. dof > ndisp .or. fixed(dof)) then
        status = DES_ERROR_INVALID_CONSTRAINT
        return
      end if
      fixed(dof) = .true.
    end do

    displacement_norm = 0.0_dp
    do dof = 1,ndisp
      if (.not. fixed(dof)) displacement_norm = max(displacement_norm,abs(residual(dof)))
    end do

    pressure_norm = maxval(abs(residual(ndisp+1:ntotal)))

    call evaluate_pointwise_volumetric_constraint_norm( &
        mesh,u,pressure_coefficients,pressure_compliance,quadrature_order, &
        volumetric_norm,status)
  end subroutine evaluate_q9_herrmann_solution_metrics

  subroutine evaluate_pointwise_volumetric_constraint_norm( &
      mesh,u,pressure_coefficients,pressure_compliance,quadrature_order, &
      volumetric_norm,status)
    type(internal_mesh_t), intent(in) :: mesh
    real(dp), intent(in) :: u(:,:), pressure_coefficients(:,:), pressure_compliance
    integer, intent(in) :: quadrature_order
    real(dp), intent(out) :: volumetric_norm
    integer, intent(out) :: status

    type(herrmann_constraint_response_t) :: response
    real(dp) :: coordinate(4),weight(4)
    real(dp) :: Xe(9,2),ue(9,2),N(9),dN_parent(9,2),dN_dX(9,2)
    real(dp) :: x_point(2),Jmap(2,2),det_jac,Np(3),F(3,3),pressure
    integer :: n_gauss,e,a,i,jdir,gx,gy,node,point_status

    volumetric_norm = 0.0_dp
    status = DES_STATUS_OK
    call set_gauss_rule(quadrature_order,n_gauss,coordinate,weight,status)
    if (status /= DES_STATUS_OK) return

    do e = 1,mesh%element_count()
      do a = 1,9
        node = mesh%q9_connectivity(e,a)
        Xe(a,:) = mesh%coordinates(node,:)
        ue(a,:) = u(node,:)
      end do

      do gy = 1,n_gauss
        do gx = 1,n_gauss
          call q9_reference_gradient( &
              Xe,coordinate(gx),coordinate(gy),N,dN_parent,dN_dX, &
              x_point,Jmap,det_jac,point_status)
          if (point_status /= DES_STATUS_OK) then
            status = point_status
            return
          end if

          call herrmann_p1_pressure_basis(coordinate(gx),coordinate(gy),Np)
          pressure = dot_product(Np,pressure_coefficients(e,:))

          F = 0.0_dp
          F(1,1) = 1.0_dp
          F(2,2) = 1.0_dp
          F(3,3) = 1.0_dp
          do a = 1,9
            do i = 1,2
              do jdir = 1,2
                F(i,jdir) = F(i,jdir) + ue(a,i)*dN_dX(a,jdir)
              end do
            end do
          end do

          call evaluate_herrmann_pressure_constraint( &
              F,pressure,pressure_compliance,response)
          if (.not. response%valid) then
            status = response%status
            return
          end if
          volumetric_norm = max(volumetric_norm,abs(response%constraint))
        end do
      end do
    end do
  end subroutine evaluate_pointwise_volumetric_constraint_norm

  subroutine set_gauss_rule(order,n_gauss,coordinate,weight,status)
    integer, intent(in) :: order
    integer, intent(out) :: n_gauss,status
    real(dp), intent(out) :: coordinate(4),weight(4)
    real(dp), parameter :: gp3 = 0.77459666924148337704_dp
    real(dp), parameter :: gp2 = 0.57735026918962576451_dp
    real(dp), parameter :: gp4_outer = 0.86113631159405257522_dp
    real(dp), parameter :: gp4_inner = 0.33998104358485626480_dp
    real(dp), parameter :: gw4_outer = 0.34785484513745385737_dp
    real(dp), parameter :: gw4_inner = 0.65214515486254614263_dp

    coordinate = 0.0_dp
    weight = 0.0_dp
    status = DES_STATUS_OK

    select case (order)
    case (Q9_HERRMANN_QUADRATURE_2X2)
      n_gauss = 2
      coordinate(1:2) = [-gp2,gp2]
      weight(1:2) = [1.0_dp,1.0_dp]
    case (Q9_HERRMANN_QUADRATURE_3X3)
      n_gauss = 3
      coordinate(1:3) = [-gp3,0.0_dp,gp3]
      weight(1:3) = [5.0_dp/9.0_dp,8.0_dp/9.0_dp,5.0_dp/9.0_dp]
    case (Q9_HERRMANN_QUADRATURE_4X4)
      n_gauss = 4
      coordinate = [-gp4_outer,-gp4_inner,gp4_inner,gp4_outer]
      weight = [gw4_outer,gw4_inner,gw4_inner,gw4_outer]
    case default
      n_gauss = 0
      status = DES_ERROR_INVALID_PARAMETERS
    end select
  end subroutine set_gauss_rule

end module des_q9_herrmann_solver_report
