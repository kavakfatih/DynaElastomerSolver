program test_q4_mesh_refinement
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_material_types, only : neo_hookean_parameters_t
  use des_q4_plane_strain_newton_solver, only : newton_report_t, &
       solve_q4_plane_strain_displacement_control
  implicit none

  type(neo_hookean_parameters_t) :: parameters
  real(dp) :: reaction(3), reference_reaction
  integer :: levels(3), q

  levels = [1,2,4]
  parameters%mu = 2.3_dp
  parameters%lambda = 19.0_dp

  do q = 1,3
    call run_level(levels(q), parameters, reaction(q))
  end do

  reference_reaction = reaction(1)
  if (maxval(abs(reaction-reference_reaction)) > &
      2.0e-10_dp*max(1.0_dp,abs(reference_reaction))) then
    write(*,*) reaction
    error stop 'Mesh refinement altında reaksiyon korunmadı.'
  end if

  write(*,'(A,3(ES14.6,1X))') 'Reaksiyonlar n=1,2,4: ', reaction
  write(*,'(A)') 'Q4 mesh-refinement invariance testi BASARILI.'
contains

  subroutine run_level(n, parameters, reaction_x)
    integer, intent(in) :: n
    type(neo_hookean_parameters_t), intent(in) :: parameters
    real(dp), intent(out) :: reaction_x

    real(dp), allocatable :: X(:,:), u(:,:), residual(:), prescribed_values(:)
    integer, allocatable :: connectivity(:,:), prescribed_dofs(:)
    type(newton_report_t) :: report
    integer :: nx, ny, nnode, nelem, i, j, e, node, nbc, k

    nx = n
    ny = n
    nnode = (nx+1)*(ny+1)
    nelem = nx*ny

    allocate(X(nnode,2), u(nnode,2), residual(2*nnode), connectivity(nelem,4))

    do j = 0,ny
      do i = 0,nx
        node = 1+i+j*(nx+1)
        X(node,1) = real(i,dp)/real(nx,dp)
        X(node,2) = real(j,dp)/real(ny,dp)
      end do
    end do

    e = 0
    do j = 0,ny-1
      do i = 0,nx-1
        e = e+1
        connectivity(e,1) = 1+i+j*(nx+1)
        connectivity(e,2) = connectivity(e,1)+1
        connectivity(e,4) = connectivity(e,1)+(nx+1)
        connectivity(e,3) = connectivity(e,4)+1
      end do
    end do

    ! Sol ve sağ kenarlarda x displacement tanımlanır; tek bir y DOF rigid translation'ı kaldırır.
    nbc = 2*(ny+1)+1
    allocate(prescribed_dofs(nbc), prescribed_values(nbc))
    k = 0
    do j = 0,ny
      node = 1+j*(nx+1)
      k = k+1
      prescribed_dofs(k) = 2*(node-1)+1
      prescribed_values(k) = 0.0_dp

      node = 1+nx+j*(nx+1)
      k = k+1
      prescribed_dofs(k) = 2*(node-1)+1
      prescribed_values(k) = 0.25_dp
    end do
    k = k+1
    prescribed_dofs(k) = 2
    prescribed_values(k) = 0.0_dp

    u = 0.0_dp
    call solve_q4_plane_strain_displacement_control( &
         X, connectivity, parameters, prescribed_dofs, prescribed_values, &
         5, 12, 1.0e-11_dp, u, residual, report)

    if (.not. report%converged .or. report%status /= DES_STATUS_OK) then
      error stop 'Mesh refinement seviyesi yakınsamadı.'
    end if

    reaction_x = 0.0_dp
    do j = 0,ny
      node = 1+nx+j*(nx+1)
      reaction_x = reaction_x + residual(2*(node-1)+1)
    end do
  end subroutine run_level
end program test_q4_mesh_refinement
