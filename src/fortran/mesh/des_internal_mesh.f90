module des_internal_mesh
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONNECTIVITY
  implicit none
  private

  public :: internal_mesh_t, initialize_q4_internal_mesh, validate_internal_mesh

  type :: internal_mesh_t
    ! V0.2 için kasıtlı olarak küçük tutulan kanonik mesh modeli.
    ! Harici mesher tipleri bilimsel çekirdeğe taşınmaz.
    real(dp), allocatable :: coordinates(:,:)
    integer, allocatable :: q4_connectivity(:,:)
  contains
    procedure :: node_count => internal_mesh_node_count
    procedure :: element_count => internal_mesh_element_count
  end type internal_mesh_t

contains

  subroutine initialize_q4_internal_mesh(mesh, coordinates, connectivity, status)
    type(internal_mesh_t), intent(out) :: mesh
    real(dp), intent(in) :: coordinates(:,:)
    integer, intent(in) :: connectivity(:,:)
    integer, intent(out) :: status

    mesh%coordinates = coordinates
    mesh%q4_connectivity = connectivity
    call validate_internal_mesh(mesh, status)

    if (status /= DES_STATUS_OK) then
      if (allocated(mesh%coordinates)) deallocate(mesh%coordinates)
      if (allocated(mesh%q4_connectivity)) deallocate(mesh%q4_connectivity)
    end if
  end subroutine initialize_q4_internal_mesh

  subroutine validate_internal_mesh(mesh, status)
    type(internal_mesh_t), intent(in) :: mesh
    integer, intent(out) :: status
    integer :: e, a, b, node_id, nnode

    status = DES_STATUS_OK

    if (.not. allocated(mesh%coordinates) .or. .not. allocated(mesh%q4_connectivity)) then
      status = DES_ERROR_INVALID_CONNECTIVITY
      return
    end if

    if (size(mesh%coordinates,2) /= 2 .or. size(mesh%coordinates,1) < 4) then
      status = DES_ERROR_INVALID_CONNECTIVITY
      return
    end if

    if (size(mesh%q4_connectivity,2) /= 4 .or. size(mesh%q4_connectivity,1) < 1) then
      status = DES_ERROR_INVALID_CONNECTIVITY
      return
    end if

    nnode = size(mesh%coordinates,1)
    do e = 1,size(mesh%q4_connectivity,1)
      do a = 1,4
        node_id = mesh%q4_connectivity(e,a)
        if (node_id < 1 .or. node_id > nnode) then
          status = DES_ERROR_INVALID_CONNECTIVITY
          return
        end if

        ! Aynı Q4 elemanda yinelenen düğüm topolojik olarak geçersizdir.
        do b = a+1,4
          if (node_id == mesh%q4_connectivity(e,b)) then
            status = DES_ERROR_INVALID_CONNECTIVITY
            return
          end if
        end do
      end do
    end do
  end subroutine validate_internal_mesh

  integer function internal_mesh_node_count(this) result(n)
    class(internal_mesh_t), intent(in) :: this
    if (allocated(this%coordinates)) then
      n = size(this%coordinates,1)
    else
      n = 0
    end if
  end function internal_mesh_node_count

  integer function internal_mesh_element_count(this) result(n)
    class(internal_mesh_t), intent(in) :: this
    if (allocated(this%q4_connectivity)) then
      n = size(this%q4_connectivity,1)
    else
      n = 0
    end if
  end function internal_mesh_element_count

end module des_internal_mesh
