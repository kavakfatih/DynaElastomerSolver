program benchmark_v03_fbar_performance
  use, intrinsic :: iso_fortran_env, only : int64, output_unit
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_material_types, only : neo_hookean_parameters_t
  use des_internal_mesh, only : internal_mesh_t, initialize_q4_internal_mesh
  use des_q4_edge_traction, only : Q4_EDGE_RIGHT
  use des_q4_mesh_edge_traction, only : add_q4_reference_edge_traction
  use des_q4_plane_strain_fbar_force_solver, only : &
      solve_q4_plane_strain_fbar_force_control
  use des_q4_plane_strain_newton_solver, only : newton_report_t
  implicit none

  integer, parameter :: mesh_sizes(4) = [4,8,12,16]
  integer, parameter :: ncases = size(mesh_sizes)
  real(dp), parameter :: bytes_per_real_dp = 8.0_dp

  type :: performance_result_t
    integer :: mesh_n = 0
    integer :: nodes = 0
    integer :: elements = 0
    integer :: total_dofs = 0
    integer :: free_equations = 0
    integer :: total_iterations = 0
    integer :: linear_solves = 0
    real(dp) :: wall_seconds = 0.0_dp
    real(dp) :: cpu_seconds = 0.0_dp
    real(dp) :: tip_y = 0.0_dp
    real(dp) :: final_residual = 0.0_dp
    real(dp) :: minimum_j = 0.0_dp
    integer(int64) :: known_dense_matrix_bytes = 0_int64
    real(dp) :: known_dense_matrix_mib = 0.0_dp
  end type performance_result_t

  type(performance_result_t) :: results(ncases)
  integer :: k, json_unit, ios

  do k = 1,ncases
    call run_case(mesh_sizes(k),results(k))
  end do

  write(*,'(A)') 'V0.3 F-bar Cook performans benchmarkı'
  write(*,'(A)') 'mesh   free eq   wall[s]    CPU[s]     known dense MiB   linear solves'
  do k = 1,ncases
    write(*,'(I2,A,I7,2(2X,F10.4),2X,F14.4,2X,I8)') &
        results(k)%mesh_n,'x'//trim(to_string(results(k)%mesh_n)), &
        results(k)%free_equations,results(k)%wall_seconds, &
        results(k)%cpu_seconds,results(k)%known_dense_matrix_mib, &
        results(k)%linear_solves
  end do

  write(*,'(A)') 'V03_FBAR_PERFORMANCE_JSON_BEGIN'
  call write_json(output_unit,results)
  write(*,'(A)') 'V03_FBAR_PERFORMANCE_JSON_END'

  open(newunit=json_unit,file='V0.3_FBAR_PERFORMANCE_RESULTS.json', &
       status='replace',action='write',iostat=ios)
  if (ios /= 0) error stop 'V0.3 F-bar performance JSON dosyası açılamadı.'
  call write_json(json_unit,results)
  close(json_unit)

  write(*,'(A)') 'V0.3 F-bar performans benchmarkı TAMAMLANDI.'

