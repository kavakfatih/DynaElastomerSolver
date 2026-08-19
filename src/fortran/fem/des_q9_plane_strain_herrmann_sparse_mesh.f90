module des_q9_plane_strain_herrmann_sparse_mesh
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONNECTIVITY, &
                         DES_ERROR_INVALID_CONSTRAINT
  use des_csr_matrix, only : csr_matrix_t, initialize_csr_from_element_dof_maps, &
                             csr_add_local_matrix
  use des_mixed_dof_layout, only : mixed_global_equation_counts, &
                                   build_discontinuous_pressure_element_dof_map
  use des_q9_plane_strain_herrmann_neo_hookean, only : &
      Q9_HERRMANN_P_DOF, Q9_HERRMANN_TOTAL_DOF, &
      Q9_HERRMANN_QUADRATURE_3X3, &
      evaluate_q9_plane_strain_herrmann_element_with_quadrature
  implicit none
  private

  public :: initialize_q9_plane_strain_herrmann_csr_pattern
  public :: assemble_q9_plane_strain_herrmann_mesh_csr
  public :: assemble_q9_plane_strain_herrmann_mesh_csr_with_quadrature

contains

  subroutine initialize_q9_plane_strain_herrmann_csr_pattern( &
      nnode, connectivity, tangent, status)
    ! Q9/P1 mixed global tangent icin topology-only CSR graph kurar.
    !
    ! Pressure unknown'lari element-internal ve discontinuous oldugu icin global
    ! equation sirasi dense assembly ile birebir aynidir:
    ! [u1x,u1y,...,unx,uny,p_e1_1,p_e1_2,p_e1_3,...]
    !
    ! Graph Newton iterasyonlari boyunca degismez; production solver bu rutini
    ! bir kere cagirip yalniz CSR values dizisini yeniden assemble edebilir.
    integer, intent(in) :: nnode
    integer, intent(in) :: connectivity(:,:)
    type(csr_matrix_t), intent(out) :: tangent
    integer, intent(out) :: status

    integer, allocatable :: element_dof_maps(:,:)
    integer :: nelem, ndisp, npres, ntotal
    integer :: count_status, map_status, e

    status = DES_STATUS_OK
    nelem = size(connectivity,1)

    if (nnode < 9 .or. nelem < 1 .or. size(connectivity,2) /= 9) then
      status = DES_ERROR_INVALID_CONNECTIVITY
      return
    end if
    if (any(connectivity < 1) .or. any(connectivity > nnode)) then
      status = DES_ERROR_INVALID_CONNECTIVITY
      return
    end if

    call mixed_global_equation_counts( &
        nnode,nelem,2,Q9_HERRMANN_P_DOF,ndisp,npres,ntotal,count_status)
    if (count_status /= DES_STATUS_OK .or. ntotal /= ndisp+npres) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    allocate(element_dof_maps(nelem,Q9_HERRMANN_TOTAL_DOF))
    do e = 1,nelem
      call build_discontinuous_pressure_element_dof_map( &
          connectivity(e,:),e,nnode,2,Q9_HERRMANN_P_DOF, &
          element_dof_maps(e,:),map_status)
      if (map_status /= DES_STATUS_OK) then
        status = map_status
        return
      end if
    end do

    call initialize_csr_from_element_dof_maps( &
        tangent,ntotal,ntotal,element_dof_maps,status)
  end subroutine initialize_q9_plane_strain_herrmann_csr_pattern

  subroutine assemble_q9_plane_strain_herrmann_mesh_csr( &
      X, connectivity, u, pressure_coefficients, shear_modulus, pressure_compliance, &
      residual, tangent, status, min_j)
    real(dp), intent(in) :: X(:,:), u(:,:), pressure_coefficients(:,:)
    integer, intent(in) :: connectivity(:,:)
    real(dp), intent(in) :: shear_modulus, pressure_compliance
    real(dp), intent(out) :: residual(:)
    type(csr_matrix_t), intent(inout) :: tangent
    integer, intent(out) :: status
    real(dp), intent(out) :: min_j

    call assemble_q9_plane_strain_herrmann_mesh_csr_with_quadrature( &
        X,connectivity,u,pressure_coefficients,shear_modulus,pressure_compliance, &
        Q9_HERRMANN_QUADRATURE_3X3,residual,tangent,status,min_j)
  end subroutine assemble_q9_plane_strain_herrmann_mesh_csr

  subroutine assemble_q9_plane_strain_herrmann_mesh_csr_with_quadrature( &
      X, connectivity, u, pressure_coefficients, shear_modulus, pressure_compliance, &
      quadrature_order, residual, tangent, status, min_j)
    ! Dense global tangent olusturmadan Q9/P1 element bloklarini dogrudan CSR
    ! values dizisine scatter eder. Element residual/tangent matematigi dense
    ! yolla ayni rutinden gelir; bu katman yalniz global storage/assembly'i ayirir.
    real(dp), intent(in) :: X(:,:), u(:,:), pressure_coefficients(:,:)
    integer, intent(in) :: connectivity(:,:)
    real(dp), intent(in) :: shear_modulus, pressure_compliance
    integer, intent(in) :: quadrature_order
    real(dp), intent(out) :: residual(:)
    type(csr_matrix_t), intent(inout) :: tangent
    integer, intent(out) :: status
    real(dp), intent(out) :: min_j

    real(dp) :: Xe(9,2), ue(9,2), pe(Q9_HERRMANN_P_DOF)
    real(dp) :: re(Q9_HERRMANN_TOTAL_DOF)
    real(dp) :: Ke(Q9_HERRMANN_TOTAL_DOF,Q9_HERRMANN_TOTAL_DOF)
    real(dp) :: element_min_j
    integer :: dof_map(Q9_HERRMANN_TOTAL_DOF)
    integer :: nnode, nelem, ndisp, npres, ntotal
    integer :: count_status, map_status, element_status, scatter_status
    integer :: e, a, lr, gr, node

    residual = 0.0_dp
    tangent%values = 0.0_dp
    status = DES_STATUS_OK
    min_j = huge(1.0_dp)

    nnode = size(X,1)
    nelem = size(connectivity,1)

    if (size(X,2) /= 2 .or. size(u,1) /= nnode .or. size(u,2) /= 2) then
      status = DES_ERROR_INVALID_CONNECTIVITY
      return
    end if
    if (size(connectivity,2) /= 9 .or. nelem < 1) then
      status = DES_ERROR_INVALID_CONNECTIVITY
      return
    end if
    if (any(connectivity < 1) .or. any(connectivity > nnode)) then
      status = DES_ERROR_INVALID_CONNECTIVITY
      return
    end if
    if (size(pressure_coefficients,1) /= nelem .or. &
        size(pressure_coefficients,2) /= Q9_HERRMANN_P_DOF) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    call mixed_global_equation_counts( &
        nnode,nelem,2,Q9_HERRMANN_P_DOF,ndisp,npres,ntotal,count_status)
    if (count_status /= DES_STATUS_OK .or. ntotal /= ndisp+npres) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    if (size(residual) /= ntotal) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if
    if (tangent%nrows /= ntotal .or. tangent%ncols /= ntotal .or. &
        .not. allocated(tangent%row_ptr) .or. .not. allocated(tangent%col_ind) .or. &
        .not. allocated(tangent%values)) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    tangent%values = 0.0_dp

    do e = 1,nelem
      do a = 1,9
        node = connectivity(e,a)
        Xe(a,:) = X(node,:)
        ue(a,:) = u(node,:)
      end do
      pe = pressure_coefficients(e,:)

      call build_discontinuous_pressure_element_dof_map( &
          connectivity(e,:),e,nnode,2,Q9_HERRMANN_P_DOF,dof_map,map_status)
      if (map_status /= DES_STATUS_OK) then
        status = map_status
        return
      end if

      call evaluate_q9_plane_strain_herrmann_element_with_quadrature( &
          Xe,ue,pe,shear_modulus,pressure_compliance,quadrature_order, &
          re,Ke,element_status,element_min_j)
      if (element_status /= DES_STATUS_OK) then
        status = element_status
        return
      end if
      min_j = min(min_j,element_min_j)

      do lr = 1,Q9_HERRMANN_TOTAL_DOF
        gr = dof_map(lr)
        residual(gr) = residual(gr)+re(lr)
      end do

      call csr_add_local_matrix(tangent,dof_map,Ke,scatter_status)
      if (scatter_status /= DES_STATUS_OK) then
        status = scatter_status
        return
      end if
    end do
  end subroutine assemble_q9_plane_strain_herrmann_mesh_csr_with_quadrature

end module des_q9_plane_strain_herrmann_sparse_mesh
