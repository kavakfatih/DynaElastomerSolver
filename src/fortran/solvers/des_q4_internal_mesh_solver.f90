module des_q4_internal_mesh_solver
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_internal_mesh, only : internal_mesh_t, validate_internal_mesh
  use des_integration_point_results, only : integration_point_results_t, &
                                            initialize_q4_integration_results
  use des_material_types, only : neo_hookean_parameters_t
  use des_linear_solver, only : linear_solver_settings_t
  use des_q4_plane_strain_newton_solver, only : newton_report_t, &
       solve_q4_plane_strain_displacement_control, &
       solve_q4_plane_strain_adaptive_displacement_control
  use des_q4_plane_strain_fbar_force_solver, only : &
       solve_q4_plane_strain_fbar_force_control, &
       solve_q4_plane_strain_fbar_adaptive_force_control
  use des_q4_plane_strain_mesh_neo_hookean, only : assemble_q4_plane_strain_mesh
  implicit none
  private

  public :: solve_q4_internal_mesh_displacement_control
  public :: solve_q4_internal_mesh_adaptive_displacement_control
  public :: solve_q4_internal_mesh_fbar_force_control
  public :: solve_q4_internal_mesh_fbar_adaptive_force_control

contains

  subroutine solve_q4_internal_mesh_displacement_control( &
      mesh, parameters, prescribed_dofs, prescribed_final_values, &
      n_increments, max_iterations, tolerance, u, residual, report, integration_results, &
      linear_settings)
    type(internal_mesh_t), intent(in) :: mesh
    type(neo_hookean_parameters_t), intent(in) :: parameters
    integer, intent(in) :: prescribed_dofs(:)
    real(dp), intent(in) :: prescribed_final_values(:)
    integer, intent(in) :: n_increments, max_iterations
    real(dp), intent(in) :: tolerance
    real(dp), intent(inout) :: u(:,:)
    real(dp), intent(out) :: residual(:)
    type(newton_report_t), intent(out) :: report
    type(integration_point_results_t), intent(out) :: integration_results
    type(linear_solver_settings_t), intent(in), optional :: linear_settings

    integer :: mesh_status

    call validate_internal_mesh(mesh, mesh_status)
    if (mesh_status /= DES_STATUS_OK) then
      report = newton_report_t()
      report%status = mesh_status
      residual = 0.0_dp
      call initialize_q4_integration_results(integration_results, 0)
      return
    end if

    if (present(linear_settings)) then
      call solve_q4_plane_strain_displacement_control( &
        mesh%coordinates, mesh%q4_connectivity, parameters, &
        prescribed_dofs, prescribed_final_values, n_increments, max_iterations, &
        tolerance, u, residual, report, linear_settings)
    else
      call solve_q4_plane_strain_displacement_control( &
        mesh%coordinates, mesh%q4_connectivity, parameters, &
        prescribed_dofs, prescribed_final_values, n_increments, max_iterations, &
        tolerance, u, residual, report)
    end if

    call collect_final_integration_results(mesh, u, parameters, residual, report, integration_results)
  end subroutine solve_q4_internal_mesh_displacement_control

  subroutine solve_q4_internal_mesh_adaptive_displacement_control( &
      mesh, parameters, prescribed_dofs, prescribed_final_values, &
      initial_increment, min_increment, cutback_factor, max_cutbacks, &
      max_iterations, tolerance, u, residual, report, integration_results, linear_settings)
    type(internal_mesh_t), intent(in) :: mesh
    type(neo_hookean_parameters_t), intent(in) :: parameters
    integer, intent(in) :: prescribed_dofs(:)
    real(dp), intent(in) :: prescribed_final_values(:)
    real(dp), intent(in) :: initial_increment, min_increment, cutback_factor
    integer, intent(in) :: max_cutbacks, max_iterations
    real(dp), intent(in) :: tolerance
    real(dp), intent(inout) :: u(:,:)
    real(dp), intent(out) :: residual(:)
    type(newton_report_t), intent(out) :: report
    type(integration_point_results_t), intent(out) :: integration_results
    type(linear_solver_settings_t), intent(in), optional :: linear_settings

    integer :: mesh_status

    call validate_internal_mesh(mesh, mesh_status)
    if (mesh_status /= DES_STATUS_OK) then
      report = newton_report_t()
      report%status = mesh_status
      residual = 0.0_dp
      call initialize_q4_integration_results(integration_results, 0)
      return
    end if

    if (present(linear_settings)) then
      call solve_q4_plane_strain_adaptive_displacement_control( &
        mesh%coordinates, mesh%q4_connectivity, parameters, &
        prescribed_dofs, prescribed_final_values, initial_increment, min_increment, &
        cutback_factor, max_cutbacks, max_iterations, tolerance, u, residual, report, &
        linear_settings)
    else
      call solve_q4_plane_strain_adaptive_displacement_control( &
        mesh%coordinates, mesh%q4_connectivity, parameters, &
        prescribed_dofs, prescribed_final_values, initial_increment, min_increment, &
        cutback_factor, max_cutbacks, max_iterations, tolerance, u, residual, report)
    end if

    call collect_final_integration_results(mesh, u, parameters, residual, report, integration_results)
  end subroutine solve_q4_internal_mesh_adaptive_displacement_control

  subroutine solve_q4_internal_mesh_fbar_force_control( &
      mesh, parameters, fixed_dofs, external_force, n_increments, max_iterations, &
      tolerance, u, residual, report, integration_results, linear_settings)
    ! Production F-bar force-control yolunu kanonik InternalMesh modeli üzerinden açar.
    ! F-bar'a özgü J-bar ve derived-pressure Results doğrudan production solverdan gelir.
    type(internal_mesh_t), intent(in) :: mesh
    type(neo_hookean_parameters_t), intent(in) :: parameters
    integer, intent(in) :: fixed_dofs(:)
    real(dp), intent(in) :: external_force(:)
    integer, intent(in) :: n_increments, max_iterations
    real(dp), intent(in) :: tolerance
    real(dp), intent(inout) :: u(:,:)
    real(dp), intent(out) :: residual(:)
    type(newton_report_t), intent(out) :: report
    type(integration_point_results_t), intent(out) :: integration_results
    type(linear_solver_settings_t), intent(in), optional :: linear_settings

    integer :: mesh_status

    call validate_internal_mesh(mesh, mesh_status)
    if (mesh_status /= DES_STATUS_OK) then
      report = newton_report_t()
      report%status = mesh_status
      residual = 0.0_dp
      call initialize_q4_integration_results(integration_results, 0)
      return
    end if

    if (present(linear_settings)) then
      call solve_q4_plane_strain_fbar_force_control( &
        mesh%coordinates, mesh%q4_connectivity, parameters, fixed_dofs, external_force, &
        n_increments, max_iterations, tolerance, u, residual, report, &
        linear_settings=linear_settings, integration_results=integration_results)
    else
      call solve_q4_plane_strain_fbar_force_control( &
        mesh%coordinates, mesh%q4_connectivity, parameters, fixed_dofs, external_force, &
        n_increments, max_iterations, tolerance, u, residual, report, &
        integration_results=integration_results)
    end if
  end subroutine solve_q4_internal_mesh_fbar_force_control

  subroutine solve_q4_internal_mesh_fbar_adaptive_force_control( &
      mesh, parameters, fixed_dofs, external_force, initial_increment, min_increment, &
      cutback_factor, max_cutbacks, max_iterations, tolerance, u, residual, report, &
      integration_results, linear_settings)
    ! Adaptive F-bar production yolunu InternalMesh modeline bağlar. Böylece mesh I/O,
    ! UI ve gelecekteki axisymmetric katman solverın ham connectivity API'sine bağımlı kalmaz.
    type(internal_mesh_t), intent(in) :: mesh
    type(neo_hookean_parameters_t), intent(in) :: parameters
    integer, intent(in) :: fixed_dofs(:)
    real(dp), intent(in) :: external_force(:)
    real(dp), intent(in) :: initial_increment, min_increment, cutback_factor
    integer, intent(in) :: max_cutbacks, max_iterations
    real(dp), intent(in) :: tolerance
    real(dp), intent(inout) :: u(:,:)
    real(dp), intent(out) :: residual(:)
    type(newton_report_t), intent(out) :: report
    type(integration_point_results_t), intent(out) :: integration_results
    type(linear_solver_settings_t), intent(in), optional :: linear_settings

    integer :: mesh_status

    call validate_internal_mesh(mesh, mesh_status)
    if (mesh_status /= DES_STATUS_OK) then
      report = newton_report_t()
      report%status = mesh_status
      residual = 0.0_dp
      call initialize_q4_integration_results(integration_results, 0)
      return
    end if

    if (present(linear_settings)) then
      call solve_q4_plane_strain_fbar_adaptive_force_control( &
        mesh%coordinates, mesh%q4_connectivity, parameters, fixed_dofs, external_force, &
        initial_increment, min_increment, cutback_factor, max_cutbacks, max_iterations, &
        tolerance, u, residual, report, linear_settings=linear_settings, &
        integration_results=integration_results)
    else
      call solve_q4_plane_strain_fbar_adaptive_force_control( &
        mesh%coordinates, mesh%q4_connectivity, parameters, fixed_dofs, external_force, &
        initial_increment, min_increment, cutback_factor, max_cutbacks, max_iterations, &
        tolerance, u, residual, report, integration_results=integration_results)
    end if
  end subroutine solve_q4_internal_mesh_fbar_adaptive_force_control

  subroutine collect_final_integration_results( &
      mesh, u, parameters, residual, report, integration_results)
    type(internal_mesh_t), intent(in) :: mesh
    real(dp), intent(in) :: u(:,:)
    type(neo_hookean_parameters_t), intent(in) :: parameters
    real(dp), intent(inout) :: residual(:)
    type(newton_report_t), intent(inout) :: report
    type(integration_point_results_t), intent(out) :: integration_results

    real(dp), allocatable :: tangent(:,:)
    real(dp) :: min_j
    integer :: ndof, status

    if (.not. report%converged) then
      call initialize_q4_integration_results(integration_results, 0)
      return
    end if

    ndof = 2*mesh%node_count()
    allocate(tangent(ndof,ndof))

    call assemble_q4_plane_strain_mesh( &
      mesh, u, parameters, residual, tangent, status, min_j, integration_results)

    if (status /= DES_STATUS_OK) then
      report%status = status
      report%last_failure_status = status
      report%converged = .false.
      return
    end if

    report%min_j = min(report%min_j, min_j)
  end subroutine collect_final_integration_results

end module des_q4_internal_mesh_solver
