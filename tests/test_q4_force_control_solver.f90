program test_q4_force_control_solver
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_material_types, only : neo_hookean_parameters_t
  use des_internal_mesh, only : internal_mesh_t, initialize_q4_internal_mesh
  use des_q4_edge_traction, only : Q4_EDGE_RIGHT
  use des_q4_mesh_edge_traction, only : add_q4_reference_edge_traction
  use des_q4_plane_strain_newton_solver, only : newton_report_t
  use des_q4_plane_strain_force_solver, only : solve_q4_plane_strain_force_control
  implicit none

  real(dp), parameter :: tol_u = 4.0e-10_dp
  real(dp), parameter :: tol_reaction = 5.0e-9_dp
  real(dp) :: X(4,2), u(4,2), residual(8), external_force(8)
  integer :: connectivity(1,4)
  integer, parameter :: fixed_dofs(3) = [1,2,7]
  real(dp) :: lambda_x, lambda_y_ref, traction_ref, reaction_left, edge_length
  real(dp) :: J_ref
  integer :: status
  type(internal_mesh_t) :: mesh
  type(neo_hookean_parameters_t) :: p
  type(newton_report_t) :: report

  X(1,:) = [0.0_dp, 0.0_dp]
  X(2,:) = [1.0_dp, 0.0_dp]
  X(3,:) = [1.0_dp, 1.0_dp]
  X(4,:) = [0.0_dp, 1.0_dp]
  connectivity(1,:) = [1,2,3,4]

  p%mu = 2.5_dp
  p%lambda = 20.0_dp
  lambda_x = 1.10_dp
  lambda_y_ref = solve_lateral_stretch(lambda_x, p%mu, p%lambda)
  J_ref = lambda_x*lambda_y_ref
  traction_ref = p%mu*lambda_x + (p%lambda*log(J_ref)-p%mu)/lambda_x

  call initialize_q4_internal_mesh(mesh, X, connectivity, status)
  if (status /= DES_STATUS_OK) error stop 'Force-control test mesh oluşturulamadı.'

  external_force = 0.0_dp
  call add_q4_reference_edge_traction( &
      mesh, 1, Q4_EDGE_RIGHT, [traction_ref,0.0_dp], &
      external_force, status, edge_length)
  if (status /= DES_STATUS_OK) error stop 'Analitik traction global yüke dönüştürülemedi.'
  if (abs(edge_length-1.0_dp) > 1.0e-12_dp) error stop 'Referans sağ kenar uzunluğu hatalı.'

  u = 0.0_dp
  call solve_q4_plane_strain_force_control( &
      X, connectivity, p, fixed_dofs, external_force, &
      5, 25, 2.0e-11_dp, u, residual, report)

  if (.not. report%converged .or. report%status /= DES_STATUS_OK) then
    error stop 'Force-control Full Newton analitik çekme probleminde yakınsamadı.'
  end if
  if (report%increments_converged /= 5) error stop 'Force-control tüm incrementleri tamamlamadı.'
  if (report%linear_solve_count < 1) error stop 'Force-control lineer solve çağrısı üretmedi.'
  if (report%final_residual_norm > 2.0e-11_dp) error stop 'Force-control final free residual toleransı aştı.'
  if (report%min_j <= 0.0_dp) error stop 'Force-control çözümünde J pozitif değil.'

  if (abs(u(2,1) - (lambda_x-1.0_dp)) > tol_u) error stop 'Node 2 x displacement analitik referansla uyuşmuyor.'
  if (abs(u(3,1) - (lambda_x-1.0_dp)) > tol_u) error stop 'Node 3 x displacement analitik referansla uyuşmuyor.'
  if (abs(u(2,2)) > tol_u) error stop 'Alt sağ node y displacement sıfır değil.'
  if (abs(u(3,2) - (lambda_y_ref-1.0_dp)) > tol_u) error stop 'Üst sağ lateral contraction hatalı.'
  if (abs(u(4,2) - (lambda_y_ref-1.0_dp)) > tol_u) error stop 'Üst sol lateral contraction hatalı.'

  reaction_left = residual(1) + residual(7)
  if (abs(reaction_left + traction_ref) > tol_reaction) then
    error stop 'Force-control sol kenar reaksiyonu analitik traction ile dengede değil.'
  end if

  write(*,'(A,ES14.6)') 'Analitik nominal traction = ', traction_ref
  write(*,'(A,ES14.6)') 'Force-control sol reaksiyon = ', reaction_left
  write(*,'(A,ES14.6)') 'lambda_y referans = ', lambda_y_ref
  write(*,'(A,ES14.6)') 'Final free residual = ', report%final_residual_norm
  write(*,'(A)') 'Q4 force-control solver analitik çekme testi BASARILI.'

contains

  function solve_lateral_stretch(lambda_x_value, mu, lame_lambda) result(lambda_y)
    real(dp), intent(in) :: lambda_x_value, mu, lame_lambda
    real(dp) :: lambda_y, lo, hi, mid, flo, fmid
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
    real(dp), intent(in) :: lambda_y, lambda_x_value, mu, lame_lambda
    real(dp) :: value, J

    J = lambda_x_value*lambda_y
    value = mu*lambda_y + (lame_lambda*log(J)-mu)/lambda_y
  end function lateral_equation

end program test_q4_force_control_solver
