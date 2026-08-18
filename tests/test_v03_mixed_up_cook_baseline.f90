program test_v03_mixed_up_cook_baseline
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_material_types, only : neo_hookean_parameters_t
  use des_internal_mesh, only : internal_mesh_t, initialize_q4_internal_mesh
  use des_pressure_diagnostics, only : pressure_diagnostics_t, &
                                       evaluate_q4_pressure_diagnostics
  use des_q4_edge_traction, only : Q4_EDGE_RIGHT
  use des_q4_mesh_edge_traction, only : add_q4_reference_edge_traction
  use des_q4_plane_strain_newton_solver, only : newton_report_t
  use des_q4_plane_strain_mixed_up_force_solver, only : &
      solve_q4_plane_strain_mixed_up_force_control
  implicit none

  real(dp) :: tip_2, tip_4, tip_8
  type(pressure_diagnostics_t) :: pd_2, pd_4, pd_8

  call run_mixed_cook_case(2,tip_2,pd_2)
  call run_mixed_cook_case(4,tip_4,pd_4)
  call run_mixed_cook_case(8,tip_8,pd_8)

  if (.not. (tip_2 < tip_4 .and. tip_4 < tip_8)) then
    error stop 'Mixed u-p Cook mesh-refinement displacement sıralaması bozuldu.'
  end if
  if (tip_2 <= 0.0_dp .or. tip_8 <= 0.0_dp) then
    error stop 'Mixed u-p Cook tip displacement pozitif değil.'
  end if
  if (.not. pd_2%valid .or. .not. pd_4%valid .or. .not. pd_8%valid) then
    error stop 'Mixed Cook pressure diagnostics geçersiz.'
  end if
  if (pd_2%neighbor_pair_count <= 0 .or. pd_4%neighbor_pair_count <= 0 .or. &
      pd_8%neighbor_pair_count <= 0) then
    error stop 'Mixed Cook pressure neighbor graph oluşmadı.'
  end if

  call print_case('2x2',tip_2,pd_2)
  call print_case('4x4',tip_4,pd_4)
  call print_case('8x8',tip_8,pd_8)
  write(*,'(A)') 'V0.3 Q4-P0 mixed u-p Cook baseline testi BASARILI.'

contains

  subroutine run_mixed_cook_case(n,tip_displacement,pd)
    integer, intent(in) :: n
    real(dp), intent(out) :: tip_displacement
    type(pressure_diagnostics_t), intent(out) :: pd

    real(dp), allocatable :: X(:,:),u(:,:),pressure(:),residual(:)
    real(dp), allocatable :: external_force(:)
    integer, allocatable :: connectivity(:,:),fixed_dofs(:)
    type(internal_mesh_t) :: mesh
    type(neo_hookean_parameters_t) :: parameters
    type(newton_report_t) :: report
    real(dp) :: traction(2),edge_length
    integer :: nnode,nelem,ndisp
    integer :: j,node,element_id,cursor,status,tip_node

    call build_cook_mesh(n,n,X,connectivity)
    nnode = size(X,1)
    nelem = size(connectivity,1)
    ndisp = 2*nnode

    allocate(u(nnode,2),pressure(nelem),residual(ndisp+nelem))
    allocate(external_force(ndisp),fixed_dofs(2*(n+1)))
    u = 0.0_dp
    pressure = 0.0_dp
    external_force = 0.0_dp

    call initialize_q4_internal_mesh(mesh,X,connectivity,status)
    if (status /= DES_STATUS_OK) error stop 'Mixed Cook mesh oluşturulamadı.'

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
      element_id = j*n + n
      call add_q4_reference_edge_traction( &
          mesh,element_id,Q4_EDGE_RIGHT,traction, &
          external_force,status,edge_length)
      if (status /= DES_STATUS_OK) error stop 'Mixed Cook traction assembly başarısız.'
    end do

    parameters%mu = 1.0_dp
    parameters%lambda = 1000.0_dp

    call solve_q4_plane_strain_mixed_up_force_control( &
        X,connectivity,parameters,fixed_dofs,external_force, &
        5,30,1.0e-9_dp,u,pressure,residual,report)

    if (.not. report%converged .or. report%status /= DES_STATUS_OK) then
      error stop 'Mixed u-p Cook benchmark yakınsamadı.'
    end if
    if (report%min_j <= 0.0_dp) error stop 'Mixed Cook non-positive J üretti.'

    j = n/2
    tip_node = 1 + j*(n+1) + n
    tip_displacement = u(tip_node,2)

    call evaluate_q4_pressure_diagnostics(connectivity,pressure,pd,status)
    if (status /= DES_STATUS_OK) error stop 'Mixed Cook pressure diagnostics başarısız.'
  end subroutine run_mixed_cook_case

  subroutine print_case(label,tip,pd)
    character(len=*), intent(in) :: label
    real(dp), intent(in) :: tip
    type(pressure_diagnostics_t), intent(in) :: pd

    write(*,'(A,A,A,ES14.6)') trim(label),': ','tip=',tip
    write(*,'(A,3(ES14.6,1X))') '  p(min/mean/max)= ',pd%minimum,pd%mean,pd%maximum
    write(*,'(A,2(ES14.6,1X))') '  p(std/rms)=      ',pd%standard_deviation,pd%rms
    write(*,'(A,3(ES14.6,1X))') '  jump(rms/max/norm)= ',pd%neighbor_jump_rms, &
      pd%maximum_neighbor_jump,pd%normalized_neighbor_jump_rms
  end subroutine print_case

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
        node = 1 + j*(nx+1) + i
        X(node,1) = s
        X(node,2) = (1.0_dp-s)*left_y + s*right_y
      end do
    end do

    e = 0
    do j = 0,ny-1
      do i = 0,nx-1
        n1 = 1 + j*(nx+1) + i
        n2 = n1 + 1
        n4 = n1 + (nx+1)
        n3 = n4 + 1
        e = e + 1
        connectivity(e,:) = [n1,n2,n3,n4]
      end do
    end do
  end subroutine build_cook_mesh

end program test_v03_mixed_up_cook_baseline
