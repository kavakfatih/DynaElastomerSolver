program test_q4_plane_strain_mesh_newton
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_dense_linear, only : solve_dense_system
  use des_material_types, only : neo_hookean_parameters_t
  use des_q4_plane_strain_mesh_neo_hookean, only : assemble_q4_plane_strain_mesh
  implicit none

  real(dp) :: X(6,2), u(6,2), residual(12), K(12,12), min_j
  integer :: connectivity(2,4)
  integer, parameter :: free_dofs(7) = [3,4,6,8,9,10,12]
  real(dp) :: Kff(7,7), rhs(7), du(7)
  real(dp) :: target_extension, current_extension, lambda_x, lambda_y_ref
  real(dp) :: reaction_right, reaction_left, reaction_ref, error_rel
  type(neo_hookean_parameters_t) :: p
  integer :: status, increment, iteration, a, b, dof, node, comp
  logical :: ok, converged
  integer, parameter :: n_increments = 5, max_iterations = 25
  real(dp), parameter :: tol = 2.0e-11_dp

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
  target_extension = 0.5_dp
  u = 0.0_dp

  do increment = 1,n_increments
    current_extension = target_extension*real(increment,dp)/real(n_increments,dp)

    u(1,1) = 0.0_dp
    u(4,1) = 0.0_dp
    u(3,1) = current_extension
    u(6,1) = current_extension
    u(1,2) = 0.0_dp

    converged = .false.
    do iteration = 1,max_iterations
      call assemble_q4_plane_strain_mesh(X, connectivity, u, p, residual, K, status, min_j)
      if (status /= DES_STATUS_OK) error stop 'Global assembly Newton sirasinda basarisiz.'

      rhs = -residual(free_dofs)
      if (maxval(abs(rhs)) < tol) then
        converged = .true.
        exit
      end if

      do a = 1,7
        do b = 1,7
          Kff(a,b) = K(free_dofs(a),free_dofs(b))
        end do
      end do
      call solve_dense_system(Kff, rhs, du, ok)
      if (.not. ok) error stop 'Global reduced dense system cozulemedi.'

      do a = 1,7
        dof = free_dofs(a)
        node = (dof+1)/2
        comp = dof - 2*(node-1)
        u(node,comp) = u(node,comp) + du(a)
      end do
    end do
    if (.not. converged) error stop 'Cok elemanli increment Newton ile yakinsamadi.'
  end do

  call assemble_q4_plane_strain_mesh(X, connectivity, u, p, residual, K, status, min_j)
  if (status /= DES_STATUS_OK) error stop 'Final global assembly basarisiz.'

  reaction_right = residual(5) + residual(11)
  reaction_left = residual(1) + residual(7)

  lambda_x = 1.0_dp + target_extension/2.0_dp
  lambda_y_ref = solve_lateral_stretch(lambda_x, p%mu, p%lambda)
  reaction_ref = p%mu*lambda_x + (p%lambda*log(lambda_x*lambda_y_ref)-p%mu)/lambda_x
  error_rel = abs(reaction_right-reaction_ref)/max(1.0_dp,abs(reaction_ref))

  if (error_rel > 3.0e-9_dp) error stop 'Cok elemanli reaksiyon analitik referansla uyusmuyor.'
  if (abs(reaction_right+reaction_left) > 2.0e-10_dp) error stop 'Cok elemanli global kuvvet dengesi bozuk.'

  ! Affine çözümde orta kolon toplam uzamanın yarısını taşır.
  if (abs(u(2,1)-0.25_dp) > 2.0e-10_dp) error stop 'Alt orta dugum ux affine referansla uyusmuyor.'
  if (abs(u(5,1)-0.25_dp) > 2.0e-10_dp) error stop 'Ust orta dugum ux affine referansla uyusmuyor.'
  if (abs(u(2,2)) > 2.0e-10_dp .or. abs(u(3,2)) > 2.0e-10_dp) then
    error stop 'Alt kenar homojen cozumde y kaymamali.'
  end if
  if (abs((1.0_dp+u(4,2))-lambda_y_ref) > 3.0e-10_dp) error stop 'Sol ust lateral stretch hatali.'
  if (abs(u(4,2)-u(5,2)) > 2.0e-10_dp .or. abs(u(5,2)-u(6,2)) > 2.0e-10_dp) then
    error stop 'Ust kenar homojen lateral contraction gostermiyor.'
  end if

  write(*,'(A,F10.6)') '2-element lambda_x = ', lambda_x
  write(*,'(A,F10.6)') '2-element lambda_y = ', 1.0_dp+u(5,2)
  write(*,'(A,ES12.4)') '2-element reaction relative error = ', error_rel
  write(*,'(A)') 'Q4 global assembly + Full Newton benchmark BASARILI.'
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

  pure function lateral_equation(lambda_y, lambda_x_value, mu, lame_lambda) result(value)
    real(dp), intent(in) :: lambda_y, lambda_x_value, mu, lame_lambda
    real(dp) :: value, J
    J = lambda_x_value*lambda_y
    value = mu*lambda_y + (lame_lambda*log(J)-mu)/lambda_y
  end function lateral_equation
end program test_q4_plane_strain_mesh_newton
