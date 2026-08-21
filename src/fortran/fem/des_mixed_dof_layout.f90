module des_mixed_dof_layout
  use des_kinds, only : i64
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONNECTIVITY, &
                         DES_ERROR_INVALID_CONSTRAINT
  implicit none
  private

  public :: mixed_global_equation_counts
  public :: mixed_global_equation_counts_i64
  public :: build_discontinuous_pressure_element_dof_map
  public :: build_discontinuous_pressure_element_dof_map_i64

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

  pure subroutine build_discontinuous_pressure_element_dof_map_i64( &
      element_nodes, element_id, node_count, displacement_components, &
      pressure_dofs_per_element, dof_map, status)
    ! B9.5l: Mixed element equation numbering'in canonical i64 yoludur.
    ! Buyuk global denklem numaralari default integer'a daraltilmadan uretilir.
    integer(i64), intent(in) :: element_nodes(:), element_id, node_count
    integer(i64), intent(in) :: displacement_components, pressure_dofs_per_element
    integer(i64), intent(out) :: dof_map(:)
    integer, intent(out) :: status

    integer(i64) :: local_node_count, expected_size, displacement_equations
    integer(i64) :: pressure_element_offset, pressure_offset, equation
    integer(i64) :: a, c, cursor, p

    dof_map = 0_i64
    status = DES_ERROR_INVALID_CONSTRAINT

    if (element_id <= 0_i64 .or. node_count <= 0_i64 .or. &
        displacement_components <= 0_i64 .or. pressure_dofs_per_element <= 0_i64) return

    local_node_count = size(element_nodes,kind=i64)
    if (local_node_count > huge(0_i64)/displacement_components) return
    expected_size = local_node_count*displacement_components
    if (expected_size > huge(0_i64)-pressure_dofs_per_element) return
    expected_size = expected_size+pressure_dofs_per_element
    if (size(dof_map,kind=i64) /= expected_size) return

    do a = 1_i64,local_node_count
      if (element_nodes(a) < 1_i64 .or. element_nodes(a) > node_count) then
        status = DES_ERROR_INVALID_CONNECTIVITY
        return
      end if
    end do

    if (node_count > huge(0_i64)/displacement_components) return
    displacement_equations = node_count*displacement_components

    if (element_id-1_i64 > huge(0_i64)/pressure_dofs_per_element) return
    pressure_element_offset = (element_id-1_i64)*pressure_dofs_per_element
    if (displacement_equations > huge(0_i64)-pressure_element_offset) return
    pressure_offset = displacement_equations+pressure_element_offset
    if (pressure_offset > huge(0_i64)-pressure_dofs_per_element) return

    cursor = 0_i64
    do a = 1_i64,local_node_count
      do c = 1_i64,displacement_components
        cursor = cursor+1_i64
        equation = displacement_components*(element_nodes(a)-1_i64)+c
        dof_map(cursor) = equation
      end do
    end do

    do p = 1_i64,pressure_dofs_per_element
      cursor = cursor+1_i64
      dof_map(cursor) = pressure_offset+p
    end do

    status = DES_STATUS_OK
  end subroutine build_discontinuous_pressure_element_dof_map_i64

  pure subroutine build_discontinuous_pressure_element_dof_map( &
      element_nodes, element_id, node_count, displacement_components, &
      pressure_dofs_per_element, dof_map, status)
    ! Legacy default-integer API, canonical i64 numbering yolunun kontrollu
    ! wrapper'idir. Sonuc default integer kapasitesini asarsa map sifir kalir.
    integer, intent(in) :: element_nodes(:), element_id, node_count
    integer, intent(in) :: displacement_components, pressure_dofs_per_element
    integer, intent(out) :: dof_map(:)
    integer, intent(out) :: status

    integer(i64) :: dof_map_i64(size(dof_map))
    integer(i64) :: default_integer_max

    dof_map = 0

    call build_discontinuous_pressure_element_dof_map_i64( &
        int(element_nodes,i64),int(element_id,i64),int(node_count,i64), &
        int(displacement_components,i64),int(pressure_dofs_per_element,i64), &
        dof_map_i64,status)
    if (status /= DES_STATUS_OK) return

    default_integer_max = int(huge(0),i64)
    if (any(dof_map_i64 < 1_i64) .or. any(dof_map_i64 > default_integer_max)) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    dof_map = int(dof_map_i64)
  end subroutine build_discontinuous_pressure_element_dof_map

end module des_mixed_dof_layout
