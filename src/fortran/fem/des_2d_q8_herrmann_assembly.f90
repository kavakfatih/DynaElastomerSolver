module des_2d_q8_herrmann_assembly
  use des_kinds, only : dp, i64
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONNECTIVITY, &
      DES_ERROR_INVALID_CONSTRAINT, DES_ERROR_INVALID_PARAMETERS
  use des_2d_analysis_contract, only : DES_2D_PLANE_STRAIN, DES_2D_AXISYMMETRIC, &
      DES_2D_AXISYMMETRIC_TORSION, DES_TOPOLOGY_Q8, DES_FORMULATION_MIXED_UP, &
      DES_PRESSURE_SPACE_P1, DES_ELEMENT_TECH_UNIFORM_REDUCED
  use des_2d_mesh_database, only : mesh_database_2d_t, validate_2d_mesh_database
  use des_2d_dof_manager, only : dof_layout_2d_t, build_2d_element_equation_map
  use des_csr_matrix, only : csr_matrix_t, initialize_csr_from_element_dof_maps_i64, &
      csr_add_local_matrix_i64
  use des_q8_plane_strain_herrmann_neo_hookean, only : &
      Q8_HERRMANN_TOTAL_DOF, evaluate_q8_plane_strain_herrmann_reduced_element
  use des_q8_axisymmetric_herrmann_neo_hookean, only : &
      Q8_AXISYM_HERRMANN_TOTAL_DOF, evaluate_q8_axisymmetric_herrmann_reduced_element
  use des_q8_axisymmetric_torsion_herrmann_neo_hookean, only : &
      Q8_TORSION_HERRMANN_TOTAL_DOF, &
      evaluate_q8_axisymmetric_torsion_herrmann_reduced_element
  implicit none
  private

  public :: initialize_2d_q8_herrmann_csr_pattern
  public :: assemble_2d_q8_herrmann_csr

