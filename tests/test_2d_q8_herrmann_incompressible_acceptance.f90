program test_2d_q8_herrmann_incompressible_acceptance
  use des_kinds, only : dp, i64
  use des_status, only : DES_STATUS_OK
  use des_2d_analysis_contract, only : DES_2D_PLANE_STRAIN, DES_2D_AXISYMMETRIC, &
      DES_TOPOLOGY_Q8, DES_FORMULATION_MIXED_UP, DES_PRESSURE_SPACE_P1, &
      DES_ELEMENT_TECH_UNIFORM_REDUCED
  use des_2d_mesh_database, only : mesh_database_2d_t
  use des_2d_dof_manager, only : dof_layout_2d_t, build_2d_dof_layout
  use des_2d_q8_herrmann_assembly, only : initialize_2d_q8_herrmann_csr_pattern, &
      assemble_2d_q8_herrmann_csr
  use des_q8_herrmann_geometry, only : q8_reference_gradient
  use des_csr_matrix, only : csr_matrix_t, csr_to_dense
  use des_linear_solver, only : linear_solver_settings_t, &
      DES_LINEAR_BACKEND_STDLIB_CSR_GMRES, DES_LINEAR_BACKEND_MUMPS_DIRECT
  use des_q4_plane_strain_newton_solver, only : newton_report_t
  use des_2d_q8_herrmann_force_solver, only : solve_2d_q8_herrmann_force_control
  implicit none

  integer :: backend
  character(len=32) :: backend_argument

  backend = DES_LINEAR_BACKEND_STDLIB_CSR_GMRES
  if (command_argument_count() > 0) then
    call get_command_argument(1,backend_argument)
    select case (trim(backend_argument))
    case ('mumps')
      backend = DES_LINEAR_BACKEND_MUMPS_DIRECT
    case ('gmres')
      backend = DES_LINEAR_BACKEND_STDLIB_CSR_GMRES
    case default
      error stop 'Q8 incompressible acceptance bilinmeyen backend argumani.'
    end select
  end if

  call run_distorted_plane_strain_case(backend)
  call run_axisymmetric_case(backend)

  write(*,'(A)') 'PASS: Q8/P1 cp=0 plane-strain + axisymmetric production acceptance'

