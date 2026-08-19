module des_q4_mesh_edge_traction
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONNECTIVITY, &
                         DES_ERROR_INVALID_CONSTRAINT
  use des_internal_mesh, only : internal_mesh_t, validate_internal_mesh
  use des_q4_edge_traction, only : q4_reference_edge_traction
  implicit none
  private

  public :: add_q4_reference_edge_traction
contains

  subroutine add_q4_reference_edge_traction( &
      mesh, element_id, edge_id, traction, global_force, status, reference_length)
    ! Tek bir Q4 eleman kenarındaki referans traction yükünü global kuvvet vektörüne ekler.
    ! global_force inout tutulur; böylece sınır boyunca birden fazla eleman kenarı ardışık
    ! çağrılarla aynı yük vektöründe biriktirilebilir.
    type(internal_mesh_t), intent(in) :: mesh
    integer, intent(in) :: element_id, edge_id
    real(dp), intent(in) :: traction(2)
    real(dp), intent(inout) :: global_force(:)
    integer, intent(out) :: status
    real(dp), intent(out), optional :: reference_length

    integer :: nodes(4)
    integer :: a, node_id, mesh_status
    real(dp) :: X(4,2), element_force(8), edge_length

    status = DES_STATUS_OK
    if (present(reference_length)) reference_length = 0.0_dp

    call validate_internal_mesh(mesh, mesh_status)
    if (mesh_status /= DES_STATUS_OK) then
      status = mesh_status
      return
    end if

    if (size(global_force) /= 2*mesh%node_count()) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    if (element_id < 1 .or. element_id > mesh%element_count()) then
      status = DES_ERROR_INVALID_CONNECTIVITY
      return
    end if

    nodes = mesh%q4_connectivity(element_id,:)
    do a = 1,4
      X(a,:) = mesh%coordinates(nodes(a),:)
    end do

    call q4_reference_edge_traction(X, edge_id, traction, element_force, status, edge_length)
    if (status /= DES_STATUS_OK) return

    do a = 1,4
      node_id = nodes(a)
      global_force(2*node_id-1) = global_force(2*node_id-1) + element_force(2*a-1)
      global_force(2*node_id)   = global_force(2*node_id)   + element_force(2*a)
    end do

    if (present(reference_length)) reference_length = edge_length
  end subroutine add_q4_reference_edge_traction

end module des_q4_mesh_edge_traction
