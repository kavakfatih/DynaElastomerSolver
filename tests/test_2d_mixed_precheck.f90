program test_2d_mixed_precheck
  use des_kinds, only : dp, i64
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONSTRAINT
  use des_2d_analysis_contract, only : DES_2D_AXISYMMETRIC_TORSION, &
      DES_TOPOLOGY_Q8, DES_FORMULATION_MIXED_UP, DES_PRESSURE_SPACE_P1, &
      DES_ELEMENT_TECH_UNIFORM_REDUCED
  use des_2d_mesh_database, only : mesh_database_2d_t
  use des_2d_dof_manager, only : dof_layout_2d_t, build_2d_dof_layout
  use des_mixed_precheck, only : mixed_dof_balance_i64_t, &
      assess_2d_mixed_dof_balance_i64
  implicit none

  type(mesh_database_2d_t) :: mesh
  type(dof_layout_2d_t) :: layout
  type(mixed_dof_balance_i64_t) :: balance
  integer(i64), allocatable :: prescribed(:)
  integer :: status, i

  call build_q8_torsion_mesh(mesh)
  call build_2d_dof_layout(mesh,layout,status)
  call require(status == DES_STATUS_OK, 'Q8 torsion layout precheck için kurulamadı')

  allocate(prescribed(6))
  prescribed = [(int(i,i64),i=1,6)]
  call assess_2d_mixed_dof_balance_i64(layout,prescribed,balance,status)
  call require(status == DES_STATUS_OK, '2D i64 Nd/Np precheck başarısız')
  call require(balance%kinematic_equations == 24_i64, 'Kinematic equation count yanlış')
  call require(balance%pressure_equations == 3_i64, 'Pressure equation count yanlış')
  call require(balance%free_kinematic_equations == 18_i64, 'Free Nd count yanlış')
  call require(abs(balance%nd_over_np-6.0_dp) <= 1.0e-14_dp, 'Nd/Np oranı yanlış')
  call require(.not. balance%overconstrained_by_count, 'Geçerli model overconstrained işaretlendi')
  deallocate(prescribed)

  allocate(prescribed(22))
  prescribed = [(int(i,i64),i=1,22)]
  call assess_2d_mixed_dof_balance_i64(layout,prescribed,balance,status)
  call require(status == DES_STATUS_OK, 'Overconstraint precheck değerlendirilemedi')
  call require(balance%free_kinematic_equations == 2_i64, 'Overconstraint free Nd yanlış')
  call require(balance%overconstrained_by_count, 'Nd < Np durumu yakalanmadı')
  deallocate(prescribed)

  allocate(prescribed(2))
  prescribed = [1_i64,1_i64]
  call assess_2d_mixed_dof_balance_i64(layout,prescribed,balance,status)
  call require(status == DES_ERROR_INVALID_CONSTRAINT, 'Duplicate BC equation reddedilmedi')
  deallocate(prescribed)

  allocate(prescribed(1))
  prescribed = [25_i64]
  call assess_2d_mixed_dof_balance_i64(layout,prescribed,balance,status)
  call require(status == DES_ERROR_INVALID_CONSTRAINT, &
      'Pressure equation kinematic prescribed listesine kabul edildi')

  print '(a)', 'PASS: 2D field-based mixed Nd/Np i64 precheck'

contains

  subroutine build_q8_torsion_mesh(model)
    type(mesh_database_2d_t), intent(out) :: model
    integer :: node

    allocate(model%nodes(8),model%elements(1))
    do node = 1,8
      model%nodes(node)%id = 3000000000_i64+int(node,i64)
      model%nodes(node)%x = real(node-1,dp)
      model%nodes(node)%y = 0.25_dp*real(mod(node-1,3),dp)
    end do

    model%elements(1)%id = 7000000001_i64
    model%elements(1)%topology = DES_TOPOLOGY_Q8
    model%elements(1)%analysis_mode = DES_2D_AXISYMMETRIC_TORSION
    model%elements(1)%formulation = DES_FORMULATION_MIXED_UP
    model%elements(1)%pressure_space = DES_PRESSURE_SPACE_P1
    model%elements(1)%element_technology = DES_ELEMENT_TECH_UNIFORM_REDUCED
    model%elements(1)%material_id = 1_i64
    model%elements(1)%connectivity = [ &
        3000000001_i64,3000000002_i64,3000000003_i64,3000000004_i64, &
        3000000005_i64,3000000006_i64,3000000007_i64,3000000008_i64]
  end subroutine build_q8_torsion_mesh

  subroutine require(condition,message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message

    if (.not. condition) error stop message
  end subroutine require

end program test_2d_mixed_precheck
