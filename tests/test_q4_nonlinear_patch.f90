program test_q4_nonlinear_patch
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_material_types, only : neo_hookean_parameters_t
  use des_q4_plane_strain_newton_solver, only : newton_report_t, solve_q4_plane_strain_displacement_control
  implicit none

  real(dp) :: X(9,2), u(9,2), residual(18), H(2,2), expected_center(2)
  integer :: connectivity(4,4)
  integer :: boundary_nodes(8), prescribed_dofs(16)
  real(dp) :: prescribed_values(16)
  type(neo_hookean_parameters_t) :: p
  type(newton_report_t) :: report
  integer :: a, node, idx
  real(dp) :: sum_fx, sum_fy, center_error

  X(1,:)=[0.0_dp,0.0_dp]
  X(2,:)=[1.0_dp,0.0_dp]
  X(3,:)=[2.0_dp,0.0_dp]
  X(4,:)=[0.0_dp,1.0_dp]
  X(5,:)=[1.08_dp,0.92_dp]
  X(6,:)=[2.0_dp,1.0_dp]
  X(7,:)=[0.0_dp,2.0_dp]
  X(8,:)=[1.0_dp,2.0_dp]
  X(9,:)=[2.0_dp,2.0_dp]

  connectivity(1,:)=[1,2,5,4]
  connectivity(2,:)=[2,3,6,5]
  connectivity(3,:)=[4,5,8,7]
  connectivity(4,:)=[5,6,9,8]

  H(1,:)=[0.12_dp,0.08_dp]
  H(2,:)=[0.03_dp,-0.04_dp]

  boundary_nodes=[1,2,3,4,6,7,8,9]
  idx=0
  do a=1,8
    node=boundary_nodes(a)
    idx=idx+1
    prescribed_dofs(idx)=2*(node-1)+1
    prescribed_values(idx)=H(1,1)*X(node,1)+H(1,2)*X(node,2)
    idx=idx+1
    prescribed_dofs(idx)=2*(node-1)+2
    prescribed_values(idx)=H(2,1)*X(node,1)+H(2,2)*X(node,2)
  end do

  p%mu=2.7_dp
  p%lambda=18.0_dp
  u=0.0_dp

  call solve_q4_plane_strain_displacement_control( &
    X, connectivity, p, prescribed_dofs, prescribed_values, &
    4, 25, 2.0e-11_dp, u, residual, report)

  if (.not. report%converged .or. report%status/=DES_STATUS_OK) then
    error stop 'Nonlinear Q4 patch solver yakinsamadi.'
  end if

  expected_center(1)=H(1,1)*X(5,1)+H(1,2)*X(5,2)
  expected_center(2)=H(2,1)*X(5,1)+H(2,2)*X(5,2)
  center_error=maxval(abs(u(5,:)-expected_center))
  if (center_error>3.0e-11_dp) then
    error stop 'Distorsiyonlu Q4 patch affine displacementi yeniden uretemedi.'
  end if

  sum_fx=sum(residual(1:18:2))
  sum_fy=sum(residual(2:18:2))
  if (abs(sum_fx)>3.0e-10_dp .or. abs(sum_fy)>3.0e-10_dp) then
    error stop 'Nonlinear patch global kuvvet dengesi kapanmadi.'
  end if

  write(*,'(A,ES12.4)') 'Patch center displacement error = ', center_error
  write(*,'(A,2ES12.4)') 'Patch global force sums = ', sum_fx, sum_fy
  write(*,'(A)') 'Distorsiyonlu nonlinear Q4 patch testi BASARILI.'
end program test_q4_nonlinear_patch