contains

  subroutine run_case(n,result)
    integer, intent(in) :: n
    type(performance_result_t), intent(out) :: result
    real(dp), allocatable :: X(:,:),u(:,:),residual(:),external_force(:)
    integer, allocatable :: connectivity(:,:),fixed_dofs(:)
    type(neo_hookean_parameters_t) :: parameters
    type(newton_report_t) :: report
    integer :: nnode,ndof,tip_node
    integer(int64) :: count_start,count_end,count_rate
    integer(int64) :: ndof64,nfree64,bytes64
    real(dp) :: cpu_start,cpu_end

    call prepare_problem(n,X,connectivity,fixed_dofs,external_force)
    nnode = size(X,1)
    ndof = 2*nnode
    allocate(u(nnode,2),residual(ndof))
    u = 0.0_dp

    parameters%mu = 1.0_dp
    parameters%lambda = 1000.0_dp

    call cpu_time(cpu_start)
    call system_clock(count_start,count_rate)

    call solve_q4_plane_strain_fbar_force_control( &
        X,connectivity,parameters,fixed_dofs,external_force, &
        5,35,2.0e-8_dp,u,residual,report)

    call system_clock(count_end)
    call cpu_time(cpu_end)

    if (.not. report%converged .or. report%status /= DES_STATUS_OK) then
      write(*,'(A,I0,A)') 'F-bar performans benchmarkı ',n,'x'//trim(to_string(n))// &
          ' meshte yakınsamadı.'
      error stop 'F-bar performans benchmarkı solver doğrulaması başarısız.'
    end if

    tip_node = midpoint_tip_node(n)
    result%mesh_n = n
    result%nodes = nnode
    result%elements = size(connectivity,1)
    result%total_dofs = ndof
    result%free_equations = report%max_linear_equation_count
    result%total_iterations = report%total_iterations
    result%linear_solves = report%linear_solve_count
    result%tip_y = u(tip_node,2)
    result%final_residual = report%final_residual_norm
    result%minimum_j = report%min_j

    if (count_rate > 0_int64) then
      result%wall_seconds = real(count_end-count_start,dp)/real(count_rate,dp)
    end if
    result%cpu_seconds = max(0.0_dp,cpu_end-cpu_start)

    ! Bilinen minimum dense çalışma-seti:
    !   K(ndof,ndof) + Kff(nfree,nfree) + linear solver Awork(nfree,nfree).
    ! stdlib/LAPACK iç workspace'i, allocator metadata'sı ve process overhead'i
    ! bu analitik sayıya dahil değildir. Linux CI ayrıca /usr/bin/time ile peak RSS
    ! kaydeder; böylece model-bazlı ve process-bazlı bellek ölçümleri ayrılır.
    ndof64 = int(ndof,int64)
    nfree64 = int(result%free_equations,int64)
    bytes64 = 8_int64*(ndof64*ndof64 + 2_int64*nfree64*nfree64)
    result%known_dense_matrix_bytes = bytes64
    result%known_dense_matrix_mib = real(bytes64,dp)/(1024.0_dp*1024.0_dp)

    if (result%tip_y <= 0.0_dp .or. result%minimum_j <= 0.0_dp) then
      error stop 'F-bar performans benchmarkı fiziksel sonuç kontrolünü geçemedi.'
    end if
  end subroutine run_case

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
    if (status /= DES_STATUS_OK) then
      error stop 'F-bar performans Cook InternalMesh oluşturulamadı.'
    end if

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
          mesh,element_id,Q4_EDGE_RIGHT,traction,external_force,status,edge_length)
      if (status /= DES_STATUS_OK .or. edge_length <= 0.0_dp) then
        error stop 'F-bar performans Cook sağ sınır traction assembly başarısız.'
      end if
    end do
  end subroutine prepare_problem

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

  integer function midpoint_tip_node(n) result(node)
    integer, intent(in) :: n
    node = 1+(n/2)*(n+1)+n
  end function midpoint_tip_node

  subroutine write_json(unit,results_value)
    integer, intent(in) :: unit
    type(performance_result_t), intent(in) :: results_value(:)
    integer :: i

    write(unit,'(A)') '{'
    write(unit,'(A)') '  "schema_version": 1,'
    write(unit,'(A)') '  "benchmark": "V0.3 F-bar Cook performance",'
    write(unit,'(A)') '  "formulation": "F-bar Q4 plane strain",'
    write(unit,'(A)') '  "linear_backend": "stdlib/LAPACK dense",'
    write(unit,'(A)') '  "timing_policy": "report-only; no wall-clock pass/fail threshold",'
    write(unit,'(A)') '  "memory_policy": "known dense matrices are analytical minimum; Linux CI records process peak RSS separately",'
    write(unit,'(A)') '  "cases": ['

    do i = 1,size(results_value)
      write(unit,'(A)') '    {'
      write(unit,'(A,I0,A)') '      "mesh_n": ',results_value(i)%mesh_n,','
      write(unit,'(A,I0,A)') '      "nodes": ',results_value(i)%nodes,','
      write(unit,'(A,I0,A)') '      "elements": ',results_value(i)%elements,','
      write(unit,'(A,I0,A)') '      "total_dofs": ',results_value(i)%total_dofs,','
      write(unit,'(A,I0,A)') '      "free_equations": ',results_value(i)%free_equations,','
      write(unit,'(A,ES24.16E3,A)') '      "wall_seconds": ',results_value(i)%wall_seconds,','
      write(unit,'(A,ES24.16E3,A)') '      "cpu_seconds": ',results_value(i)%cpu_seconds,','
      write(unit,'(A,ES24.16E3,A)') '      "tip_y_displacement": ',results_value(i)%tip_y,','
      write(unit,'(A,ES24.16E3,A)') '      "final_residual_inf_norm": ',results_value(i)%final_residual,','
      write(unit,'(A,ES24.16E3,A)') '      "minimum_J": ',results_value(i)%minimum_j,','
      write(unit,'(A,I0,A)') '      "total_iterations": ',results_value(i)%total_iterations,','
      write(unit,'(A,I0,A)') '      "linear_solves": ',results_value(i)%linear_solves,','
      write(unit,'(A,I0,A)') '      "known_dense_matrix_bytes": ',results_value(i)%known_dense_matrix_bytes,','
      write(unit,'(A,ES24.16E3)') '      "known_dense_matrix_mib": ',results_value(i)%known_dense_matrix_mib
      if (i < size(results_value)) then
        write(unit,'(A)') '    },'
      else
        write(unit,'(A)') '    }'
      end if
    end do

    write(unit,'(A)') '  ]'
    write(unit,'(A)') '}'
  end subroutine write_json

  function to_string(value) result(text)
    integer, intent(in) :: value
    character(len=24) :: text
    write(text,'(I0)') value
  end function to_string

end program benchmark_v03_fbar_performance
