program test_v03_cook_bakeoff_compare
  use, intrinsic :: iso_fortran_env, only : output_unit
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_material_types, only : neo_hookean_parameters_t
  use des_internal_mesh, only : internal_mesh_t, initialize_q4_internal_mesh
  use des_pressure_diagnostics, only : pressure_diagnostics_t, &
                                       evaluate_q4_pressure_diagnostics
  use des_q4_edge_traction, only : Q4_EDGE_RIGHT
  use des_q4_mesh_edge_traction, only : add_q4_reference_edge_traction
  use des_q4_plane_strain_mesh_neo_hookean, only : assemble_q4_plane_strain_mesh
  use des_q4_plane_strain_mixed_up_mesh, only : assemble_q4_plane_strain_mixed_up_mesh
  use des_q4_plane_strain_fbar_mesh, only : assemble_q4_plane_strain_fbar_mesh
  use des_q4_plane_strain_newton_solver, only : newton_report_t
  use des_q4_plane_strain_force_solver, only : solve_q4_plane_strain_force_control
  use des_q4_plane_strain_mixed_up_force_solver, only : &
      solve_q4_plane_strain_mixed_up_force_control
  use des_q4_plane_strain_fbar_force_solver, only : &
      solve_q4_plane_strain_fbar_force_control
  implicit none

  type :: cook_result_t
    integer :: mesh_n = 0
    real(dp) :: tip = 0.0_dp
    real(dp) :: final_min_j = 0.0_dp
    integer :: total_iterations = 0
    integer :: linear_solves = 0
    integer :: equation_count = 0
    real(dp) :: pressure_mean = 0.0_dp
    real(dp) :: pressure_std = 0.0_dp
    real(dp) :: pressure_rms = 0.0_dp
    real(dp) :: pressure_jump_rms = 0.0_dp
    real(dp) :: pressure_graph_roughness = 0.0_dp
    real(dp) :: min_j_bar = 0.0_dp
    real(dp) :: max_j_bar = 0.0_dp
  end type cook_result_t

  integer, parameter :: mesh_sizes(3) = [2,4,8]
  type(cook_result_t) :: displacement(3), mixed(3), fbar(3)
  real(dp) :: gap_displacement, gap_mixed, gap_fbar
  integer :: k, json_unit, ios

  do k = 1,3
    call run_displacement_case(mesh_sizes(k),displacement(k))
    call run_mixed_case(mesh_sizes(k),mixed(k))
    call run_fbar_case(mesh_sizes(k),fbar(k))
  end do

  call validate_results(displacement,mixed,fbar)

  gap_displacement = 1.0_dp-displacement(1)%tip/displacement(3)%tip
  gap_mixed = 1.0_dp-mixed(1)%tip/mixed(3)%tip
  gap_fbar = 1.0_dp-fbar(1)%tip/fbar(3)%tip

  write(*,'(A)') 'V0.3 Cook formulation bake-off karşılaştırması'
  write(*,'(A)') 'mesh       displacement          mixed Q4/P0              F-bar'
  do k = 1,3
    write(*,'(I2,A,3(3X,ES18.10))') mesh_sizes(k), &
      'x'//trim(to_string(mesh_sizes(k))), &
      displacement(k)%tip,mixed(k)%tip,fbar(k)%tip
  end do
  write(*,'(A,3(3X,F10.4,A))') 'coarse-to-8x8 gap:', &
      100.0_dp*gap_displacement,' %',100.0_dp*gap_mixed,' %', &
      100.0_dp*gap_fbar,' %'

  write(*,'(A)') '--- Mixed pressure roughness ---'
  do k = 1,3
    write(*,'(I0,A,3(A,ES14.6))') mesh_sizes(k), &
      'x'//trim(to_string(mesh_sizes(k))), &
      ' mean=',mixed(k)%pressure_mean, &
      ' std=',mixed(k)%pressure_std, &
      ' graph=',mixed(k)%pressure_graph_roughness
  end do

  write(*,'(A)') '--- Solver equation counts ---'
  do k = 1,3
    write(*,'(I0,A,3(A,I0))') mesh_sizes(k), &
      'x'//trim(to_string(mesh_sizes(k))), &
      ' displacement=',displacement(k)%equation_count, &
      ' mixed=',mixed(k)%equation_count, &
      ' fbar=',fbar(k)%equation_count
  end do

  ! CTest stdout'u makine-okunur bir JSON bloğu taşır. Aynı içerik build
  ! dizinine de yazılır; CI artifact toplama açıldığında doğrudan alınabilir.
  write(*,'(A)') 'V03_BAKEOFF_JSON_BEGIN'
  call write_json(output_unit,displacement,mixed,fbar, &
                  gap_displacement,gap_mixed,gap_fbar)
  write(*,'(A)') 'V03_BAKEOFF_JSON_END'

  open(newunit=json_unit,file='V0.3_COOK_BAKEOFF_RESULTS.json', &
       status='replace',action='write',iostat=ios)
  if (ios /= 0) error stop 'V0.3 bake-off JSON dosyası açılamadı.'
  call write_json(json_unit,displacement,mixed,fbar, &
                  gap_displacement,gap_mixed,gap_fbar)
  close(json_unit)

  write(*,'(A)') 'V0.3 birleşik Cook bake-off testi BASARILI.'

