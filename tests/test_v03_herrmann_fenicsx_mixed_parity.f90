program test_v03_herrmann_fenicsx_mixed_parity
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_internal_mesh, only : internal_mesh_t, initialize_q9_internal_mesh
  use des_linear_solver, only : linear_solver_settings_t, DES_LINEAR_BACKEND_STDLIB_DENSE
  use des_q9_plane_strain_herrmann_neo_hookean, only : &
      Q9_HERRMANN_QUADRATURE_3X3, Q9_HERRMANN_QUADRATURE_4X4
  use des_q9_herrmann_solver_report, only : herrmann_solver_report_t, &
      solve_q9_internal_mesh_herrmann_adaptive_reported
  use des_q9_herrmann_geometry, only : q9_reference_gradient
  use des_herrmann_pressure_interpolation, only : herrmann_p1_pressure_basis
  implicit none

  integer, parameter :: n = 4
  integer, parameter :: ncase = 2
  integer, parameter :: orders(ncase) = [Q9_HERRMANN_QUADRATURE_3X3, &
                                          Q9_HERRMANN_QUADRATURE_4X4]
  real(dp), parameter :: mu = 1.0_dp
  real(dp), parameter :: pressure_compliance = 1.0e-3_dp

  ! Bagimsiz DOLFINx/UFL/PETSc workflow'undan dondurulmus reference snapshotlari.
  ! Q2 displacement + discontinuous complete-linear DPC1 pressure space kullanir.
  ! degree=4 Basix -> 9 cell point (3x3); degree=6 -> 16 cell point (4x4).
  real(dp), parameter :: ref_midpoint(ncase) = [ &
      2.0247415245965815e-2_dp, 2.0247003861301714e-2_dp]
  real(dp), parameter :: ref_p_mean(ncase) = [ &
      -2.3224402554388440e-3_dp, -2.3223167314948686e-3_dp]
  real(dp), parameter :: ref_p_std(ncase) = [ &
      9.9688420663465900e-3_dp, 9.9690392435480160e-3_dp]
  real(dp), parameter :: ref_p_rms(ncase) = [ &
      1.0235797032173127e-2_dp, 1.0235961041386460e-2_dp]
  real(dp), parameter :: ref_constraint_l2(ncase) = [ &
      9.8557138381746300e-4_dp, 9.8556465428459260e-4_dp]
  real(dp), parameter :: ref_j_average(ncase) = [ &
      1.0000023224402554_dp, 1.0000023223167307_dp]

  real(dp), parameter :: displacement_rel_tol = 2.0e-5_dp
  real(dp), parameter :: pressure_rel_tol = 2.0e-4_dp
  real(dp), parameter :: constraint_rel_tol = 5.0e-4_dp
  real(dp), parameter :: j_abs_tol = 5.0e-7_dp
  real(dp), parameter :: weak_residual_tol = 2.0e-8_dp

  real(dp) :: midpoint(ncase),p_mean(ncase),p_std(ncase),p_rms(ncase)
  real(dp) :: constraint_l2(ncase),j_average(ncase)
  real(dp) :: du_norm(ncase),rp_norm(ncase),pointwise_constraint(ncase)
  integer :: k,status

  do k = 1,ncase
    call solve_and_measure(orders(k),midpoint(k),p_mean(k),p_std(k),p_rms(k), &
        constraint_l2(k),j_average(k),du_norm(k),rp_norm(k), &
        pointwise_constraint(k),status)
    if (status /= DES_STATUS_OK) then
      error stop 'Q9/P1 FEniCSx mixed parity solve veya metric evaluation basarisiz.'
    end if

    if (du_norm(k) > weak_residual_tol .or. rp_norm(k) > weak_residual_tol) then
      error stop 'Q9/P1 FEniCSx parity weak residual tolerans disi.'
    end if

    call require_relative_match('midpoint displacement',midpoint(k), &
        ref_midpoint(k),displacement_rel_tol)
    call require_relative_match('pressure mean',p_mean(k), &
        ref_p_mean(k),pressure_rel_tol)
    call require_relative_match('pressure std',p_std(k), &
        ref_p_std(k),pressure_rel_tol)
    call require_relative_match('pressure rms',p_rms(k), &
        ref_p_rms(k),pressure_rel_tol)
    call require_relative_match('constraint L2 RMS',constraint_l2(k), &
        ref_constraint_l2(k),constraint_rel_tol)
    if (abs(j_average(k)-ref_j_average(k)) > j_abs_tol) then
      error stop 'Q9/P1 FEniCSx parity average J tolerans disi.'
    end if

    write(*,'(A,I0,A)') 'Matched quadrature ',orders(k),'x', ' parity metrics:'
    write(*,'(A,ES16.8,A,ES12.4)') '  midpoint=',midpoint(k), &
        ' relerr=',relative_error(midpoint(k),ref_midpoint(k))
    write(*,'(A,ES16.8,A,ES12.4)') '  p_mean=',p_mean(k), &
        ' relerr=',relative_error(p_mean(k),ref_p_mean(k))
    write(*,'(A,ES16.8,A,ES12.4)') '  p_std=',p_std(k), &
        ' relerr=',relative_error(p_std(k),ref_p_std(k))
    write(*,'(A,ES16.8,A,ES12.4)') '  p_rms=',p_rms(k), &
        ' relerr=',relative_error(p_rms(k),ref_p_rms(k))
    write(*,'(A,ES16.8,A,ES12.4)') '  constraint_L2=',constraint_l2(k), &
        ' relerr=',relative_error(constraint_l2(k),ref_constraint_l2(k))
    write(*,'(A,ES16.8,A,ES12.4)') '  J_average=',j_average(k), &
        ' abserr=',abs(j_average(k)-ref_j_average(k))
    write(*,'(A,ES12.4,A,ES12.4,A,ES12.4)') &
        '  Ru_inf=',du_norm(k),' Rp_inf=',rp_norm(k), &
        ' pointwise_C_inf=',pointwise_constraint(k)
  end do

  write(*,'(A)') 'Q9/P1 Herrmann <-> FEniCSx mixed Q2/DPC1 parity gate BASARILI.'

