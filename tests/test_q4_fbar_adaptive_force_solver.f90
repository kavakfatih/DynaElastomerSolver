program test_q4_fbar_adaptive_force_solver
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_CUTBACK_EXHAUSTED
  use des_material_types, only : neo_hookean_parameters_t
  use des_internal_mesh, only : internal_mesh_t, initialize_q4_internal_mesh
  use des_integration_point_results, only : integration_point_results_t
  use des_q4_edge_traction, only : Q4_EDGE_RIGHT
  use des_q4_mesh_edge_traction, only : add_q4_reference_edge_traction
  use des_q4_plane_strain_newton_solver, only : newton_report_t
  use des_q4_plane_strain_fbar_force_solver, only : &
      solve_q4_plane_strain_fbar_force_control, &
      solve_q4_plane_strain_fbar_adaptive_force_control
  implicit none

  real(dp) :: X(4,2),u(4,2),u_ref(4,2),u_fail(4,2)
  real(dp) :: residual(8),residual_ref(8),residual_fail(8),external_force(8)
  integer :: connectivity(1,4)
  integer, parameter :: fixed_dofs(3) = [1,2,7]
  real(dp) :: lambda_x,lambda_y_ref,J_ref,traction_ref,edge_length
  integer :: status
  type(internal_mesh_t) :: mesh
  type(neo_hookean_parameters_t) :: p
  type(newton_report_t) :: report,report_ref,report_fail
  type(integration_point_results_t) :: results

  X(1,:) = [0.0_dp,0.0_dp]
  X(2,:) = [1.0_dp,0.0_dp]
  X(3,:) = [1.0_dp,1.0_dp]
  X(4,:) = [0.0_dp,1.0_dp]
  connectivity(1,:) = [1,2,3,4]

  p%mu = 2.5_dp
  p%lambda = 20.0_dp
  lambda_x = 1.10_dp
  lambda_y_ref = solve_lateral_stretch(lambda_x,p%mu,p%lambda)
  J_ref = lambda_x*lambda_y_ref
  traction_ref = p%mu*lambda_x+(p%lambda*log(J_ref)-p%mu)/lambda_x

  call initialize_q4_internal_mesh(mesh,X,connectivity,status)
  if (status /= DES_STATUS_OK) error stop 'Adaptive F-bar test mesh oluşturulamadı.'

  external_force = 0.0_dp
  call add_q4_reference_edge_traction( &
      mesh,1,Q4_EDGE_RIGHT,[traction_ref,0.0_dp], &
      external_force,status,edge_length)
  if (status /= DES_STATUS_OK) error stop 'Adaptive F-bar traction assembly başarısız.'

  ! Bir Newton iterasyonu bilerek yetersiz bırakılır. Her başarısız denemede
  ! trial state revert edilmeli ve cutback limiti sonunda committed state korunmalıdır.
  u_fail = 0.0_dp
  call solve_q4_plane_strain_fbar_adaptive_force_control( &
      X,connectivity,p,fixed_dofs,external_force, &
      1.0_dp,0.125_dp,0.5_dp,2,1,1.0e-12_dp, &
      u_fail,residual_fail,report_fail)

  if (report_fail%status /= DES_ERROR_CUTBACK_EXHAUSTED) then
    error stop 'Adaptive F-bar cutback exhaustion status hatalı.'
  end if
  if (report_fail%converged) error stop 'Exhausted çözüm yakınsamış görünmemeli.'
  if (report_fail%cutback_count /= 3) error stop 'Adaptive F-bar cutback sayısı hatalı.'
  if (report_fail%state_commit_count /= 0) error stop 'Başarısız trial commit edildi.'
  if (report_fail%state_revert_count /= 3) error stop 'Trial revert sayısı hatalı.'
  if (maxval(abs(u_fail)) > 1.0e-14_dp) then
    error stop 'Cutback exhaustion committed displacement stateini bozdu.'
  end if

  ! Normal adaptive çözüm aynı fiziksel final state'i sabit 5-increment
  ! referans çözümle üretmelidir.
  u = 0.0_dp
  u_ref = 0.0_dp
  call solve_q4_plane_strain_fbar_adaptive_force_control( &
      X,connectivity,p,fixed_dofs,external_force, &
      0.2_dp,0.025_dp,0.5_dp,4,30,5.0e-9_dp, &
      u,residual,report,integration_results=results)

  call solve_q4_plane_strain_fbar_force_control( &
      X,connectivity,p,fixed_dofs,external_force, &
      5,30,5.0e-9_dp,u_ref,residual_ref,report_ref)

  if (.not. report%converged .or. report%status /= DES_STATUS_OK) then
    error stop 'Adaptive F-bar force-control yakınsamadı.'
  end if
  if (.not. report_ref%converged .or. report_ref%status /= DES_STATUS_OK) then
    error stop 'Sabit F-bar referans çözüm yakınsamadı.'
  end if
  if (abs(report%final_load_factor-1.0_dp) > 1.0e-14_dp) then
    error stop 'Adaptive F-bar final load factor 1.0 değil.'
  end if
  if (report%state_commit_count /= report%increments_converged) then
    error stop 'Adaptive F-bar commit sayısı yakınsayan incrementlerle uyumsuz.'
  end if
  if (maxval(abs(u-u_ref)) > 2.0e-8_dp) then
    error stop 'Adaptive ve sabit F-bar displacement sonuçları farklı.'
  end if
  if (maxval(abs(residual-residual_ref)) > 2.0e-7_dp) then
    error stop 'Adaptive ve sabit F-bar reaction sonuçları farklı.'
  end if
  if (results%count() /= 4) then
    error stop 'Adaptive F-bar final state için 4 Gauss sonucu bekleniyordu.'
  end if

  write(*,'(A,I0)') 'Adaptive F-bar committed increment = ',report%state_commit_count
  write(*,'(A,I0)') 'Adaptive F-bar exhaustion revert = ',report_fail%state_revert_count
  write(*,'(A,ES12.4)') 'Adaptive F-bar final residual = ',report%final_residual_norm
  write(*,'(A)') 'Q4 F-bar adaptive force-control testi BASARILI.'

contains

  function solve_lateral_stretch(lambda_x_value,mu,lame_lambda) result(lambda_y)
    real(dp), intent(in) :: lambda_x_value,mu,lame_lambda
    real(dp) :: lambda_y,lo,hi,mid,flo,fmid
    integer :: iter

    lo = 0.2_dp
    hi = 1.5_dp
    flo = lateral_equation(lo,lambda_x_value,mu,lame_lambda)
    do iter = 1,100
      mid = 0.5_dp*(lo+hi)
      fmid = lateral_equation(mid,lambda_x_value,mu,lame_lambda)
      if (abs(fmid) < 1.0e-14_dp) exit
      if (flo*fmid <= 0.0_dp) then
        hi = mid
      else
        lo = mid
        flo = fmid
      end if
    end do
    lambda_y = mid
  end function solve_lateral_stretch

  pure function lateral_equation(lambda_y,lambda_x_value,mu,lame_lambda) result(value)
    real(dp), intent(in) :: lambda_y,lambda_x_value,mu,lame_lambda
    real(dp) :: value,J

    J = lambda_x_value*lambda_y
    value = mu*lambda_y+(lame_lambda*log(J)-mu)/lambda_y
  end function lateral_equation

end program test_q4_fbar_adaptive_force_solver
