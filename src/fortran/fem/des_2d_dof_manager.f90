module des_2d_dof_manager
  use des_kinds, only : i64
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONNECTIVITY, &
      DES_ERROR_INVALID_CONSTRAINT, DES_ERROR_INVALID_PARAMETERS
  use des_2d_analysis_contract, only : DES_2D_GENERALIZED_PLANE_STRAIN, &
      DES_PRESSURE_SPACE_NONE, des_2d_nodal_kinematic_dof_count, &
      des_2d_pressure_dof_count, des_2d_formulation_contract_is_valid
  use des_2d_mesh_database, only : mesh_database_2d_t, validate_2d_mesh_database
  implicit none
  private

  integer, parameter :: DES_MAX_2D_NODAL_DOF = 3
  integer, parameter :: DES_MAX_2D_PRESSURE_DOF = 3
  integer, parameter :: DES_GENERALIZED_PLANE_STRAIN_DOF = 3

  public :: dof_layout_2d_t
  public :: build_2d_dof_layout
  public :: build_2d_element_equation_map
  public :: node_equation_from_id

  type :: dof_layout_2d_t
    ! Nodal kinematic alan, element-internal generalized kinematic alan ve
    ! pressure alanı ayrı tutulur. Sıfır değer ilgili slotta DOF olmadığını belirtir.
    integer :: analysis_mode = 0
    integer :: nodal_dofs_per_node = 0
    integer(i64), allocatable :: node_ids(:)
    integer(i64), allocatable :: nodal_equations(:,:)
    integer(i64), allocatable :: generalized_equations(:,:)
    integer(i64), allocatable :: pressure_equations(:,:)
    integer(i64) :: nodal_equation_count = 0_i64
    integer(i64) :: generalized_equation_count = 0_i64
    integer(i64) :: pressure_equation_count = 0_i64
    integer(i64) :: total_equation_count = 0_i64
  end type dof_layout_2d_t

