program test_v03_herrmann_production_benchmark
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_internal_mesh, only : internal_mesh_t, initialize_q9_internal_mesh
  use des_q9_plane_strain_herrmann_neo_hookean, only : &
      Q9_HERRMANN_QUADRATURE_2X2, Q9_HERRMANN_QUADRATURE_3X3
  use des_q9_herrmann_solver_report, only : herrmann_solver_report_t, &
      solve_q9_internal_mesh_herrmann_adaptive_reported
  use des_q9_internal_mesh_herrmann_assembly, only : &
      assemble_q9_internal_mesh_herrmann_with_quadrature
  use des_q9_herrmann_geometry, only : q9_reference_gradient
  implicit none

  integer, parameter :: nx = 2, ny = 2
  real(dp), parameter :: mu = 1.0_dp
  real(dp), parameter :: compliances(4) = [1.0e-1_dp,1.0e-2_dp,1.0e-3_dp,0.0_dp]
  real(dp), parameter :: metric_tol = 5.0e-8_dp
  real(dp), parameter :: severe_state_tol = 2.0e-7_dp

  type(internal_mesh_t) :: cook_mesh
  real(dp), allocatable :: cook_X(:,:),cook_external(:)
  integer, allocatable :: cook_conn(:,:),cook_fixed(:)
  real(dp) :: tip_3x3(4),disp_norm(4),pressure_norm(4),volumetric_norm(4)
  real(dp) :: tip_2x2_k1000,tip_2x2_incompressible
  real(dp) :: gap_k1000,gap_incompressible,k1000_to_incompressible_gap
  logical :: q2_k1000_converged,q2_incompressible_converged
  integer :: k,status,json_unit,ios

  real(dp) :: severe_jacobian_spread,severe_displacement_error,severe_pressure_error
  real(dp) :: severe_disp_norm,severe_pressure_norm,severe_volumetric_norm

  call build_cook_q9(nx,ny,cook_X,cook_conn,cook_fixed,cook_external)
  call initialize_q9_internal_mesh(cook_mesh,cook_X,cook_conn,status)
  if (status /= DES_STATUS_OK) error stop 'Herrmann Cook Q9 mesh olusturulamadi.'

  do k = 1,4
    call solve_cook_case( &
        cook_mesh,cook_fixed,cook_external,compliances(k),Q9_HERRMANN_QUADRATURE_3X3, &
        tip_3x3(k),disp_norm(k),pressure_norm(k),volumetric_norm(k),status)
    if (status /= DES_STATUS_OK) then
      error stop 'Q9/P1 Herrmann 3x3 incompressibility sweep solve basarisiz.'
    end if
    if (disp_norm(k) > metric_tol .or. pressure_norm(k) > metric_tol .or. &
        volumetric_norm(k) > metric_tol) then
      error stop 'Q9/P1 Herrmann sweep convergence metric tolerans disi.'
    end if
    if (tip_3x3(k) <= 0.0_dp) then
      error stop 'Q9/P1 Herrmann Cook tip displacement yuk yonuyle uyumsuz.'
    end if
  end do

  k1000_to_incompressible_gap = relative_gap(tip_3x3(3),tip_3x3(4))
  if (k1000_to_incompressible_gap > 0.20_dp) then
    error stop 'Q9/P1 K/mu=1000 sonucu fully incompressible limite yeterince yaklasmadi.'
  end if

  call try_solve_cook_quadrature( &
      cook_mesh,cook_fixed,cook_external,compliances(3),Q9_HERRMANN_QUADRATURE_2X2, &
      tip_2x2_k1000,q2_k1000_converged)
  call try_solve_cook_quadrature( &
      cook_mesh,cook_fixed,cook_external,compliances(4),Q9_HERRMANN_QUADRATURE_2X2, &
      tip_2x2_incompressible,q2_incompressible_converged)

  if (q2_k1000_converged) then
    gap_k1000 = relative_gap(tip_2x2_k1000,tip_3x3(3))
  else
    gap_k1000 = -1.0_dp
  end if
  if (q2_incompressible_converged) then
    gap_incompressible = relative_gap(tip_2x2_incompressible,tip_3x3(4))
  else
    gap_incompressible = -1.0_dp
  end if

  call run_severe_distortion_case( &
      severe_jacobian_spread,severe_displacement_error,severe_pressure_error, &
      severe_disp_norm,severe_pressure_norm,severe_volumetric_norm)

  if (severe_jacobian_spread < 6.0_dp) then
    error stop 'Q9/P1 severe-distortion benchmark geometrisi yeterince zorlayici degil.'
  end if
  if (severe_displacement_error > severe_state_tol .or. &
      severe_pressure_error > severe_state_tol) then
    error stop 'Q9/P1 severe-distortion exact affine state geri kazanilamadi.'
  end if
  if (severe_disp_norm > metric_tol .or. severe_pressure_norm > metric_tol .or. &
      severe_volumetric_norm > metric_tol) then
    error stop 'Q9/P1 severe-distortion convergence metric tolerans disi.'
  end if

  write(*,'(A)') 'Q9/P1 Herrmann 2x2 Cook incompressibility sweep (3x3 production):'
  do k = 1,4
    write(*,'(A,ES12.4,A,ES14.6,A,ES12.4,A,ES12.4)') &
        '  compliance=',compliances(k),' tip_y=',tip_3x3(k), &
        ' Rp_inf=',pressure_norm(k),' Cvol_inf=',volumetric_norm(k)
  end do
  write(*,'(A,F8.3,A)') '  K/mu=1000 -> incompressible tip gap = ', &
      100.0_dp*k1000_to_incompressible_gap,' %'
  write(*,'(A,L1,A,ES14.6,A,ES12.4)') '  2x2 K/mu=1000 converged=', &
      q2_k1000_converged,' tip_y=',tip_2x2_k1000,' gap=',gap_k1000
  write(*,'(A,L1,A,ES14.6,A,ES12.4)') '  2x2 incompressible converged=', &
      q2_incompressible_converged,' tip_y=',tip_2x2_incompressible, &
      ' gap=',gap_incompressible
  write(*,'(A,ES14.6)') '  severe-distortion Jacobian spread = ',severe_jacobian_spread
  write(*,'(A,ES14.6)') '  severe displacement error = ',severe_displacement_error
  write(*,'(A,ES14.6)') '  severe pressure error = ',severe_pressure_error
  write(*,'(A,ES14.6)') '  severe volumetric constraint = ',severe_volumetric_norm

  open(newunit=json_unit,file='V0.3_HERRMANN_PRODUCTION_BENCHMARK_RESULTS.json', &
       status='replace',action='write',iostat=ios)
  if (ios /= 0) error stop 'Herrmann production benchmark JSON acilamadi.'
  call write_benchmark_json( &
      json_unit,tip_3x3,disp_norm,pressure_norm,volumetric_norm, &
      k1000_to_incompressible_gap,q2_k1000_converged,tip_2x2_k1000,gap_k1000, &
      q2_incompressible_converged,tip_2x2_incompressible,gap_incompressible, &
      severe_jacobian_spread,severe_displacement_error,severe_pressure_error, &
      severe_disp_norm,severe_pressure_norm,severe_volumetric_norm)
  close(json_unit)

  write(*,'(A)') 'Q9/P1 Herrmann production benchmark paketi BASARILI.'

