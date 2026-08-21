module des_mixed_dof_layout
  use des_kinds, only : i64
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONNECTIVITY, &
                         DES_ERROR_INVALID_CONSTRAINT
  implicit none
  private

  public :: mixed_global_equation_counts
  public :: mixed_global_equation_counts_i64
  public :: build_discontinuous_pressure_element_dof_map

contains

  pure subroutine mixed_global_equation_counts_i64( &
      node_count, element_count, displacement_components, &
      pressure_dofs_per_element, displacement_equations, &
      pressure_equations, total_equations, status)
    ! B9.5g: Global mixed equation cardinality hesaplarini i64 uzerinde yapar.
    ! Bu rutin yalniz sayim yapar; buyuk problem icin allocation gerektirmez.
    integer(i64), intent(in) :: node_count, element_count
    integer(i64), intent(in) :: displacement_components, pressure_dofs_per_element
    integer(i64), intent(out) :: displacement_equations, pressure_equations
    integer(i64), intent(out) :: total_equations
    integer, intent(out) :: status

    displacement_equations = 0_i64
    pressure_equations = 0_i64
    total_equations = 0_i64
    status = DES_ERROR_INVALID_CONSTRAINT

    if (node_count <= 0_i64 .or. element_count <= 0_i64 .or. &
        displacement_components <= 0_i64 .or. pressure_dofs_per_element <= 0_i64) return

    if (node_count > huge(0_i64)/displacement_components) return
    displacement_equations = node_count*displacement_components

    if (element_count > huge(0_i64)/pressure_dofs_per_element) then
      displacement_equations = 0_i64
      return
    end if
    pressure_equations = element_count*pressure_dofs_per_element

    if (displacement_equations > huge(0_i64)-pressure_equations) then
      displacement_equations = 0_i64
      pressure_equations = 0_i64
      return
    end if

    total_equations = displacement_equations+pressure_equations
    status = DES_STATUS_OK
  end subroutine mixed_global_equation_counts_i64

  pure subroutine mixed_global_equation_counts( &
      node_count, element_count, displacement_components, &
      pressure_dofs_per_element, displacement_equations, &
      pressure_equations, total_equations, status)
    ! Legacy default-integer API korunur; aritmetik i64 helper uzerinden yapilir.
    ! Sonuc default integer kapasitesini asarsa silent wrap yerine fail-fast doner.
    integer, intent(in) :: node_count, element_count
    integer, intent(in) :: displacement_components, pressure_dofs_per_element
    integer, intent(out) :: displacement_equations, pressure_equations, total_equations
    integer, intent(out) :: status

    integer(i64) :: displacement_equations_i64, pressure_equations_i64
    integer(i64) :: total_equations_i64, default_integer_max

    displacement_equations = 0
    pressure_equations = 0
    total_equations = 0

    call mixed_global_equation_counts_i64( &
        int(node_count,i64),int(element_count,i64), &
        int(displacement_components,i64),int(pressure_dofs_per_element,i64), &
        displacement_equations_i64,pressure_equations_i64,total_equations_i64,status)
    if (status /= DES_STATUS_OK) return

    default_integer_max = int(huge(0),i64)
    if (displacement_equations_i64 > default_integer_max .or. &
        pressure_equations_i64 > default_integer_max .or. &
        total_equations_i64 > default_integer_max) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    displacement_equations = int(displacement_equations_i64)
    pressure_equations = int(pressure_equations_i64)
    total_equations = int(total_equations_i64)
  end subroutine mixed_global_equation_counts

  pure subroutine build_discontinuous_pressure_element_dof_map( &
      element_nodes, element_id, node_count, displacement_components, &
      pressure_dofs_per_element, dof_map, status)
    ! Yerel mixed element unknown sirasini global denklem numaralarina tasir:
    ! [node-1 displacement components, ..., node-n displacement components,
    !  element-internal pressure coefficients].
    !
    ! B9.5g: Pressure offset ve equation-number aritmetigi i64 temporary ile
    ! yapilir. Default-integer dof_map'e yalniz butun aralik kanitlandiktan sonra
    ! narrowing yapilir; boylece buyuk numbering sessizce wrap etmez.
    integer, intent(in) :: element_nodes(:), element_id, node_count
    integer, intent(in) :: displacement_components, pressure_dofs_per_element
    integer, intent(out) :: dof_map(:)
    integer, intent(out) :: status

    integer :: a, c, cursor, p
    integer(i64) :: local_node_count_i64, component_count_i64, pressure_count_i64
    integer(i64) :: expected_size_i64, displacement_equations_i64
    integer(i64) :: pressure_element_offset_i64, pressure_offset_i64
    integer(i64) :: equation_i64, default_integer_max

    dof_map = 0
    status = DES_ERROR_INVALID_CONSTRAINT

    if (element_id <= 0 .or. node_count <= 0 .or. &
        displacement_components <= 0 .or. pressure_dofs_per_element <= 0) return

    local_node_count_i64 = size(element_nodes,kind=i64)
    component_count_i64 = int(displacement_components,i64)
    pressure_count_i64 = int(pressure_dofs_per_element,i64)

    if (local_node_count_i64 > huge(0_i64)/component_count_i64) return
    expected_size_i64 = local_node_count_i64*component_count_i64
    if (expected_size_i64 > huge(0_i64)-pressure_count_i64) return
    expected_size_i64 = expected_size_i64+pressure_count_i64
    if (size(dof_map,kind=i64) /= expected_size_i64) return

    do a = 1,size(element_nodes)
      if (element_nodes(a) < 1 .or. element_nodes(a) > node_count) then
        status = DES_ERROR_INVALID_CONNECTIVITY
        return
      end if
    end do

    if (int(node_count,i64) > huge(0_i64)/component_count_i64) return
    displacement_equations_i64 = int(node_count,i64)*component_count_i64

    if (int(element_id-1,i64) > huge(0_i64)/pressure_count_i64) return
    pressure_element_offset_i64 = int(element_id-1,i64)*pressure_count_i64
    if (displacement_equations_i64 > huge(0_i64)-pressure_element_offset_i64) return
    pressure_offset_i64 = displacement_equations_i64+pressure_element_offset_i64

    default_integer_max = int(huge(0),i64)
    if (pressure_count_i64 > default_integer_max) return
    if (pressure_offset_i64 > default_integer_max-pressure_count_i64) return

    cursor = 0
    do a = 1,size(element_nodes)
      do c = 1,displacement_components
        cursor = cursor+1
        equation_i64 = component_count_i64*int(element_nodes(a)-1,i64)+int(c,i64)
        dof_map(cursor) = int(equation_i64)
      end do
    end do

    do p = 1,pressure_dofs_per_element
      cursor = cursor+1
      equation_i64 = pressure_offset_i64+int(p,i64)
      dof_map(cursor) = int(equation_i64)
    end do

    status = DES_STATUS_OK
  end subroutine build_discontinuous_pressure_element_dof_map

end module des_mixed_dof_layout