contains

  subroutine build_2d_dof_layout(mesh, layout, status)
    type(mesh_database_2d_t), intent(in) :: mesh
    type(dof_layout_2d_t), intent(out) :: layout
    integer, intent(out) :: status

    integer :: node_index, element_index, component, pressure_dof_count
    integer :: generalized_dof_count
    integer(i64) :: nnode, nelem, next_equation

    call validate_2d_mesh_database(mesh, status)
    if (status /= DES_STATUS_OK) return

    nnode = mesh%node_count_i64()
    nelem = mesh%element_count_i64()
    layout%analysis_mode = mesh%elements(1)%analysis_mode
    layout%nodal_dofs_per_node = des_2d_nodal_kinematic_dof_count(layout%analysis_mode)

    if (layout%nodal_dofs_per_node < 1 .or. &
        layout%nodal_dofs_per_node > DES_MAX_2D_NODAL_DOF) then
      status = DES_ERROR_INVALID_PARAMETERS
      return
    end if

    ! Tek bir nonlinear solution region içinde farklı 2D kinematik kipleri
    ! karıştırılmaz. Farklı region'lar ileride model/assembly katmanında ayrılır.
    do element_index = 1, size(mesh%elements)
      if (mesh%elements(element_index)%analysis_mode /= layout%analysis_mode) then
        status = DES_ERROR_INVALID_PARAMETERS
        return
      end if
      if (.not. des_2d_formulation_contract_is_valid( &
          mesh%elements(element_index)%analysis_mode, &
          mesh%elements(element_index)%formulation, &
          mesh%elements(element_index)%pressure_space)) then
        status = DES_ERROR_INVALID_PARAMETERS
        return
      end if
    end do

    if (nnode > huge(0_i64)/int(layout%nodal_dofs_per_node, i64)) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if
    layout%nodal_equation_count = nnode*int(layout%nodal_dofs_per_node, i64)

    layout%generalized_equation_count = 0_i64
    layout%pressure_equation_count = 0_i64
    do element_index = 1, size(mesh%elements)
      generalized_dof_count = generalized_dofs_for_analysis(mesh%elements(element_index)%analysis_mode)
      if (layout%generalized_equation_count > &
          huge(0_i64)-int(generalized_dof_count, i64)) then
        status = DES_ERROR_INVALID_CONSTRAINT
        return
      end if
      layout%generalized_equation_count = layout%generalized_equation_count + &
          int(generalized_dof_count, i64)

      pressure_dof_count = des_2d_pressure_dof_count(mesh%elements(element_index)%pressure_space)
      if (pressure_dof_count < 0 .or. pressure_dof_count > DES_MAX_2D_PRESSURE_DOF) then
        status = DES_ERROR_INVALID_PARAMETERS
        return
      end if
      if (layout%pressure_equation_count > huge(0_i64)-int(pressure_dof_count, i64)) then
        status = DES_ERROR_INVALID_CONSTRAINT
        return
      end if
      layout%pressure_equation_count = layout%pressure_equation_count + int(pressure_dof_count, i64)
    end do

    if (layout%nodal_equation_count > huge(0_i64)-layout%generalized_equation_count) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if
    layout%total_equation_count = layout%nodal_equation_count + layout%generalized_equation_count
    if (layout%total_equation_count > huge(0_i64)-layout%pressure_equation_count) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if
    layout%total_equation_count = layout%total_equation_count + layout%pressure_equation_count

    ! Bu allocation'lar mevcut makinede temsil edilen mesh cardinality'si kadar
    ! olacaktır; equation numaraları ve kimlikler i64 kalır.
    allocate(layout%node_ids(size(mesh%nodes)))
    allocate(layout%nodal_equations(DES_MAX_2D_NODAL_DOF, size(mesh%nodes)))
    allocate(layout%generalized_equations(DES_GENERALIZED_PLANE_STRAIN_DOF, size(mesh%elements)))
    allocate(layout%pressure_equations(DES_MAX_2D_PRESSURE_DOF, size(mesh%elements)))
    layout%nodal_equations = 0_i64
    layout%generalized_equations = 0_i64
    layout%pressure_equations = 0_i64

    next_equation = 0_i64
    do node_index = 1, size(mesh%nodes)
      layout%node_ids(node_index) = mesh%nodes(node_index)%id
      do component = 1, layout%nodal_dofs_per_node
        next_equation = next_equation + 1_i64
        layout%nodal_equations(component, node_index) = next_equation
      end do
    end do

    ! Kinematic block içinde generalized-plane-strain DOF'ları nodal U alanını
    ! izler. Böylece pressure block tüm kinematik bilinmeyenlerden sonra başlar.
    do element_index = 1, size(mesh%elements)
      generalized_dof_count = generalized_dofs_for_analysis(mesh%elements(element_index)%analysis_mode)
      do component = 1, generalized_dof_count
        next_equation = next_equation + 1_i64
        layout%generalized_equations(component, element_index) = next_equation
      end do
    end do

    do element_index = 1, size(mesh%elements)
      pressure_dof_count = des_2d_pressure_dof_count(mesh%elements(element_index)%pressure_space)
      do component = 1, pressure_dof_count
        next_equation = next_equation + 1_i64
        layout%pressure_equations(component, element_index) = next_equation
      end do
    end do

    if (next_equation /= layout%total_equation_count) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    status = DES_STATUS_OK
  end subroutine build_2d_dof_layout

  subroutine build_2d_element_equation_map(mesh, layout, element_index, equation_map, status)
    type(mesh_database_2d_t), intent(in) :: mesh
    type(dof_layout_2d_t), intent(in) :: layout
    integer(i64), intent(in) :: element_index
    integer(i64), intent(out) :: equation_map(:)
    integer, intent(out) :: status

    integer :: local_node, component, node_row, pressure_dof_count
    integer :: generalized_dof_count
    integer(i64) :: expected_size, cursor

    equation_map = 0_i64
    status = DES_ERROR_INVALID_CONSTRAINT

    if (element_index < 1_i64 .or. element_index > size(mesh%elements, kind=i64)) then
      status = DES_ERROR_INVALID_CONNECTIVITY
      return
    end if
    if (.not. allocated(layout%node_ids) .or. .not. allocated(layout%nodal_equations) .or. &
        .not. allocated(layout%generalized_equations) .or. &
        .not. allocated(layout%pressure_equations)) return

    generalized_dof_count = generalized_dofs_for_analysis(mesh%elements(element_index)%analysis_mode)
    pressure_dof_count = des_2d_pressure_dof_count(mesh%elements(element_index)%pressure_space)

    expected_size = size(mesh%elements(element_index)%connectivity, kind=i64)
    if (expected_size > huge(0_i64)/int(layout%nodal_dofs_per_node, i64)) return
    expected_size = expected_size*int(layout%nodal_dofs_per_node, i64)
    if (expected_size > huge(0_i64)-int(generalized_dof_count, i64)) return
    expected_size = expected_size + int(generalized_dof_count, i64)
    if (expected_size > huge(0_i64)-int(pressure_dof_count, i64)) return
    expected_size = expected_size + int(pressure_dof_count, i64)
    if (size(equation_map, kind=i64) /= expected_size) return

    cursor = 0_i64
    do local_node = 1, size(mesh%elements(element_index)%connectivity)
      node_row = find_node_row(layout, mesh%elements(element_index)%connectivity(local_node))
      if (node_row <= 0) then
        status = DES_ERROR_INVALID_CONNECTIVITY
        return
      end if
      do component = 1, layout%nodal_dofs_per_node
        cursor = cursor + 1_i64
        equation_map(cursor) = layout%nodal_equations(component, node_row)
      end do
    end do

    do component = 1, generalized_dof_count
      cursor = cursor + 1_i64
      equation_map(cursor) = layout%generalized_equations(component, element_index)
    end do

    do component = 1, pressure_dof_count
      cursor = cursor + 1_i64
      equation_map(cursor) = layout%pressure_equations(component, element_index)
    end do

    if (cursor /= expected_size .or. any(equation_map <= 0_i64)) then
      equation_map = 0_i64
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    status = DES_STATUS_OK
  end subroutine build_2d_element_equation_map

  pure integer(i64) function node_equation_from_id(layout, node_id, component) result(equation)
    type(dof_layout_2d_t), intent(in) :: layout
    integer(i64), intent(in) :: node_id
    integer, intent(in) :: component
    integer :: node_row

    equation = 0_i64
    if (.not. allocated(layout%nodal_equations)) return
    if (component < 1 .or. component > layout%nodal_dofs_per_node) return

    node_row = find_node_row(layout, node_id)
    if (node_row <= 0) return
    equation = layout%nodal_equations(component, node_row)
  end function node_equation_from_id

  pure integer function find_node_row(layout, node_id) result(node_row)
    type(dof_layout_2d_t), intent(in) :: layout
    integer(i64), intent(in) :: node_id
    integer :: i

    node_row = 0
    if (.not. allocated(layout%node_ids)) return
    do i = 1, size(layout%node_ids)
      if (layout%node_ids(i) == node_id) then
        node_row = i
        return
      end if
    end do
  end function find_node_row

  pure integer function generalized_dofs_for_analysis(analysis_mode) result(ndof)
    integer, intent(in) :: analysis_mode

    if (analysis_mode == DES_2D_GENERALIZED_PLANE_STRAIN) then
      ! ANSYS current-technology generalized plane-strain seçeneği üç ek
      ! internal kinematic DOF taşır. Dyna bunları pressure alanından ayrı tutar.
      ndof = DES_GENERALIZED_PLANE_STRAIN_DOF
    else
      ndof = 0
    end if
  end function generalized_dofs_for_analysis

end module des_2d_dof_manager