contains

  subroutine solve_and_measure(order,tip,mean_p,std_p,rms_p,constraint_rms,j_avg, &
      du_metric,rp_metric,pointwise_metric,solve_status)
    integer, intent(in) :: order
    real(dp), intent(out) :: tip,mean_p,std_p,rms_p,constraint_rms,j_avg
    real(dp), intent(out) :: du_metric,rp_metric,pointwise_metric
    integer, intent(out) :: solve_status

    type(internal_mesh_t) :: mesh
    type(herrmann_solver_report_t) :: report
    type(linear_solver_settings_t) :: dense_settings
    real(dp), allocatable :: X(:,:),external_force(:),u(:,:),p(:,:),residual(:)
    integer, allocatable :: connectivity(:,:),fixed_dofs(:)
    integer :: nnode,nelem,npx,tip_node

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
        0.125_dp,0.015625_dp,0.5_dp,6,50,1.0e-11_dp, &
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
    rp_metric = report%pressure_residual_inf_norm
    pointwise_metric = report%volumetric_constraint_inf_norm

    call evaluate_integral_metrics(mesh,u,p,order,mean_p,std_p,rms_p, &
        constraint_rms,j_avg,solve_status)
  end subroutine solve_and_measure

  subroutine evaluate_integral_metrics(mesh,u,p,order,mean_p,std_p,rms_p, &
      constraint_rms,j_avg,status)
    type(internal_mesh_t), intent(in) :: mesh
    real(dp), intent(in) :: u(:,:),p(:,:)
    integer, intent(in) :: order
    real(dp), intent(out) :: mean_p,std_p,rms_p,constraint_rms,j_avg
    integer, intent(out) :: status

    real(dp) :: coord(4),weight1d(4),Xe(9,2),ue(9,2)
    real(dp) :: N(9),dN_parent(9,2),dN_dX(9,2),x_point(2),Jmap(2,2)
    real(dp) :: Np(3),F11,F12,F21,F22,J,p_value,constraint,det_jac,w
    real(dp) :: area,sum_p,sum_p2,sum_c2,sum_j,variance
    integer :: n_gauss,e,a,gx,gy,node,point_status

    status = DES_STATUS_OK
    call local_gauss_rule(order,n_gauss,coord,weight1d,status)
    if (status /= DES_STATUS_OK) return

    area = 0.0_dp
    sum_p = 0.0_dp
    sum_p2 = 0.0_dp
    sum_c2 = 0.0_dp
    sum_j = 0.0_dp

    do e = 1,mesh%element_count()
      do a = 1,9
        node = mesh%q9_connectivity(e,a)
        Xe(a,:) = mesh%coordinates(node,:)
        ue(a,:) = u(node,:)
      end do

      do gy = 1,n_gauss
        do gx = 1,n_gauss
          call q9_reference_gradient(Xe,coord(gx),coord(gy),N,dN_parent,dN_dX, &
              x_point,Jmap,det_jac,point_status)
          if (point_status /= DES_STATUS_OK) then
            status = point_status
            return
          end if

          call herrmann_p1_pressure_basis(coord(gx),coord(gy),Np)
          p_value = dot_product(Np,p(e,:))

          F11 = 1.0_dp
          F12 = 0.0_dp
          F21 = 0.0_dp
          F22 = 1.0_dp
          do a = 1,9
            F11 = F11 + ue(a,1)*dN_dX(a,1)
            F12 = F12 + ue(a,1)*dN_dX(a,2)
            F21 = F21 + ue(a,2)*dN_dX(a,1)
            F22 = F22 + ue(a,2)*dN_dX(a,2)
          end do
          J = F11*F22-F12*F21
          if (J <= 0.0_dp) then
            status = -998
            return
          end if

          constraint = (J-1.0_dp)+pressure_compliance*p_value
          w = det_jac*weight1d(gx)*weight1d(gy)
          area = area+w
          sum_p = sum_p+p_value*w
          sum_p2 = sum_p2+p_value*p_value*w
          sum_c2 = sum_c2+constraint*constraint*w
          sum_j = sum_j+J*w
        end do
      end do
    end do

    if (area <= 0.0_dp) then
      status = -997
      return
    end if

    mean_p = sum_p/area
    rms_p = sqrt(max(sum_p2/area,0.0_dp))
    variance = max(sum_p2/area-mean_p*mean_p,0.0_dp)
    std_p = sqrt(variance)
    constraint_rms = sqrt(max(sum_c2/area,0.0_dp))
    j_avg = sum_j/area
  end subroutine evaluate_integral_metrics

  subroutine local_gauss_rule(order,n_gauss,coord,weight,status)
    integer, intent(in) :: order
    integer, intent(out) :: n_gauss,status
    real(dp), intent(out) :: coord(4),weight(4)
    real(dp), parameter :: gp3 = 0.77459666924148337704_dp
    real(dp), parameter :: gp4o = 0.86113631159405257522_dp
    real(dp), parameter :: gp4i = 0.33998104358485626480_dp
    real(dp), parameter :: gw4o = 0.34785484513745385737_dp
    real(dp), parameter :: gw4i = 0.65214515486254614263_dp

    coord = 0.0_dp
    weight = 0.0_dp
    status = DES_STATUS_OK
    select case(order)
    case(Q9_HERRMANN_QUADRATURE_3X3)
      n_gauss = 3
      coord(1:3) = [-gp3,0.0_dp,gp3]
      weight(1:3) = [5.0_dp/9.0_dp,8.0_dp/9.0_dp,5.0_dp/9.0_dp]
    case(Q9_HERRMANN_QUADRATURE_4X4)
      n_gauss = 4
      coord = [-gp4o,-gp4i,gp4i,gp4o]
      weight = [gw4o,gw4i,gw4i,gw4o]
    case default
      n_gauss = 0
      status = -996
    end select
  end subroutine local_gauss_rule

  subroutine require_relative_match(name,value,reference,tolerance)
    character(len=*), intent(in) :: name
    real(dp), intent(in) :: value,reference,tolerance
    if (relative_error(value,reference) > tolerance) then
      write(*,'(A,A,A,ES16.8,A,ES16.8,A,ES12.4)') &
          'Parity mismatch: ',trim(name),' value=',value,' ref=',reference, &
          ' relerr=',relative_error(value,reference)
      error stop 'Q9/P1 FEniCSx mixed parity tolerance asildi.'
    end if
  end subroutine require_relative_match

  real(dp) function relative_error(value,reference) result(err)
    real(dp), intent(in) :: value,reference
    err = abs(value-reference)/max(abs(reference),1.0e-14_dp)
  end function relative_error

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

end program test_v03_herrmann_fenicsx_mixed_parity
