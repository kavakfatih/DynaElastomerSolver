program test_2d_q8_herrmann_csr_assembly
  use des_kinds, only : dp, i64
  use des_status, only : DES_STATUS_OK
  use des_2d_analysis_contract, only : DES_2D_PLANE_STRAIN, DES_2D_AXISYMMETRIC, &
      DES_2D_AXISYMMETRIC_TORSION, DES_TOPOLOGY_Q8, DES_FORMULATION_MIXED_UP, &
      DES_PRESSURE_SPACE_P1, DES_ELEMENT_TECH_UNIFORM_REDUCED
  use des_2d_mesh_database, only : mesh_database_2d_t
  use des_2d_dof_manager, only : dof_layout_2d_t, build_2d_dof_layout
  use des_csr_matrix, only : csr_matrix_t, csr_to_dense
  use des_2d_q8_herrmann_assembly, only : initialize_2d_q8_herrmann_csr_pattern, &
      assemble_2d_q8_herrmann_csr
  use des_q8_plane_strain_herrmann_neo_hookean, only : &
      evaluate_q8_plane_strain_herrmann_reduced_element
  use des_q8_axisymmetric_herrmann_neo_hookean, only : &
      evaluate_q8_axisymmetric_herrmann_reduced_element
  use des_q8_axisymmetric_torsion_herrmann_neo_hookean, only : &
      evaluate_q8_axisymmetric_torsion_herrmann_reduced_element
  implicit none

  call run_plane_strain_case()
  call run_axisymmetric_case()
  call run_axisymmetric_torsion_case()

  print '(a)', 'PASS: 2D Q8 Herrmann i64 CSR assembly vertical slice'

