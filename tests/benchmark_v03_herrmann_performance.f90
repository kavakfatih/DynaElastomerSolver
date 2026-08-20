program benchmark_v03_herrmann_performance
  use, intrinsic :: iso_fortran_env, only : int64, output_unit
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_internal_mesh, only : internal_mesh_t, initialize_q9_internal_mesh
  use des_csr_matrix, only : csr_matrix_t
  use des_linear_solver, only : linear_solver_settings_t, &
      DES_LINEAR_BACKEND_STDLIB_CSR_GMRES, DES_LINEAR_BACKEND_MUMPS_DIRECT, &
      linear_backend_name, production_linear_solver_settings
  use des_q9_plane_strain_herrmann_sparse_mesh, only : &
      initialize_q9_plane_strain_herrmann_csr_pattern
  use des_q9_herrmann_solver_report, only : herrmann_solver_report_t, &
      solve_q9_internal_mesh_herrmann_adaptive_reported
  implicit none

  integer, parameter :: mesh_sizes(4) = [1,2,3,4]
  integer, parameter :: ncases = size(mesh_sizes)
  real(dp), parameter :: mu = 1.0_dp
  real(dp), parameter :: pressure_compliance = 1.0e-3_dp
  real(dp), parameter :: solve_tolerance = 1.0e-9_dp

  type :: performance_result_t
    integer :: mesh_n = 0
    integer :: nodes = 0
    integer :: elements = 0
    integer :: displacement_dofs = 0
    integer :: pressure_dofs = 0
    integer :: total_dofs = 0
    integer :: constrained_displacement_dofs = 0
    integer :: free_equations = 0
    integer :: csr_nnz = 0
    real(dp) :: csr_density = 0.0_dp
    integer :: increments_converged = 0
    integer :: cutbacks = 0
    integer :: total_iterations = 0
    integer :: linear_solves = 0
    integer :: pattern_analysis_count = 0
    integer :: reorder_count = 0
    integer :: factorization_count = 0
    integer :: context_solve_count = 0
    integer :: symbolic_reuse_count = 0
    integer :: selected_backend = 0
    logical :: fallback_used = .false.
    real(dp) :: wall_seconds = 0.0_dp
    real(dp) :: cpu_seconds = 0.0_dp
    real(dp) :: tip_y = 0.0_dp
    real(dp) :: final_residual = 0.0_dp
    real(dp) :: displacement_residual = 0.0_dp
    real(dp) :: pressure_residual = 0.0_dp
    real(dp) :: volumetric_constraint = 0.0_dp
    real(dp) :: minimum_j = 0.0_dp
  end type performance_result_t

  type(performance_result_t) :: results(ncases)
  type(linear_solver_settings_t) :: settings
  character(len=32) :: mode
  character(len=96) :: output_file
  integer :: k,json_unit,ios

  call get_command_argument(1,mode)
  if (len_trim(mode) == 0) mode = 'gmres'
  mode = trim(adjustl(mode))

  select case (trim(mode))
  case ('gmres')
    settings = linear_solver_settings_t()
    settings%backend = DES_LINEAR_BACKEND_STDLIB_CSR_GMRES
    settings%max_iterations = 600
    settings%krylov_dimension = 80
    output_file = 'V0.3_HERRMANN_PERFORMANCE_GMRES_RESULTS.json'
  case ('mumps')
    settings = production_linear_solver_settings()
    settings%backend = DES_LINEAR_BACKEND_MUMPS_DIRECT
    output_file = 'V0.3_HERRMANN_PERFORMANCE_MUMPS_RESULTS.json'
  case default
    error stop 'Herrmann performance backend argumani gmres veya mumps olmali.'
  end select

  do k = 1,ncases
    call run_case(mesh_sizes(k),settings,results(k))
  end do

  write(*,'(A)') 'V0.3 Q9/P1 Herrmann performance/scaling baseline'
  write(*,'(A,A)') 'Requested backend: ',trim(mode)
  write(*,'(A)') &
      'mesh  total DOF  CSR nnz  density     wall[s]   iterations  linear solves'
  do k = 1,ncases
    write(*,'(I2,A,I9,2X,I8,2X,ES10.3,2X,F9.4,2X,I8,2X,I8)') &
        results(k)%mesh_n,'x'//trim(to_string(results(k)%mesh_n)), &
        results(k)%total_dofs,results(k)%csr_nnz,results(k)%csr_density, &
        results(k)%wall_seconds,results(k)%total_iterations, &
        results(k)%linear_solves
  end do

  write(*,'(A)') 'V03_HERRMANN_PERFORMANCE_JSON_BEGIN'
  call write_json(output_unit,trim(mode),results)
  write(*,'(A)') 'V03_HERRMANN_PERFORMANCE_JSON_END'

  open(newunit=json_unit,file=trim(output_file),status='replace', &
       action='write',iostat=ios)
  if (ios /= 0) error stop 'Herrmann performance JSON dosyasi acilamadi.'
  call write_json(json_unit,trim(mode),results)
  close(json_unit)

  write(*,'(A,A)') 'Q9/P1 Herrmann performance benchmark TAMAMLANDI: ', &
      trim(output_file)

