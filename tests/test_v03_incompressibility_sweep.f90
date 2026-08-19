program test_v03_incompressibility_sweep
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_material_types, only : neo_hookean_parameters_t
  use des_internal_mesh, only : internal_mesh_t, initialize_q4_internal_mesh
  use des_q4_edge_traction, only : Q4_EDGE_RIGHT
  use des_q4_mesh_edge_traction, only : add_q4_reference_edge_traction
  use des_q4_plane_strain_newton_solver, only : newton_report_t
  use des_q4_plane_strain_force_solver, only : solve_q4_plane_strain_force_control
  use des_q4_plane_strain_mixed_up_force_solver, only : &
      solve_q4_plane_strain_mixed_up_force_control
  use des_q4_plane_strain_fbar_force_solver, only : &
      solve_q4_plane_strain_fbar_force_control
  implicit none

  real(dp), parameter :: lambdas(3) = [10.0_dp,100.0_dp,1000.0_dp]
  real(dp) :: tip_disp(3),tip_mixed(3),tip_fbar(3)
  real(dp) :: displacement_drop,mixed_drop,fbar_drop
  real(dp) :: mixed_fbar_gap
  integer :: k,json_unit,ios

  do k = 1,3
    call solve_displacement_case(lambdas(k),tip_disp(k))
    call solve_mixed_case(lambdas(k),tip_mixed(k))
    call solve_fbar_case(lambdas(k),tip_fbar(k))
  end do

  if (.not. (tip_disp(1) > tip_disp(2) .and. tip_disp(2) > tip_disp(3))) then
    error stop 'Displacement Q4 lambda/mu sweep beklenen locking trendini göstermedi.'
  end if

  displacement_drop = 1.0_dp-tip_disp(3)/tip_disp(1)
  mixed_drop = 1.0_dp-tip_mixed(3)/tip_mixed(1)
  fbar_drop = 1.0_dp-tip_fbar(3)/tip_fbar(1)

  ! Full-integration displacement Q4 nearly-incompressible sınıra gidildikçe
  ! belirgin biçimde yapay rijitleşmelidir. Mixed ve F-bar aynı ölçekte bu kadar
  ! büyük volumetrik locking göstermemelidir.
  if (displacement_drop < 0.50_dp) then
    error stop 'Displacement Q4 incompressibility sweep locking sinyali yeterince güçlü değil.'
  end if
  if (mixed_drop > 0.20_dp) then
    error stop 'Mixed Q4/P0 incompressibility sweep beklenenden fazla rijitleşti.'
  end if
  if (fbar_drop > 0.20_dp) then
    error stop 'F-bar incompressibility sweep beklenenden fazla rijitleşti.'
  end if

  ! En nearly-incompressible noktada mixed ve F-bar aynı çözüm ailesine yaklaşmalı.
  mixed_fbar_gap = abs(tip_fbar(3)-tip_mixed(3))/max(abs(tip_fbar(3)),tiny(1.0_dp))
  if (mixed_fbar_gap > 0.15_dp) then
    error stop 'Mixed ve F-bar lambda/mu=1000 sonuçları beklenen yakınlığı göstermedi.'
  end if

  write(*,'(A)') 'V0.3 4x4 Cook incompressibility sweep:'
  do k = 1,3
    write(*,'(A,F8.1,3(A,ES14.6))') &
      '  lambda/mu=',lambdas(k), &
      ' displacement=',tip_disp(k), &
      ' mixed=',tip_mixed(k), &
      ' fbar=',tip_fbar(k)
  end do
  write(*,'(A,F8.3,A)') '  displacement lambda10->1000 drop = ',100.0_dp*displacement_drop,' %'
  write(*,'(A,F8.3,A)') '  mixed lambda10->1000 drop        = ',100.0_dp*mixed_drop,' %'
  write(*,'(A,F8.3,A)') '  F-bar lambda10->1000 drop        = ',100.0_dp*fbar_drop,' %'
  write(*,'(A,F8.3,A)') '  mixed/F-bar lambda1000 tip farkı = ',100.0_dp*mixed_fbar_gap,' %'

  ! Sweep sonucu log parse edilmeden doğrudan test executable'ı tarafından yazılır.
  open(newunit=json_unit,file='V0.3_INCOMPRESSIBILITY_SWEEP_RESULTS.json', &
       status='replace',action='write',iostat=ios)
  if (ios /= 0) error stop 'V0.3 incompressibility sweep JSON dosyası açılamadı.'
  call write_sweep_json(json_unit,tip_disp,tip_mixed,tip_fbar, &
                        displacement_drop,mixed_drop,fbar_drop,mixed_fbar_gap)
  close(json_unit)

  write(*,'(A)') 'V0.3 incompressibility sweep testi BASARILI.'

