program test_q9_herrmann_quadrature_convergence
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_internal_mesh, only : internal_mesh_t, initialize_q9_internal_mesh
  use des_linear_solver, only : linear_solver_settings_t, DES_LINEAR_BACKEND_STDLIB_DENSE
  use des_q9_plane_strain_herrmann_neo_hookean, only : &
      Q9_HERRMANN_QUADRATURE_2X2, Q9_HERRMANN_QUADRATURE_3X3, &
      Q9_HERRMANN_QUADRATURE_4X4
  use des_q9_herrmann_solver_report, only : herrmann_solver_report_t, &
      solve_q9_internal_mesh_herrmann_adaptive_reported
  implicit none

  integer, parameter :: n = 4
  integer, parameter :: norder = 3
  integer, parameter :: orders(norder) = [ &
      Q9_HERRMANN_QUADRATURE_2X2, &
      Q9_HERRMANN_QUADRATURE_3X3, &
      Q9_HERRMANN_QUADRATURE_4X4]
  real(dp), parameter :: mu = 1.0_dp
  real(dp), parameter :: pressure_compliance = 1.0e-3_dp
  real(dp), parameter :: residual_tol = 5.0e-8_dp
  real(dp) :: midpoint(norder),du_norm(norder),p_norm(norder),c_norm(norder),min_j(norder)
  real(dp) :: gap23,gap34
  integer :: k,status,json_unit,ios

  do k = 1,norder
    call solve_case(orders(k),midpoint(k),du_norm(k),p_norm(k),c_norm(k),min_j(k),status)
    if (status /= DES_STATUS_OK) then
      error stop 'Q9/P1 Cook quadrature convergence solve basarisiz.'
    end if
    if (midpoint(k) <= 0.0_dp .or. min_j(k) <= 0.0_dp) then
      error stop 'Q9/P1 quadrature convergence fiziksel state gecersiz.'
    end if
    if (du_norm(k) > residual_tol .or. p_norm(k) > residual_tol) then
      error stop 'Q9/P1 quadrature convergence weak residual tolerans disi.'
    end if
    if (c_norm(k) < 0.0_dp .or. c_norm(k) >= huge(1.0_dp)) then
      error stop 'Q9/P1 quadrature convergence volumetric diagnostic gecersiz.'
    end if
  end do

  gap23 = relative_gap(midpoint(1),midpoint(2))
  gap34 = relative_gap(midpoint(2),midpoint(3))

  ! Higher-order integration eklentisinin temel amaci external mixed referans ile
  ! gorulen farkin quadrature kaynakli olup olmadigini ayirmaktir. 3x3 -> 4x4
  ! farkinin 2x2 -> 3x3 farkindan kucuk olmasi normal convergence beklentisidir.
  if (gap34 >= gap23) then
    error stop 'Q9/P1 quadrature sequence 3x3 -> 4x4 ile stabilize olmuyor.'
  end if

  write(*,'(A)') 'Q9/P1 Herrmann Cook 4x4 mesh quadrature convergence:'
  do k = 1,norder
    write(*,'(A,I0,A,ES14.6,A,ES12.4,A,ES12.4,A,ES12.4,A,ES12.4)') &
        '  order=',orders(k),'x',midpoint(k), &
        ' Ru_inf=',du_norm(k),' Rp_inf=',p_norm(k), &
        ' Cvol_inf=',c_norm(k),' minJ=',min_j(k)
  end do
  write(*,'(A,F10.5,A)') '  2x2 -> 3x3 midpoint gap = ',100.0_dp*gap23,' %'
  write(*,'(A,F10.5,A)') '  3x3 -> 4x4 midpoint gap = ',100.0_dp*gap34,' %'

  open(newunit=json_unit,file='V0.3_HERRMANN_QUADRATURE_CONVERGENCE_RESULTS.json', &
       status='replace',action='write',iostat=ios)
  if (ios /= 0) error stop 'Q9/P1 quadrature convergence JSON acilamadi.'
  write(json_unit,'(A)') '{'
  write(json_unit,'(A)') '  "schema_version": 1,'
  write(json_unit,'(A)') '  "benchmark": "q9_p1_herrmann_quadrature_convergence",'
  write(json_unit,'(A)') '  "mesh": "4x4_Q9",'
  write(json_unit,'(A)') '  "tip_definition": "right_edge_geometric_midpoint",'
  write(json_unit,'(A)') '  "bulk_over_mu": 1000,'
  write(json_unit,'(A)') '  "quadrature_orders": [2, 3, 4],'
  write(json_unit,'(A,ES24.16,A,ES24.16,A,ES24.16,A)') &
      '  "midpoint_y": [',midpoint(1),', ',midpoint(2),', ',midpoint(3),'],'
  write(json_unit,'(A,ES24.16,A)') '  "gap_2_to_3": ',gap23,','
  write(json_unit,'(A,ES24.16)') '  "gap_3_to_4": ',gap34
  write(json_unit,'(A)') '}'
  close(json_unit)

  write(*,'(A)') 'Q9/P1 Herrmann quadrature-convergence diagnostic BASARILI.'

