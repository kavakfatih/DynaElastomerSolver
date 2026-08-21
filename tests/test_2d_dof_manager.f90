program test_2d_dof_manager
  use des_kinds, only : dp, i64
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_PARAMETERS
  use des_2d_analysis_contract, only : DES_2D_PLANE_STRAIN, &
      DES_2D_GENERALIZED_PLANE_STRAIN, DES_2D_AXISYMMETRIC_TORSION, &
      DES_TOPOLOGY_Q4, DES_TOPOLOGY_Q8, DES_FORMULATION_MIXED_UP, &
      DES_PRESSURE_SPACE_P0, DES_PRESSURE_SPACE_P1, &
      DES_ELEMENT_TECH_SELECTIVE_BBAR, DES_ELEMENT_TECH_UNIFORM_REDUCED
  use des_2d_mesh_database, only : mesh_database_2d_t
  use des_2d_dof_manager, only : dof_layout_2d_t, build_2d_dof_layout, &
      build_2d_element_equation_map, node_equation_from_id
  implicit none

  type(mesh_database_2d_t) :: mesh
  type(dof_layout_2d_t) :: layout
  integer(i64), allocatable :: element_map(:)
  integer :: status, i

  call build_q8_torsion_mesh(mesh)
  call build_2d_dof_layout(mesh, layout, status)
  call require(status == DES_STATUS_OK, 'Q8/P1 torsion DOF layout kurulamadı')
  call require(layout%nodal_dofs_per_node == 3, 'Torsion nodal DOF sayısı 3 olmalı')
  call require(layout%nodal_equation_count == 24_i64, 'Q8 torsion nodal equation count yanlış')
  call require(layout%generalized_equation_count == 0_i64, 'Torsion generalized DOF üretmemeli')
  call require(layout%pressure_equation_count == 3_i64, 'Q8/P1 pressure equation count yanlış')
  call require(layout%total_equation_count == 27_i64, 'Q8/P1 torsion toplam equation count 27 olmalı')
  call require(node_equation_from_id(layout, 3000000001_i64, 1) == 1_i64, &
      'Büyük external node ID ilk equation ile eşleşmedi')
  call require(node_equation_from_id(layout, 3000000008_i64, 3) == 24_i64, &
      'Büyük external node ID son torsion equation ile eşleşmedi')

  allocate(element_map(27))
  call build_2d_element_equation_map(mesh, layout, 1_i64, element_map, status)
  call require(status == DES_STATUS_OK, 'Q8/P1 torsion local-to-global map kurulamadı')
  call require(all(element_map(1:24) == [(int(i, i64), i=1,24)]), &
      'Q8 torsion kinematic equation ordering yanlış')
  call require(all(element_map(25:27) == [25_i64, 26_i64, 27_i64]), &
      'Q8/P1 pressure block ordering yanlış')
  deallocate(element_map)

  call build_q4_plane_strain_mesh(mesh)
  call build_2d_dof_layout(mesh, layout, status)
  call require(status == DES_STATUS_OK, 'Q4/P0 plane-strain DOF layout kurulamadı')
  call require(layout%nodal_equation_count == 8_i64, 'Q4 plane-strain nodal count yanlış')
  call require(layout%pressure_equation_count == 1_i64, 'Q4/P0 pressure count yanlış')
  call require(layout%total_equation_count == 9_i64, 'Q4/P0 toplam equation count 9 olmalı')

  allocate(element_map(9))
  call build_2d_element_equation_map(mesh, layout, 1_i64, element_map, status)
  call require(status == DES_STATUS_OK, 'Q4/P0 local-to-global map kurulamadı')
  call require(element_map(9) == 9_i64, 'Q4/P0 pressure equation son blokta olmalı')
  deallocate(element_map)

  call build_q8_generalized_plane_strain_mesh(mesh)
  call build_2d_dof_layout(mesh, layout, status)
  call require(status == DES_STATUS_OK, 'Generalized plane-strain DOF layout kurulamadı')
  call require(layout%nodal_equation_count == 16_i64, 'GPS nodal equation count yanlış')
  call require(layout%generalized_equation_count == 3_i64, 'GPS üç internal kinematic DOF taşımalı')
  call require(layout%pressure_equation_count == 3_i64, 'GPS Q8/P1 pressure count yanlış')
  call require(layout%total_equation_count == 22_i64, 'GPS Q8/P1 toplam equation count 22 olmalı')

  allocate(element_map(22))
  call build_2d_element_equation_map(mesh, layout, 1_i64, element_map, status)
  call require(status == DES_STATUS_OK, 'GPS Q8/P1 local-to-global map kurulamadı')
  call require(all(element_map(17:19) == [17_i64,18_i64,19_i64]), &
      'GPS internal kinematic block pressure önünde olmalı')
  call require(all(element_map(20:22) == [20_i64,21_i64,22_i64]), &
      'GPS pressure block ordering yanlış')
  deallocate(element_map)

  ! Aynı solution region içinde incompatible 2D analysis mode karışımı reddedilir.
  call build_two_element_mixed_analysis_mesh(mesh)
  call build_2d_dof_layout(mesh, layout, status)
  call require(status == DES_ERROR_INVALID_PARAMETERS, &
      'Tek solution region içinde farklı analysis mode karışımı reddedilmedi')

  print '(a)', 'PASS: field-based 2D i64 DOF manager'

