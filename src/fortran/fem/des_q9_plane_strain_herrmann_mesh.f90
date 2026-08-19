module des_q9_plane_strain_herrmann_mesh
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONNECTIVITY, &
                         DES_ERROR_INVALID_CONSTRAINT
  use des_mixed_dof_layout, only : mixed_global_equation_counts, &
                                   build_discontinuous_pressure_element_dof_map
  use des_q9_plane_strain_herrmann_neo_hookean, only : &
      Q9_HERRMANN_P_DOF, Q9_HERRMANN_TOTAL_DOF, &
      Q9_HERRMANN_QUADRATURE_3X3, &
      evaluate_q9_plane_strain_herrmann_element_with_quadrature
  implicit none
  private

  public :: assemble_q9_plane_strain_herrmann_mesh
  public :: assemble_q9_plane_strain_herrmann_mesh_with_quadrature

contains

  subroutine assemble_q9_plane_strain_herrmann_mesh( &
      X, connectivity, u, pressure_coefficients, shear_modulus, pressure_compliance, &
      residual, tangent, status, min_j)
    ! Varsayilan global Q9/P1 Herrmann assembly yolu 3x3 Gauss baseline'ini korur.
    real(dp), intent(in) :: X(:,:), u(:,:), pressure_coefficients(:,:)
    integer, intent(in) :: connectivity(:,:)
    real(dp), intent(in) :: shear_modulus, pressure_compliance
    real(dp), intent(out) :: residual(:), tangent(:,:)
    integer, intent(out) :: status
    real(dp), intent(out) :: min_j

    call assemble_q9_plane_strain_herrmann_mesh_with_quadrature( &
        X,connectivity,u,pressure_coefficients,shear_modulus,pressure_compliance, &
        Q9_HERRMANN_QUADRATURE_3X3,residual,tangent,status,min_j)
  end subroutine assemble_q9_plane_strain_herrmann_mesh

  subroutine assemble_q9_plane_strain_herrmann_mesh_with_quadrature( &
      X, connectivity, u, pressure_coefficients, shear_modulus, pressure_compliance, &
      quadrature_order, residual, tangent, status, min_j)
    ! Global mixed unknown sirasi:
    ! [u1x,u1y,...,unx,uny,
    !  p_element_1_mode_1,p_element_1_mode_2,p_element_1_mode_3,...]
    !
    ! Pressure coefficients mesh dugumlerine yapistirilmaz. Her elementin 3 pressure
    ! unknown'u global saddle-point sisteminde bagimsiz denklem olarak tutulur.
    real(dp), intent(in) :: X(:,:), u(:,:), pressure_coefficients(:,:)
    integer, intent(in) :: connectivity(:,:)
    real(dp), intent(in) :: shear_modulus, pressure_compliance
    integer, intent(in) :: quadrature_order
    real(dp), intent(out) :: residual(:), tangent(:,:)
    integer, intent(out) :: status
    real(dp), intent(out) :: min_j

    real(dp) :: Xe(9,2), ue(9,2), pe(Q9_HERRMANN_P_DOF)
    real(dp) :: re(Q9_HERRMANN_TOTAL_DOF)
    real(dp) :: Ke(Q9_HERRMANN_TOTAL_DOF,Q9_HERRMANN_TOTAL_DOF)
    real(dp) :: element_min_j
    integer :: dof_map(Q9_HERRMANN_TOTAL_DOF)
    integer :: element_status, map_status, count_status
    integer :: nnode, nelem, ndisp, npres, ntotal
    integer :: e, a, lr, lc, gr, gc, node

    residual = 0.0_dp
    tangent = 0.0_dp
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
    if (size(pressure_coefficients,1) /= nelem .or. &
        size(pressure_coefficients,2) /= Q9_HERRMANN_P_DOF) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    call mixed_global_equation_counts( &
        nnode,nelem,2,Q9_HERRMANN_P_DOF,ndisp,npres,ntotal,count_status)
    if (count_status /= DES_STATUS_OK) then
      status = count_status
      return
    end if
    if (ntotal /= ndisp+npres) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    if (size(residual) /= ntotal) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if
    if (size(tangent,1) /= ntotal .or. size(tangent,2) /= ntotal) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    do e = 1,nelem
      do a = 1,9
        node = connectivity(e,a)
        if (node < 1 .or. node > nnode) then
          status = DES_ERROR_INVALID_CONNECTIVITY
          return
        end if
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
        do lc = 1,Q9_HERRMANN_TOTAL_DOF
          gc = dof_map(lc)
          tangent(gr,gc) = tangent(gr,gc)+Ke(lr,lc)
        end do
      end do
    end do
  end subroutine assemble_q9_plane_strain_herrmann_mesh_with_quadrature

end module des_q9_plane_strain_herrmann_mesh