contains

  subroutine validate_results(d,m,f)
    type(cook_result_t), intent(in) :: d(3),m(3),f(3)
    integer :: i

    do i = 1,3
      if (d(i)%tip <= 0.0_dp .or. m(i)%tip <= 0.0_dp .or. f(i)%tip <= 0.0_dp) then
        error stop 'Bake-off tip displacement pozitiflik kontrolü başarısız.'
      end if
      if (d(i)%final_min_j <= 0.0_dp .or. m(i)%final_min_j <= 0.0_dp .or. &
          f(i)%final_min_j <= 0.0_dp) then
        error stop 'Bake-off final J pozitiflik kontrolü başarısız.'
      end if
      if (d(i)%equation_count <= 0 .or. m(i)%equation_count <= 0 .or. &
          f(i)%equation_count <= 0) then
        error stop 'Bake-off lineer solver equation-count diagnostics eksik.'
      end if
      if (m(i)%pressure_graph_roughness < 0.0_dp) then
        error stop 'Mixed pressure graph roughness negatif olamaz.'
      end if
      if (f(i)%min_j_bar <= 0.0_dp .or. f(i)%max_j_bar < f(i)%min_j_bar) then
        error stop 'F-bar J_bar aralığı geçersiz.'
      end if
    end do

    ! Her formulation kendi içinde aynı mesh-refinement yönünü göstermelidir.
    if (.not. (d(1)%tip < d(2)%tip .and. d(2)%tip < d(3)%tip)) then
      error stop 'Displacement Q4 mesh-refinement sıralaması bozuldu.'
    end if
    if (.not. (m(1)%tip < m(2)%tip .and. m(2)%tip < m(3)%tip)) then
      error stop 'Mixed Q4/P0 mesh-refinement sıralaması bozuldu.'
    end if
    if (.not. (f(1)%tip < f(2)%tip .and. f(2)%tip < f(3)%tip)) then
      error stop 'F-bar mesh-refinement sıralaması bozuldu.'
    end if

    ! Mixed formulation her element için ek bir pressure DOF taşıdığı için
    ! lineer sistem displacement-only/F-bar sisteminden büyük olmalıdır.
    do i = 1,3
      if (m(i)%equation_count <= d(i)%equation_count) then
        error stop 'Mixed Q4/P0 beklenen ek pressure DOF maliyetini göstermedi.'
      end if
    end do
  end subroutine validate_results

  subroutine run_displacement_case(n,result)
    integer, intent(in) :: n
    type(cook_result_t), intent(out) :: result
    real(dp), allocatable :: X(:,:),u(:,:),residual(:),external_force(:),tangent(:,:)
    integer, allocatable :: connectivity(:,:),fixed_dofs(:)
    type(neo_hookean_parameters_t) :: p
    type(newton_report_t) :: report
    integer :: nnode,ndof,status,tip_node

    call prepare_problem(n,X,connectivity,fixed_dofs,external_force)
    nnode = size(X,1)
    ndof = 2*nnode
    allocate(u(nnode,2),residual(ndof),tangent(ndof,ndof))
    u = 0.0_dp
    p%mu = 1.0_dp
    p%lambda = 1000.0_dp

    call solve_q4_plane_strain_force_control( &
        X,connectivity,p,fixed_dofs,external_force, &
        5,30,1.0e-9_dp,u,residual,report)
    if (.not. report%converged .or. report%status /= DES_STATUS_OK) then
      error stop 'Birleşik bake-off displacement Q4 yakınsamadı.'
    end if

    tip_node = midpoint_tip_node(n)
    result%mesh_n = n
    result%tip = u(tip_node,2)
    call assemble_q4_plane_strain_mesh( &
        X,connectivity,u,p,residual,tangent,status,result%final_min_j)
    if (status /= DES_STATUS_OK) error stop 'Displacement final-state assembly başarısız.'
    call copy_solver_metrics(report,result)
  end subroutine run_displacement_case

  subroutine run_mixed_case(n,result)
    integer, intent(in) :: n
    type(cook_result_t), intent(out) :: result
    real(dp), allocatable :: X(:,:),u(:,:),pressure(:),residual(:)
    real(dp), allocatable :: external_force(:),tangent(:,:)
    integer, allocatable :: connectivity(:,:),fixed_dofs(:)
    type(neo_hookean_parameters_t) :: p
    type(newton_report_t) :: report
    type(pressure_diagnostics_t) :: pd
    integer :: nnode,nelem,ndisp,ntotal,status,tip_node

    call prepare_problem(n,X,connectivity,fixed_dofs,external_force)
    nnode = size(X,1)
    nelem = size(connectivity,1)
    ndisp = 2*nnode
    ntotal = ndisp+nelem
    allocate(u(nnode,2),pressure(nelem),residual(ntotal),tangent(ntotal,ntotal))
    u = 0.0_dp
    pressure = 0.0_dp
    p%mu = 1.0_dp
    p%lambda = 1000.0_dp

    call solve_q4_plane_strain_mixed_up_force_control( &
        X,connectivity,p,fixed_dofs,external_force,5,30,1.0e-9_dp, &
        u,pressure,residual,report)
    if (.not. report%converged .or. report%status /= DES_STATUS_OK) then
      error stop 'Birleşik bake-off mixed Q4/P0 yakınsamadı.'
    end if

    tip_node = midpoint_tip_node(n)
    result%mesh_n = n
    result%tip = u(tip_node,2)
    call assemble_q4_plane_strain_mixed_up_mesh( &
        X,connectivity,u,pressure,p,residual,tangent,status,result%final_min_j)
    if (status /= DES_STATUS_OK) error stop 'Mixed final-state assembly başarısız.'
    call evaluate_q4_pressure_diagnostics(connectivity,pressure,pd,status)
    if (status /= DES_STATUS_OK .or. .not. pd%valid) then
      error stop 'Mixed pressure diagnostics başarısız.'
    end if
    call copy_solver_metrics(report,result)
    result%pressure_mean = pd%mean
    result%pressure_std = pd%standard_deviation
    result%pressure_rms = pd%rms
    result%pressure_jump_rms = pd%neighbor_jump_rms
    result%pressure_graph_roughness = pd%graph_roughness
  end subroutine run_mixed_case

  subroutine run_fbar_case(n,result)
    integer, intent(in) :: n
    type(cook_result_t), intent(out) :: result
    real(dp), allocatable :: X(:,:),u(:,:),residual(:),external_force(:),tangent(:,:)
    integer, allocatable :: connectivity(:,:),fixed_dofs(:)
    type(neo_hookean_parameters_t) :: p
    type(newton_report_t) :: report
    integer :: nnode,ndof,status,tip_node

    call prepare_problem(n,X,connectivity,fixed_dofs,external_force)
    nnode = size(X,1)
    ndof = 2*nnode
    allocate(u(nnode,2),residual(ndof),tangent(ndof,ndof))
    u = 0.0_dp
    p%mu = 1.0_dp
    p%lambda = 1000.0_dp

    call solve_q4_plane_strain_fbar_force_control( &
        X,connectivity,p,fixed_dofs,external_force, &
        5,35,2.0e-8_dp,u,residual,report)
    if (.not. report%converged .or. report%status /= DES_STATUS_OK) then
      error stop 'Birleşik bake-off F-bar yakınsamadı.'
    end if

    tip_node = midpoint_tip_node(n)
    result%mesh_n = n
    result%tip = u(tip_node,2)
    call assemble_q4_plane_strain_fbar_mesh( &
        X,connectivity,u,p,residual,tangent,status,result%final_min_j, &
        result%min_j_bar,result%max_j_bar)
    if (status /= DES_STATUS_OK) error stop 'F-bar final-state assembly başarısız.'
    call copy_solver_metrics(report,result)
  end subroutine run_fbar_case

  subroutine copy_solver_metrics(report,result)
    type(newton_report_t), intent(in) :: report
    type(cook_result_t), intent(inout) :: result
    result%total_iterations = report%total_iterations
    result%linear_solves = report%linear_solve_count
    result%equation_count = report%max_linear_equation_count
  end subroutine copy_solver_metrics

  subroutine prepare_problem(n,X,connectivity,fixed_dofs,external_force)
    integer, intent(in) :: n
    real(dp), allocatable, intent(out) :: X(:,:),external_force(:)
    integer, allocatable, intent(out) :: connectivity(:,:),fixed_dofs(:)
    type(internal_mesh_t) :: mesh
    real(dp) :: traction(2),edge_length
    integer :: j,node,element_id,cursor,status,nnode

    call build_cook_mesh(n,n,X,connectivity)
    nnode = size(X,1)
    allocate(fixed_dofs(2*(n+1)),external_force(2*nnode))
    external_force = 0.0_dp

    call initialize_q4_internal_mesh(mesh,X,connectivity,status)
    if (status /= DES_STATUS_OK) error stop 'Birleşik Cook InternalMesh oluşturulamadı.'

    cursor = 0
    do j = 0,n
      node = 1+j*(n+1)
      cursor = cursor+1
      fixed_dofs(cursor) = 2*node-1
      cursor = cursor+1
      fixed_dofs(cursor) = 2*node
    end do

    traction = [0.0_dp,0.01_dp]
    do j = 0,n-1
      element_id = j*n+n
      call add_q4_reference_edge_traction( &
          mesh,element_id,Q4_EDGE_RIGHT,traction, &
          external_force,status,edge_length)
      if (status /= DES_STATUS_OK .or. edge_length <= 0.0_dp) then
        error stop 'Birleşik Cook sağ sınır traction assembly başarısız.'
      end if
    end do
  end subroutine prepare_problem

  integer function midpoint_tip_node(n) result(node)
    integer, intent(in) :: n
    node = 1+(n/2)*(n+1)+n
  end function midpoint_tip_node

  subroutine build_cook_mesh(nx,ny,X,connectivity)
    integer, intent(in) :: nx,ny
    real(dp), allocatable, intent(out) :: X(:,:)
    integer, allocatable, intent(out) :: connectivity(:,:)
    real(dp), parameter :: y_right_bottom = 44.0_dp/48.0_dp
    real(dp), parameter :: y_right_top = 60.0_dp/48.0_dp
    real(dp), parameter :: y_left_top = 44.0_dp/48.0_dp
    real(dp) :: s,t,left_y,right_y
    integer :: i,j,node,e,n1,n2,n3,n4

    allocate(X((nx+1)*(ny+1),2),connectivity(nx*ny,4))
    do j = 0,ny
      t = real(j,dp)/real(ny,dp)
      left_y = t*y_left_top
      right_y = (1.0_dp-t)*y_right_bottom+t*y_right_top
      do i = 0,nx
        s = real(i,dp)/real(nx,dp)
        node = 1+j*(nx+1)+i
        X(node,1) = s
        X(node,2) = (1.0_dp-s)*left_y+s*right_y
      end do
    end do

    e = 0
    do j = 0,ny-1
      do i = 0,nx-1
        n1 = 1+j*(nx+1)+i
        n2 = n1+1
        n4 = n1+(nx+1)
        n3 = n4+1
        e = e+1
        connectivity(e,:) = [n1,n2,n3,n4]
      end do
    end do
  end subroutine build_cook_mesh

  subroutine write_json(unit,d,m,f,gap_d,gap_m,gap_f)
    integer, intent(in) :: unit
    type(cook_result_t), intent(in) :: d(3),m(3),f(3)
    real(dp), intent(in) :: gap_d,gap_m,gap_f

    write(unit,'(A)') '{'
    write(unit,'(A)') '  "schema_version": 3,'
    write(unit,'(A)') '  "problem": "V0.3 normalized Cook plane-strain bake-off",'
    write(unit,'(A)') '  "material": {"mu": 1.0, "lambda": 1000.0},'
    write(unit,'(A)') '  "traction_y": 0.01,'
    write(unit,'(A)') '  "formulations": {'
    call write_formulation_json(unit,'displacement_q4',d,gap_d,.true.)
    call write_formulation_json(unit,'mixed_q4_p0',m,gap_m,.true.)
    call write_formulation_json(unit,'fbar_q4',f,gap_f,.false.)
    write(unit,'(A)') '  }'
    write(unit,'(A)') '}'
  end subroutine write_json

  subroutine write_formulation_json(unit,name,r,gap,comma_after)
    integer, intent(in) :: unit
    character(len=*), intent(in) :: name
    type(cook_result_t), intent(in) :: r(3)
    real(dp), intent(in) :: gap
    logical, intent(in) :: comma_after
    integer :: i

    write(unit,'(A,A,A)') '    "',trim(name),'": {'
    write(unit,'(A,ES24.16E3,A)') '      "coarse_to_8x8_gap": ',gap,','
    write(unit,'(A)') '      "meshes": ['
    do i = 1,3
      write(unit,'(A)') '        {'
      write(unit,'(A,I0,A)') '          "n": ',r(i)%mesh_n,','
      write(unit,'(A,ES24.16E3,A)') '          "tip": ',r(i)%tip,','
      write(unit,'(A,ES24.16E3,A)') &
        '          "final_min_j": ',r(i)%final_min_j,','
      write(unit,'(A,I0,A)') &
        '          "iterations": ',r(i)%total_iterations,','
      write(unit,'(A,I0,A)') &
        '          "linear_solves": ',r(i)%linear_solves,','
      write(unit,'(A,I0,A)') &
        '          "equations": ',r(i)%equation_count,','
      write(unit,'(A,ES24.16E3,A)') &
        '          "pressure_mean": ',r(i)%pressure_mean,','
      write(unit,'(A,ES24.16E3,A)') &
        '          "pressure_std": ',r(i)%pressure_std,','
      write(unit,'(A,ES24.16E3,A)') &
        '          "pressure_rms": ',r(i)%pressure_rms,','
      write(unit,'(A,ES24.16E3,A)') &
        '          "pressure_jump_rms": ',r(i)%pressure_jump_rms,','
      write(unit,'(A,ES24.16E3,A)') &
        '          "pressure_graph_roughness": ', &
        r(i)%pressure_graph_roughness,','
      write(unit,'(A,ES24.16E3,A)') &
        '          "min_j_bar": ',r(i)%min_j_bar,','
      write(unit,'(A,ES24.16E3)') &
        '          "max_j_bar": ',r(i)%max_j_bar
      if (i < 3) then
        write(unit,'(A)') '        },'
      else
        write(unit,'(A)') '        }'
      end if
    end do
    write(unit,'(A)') '      ]'
    if (comma_after) then
      write(unit,'(A)') '    },'
    else
      write(unit,'(A)') '    }'
    end if
  end subroutine write_formulation_json

  function to_string(value) result(text)
    integer, intent(in) :: value
    character(len=16) :: text
    write(text,'(I0)') value
  end function to_string

end program test_v03_cook_bakeoff_compare