contains

  subroutine build_q8_torsion_mesh(mesh)
    type(mesh_database_2d_t), intent(out) :: mesh
    integer :: i

    allocate(mesh%nodes(8), mesh%elements(1))
    do i = 1, 8
      mesh%nodes(i)%id = 3000000000_i64 + int(i, i64)
      mesh%nodes(i)%x = real(i - 1, dp)
      mesh%nodes(i)%y = 0.25_dp*real(mod(i - 1, 3), dp)
    end do

    mesh%elements(1)%id = 7000000001_i64
    mesh%elements(1)%topology = DES_TOPOLOGY_Q8
    mesh%elements(1)%analysis_mode = DES_2D_AXISYMMETRIC_TORSION
    mesh%elements(1)%formulation = DES_FORMULATION_MIXED_UP
    mesh%elements(1)%pressure_space = DES_PRESSURE_SPACE_P1
    mesh%elements(1)%element_technology = DES_ELEMENT_TECH_UNIFORM_REDUCED
    mesh%elements(1)%material_id = 1_i64
    mesh%elements(1)%connectivity = [ &
        3000000001_i64,3000000002_i64,3000000003_i64,3000000004_i64, &
        3000000005_i64,3000000006_i64,3000000007_i64,3000000008_i64]
  end subroutine build_q8_torsion_mesh

  subroutine build_q4_plane_strain_mesh(mesh)
    type(mesh_database_2d_t), intent(out) :: mesh

    allocate(mesh%nodes(4), mesh%elements(1))
    mesh%nodes(1)%id = 10_i64; mesh%nodes(1)%x = 0.0_dp; mesh%nodes(1)%y = 0.0_dp
    mesh%nodes(2)%id = 20_i64; mesh%nodes(2)%x = 1.0_dp; mesh%nodes(2)%y = 0.0_dp
    mesh%nodes(3)%id = 30_i64; mesh%nodes(3)%x = 1.0_dp; mesh%nodes(3)%y = 1.0_dp
    mesh%nodes(4)%id = 40_i64; mesh%nodes(4)%x = 0.0_dp; mesh%nodes(4)%y = 1.0_dp

    mesh%elements(1)%id = 1_i64
    mesh%elements(1)%topology = DES_TOPOLOGY_Q4
    mesh%elements(1)%analysis_mode = DES_2D_PLANE_STRAIN
    mesh%elements(1)%formulation = DES_FORMULATION_MIXED_UP
    mesh%elements(1)%pressure_space = DES_PRESSURE_SPACE_P0
    mesh%elements(1)%element_technology = DES_ELEMENT_TECH_SELECTIVE_BBAR
    mesh%elements(1)%material_id = 1_i64
    mesh%elements(1)%connectivity = [10_i64,20_i64,30_i64,40_i64]
  end subroutine build_q4_plane_strain_mesh

  subroutine build_q8_generalized_plane_strain_mesh(mesh)
    type(mesh_database_2d_t), intent(out) :: mesh
    integer :: i

    allocate(mesh%nodes(8), mesh%elements(1))
    do i = 1, 8
      mesh%nodes(i)%id = int(100 + 10*i, i64)
      mesh%nodes(i)%x = real(i - 1, dp)
      mesh%nodes(i)%y = 0.1_dp*real(mod(i - 1, 2), dp)
    end do

    mesh%elements(1)%id = 5_i64
    mesh%elements(1)%topology = DES_TOPOLOGY_Q8
    mesh%elements(1)%analysis_mode = DES_2D_GENERALIZED_PLANE_STRAIN
    mesh%elements(1)%formulation = DES_FORMULATION_MIXED_UP
    mesh%elements(1)%pressure_space = DES_PRESSURE_SPACE_P1
    mesh%elements(1)%element_technology = DES_ELEMENT_TECH_UNIFORM_REDUCED
    mesh%elements(1)%material_id = 2_i64
    mesh%elements(1)%connectivity = [110_i64,120_i64,130_i64,140_i64, &
                                     150_i64,160_i64,170_i64,180_i64]
  end subroutine build_q8_generalized_plane_strain_mesh

  subroutine build_two_element_mixed_analysis_mesh(mesh)
    type(mesh_database_2d_t), intent(out) :: mesh
    integer :: i

    allocate(mesh%nodes(8), mesh%elements(2))
    do i = 1, 8
      mesh%nodes(i)%id = int(i, i64)
      mesh%nodes(i)%x = real(mod(i - 1, 4), dp)
      mesh%nodes(i)%y = real((i - 1)/4, dp)
    end do

    mesh%elements(1)%id = 1_i64
    mesh%elements(1)%topology = DES_TOPOLOGY_Q4
    mesh%elements(1)%analysis_mode = DES_2D_PLANE_STRAIN
    mesh%elements(1)%formulation = DES_FORMULATION_MIXED_UP
    mesh%elements(1)%pressure_space = DES_PRESSURE_SPACE_P0
    mesh%elements(1)%element_technology = DES_ELEMENT_TECH_SELECTIVE_BBAR
    mesh%elements(1)%material_id = 1_i64
    mesh%elements(1)%connectivity = [1_i64,2_i64,3_i64,4_i64]

    mesh%elements(2)%id = 2_i64
    mesh%elements(2)%topology = DES_TOPOLOGY_Q4
    mesh%elements(2)%analysis_mode = DES_2D_AXISYMMETRIC_TORSION
    mesh%elements(2)%formulation = DES_FORMULATION_MIXED_UP
    mesh%elements(2)%pressure_space = DES_PRESSURE_SPACE_P0
    mesh%elements(2)%element_technology = DES_ELEMENT_TECH_SELECTIVE_BBAR
    mesh%elements(2)%material_id = 1_i64
    mesh%elements(2)%connectivity = [5_i64,6_i64,7_i64,8_i64]
  end subroutine build_two_element_mixed_analysis_mesh

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message

    if (.not. condition) error stop message
  end subroutine require

end program test_2d_dof_manager
