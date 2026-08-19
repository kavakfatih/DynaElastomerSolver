program test_q9_internal_mesh
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONNECTIVITY
  use des_internal_mesh, only : internal_mesh_t, initialize_q9_internal_mesh, &
                                validate_internal_mesh
  implicit none

  type(internal_mesh_t) :: mesh, invalid_mesh
  real(dp) :: X(15,2)
  integer :: conn(2,9), bad_conn(2,9)
  integer :: status,ix,iy,id

  id = 0
  do iy = 0,2
    do ix = 0,4
      id = id+1
      X(id,:) = [0.5_dp*real(ix,dp),0.5_dp*real(iy,dp)]
    end do
  end do

  conn(1,:) = [1,3,13,11,2,8,12,6,7]
  conn(2,:) = [3,5,15,13,4,10,14,8,9]

  call initialize_q9_internal_mesh(mesh,X,conn,status)
  if (status /= DES_STATUS_OK) error stop 'Q9 InternalMesh initialize basarisiz.'
  if (mesh%node_count() /= 15) error stop 'Q9 InternalMesh node_count hatali.'
  if (mesh%element_count() /= 2) error stop 'Q9 InternalMesh element_count hatali.'
  if (mesh%element_node_count() /= 9) error stop 'Q9 InternalMesh element_node_count hatali.'
  if (.not. mesh%is_q9()) error stop 'Q9 InternalMesh topology kimligi hatali.'
  if (mesh%is_q4()) error stop 'Q9 InternalMesh yanlislikla Q4 olarak isaretlendi.'

  call validate_internal_mesh(mesh,status)
  if (status /= DES_STATUS_OK) error stop 'Q9 InternalMesh yeniden validation basarisiz.'

  bad_conn = conn
  bad_conn(2,9) = bad_conn(2,1)
  call initialize_q9_internal_mesh(invalid_mesh,X,bad_conn,status)
  if (status /= DES_ERROR_INVALID_CONNECTIVITY) then
    error stop 'Yinelenen dugum iceren Q9 InternalMesh reddedilmedi.'
  end if
  if (allocated(invalid_mesh%coordinates) .or. allocated(invalid_mesh%q9_connectivity)) then
    error stop 'Gecersiz Q9 InternalMesh initialize sonrasi temizlenmedi.'
  end if

  write(*,'(A,I0)') 'Q9 InternalMesh node count = ',mesh%node_count()
  write(*,'(A,I0)') 'Q9 InternalMesh element count = ',mesh%element_count()
  write(*,'(A)') 'Q9 InternalMesh topology/validation testi BASARILI.'
end program test_q9_internal_mesh
