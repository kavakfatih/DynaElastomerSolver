program test_q4_internal_mesh_solver
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_material_types, only : neo_hookean_parameters_t
  use des_internal_mesh, only : internal_mesh_t, initialize_q4_internal_mesh
  use des_integration_point_results, only : integration_point_results_t
  use des_q4_plane_strain_newton_solver, only : newton_report_t
  use des_q4_internal_mesh_solver, only : solve_q4_internal_mesh_displacement_control
  implicit none

  real(dp) :: X(6,2), u(6,2), residual(12)
  integer :: connectivity(2,4), status, g
  integer, parameter :: prescribed_dofs(5) = [1,2,5,7,11]
  real(dp), parameter :: prescribed_values(5) = [0.0_dp,0.0_dp,0.5_dp,0.0_dp,0.5_dp]
  type(neo_hookean_parameters_t) :: parameters
  type(internal_mesh_t) :: mesh
  type(integration_point_results_t) :: integration_results
  type(newton_report_t) :: report

  X(1,:) = [0.0_dp,0.0_dp]
  X(2,:) = [1.0_dp,0.0_dp]
  X(3,:) = [2.0_dp,0.0_dp]
  X(4,:) = [0.0_dp,1.0_dp]
  X(5,:) = [1.0_dp,1.0_dp]
  X(6,:) = [2.0_dp,1.0_dp]
  connectivity(1,:) = [1,2,5,4]
  connectivity(2,:) = [2,3,6,5]

  call initialize_q4_internal_mesh(mesh, X, connectivity, status)
  if (status /= DES_STATUS_OK) error stop 'InternalMesh solver testi mesh olusturamadi.'

  parameters%mu = 2.5_dp
  parameters%lambda = 20.0_dp
  u = 0.0_dp

  call solve_q4_internal_mesh_displacement_control( &
    mesh, parameters, prescribed_dofs, prescribed_values, &
    5, 25, 2.0e-11_dp, u, residual, report, integration_results)

  if (.not. report%converged .or. report%status /= DES_STATUS_OK) then
    error stop 'InternalMesh solver adapteri yakinsamadi.'
  end if
  if (integration_results%count() /= 8) then
    error stop 'Iki Q4 eleman icin sekiz Gauss sonucu bekleniyordu.'
  end if

  do g = 1,integration_results%count()
    if (.not. integration_results%points(g)%valid) then
      error stop 'Solver sonrasi ham Gauss sonucu gecersiz.'
    end if
    if (integration_results%points(g)%J <= 0.0_dp) then
      error stop 'Solver sonrasi Gauss J sonucu fiziksel degil.'
    end if
  end do

  if (integration_results%points(1)%element_id /= 1 .or. &
      integration_results%points(5)%element_id /= 2) then
    error stop 'Gauss element kimlikleri beklenen sirada degil.'
  end if

  write(*,'(A,I0)') 'InternalMesh solver Newton iterations = ', report%total_iterations
  write(*,'(A,I0)') 'Final ham Gauss sonucu sayisi = ', integration_results%count()
  write(*,'(A)') 'InternalMesh solver adapter testi BASARILI.'
end program test_q4_internal_mesh_solver