contains

  subroutine write_sweep_json(unit,displacement,mixed,fbar, &
                              drop_displacement,drop_mixed,drop_fbar,mixed_fbar_gap_value)
    integer, intent(in) :: unit
    real(dp), intent(in) :: displacement(3),mixed(3),fbar(3)
    real(dp), intent(in) :: drop_displacement,drop_mixed,drop_fbar,mixed_fbar_gap_value

    write(unit,'(A)') '{'
    write(unit,'(A)') '  "schema_version": 1,'
    write(unit,'(A)') '  "status": "fortran_ctest_measurement",'
    write(unit,'(A)') '  "benchmark": "cook_4x4_incompressibility_lambda_mu_sweep",'
    write(unit,'(A)') '  "plane_condition": "plane_strain",'
    write(unit,'(A)') '  "mu": 1.0,'
    write(unit,'(A)') '  "reference_nominal_traction_y": 0.01,'
    write(unit,'(A)') '  "load_increments": 5,'
    write(unit,'(A,3(ES24.16E3,A))') &
      '  "lambda_over_mu": [',lambdas(1),',',lambdas(2),',',lambdas(3),'],'
    write(unit,'(A)') '  "tip_displacement": {'
    call write_three_values(unit,'displacement_q4',displacement,.true.)
    call write_three_values(unit,'mixed_q4_p0',mixed,.true.)
    call write_three_values(unit,'fbar_q4',fbar,.false.)
    write(unit,'(A)') '  },'
    write(unit,'(A)') '  "lambda10_to_1000_drop": {'
    write(unit,'(A,ES24.16E3,A)') '    "displacement_q4": ',drop_displacement,','
    write(unit,'(A,ES24.16E3,A)') '    "mixed_q4_p0": ',drop_mixed,','
    write(unit,'(A,ES24.16E3)')   '    "fbar_q4": ',drop_fbar
    write(unit,'(A)') '  },'
    write(unit,'(A,ES24.16E3)') &
      '  "mixed_fbar_relative_tip_difference_at_lambda1000": ',mixed_fbar_gap_value
    write(unit,'(A)') '}'
  end subroutine write_sweep_json

  subroutine write_three_values(unit,name,values,with_comma)
    integer, intent(in) :: unit
    character(len=*), intent(in) :: name
    real(dp), intent(in) :: values(3)
    logical, intent(in) :: with_comma

    if (with_comma) then
      write(unit,'(A,3(ES24.16E3,A))') &
        '    "'//trim(name)//'": [',values(1),',',values(2),',',values(3),'],'
    else
      write(unit,'(A,3(ES24.16E3,A))') &
        '    "'//trim(name)//'": [',values(1),',',values(2),',',values(3),']'
    end if
  end subroutine write_three_values

  subroutine solve_displacement_case(lame_lambda,tip)
    real(dp), intent(in) :: lame_lambda
    real(dp), intent(out) :: tip
    real(dp), allocatable :: X(:,:),u(:,:),external_force(:),residual(:)
    integer, allocatable :: connectivity(:,:),fixed_dofs(:)
    type(neo_hookean_parameters_t) :: p
    type(newton_report_t) :: report
    integer :: tip_node

    call prepare_case(X,connectivity,fixed_dofs,external_force)
    allocate(u(size(X,1),2),residual(2*size(X,1)))
    u = 0.0_dp
    p%mu = 1.0_dp
    p%lambda = lame_lambda

    call solve_q4_plane_strain_force_control( &
        X,connectivity,p,fixed_dofs,external_force,5,30,1.0e-9_dp,u,residual,report)
    if (.not. report%converged .or. report%status /= DES_STATUS_OK) then
      error stop 'Incompressibility sweep displacement solve yakınsamadı.'
    end if

    tip_node = 1 + 2*5 + 4
    tip = u(tip_node,2)
  end subroutine solve_displacement_case

  subroutine solve_mixed_case(lame_lambda,tip)
    real(dp), intent(in) :: lame_lambda
    real(dp), intent(out) :: tip
    real(dp), allocatable :: X(:,:),u(:,:),pressure(:),external_force(:),residual(:)
    integer, allocatable :: connectivity(:,:),fixed_dofs(:)
    type(neo_hookean_parameters_t) :: p
    type(newton_report_t) :: report
    integer :: tip_node,nnode,nelem

    call prepare_case(X,connectivity,fixed_dofs,external_force)
    nnode = size(X,1)
    nelem = size(connectivity,1)
    allocate(u(nnode,2),pressure(nelem),residual(2*nnode+nelem))
    u = 0.0_dp
    pressure = 0.0_dp
    p%mu = 1.0_dp
    p%lambda = lame_lambda

    call solve_q4_plane_strain_mixed_up_force_control( &
        X,connectivity,p,fixed_dofs,external_force,5,30,1.0e-9_dp, &
        u,pressure,residual,report)
    if (.not. report%converged .or. report%status /= DES_STATUS_OK) then
      error stop 'Incompressibility sweep mixed solve yakınsamadı.'
    end if

    tip_node = 1 + 2*5 + 4
    tip = u(tip_node,2)
  end subroutine solve_mixed_case

  subroutine solve_fbar_case(lame_lambda,tip)
    real(dp), intent(in) :: lame_lambda
    real(dp), intent(out) :: tip
    real(dp), allocatable :: X(:,:),u(:,:),external_force(:),residual(:)
    integer, allocatable :: connectivity(:,:),fixed_dofs(:)
    type(neo_hookean_parameters_t) :: p
    type(newton_report_t) :: report
    integer :: tip_node

    call prepare_case(X,connectivity,fixed_dofs,external_force)
    allocate(u(size(X,1),2),residual(2*size(X,1)))
    u = 0.0_dp
    p%mu = 1.0_dp
    p%lambda = lame_lambda

    call solve_q4_plane_strain_fbar_force_control( &
        X,connectivity,p,fixed_dofs,external_force,5,35,2.0e-8_dp,u,residual,report)
    if (.not. report%converged .or. report%status /= DES_STATUS_OK) then
      error stop 'Incompressibility sweep F-bar solve yakınsamadı.'
    end if

    tip_node = 1 + 2*5 + 4
    tip = u(tip_node,2)
  end subroutine solve_fbar_case

  subroutine prepare_case(X,connectivity,fixed_dofs,external_force)
    real(dp), allocatable, intent(out) :: X(:,:),external_force(:)
    integer, allocatable, intent(out) :: connectivity(:,:),fixed_dofs(:)
    type(internal_mesh_t) :: mesh
    real(dp) :: traction(2),edge_length
    integer :: j,node,element_id,cursor,status

    call build_cook_mesh(4,4,X,connectivity)
    allocate(fixed_dofs(10),external_force(2*size(X,1)))
    external_force = 0.0_dp

    call initialize_q4_internal_mesh(mesh,X,connectivity,status)
    if (status /= DES_STATUS_OK) error stop 'Sweep Cook mesh oluşturulamadı.'

    cursor = 0
    do j = 0,4
      node = 1 + j*5
      cursor = cursor + 1
      fixed_dofs(cursor) = 2*node-1
      cursor = cursor + 1
      fixed_dofs(cursor) = 2*node
    end do

    traction = [0.0_dp,0.01_dp]
    do j = 0,3
      element_id = j*4 + 4
      call add_q4_reference_edge_traction( &
          mesh,element_id,Q4_EDGE_RIGHT,traction,external_force,status,edge_length)
      if (status /= DES_STATUS_OK .or. edge_length <= 0.0_dp) then
        error stop 'Sweep Cook traction assembly başarısız.'
      end if
    end do
  end subroutine prepare_case

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
      right_y = (1.0_dp-t)*y_right_bottom+t*y_right_top
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

end program test_v03_incompressibility_sweep