contains

  subroutine run_distorted_plane_strain_case(active_backend)
    integer, intent(in) :: active_backend
    type(mesh_database_2d_t) :: mesh
    type(dof_layout_2d_t) :: layout
    type(csr_matrix_t) :: tangent
    type(newton_report_t) :: report
    type(linear_solver_settings_t) :: settings
    real(dp), allocatable :: target_state(:),state(:),target_residual(:),residual(:)
    real(dp), allocatable :: external_load(:),dense(:,:),coupling(:,:)
    integer(i64), allocatable :: fixed(:),free(:),pressure_rows(:)
    real(dp) :: lambda_x,lambda_y,min_j,state_error,pressure_error,spread
    integer :: status,i,e,cursor,rank_value

    call build_distorted_plane_mesh(mesh)
    call build_2d_dof_layout(mesh,layout,status)
    call require(status == DES_STATUS_OK,'Distorted plane-strain Q8 DOF layout kurulamadı')
    call require(layout%total_equation_count == 54_i64, &
        'Distorted 2x2 Q8/P1 plane-strain 54 equation bekliyor')
    ! Büyük external mesh ID'leri i64 mesh kimliğini doğrular. Bu kontrol solver
    ! equation-index capability'sini büyütülmüş saymaz; o sınır ayrı tutulur.
    call require(mesh%nodes(1)%id > 2147483647_i64, &
        'Yeni mesh database i64 external node ID gate kullanmıyor')

    allocate(target_state(layout%total_equation_count),state(layout%total_equation_count))
    allocate(target_residual(layout%total_equation_count),residual(layout%total_equation_count))
    allocate(external_load(layout%total_equation_count))
    allocate(pressure_rows(layout%pressure_equation_count))
    target_state = 0.0_dp

    lambda_x = 1.08_dp
    lambda_y = 1.0_dp/lambda_x
    do i = 1,size(mesh%nodes)
      target_state(layout%nodal_equations(1,i)) = &
          (lambda_x-1.0_dp)*mesh%nodes(i)%x
      target_state(layout%nodal_equations(2,i)) = &
          (lambda_y-1.0_dp)*mesh%nodes(i)%y
    end do

    cursor = 0
    do e = 1,size(mesh%elements)
      target_state(layout%pressure_equations(1,e)) = 0.10_dp+0.015_dp*real(e,dp)
      if (mod(e,2) == 0) then
        target_state(layout%pressure_equations(2,e)) = 0.012_dp
      else
        target_state(layout%pressure_equations(2,e)) = -0.012_dp
      end if
      target_state(layout%pressure_equations(3,e)) = -0.006_dp*real(e,dp)
      do i = 1,3
        cursor = cursor+1
        pressure_rows(cursor) = layout%pressure_equations(i,e)
      end do
    end do

    allocate(fixed(3))
    fixed = [layout%nodal_equations(1,1),layout%nodal_equations(2,1), &
             layout%nodal_equations(2,5)]
    call require(maxval(abs(target_state(fixed))) <= 1.0e-15_dp, &
        'Plane-strain manufactured state fixed equation ile uyumsuz')
    call build_free_equations(layout%total_equation_count,fixed,free)

    call initialize_2d_q8_herrmann_csr_pattern(mesh,layout,tangent,status)
    call require(status == DES_STATUS_OK,'Distorted plane-strain CSR graph kurulamadı')
    call assemble_2d_q8_herrmann_csr( &
        mesh,layout,target_state,2.5_dp,0.0_dp,target_residual,tangent,status,min_j)
    call require(status == DES_STATUS_OK,'Distorted plane-strain cp=0 target assemble edilemedi')
    call require(abs(min_j-1.0_dp) <= 2.0e-12_dp, &
        'Distorted plane-strain manufactured state J=1 değil')
    call require(maxval(abs(target_residual(pressure_rows))) <= 2.0e-11_dp, &
        'Distorted plane-strain cp=0 pressure residual sıfır değil')

    allocate(dense(layout%total_equation_count,layout%total_equation_count))
    call csr_to_dense(tangent,dense,status)
    call require(status == DES_STATUS_OK,'Distorted plane-strain CSR dense diagnostic başarısız')
    call require(maxval(abs(dense(pressure_rows,pressure_rows))) <= 1.0e-13_dp, &
        'Distorted plane-strain fully incompressible Kpp sıfır değil')

    allocate(coupling(layout%pressure_equation_count,layout%nodal_equation_count))
    coupling = dense(pressure_rows,1:layout%nodal_equation_count)
    coupling(:,fixed) = 0.0_dp
    rank_value = numerical_row_rank(coupling,1.0e-11_dp)
    call require(rank_value == int(layout%pressure_equation_count), &
        'Distorted plane-strain global pressure coupling full-row-rank değil')

    call measure_plane_distortion(mesh,spread,status)
    call require(status == DES_STATUS_OK,'Distorted Q8 geometry metric üretilemedi')
    call require(spread >= 4.0_dp,'Plane-strain acceptance yeterli mesh distortion içermiyor')

    external_load = target_residual
    external_load(fixed) = 0.0_dp
    external_load(pressure_rows) = 0.0_dp
    call configure_sparse_settings(settings,active_backend,int(layout%total_equation_count))

    state = 0.0_dp
    call solve_2d_q8_herrmann_force_control( &
        mesh,layout,2.5_dp,0.0_dp,fixed,external_load,5,45,1.0e-9_dp, &
        state,residual,report,linear_settings=settings)
    call require(report%status == DES_STATUS_OK .and. report%converged, &
        'Distorted plane-strain cp=0 sparse Newton yakinsamadi')
    call require(abs(report%final_load_factor-1.0_dp) <= 1.0e-14_dp, &
        'Distorted plane-strain final load factor 1 değil')
    call require(report%last_linear_report%pattern_analysis_count == 1, &
        'Distorted plane-strain CSR pattern birden fazla analyze edildi')
    call require(report%last_linear_report%reorder_count == 1, &
        'Distorted plane-strain ordering birden fazla çalıştı')
    call require(report%last_linear_report%backend == active_backend, &
        'Distorted plane-strain backend raporu seçimle uyuşmuyor')

    state_error = maxval(abs(state(free)-target_state(free)))
    pressure_error = maxval(abs(state(pressure_rows)-target_state(pressure_rows)))
    call require(state_error <= 2.0e-6_dp, &
        'Distorted plane-strain cp=0 manufactured state kurtarılamadı')
    call require(pressure_error <= 2.0e-6_dp, &
        'Distorted plane-strain P1 pressure mode recovery toleransı aşıldı')
    call require(maxval(abs(residual(free))) <= 2.0e-8_dp, &
        'Distorted plane-strain final free residual toleransı aşıldı')

    call assemble_2d_q8_herrmann_csr( &
        mesh,layout,state,2.5_dp,0.0_dp,residual,tangent,status,min_j)
    call require(status == DES_STATUS_OK,'Distorted plane-strain final state assemble edilemedi')
    call require(abs(min_j-1.0_dp) <= 2.0e-6_dp, &
        'Distorted plane-strain final state incompressibility kaybetti')

    write(*,'(A,ES14.6)') 'Q8 distorted plane Jacobian spread = ',spread
    write(*,'(A,I0,A,I0)') 'Q8 distorted plane pressure rank = ',rank_value,' / ', &
        int(layout%pressure_equation_count)
    write(*,'(A,ES14.6)') 'Q8 distorted plane state max error = ',state_error
    write(*,'(A,ES14.6)') 'Q8 distorted plane pressure max error = ',pressure_error
  end subroutine run_distorted_plane_strain_case

  subroutine run_axisymmetric_case(active_backend)
    integer, intent(in) :: active_backend
    type(mesh_database_2d_t) :: mesh
    type(dof_layout_2d_t) :: layout
    type(csr_matrix_t) :: tangent
    type(newton_report_t) :: report
    type(linear_solver_settings_t) :: settings
    real(dp), allocatable :: target_state(:),state(:),target_residual(:),residual(:)
    real(dp), allocatable :: external_load(:),dense(:,:),coupling(:,:)
    integer(i64), allocatable :: fixed(:),free(:),pressure_rows(:)
    real(dp) :: lambda_r,lambda_z,min_j,state_error,pressure_error
    integer :: status,i,rank_value

    call build_axisymmetric_mesh(mesh)
    call build_2d_dof_layout(mesh,layout,status)
    call require(status == DES_STATUS_OK,'Axisymmetric Q8 DOF layout kurulamadı')
    call require(layout%total_equation_count == 19_i64, &
        'Axisymmetric Q8/P1 tek eleman 19 equation bekliyor')

    allocate(target_state(layout%total_equation_count),state(layout%total_equation_count))
    allocate(target_residual(layout%total_equation_count),residual(layout%total_equation_count))
    allocate(external_load(layout%total_equation_count),pressure_rows(3))
    target_state = 0.0_dp

    lambda_r = 1.04_dp
    lambda_z = 1.0_dp/(lambda_r*lambda_r)
    do i = 1,size(mesh%nodes)
      target_state(layout%nodal_equations(1,i)) = &
          (lambda_r-1.0_dp)*mesh%nodes(i)%x
      target_state(layout%nodal_equations(2,i)) = &
          (lambda_z-1.0_dp)*mesh%nodes(i)%y
    end do
    target_state(layout%pressure_equations(1,1)) = 0.16_dp
    target_state(layout%pressure_equations(2,1)) = 0.025_dp
    target_state(layout%pressure_equations(3,1)) = -0.018_dp
    pressure_rows = layout%pressure_equations(1:3,1)

    allocate(fixed(3))
    fixed = [layout%nodal_equations(2,1),layout%nodal_equations(2,2), &
             layout%nodal_equations(2,5)]
    call require(maxval(abs(target_state(fixed))) <= 1.0e-15_dp, &
        'Axisymmetric manufactured state fixed equation ile uyumsuz')
    call build_free_equations(layout%total_equation_count,fixed,free)

    call initialize_2d_q8_herrmann_csr_pattern(mesh,layout,tangent,status)
    call require(status == DES_STATUS_OK,'Axisymmetric Q8 CSR graph kurulamadı')
    call assemble_2d_q8_herrmann_csr( &
        mesh,layout,target_state,2.5_dp,0.0_dp,target_residual,tangent,status,min_j)
    call require(status == DES_STATUS_OK,'Axisymmetric Q8 cp=0 target assemble edilemedi')
    call require(abs(min_j-1.0_dp) <= 2.0e-12_dp, &
        'Axisymmetric manufactured state J=1 değil')
    call require(maxval(abs(target_residual(pressure_rows))) <= 2.0e-11_dp, &
        'Axisymmetric cp=0 pressure residual sıfır değil')

    allocate(dense(layout%total_equation_count,layout%total_equation_count))
    call csr_to_dense(tangent,dense,status)
    call require(status == DES_STATUS_OK,'Axisymmetric CSR dense diagnostic başarısız')
    call require(maxval(abs(dense(pressure_rows,pressure_rows))) <= 1.0e-13_dp, &
        'Axisymmetric fully incompressible Kpp sıfır değil')

    allocate(coupling(3,layout%nodal_equation_count))
    coupling = dense(pressure_rows,1:layout%nodal_equation_count)
    coupling(:,fixed) = 0.0_dp
    rank_value = numerical_row_rank(coupling,1.0e-11_dp)
    call require(rank_value == 3,'Axisymmetric pressure coupling full-row-rank değil')

    external_load = target_residual
    external_load(fixed) = 0.0_dp
    external_load(pressure_rows) = 0.0_dp
    call configure_sparse_settings(settings,active_backend,int(layout%total_equation_count))

    state = 0.0_dp
    call solve_2d_q8_herrmann_force_control( &
        mesh,layout,2.5_dp,0.0_dp,fixed,external_load,5,45,1.0e-9_dp, &
        state,residual,report,linear_settings=settings)
    call require(report%status == DES_STATUS_OK .and. report%converged, &
        'Axisymmetric Q8 cp=0 sparse Newton yakinsamadi')
    call require(report%last_linear_report%pattern_analysis_count == 1, &
        'Axisymmetric Q8 CSR pattern birden fazla analyze edildi')
    call require(report%last_linear_report%reorder_count == 1, &
        'Axisymmetric Q8 ordering birden fazla çalıştı')
    call require(report%last_linear_report%backend == active_backend, &
        'Axisymmetric Q8 backend raporu seçimle uyuşmuyor')

    state_error = maxval(abs(state(free)-target_state(free)))
    pressure_error = maxval(abs(state(pressure_rows)-target_state(pressure_rows)))
    call require(state_error <= 2.0e-6_dp, &
        'Axisymmetric cp=0 manufactured state kurtarılamadı')
    call require(pressure_error <= 2.0e-6_dp, &
        'Axisymmetric P1 pressure mode recovery toleransı aşıldı')
    call require(maxval(abs(residual(free))) <= 2.0e-8_dp, &
        'Axisymmetric cp=0 final free residual toleransı aşıldı')

    call assemble_2d_q8_herrmann_csr( &
        mesh,layout,state,2.5_dp,0.0_dp,residual,tangent,status,min_j)
    call require(status == DES_STATUS_OK,'Axisymmetric final state assemble edilemedi')
    call require(abs(min_j-1.0_dp) <= 2.0e-6_dp, &
        'Axisymmetric final state incompressibility kaybetti')

    write(*,'(A,I0,A,I0)') 'Q8 axisymmetric pressure rank = ',rank_value,' / ',3
    write(*,'(A,ES14.6)') 'Q8 axisymmetric state max error = ',state_error
    write(*,'(A,ES14.6)') 'Q8 axisymmetric pressure max error = ',pressure_error
  end subroutine run_axisymmetric_case

  subroutine build_distorted_plane_mesh(mesh)
    type(mesh_database_2d_t), intent(out) :: mesh
    integer, parameter :: nnode = 21, nelem = 4
    real(dp) :: coords(nnode,2)
    integer :: conn(nelem,8),i,e
    integer(i64) :: ids(nnode)

    coords(1,:)  = [0.00_dp, 0.00_dp]
    coords(2,:)  = [0.46_dp,-0.03_dp]
    coords(3,:)  = [0.98_dp, 0.04_dp]
    coords(4,:)  = [1.48_dp,-0.02_dp]
    coords(5,:)  = [2.00_dp, 0.00_dp]
    coords(6,:)  = [0.00_dp, 0.47_dp]
    coords(7,:)  = [0.93_dp, 0.59_dp]
    coords(8,:)  = [1.97_dp, 0.56_dp]
    coords(9,:)  = [0.00_dp, 0.98_dp]
    coords(10,:) = [0.53_dp, 1.07_dp]
    coords(11,:) = [1.14_dp, 0.91_dp]
    coords(12,:) = [1.43_dp, 1.08_dp]
    coords(13,:) = [1.94_dp, 1.03_dp]
    coords(14,:) = [0.00_dp, 1.56_dp]
    coords(15,:) = [0.91_dp, 1.43_dp]
    coords(16,:) = [1.96_dp, 1.48_dp]
    coords(17,:) = [0.00_dp, 2.00_dp]
    coords(18,:) = [0.47_dp, 1.98_dp]
    coords(19,:) = [1.07_dp, 2.01_dp]
    coords(20,:) = [1.56_dp, 1.95_dp]
    coords(21,:) = [2.00_dp, 2.00_dp]

    conn(1,:) = [1,3,11,9,2,7,10,6]
    conn(2,:) = [3,5,13,11,4,8,12,7]
    conn(3,:) = [9,11,19,17,10,15,18,14]
    conn(4,:) = [11,13,21,19,12,16,20,15]

    allocate(mesh%nodes(nnode),mesh%elements(nelem))
    do i = 1,nnode
      ids(i) = 3000000000_i64+17_i64*int(i,i64)
      mesh%nodes(i)%id = ids(i)
      mesh%nodes(i)%x = coords(i,1)
      mesh%nodes(i)%y = coords(i,2)
    end do

    do e = 1,nelem
      mesh%elements(e)%id = 5000000000_i64+int(e,i64)
      mesh%elements(e)%topology = DES_TOPOLOGY_Q8
      mesh%elements(e)%analysis_mode = DES_2D_PLANE_STRAIN
      mesh%elements(e)%formulation = DES_FORMULATION_MIXED_UP
      mesh%elements(e)%pressure_space = DES_PRESSURE_SPACE_P1
      mesh%elements(e)%element_technology = DES_ELEMENT_TECH_UNIFORM_REDUCED
      mesh%elements(e)%material_id = 7000000001_i64
      mesh%elements(e)%connectivity = ids(conn(e,:))
    end do
  end subroutine build_distorted_plane_mesh

  subroutine build_axisymmetric_mesh(mesh)
    type(mesh_database_2d_t), intent(out) :: mesh
    real(dp) :: coords(8,2)
    integer :: i
    integer(i64) :: ids(8)

    coords(1,:) = [1.00_dp,0.00_dp]
    coords(2,:) = [2.20_dp,0.00_dp]
    coords(3,:) = [2.05_dp,1.00_dp]
    coords(4,:) = [1.08_dp,0.86_dp]
    coords(5,:) = [1.60_dp,0.00_dp]
    coords(6,:) = [2.125_dp,0.50_dp]
    coords(7,:) = [1.565_dp,0.93_dp]
    coords(8,:) = [1.04_dp,0.43_dp]

    allocate(mesh%nodes(8),mesh%elements(1))
    do i = 1,8
      ids(i) = 4000000000_i64+23_i64*int(i,i64)
      mesh%nodes(i)%id = ids(i)
      mesh%nodes(i)%x = coords(i,1)
      mesh%nodes(i)%y = coords(i,2)
    end do

    mesh%elements(1)%id = 6000000001_i64
    mesh%elements(1)%topology = DES_TOPOLOGY_Q8
    mesh%elements(1)%analysis_mode = DES_2D_AXISYMMETRIC
    mesh%elements(1)%formulation = DES_FORMULATION_MIXED_UP
    mesh%elements(1)%pressure_space = DES_PRESSURE_SPACE_P1
    mesh%elements(1)%element_technology = DES_ELEMENT_TECH_UNIFORM_REDUCED
    mesh%elements(1)%material_id = 7000000002_i64
    mesh%elements(1)%connectivity = ids
  end subroutine build_axisymmetric_mesh

  subroutine configure_sparse_settings(settings,active_backend,dimension)
    type(linear_solver_settings_t), intent(out) :: settings
    integer, intent(in) :: active_backend,dimension

    settings = linear_solver_settings_t()
    settings%backend = active_backend
    settings%relative_tolerance = 1.0e-11_dp
    settings%absolute_tolerance = 1.0e-12_dp
    settings%max_iterations = max(200,4*dimension)
    settings%krylov_dimension = dimension
    settings%compact_krylov = .true.
  end subroutine configure_sparse_settings

  subroutine build_free_equations(ntotal,fixed,free)
    integer(i64), intent(in) :: ntotal,fixed(:)
    integer(i64), allocatable, intent(out) :: free(:)
    logical, allocatable :: is_fixed(:)
    integer(i64) :: dof,cursor

    allocate(is_fixed(ntotal))
    is_fixed = .false.
    is_fixed(fixed) = .true.
    allocate(free(count(.not.is_fixed)))
    cursor = 0_i64
    do dof = 1_i64,ntotal
      if (.not.is_fixed(dof)) then
        cursor = cursor+1_i64
        free(cursor) = dof
      end if
    end do
  end subroutine build_free_equations

  subroutine measure_plane_distortion(mesh,spread,status)
    type(mesh_database_2d_t), intent(in) :: mesh
    real(dp), intent(out) :: spread
    integer, intent(out) :: status
    real(dp), parameter :: gp = 0.77459666924148337704_dp
    real(dp), parameter :: g(3) = [-gp,0.0_dp,gp]
    real(dp) :: X(8,2),N(8),dNp(8,2),dNx(8,2),xp(2),Jmap(2,2),det_jac
    real(dp) :: minimum_det,maximum_det
    integer :: e,a,gx,gy,row,point_status

    minimum_det = huge(1.0_dp)
    maximum_det = 0.0_dp
    status = DES_STATUS_OK

    do e = 1,size(mesh%elements)
      do a = 1,8
        row = node_row(mesh,mesh%elements(e)%connectivity(a))
        if (row <= 0) then
          status = -1
          return
        end if
        X(a,1) = mesh%nodes(row)%x
        X(a,2) = mesh%nodes(row)%y
      end do
      do gy = 1,3
        do gx = 1,3
          call q8_reference_gradient( &
              X,g(gx),g(gy),N,dNp,dNx,xp,Jmap,det_jac,point_status)
          if (point_status /= DES_STATUS_OK) then
            status = point_status
            return
          end if
          minimum_det = min(minimum_det,det_jac)
          maximum_det = max(maximum_det,det_jac)
        end do
      end do
    end do

    if (minimum_det <= 0.0_dp) then
      status = -1
      return
    end if
    spread = maximum_det/minimum_det
  end subroutine measure_plane_distortion

  integer function node_row(mesh,node_id) result(row)
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
  end function node_row

  function numerical_row_rank(matrix,tolerance) result(rank_value)
    real(dp), intent(in) :: matrix(:,:),tolerance
    integer :: rank_value
    real(dp), allocatable :: work(:,:)
    real(dp) :: pivot_value,factor,scale
    integer :: row,col,pivot_row,r,m,n

    work = matrix
    m = size(work,1)
    n = size(work,2)
    rank_value = 0
    row = 1
    scale = max(1.0_dp,maxval(abs(work)))

    do col = 1,n
      if (row > m) exit
      pivot_row = row
      do r = row+1,m
        if (abs(work(r,col)) > abs(work(pivot_row,col))) pivot_row = r
      end do
      pivot_value = work(pivot_row,col)
      if (abs(pivot_value) <= tolerance*scale) cycle

      if (pivot_row /= row) call swap_rows(work,pivot_row,row)
      pivot_value = work(row,col)
      do r = row+1,m
        factor = work(r,col)/pivot_value
        work(r,col:n) = work(r,col:n)-factor*work(row,col:n)
      end do
      rank_value = rank_value+1
      row = row+1
    end do
  end function numerical_row_rank

  subroutine swap_rows(matrix,row_a,row_b)
    real(dp), intent(inout) :: matrix(:,:)
    integer, intent(in) :: row_a,row_b
    real(dp) :: temp(size(matrix,2))

    temp = matrix(row_a,:)
    matrix(row_a,:) = matrix(row_b,:)
    matrix(row_b,:) = temp
  end subroutine swap_rows

  subroutine require(condition,message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not.condition) error stop message
  end subroutine require

end program test_2d_q8_herrmann_incompressible_acceptance
