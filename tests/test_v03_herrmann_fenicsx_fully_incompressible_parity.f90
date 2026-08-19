program test_v03_herrmann_fenicsx_fully_incompressible_parity
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_internal_mesh, only : internal_mesh_t, initialize_q9_internal_mesh
  use des_q9_plane_strain_herrmann_neo_hookean, only : Q9_HERRMANN_QUADRATURE_3X3
  use des_q9_herrmann_solver_report, only : herrmann_solver_report_t, &
      solve_q9_internal_mesh_herrmann_adaptive_reported
  use des_q9_herrmann_geometry, only : q9_reference_gradient
  use des_herrmann_pressure_interpolation, only : herrmann_p1_pressure_basis
  implicit none

  integer, parameter :: n = 4
  real(dp), parameter :: mu = 1.0_dp
  real(dp), parameter :: pressure_compliance = 0.0_dp

  ! Bagimsiz FEniCSx/DOLFINx fully-incompressible Q2/DPC1 workflow'undan
  ! dondurulmus n=4, Basix degree=4 -> 9 point (3x3) reference snapshoti.
  ! Dyna Fortran kodu bu degerlerin uretilmesinde kullanilmamistir.
  real(dp), parameter :: ref_midpoint = 2.0227982624133290e-2_dp
  real(dp), parameter :: ref_p_mean = -2.3234571892092053e-3_dp
  real(dp), parameter :: ref_p_std = 9.9739236805459470e-3_dp
  real(dp), parameter :: ref_p_rms = 1.0240976852597762e-2_dp
  real(dp), parameter :: ref_constraint_l2 = 9.8578192484690260e-4_dp
  real(dp), parameter :: ref_j_average = 1.0000000000000002_dp

  ! Ayni discrete space + ayni quadrature icin siki regression kapilari.
  ! Bunlar continuum-level commercial parity toleranslari degildir; implementation
  ! equivalence kontroludur. Failure olursa threshold sonucu uydurmak icin gevsetilmez.
  real(dp), parameter :: displacement_rel_tol = 2.0e-5_dp
  real(dp), parameter :: pressure_rel_tol = 2.0e-4_dp
  real(dp), parameter :: constraint_rel_tol = 5.0e-4_dp
  real(dp), parameter :: j_abs_tol = 5.0e-7_dp
  real(dp), parameter :: weak_residual_tol = 2.0e-8_dp

  type(internal_mesh_t) :: mesh
  type(herrmann_solver_report_t) :: report
  real(dp), allocatable :: X(:,:),external_force(:),u(:,:),p(:,:),residual(:)
  integer, allocatable :: connectivity(:,:),fixed_dofs(:)
  real(dp) :: midpoint,p_mean,p_std,p_rms,constraint_l2,j_average
  integer :: nnode,nelem,npx,tip_node,status

  call build_cook_q9(n,n,X,connectivity,fixed_dofs,external_force)
  call initialize_q9_internal_mesh(mesh,X,connectivity,status)
  if (status /= DES_STATUS_OK) then
    error stop 'Fully incompressible parity Q9 mesh olusturulamadi.'
  end if

  nnode = mesh%node_count()
  nelem = mesh%element_count()
  allocate(u(nnode,2),p(nelem,3),residual(2*nnode+3*nelem))
  u = 0.0_dp
  p = 0.0_dp

  call solve_q9_internal_mesh_herrmann_adaptive_reported( &
      mesh,mu,pressure_compliance,fixed_dofs,external_force, &
      0.125_dp,0.015625_dp,0.5_dp,6,50,1.0e-11_dp, &
      u,p,residual,report,quadrature_order=Q9_HERRMANN_QUADRATURE_3X3)

  if (.not. report%nonlinear%converged .or. &
      report%nonlinear%status /= DES_STATUS_OK .or. .not. report%metrics_valid) then
    error stop 'Fully incompressible Q9/P1 Cook solve yakinsamadi.'
  end if
  if (report%displacement_residual_inf_norm > weak_residual_tol .or. &
      report%pressure_residual_inf_norm > weak_residual_tol) then
    error stop 'Fully incompressible Q9/P1 weak residual tolerans disi.'
  end if
  if (report%nonlinear%min_j <= 0.0_dp) then
    error stop 'Fully incompressible Q9/P1 cozumunde J pozitif degil.'
  end if

  npx = 2*n+1
  tip_node = q9_node_id(2*n,n,npx)
  midpoint = u(tip_node,2)

  call evaluate_integral_metrics( &
      mesh,u,p,p_mean,p_std,p_rms,constraint_l2,j_average,status)
  if (status /= DES_STATUS_OK) then
    error stop 'Fully incompressible parity integral metric evaluation basarisiz.'
  end if

  call require_relative_match('midpoint displacement',midpoint, &
      ref_midpoint,displacement_rel_tol)
  call require_relative_match('pressure mean',p_mean,ref_p_mean,pressure_rel_tol)
  call require_relative_match('pressure std',p_std,ref_p_std,pressure_rel_tol)
  call require_relative_match('pressure rms',p_rms,ref_p_rms,pressure_rel_tol)
  call require_relative_match('constraint L2 RMS',constraint_l2, &
      ref_constraint_l2,constraint_rel_tol)
  if (abs(j_average-ref_j_average) > j_abs_tol) then
    write(*,'(A,ES16.8,A,ES16.8,A,ES12.4)') &
        'average J value=',j_average,' ref=',ref_j_average, &
        ' abserr=',abs(j_average-ref_j_average)
    error stop 'Fully incompressible parity average J tolerans disi.'
  end if

  write(*,'(A)') 'Fully incompressible matched Q9/P1 <-> FEniCSx Q2/DPC1:'
  write(*,'(A,ES16.8,A,ES12.4)') '  midpoint=',midpoint, &
      ' relerr=',relative_error(midpoint,ref_midpoint)
  write(*,'(A,ES16.8,A,ES12.4)') '  p_mean=',p_mean, &
      ' relerr=',relative_error(p_mean,ref_p_mean)
  write(*,'(A,ES16.8,A,ES12.4)') '  p_std=',p_std, &
      ' relerr=',relative_error(p_std,ref_p_std)
  write(*,'(A,ES16.8,A,ES12.4)') '  p_rms=',p_rms, &
      ' relerr=',relative_error(p_rms,ref_p_rms)
  write(*,'(A,ES16.8,A,ES12.4)') '  constraint_L2=',constraint_l2, &
      ' relerr=',relative_error(constraint_l2,ref_constraint_l2)
  write(*,'(A,ES16.8,A,ES12.4)') '  J_average=',j_average, &
      ' abserr=',abs(j_average-ref_j_average)
  write(*,'(A,ES12.4,A,ES12.4,A,ES12.4)') &
      '  Ru_inf=',report%displacement_residual_inf_norm, &
      ' Rp_inf=',report%pressure_residual_inf_norm, &
      ' pointwise_C_inf=',report%volumetric_constraint_inf_norm
  write(*,'(A)') 'Fully incompressible Q9/P1 FEniCSx mixed parity gate BASARILI.'

