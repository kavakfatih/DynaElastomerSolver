program test_q4_plane_strain_element
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_material_types, only : neo_hookean_parameters_t
  use des_q4_plane_strain_neo_hookean, only : evaluate_q4_plane_strain_element
  implicit none

  real(dp) :: X(4,2), u(4,2), up(4,2), um(4,2)
  real(dp) :: residual(8), rp(8), rm(8), K(8,8), Ktmp(8,8)
  real(dp) :: min_j, min_j_tmp, eps, max_error, scale, fd
  type(neo_hookean_parameters_t) :: p
  integer :: status, status_tmp, col, row, node, comp

  ! Hafif distorsiyonlu konveks bir Q4: referans mapping'in sabit dikdörtgene özel kalmaması test edilir.
  X(1,:) = [0.0_dp, 0.0_dp]
  X(2,:) = [1.2_dp, 0.05_dp]
  X(3,:) = [1.1_dp, 0.95_dp]
  X(4,:) = [-0.05_dp, 1.0_dp]

  ! Büyük olmayan fakat gerçekten nonlinear/affine olmayan bir displacement state.
  u(1,:) = [ 0.00_dp,  0.00_dp]
  u(2,:) = [ 0.09_dp, -0.01_dp]
  u(3,:) = [ 0.14_dp,  0.07_dp]
  u(4,:) = [ 0.02_dp,  0.05_dp]

  p%mu = 2.4_dp
  p%lambda = 25.0_dp

  call evaluate_q4_plane_strain_element(X, u, p, residual, K, status, min_j)
  if (status /= DES_STATUS_OK) error stop 'Q4 element ana state degerlendirmesi basarisiz.'
  if (min_j <= 0.0_dp) error stop 'Q4 element pozitif J uretmeliydi.'

  ! Element seviyesinde consistent tangent doğrudan residual finite-difference'i ile kontrol edilir.
  eps = 1.0e-7_dp
  max_error = 0.0_dp
  scale = max(1.0_dp, maxval(abs(K)))

  do col = 1,8
    node = (col+1)/2
    comp = col - 2*(node-1)
    up = u
    um = u
    up(node,comp) = up(node,comp) + eps
    um(node,comp) = um(node,comp) - eps

    call evaluate_q4_plane_strain_element(X, up, p, rp, Ktmp, status_tmp, min_j_tmp)
    if (status_tmp /= DES_STATUS_OK) error stop 'Pozitif FD perturbasyonu basarisiz.'
    call evaluate_q4_plane_strain_element(X, um, p, rm, Ktmp, status_tmp, min_j_tmp)
    if (status_tmp /= DES_STATUS_OK) error stop 'Negatif FD perturbasyonu basarisiz.'

    do row = 1,8
      fd = (rp(row)-rm(row))/(2.0_dp*eps)
      max_error = max(max_error, abs(fd-K(row,col)))
    end do
  end do

  if (max_error/scale > 5.0e-7_dp) then
    write(*,'(A,ES12.4)') 'Q4 normalized tangent error = ', max_error/scale
    error stop 'Q4 element tangent finite-difference kontrolunu gecemedi.'
  end if

  ! Referans state'te P=0 olduğundan iç residual sıfır olmalıdır.
  u = 0.0_dp
  call evaluate_q4_plane_strain_element(X, u, p, residual, K, status, min_j)
  if (status /= DES_STATUS_OK) error stop 'Q4 referans state basarisiz.'
  if (maxval(abs(residual)) > 1.0e-12_dp) error stop 'Q4 referans residual sifir degil.'

  write(*,'(A,ES12.4)') 'Q4 normalized tangent error = ', max_error/scale
  write(*,'(A)') 'Q4 plane-strain element testi BASARILI.'
end program test_q4_plane_strain_element
