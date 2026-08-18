program test_v03_fbar_cook_baseline
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_material_types, only : neo_hookean_parameters_t
  use des_internal_mesh, only : internal_mesh_t, initialize_q4_internal_mesh
  use des_q4_edge_traction, only : Q4_EDGE_RIGHT
  use des_q4_mesh_edge_traction, only : add_q4_reference_edge_traction
  use des_q4_plane_strain_newton_solver, only : newton_report_t
  use des_q4_plane_strain_fbar_force_solver, only : &
      solve_q4_plane_strain_fbar_force_control
  implicit none

  real(dp) :: tip_2,tip_4,tip_8,minj_2,minj_4,minj_8

  call run_fbar_cook_case(2,tip_2,minj_2)
  call run_fbar_cook_case(4,tip_4,minj_4)
  call run_fbar_cook_case(8,tip_8,minj_8)

  if (.not. (tip_2 < tip_4 .and. tip_4 < tip_8)) then
    error stop 'F-bar Cook mesh-refinement displacement sıralaması bozuldu.'
  end if
  if (tip_2 <= 0.0_dp .or. min(minj_2,min(minj_4,minj_8)) <= 0.0_dp) then
    error stop 'F-bar Cook fiziksel pozitiflik kontrolü başarısız.'
  end if

  write(*,'(A,ES14.6,A,ES14.6)') '2x2 F-bar tip=',tip_2,' minJ=',minj_2
  write(*,'(A,ES14.6,A,ES14.6)') '4x4 F-bar tip=',tip_4,' minJ=',minj_4
  write(*,'(A,ES14.6,A,ES14.6)') '8x8 F-bar tip=',tip_8,' minJ=',minj_8
  write(*,'(A,F8.3,A)') 'F-bar coarse-to-8x8 gap = ', &
    100.0_dp*(1.0_dp-tip_2/tip_8),' %'
  write(*,'(A)') 'V0.3 F-bar Cook baseline testi BASARILI.'

contains

  subroutine run_fbar_cook_case(n,tip_displacement,min_j_result)
    integer, intent(in) :: n
    real(dp), intent(out) :: tip_displacement,min_j_result

    real(dp), allocatable :: X(:,:),u(:,:),residual(:),external_force(:)
    integer, allocatable :: connectivity(:,:),fixed_dofs(:)
    type(internal_mesh_t) :: mesh
    type(neo_hookean_parameters_t) :: parameters
    type(newton_report_t) :: report
    real(dp) :: traction(2),edge_length
    integer :: nnode,ndisp,j,node,element_id,cursor,status,tip_node

    call build_cook_mesh(n,n,X,connectivity)
    nnode = size(X,1)
    ndisp = 2*nnode
    allocate(u(nnode,2),residual(ndisp),external_force(ndisp))
    allocate(fixed_dofs(2*(n+1)))
    u = 0.0_dp
    external_force = 0.0_dp

    call initialize_q4_internal_mesh(mesh,X,connectivity,status)
    if (status /= DES_STATUS_OK) error stop 'F-bar Cook mesh oluşturulamadı.'

    cursor = 0
    do j = 0,n
      node = 1 + j*(n+1)
      cursor = cursor + 1
      fixed_dofs(cursor) = 2*node-1
      cursor = cursor + 1
      fixed_dofs(cursor) = 2*node
    end do

    traction = [0.0_dp,0.01_dp]
    do j = 0,n-1
      element_id = j*n+n
      call add_q4_reference_edge_traction( &
          mesh,element_id,Q4_EDGE_RIGHT,traction, &
          external_force,status,edge_length)
      if (status /= DES_STATUS_OK) error stop 'F-bar Cook traction assembly başarısız.'
    end do

    parameters%mu = 1.0_dp
    parameters%lambda = 1000.0_dp

    call solve_q4_plane_strain_fbar_force_control( &
        X,connectivity,parameters,fixed_dofs,external_force, &
        5,35,2.0e-8_dp,u,residual,report)

    if (.not. report%converged .or. report%status /= DES_STATUS_OK) then
      error stop 'F-bar Cook benchmark yakınsamadı.'
    end if

    j = n/2
    tip_node = 1 + j*(n+1)+n
    tip_displacement = u(tip_node,2)
    min_j_result = report%min_j
  end subroutine run_fbar_cook_case

  subroutine build_cook_mesh(nx,ny,X,connectivity)
    integer, intent(in) :: nx,ny
    real(dp), allocatable, intent(out) :: X(:,:)
    integer, allocatable, intent(out) :: connectivity(:,:)
    real(dp), parameter :: y_right_bottom = 44.0_dp/48.0_dp
    real(dp), parameter :: y_right_top = 60.0_dp/48.0_dp
    real(dp), parameter :: y_left_top = 44.0_dp/48.0_dp
    real(dp) :: s,t,left_y,right_y
    integer :: i,j,node,e,n1,n2,n3,n4

    allocate(X((nx+1)*(ny+1),2))
    allocate(connectivity(nx*ny,4))

    do j = 0,ny
      t = real(j,dp)/real(ny,dp)
      left_y = t*y_left_top
      right_y = (1.0_dp-t)*y_right_bottom + t*y_right_top
      do i = 0,nx
        s = real(i,dp)/real(nx,dp)
        node = 1 + j*(nx+1)+i
        X(node,1) = s
        X(node,2) = (1.0_dp-s)*left_y+s*right_y
      end do
    end do

    e = 0
    do j = 0,ny-1
      do i = 0,nx-1
        n1 = 1 + j*(nx+1)+i
        n2 = n1+1
        n4 = n1+(nx+1)
        n3 = n4+1
        e = e+1
        connectivity(e,:) = [n1,n2,n3,n4]
      end do
    end do
  end subroutine build_cook_mesh

end program test_v03_fbar_cook_baseline
