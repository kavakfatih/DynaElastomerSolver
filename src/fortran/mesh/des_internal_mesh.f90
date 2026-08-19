module des_internal_mesh
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONNECTIVITY
  implicit none
  private

  public :: internal_mesh_t
  public :: initialize_q4_internal_mesh, initialize_q9_internal_mesh
  public :: validate_internal_mesh

  type :: internal_mesh_t
    ! Kanonik mesh siniri harici mesher tiplerini bilimsel cekirdekten ayirir.
    ! V0.3 Herrmann hattinda Q4 regression topolojisi korunurken Q9 production
    ! adayini da ayni InternalMesh sozlesmesinden tasiyabilmek icin iki topoloji
    ! bilincli olarak ayri alanlarda tutulur. Bir mesh nesnesi ayni anda yalniz
    ! bir aktif element topolojisi tasir.
    real(dp), allocatable :: coordinates(:,:)
    integer, allocatable :: q4_connectivity(:,:)
    integer, allocatable :: q9_connectivity(:,:)
  contains
    procedure :: node_count => internal_mesh_node_count
    procedure :: element_count => internal_mesh_element_count
    procedure :: element_node_count => internal_mesh_element_node_count
    procedure :: is_q4 => internal_mesh_is_q4
    procedure :: is_q9 => internal_mesh_is_q9
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

    if (status /= DES_STATUS_OK) call clear_internal_mesh(mesh)
  end subroutine initialize_q4_internal_mesh

  subroutine initialize_q9_internal_mesh(mesh, coordinates, connectivity, status)
    type(internal_mesh_t), intent(out) :: mesh
    real(dp), intent(in) :: coordinates(:,:)
    integer, intent(in) :: connectivity(:,:)
    integer, intent(out) :: status

    mesh%coordinates = coordinates
    mesh%q9_connectivity = connectivity
    call validate_internal_mesh(mesh, status)

    if (status /= DES_STATUS_OK) call clear_internal_mesh(mesh)
  end subroutine initialize_q9_internal_mesh

  subroutine validate_internal_mesh(mesh, status)
    type(internal_mesh_t), intent(in) :: mesh
    integer, intent(out) :: status
    logical :: has_q4, has_q9

    status = DES_STATUS_OK

    if (.not. allocated(mesh%coordinates)) then
      status = DES_ERROR_INVALID_CONNECTIVITY
      return
    end if
    if (size(mesh%coordinates,2) /= 2) then
      status = DES_ERROR_INVALID_CONNECTIVITY
      return
    end if

    has_q4 = allocated(mesh%q4_connectivity)
    has_q9 = allocated(mesh%q9_connectivity)

    ! Tek bir InternalMesh nesnesinde karisik topolojiye bu asamada izin verilmez.
    ! Mixed-topology ihtiyaci gelirse element-block yapisi ayri ADR ile eklenir.
    if (has_q4 .eqv. has_q9) then
      status = DES_ERROR_INVALID_CONNECTIVITY
      return
    end if

    if (has_q4) then
      call validate_connectivity_block( &
          mesh%coordinates,mesh%q4_connectivity,4,status)
      return
    end if

    call validate_connectivity_block( &
        mesh%coordinates,mesh%q9_connectivity,9,status)
  end subroutine validate_internal_mesh

  subroutine validate_connectivity_block(coordinates,connectivity,expected_nodes,status)
    real(dp), intent(in) :: coordinates(:,:)
    integer, intent(in) :: connectivity(:,:)
    integer, intent(in) :: expected_nodes
    integer, intent(out) :: status
    integer :: e,a,b,node_id,nnode

    status = DES_STATUS_OK
    nnode = size(coordinates,1)

    if (nnode < expected_nodes .or. size(connectivity,1) < 1 .or. &
        size(connectivity,2) /= expected_nodes) then
      status = DES_ERROR_INVALID_CONNECTIVITY
      return
    end if

    do e = 1,size(connectivity,1)
      do a = 1,expected_nodes
        node_id = connectivity(e,a)
        if (node_id < 1 .or. node_id > nnode) then
          status = DES_ERROR_INVALID_CONNECTIVITY
          return
        end if

        do b = a+1,expected_nodes
          if (node_id == connectivity(e,b)) then
            status = DES_ERROR_INVALID_CONNECTIVITY
            return
          end if
        end do
      end do
    end do
  end subroutine validate_connectivity_block

  subroutine clear_internal_mesh(mesh)
    type(internal_mesh_t), intent(inout) :: mesh

    if (allocated(mesh%coordinates)) deallocate(mesh%coordinates)
    if (allocated(mesh%q4_connectivity)) deallocate(mesh%q4_connectivity)
    if (allocated(mesh%q9_connectivity)) deallocate(mesh%q9_connectivity)
  end subroutine clear_internal_mesh

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
    elseif (allocated(this%q9_connectivity)) then
      n = size(this%q9_connectivity,1)
    else
      n = 0
    end if
  end function internal_mesh_element_count

  integer function internal_mesh_element_node_count(this) result(n)
    class(internal_mesh_t), intent(in) :: this
    if (allocated(this%q4_connectivity)) then
      n = 4
    elseif (allocated(this%q9_connectivity)) then
      n = 9
    else
      n = 0
    end if
  end function internal_mesh_element_node_count

  logical function internal_mesh_is_q4(this) result(is_q4)
    class(internal_mesh_t), intent(in) :: this
    is_q4 = allocated(this%q4_connectivity) .and. .not. allocated(this%q9_connectivity)
  end function internal_mesh_is_q4

  logical function internal_mesh_is_q9(this) result(is_q9)
    class(internal_mesh_t), intent(in) :: this
    is_q9 = allocated(this%q9_connectivity) .and. .not. allocated(this%q4_connectivity)
  end function internal_mesh_is_q9

end module des_internal_mesh