contains

  subroutine run_plane_strain_case()
    type(mesh_database_2d_t) :: mesh
    type(dof_layout_2d_t) :: layout
    type(csr_matrix_t) :: tangent
    real(dp), allocatable :: state(:),residual(:),dense(:,:)
    real(dp) :: X(8,2),u(8,2),p(3),r_ref(19),k_ref(19,19),min_j,min_j_ref
    integer :: status,a

    call build_q8_mesh(mesh,DES_2D_PLANE_STRAIN,.false.)
    call build_2d_dof_layout(mesh,layout,status)
    call require(status == DES_STATUS_OK,'Plane-strain layout kurulamadı')
    call require(layout%total_equation_count == 19_i64,'Plane-strain total equation count yanlış')

    allocate(state(19),residual(19),dense(19,19))
    state = 0.0_dp
    do a = 1,8
      X(a,:) = [mesh%nodes(a)%x,mesh%nodes(a)%y]
      u(a,1) = 0.08_dp*X(a,1)+0.12_dp*X(a,2)
      u(a,2) = 0.04_dp*X(a,1)-0.05_dp*X(a,2)
      state(layout%nodal_equations(1,a)) = u(a,1)
      state(layout%nodal_equations(2,a)) = u(a,2)
    end do
    p = [-0.5_dp,0.03_dp,-0.02_dp]
    state(layout%pressure_equations(1:3,1)) = p

    call initialize_2d_q8_herrmann_csr_pattern(mesh,layout,tangent,status)
    call require(status == DES_STATUS_OK,'Plane-strain i64 CSR pattern kurulamadı')
    call assemble_2d_q8_herrmann_csr( &
        mesh,layout,state,2.5_dp,0.02_dp,residual,tangent,status,min_j)
    call require(status == DES_STATUS_OK,'Plane-strain i64 CSR assembly başarısız')
    call csr_to_dense(tangent,dense,status)
    call require(status == DES_STATUS_OK,'Plane-strain CSR dense dönüşüm başarısız')

    call evaluate_q8_plane_strain_herrmann_reduced_element( &
        X,u,p,2.5_dp,0.02_dp,r_ref,k_ref,status,min_j_ref)
    call require(status == DES_STATUS_OK,'Plane-strain local reference başarısız')
    call require(maxval(abs(residual-r_ref)) <= 2.0e-13_dp, &
        'Plane-strain global residual local reference ile uyuşmuyor')
    call require(maxval(abs(dense-k_ref)) <= 2.0e-13_dp, &
        'Plane-strain CSR tangent local reference ile uyuşmuyor')
    call require(abs(min_j-min_j_ref) <= 1.0e-14_dp,'Plane-strain global min-J yanlış')
  end subroutine run_plane_strain_case

  subroutine run_axisymmetric_case()
    type(mesh_database_2d_t) :: mesh
    type(dof_layout_2d_t) :: layout
    type(csr_matrix_t) :: tangent
    real(dp), allocatable :: state(:),residual(:),dense(:,:)
    real(dp) :: X(8,2),u(8,2),p(3),r_ref(19),k_ref(19,19),min_j,min_j_ref
    integer :: status,a

    call build_q8_mesh(mesh,DES_2D_AXISYMMETRIC,.true.)
    call build_2d_dof_layout(mesh,layout,status)
    call require(status == DES_STATUS_OK,'Axisymmetric layout kurulamadı')
    allocate(state(19),residual(19),dense(19,19))
    state = 0.0_dp

    do a = 1,8
      X(a,:) = [mesh%nodes(a)%x,mesh%nodes(a)%y]
      u(a,1) = 0.04_dp*X(a,1)
      u(a,2) = 0.01_dp*X(a,1)+0.02_dp*X(a,2)
      state(layout%nodal_equations(1,a)) = u(a,1)
      state(layout%nodal_equations(2,a)) = u(a,2)
    end do
    p = [-0.4_dp,0.02_dp,0.01_dp]
    state(layout%pressure_equations(1:3,1)) = p

    call initialize_2d_q8_herrmann_csr_pattern(mesh,layout,tangent,status)
    call require(status == DES_STATUS_OK,'Axisymmetric i64 CSR pattern kurulamadı')
    call assemble_2d_q8_herrmann_csr( &
        mesh,layout,state,2.5_dp,0.02_dp,residual,tangent,status,min_j)
    call require(status == DES_STATUS_OK,'Axisymmetric i64 CSR assembly başarısız')
    call csr_to_dense(tangent,dense,status)
    call require(status == DES_STATUS_OK,'Axisymmetric CSR dense dönüşüm başarısız')

    call evaluate_q8_axisymmetric_herrmann_reduced_element( &
        X,u,p,2.5_dp,0.02_dp,r_ref,k_ref,status,min_j_ref)
    call require(status == DES_STATUS_OK,'Axisymmetric local reference başarısız')
    call require(maxval(abs(residual-r_ref)) <= 2.0e-13_dp, &
        'Axisymmetric global residual local reference ile uyuşmuyor')
    call require(maxval(abs(dense-k_ref)) <= 2.0e-13_dp, &
        'Axisymmetric CSR tangent local reference ile uyuşmuyor')
    call require(abs(min_j-min_j_ref) <= 1.0e-14_dp,'Axisymmetric global min-J yanlış')
  end subroutine run_axisymmetric_case

  subroutine run_axisymmetric_torsion_case()
    type(mesh_database_2d_t) :: mesh
    type(dof_layout_2d_t) :: layout
    type(csr_matrix_t) :: tangent
    real(dp), allocatable :: state(:),residual(:),dense(:,:)
    real(dp) :: X(8,2),u(8,3),p(3),r_ref(27),k_ref(27,27),min_j,min_j_ref
    integer :: status,a

    call build_q8_mesh(mesh,DES_2D_AXISYMMETRIC_TORSION,.true.)
    call build_2d_dof_layout(mesh,layout,status)
    call require(status == DES_STATUS_OK,'Torsion layout kurulamadı')
    call require(layout%total_equation_count == 27_i64,'Torsion total equation count yanlış')
    allocate(state(27),residual(27),dense(27,27))
    state = 0.0_dp

    do a = 1,8
      X(a,:) = [mesh%nodes(a)%x,mesh%nodes(a)%y]
      u(a,1) = 0.02_dp*X(a,1)
      u(a,2) = -0.01_dp*X(a,2)
      u(a,3) = 0.01_dp*X(a,1)+0.08_dp*X(a,2)
      state(layout%nodal_equations(1,a)) = u(a,1)
      state(layout%nodal_equations(2,a)) = u(a,2)
      state(layout%nodal_equations(3,a)) = u(a,3)
    end do
    p = [-0.3_dp,0.01_dp,-0.02_dp]
    state(layout%pressure_equations(1:3,1)) = p

    call initialize_2d_q8_herrmann_csr_pattern(mesh,layout,tangent,status)
    call require(status == DES_STATUS_OK,'Torsion i64 CSR pattern kurulamadı')
    call assemble_2d_q8_herrmann_csr( &
        mesh,layout,state,2.5_dp,0.02_dp,residual,tangent,status,min_j)
    call require(status == DES_STATUS_OK,'Torsion i64 CSR assembly başarısız')
    call csr_to_dense(tangent,dense,status)
    call require(status == DES_STATUS_OK,'Torsion CSR dense dönüşüm başarısız')

    call evaluate_q8_axisymmetric_torsion_herrmann_reduced_element( &
        X,u,p,2.5_dp,0.02_dp,r_ref,k_ref,status,min_j_ref)
    call require(status == DES_STATUS_OK,'Torsion local reference başarısız')
    call require(maxval(abs(residual-r_ref)) <= 2.0e-13_dp, &
        'Torsion global residual local reference ile uyuşmuyor')
    call require(maxval(abs(dense-k_ref)) <= 2.0e-13_dp, &
        'Torsion CSR tangent local reference ile uyuşmuyor')
    call require(abs(min_j-min_j_ref) <= 1.0e-14_dp,'Torsion global min-J yanlış')
  end subroutine run_axisymmetric_torsion_case

  subroutine build_q8_mesh(mesh,analysis_mode,annular)
    type(mesh_database_2d_t), intent(out) :: mesh
    integer, intent(in) :: analysis_mode
    logical, intent(in) :: annular
    real(dp) :: X(8,2)
    integer :: a
    integer(i64), parameter :: base_id = 3000000000_i64

    if (annular) then
      X(1,:)=[1.0_dp,0.0_dp]; X(2,:)=[2.0_dp,0.0_dp]
      X(3,:)=[2.0_dp,1.0_dp]; X(4,:)=[1.0_dp,1.0_dp]
      X(5,:)=[1.5_dp,0.0_dp]; X(6,:)=[2.0_dp,0.5_dp]
      X(7,:)=[1.5_dp,1.0_dp]; X(8,:)=[1.0_dp,0.5_dp]
    else
      X(1,:)=[0.0_dp,0.0_dp]; X(2,:)=[1.0_dp,0.0_dp]
      X(3,:)=[1.0_dp,1.0_dp]; X(4,:)=[0.0_dp,1.0_dp]
      X(5,:)=[0.5_dp,0.0_dp]; X(6,:)=[1.0_dp,0.5_dp]
      X(7,:)=[0.5_dp,1.0_dp]; X(8,:)=[0.0_dp,0.5_dp]
    end if

    allocate(mesh%nodes(8),mesh%elements(1))
    do a=1,8
      mesh%nodes(a)%id = base_id+int(a,i64)
      mesh%nodes(a)%x = X(a,1)
      mesh%nodes(a)%y = X(a,2)
    end do
    mesh%elements(1)%id = 7000000001_i64
    mesh%elements(1)%topology = DES_TOPOLOGY_Q8
    mesh%elements(1)%analysis_mode = analysis_mode
    mesh%elements(1)%formulation = DES_FORMULATION_MIXED_UP
    mesh%elements(1)%pressure_space = DES_PRESSURE_SPACE_P1
    mesh%elements(1)%element_technology = DES_ELEMENT_TECH_UNIFORM_REDUCED
    mesh%elements(1)%material_id = 1_i64
    mesh%elements(1)%connectivity = [(base_id+int(a,i64),a=1,8)]
  end subroutine build_q8_mesh

  subroutine require(condition,message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) error stop message
  end subroutine require

end program test_2d_q8_herrmann_csr_assembly
