module des_q4_plane_strain_mesh_neo_hookean
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONNECTIVITY
  use des_material_types, only : neo_hookean_parameters_t
  use des_internal_mesh, only : internal_mesh_t, validate_internal_mesh
  use des_integration_point_results, only : integration_point_result_t, integration_point_results_t, &
                                            initialize_q4_integration_results
  use des_q4_plane_strain_neo_hookean, only : evaluate_q4_plane_strain_element
  implicit none
  private
  public :: assemble_q4_plane_strain_mesh

  interface assemble_q4_plane_strain_mesh
    module procedure assemble_q4_plane_strain_arrays
    module procedure assemble_q4_plane_strain_internal_mesh
  end interface assemble_q4_plane_strain_mesh

contains

  subroutine assemble_q4_plane_strain_internal_mesh( &
      mesh, u, parameters, residual, tangent, status, min_j, integration_results)
    type(internal_mesh_t), intent(in) :: mesh
    real(dp), intent(in) :: u(:,:)
    type(neo_hookean_parameters_t), intent(in) :: parameters
    real(dp), intent(out) :: residual(:), tangent(:,:)
    integer, intent(out) :: status
    real(dp), intent(out) :: min_j
    type(integration_point_results_t), intent(out), optional :: integration_results

    call validate_internal_mesh(mesh, status)
    if (status /= DES_STATUS_OK) then
      residual = 0.0_dp
      tangent = 0.0_dp
      min_j = huge(1.0_dp)
      if (present(integration_results)) call initialize_q4_integration_results(integration_results, 0)
      return
    end if

    if (present(integration_results)) then
      call assemble_q4_plane_strain_arrays( &
        mesh%coordinates, mesh%q4_connectivity, u, parameters, residual, tangent, status, min_j, integration_results)
    else
      call assemble_q4_plane_strain_arrays( &
        mesh%coordinates, mesh%q4_connectivity, u, parameters, residual, tangent, status, min_j)
    end if
  end subroutine assemble_q4_plane_strain_internal_mesh

  subroutine assemble_q4_plane_strain_arrays( &
      X, connectivity, u, parameters, residual, tangent, status, min_j, integration_results)
    real(dp), intent(in) :: X(:,:), u(:,:)
    integer, intent(in) :: connectivity(:,:)
    type(neo_hookean_parameters_t), intent(in) :: parameters
    real(dp), intent(out) :: residual(:), tangent(:,:)
    integer, intent(out) :: status
    real(dp), intent(out) :: min_j
    type(integration_point_results_t), intent(out), optional :: integration_results

    real(dp) :: Xe(4,2), ue(4,2), re(8), Ke(8,8), element_min_j
    type(integration_point_result_t) :: element_results(4)
    integer :: element_status, e, g, a, b, i, k, row, col, grow, gcol, node_a, node_b
    integer :: nnode, nelem, ndof, result_index

    nnode = size(X,1)
    nelem = size(connectivity,1)
    ndof = 2*nnode

    residual = 0.0_dp
    tangent = 0.0_dp
    status = DES_STATUS_OK
    min_j = huge(1.0_dp)
    if (present(integration_results)) call initialize_q4_integration_results(integration_results, nelem)

    if (size(X,2) /= 2 .or. size(u,1) /= nnode .or. size(u,2) /= 2) then
      status = DES_ERROR_INVALID_CONNECTIVITY
      return
    end if
    if (size(connectivity,2) /= 4 .or. size(residual) /= ndof) then
      status = DES_ERROR_INVALID_CONNECTIVITY
      return
    end if
    if (size(tangent,1) /= ndof .or. size(tangent,2) /= ndof) then
      status = DES_ERROR_INVALID_CONNECTIVITY
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

      if (present(integration_results)) then
        call evaluate_q4_plane_strain_element( &
          Xe, ue, parameters, re, Ke, element_status, element_min_j, element_results)

        do g = 1,4
          result_index = 4*(e-1) + g
          element_results(g)%element_id = e
          integration_results%points(result_index) = element_results(g)
        end do
      else
        call evaluate_q4_plane_strain_element(Xe, ue, parameters, re, Ke, element_status, element_min_j)
      end if

      ! Başarısız material-point durumunda da teşhis için görülen en küçük J korunur.
      min_j = min(min_j, element_min_j)
      if (element_status /= DES_STATUS_OK) then
        status = element_status
        return
      end if

      do a = 1,4
        node_a = connectivity(e,a)
        do i = 1,2
          row = 2*(a-1)+i
          grow = 2*(node_a-1)+i
          residual(grow) = residual(grow) + re(row)

          do b = 1,4
            node_b = connectivity(e,b)
            do k = 1,2
              col = 2*(b-1)+k
              gcol = 2*(node_b-1)+k
              tangent(grow,gcol) = tangent(grow,gcol) + Ke(row,col)
            end do
          end do
        end do
      end do
    end do
  end subroutine assemble_q4_plane_strain_arrays

end module des_q4_plane_strain_mesh_neo_hookean
