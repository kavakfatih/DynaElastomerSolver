program test_v03_mixed_up_cook_baseline
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_tensor3, only : inverse3
  use des_material_types, only : neo_hookean_parameters_t
  use des_internal_mesh, only : internal_mesh_t, initialize_q4_internal_mesh
  use des_pressure_diagnostics, only : pressure_diagnostics_t, &
                                       evaluate_q4_pressure_diagnostics
  use des_q4_shape, only : q4_shape_functions
  use des_q4_edge_traction, only : Q4_EDGE_RIGHT
  use des_q4_mesh_edge_traction, only : add_q4_reference_edge_traction
  use des_q4_plane_strain_mixed_up_mesh, only : assemble_q4_plane_strain_mixed_up_mesh
  use des_q4_plane_strain_newton_solver, only : newton_report_t
  use des_q4_plane_strain_mixed_up_force_solver, only : &
      solve_q4_plane_strain_mixed_up_force_control
  implicit none

  real(dp) :: tip_2, tip_4, tip_8
  real(dp) :: minj_2, minj_4, minj_8
  real(dp) :: stationarity_2, stationarity_4, stationarity_8
  integer :: iter_2, iter_4, iter_8
  integer :: linear_2, linear_4, linear_8
  integer :: eq_2, eq_4, eq_8
  type(pressure_diagnostics_t) :: pd_2, pd_4, pd_8

  call run_mixed_cook_case(2,tip_2,minj_2,iter_2,linear_2,eq_2,pd_2,stationarity_2)
  call run_mixed_cook_case(4,tip_4,minj_4,iter_4,linear_4,eq_4,pd_4,stationarity_4)
  call run_mixed_cook_case(8,tip_8,minj_8,iter_8,linear_8,eq_8,pd_8,stationarity_8)

  if (.not. (tip_2 < tip_4 .and. tip_4 < tip_8)) then
    error stop 'Mixed u-p Cook mesh-refinement displacement sıralaması bozuldu.'
  end if
  if (tip_2 <= 0.0_dp .or. tip_8 <= 0.0_dp) then
    error stop 'Mixed u-p Cook tip displacement pozitif değil.'
  end if
  if (min(minj_2,min(minj_4,minj_8)) <= 0.0_dp) then
    error stop 'Mixed Cook final durumda non-positive J üretti.'
  end if
  if (.not. pd_2%valid .or. .not. pd_4%valid .or. .not. pd_8%valid) then
    error stop 'Mixed Cook pressure diagnostics geçersiz.'
  end if
  if (pd_2%neighbor_pair_count <= 0 .or. pd_4%neighbor_pair_count <= 0 .or. &
      pd_8%neighbor_pair_count <= 0) then
    error stop 'Mixed Cook pressure neighbor graph oluşmadı.'
  end if

  ! P0 pressure unknown'ı element bazında stationarity denklemini sağlamalıdır:
  ! p_e = lambda * <ln J>_e. Bu kontrol pressure alanının düzgünlüğünden ayrıdır;
  ! solver'ın kendi mixed denklemini gerçekten çözdüğünü doğrular.
  if (max(stationarity_2,max(stationarity_4,stationarity_8)) > 2.0e-4_dp) then
    error stop 'Mixed Cook pressure stationarity tutarlılığı tolerans dışında.'
  end if

  call print_case('2x2',tip_2,minj_2,iter_2,linear_2,eq_2,pd_2,stationarity_2)
  call print_case('4x4',tip_4,minj_4,iter_4,linear_4,eq_4,pd_4,stationarity_4)
  call print_case('8x8',tip_8,minj_8,iter_8,linear_8,eq_8,pd_8,stationarity_8)
  write(*,'(A)') 'V0.3 Q4-P0 mixed u-p Cook baseline testi BASARILI.'

