module des_q4_plane_strain_fbar_mesh
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONNECTIVITY, &
                         DES_ERROR_INVALID_CONSTRAINT
  use des_material_types, only : neo_hookean_parameters_t
  use des_q4_plane_strain_fbar_neo_hookean, only : &
      evaluate_q4_plane_strain_fbar_element
  implicit none
  private

  public :: assemble_q4_plane_strain_fbar_mesh

contains

  subroutine assemble_q4_plane_strain_fbar_mesh( &
      X, connectivity, u, parameters, residual, tangent, status, &
      min_j, min_j_bar, max_j_bar)
    real(dp), intent(in) :: X(:,:), u(:,:)
    integer, intent(in) :: connectivity(:,:)
    type(neo_hookean_parameters_t), intent(in) :: parameters
    real(dp), intent(out) :: residual(:), tangent(:,:)
    integer, intent(out) :: status
    real(dp), intent(out) :: min_j
    real(dp), intent(out), optional :: min_j_bar, max_j_bar

    real(dp) :: Xe(4,2), ue(4,2), re(8), Ke(8,8)
    real(dp) :: element_min_j, element_j_bar
    integer :: element_status, nnode, nelem, ndof
    integer :: e, a, b, i, k, lrow, lcol, grow, gcol
    integer :: node_a, node_b

    nnode = size(X,1)
    nelem = size(connectivity,1)
    ndof = 2*nnode

    residual = 0.0_dp
    tangent = 0.0_dp
    status = DES_STATUS_OK
    min_j = huge(1.0_dp)
    if (present(min_j_bar)) min_j_bar = huge(1.0_dp)
    if (present(max_j_bar)) max_j_bar = -huge(1.0_dp)

    if (size(X,2) /= 2 .or. size(u,1) /= nnode .or. size(u,2) /= 2) then
      status = DES_ERROR_INVALID_CONNECTIVITY
      return
    end if
    if (size(connectivity,2) /= 4 .or. nelem < 1) then
      status = DES_ERROR_INVALID_CONNECTIVITY
      return
    end if
    if (size(residual) /= ndof .or. size(tangent,1) /= ndof .or. &
        size(tangent,2) /= ndof) then
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

      call evaluate_q4_plane_strain_fbar_element( &
          Xe, ue, parameters, re, Ke, element_status, &
          element_min_j, element_j_bar)

      min_j = min(min_j,element_min_j)
      if (present(min_j_bar)) min_j_bar = min(min_j_bar,element_j_bar)
      if (present(max_j_bar)) max_j_bar = max(max_j_bar,element_j_bar)
      if (element_status /= DES_STATUS_OK) then
        status = element_status
        return
      end if

      do a = 1,4
        node_a = connectivity(e,a)
        do i = 1,2
          lrow = 2*(a-1)+i
          grow = 2*(node_a-1)+i
          residual(grow) = residual(grow) + re(lrow)

          do b = 1,4
            node_b = connectivity(e,b)
            do k = 1,2
              lcol = 2*(b-1)+k
              gcol = 2*(node_b-1)+k
              tangent(grow,gcol) = tangent(grow,gcol) + Ke(lrow,lcol)
            end do
          end do
        end do
      end do
    end do
  end subroutine assemble_q4_plane_strain_fbar_mesh

end module des_q4_plane_strain_fbar_mesh
