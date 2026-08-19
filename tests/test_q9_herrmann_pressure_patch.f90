program test_q9_herrmann_pressure_patch
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_internal_mesh, only : internal_mesh_t, initialize_q9_internal_mesh
  use des_q4_plane_strain_newton_solver, only : newton_report_t
  use des_q9_internal_mesh_herrmann_assembly, only : assemble_q9_internal_mesh_herrmann
  use des_q9_plane_strain_herrmann_force_solver, only : &
      solve_q9_internal_mesh_herrmann_adaptive_force_control
  implicit none

  integer, parameter :: ncase = 4
  real(dp) :: X(9,2),u_target(9,2),u(9,2)
  real(dp) :: pressure_cases(ncase,3),p_target(1,3),p(1,3)
  real(dp) :: residual_target(21),residual(21),K_target(21,21),external_force(18)
  integer :: connectivity(1,9)
  integer, parameter :: fixed_dofs(3) = [1,2,7]
  real(dp), parameter :: shear_modulus = 2.0_dp
  real(dp), parameter :: pressure_compliance = 0.0_dp
  real(dp), parameter :: alpha = 2.0e-2_dp
  real(dp), parameter :: beta = 1.0_dp/(1.0_dp+alpha)-1.0_dp
  real(dp), parameter :: displacement_tol = 1.0e-7_dp
  real(dp), parameter :: pressure_tol = 1.0e-7_dp
  real(dp), parameter :: residual_tol = 1.0e-9_dp
  real(dp) :: J_target,min_j,max_u_error,max_p_error,max_rp
  integer :: status,a,k
  type(internal_mesh_t) :: mesh
  type(newton_report_t) :: report

  X(1,:) = [0.0_dp,0.0_dp]
  X(2,:) = [1.0_dp,0.0_dp]
  X(3,:) = [1.0_dp,1.0_dp]
  X(4,:) = [0.0_dp,1.0_dp]
  X(5,:) = [0.5_dp,0.0_dp]
  X(6,:) = [1.0_dp,0.5_dp]
  X(7,:) = [0.5_dp,1.0_dp]
  X(8,:) = [0.0_dp,0.5_dp]
  X(9,:) = [0.5_dp,0.5_dp]
  connectivity(1,:) = [1,2,3,4,5,6,7,8,9]

  call initialize_q9_internal_mesh(mesh,X,connectivity,status)
  if (status /= DES_STATUS_OK) error stop 'Q9/P1 pressure patch mesh olusturulamadi.'

  do a = 1,9
    u_target(a,1) = alpha*X(a,1)
    u_target(a,2) = beta*X(a,2)
  end do
  J_target = (1.0_dp+alpha)*(1.0_dp+beta)
  if (abs(J_target-1.0_dp) > 5.0e-15_dp) then
    error stop 'Q9/P1 pressure patch manufactured state J=1 degil.'
  end if

  ! P1 pressure basis katsayilari [1, xi, eta]. Tek tek ve birlikte tum
  ! pressure mode'lari fully-incompressible manufactured state uzerinde sinanir.
  pressure_cases(1,:) = [ 1.50e-1_dp, 0.00e0_dp,  0.00e0_dp]
  pressure_cases(2,:) = [ 0.00e0_dp, 8.00e-2_dp,  0.00e0_dp]
  pressure_cases(3,:) = [ 0.00e0_dp, 0.00e0_dp, -6.00e-2_dp]
  pressure_cases(4,:) = [ 1.50e-1_dp, 8.00e-2_dp, -6.00e-2_dp]

  do k = 1,ncase
    p_target = 0.0_dp
    p_target(1,:) = pressure_cases(k,:)

    ! c_p=0 icin pressure denklemi yalniz J-1 weak constraint'idir. J=1 olan
    ! affine displacement alani tum P1 pressure katsayilari icin admissible'dir.
    ! Hedef state'ten uretilen tutarli nodal yuk, solver'in pressure mode'unu
    ! displacement ile birlikte geri kazanmasini zorunlu kilar.
    call assemble_q9_internal_mesh_herrmann( &
        mesh,u_target,p_target,shear_modulus,pressure_compliance, &
        residual_target,K_target,status,min_j)
    if (status /= DES_STATUS_OK) error stop 'Q9/P1 pressure patch target assembly basarisiz.'

    max_rp = maxval(abs(residual_target(19:21)))
    if (max_rp > 2.0e-12_dp) then
      error stop 'Q9/P1 pressure patch target weak constraint residual sifir degil.'
    end if
    external_force = residual_target(1:18)

    u = 0.0_dp
    p = 0.0_dp
    call solve_q9_internal_mesh_herrmann_adaptive_force_control( &
        mesh,shear_modulus,pressure_compliance,fixed_dofs,external_force, &
        0.2_dp,0.0125_dp,0.5_dp,6,45,1.0e-11_dp, &
        u,p,residual,report)

    if (.not. report%converged .or. report%status /= DES_STATUS_OK) then
      error stop 'Q9/P1 pressure patch nonlinear solver yakinsamadi.'
    end if

    max_u_error = maxval(abs(u-u_target))
    max_p_error = maxval(abs(p-p_target))
    max_rp = maxval(abs(residual(19:21)))

    if (max_u_error > displacement_tol) then
      error stop 'Q9/P1 pressure patch displacement recovery tolerans disi.'
    end if
    if (max_p_error > pressure_tol) then
      error stop 'Q9/P1 pressure patch pressure-mode recovery tolerans disi.'
    end if
    if (max_rp > residual_tol) then
      error stop 'Q9/P1 pressure patch final pressure residual tolerans disi.'
    end if
    if (report%min_j <= 0.0_dp) then
      error stop 'Q9/P1 pressure patch cozumunde J pozitif degil.'
    end if

    write(*,'(A,I0,A,3(ES12.4,1X))') &
        'Pressure patch case ',k,' target coeffs=',pressure_cases(k,:)
    write(*,'(A,ES12.4,A,ES12.4,A,ES12.4)') &
        '  max|du|=',max_u_error,' max|dp|=',max_p_error,' max|Rp|=',max_rp
  end do

  write(*,'(A,ES12.4)') 'Q9/P1 pressure patch target J = ',J_target
  write(*,'(A)') 'Q9/P1 sabit + xi + eta + birlesik P1 pressure patch testi BASARILI.'
end program test_q9_herrmann_pressure_patch
