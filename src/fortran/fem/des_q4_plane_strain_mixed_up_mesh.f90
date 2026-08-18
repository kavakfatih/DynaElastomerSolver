module des_q4_plane_strain_mixed_up_mesh
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONNECTIVITY, &
                         DES_ERROR_INVALID_CONSTRAINT
  use des_material_types, only : neo_hookean_parameters_t
  use des_q4_plane_strain_mixed_up_neo_hookean, only : &
      evaluate_q4_plane_strain_mixed_up_element
  implicit none
  private

  public :: assemble_q4_plane_strain_mixed_up_mesh

contains

  subroutine assemble_q4_plane_strain_mixed_up_mesh( &
      X, connectivity, u, pressure, parameters, residual, tangent, status, min_j)
    ! Global DOF sırası:
    ! [u1x,u1y,...,unx,uny, p_element_1,...,p_element_ne]
    ! Her Q4 eleman bir sabit P0 pressure DOF taşır.
    real(dp), intent(in) :: X(:,:), u(:,:), pressure(:)
    integer, intent(in) :: connectivity(:,:)
    type(neo_hookean_parameters_t), intent(in) :: parameters
    real(dp), intent(out) :: residual(:), tangent(:,:)
    integer, intent(out) :: status
    real(dp), intent(out) :: min_j

    real(dp) :: Xe(4,2), ue(4,2), re(9), Ke(9,9), element_min_j
    integer :: element_status
    integer :: nnode, nelem, ndisp, ntotal
    integer :: e, a, b, i, k, lrow, lcol, grow, gcol
    integer :: node_a, node_b, pressure_dof

    nnode = size(X,1)
    nelem = size(connectivity,1)
    ndisp = 2*nnode
    ntotal = ndisp + nelem

    residual = 0.0_dp
    tangent = 0.0_dp
    status = DES_STATUS_OK
    min_j = huge(1.0_dp)

    if (size(X,2) /= 2 .or. size(u,1) /= nnode .or. size(u,2) /= 2) then
      status = DES_ERROR_INVALID_CONNECTIVITY
      return
    end if
    if (size(connectivity,2) /= 4 .or. nelem < 1) then
      status = DES_ERROR_INVALID_CONNECTIVITY
      return
    end if
    if (size(pressure) /= nelem .or. size(residual) /= ntotal) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if
    if (size(tangent,1) /= ntotal .or. size(tangent,2) /= ntotal) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    do e = 1,nelem
      do a = 1,4
        node_a = connectivity(e,a)
        if (node_a < 1 .or. node_a > nnode) then
          status = DES_ERROR_INVALID_CONNECTIVITY
          return
        end if
        Xe(a,:) = X(node_a,:)
        ue(a,:) = u(node_a,:)
      end do

      call evaluate_q4_plane_strain_mixed_up_element( &
          Xe, ue, pressure(e), parameters%mu, parameters%lambda, &
          re, Ke, element_status, element_min_j)

      min_j = min(min_j, element_min_j)
      if (element_status /= DES_STATUS_OK) then
        status = element_status
        return
      end if

      pressure_dof = ndisp + e

      do a = 1,4
        node_a = connectivity(e,a)
        do i = 1,2
          lrow = 2*(a-1) + i
          grow = 2*(node_a-1) + i
          residual(grow) = residual(grow) + re(lrow)

          do b = 1,4
            node_b = connectivity(e,b)
            do k = 1,2
              lcol = 2*(b-1) + k
              gcol = 2*(node_b-1) + k
              tangent(grow,gcol) = tangent(grow,gcol) + Ke(lrow,lcol)
            end do
          end do

          tangent(grow,pressure_dof) = &
            tangent(grow,pressure_dof) + Ke(lrow,9)
          tangent(pressure_dof,grow) = &
            tangent(pressure_dof,grow) + Ke(9,lrow)
        end do
      end do

      residual(pressure_dof) = residual(pressure_dof) + re(9)
      tangent(pressure_dof,pressure_dof) = &
        tangent(pressure_dof,pressure_dof) + Ke(9,9)
    end do
  end subroutine assemble_q4_plane_strain_mixed_up_mesh

end module des_q4_plane_strain_mixed_up_mesh