contains

  subroutine run_case(n,active_settings,result)
    integer, intent(in) :: n
    type(linear_solver_settings_t), intent(in) :: active_settings
    type(performance_result_t), intent(out) :: result

    type(internal_mesh_t) :: mesh
    type(csr_matrix_t) :: pattern
    type(herrmann_solver_report_t) :: report
    real(dp), allocatable :: X(:,:),external_force(:),u(:,:),p(:,:),residual(:)
    integer, allocatable :: connectivity(:,:),fixed_dofs(:)
    integer(int64) :: count_start,count_end,count_rate
    real(dp) :: cpu_start,cpu_end
    integer :: status,nnode,nelem,npx,tip_node

    call build_cook_q9(n,n,X,connectivity,fixed_dofs,external_force)
    call initialize_q9_internal_mesh(mesh,X,connectivity,status)
    if (status /= DES_STATUS_OK) then
      error stop 'Herrmann performance Q9 InternalMesh kurulamadi.'
    end if

    nnode = mesh%node_count()
    nelem = mesh%element_count()
    allocate(u(nnode,2),p(nelem,3),residual(2*nnode+3*nelem))
    u = 0.0_dp
    p = 0.0_dp

    call initialize_q9_plane_strain_herrmann_csr_pattern( &
        nnode,connectivity,pattern,status)
    if (status /= DES_STATUS_OK) then
      error stop 'Herrmann performance CSR pattern kurulamadi.'
    end if

    call cpu_time(cpu_start)
    call system_clock(count_start,count_rate)

    call solve_q9_internal_mesh_herrmann_adaptive_reported( &
        mesh,mu,pressure_compliance,fixed_dofs,external_force, &
        0.25_dp,0.015625_dp,0.5_dp,6,45,solve_tolerance, &
        u,p,residual,report,linear_settings=active_settings)

    call system_clock(count_end)
    call cpu_time(cpu_end)

    if (.not. report%nonlinear%converged .or. &
        report%nonlinear%status /= DES_STATUS_OK .or. &
        .not. report%metrics_valid) then
      write(*,'(A,I0,A)') 'Herrmann performance ',n, &
          'x'//trim(to_string(n))//' meshte yakinsamadi.'
      error stop 'Herrmann performance solver correctness kontrolu basarisiz.'
    end if

    npx = 2*n+1
    tip_node = q9_node_id(2*n,n,npx)

    result%mesh_n = n
    result%nodes = nnode
    result%elements = nelem
    result%displacement_dofs = 2*nnode
    result%pressure_dofs = 3*nelem
    result%total_dofs = result%displacement_dofs+result%pressure_dofs
    result%constrained_displacement_dofs = size(fixed_dofs)
    result%free_equations = result%total_dofs-size(fixed_dofs)
    result%csr_nnz = pattern%nnz()
    result%csr_density = real(result%csr_nnz,dp)/ &
        (real(result%total_dofs,dp)*real(result%total_dofs,dp))
    result%increments_converged = report%nonlinear%increments_converged
    result%cutbacks = report%nonlinear%cutback_count
    result%total_iterations = report%nonlinear%total_iterations
    result%linear_solves = report%nonlinear%linear_solve_count
    result%pattern_analysis_count = &
        report%nonlinear%last_linear_report%pattern_analysis_count
    result%reorder_count = report%nonlinear%last_linear_report%reorder_count
    result%factorization_count = &
        report%nonlinear%last_linear_report%factorization_count
    result%context_solve_count = &
        report%nonlinear%last_linear_report%context_solve_count
    result%symbolic_reuse_count = &
        report%nonlinear%last_linear_report%symbolic_reuse_count
    result%selected_backend = report%nonlinear%last_linear_report%backend
    result%fallback_used = report%nonlinear%last_linear_report%fallback_used
    result%tip_y = u(tip_node,2)
    result%final_residual = report%nonlinear%final_residual_norm
    result%displacement_residual = report%displacement_residual_inf_norm
    result%pressure_residual = report%pressure_residual_inf_norm
    result%volumetric_constraint = report%volumetric_constraint_inf_norm
    result%minimum_j = report%nonlinear%min_j

    if (count_rate > 0_int64) then
      result%wall_seconds = real(count_end-count_start,dp)/real(count_rate,dp)
    end if
    result%cpu_seconds = max(0.0_dp,cpu_end-cpu_start)

    if (result%tip_y <= 0.0_dp .or. result%minimum_j <= 0.0_dp) then
      error stop 'Herrmann performance fiziksel sonuc kontrolu basarisiz.'
    end if
    if (abs(report%nonlinear%final_load_factor-1.0_dp) > 1.0e-12_dp) then
      error stop 'Herrmann performance final load factor 1 degil.'
    end if
    if (result%displacement_residual > 5.0e-8_dp .or. &
        result%pressure_residual > 5.0e-8_dp) then
      error stop 'Herrmann performance final weak residual tolerans disi.'
    end if
  end subroutine run_case

  subroutine build_cook_q9(nx_local,ny_local,X,connectivity,fixed_dofs,external_force)
    integer, intent(in) :: nx_local,ny_local
    real(dp), allocatable, intent(out) :: X(:,:),external_force(:)
    integer, allocatable, intent(out) :: connectivity(:,:),fixed_dofs(:)

    real(dp), parameter :: y_right_bottom = 44.0_dp/48.0_dp
    real(dp), parameter :: y_right_top = 60.0_dp/48.0_dp
    real(dp), parameter :: y_left_top = 44.0_dp/48.0_dp
    real(dp) :: s,t,left_y,right_y,traction(2)
    integer :: npx,npy,ix,iy,node,e,i,j,cursor,edge_nodes(3)

    npx = 2*nx_local+1
    npy = 2*ny_local+1
    allocate(X(npx*npy,2),connectivity(nx_local*ny_local,9))
    allocate(fixed_dofs(2*npy),external_force(2*npx*npy))
    external_force = 0.0_dp

    do iy = 0,2*ny_local
      t = real(iy,dp)/real(2*ny_local,dp)
      left_y = t*y_left_top
      right_y = (1.0_dp-t)*y_right_bottom+t*y_right_top
      do ix = 0,2*nx_local
        s = real(ix,dp)/real(2*nx_local,dp)
        node = 1+iy*npx+ix
        X(node,1) = s
        X(node,2) = (1.0_dp-s)*left_y+s*right_y
      end do
    end do

    e = 0
    do j = 0,ny_local-1
      do i = 0,nx_local-1
        e = e+1
        connectivity(e,1) = q9_node_id(2*i,2*j,npx)
        connectivity(e,2) = q9_node_id(2*i+2,2*j,npx)
        connectivity(e,3) = q9_node_id(2*i+2,2*j+2,npx)
        connectivity(e,4) = q9_node_id(2*i,2*j+2,npx)
        connectivity(e,5) = q9_node_id(2*i+1,2*j,npx)
        connectivity(e,6) = q9_node_id(2*i+2,2*j+1,npx)
        connectivity(e,7) = q9_node_id(2*i+1,2*j+2,npx)
        connectivity(e,8) = q9_node_id(2*i,2*j+1,npx)
        connectivity(e,9) = q9_node_id(2*i+1,2*j+1,npx)
      end do
    end do

    cursor = 0
    do iy = 0,2*ny_local
      node = q9_node_id(0,iy,npx)
      cursor = cursor+1
      fixed_dofs(cursor) = 2*node-1
      cursor = cursor+1
      fixed_dofs(cursor) = 2*node
    end do

    traction = [0.0_dp,0.01_dp]
    do j = 0,ny_local-1
      e = j*nx_local+nx_local
      edge_nodes = [connectivity(e,2),connectivity(e,6),connectivity(e,3)]
      call add_q9_reference_edge_traction(X,edge_nodes,traction,external_force)
    end do
  end subroutine build_cook_q9

  integer function q9_node_id(ix,iy,npx) result(node)
    integer, intent(in) :: ix,iy,npx
    node = 1+iy*npx+ix
  end function q9_node_id

  subroutine add_q9_reference_edge_traction(X,edge_nodes,traction,force)
    real(dp), intent(in) :: X(:,:),traction(2)
    integer, intent(in) :: edge_nodes(3)
    real(dp), intent(inout) :: force(:)
    real(dp), parameter :: gp = 0.77459666924148337704_dp
    real(dp), parameter :: coord(3) = [-gp,0.0_dp,gp]
    real(dp), parameter :: weights(3) = &
        [5.0_dp/9.0_dp,8.0_dp/9.0_dp,5.0_dp/9.0_dp]
    real(dp) :: N(3),dN(3),r,dxdr,dydr,jac
    integer :: g,a,node

    do g = 1,3
      r = coord(g)
      N(1) = 0.5_dp*r*(r-1.0_dp)
      N(2) = 1.0_dp-r*r
      N(3) = 0.5_dp*r*(r+1.0_dp)
      dN(1) = r-0.5_dp
      dN(2) = -2.0_dp*r
      dN(3) = r+0.5_dp

      dxdr = 0.0_dp
      dydr = 0.0_dp
      do a = 1,3
        dxdr = dxdr+dN(a)*X(edge_nodes(a),1)
        dydr = dydr+dN(a)*X(edge_nodes(a),2)
      end do
      jac = sqrt(dxdr*dxdr+dydr*dydr)
      if (jac <= 0.0_dp) then
        error stop 'Herrmann performance edge Jacobian non-positive.'
      end if

      do a = 1,3
        node = edge_nodes(a)
        force(2*node-1) = force(2*node-1)+ &
            N(a)*traction(1)*jac*weights(g)
        force(2*node) = force(2*node)+ &
            N(a)*traction(2)*jac*weights(g)
      end do
    end do
  end subroutine add_q9_reference_edge_traction

  subroutine write_json(unit,mode_value,results_value)
    integer, intent(in) :: unit
    character(len=*), intent(in) :: mode_value
    type(performance_result_t), intent(in) :: results_value(:)
    integer :: i

    write(unit,'(A)') '{'
    write(unit,'(A)') '  "schema_version": 1,'
    write(unit,'(A)') &
        '  "benchmark": "V0.3 Q9/P1 Herrmann performance/scaling",'
    write(unit,'(A)') '  "formulation": "Q9/P1 Herrmann plane strain",'
    write(unit,'(A,A,A)') '  "requested_backend": "',trim(mode_value),'",'
    write(unit,'(A)') '  "quadrature": "3x3",'
    write(unit,'(A)') '  "bulk_over_mu": 1000,'
    write(unit,'(A)') &
        '  "timing_policy": "report-only; no wall-clock pass/fail threshold",'
    write(unit,'(A)') &
        '  "phase_timing": "not instrumented in B9.1; total wall/cpu only",'
    write(unit,'(A)') '  "cases": ['

    do i = 1,size(results_value)
      write(unit,'(A)') '    {'
      write(unit,'(A,I0,A)') &
          '      "mesh_n": ',results_value(i)%mesh_n,','
      write(unit,'(A,I0,A)') &
          '      "nodes": ',results_value(i)%nodes,','
      write(unit,'(A,I0,A)') &
          '      "elements": ',results_value(i)%elements,','
      write(unit,'(A,I0,A)') '      "displacement_dofs": ', &
          results_value(i)%displacement_dofs,','
      write(unit,'(A,I0,A)') '      "pressure_dofs": ', &
          results_value(i)%pressure_dofs,','
      write(unit,'(A,I0,A)') &
          '      "total_dofs": ',results_value(i)%total_dofs,','
      write(unit,'(A,I0,A)') '      "constrained_displacement_dofs": ', &
          results_value(i)%constrained_displacement_dofs,','
      write(unit,'(A,I0,A)') &
          '      "free_equations": ',results_value(i)%free_equations,','
      write(unit,'(A,I0,A)') &
          '      "csr_nnz": ',results_value(i)%csr_nnz,','
      write(unit,'(A,ES24.16E3,A)') &
          '      "csr_density": ',results_value(i)%csr_density,','
      write(unit,'(A,ES24.16E3,A)') &
          '      "wall_seconds": ',results_value(i)%wall_seconds,','
      write(unit,'(A,ES24.16E3,A)') &
          '      "cpu_seconds": ',results_value(i)%cpu_seconds,','
      write(unit,'(A,I0,A)') '      "increments_converged": ', &
          results_value(i)%increments_converged,','
      write(unit,'(A,I0,A)') &
          '      "cutbacks": ',results_value(i)%cutbacks,','
      write(unit,'(A,I0,A)') &
          '      "total_iterations": ',results_value(i)%total_iterations,','
      write(unit,'(A,I0,A)') &
          '      "linear_solves": ',results_value(i)%linear_solves,','
      write(unit,'(A,I0,A)') '      "pattern_analysis_count": ', &
          results_value(i)%pattern_analysis_count,','
      write(unit,'(A,I0,A)') &
          '      "reorder_count": ',results_value(i)%reorder_count,','
      write(unit,'(A,I0,A)') '      "factorization_count": ', &
          results_value(i)%factorization_count,','
      write(unit,'(A,I0,A)') '      "context_solve_count": ', &
          results_value(i)%context_solve_count,','
      write(unit,'(A,I0,A)') '      "symbolic_reuse_count": ', &
          results_value(i)%symbolic_reuse_count,','
      write(unit,'(A,I0,A)') '      "selected_backend_id": ', &
          results_value(i)%selected_backend,','
      write(unit,'(A,A,A)') '      "selected_backend": "', &
          trim(linear_backend_name(results_value(i)%selected_backend)),'",'
      write(unit,'(A,A,A)') '      "fallback_used": ', &
          trim(json_boolean(results_value(i)%fallback_used)),','
      write(unit,'(A,ES24.16E3,A)') '      "tip_y_displacement": ', &
          results_value(i)%tip_y,','
      write(unit,'(A,ES24.16E3,A)') '      "final_residual_inf_norm": ', &
          results_value(i)%final_residual,','
      write(unit,'(A,ES24.16E3,A)') &
          '      "displacement_residual_inf_norm": ', &
          results_value(i)%displacement_residual,','
      write(unit,'(A,ES24.16E3,A)') &
          '      "pressure_residual_inf_norm": ', &
          results_value(i)%pressure_residual,','
      write(unit,'(A,ES24.16E3,A)') &
          '      "volumetric_constraint_inf_norm": ', &
          results_value(i)%volumetric_constraint,','
      write(unit,'(A,ES24.16E3)') &
          '      "minimum_J": ',results_value(i)%minimum_j
      if (i < size(results_value)) then
        write(unit,'(A)') '    },'
      else
        write(unit,'(A)') '    }'
      end if
    end do

    write(unit,'(A)') '  ]'
    write(unit,'(A)') '}'
  end subroutine write_json

  pure function json_boolean(value) result(text)
    logical, intent(in) :: value
    character(len=5) :: text

    if (value) then
      text = 'true '
    else
      text = 'false'
    end if
  end function json_boolean

  function to_string(value) result(text)
    integer, intent(in) :: value
    character(len=24) :: text
    write(text,'(I0)') value
  end function to_string

end program benchmark_v03_herrmann_performance
