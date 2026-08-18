module des_mixed_dof_layout
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONNECTIVITY, &
                         DES_ERROR_INVALID_CONSTRAINT
  implicit none
  private

  public :: mixed_global_equation_counts
  public :: build_discontinuous_pressure_element_dof_map

contains

  pure subroutine mixed_global_equation_counts( &
      node_count, element_count, displacement_components, &
      pressure_dofs_per_element, displacement_equations, &
      pressure_equations, total_equations, status)
    ! Discontinuous element-internal pressure coefficients için global denklem sayısı.
    ! Pressure DOF'ları mesh node'larına eklenmez; displacement denklem bloğundan sonra
    ! her element için benzersiz bir pressure-equation grubu ayrılır.
    integer, intent(in) :: node_count, element_count
    integer, intent(in) :: displacement_components, pressure_dofs_per_element
    integer, intent(out) :: displacement_equations, pressure_equations, total_equations
    integer, intent(out) :: status

    displacement_equations = 0
    pressure_equations = 0
    total_equations = 0

    if (node_count <= 0 .or. element_count <= 0 .or. &
        displacement_components <= 0 .or. pressure_dofs_per_element <= 0) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    displacement_equations = node_count*displacement_components
    pressure_equations = element_count*pressure_dofs_per_element
    total_equations = displacement_equations + pressure_equations
    status = DES_STATUS_OK
  end subroutine mixed_global_equation_counts

  pure subroutine build_discontinuous_pressure_element_dof_map( &
      element_nodes, element_id, node_count, displacement_components, &
      pressure_dofs_per_element, dof_map, status)
    ! Yerel mixed element unknown sırasını global denklem numaralarına taşır:
    ! [node-1 displacement components, ..., node-n displacement components,
    !  element-internal pressure coefficients].
    !
    ! Bu sözleşme Q8/P1 Herrmann adayında 16 + 3 = 19 local unknown üretir.
    ! Axisymmetric-with-torsion için aynı rutin 24 + 3 = 27 unknown üretir.
    integer, intent(in) :: element_nodes(:), element_id, node_count
    integer, intent(in) :: displacement_components, pressure_dofs_per_element
    integer, intent(out) :: dof_map(:)
    integer, intent(out) :: status

    integer :: expected_size, pressure_offset
    integer :: a, c, cursor, p

    dof_map = 0
    expected_size = size(element_nodes)*displacement_components + pressure_dofs_per_element

    if (element_id <= 0 .or. node_count <= 0 .or. &
        displacement_components <= 0 .or. pressure_dofs_per_element <= 0 .or. &
        size(dof_map) /= expected_size) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    do a = 1,size(element_nodes)
      if (element_nodes(a) < 1 .or. element_nodes(a) > node_count) then
        status = DES_ERROR_INVALID_CONNECTIVITY
        return
      end if
    end do

    cursor = 0
    do a = 1,size(element_nodes)
      do c = 1,displacement_components
        cursor = cursor + 1
        dof_map(cursor) = displacement_components*(element_nodes(a)-1) + c
      end do
    end do

    pressure_offset = node_count*displacement_components &
                    + pressure_dofs_per_element*(element_id-1)
    do p = 1,pressure_dofs_per_element
      cursor = cursor + 1
      dof_map(cursor) = pressure_offset + p
    end do

    status = DES_STATUS_OK
  end subroutine build_discontinuous_pressure_element_dof_map

end module des_mixed_dof_layout
