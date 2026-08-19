program test_q9_herrmann_sparse_assembly
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_csr_matrix, only : csr_matrix_t, csr_to_dense
  use des_q9_plane_strain_herrmann_neo_hookean, only : Q9_HERRMANN_QUADRATURE_3X3
  use des_q9_plane_strain_herrmann_mesh, only : &
      assemble_q9_plane_strain_herrmann_mesh_with_quadrature
  use des_q9_plane_strain_herrmann_sparse_mesh, only : &
      initialize_q9_plane_strain_herrmann_csr_pattern, &
      assemble_q9_plane_strain_herrmann_mesh_csr_with_quadrature
  implicit none

  integer, parameter :: nnode = 15, nelem = 2
  integer, parameter :: ntotal = 2*nnode+3*nelem

  call run_parity_case(0.02_dp,.false.)
  call run_parity_case(0.0_dp,.true.)

  write(*,'(A)') 'Q9/P1 Herrmann dense-vs-CSR assembly parity testi BASARILI.'

contains

  subroutine run_parity_case(compliance,distorted)
    real(dp), intent(in) :: compliance
    logical, intent(in) :: distorted

    real(dp), parameter :: mu = 2.5_dp
    real(dp) :: X(nnode,2), u(nnode,2), p(nelem,3)
    integer :: conn(nelem,9)
    real(dp) :: dense_residual(ntotal), sparse_residual(ntotal)
    real(dp) :: dense_tangent(ntotal,ntotal), sparse_as_dense(ntotal,ntotal)
    real(dp) :: dense_min_j, sparse_min_j, x0, y0
    real(dp) :: residual_error, tangent_error, tangent_scale
    type(csr_matrix_t) :: sparse_tangent
    integer :: status, convert_status, node

    call build_two_element_q9_mesh(X,conn)

    if (distorted) then
      do node = 1,nnode
        x0 = X(node,1)
        y0 = X(node,2)
        X(node,1) = x0+0.08_dp*y0+0.06_dp*x0*y0
        X(node,2) = y0+0.04_dp*x0+0.025_dp*x0*x0
      end do
    end if

    do node = 1,nnode
      u(node,1) = 0.04_dp*X(node,1)+0.03_dp*X(node,2) &
          +0.012_dp*X(node,1)*X(node,2)+0.008_dp*X(node,1)*X(node,1)
      u(node,2) = -0.015_dp*X(node,1)+0.035_dp*X(node,2) &
          -0.009_dp*X(node,1)*X(node,2)+0.006_dp*X(node,2)*X(node,2)
    end do
    p(1,:) = [0.16_dp,0.030_dp,-0.020_dp]
    p(2,:) = [0.12_dp,-0.025_dp,0.018_dp]

    call assemble_q9_plane_strain_herrmann_mesh_with_quadrature( &
        X,conn,u,p,mu,compliance,Q9_HERRMANN_QUADRATURE_3X3, &
        dense_residual,dense_tangent,status,dense_min_j)
    if (status /= DES_STATUS_OK) then
      error stop 'Q9/P1 dense reference assembly basarisiz.'
    end if

    call initialize_q9_plane_strain_herrmann_csr_pattern( &
        nnode,conn,sparse_tangent,status)
    if (status /= DES_STATUS_OK) then
      error stop 'Q9/P1 CSR structural graph kurulamadı.'
    end if
    if (sparse_tangent%nnz() >= ntotal*ntotal) then
      error stop 'Q9/P1 CSR graph dense matris kadar nonzero ayirdi.'
    end if

    call assemble_q9_plane_strain_herrmann_mesh_csr_with_quadrature( &
        X,conn,u,p,mu,compliance,Q9_HERRMANN_QUADRATURE_3X3, &
        sparse_residual,sparse_tangent,status,sparse_min_j)
    if (status /= DES_STATUS_OK) then
      error stop 'Q9/P1 CSR assembly basarisiz.'
    end if

    call csr_to_dense(sparse_tangent,sparse_as_dense,convert_status)
    if (convert_status /= DES_STATUS_OK) then
      error stop 'Q9/P1 CSR tangent test icin dense forma donusturulemedi.'
    end if

    residual_error = maxval(abs(sparse_residual-dense_residual))
    tangent_scale = max(1.0_dp,maxval(abs(dense_tangent)))
    tangent_error = maxval(abs(sparse_as_dense-dense_tangent))/tangent_scale

    if (residual_error > 5.0e-14_dp) then
      error stop 'Q9/P1 CSR residual dense assembly ile uyusmuyor.'
    end if
    if (tangent_error > 5.0e-14_dp) then
      error stop 'Q9/P1 CSR tangent dense assembly ile uyusmuyor.'
    end if
    if (abs(sparse_min_j-dense_min_j) > 5.0e-14_dp) then
      error stop 'Q9/P1 CSR min(J) dense assembly ile uyusmuyor.'
    end if
    if (dense_min_j <= 0.80_dp) then
      error stop 'Q9/P1 CSR parity test geometry/deformation gecersiz.'
    end if

    if (compliance == 0.0_dp) then
      ! Fully-incompressible Herrmann limitinde Kpp blogu fiziksel olarak sifirdir.
      ! Sparse graph structural entry'leri koruyabilir; numerical degerler dense
      ! referansla birebir ayni sifir saddle-point blogunu tasimalidir.
      if (maxval(abs(sparse_as_dense(2*nnode+1:ntotal,2*nnode+1:ntotal))) &
          > 5.0e-14_dp) then
        error stop 'Fully-incompressible CSR Kpp blogu sifir degil.'
      end if
    end if

    write(*,'(A,L1,A,ES12.4,A,I0)') &
        'CSR parity distorted=',distorted,' tangent error=',tangent_error, &
        ' nnz=',sparse_tangent%nnz()
  end subroutine run_parity_case

  subroutine build_two_element_q9_mesh(coords,connectivity)
    real(dp), intent(out) :: coords(nnode,2)
    integer, intent(out) :: connectivity(nelem,9)
    integer :: ix,iy,id

    id = 0
    do iy = 0,2
      do ix = 0,4
        id = id+1
        coords(id,:) = [0.5_dp*real(ix,dp),0.5_dp*real(iy,dp)]
      end do
    end do

    connectivity(1,:) = [1,3,13,11,2,8,12,6,7]
    connectivity(2,:) = [3,5,15,13,4,10,14,8,9]
  end subroutine build_two_element_q9_mesh

end program test_q9_herrmann_sparse_assembly
