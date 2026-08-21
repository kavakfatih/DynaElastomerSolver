module des_2d_mesh_database
  use, intrinsic :: ieee_arithmetic, only : ieee_is_finite
  use des_kinds, only : dp, i64
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONNECTIVITY, &
      DES_ERROR_INVALID_PARAMETERS
  use des_2d_analysis_contract, only : des_2d_analysis_mode_is_valid, &
      des_2d_topology_node_count, des_2d_formulation_contract_is_valid, &
      DES_TOPOLOGY_UNKNOWN, DES_FORMULATION_UNKNOWN, &
      DES_PRESSURE_SPACE_NONE, DES_2D_ANALYSIS_UNKNOWN
  implicit none
  private

  public :: mesh_node_2d_t
  public :: mesh_element_2d_t
  public :: mesh_database_2d_t
  public :: validate_2d_mesh_database
  public :: mesh_2d_has_node_id

  type :: mesh_node_2d_t
    ! Kullanıcı/mesher kimliği ile dizi satırını birbirine bağlamıyoruz.
    ! Böylece dış mesh ID'leri ve büyük model kimlikleri i64 olarak korunur.
    integer(i64) :: id = 0_i64
    real(dp) :: x = 0.0_dp
    real(dp) :: y = 0.0_dp
  end type mesh_node_2d_t

  type :: mesh_element_2d_t
    integer(i64) :: id = 0_i64
    integer :: topology = DES_TOPOLOGY_UNKNOWN
    integer :: analysis_mode = DES_2D_ANALYSIS_UNKNOWN
    integer :: formulation = DES_FORMULATION_UNKNOWN
    integer :: pressure_space = DES_PRESSURE_SPACE_NONE
    integer(i64) :: material_id = 0_i64
    integer(i64), allocatable :: connectivity(:)
  end type mesh_element_2d_t

  type :: mesh_database_2d_t
    ! C1 aşamasında tek bir mesh database aynı model içinde farklı element
    ! bloklarını taşıyabilir. Solver-specific Q4/Q8/Q9 dizileri burada yoktur.
    type(mesh_node_2d_t), allocatable :: nodes(:)
    type(mesh_element_2d_t), allocatable :: elements(:)
  contains
    procedure :: node_count_i64 => mesh_2d_node_count_i64
    procedure :: element_count_i64 => mesh_2d_element_count_i64
  end type mesh_database_2d_t

contains

  subroutine validate_2d_mesh_database(mesh, status)
    type(mesh_database_2d_t), intent(in) :: mesh
    integer, intent(out) :: status
    integer :: i, j, expected_nodes

    status = DES_STATUS_OK

    if (.not. allocated(mesh%nodes) .or. .not. allocated(mesh%elements)) then
      status = DES_ERROR_INVALID_CONNECTIVITY
      return
    end if

    if (size(mesh%nodes) < 1 .or. size(mesh%elements) < 1) then
      status = DES_ERROR_INVALID_CONNECTIVITY
      return
    end if

    do i = 1, size(mesh%nodes)
      if (mesh%nodes(i)%id <= 0_i64) then
        status = DES_ERROR_INVALID_CONNECTIVITY
        return
      end if
      if (.not. ieee_is_finite(mesh%nodes(i)%x) .or. &
          .not. ieee_is_finite(mesh%nodes(i)%y)) then
        status = DES_ERROR_INVALID_CONNECTIVITY
        return
      end if

      do j = i + 1, size(mesh%nodes)
        if (mesh%nodes(i)%id == mesh%nodes(j)%id) then
          status = DES_ERROR_INVALID_CONNECTIVITY
          return
        end if
      end do
    end do

    do i = 1, size(mesh%elements)
      if (mesh%elements(i)%id <= 0_i64 .or. mesh%elements(i)%material_id <= 0_i64) then
        status = DES_ERROR_INVALID_PARAMETERS
        return
      end if

      do j = i + 1, size(mesh%elements)
        if (mesh%elements(i)%id == mesh%elements(j)%id) then
          status = DES_ERROR_INVALID_CONNECTIVITY
          return
        end if
      end do

      if (.not. des_2d_analysis_mode_is_valid(mesh%elements(i)%analysis_mode)) then
        status = DES_ERROR_INVALID_PARAMETERS
        return
      end if

      if (.not. des_2d_formulation_contract_is_valid( &
          mesh%elements(i)%analysis_mode, mesh%elements(i)%formulation, &
          mesh%elements(i)%pressure_space)) then
        status = DES_ERROR_INVALID_PARAMETERS
        return
      end if

      expected_nodes = des_2d_topology_node_count(mesh%elements(i)%topology)
      if (expected_nodes <= 0 .or. .not. allocated(mesh%elements(i)%connectivity)) then
        status = DES_ERROR_INVALID_CONNECTIVITY
        return
      end if
      if (size(mesh%elements(i)%connectivity) /= expected_nodes) then
        status = DES_ERROR_INVALID_CONNECTIVITY
        return
      end if

      call validate_element_connectivity(mesh, mesh%elements(i), status)
      if (status /= DES_STATUS_OK) return
    end do
  end subroutine validate_2d_mesh_database

  subroutine validate_element_connectivity(mesh, element, status)
    type(mesh_database_2d_t), intent(in) :: mesh
    type(mesh_element_2d_t), intent(in) :: element
    integer, intent(out) :: status
    integer :: a, b

    status = DES_STATUS_OK

    do a = 1, size(element%connectivity)
      if (element%connectivity(a) <= 0_i64 .or. &
          .not. mesh_2d_has_node_id(mesh, element%connectivity(a))) then
        status = DES_ERROR_INVALID_CONNECTIVITY
        return
      end if

      do b = a + 1, size(element%connectivity)
        if (element%connectivity(a) == element%connectivity(b)) then
          status = DES_ERROR_INVALID_CONNECTIVITY
          return
        end if
      end do
    end do
  end subroutine validate_element_connectivity

  pure logical function mesh_2d_has_node_id(mesh, node_id) result(found)
    type(mesh_database_2d_t), intent(in) :: mesh
    integer(i64), intent(in) :: node_id
    integer :: i

    found = .false.
    if (.not. allocated(mesh%nodes)) return

    do i = 1, size(mesh%nodes)
      if (mesh%nodes(i)%id == node_id) then
        found = .true.
        return
      end if
    end do
  end function mesh_2d_has_node_id

  pure integer(i64) function mesh_2d_node_count_i64(this) result(node_count)
    class(mesh_database_2d_t), intent(in) :: this

    if (allocated(this%nodes)) then
      node_count = size(this%nodes, kind=i64)
    else
      node_count = 0_i64
    end if
  end function mesh_2d_node_count_i64

  pure integer(i64) function mesh_2d_element_count_i64(this) result(element_count)
    class(mesh_database_2d_t), intent(in) :: this

    if (allocated(this%elements)) then
      element_count = size(this%elements, kind=i64)
    else
      element_count = 0_i64
    end if
  end function mesh_2d_element_count_i64

end module des_2d_mesh_database
