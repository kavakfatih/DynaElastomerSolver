program test_q4_severe_distortion_solver
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_material_types, only : neo_hookean_parameters_t
  use des_internal_mesh, only : internal_mesh_t, initialize_q4_internal_mesh
  use des_integration_point_results, only : integration_point_results_t
  use des_q4_plane_strain_newton_solver, only : newton_report_t
  use des_q4_internal_mesh_solver, only : solve_q4_internal_mesh_displacement_control
  implicit none

  real(dp) :: X(9,2), u(9,2), residual(18), H(2,2)
  real(dp) :: prescribed_values(16), expected_center(2), expected_F(3,3)
  real(dp) :: center_error, force_sum_x, force_sum_y
  real(dp) :: min_weight, max_weight, weight_ratio, max_F_error, expected_J
  integer :: connectivity(4,4), boundary_nodes(8), prescribed_dofs(16)
  integer :: status, a, node, idx, g
  type(neo_hookean_parameters_t) :: parameters
  type(internal_mesh_t) :: mesh
  type(integration_point_results_t) :: integration_results
  type(newton_report_t) :: report

  ! 2x2 Q4 mesh; merkez düğüm özellikle ciddi biçimde sağ-alt yöne kaydırılmıştır.
  ! Bu geometri Gauss noktalarında pozitif fakat geniş aralıklı reference Jacobian üretir.
  X(1,:) = [0.0_dp,0.0_dp]
  X(2,:) = [1.0_dp,0.0_dp]
  X(3,:) = [2.0_dp,0.0_dp]
  X(4,:) = [0.0_dp,1.0_dp]
  X(5,:) = [1.45_dp,0.55_dp]
  X(6,:) = [2.0_dp,1.0_dp]
  X(7,:) = [0.0_dp,2.0_dp]
  X(8,:) = [1.0_dp,2.0_dp]
  X(9,:) = [2.0_dp,2.0_dp]

  connectivity(1,:) = [1,2,5,4]
  connectivity(2,:) = [2,3,6,5]
  connectivity(3,:) = [4,5,8,7]
  connectivity(4,:) = [5,6,9,8]

  call initialize_q4_internal_mesh(mesh, X, connectivity, status)
  if (status /= DES_STATUS_OK) error stop 'Severe-distortion benchmark mesh olusturamadi.'

  ! Büyük affine finite-strain alanı. Q4 izoparametrik eleman affine fiziksel alanı
  ! geometrik distorsiyondan bağımsız olarak yeniden üretebilmelidir.
  H(1,:) = [0.35_dp, 0.28_dp]
  H(2,:) = [0.12_dp,-0.22_dp]

  boundary_nodes = [1,2,3,4,6,7,8,9]
  idx = 0
  do a = 1,size(boundary_nodes)
    node = boundary_nodes(a)
    idx = idx + 1
    prescribed_dofs(idx) = 2*(node-1)+1
    prescribed_values(idx) = H(1,1)*X(node,1) + H(1,2)*X(node,2)
    idx = idx + 1
    prescribed_dofs(idx) = 2*(node-1)+2
    prescribed_values(idx) = H(2,1)*X(node,1) + H(2,2)*X(node,2)
  end do

  expected_center(1) = H(1,1)*X(5,1) + H(1,2)*X(5,2)
  expected_center(2) = H(2,1)*X(5,1) + H(2,2)*X(5,2)

  expected_F = 0.0_dp
  expected_F(1,1) = 1.0_dp + H(1,1)
  expected_F(1,2) = H(1,2)
  expected_F(2,1) = H(2,1)
  expected_F(2,2) = 1.0_dp + H(2,2)
  expected_F(3,3) = 1.0_dp
  expected_J = expected_F(1,1)*expected_F(2,2) - expected_F(1,2)*expected_F(2,1)

  parameters%mu = 2.7_dp
  parameters%lambda = 25.0_dp
  u = 0.0_dp

  call solve_q4_internal_mesh_displacement_control( &
    mesh, parameters, prescribed_dofs, prescribed_values, &
    6, 30, 2.0e-11_dp, u, residual, report, integration_results)

  if (.not. report%converged .or. report%status /= DES_STATUS_OK) then
    error stop 'Yuksek distorsiyonlu Q4 nonlinear solver yakinsamadi.'
  end if

  center_error = maxval(abs(u(5,:) - expected_center))
  if (center_error > 5.0e-10_dp) then
    error stop 'Yuksek distorsiyonlu mesh affine merkez displacementini yeniden uretemedi.'
  end if

  force_sum_x = sum(residual(1:18:2))
  force_sum_y = sum(residual(2:18:2))
  if (abs(force_sum_x) > 5.0e-9_dp .or. abs(force_sum_y) > 5.0e-9_dp) then
    error stop 'Yuksek distorsiyon benchmarkinda global kuvvet dengesi kapanmadi.'
  end if

  if (integration_results%count() /= 16) then
    error stop 'Dort Q4 eleman icin 16 ham Gauss sonucu bekleniyordu.'
  end if

  min_weight = huge(1.0_dp)
  max_weight = 0.0_dp
  max_F_error = 0.0_dp
  do g = 1,integration_results%count()
    if (.not. integration_results%points(g)%valid) then
      error stop 'Yuksek distorsiyon benchmarkinda gecersiz Gauss sonucu var.'
    end if

    min_weight = min(min_weight, integration_results%points(g)%reference_weight)
    max_weight = max(max_weight, integration_results%points(g)%reference_weight)
    max_F_error = max(max_F_error, &
      maxval(abs(integration_results%points(g)%F - expected_F)))

    if (abs(integration_results%points(g)%J - expected_J) > 5.0e-10_dp) then
      error stop 'Gauss J sonucu affine referansla uyusmuyor.'
    end if
  end do

  if (min_weight <= 0.05_dp) then
    error stop 'Reference mesh Jacobiani severe-distortion testinde fazla kucuk/gecersiz.'
  end if
  weight_ratio = min_weight/max_weight
  if (weight_ratio >= 0.20_dp) then
    error stop 'Benchmark geometrisi hedeflenen yuksek distorsiyon seviyesine ulasmadi.'
  end if
  if (max_F_error > 5.0e-10_dp) then
    error stop 'Gauss deformation gradient affine referansla uyusmuyor.'
  end if
  if (report%min_j <= 0.0_dp) then
    error stop 'Newton yolu non-positive material J gordu.'
  end if
  if (report%linear_solve_count <= 0) then
    error stop 'Severe-distortion benchmark lineer solve diagnostics uretmedi.'
  end if
  if (report%max_linear_residual_inf_norm > 1.0e-9_dp) then
    error stop 'Severe-distortion benchmark lineer residual toleransi asti.'
  end if

  write(*,'(A,ES12.4)') 'Severe mesh min reference weight = ', min_weight
  write(*,'(A,ES12.4)') 'Severe mesh weight ratio = ', weight_ratio
  write(*,'(A,ES12.4)') 'Affine center displacement error = ', center_error
  write(*,'(A,ES12.4)') 'Max Gauss F error = ', max_F_error
  write(*,'(A,I0)') 'Newton lineer solve sayisi = ', report%linear_solve_count
  write(*,'(A)') 'Yuksek distorsiyonlu Q4 nonlinear benchmark testi BASARILI.'
end program test_q4_severe_distortion_solver
