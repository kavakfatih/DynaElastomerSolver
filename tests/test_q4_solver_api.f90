program test_q4_solver_api
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_material_types, only : neo_hookean_parameters_t
  use des_q4_plane_strain_newton_solver, only : newton_report_t, solve_q4_plane_strain_displacement_control
  implicit none

  real(dp) :: X(6,2), u(6,2), residual(12)
  integer :: connectivity(2,4)
  integer, parameter :: prescribed_dofs(5) = [1,2,5,7,11]
  real(dp), parameter :: prescribed_values(5) = [0.0_dp,0.0_dp,0.5_dp,0.0_dp,0.5_dp]
  real(dp) :: lambda_x, lambda_y_ref, reaction_right, reaction_ref, error_rel
  type(neo_hookean_parameters_t) :: p
  type(newton_report_t) :: report

  X(1,:) = [0.0_dp,0.0_dp]
  X(2,:) = [1.0_dp,0.0_dp]
  X(3,:) = [2.0_dp,0.0_dp]
  X(4,:) = [0.0_dp,1.0_dp]
  X(5,:) = [1.0_dp,1.0_dp]
  X(6,:) = [2.0_dp,1.0_dp]
  connectivity(1,:) = [1,2,5,4]
  connectivity(2,:) = [2,3,6,5]

  p%mu = 2.5_dp
  p%lambda = 20.0_dp
  u = 0.0_dp

  call solve_q4_plane_strain_displacement_control( &
    X, connectivity, p, prescribed_dofs, prescribed_values, &
    5, 25, 2.0e-11_dp, u, residual, report)

  if (.not. report%converged .or. report%status /= DES_STATUS_OK) then
    error stop 'Minimal Full Newton solver API benchmarki yakinsamadi.'
  end if
  if (report%increments_converged /= 5) error stop 'Tum incrementler converged olmali.'
  if (report%total_iterations <= 0) error stop 'Nonlinear benchmark Newton iterasyonu yapmadi.'

  lambda_x = 1.25_dp
  lambda_y_ref = solve_lateral_stretch(lambda_x,p%mu,p%lambda)
  reaction_right = residual(5)+residual(11)
  reaction_ref = p%mu*lambda_x + (p%lambda*log(lambda_x*lambda_y_ref)-p%mu)/lambda_x
  error_rel = abs(reaction_right-reaction_ref)/max(1.0_dp,abs(reaction_ref))

  if (error_rel > 3.0e-9_dp) error stop 'Solver API reaksiyonu analitik referansla uyusmuyor.'
  if (abs(u(2,1)-0.25_dp) > 3.0e-10_dp .or. abs(u(5,1)-0.25_dp) > 3.0e-10_dp) then
    error stop 'Solver API affine orta kolon displacementini uretmedi.'
  end if
  if (abs((1.0_dp+u(5,2))-lambda_y_ref) > 3.0e-10_dp) then
    error stop 'Solver API lateral contraction referansla uyusmuyor.'
  end if

  write(*,'(A,I0)') 'Total Newton iterations = ', report%total_iterations
  write(*,'(A,ES12.4)') 'Final free residual norm = ', report%final_residual_norm
  write(*,'(A,ES12.4)') 'Solver API reaction relative error = ', error_rel
  write(*,'(A)') 'Minimal Q4 Full Newton solver API testi BASARILI.'
contains
  function solve_lateral_stretch(lambda_x_value, mu, lame_lambda) result(lambda_y)
    real(dp), intent(in) :: lambda_x_value, mu, lame_lambda
    real(dp) :: lambda_y, lo, hi, mid, flo, fmid
    integer :: iter
    lo=0.2_dp; hi=1.5_dp
    flo=lateral_equation(lo,lambda_x_value,mu,lame_lambda)
    do iter=1,100
      mid=0.5_dp*(lo+hi)
      fmid=lateral_equation(mid,lambda_x_value,mu,lame_lambda)
      if (abs(fmid)<1.0e-14_dp) exit
      if (flo*fmid<=0.0_dp) then
        hi=mid
      else
        lo=mid; flo=fmid
      end if
    end do
    lambda_y=mid
  end function solve_lateral_stretch

  pure function lateral_equation(lambda_y,lambda_x_value,mu,lame_lambda) result(value)
    real(dp), intent(in) :: lambda_y,lambda_x_value,mu,lame_lambda
    real(dp) :: value,J
    J=lambda_x_value*lambda_y
    value=mu*lambda_y+(lame_lambda*log(J)-mu)/lambda_y
  end function lateral_equation
end program test_q4_solver_api
