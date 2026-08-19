program test_q9_internal_mesh
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONNECTIVITY
  use des_internal_mesh, only : internal_mesh_t, initialize_q4_internal_mesh, &
                                initialize_q9_internal_mesh, validate_internal_mesh
  use des_q9_internal_mesh_herrmann_assembly, only : assemble_q9_internal_mesh_herrmann
  use des_q9_plane_strain_herrmann_mesh, only : assemble_q9_plane_strain_herrmann_mesh
  implicit none

  integer, parameter :: nnode = 15, nelem = 2, ntotal = 2*nnode + 3*nelem
  type(internal_mesh_t) :: mesh, invalid_mesh, q4_mesh
  real(dp) :: X(nnode,2), q4_X(4,2), u(nnode,2), p(nelem,3)
  integer :: conn(nelem,9), bad_conn(nelem,9), q4_conn(1,4)
  real(dp) :: residual_mesh(ntotal), residual_raw(ntotal)
  real(dp) :: tangent_mesh(ntotal,ntotal), tangent_raw(ntotal,ntotal)
  real(dp) :: min_j_mesh, min_j_raw
  integer :: status, raw_status, ix, iy, id, node

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
  if (mesh%node_count() /= nnode) error stop 'Q9 InternalMesh node_count hatali.'
  if (mesh%element_count() /= nelem) error stop 'Q9 InternalMesh element_count hatali.'
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

  ! Canonical InternalMesh facade'in ham array assembly ile ayni operatoru urettigini
  ! iki elemanli, non-affine bir durumda dogrula.
  do node = 1,nnode
    u(node,1) = 0.04_dp*X(node,1) + 0.03_dp*X(node,2) &
        + 0.012_dp*X(node,1)*X(node,2)
    u(node,2) = -0.015_dp*X(node,1) + 0.035_dp*X(node,2) &
        - 0.009_dp*X(node,1)*X(node,2)
  end do
  p(1,:) = [0.16_dp, 0.030_dp,-0.020_dp]
  p(2,:) = [0.12_dp,-0.025_dp, 0.018_dp]

  call assemble_q9_internal_mesh_herrmann( &
      mesh,u,p,2.5_dp,0.02_dp,residual_mesh,tangent_mesh,status,min_j_mesh)
  if (status /= DES_STATUS_OK) error stop 'Q9 InternalMesh Herrmann assembly basarisiz.'

  call assemble_q9_plane_strain_herrmann_mesh( &
      X,conn,u,p,2.5_dp,0.02_dp,residual_raw,tangent_raw,raw_status,min_j_raw)
  if (raw_status /= DES_STATUS_OK) error stop 'Q9 raw Herrmann assembly baseline basarisiz.'

  if (maxval(abs(residual_mesh-residual_raw)) > 5.0e-13_dp) then
    error stop 'Q9 InternalMesh residual ham assembly ile uyusmuyor.'
  end if
  if (maxval(abs(tangent_mesh-tangent_raw)) > 5.0e-13_dp) then
    error stop 'Q9 InternalMesh tangent ham assembly ile uyusmuyor.'
  end if
  if (abs(min_j_mesh-min_j_raw) > 5.0e-14_dp) then
    error stop 'Q9 InternalMesh minJ ham assembly ile uyusmuyor.'
  end if

  ! Q9 facade Q4 mesh kabul etmemeli; topology hatasi assembly baslamadan donmeli.
  q4_X(1,:) = [0.0_dp,0.0_dp]
  q4_X(2,:) = [1.0_dp,0.0_dp]
  q4_X(3,:) = [1.0_dp,1.0_dp]
  q4_X(4,:) = [0.0_dp,1.0_dp]
  q4_conn(1,:) = [1,2,3,4]
  call initialize_q4_internal_mesh(q4_mesh,q4_X,q4_conn,status)
  if (status /= DES_STATUS_OK) error stop 'Q4 kontrol InternalMesh initialize basarisiz.'

  call assemble_q9_internal_mesh_herrmann( &
      q4_mesh,u,p,2.5_dp,0.02_dp,residual_mesh,tangent_mesh,status,min_j_mesh)
  if (status /= DES_ERROR_INVALID_CONNECTIVITY) then
    error stop 'Q9 InternalMesh Herrmann facade Q4 topolojisini reddetmedi.'
  end if
  if (maxval(abs(residual_mesh)) > 0.0_dp .or. maxval(abs(tangent_mesh)) > 0.0_dp) then
    error stop 'Q9 facade topology hatasinda outputlari temiz birakmadi.'
  end if

  write(*,'(A,I0)') 'Q9 InternalMesh node count = ',mesh%node_count()
  write(*,'(A,I0)') 'Q9 InternalMesh element count = ',mesh%element_count()
  write(*,'(A)') 'Q9 InternalMesh topology + Herrmann facade testi BASARILI.'
end program test_q9_internal_mesh
