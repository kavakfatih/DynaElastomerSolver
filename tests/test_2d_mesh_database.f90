program test_2d_mesh_database
  use des_kinds, only : dp, i64
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONNECTIVITY, &
      DES_ERROR_INVALID_PARAMETERS
  use des_2d_analysis_contract, only : DES_2D_PLANE_STRESS, &
      DES_2D_PLANE_STRAIN, DES_2D_AXISYMMETRIC_TORSION, &
      DES_TOPOLOGY_Q4, DES_TOPOLOGY_Q8, DES_TOPOLOGY_Q9_LEGACY, &
      DES_FORMULATION_MIXED_UP, DES_PRESSURE_SPACE_P0, DES_PRESSURE_SPACE_P1, &
      DES_ELEMENT_TECH_SELECTIVE_BBAR, DES_ELEMENT_TECH_UNIFORM_REDUCED, &
      des_2d_analysis_allows_mixed_up, des_2d_nodal_kinematic_dof_count, &
      des_2d_pressure_dof_count, des_2d_primary_mixed_pair_is_defined, &
      des_2d_primary_mixed_configuration_is_defined, &
      des_2d_configuration_is_production_validated
  use des_2d_mesh_database, only : mesh_database_2d_t, validate_2d_mesh_database
  implicit none

  type(mesh_database_2d_t) :: mesh
  integer :: status

  call require(.not. des_2d_analysis_allows_mixed_up(DES_2D_PLANE_STRESS), &
      'Plane-stress mixed u-P contract yanlışlıkla etkinleştirildi')
  call require(des_2d_analysis_allows_mixed_up(DES_2D_PLANE_STRAIN), &
      'Plane-strain mixed u-P contract kapalı')
  call require(des_2d_analysis_allows_mixed_up(DES_2D_AXISYMMETRIC_TORSION), &
      'Axisymmetric torsion mixed u-P contract kapalı')
  call require(des_2d_nodal_kinematic_dof_count(DES_2D_AXISYMMETRIC_TORSION) == 3, &
      'Axisymmetric torsion üç nodal kinematik DOF taşımalı')
  call require(des_2d_pressure_dof_count(DES_PRESSURE_SPACE_P0) == 1, &
      'P0 pressure space bir DOF taşımalı')
  call require(des_2d_pressure_dof_count(DES_PRESSURE_SPACE_P1) == 3, &
      'P1 pressure space üç complete-linear DOF taşımalı')
  call require(des_2d_primary_mixed_pair_is_defined(DES_TOPOLOGY_Q4, DES_PRESSURE_SPACE_P0), &
      'Q4/P0 primary mixed pair tanımsız')
  call require(des_2d_primary_mixed_pair_is_defined(DES_TOPOLOGY_Q8, DES_PRESSURE_SPACE_P1), &
      'Q8/P1 primary mixed pair tanımsız')
  call require(.not. des_2d_primary_mixed_pair_is_defined( &
      DES_TOPOLOGY_Q9_LEGACY, DES_PRESSURE_SPACE_P1), &
      'Q9/P1 yeni production primary pair olmamalı')
  call require(des_2d_primary_mixed_configuration_is_defined( &
      DES_TOPOLOGY_Q4, DES_PRESSURE_SPACE_P0, DES_ELEMENT_TECH_SELECTIVE_BBAR), &
      'Q4/P0 selective-Bbar target configuration tanımsız')
  call require(des_2d_primary_mixed_configuration_is_defined( &
      DES_TOPOLOGY_Q8, DES_PRESSURE_SPACE_P1, DES_ELEMENT_TECH_UNIFORM_REDUCED), &
      'Q8/P1 reduced-integration target configuration tanımsız')

  ! Target configuration ile production acceptance aynı şey değildir. C2
  ! pressure-stability ve end-to-end solver gate'leri kapanana kadar false kalır.
  call require(.not. des_2d_configuration_is_production_validated( &
      DES_TOPOLOGY_Q4, DES_PRESSURE_SPACE_P0, DES_ELEMENT_TECH_SELECTIVE_BBAR), &
      'Q4/P0 henüz production validated ilan edilmemeli')
  call require(.not. des_2d_configuration_is_production_validated( &
      DES_TOPOLOGY_Q8, DES_PRESSURE_SPACE_P1, DES_ELEMENT_TECH_UNIFORM_REDUCED), &
      'Q8/P1 stability gate kapanmadan production validated ilan edilmemeli')

  call build_q8_torsion_mesh(mesh)
  call validate_2d_mesh_database(mesh, status)
  call require(status == DES_STATUS_OK, &
      'Q8/P1 axisymmetric-torsion i64 mesh doğrulanamadı')
  call require(mesh%node_count_i64() == 8_i64, 'i64 node cardinality yanlış')
  call require(mesh%element_count_i64() == 1_i64, 'i64 element cardinality yanlış')
  call require(mesh%nodes(1)%id > int(huge(0), i64), &
      'Regression mesh kimliği default-integer sınırını aşmalı')

  mesh%elements(1)%analysis_mode = DES_2D_PLANE_STRESS
  call validate_2d_mesh_database(mesh, status)
  call require(status == DES_ERROR_INVALID_PARAMETERS, &
      'Plane-stress + mixed u-P geçersiz contract reddedilmedi')

  call build_q8_torsion_mesh(mesh)
  mesh%elements(1)%connectivity(8) = 9000000001_i64
  call validate_2d_mesh_database(mesh, status)
  call require(status == DES_ERROR_INVALID_CONNECTIVITY, &
      'Mesh database içinde olmayan i64 node ID reddedilmedi')

  call build_q4_plane_strain_mesh(mesh)
  call validate_2d_mesh_database(mesh, status)
  call require(status == DES_STATUS_OK, 'Q4/P0 plane-strain mesh doğrulanamadı')

  mesh%elements(1)%analysis_mode = DES_2D_AXISYMMETRIC_TORSION
  mesh%elements(1)%element_technology = DES_ELEMENT_TECH_UNIFORM_REDUCED
  call validate_2d_mesh_database(mesh, status)
  call require(status == DES_ERROR_INVALID_PARAMETERS, &
      'Q4 torsion için ANSYS-benzeri B-bar technology kısıtı korunmadı')

  call build_q4_plane_strain_mesh(mesh)
  mesh%nodes(4)%id = mesh%nodes(3)%id
  call validate_2d_mesh_database(mesh, status)
  call require(status == DES_ERROR_INVALID_CONNECTIVITY, &
      'Tekrarlanan node ID reddedilmedi')

  print '(a)', 'PASS: 2D target/validation contract, technology ve i64 mesh database'