contains

  subroutine run_mixed_cook_case(n,tip_displacement,final_min_j,total_iterations, &
                                 linear_solves,equation_count,pd,stationarity_error)
    integer, intent(in) :: n
    real(dp), intent(out) :: tip_displacement, final_min_j, stationarity_error
    integer, intent(out) :: total_iterations, linear_solves, equation_count
    type(pressure_diagnostics_t), intent(out) :: pd

    real(dp), allocatable :: X(:,:),u(:,:),pressure(:),residual(:)
    real(dp), allocatable :: external_force(:),tangent(:,:)
    integer, allocatable :: connectivity(:,:),fixed_dofs(:)
    type(internal_mesh_t) :: mesh
    type(neo_hookean_parameters_t) :: parameters
    type(newton_report_t) :: report
    real(dp) :: traction(2),edge_length
    integer :: nnode,nelem,ndisp,ntotal
    integer :: j,node,element_id,cursor,status,tip_node

    call build_cook_mesh(n,n,X,connectivity)
    nnode = size(X,1)
    nelem = size(connectivity,1)
    ndisp = 2*nnode
    ntotal = ndisp + nelem

    allocate(u(nnode,2),pressure(nelem),residual(ntotal),tangent(ntotal,ntotal))
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

    j = n/2
    tip_node = 1 + j*(n+1) + n
    tip_displacement = u(tip_node,2)

    ! Yakınsamış son durum J değeri historical Newton minimumundan ayrı ölçülür.
    call assemble_q4_plane_strain_mixed_up_mesh( &
        X,connectivity,u,pressure,parameters,residual,tangent,status,final_min_j)
    if (status /= DES_STATUS_OK) error stop 'Mixed Cook final-state assembly başarısız.'

    total_iterations = report%total_iterations
    linear_solves = report%linear_solve_count
    equation_count = report%max_linear_equation_count

    call evaluate_q4_pressure_diagnostics(connectivity,pressure,pd,status)
    if (status /= DES_STATUS_OK) error stop 'Mixed Cook pressure diagnostics başarısız.'

    call evaluate_pressure_stationarity_error( &
        X,connectivity,u,pressure,parameters%lambda,stationarity_error,status)
    if (status /= DES_STATUS_OK) error stop 'Mixed Cook pressure stationarity hesabı başarısız.'
  end subroutine run_mixed_cook_case

  subroutine print_case(label,tip,final_min_j,total_iterations,linear_solves,equation_count,pd, &
                        stationarity_error)
    character(len=*), intent(in) :: label
    real(dp), intent(in) :: tip, final_min_j, stationarity_error
    integer, intent(in) :: total_iterations, linear_solves, equation_count
    type(pressure_diagnostics_t), intent(in) :: pd

    write(*,'(A,A,A,ES14.6)') trim(label),': ','tip=',tip
    write(*,'(A,3(ES14.6,1X))') '  p(min/mean/max)= ',pd%minimum,pd%mean,pd%maximum
    write(*,'(A,2(ES14.6,1X))') '  p(std/rms)=      ',pd%standard_deviation,pd%rms
    write(*,'(A,3(ES14.6,1X))') '  jump(rms/max/norm)= ',pd%neighbor_jump_rms, &
      pd%maximum_neighbor_jump,pd%normalized_neighbor_jump_rms
    write(*,'(A,2(ES14.6,1X))') '  roughness(jump/std,graph)= ', &
      pd%neighbor_jump_to_std,pd%graph_roughness
    write(*,'(A,ES14.6)') '  pressure stationarity max error= ',stationarity_error
    write(*,'(A,ES14.6,3(A,I0))') '  solver(finalMinJ)= ',final_min_j, &
      ' iterations=',total_iterations, &
      ' linearSolves=',linear_solves, &
      ' equations=',equation_count
  end subroutine print_case

  subroutine evaluate_pressure_stationarity_error( &
      X,connectivity,u,pressure,lame_lambda,max_error,status)
    real(dp), intent(in) :: X(:,:),u(:,:),pressure(:),lame_lambda
    integer, intent(in) :: connectivity(:,:)
    real(dp), intent(out) :: max_error
    integer, intent(out) :: status

    real(dp), parameter :: gp = 0.57735026918962576451_dp
    real(dp), parameter :: gauss_xi(4) = [-gp,gp,gp,-gp]
    real(dp), parameter :: gauss_eta(4) = [-gp,-gp,gp,gp]
    real(dp) :: Xe(4,2),ue(4,2),N(4),dN_parent(4,2),dN_dX(4,2)
    real(dp) :: Jmap(2,2),invJmap(2,2),detJmap
    real(dp) :: F(3,3),Finv(3,3),J,volume,weighted_ln_j,expected_pressure
    integer :: e,g,a,i,Jdir,node
    logical :: inverse_ok

    status = DES_STATUS_OK
    max_error = 0.0_dp

    do e = 1,size(connectivity,1)
      do a = 1,4
        node = connectivity(e,a)
        Xe(a,:) = X(node,:)
        ue(a,:) = u(node,:)
      end do

      volume = 0.0_dp
      weighted_ln_j = 0.0_dp

      do g = 1,4
        call q4_shape_functions(gauss_xi(g),gauss_eta(g),N,dN_parent)
        call reference_gradient(Xe,dN_parent,Jmap,invJmap,detJmap,dN_dX)
        if (detJmap <= 0.0_dp) then
          status = -1
          return
        end if

        F = 0.0_dp
        F(1,1) = 1.0_dp
        F(2,2) = 1.0_dp
        F(3,3) = 1.0_dp
        do a = 1,4
          do i = 1,2
            do Jdir = 1,2
              F(i,Jdir) = F(i,Jdir) + ue(a,i)*dN_dX(a,Jdir)
            end do
          end do
        end do

        call inverse3(F,Finv,J,inverse_ok)
        if (.not. inverse_ok .or. J <= 0.0_dp) then
          status = -1
          return
        end if

        volume = volume + detJmap
        weighted_ln_j = weighted_ln_j + detJmap*log(J)
      end do

      expected_pressure = lame_lambda*weighted_ln_j/volume
      max_error = max(max_error,abs(pressure(e)-expected_pressure))
    end do
  end subroutine evaluate_pressure_stationarity_error

  pure subroutine reference_gradient(X,dN_parent,Jmap,invJmap,detJmap,dN_dX)
    real(dp), intent(in) :: X(4,2),dN_parent(4,2)
    real(dp), intent(out) :: Jmap(2,2),invJmap(2,2),detJmap,dN_dX(4,2)
    integer :: a

    Jmap = 0.0_dp
    do a = 1,4
      Jmap(1,1) = Jmap(1,1) + dN_parent(a,1)*X(a,1)
      Jmap(1,2) = Jmap(1,2) + dN_parent(a,1)*X(a,2)
      Jmap(2,1) = Jmap(2,1) + dN_parent(a,2)*X(a,1)
      Jmap(2,2) = Jmap(2,2) + dN_parent(a,2)*X(a,2)
    end do

    detJmap = Jmap(1,1)*Jmap(2,2) - Jmap(1,2)*Jmap(2,1)
    if (abs(detJmap) <= 100.0_dp*epsilon(1.0_dp)) then
      invJmap = 0.0_dp
      dN_dX = 0.0_dp
      return
    end if

    invJmap(1,1) =  Jmap(2,2)/detJmap
    invJmap(1,2) = -Jmap(1,2)/detJmap
    invJmap(2,1) = -Jmap(2,1)/detJmap
    invJmap(2,2) =  Jmap(1,1)/detJmap

    do a = 1,4
      dN_dX(a,1) = invJmap(1,1)*dN_parent(a,1) &
                  + invJmap(1,2)*dN_parent(a,2)
      dN_dX(a,2) = invJmap(2,1)*dN_parent(a,1) &
                  + invJmap(2,2)*dN_parent(a,2)
    end do
  end subroutine reference_gradient

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
