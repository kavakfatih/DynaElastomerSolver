program test_v03_displacement_q4_locking_baseline
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_material_types, only : neo_hookean_parameters_t
  use des_internal_mesh, only : internal_mesh_t, initialize_q4_internal_mesh
  use des_q4_edge_traction, only : Q4_EDGE_RIGHT
  use des_q4_mesh_edge_traction, only : add_q4_reference_edge_traction
  use des_q4_plane_strain_newton_solver, only : newton_report_t
  use des_q4_plane_strain_force_solver, only : solve_q4_plane_strain_force_control
  implicit none

  real(dp) :: tip_2, tip_4, tip_8, locking_gap

  call run_cook_case(2, tip_2)
  call run_cook_case(4, tip_4)
  call run_cook_case(8, tip_8)

  ! Bu test displacement-only Q4'ün V0.3 baseline davranışını kaydeder.
  ! Near-incompressible durumda coarse mesh daha rijit olduğundan tip displacement
  ! mesh refinement ile artmalıdır. Mixed u-p ve F-bar daha sonra aynı benchmarka bağlanacaktır.
  if (.not. (tip_2 < tip_4 .and. tip_4 < tip_8)) then
    error stop 'Displacement Q4 locking baseline mesh-refinement sıralaması bozuldu.'
  end if

  locking_gap = 1.0_dp - tip_2/tip_8
  if (locking_gap < 0.05_dp) then
    error stop 'V0.3 displacement-Q4 baseline beklenen coarse-mesh stiffness farkını göstermedi.'
  end if

  if (tip_2 <= 0.0_dp .or. tip_8 <= 0.0_dp) then
    error stop 'Cook baseline tip displacement pozitif değil.'
  end if

  write(*,'(A,ES14.6)') 'Cook 2x2 tip displacement = ', tip_2
  write(*,'(A,ES14.6)') 'Cook 4x4 tip displacement = ', tip_4
  write(*,'(A,ES14.6)') 'Cook 8x8 tip displacement = ', tip_8
  write(*,'(A,F8.3,A)') 'Coarse-to-8x8 stiffness/locking göstergesi = ', 100.0_dp*locking_gap, ' %'
  write(*,'(A)') 'V0.3 displacement-only Q4 locking baseline testi BASARILI.'

contains

  subroutine run_cook_case(n, tip_displacement)
    integer, intent(in) :: n
    real(dp), intent(out) :: tip_displacement

    real(dp), allocatable :: X(:,:), u(:,:), residual(:), external_force(:)
    integer, allocatable :: connectivity(:,:), fixed_dofs(:)
    type(internal_mesh_t) :: mesh
    type(neo_hookean_parameters_t) :: p
    type(newton_report_t) :: report
    real(dp) :: traction(2), edge_length
    integer :: nnode, nelem, ndof
    integer :: i, j, node, element_id, cursor, status, tip_node

    call build_cook_mesh(n, n, X, connectivity)
    nnode = size(X,1)
    nelem = size(connectivity,1)
    ndof = 2*nnode

    allocate(u(nnode,2), residual(ndof), external_force(ndof))
    allocate(fixed_dofs(2*(n+1)))
    u = 0.0_dp
    external_force = 0.0_dp

    call initialize_q4_internal_mesh(mesh, X, connectivity, status)
    if (status /= DES_STATUS_OK) error stop 'Cook InternalMesh oluşturulamadı.'

    ! Sol kenar tamamen ankastre.
    cursor = 0
    do j = 0,n
      node = 1 + j*(n+1)
      cursor = cursor + 1
      fixed_dofs(cursor) = 2*node-1
      cursor = cursor + 1
      fixed_dofs(cursor) = 2*node
    end do

    ! Sağ sınır boyunca sabit yukarı nominal traction.
    traction = [0.0_dp, 0.01_dp]
    do j = 0,n-1
      element_id = j*n + n
      call add_q4_reference_edge_traction( &
          mesh, element_id, Q4_EDGE_RIGHT, traction, &
          external_force, status, edge_length)
      if (status /= DES_STATUS_OK) error stop 'Cook sağ sınır traction assembly başarısız.'
      if (edge_length <= 0.0_dp) error stop 'Cook edge uzunluğu pozitif değil.'
    end do

    p%mu = 1.0_dp
    p%lambda = 1000.0_dp

    call solve_q4_plane_strain_force_control( &
        X, connectivity, p, fixed_dofs, external_force, &
        5, 30, 1.0e-9_dp, u, residual, report)

    if (.not. report%converged .or. report%status /= DES_STATUS_OK) then
      error stop 'Cook displacement-Q4 baseline yakınsamadı.'
    end if
    if (report%final_load_factor < 1.0_dp-1.0e-12_dp) error stop 'Cook tam yüke ulaşmadı.'
    if (report%min_j <= 0.0_dp) error stop 'Cook çözümünde non-positive J oluştu.'
    if (report%max_linear_equation_count <= 0) error stop 'Cook lineer solver diagnostics oluşmadı.'

    ! Sağ kenarın orta düğümü; n=2,4,8 için tam midpoint düğümü vardır.
    j = n/2
    i = n
    tip_node = 1 + j*(n+1) + i
    tip_displacement = u(tip_node,2)

    if (nelem /= n*n) error stop 'Cook mesh element sayısı beklenenden farklı.'
  end subroutine run_cook_case

  subroutine build_cook_mesh(nx, ny, X, connectivity)
    integer, intent(in) :: nx, ny
    real(dp), allocatable, intent(out) :: X(:,:)
    integer, allocatable, intent(out) :: connectivity(:,:)

    real(dp), parameter :: y_right_bottom = 44.0_dp/48.0_dp
    real(dp), parameter :: y_right_top = 60.0_dp/48.0_dp
    real(dp), parameter :: y_left_top = 44.0_dp/48.0_dp
    real(dp) :: s, t, left_y, right_y
    integer :: i, j, node, e
    integer :: n1, n2, n3, n4

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

end program test_v03_displacement_q4_locking_baseline