contains

  subroutine solve_case(order,tip,du_metric,p_metric,c_metric,j_min,solve_status)
    integer, intent(in) :: order
    real(dp), intent(out) :: tip,du_metric,p_metric,c_metric,j_min
    integer, intent(out) :: solve_status

    type(internal_mesh_t) :: mesh
    type(herrmann_solver_report_t) :: report
    type(linear_solver_settings_t) :: dense_settings
    real(dp), allocatable :: X(:,:),external_force(:),u(:,:),p(:,:),residual(:)
    integer, allocatable :: connectivity(:,:),fixed_dofs(:)
    integer :: nnode,nelem,tip_node,npx

    call build_cook_q9(n,n,X,connectivity,fixed_dofs,external_force)
    call initialize_q9_internal_mesh(mesh,X,connectivity,solve_status)
    if (solve_status /= DES_STATUS_OK) return

    nnode = mesh%node_count()
    nelem = mesh%element_count()
    allocate(u(nnode,2),p(nelem,3),residual(2*nnode+3*nelem))
    u = 0.0_dp
    p = 0.0_dp
    dense_settings%backend = DES_LINEAR_BACKEND_STDLIB_DENSE

    call solve_q9_internal_mesh_herrmann_adaptive_reported( &
        mesh,mu,pressure_compliance,fixed_dofs,external_force, &
        0.25_dp,0.015625_dp,0.5_dp,6,45,1.0e-9_dp, &
        u,p,residual,report,linear_settings=dense_settings,quadrature_order=order)

    solve_status = report%nonlinear%status
    if (.not. report%nonlinear%converged .or. .not. report%metrics_valid) then
      if (solve_status == DES_STATUS_OK) solve_status = -999
      return
    end if

    npx = 2*n+1
    tip_node = q9_node_id(2*n,n,npx)
    tip = u(tip_node,2)
    du_metric = report%displacement_residual_inf_norm
    p_metric = report%pressure_residual_inf_norm
    c_metric = report%volumetric_constraint_inf_norm
    j_min = report%nonlinear%min_j
  end subroutine solve_case

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
    real(dp) :: Nedge(3),dNedge(3),r,dxdr,dydr,jac
    integer :: g,a,node

    do g = 1,3
      r = coord(g)
      Nedge(1) = 0.5_dp*r*(r-1.0_dp)
      Nedge(2) = 1.0_dp-r*r
      Nedge(3) = 0.5_dp*r*(r+1.0_dp)
      dNedge(1) = r-0.5_dp
      dNedge(2) = -2.0_dp*r
      dNedge(3) = r+0.5_dp

      dxdr = 0.0_dp
      dydr = 0.0_dp
      do a = 1,3
        dxdr = dxdr+dNedge(a)*X(edge_nodes(a),1)
        dydr = dydr+dNedge(a)*X(edge_nodes(a),2)
      end do
      jac = sqrt(dxdr*dxdr+dydr*dydr)
      if (jac <= 0.0_dp) error stop 'Q9 Cook edge Jacobian non-positive.'

      do a = 1,3
        node = edge_nodes(a)
        force(2*node-1) = force(2*node-1)+Nedge(a)*traction(1)*jac*weights(g)
        force(2*node) = force(2*node)+Nedge(a)*traction(2)*jac*weights(g)
      end do
    end do
  end subroutine add_q9_reference_edge_traction

  real(dp) function relative_gap(a,b) result(gap)
    real(dp), intent(in) :: a,b
    gap = abs(a-b)/max(abs(b),1.0e-14_dp)
  end function relative_gap

end program test_q9_herrmann_quadrature_convergence
