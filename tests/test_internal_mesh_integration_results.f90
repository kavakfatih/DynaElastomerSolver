program test_internal_mesh_integration_results
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONNECTIVITY
  use des_material_types, only : neo_hookean_parameters_t
  use des_internal_mesh, only : internal_mesh_t, initialize_q4_internal_mesh
  use des_integration_point_results, only : integration_point_results_t
  use des_q4_plane_strain_mesh_neo_hookean, only : assemble_q4_plane_strain_mesh
  implicit none

  real(dp) :: X(4,2), u(4,2)
  integer :: connectivity(1,4), invalid_connectivity(1,4)
  real(dp) :: residual_mesh(8), residual_arrays(8)
  real(dp) :: tangent_mesh(8,8), tangent_arrays(8,8)
  real(dp) :: min_j_mesh, min_j_arrays, expected_j
  integer :: status, status_arrays, g
  type(internal_mesh_t) :: mesh, invalid_mesh
  type(integration_point_results_t) :: results
  type(neo_hookean_parameters_t) :: parameters

  X(1,:) = [0.0_dp, 0.0_dp]
  X(2,:) = [1.0_dp, 0.0_dp]
  X(3,:) = [1.0_dp, 1.0_dp]
  X(4,:) = [0.0_dp, 1.0_dp]
  connectivity(1,:) = [1,2,3,4]

  call initialize_q4_internal_mesh(mesh, X, connectivity, status)
  if (status /= DES_STATUS_OK) error stop 'InternalMesh olusturulamadi.'
  if (mesh%node_count() /= 4) error stop 'InternalMesh node_count yanlis.'
  if (mesh%element_count() /= 1) error stop 'InternalMesh element_count yanlis.'

  ! Homojen affine deformasyon: F = diag(1.10, 0.95, 1.0).
  u(:,1) = 0.10_dp*X(:,1)
  u(:,2) = -0.05_dp*X(:,2)
  expected_j = 1.10_dp*0.95_dp

  parameters%mu = 2.3_dp
  parameters%lambda = 19.0_dp

  call assemble_q4_plane_strain_mesh( &
       mesh, u, parameters, residual_mesh, tangent_mesh, status, min_j_mesh, results)
  if (status /= DES_STATUS_OK) error stop 'InternalMesh assembly basarisiz.'
  if (results%count() /= 4) error stop 'Q4 icin dört Gauss sonucu bekleniyordu.'

  do g = 1,4
    if (.not. results%points(g)%valid) error stop 'Gauss sonucu gecersiz.'
    if (results%points(g)%element_id /= 1) error stop 'Gauss element_id yanlis.'
    if (results%points(g)%point_id /= g) error stop 'Gauss point_id yanlis.'
    if (abs(results%points(g)%J-expected_j) > 1.0e-12_dp) error stop 'Gauss J sonucu yanlis.'
    if (abs(results%points(g)%F(1,1)-1.10_dp) > 1.0e-12_dp) error stop 'Gauss F11 yanlis.'
    if (abs(results%points(g)%F(2,2)-0.95_dp) > 1.0e-12_dp) error stop 'Gauss F22 yanlis.'
    if (results%points(g)%strain_energy_density <= 0.0_dp) error stop 'Gauss enerji sonucu beklenmedik.'
  end do

  ! Yeni InternalMesh yolu, mevcut dizi tabanlı assembly ile aynı fizik sonucunu vermeli.
  call assemble_q4_plane_strain_mesh( &
       X, connectivity, u, parameters, residual_arrays, tangent_arrays, status_arrays, min_j_arrays)
  if (status_arrays /= DES_STATUS_OK) error stop 'Dizi tabanli referans assembly basarisiz.'
  if (maxval(abs(residual_mesh-residual_arrays)) > 1.0e-13_dp) then
    error stop 'InternalMesh ve dizi residual sonuçlari farkli.'
  end if
  if (maxval(abs(tangent_mesh-tangent_arrays)) > 1.0e-13_dp) then
    error stop 'InternalMesh ve dizi tangent sonuçlari farkli.'
  end if
  if (abs(min_j_mesh-min_j_arrays) > 1.0e-13_dp) then
    error stop 'InternalMesh ve dizi minimum J sonuçlari farkli.'
  end if

  ! Topolojik olarak yinelenen node içeren Q4 daha mesh kurulurken reddedilmeli.
  invalid_connectivity(1,:) = [1,2,2,4]
  call initialize_q4_internal_mesh(invalid_mesh, X, invalid_connectivity, status)
  if (status /= DES_ERROR_INVALID_CONNECTIVITY) then
    error stop 'Gecersiz Q4 connectivity reddedilmedi.'
  end if

  write(*,'(A,ES12.4)') 'InternalMesh min(J) = ', min_j_mesh
  write(*,'(A,I0)') 'Ham Gauss sonucu sayisi = ', results%count()
  write(*,'(A)') 'InternalMesh + integration-point result testi BASARILI.'
end program test_internal_mesh_integration_results