contains

  subroutine solve_cook_case( &
      mesh,fixed_dofs,external_force,pressure_compliance,quadrature_order, &
      tip,displacement_metric,pressure_metric,volumetric_metric,solve_status)
    type(internal_mesh_t), intent(in) :: mesh
    integer, intent(in) :: fixed_dofs(:),quadrature_order
    real(dp), intent(in) :: external_force(:),pressure_compliance
    real(dp), intent(out) :: tip,displacement_metric,pressure_metric,volumetric_metric
    integer, intent(out) :: solve_status

    real(dp), allocatable :: u(:,:),p(:,:),residual(:)
    type(herrmann_solver_report_t) :: report
    integer :: tip_node,nnode,nelem

    nnode = mesh%node_count()
    nelem = mesh%element_count()
    allocate(u(nnode,2),p(nelem,3),residual(2*nnode+3*nelem))
    u = 0.0_dp
    p = 0.0_dp

    call solve_q9_internal_mesh_herrmann_adaptive_reported( &
        mesh,mu,pressure_compliance,fixed_dofs,external_force, &
        0.25_dp,0.015625_dp,0.5_dp,6,40,1.0e-9_dp, &
        u,p,residual,report,quadrature_order=quadrature_order)

    solve_status = report%nonlinear%status
    if (.not. report%nonlinear%converged .or. .not. report%metrics_valid) then
      if (solve_status == DES_STATUS_OK) solve_status = -999
      tip = 0.0_dp
      displacement_metric = huge(1.0_dp)
      pressure_metric = huge(1.0_dp)
      volumetric_metric = huge(1.0_dp)
      return
    end if

    tip_node = nnode
    tip = u(tip_node,2)
    displacement_metric = report%displacement_residual_inf_norm
    pressure_metric = report%pressure_residual_inf_norm
    volumetric_metric = report%volumetric_constraint_inf_norm
  end subroutine solve_cook_case

  subroutine try_solve_cook_quadrature( &
      mesh,fixed_dofs,external_force,pressure_compliance,quadrature_order,tip,converged)
    type(internal_mesh_t), intent(in) :: mesh
    integer, intent(in) :: fixed_dofs(:),quadrature_order
    real(dp), intent(in) :: external_force(:),pressure_compliance
    real(dp), intent(out) :: tip
    logical, intent(out) :: converged
    real(dp) :: du_norm,p_norm,c_norm
    integer :: local_status

    call solve_cook_case( &
        mesh,fixed_dofs,external_force,pressure_compliance,quadrature_order, &
        tip,du_norm,p_norm,c_norm,local_status)
    converged = local_status == DES_STATUS_OK
  end subroutine try_solve_cook_quadrature

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
    real(dp), parameter :: weights(3) = [5.0_dp/9.0_dp,8.0_dp/9.0_dp,5.0_dp/9.0_dp]
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
      if (jac <= 0.0_dp) error stop 'Q9 Cook edge Jacobian non-positive.'

      do a = 1,3
        node = edge_nodes(a)
        force(2*node-1) = force(2*node-1)+N(a)*traction(1)*jac*weights(g)
        force(2*node) = force(2*node)+N(a)*traction(2)*jac*weights(g)
      end do
    end do
  end subroutine add_q9_reference_edge_traction

  subroutine run_severe_distortion_case( &
      jacobian_spread,displacement_error,pressure_error, &
      displacement_metric,pressure_metric,volumetric_metric)
    real(dp), intent(out) :: jacobian_spread,displacement_error,pressure_error
    real(dp), intent(out) :: displacement_metric,pressure_metric,volumetric_metric

    integer, parameter :: nnode = 25,nelem = 4,ndisp = 2*nnode,ntotal = ndisp+3*nelem
    integer, parameter :: fixed_dofs(3) = [1,2,10]
    real(dp), parameter :: p0 = 0.15_dp
    real(dp) :: X(nnode,2),u_target(nnode,2),u(nnode,2),p_target(nelem,3),p(nelem,3)
    real(dp) :: target_residual(ntotal),residual(ntotal),K(ntotal,ntotal),external_force(ndisp)
    real(dp) :: H(2,2),min_j
    integer :: connectivity(nelem,9),local_status,node
    type(internal_mesh_t) :: mesh
    type(herrmann_solver_report_t) :: report

    call set_distorted_2x2_q9(X,connectivity)
    call initialize_q9_internal_mesh(mesh,X,connectivity,local_status)
    if (local_status /= DES_STATUS_OK) error stop 'Severe Q9 mesh olusturulamadi.'

    call q9_reference_jacobian_spread(mesh,jacobian_spread)

    H = 0.0_dp
    H(1,1) = 0.20_dp
    H(1,2) = 0.25_dp
    H(2,2) = -1.0_dp/6.0_dp

    do node = 1,nnode
      u_target(node,1) = H(1,1)*X(node,1)+H(1,2)*X(node,2)
      u_target(node,2) = H(2,2)*X(node,2)
    end do
    p_target = 0.0_dp
    p_target(:,1) = p0

    call assemble_q9_internal_mesh_herrmann_with_quadrature( &
        mesh,u_target,p_target,2.7_dp,0.0_dp,Q9_HERRMANN_QUADRATURE_3X3, &
        target_residual,K,local_status,min_j)
    if (local_status /= DES_STATUS_OK) error stop 'Severe target Q9 assembly basarisiz.'
    if (maxval(abs(target_residual(ndisp+1:ntotal))) > 2.0e-11_dp) then
      error stop 'Severe Q9 target pressure residual sifir degil.'
    end if
    external_force = target_residual(1:ndisp)

    u = 0.0_dp
    p = 0.0_dp
    call solve_q9_internal_mesh_herrmann_adaptive_reported( &
        mesh,2.7_dp,0.0_dp,fixed_dofs,external_force, &
        0.10_dp,0.00625_dp,0.5_dp,8,50,1.0e-9_dp, &
        u,p,residual,report,quadrature_order=Q9_HERRMANN_QUADRATURE_3X3)

    if (.not. report%nonlinear%converged .or. .not. report%metrics_valid) then
      error stop 'Severe Q9/P1 fully incompressible solve yakinsamadi.'
    end if

    displacement_error = maxval(abs(u-u_target))
    pressure_error = maxval(abs(p-p_target))
    displacement_metric = report%displacement_residual_inf_norm
    pressure_metric = report%pressure_residual_inf_norm
    volumetric_metric = report%volumetric_constraint_inf_norm
  end subroutine run_severe_distortion_case

  subroutine set_distorted_2x2_q9(coords,connectivity)
    real(dp), intent(out) :: coords(25,2)
    integer, intent(out) :: connectivity(4,9)
    real(dp) :: x0,y0
    integer :: ix,iy,node

    node = 0
    do iy = 0,4
      do ix = 0,4
        node = node+1
        x0 = 0.5_dp*real(ix,dp)
        y0 = 0.5_dp*real(iy,dp)
        coords(node,1) = x0 + 0.45_dp*x0*(2.0_dp-x0) &
            * sin(0.5_dp*acos(-1.0_dp)*y0)
        coords(node,2) = y0 + 0.15_dp*y0*(2.0_dp-y0) &
            * sin(0.5_dp*acos(-1.0_dp)*x0)
      end do
    end do

    connectivity(1,:) = [1,3,13,11,2,8,12,6,7]
    connectivity(2,:) = [3,5,15,13,4,10,14,8,9]
    connectivity(3,:) = [11,13,23,21,12,18,22,16,17]
    connectivity(4,:) = [13,15,25,23,14,20,24,18,19]
  end subroutine set_distorted_2x2_q9

  subroutine q9_reference_jacobian_spread(mesh,spread)
    type(internal_mesh_t), intent(in) :: mesh
    real(dp), intent(out) :: spread
    real(dp), parameter :: gp = 0.77459666924148337704_dp
    real(dp), parameter :: coord(3) = [-gp,0.0_dp,gp]
    real(dp) :: N(9),dN_parent(9,2),dN_dX(9,2),x_point(2),Jmap(2,2),det_jac
    real(dp) :: min_det,max_det
    integer :: e,gx,gy,local_status

    min_det = huge(1.0_dp)
    max_det = 0.0_dp
    do e = 1,mesh%element_count()
      do gy = 1,3
        do gx = 1,3
          call q9_reference_gradient( &
              mesh%coordinates(mesh%q9_connectivity(e,:),:),coord(gx),coord(gy), &
              N,dN_parent,dN_dX,x_point,Jmap,det_jac,local_status)
          if (local_status /= DES_STATUS_OK .or. det_jac <= 0.0_dp) then
            error stop 'Severe Q9 reference Jacobian gecersiz.'
          end if
          min_det = min(min_det,det_jac)
          max_det = max(max_det,det_jac)
        end do
      end do
    end do
    spread = max_det/min_det
  end subroutine q9_reference_jacobian_spread

  real(dp) function relative_gap(a,b) result(gap)
    real(dp), intent(in) :: a,b
    gap = abs(a-b)/max(abs(b),1.0e-14_dp)
  end function relative_gap

  subroutine write_benchmark_json( &
      unit,tip,du_norm,p_norm,c_norm,limit_gap,q2_k_converged,q2_k_tip,q2_k_gap, &
      q2_i_converged,q2_i_tip,q2_i_gap,severe_spread,severe_u_error,severe_p_error, &
      severe_du_norm,severe_p_norm,severe_c_norm)
    integer, intent(in) :: unit
    real(dp), intent(in) :: tip(4),du_norm(4),p_norm(4),c_norm(4),limit_gap
    logical, intent(in) :: q2_k_converged,q2_i_converged
    real(dp), intent(in) :: q2_k_tip,q2_k_gap,q2_i_tip,q2_i_gap
    real(dp), intent(in) :: severe_spread,severe_u_error,severe_p_error
    real(dp), intent(in) :: severe_du_norm,severe_p_norm,severe_c_norm

    write(unit,'(A)') '{'
    write(unit,'(A)') '  "schema_version": 1,'
    write(unit,'(A)') '  "benchmark": "q9_p1_herrmann_production_acceptance",'
    write(unit,'(A)') '  "element": "Q9/P1 Herrmann",'
    write(unit,'(A)') '  "primary_quadrature": "3x3",'
    write(unit,'(A)') '  "cook_mesh": "2x2_Q9",'
    write(unit,'(A)') '  "incompressibility_sweep": {'
    write(unit,'(A)') '    "bulk_over_mu": [10.0,100.0,1000.0,"infinite"],'
    call write_four_values(unit,'tip_y',tip,.true.)
    call write_four_values(unit,'displacement_residual_inf',du_norm,.true.)
    call write_four_values(unit,'pressure_residual_inf',p_norm,.true.)
    call write_four_values(unit,'volumetric_constraint_inf',c_norm,.true.)
    write(unit,'(A,ES24.16E3)') '    "k1000_to_incompressible_relative_tip_gap": ',limit_gap
    write(unit,'(A)') '  },'
    write(unit,'(A)') '  "quadrature_comparison": {'
    call write_quadrature_case(unit,'bulk_over_mu_1000',q2_k_converged,q2_k_tip,q2_k_gap,.true.)
    call write_quadrature_case(unit,'fully_incompressible',q2_i_converged,q2_i_tip,q2_i_gap,.false.)
    write(unit,'(A)') '  },'
    write(unit,'(A)') '  "severe_distortion": {'
    write(unit,'(A,ES24.16E3,A)') '    "reference_jacobian_spread": ',severe_spread,','
    write(unit,'(A,ES24.16E3,A)') '    "max_displacement_error": ',severe_u_error,','
    write(unit,'(A,ES24.16E3,A)') '    "max_pressure_error": ',severe_p_error,','
    write(unit,'(A,ES24.16E3,A)') '    "displacement_residual_inf": ',severe_du_norm,','
    write(unit,'(A,ES24.16E3,A)') '    "pressure_residual_inf": ',severe_p_norm,','
    write(unit,'(A,ES24.16E3)') '    "volumetric_constraint_inf": ',severe_c_norm
    write(unit,'(A)') '  }'
    write(unit,'(A)') '}'
  end subroutine write_benchmark_json

  subroutine write_four_values(unit,name,values,with_comma)
    integer, intent(in) :: unit
    character(len=*), intent(in) :: name
    real(dp), intent(in) :: values(4)
    logical, intent(in) :: with_comma
    character(len=1) :: suffix

    suffix = ' '
    if (with_comma) suffix = ','
    write(unit,'(A,4(ES24.16E3,A),A)') &
        '    "'//trim(name)//'": [',values(1),',',values(2),',',values(3),',', &
        values(4),']',suffix
  end subroutine write_four_values

  subroutine write_quadrature_case(unit,name,converged,tip,gap,with_comma)
    integer, intent(in) :: unit
    character(len=*), intent(in) :: name
    logical, intent(in) :: converged,with_comma
    real(dp), intent(in) :: tip,gap
    character(len=5) :: bool_text
    character(len=1) :: suffix

    bool_text = 'false'
    if (converged) bool_text = 'true '
    suffix = ' '
    if (with_comma) suffix = ','
    write(unit,'(A)') '    "'//trim(name)//'": {'
    write(unit,'(A,A,A)') '      "q2x2_converged": ',trim(bool_text),','
    write(unit,'(A,ES24.16E3,A)') '      "q2x2_tip_y": ',tip,','
    write(unit,'(A,ES24.16E3)') '      "q2x2_vs_q3x3_relative_tip_gap": ',gap
    write(unit,'(A,A)') '    }',suffix
  end subroutine write_quadrature_case

end program test_v03_herrmann_production_benchmark
