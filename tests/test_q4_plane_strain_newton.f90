program test_q4_plane_strain_newton
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_tensor3, only : inverse3
  use des_material_types, only : neo_hookean_parameters_t
  use des_q4_plane_strain_neo_hookean, only : evaluate_q4_plane_strain_element
  implicit none

  real(dp) :: X(4,2), u(4,2), residual(8), K(8,8), min_j
  real(dp) :: Kff(3,3), Kff_inv(3,3), rhs(3), du(3), detK
  real(dp) :: target_extension, current_extension, reaction_right, reaction_left
  real(dp) :: lambda_x, lambda_y_ref, reaction_ref, error_rel
  type(neo_hookean_parameters_t) :: p
  integer, parameter :: free_dofs(3) = [4, 6, 8]
  integer :: status, increment, iteration, a, b
  logical :: ok, converged
  real(dp), parameter :: tol = 1.0e-11_dp
  integer, parameter :: n_increments = 5
  integer, parameter :: max_iterations = 20

  X(1,:) = [0.0_dp, 0.0_dp]
  X(2,:) = [1.0_dp, 0.0_dp]
  X(3,:) = [1.0_dp, 1.0_dp]
  X(4,:) = [0.0_dp, 1.0_dp]

  p%mu = 2.5_dp
  p%lambda = 20.0_dp
  target_extension = 0.25_dp
  u = 0.0_dp

  do increment = 1, n_increments
    current_extension = target_extension*real(increment,dp)/real(n_increments,dp)

    ! Sol kenar ux=0; sağ kenar ux=delta. Node 1 uy=0 rigid-body düşey modunu kaldırır.
    u(1,1) = 0.0_dp
    u(4,1) = 0.0_dp
    u(2,1) = current_extension
    u(3,1) = current_extension
    u(1,2) = 0.0_dp

    converged = .false.
    do iteration = 1, max_iterations
      call evaluate_q4_plane_strain_element(X, u, p, residual, K, status, min_j)
      if (status /= DES_STATUS_OK) error stop 'Newton sirasinda element degerlendirmesi basarisiz.'

      rhs = -residual(free_dofs)
      if (maxval(abs(rhs)) < tol) then
        converged = .true.
        exit
      end if

      do a = 1,3
        do b = 1,3
          Kff(a,b) = K(free_dofs(a), free_dofs(b))
        end do
      end do

      call inverse3(Kff, Kff_inv, detK, ok)
      if (.not. ok) error stop 'Newton reduced tangent singular.'
      du = matmul(Kff_inv, rhs)

      u(2,2) = u(2,2) + du(1)
      u(3,2) = u(3,2) + du(2)
      u(4,2) = u(4,2) + du(3)
    end do

    if (.not. converged) error stop 'Increment Full Newton ile yakinsamadi.'
  end do

  call evaluate_q4_plane_strain_element(X, u, p, residual, K, status, min_j)
  if (status /= DES_STATUS_OK) error stop 'Final element degerlendirmesi basarisiz.'

  reaction_right = residual(3) + residual(5)
  reaction_left = residual(1) + residual(7)

  ! Bağımsız homojen plane-strain referansı:
  ! F=diag(lambda_x, lambda_y, 1), serbest lateral sınır için P22=0.
  lambda_x = 1.0_dp + target_extension
  lambda_y_ref = solve_lateral_stretch(lambda_x, p%mu, p%lambda)
  reaction_ref = p%mu*lambda_x + (p%lambda*log(lambda_x*lambda_y_ref)-p%mu)/lambda_x

  error_rel = abs(reaction_right-reaction_ref)/max(1.0_dp, abs(reaction_ref))
  if (error_rel > 2.0e-9_dp) then
    write(*,'(A,3ES18.8)') 'FE/ref/relative reaction: ', reaction_right, reaction_ref, error_rel
    error stop 'Q4 Newton reaksiyonu homojen referansla uyusmuyor.'
  end if

  if (abs(reaction_right + reaction_left) > 1.0e-10_dp) then
    error stop 'Global x kuvvet dengesi saglanmiyor.'
  end if

  if (abs(u(2,2)) > 1.0e-10_dp) error stop 'Alt sag dugum homojen cozumde uy=0 olmali.'
  if (abs(u(3,2)-u(4,2)) > 1.0e-10_dp) error stop 'Ust dugumler ayni lateral contraction gostermeli.'
  if (abs((1.0_dp+u(3,2))-lambda_y_ref) > 2.0e-10_dp) then
    error stop 'FE lateral stretch homojen referansla uyusmuyor.'
  end if

  write(*,'(A,F10.6)') 'Final lambda_x = ', lambda_x
  write(*,'(A,F10.6)') 'Final lambda_y = ', 1.0_dp + u(3,2)
  write(*,'(A,ES12.4)') 'Reaction relative error = ', error_rel
  write(*,'(A)') 'Q4 incremental Full Newton benchmark BASARILI.'
contains

  function solve_lateral_stretch(lambda_x_value, mu, lame_lambda) result(lambda_y)
    real(dp), intent(in) :: lambda_x_value, mu, lame_lambda
    real(dp) :: lambda_y
    real(dp) :: lo, hi, mid, flo, fmid
    integer :: iter

    lo = 0.2_dp
    hi = 1.5_dp
    flo = lateral_equation(lo, lambda_x_value, mu, lame_lambda)

    do iter = 1,100
      mid = 0.5_dp*(lo+hi)
      fmid = lateral_equation(mid, lambda_x_value, mu, lame_lambda)
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
end program test_q4_plane_strain_newton