contains

  subroutine build_q8_torsion_mesh(mesh)
    type(mesh_database_2d_t), intent(out) :: mesh
    integer :: i
    integer(i64), parameter :: first_id = 3000000001_i64

    allocate(mesh%nodes(8), mesh%elements(1))

    do i = 1, 8
      mesh%nodes(i)%id = first_id + int(i - 1, i64)
      mesh%nodes(i)%x = real(i - 1, dp)
      mesh%nodes(i)%y = 0.25_dp * real(mod(i - 1, 3), dp)
    end do

    mesh%elements(1)%id = 7000000001_i64
    mesh%elements(1)%topology = DES_TOPOLOGY_Q8
    mesh%elements(1)%analysis_mode = DES_2D_AXISYMMETRIC_TORSION
    mesh%elements(1)%formulation = DES_FORMULATION_MIXED_UP
    mesh%elements(1)%pressure_space = DES_PRESSURE_SPACE_P1
    mesh%elements(1)%element_technology = DES_ELEMENT_TECH_UNIFORM_REDUCED
    mesh%elements(1)%material_id = 1_i64
    mesh%elements(1)%connectivity = [ &
        3000000001_i64, 3000000002_i64, 3000000003_i64, 3000000004_i64, &
        3000000005_i64, 3000000006_i64, 3000000007_i64, 3000000008_i64 ]
  end subroutine build_q8_torsion_mesh

  subroutine build_q4_plane_strain_mesh(mesh)
    type(mesh_database_2d_t), intent(out) :: mesh

    allocate(mesh%nodes(4), mesh%elements(1))

    mesh%nodes(1)%id = 101_i64
    mesh%nodes(1)%x = 0.0_dp
    mesh%nodes(1)%y = 0.0_dp
    mesh%nodes(2)%id = 103_i64
    mesh%nodes(2)%x = 1.0_dp
    mesh%nodes(2)%y = 0.0_dp
    mesh%nodes(3)%id = 107_i64
    mesh%nodes(3)%x = 1.0_dp
    mesh%nodes(3)%y = 1.0_dp
    mesh%nodes(4)%id = 109_i64
    mesh%nodes(4)%x = 0.0_dp
    mesh%nodes(4)%y = 1.0_dp

    mesh%elements(1)%id = 201_i64
    mesh%elements(1)%topology = DES_TOPOLOGY_Q4
    mesh%elements(1)%analysis_mode = DES_2D_PLANE_STRAIN
    mesh%elements(1)%formulation = DES_FORMULATION_MIXED_UP
    mesh%elements(1)%pressure_space = DES_PRESSURE_SPACE_P0
    mesh%elements(1)%element_technology = DES_ELEMENT_TECH_SELECTIVE_BBAR
    mesh%elements(1)%material_id = 1_i64
    mesh%elements(1)%connectivity = [101_i64, 103_i64, 107_i64, 109_i64]
  end subroutine build_q4_plane_strain_mesh

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message

    if (.not. condition) error stop message
  end subroutine require

end program test_2d_mesh_database
