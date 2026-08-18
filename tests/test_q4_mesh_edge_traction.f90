program test_q4_mesh_edge_traction
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONNECTIVITY, &
                         DES_ERROR_INVALID_CONSTRAINT
  use des_internal_mesh, only : internal_mesh_t, initialize_q4_internal_mesh
  use des_q4_edge_traction, only : Q4_EDGE_RIGHT
  use des_q4_mesh_edge_traction, only : add_q4_reference_edge_traction
  implicit none

  real(dp), parameter :: tol = 1.0e-12_dp
  type(internal_mesh_t) :: mesh
  real(dp) :: coordinates(6,2), global_force(12), traction(2), edge_length
  real(dp) :: before(12)
  integer :: connectivity(2,4)
  integer :: status

  coordinates(1,:) = [0.0_dp, 0.0_dp]
  coordinates(2,:) = [1.0_dp, 0.0_dp]
  coordinates(3,:) = [2.0_dp, 0.0_dp]
  coordinates(4,:) = [0.0_dp, 1.0_dp]
  coordinates(5,:) = [1.0_dp, 1.0_dp]
  coordinates(6,:) = [2.0_dp, 1.0_dp]

  connectivity(1,:) = [1,2,5,4]
  connectivity(2,:) = [2,3,6,5]

  call initialize_q4_internal_mesh(mesh, coordinates, connectivity, status)
  if (status /= DES_STATUS_OK) error stop 'InternalMesh oluşturulamadı.'

  global_force = 0.0_dp
  traction = [4.0_dp, 2.0_dp]
  call add_q4_reference_edge_traction( &
      mesh, 2, Q4_EDGE_RIGHT, traction, global_force, status, edge_length)

  if (status /= DES_STATUS_OK) error stop 'Global edge traction assembly başarısız.'
  if (abs(edge_length - 1.0_dp) > tol) error stop 'Global assembly edge uzunluğu hatalı.'

  ! Sağ sınır node 3 ve node 6'dır; sabit traction iki node'a eşit dağılır.
  if (abs(global_force(5) - 2.0_dp) > tol) error stop 'Node 3 x yükü hatalı.'
  if (abs(global_force(6) - 1.0_dp) > tol) error stop 'Node 3 y yükü hatalı.'
  if (abs(global_force(11) - 2.0_dp) > tol) error stop 'Node 6 x yükü hatalı.'
  if (abs(global_force(12) - 1.0_dp) > tol) error stop 'Node 6 y yükü hatalı.'
  if (abs(sum(global_force(1:12:2)) - 4.0_dp) > tol) error stop 'Global x kuvveti korunmadı.'
  if (abs(sum(global_force(2:12:2)) - 2.0_dp) > tol) error stop 'Global y kuvveti korunmadı.'

  ! İkinci çağrı aynı global vektörde birikmelidir.
  traction = [-1.0_dp, 3.0_dp]
  call add_q4_reference_edge_traction( &
      mesh, 2, Q4_EDGE_RIGHT, traction, global_force, status, edge_length)
  if (status /= DES_STATUS_OK) error stop 'İkinci edge traction assembly başarısız.'
  if (abs(sum(global_force(1:12:2)) - 3.0_dp) > tol) error stop 'Birikimli global x kuvveti hatalı.'
  if (abs(sum(global_force(2:12:2)) - 5.0_dp) > tol) error stop 'Birikimli global y kuvveti hatalı.'

  ! Geçersiz element id global vektörü değiştirmemelidir.
  before = global_force
  call add_q4_reference_edge_traction( &
      mesh, 0, Q4_EDGE_RIGHT, traction, global_force, status, edge_length)
  if (status /= DES_ERROR_INVALID_CONNECTIVITY) error stop 'Geçersiz element id reddedilmedi.'
  if (maxval(abs(global_force-before)) > tol) error stop 'Geçersiz element çağrısı global kuvveti değiştirdi.'

  ! Global kuvvet vektörü yanlış boyuttaysa açık constraint hatası dönmelidir.
  call check_bad_global_size(mesh)

  write(*,'(A)') 'Q4 mesh edge traction assembly testi BASARILI.'

contains

  subroutine check_bad_global_size(active_mesh)
    type(internal_mesh_t), intent(in) :: active_mesh
    real(dp) :: bad_force(10), local_traction(2)
    integer :: local_status

    bad_force = 0.0_dp
    local_traction = [1.0_dp, 0.0_dp]
    call add_q4_reference_edge_traction( &
        active_mesh, 2, Q4_EDGE_RIGHT, local_traction, bad_force, local_status)
    if (local_status /= DES_ERROR_INVALID_CONSTRAINT) then
      error stop 'Yanlış global kuvvet boyutu reddedilmedi.'
    end if
  end subroutine check_bad_global_size

end program test_q4_mesh_edge_traction