contains

  subroutine evaluate_integral_metrics( &
      local_mesh,u_state,p_state,mean_p,std_p,rms_p,constraint_rms,j_avg,metric_status)
    type(internal_mesh_t), intent(in) :: local_mesh
    real(dp), intent(in) :: u_state(:,:),p_state(:,:)
    real(dp), intent(out) :: mean_p,std_p,rms_p,constraint_rms,j_avg
    integer, intent(out) :: metric_status

    real(dp), parameter :: gp = 0.77459666924148337704_dp
    real(dp), parameter :: coord(3) = [-gp,0.0_dp,gp]
    real(dp), parameter :: weight1d(3) = [5.0_dp/9.0_dp,8.0_dp/9.0_dp,5.0_dp/9.0_dp]
    real(dp) :: Xe(9,2),ue(9,2),Nshape(9),dN_parent(9,2),dN_dX(9,2)
    real(dp) :: x_point(2),Jmap(2,2),det_jac,Np(3)
    real(dp) :: F11,F12,F21,F22,J,p_value,constraint,w
    real(dp) :: area,sum_p,sum_p2,sum_c2,sum_j,variance
    integer :: e,a,gx,gy,node,point_status

    metric_status = DES_STATUS_OK
    area = 0.0_dp
    sum_p = 0.0_dp
    sum_p2 = 0.0_dp
    sum_c2 = 0.0_dp
    sum_j = 0.0_dp

    do e = 1,local_mesh%element_count()
      do a = 1,9
        node = local_mesh%q9_connectivity(e,a)
        Xe(a,:) = local_mesh%coordinates(node,:)
        ue(a,:) = u_state(node,:)
      end do

      do gy = 1,3
        do gx = 1,3
          call q9_reference_gradient( &
              Xe,coord(gx),coord(gy),Nshape,dN_parent,dN_dX, &
              x_point,Jmap,det_jac,point_status)
          if (point_status /= DES_STATUS_OK) then
            metric_status = point_status
            return
          end if

          call herrmann_p1_pressure_basis(coord(gx),coord(gy),Np)
          p_value = dot_product(Np,p_state(e,:))

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
            metric_status = -998
            return
          end if

          ! Fully incompressible pointwise diagnostic: pressure compliance sifir.
          ! Weak pressure equation P1 test uzayinda exact; pointwise J-1 sifira
          ! zorlanmaz ve external referans ile ayni L2-RMS anlaminda karsilastirilir.
          constraint = J-1.0_dp
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
      metric_status = -997
      return
    end if

    mean_p = sum_p/area
    rms_p = sqrt(max(sum_p2/area,0.0_dp))
    variance = max(sum_p2/area-mean_p*mean_p,0.0_dp)
    std_p = sqrt(variance)
    constraint_rms = sqrt(max(sum_c2/area,0.0_dp))
    j_avg = sum_j/area
  end subroutine evaluate_integral_metrics

  subroutine require_relative_match(name,value,reference,tolerance)
    character(len=*), intent(in) :: name
    real(dp), intent(in) :: value,reference,tolerance
    if (relative_error(value,reference) > tolerance) then
      write(*,'(A,A,A,ES16.8,A,ES16.8,A,ES12.4)') &
          'Parity mismatch: ',trim(name),' value=',value,' ref=',reference, &
          ' relerr=',relative_error(value,reference)
      error stop 'Fully incompressible Q9/P1 FEniCSx parity tolerance asildi.'
    end if
  end subroutine require_relative_match

  real(dp) function relative_error(value,reference) result(err)
    real(dp), intent(in) :: value,reference
    err = abs(value-reference)/max(abs(reference),1.0e-14_dp)
  end function relative_error

  subroutine build_cook_q9(nx_local,ny_local,X,conn,fixed,force)
    integer, intent(in) :: nx_local,ny_local
    real(dp), allocatable, intent(out) :: X(:,:),force(:)
    integer, allocatable, intent(out) :: conn(:,:),fixed(:)
    real(dp), parameter :: y_right_bottom = 44.0_dp/48.0_dp
    real(dp), parameter :: y_right_top = 60.0_dp/48.0_dp
    real(dp), parameter :: y_left_top = 44.0_dp/48.0_dp
    real(dp) :: s,t,left_y,right_y,traction(2)
    integer :: npx_local,npy,ix,iy,node,e,i,j,cursor,edge_nodes(3)

    npx_local = 2*nx_local+1
    npy = 2*ny_local+1
    allocate(X(npx_local*npy,2),conn(nx_local*ny_local,9))
    allocate(fixed(2*npy),force(2*npx_local*npy))
    force = 0.0_dp

    do iy = 0,2*ny_local
      t = real(iy,dp)/real(2*ny_local,dp)
      left_y = t*y_left_top
      right_y = (1.0_dp-t)*y_right_bottom+t*y_right_top
      do ix = 0,2*nx_local
        s = real(ix,dp)/real(2*nx_local,dp)
        node = 1+iy*npx_local+ix
        X(node,1) = s
        X(node,2) = (1.0_dp-s)*left_y+s*right_y
      end do
    end do

    e = 0
    do j = 0,ny_local-1
      do i = 0,nx_local-1
        e = e+1
        conn(e,1) = q9_node_id(2*i,2*j,npx_local)
        conn(e,2) = q9_node_id(2*i+2,2*j,npx_local)
        conn(e,3) = q9_node_id(2*i+2,2*j+2,npx_local)
        conn(e,4) = q9_node_id(2*i,2*j+2,npx_local)
        conn(e,5) = q9_node_id(2*i+1,2*j,npx_local)
        conn(e,6) = q9_node_id(2*i+2,2*j+1,npx_local)
        conn(e,7) = q9_node_id(2*i+1,2*j+2,npx_local)
        conn(e,8) = q9_node_id(2*i,2*j+1,npx_local)
        conn(e,9) = q9_node_id(2*i+1,2*j+1,npx_local)
      end do
    end do

    cursor = 0
    do iy = 0,2*ny_local
      node = q9_node_id(0,iy,npx_local)
      cursor = cursor+1
      fixed(cursor) = 2*node-1
      cursor = cursor+1
      fixed(cursor) = 2*node
    end do

    traction = [0.0_dp,0.01_dp]
    do j = 0,ny_local-1
      e = j*nx_local+nx_local
      edge_nodes = [conn(e,2),conn(e,6),conn(e,3)]
      call add_q9_reference_edge_traction(X,edge_nodes,traction,force)
    end do
  end subroutine build_cook_q9

  integer function q9_node_id(ix,iy,npx_local) result(node)
    integer, intent(in) :: ix,iy,npx_local
    node = 1+iy*npx_local+ix
  end function q9_node_id

  subroutine add_q9_reference_edge_traction(X,edge_nodes,traction,force)
    real(dp), intent(in) :: X(:,:),traction(2)
    integer, intent(in) :: edge_nodes(3)
    real(dp), intent(inout) :: force(:)
    real(dp), parameter :: gp_edge = 0.77459666924148337704_dp
    real(dp), parameter :: coord_edge(3) = [-gp_edge,0.0_dp,gp_edge]
    real(dp), parameter :: weights_edge(3) = [ &
        5.0_dp/9.0_dp,8.0_dp/9.0_dp,5.0_dp/9.0_dp]
    real(dp) :: Nedge(3),dNedge(3),r,dxdr,dydr,jac
    integer :: g,a,node

    do g = 1,3
      r = coord_edge(g)
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
        force(2*node-1) = force(2*node-1)+Nedge(a)*traction(1)*jac*weights_edge(g)
        force(2*node) = force(2*node)+Nedge(a)*traction(2)*jac*weights_edge(g)
      end do
    end do
  end subroutine add_q9_reference_edge_traction

end program test_v03_herrmann_fenicsx_fully_incompressible_parity