contains

  subroutine initialize_2d_q8_herrmann_csr_pattern(mesh,layout,tangent,status)
    type(mesh_database_2d_t), intent(in) :: mesh
    type(dof_layout_2d_t), intent(in) :: layout
    type(csr_matrix_t), intent(out) :: tangent
    integer, intent(out) :: status

    integer(i64), allocatable :: element_maps(:,:)
    integer :: local_dof_count, e

    call validate_q8_solution_region(mesh,layout,local_dof_count,status)
    if (status /= DES_STATUS_OK) return

    allocate(element_maps(size(mesh%elements),local_dof_count))
    do e = 1,size(mesh%elements)
      call build_2d_element_equation_map( &
          mesh,layout,int(e,i64),element_maps(e,:),status)
      if (status /= DES_STATUS_OK) return
    end do

    call initialize_csr_from_element_dof_maps_i64( &
        tangent,layout%total_equation_count,layout%total_equation_count, &
        element_maps,status)
  end subroutine initialize_2d_q8_herrmann_csr_pattern

  subroutine assemble_2d_q8_herrmann_csr( &
      mesh,layout,state,shear_modulus,pressure_compliance,residual,tangent,status,min_j)
    type(mesh_database_2d_t), intent(in) :: mesh
    type(dof_layout_2d_t), intent(in) :: layout
    real(dp), intent(in) :: state(:)
    real(dp), intent(in) :: shear_modulus, pressure_compliance
    real(dp), intent(out) :: residual(:)
    type(csr_matrix_t), intent(inout) :: tangent
    integer, intent(out) :: status
    real(dp), intent(out) :: min_j

    real(dp) :: X(8,2),u2(8,2),u3(8,3),pressure(3)
    real(dp) :: r19(Q8_HERRMANN_TOTAL_DOF),k19(Q8_HERRMANN_TOTAL_DOF,Q8_HERRMANN_TOTAL_DOF)
    real(dp) :: r27(Q8_TORSION_HERRMANN_TOTAL_DOF)
    real(dp) :: k27(Q8_TORSION_HERRMANN_TOTAL_DOF,Q8_TORSION_HERRMANN_TOTAL_DOF)
    integer(i64), allocatable :: equation_map(:)
    real(dp) :: element_min_j
    integer :: local_dof_count,e,a,c,node_row

    residual = 0.0_dp
    min_j = huge(1.0_dp)

    call validate_q8_solution_region(mesh,layout,local_dof_count,status)
    if (status /= DES_STATUS_OK) return

    if (size(state,kind=i64) /= layout%total_equation_count .or. &
        size(residual,kind=i64) /= layout%total_equation_count) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if
    if (tangent%nrows /= layout%total_equation_count .or. &
        tangent%ncols /= layout%total_equation_count .or. &
        .not. allocated(tangent%row_ptr) .or. .not. allocated(tangent%values)) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if
    if (shear_modulus <= 0.0_dp .or. pressure_compliance < 0.0_dp) then
      status = DES_ERROR_INVALID_PARAMETERS
      return
    end if

    call tangent%zero_values()
    allocate(equation_map(local_dof_count))

    do e = 1,size(mesh%elements)
      call build_2d_element_equation_map( &
          mesh,layout,int(e,i64),equation_map,status)
      if (status /= DES_STATUS_OK) return

      do a = 1,8
        node_row = find_mesh_node_row(mesh,mesh%elements(e)%connectivity(a))
        if (node_row <= 0) then
          status = DES_ERROR_INVALID_CONNECTIVITY
          return
        end if
        X(a,1) = mesh%nodes(node_row)%x
        X(a,2) = mesh%nodes(node_row)%y
      end do

      pressure = state(layout%pressure_equations(1:3,e))

      select case (layout%analysis_mode)
      case (DES_2D_PLANE_STRAIN,DES_2D_AXISYMMETRIC)
        do a = 1,8
          do c = 1,2
            u2(a,c) = state(layout%nodal_equations(c, &
                find_mesh_node_row(mesh,mesh%elements(e)%connectivity(a))))
          end do
        end do

        if (layout%analysis_mode == DES_2D_PLANE_STRAIN) then
          call evaluate_q8_plane_strain_herrmann_reduced_element( &
              X,u2,pressure,shear_modulus,pressure_compliance, &
              r19,k19,status,element_min_j)
        else
          call evaluate_q8_axisymmetric_herrmann_reduced_element( &
              X,u2,pressure,shear_modulus,pressure_compliance, &
              r19,k19,status,element_min_j)
        end if
        if (status /= DES_STATUS_OK) return

        residual(equation_map) = residual(equation_map)+r19
        call csr_add_local_matrix_i64(tangent,equation_map,k19,status)
        if (status /= DES_STATUS_OK) return

      case (DES_2D_AXISYMMETRIC_TORSION)
        do a = 1,8
          node_row = find_mesh_node_row(mesh,mesh%elements(e)%connectivity(a))
          do c = 1,3
            u3(a,c) = state(layout%nodal_equations(c,node_row))
          end do
        end do

        call evaluate_q8_axisymmetric_torsion_herrmann_reduced_element( &
            X,u3,pressure,shear_modulus,pressure_compliance, &
            r27,k27,status,element_min_j)
        if (status /= DES_STATUS_OK) return

        residual(equation_map) = residual(equation_map)+r27
        call csr_add_local_matrix_i64(tangent,equation_map,k27,status)
        if (status /= DES_STATUS_OK) return

      case default
        status = DES_ERROR_INVALID_PARAMETERS
        return
      end select

      min_j = min(min_j,element_min_j)
    end do

    status = DES_STATUS_OK
  end subroutine assemble_2d_q8_herrmann_csr

  subroutine validate_q8_solution_region(mesh,layout,local_dof_count,status)
    type(mesh_database_2d_t), intent(in) :: mesh
    type(dof_layout_2d_t), intent(in) :: layout
    integer, intent(out) :: local_dof_count
    integer, intent(out) :: status
    integer :: e

    local_dof_count = 0
    call validate_2d_mesh_database(mesh,status)
    if (status /= DES_STATUS_OK) return

    if (layout%analysis_mode /= mesh%elements(1)%analysis_mode) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    select case (layout%analysis_mode)
    case (DES_2D_PLANE_STRAIN,DES_2D_AXISYMMETRIC)
      local_dof_count = Q8_HERRMANN_TOTAL_DOF
      if (layout%nodal_dofs_per_node /= 2) then
        status = DES_ERROR_INVALID_CONSTRAINT
        return
      end if
    case (DES_2D_AXISYMMETRIC_TORSION)
      local_dof_count = Q8_TORSION_HERRMANN_TOTAL_DOF
      if (layout%nodal_dofs_per_node /= 3) then
        status = DES_ERROR_INVALID_CONSTRAINT
        return
      end if
    case default
      status = DES_ERROR_INVALID_PARAMETERS
      return
    end select

    do e = 1,size(mesh%elements)
      if (mesh%elements(e)%topology /= DES_TOPOLOGY_Q8 .or. &
          mesh%elements(e)%formulation /= DES_FORMULATION_MIXED_UP .or. &
          mesh%elements(e)%pressure_space /= DES_PRESSURE_SPACE_P1 .or. &
          mesh%elements(e)%element_technology /= DES_ELEMENT_TECH_UNIFORM_REDUCED .or. &
          mesh%elements(e)%analysis_mode /= layout%analysis_mode) then
        status = DES_ERROR_INVALID_PARAMETERS
        return
      end if
    end do

    status = DES_STATUS_OK
  end subroutine validate_q8_solution_region

  pure integer function find_mesh_node_row(mesh,node_id) result(row)
    type(mesh_database_2d_t), intent(in) :: mesh
    integer(i64), intent(in) :: node_id
    integer :: i

    row = 0
    do i = 1,size(mesh%nodes)
      if (mesh%nodes(i)%id == node_id) then
        row = i
        return
      end if
    end do
  end function find_mesh_node_row

end module des_2d_q8_herrmann_assembly
