program test_q4_mixed_up_mesh
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONSTRAINT
  use des_material_types, only : neo_hookean_parameters_t
  use des_q4_plane_strain_mesh_neo_hookean, only : assemble_q4_plane_strain_mesh
  use des_q4_plane_strain_mixed_up_mesh, only : assemble_q4_plane_strain_mixed_up_mesh
  implicit none

  real(dp), parameter :: tol = 2.0e-11_dp
  real(dp) :: X(6,2), u(6,2), pressure(2)
  integer :: connectivity(2,4)
  real(dp) :: mixed_residual(14), mixed_tangent(14,14), mixed_min_j
  real(dp) :: old_residual(12), old_tangent(12,12), old_min_j
  real(dp) :: F11, F22, J
  real(dp) :: bad_residual(13), bad_tangent(13,13)
  integer :: status
  type(neo_hookean_parameters_t) :: p

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
  F11 = 1.12_dp
  F22 = 0.93_dp
  J = F11*F22

  u(:,1) = (F11-1.0_dp)*X(:,1)
  u(:,2) = (F22-1.0_dp)*X(:,2)
  pressure = p%lambda*log(J)

  call assemble_q4_plane_strain_mixed_up_mesh( &
      X, connectivity, u, pressure, p, &
      mixed_residual, mixed_tangent, status, mixed_min_j)
  if (status /= DES_STATUS_OK) error stop 'Mixed u-p global assembly başarısız.'
  if (abs(mixed_residual(13)) > tol .or. abs(mixed_residual(14)) > tol) then
    error stop 'Homojen mixed pressure residualı sıfır değil.'
  end if
  if (maxval(abs(mixed_tangent-transpose(mixed_tangent))) > 5.0e-11_dp) then
    error stop 'Mixed global tangent simetrik değil.'
  end if

  call assemble_q4_plane_strain_mesh( &
      X, connectivity, u, p, old_residual, old_tangent, status, old_min_j)
  if (status /= DES_STATUS_OK) error stop 'Displacement-only referans assembly başarısız.'
  if (maxval(abs(mixed_residual(1:12)-old_residual)) > tol) then
    error stop 'Homojen mixed displacement residualı displacement-only referansla eşleşmiyor.'
  end if
  if (abs(mixed_min_j-old_min_j) > tol) error stop 'Mixed minimum J referansla eşleşmiyor.'

  ! Pressure boyutu eleman sayısıyla birebir eşleşmelidir.
  call check_invalid_pressure_size(X, connectivity, u, p)

  write(*,'(A,ES14.6)') 'Mixed global tangent symmetry error = ', &
    maxval(abs(mixed_tangent-transpose(mixed_tangent)))
  write(*,'(A)') 'Q4-P0 mixed u-p global assembly testi BASARILI.'

contains

  subroutine check_invalid_pressure_size(Xv, conn, uv, parameters)
    real(dp), intent(in) :: Xv(:,:), uv(:,:)
    integer, intent(in) :: conn(:,:)
    type(neo_hookean_parameters_t), intent(in) :: parameters
    real(dp) :: wrong_pressure(1), local_min_j
    integer :: local_status

    wrong_pressure = 0.0_dp
    call assemble_q4_plane_strain_mixed_up_mesh( &
        Xv, conn, uv, wrong_pressure, parameters, &
        bad_residual, bad_tangent, local_status, local_min_j)
    if (local_status /= DES_ERROR_INVALID_CONSTRAINT) then
      error stop 'Yanlış pressure DOF boyutu reddedilmedi.'
    end if
  end subroutine check_invalid_pressure_size

end program test_q4_mixed_up_mesh
