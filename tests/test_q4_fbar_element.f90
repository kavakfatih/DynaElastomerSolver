program test_q4_fbar_element
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_material_types, only : neo_hookean_parameters_t
  use des_q4_plane_strain_neo_hookean, only : evaluate_q4_plane_strain_element
  use des_q4_plane_strain_fbar_neo_hookean, only : &
      evaluate_q4_plane_strain_fbar_element
  implicit none

  real(dp), parameter :: residual_tol = 2.0e-10_dp
  real(dp), parameter :: tangent_tol = 8.0e-6_dp
  real(dp), parameter :: symmetry_tol = 8.0e-6_dp
  real(dp), parameter :: h_test = 8.0e-7_dp
  real(dp) :: X(4,2), u(4,2), up(4,2), um(4,2)
  real(dp) :: r_fbar(8), K_fbar(8,8), rp(8), rm(8), Kdummy(8,8)
  real(dp) :: r_standard(8), K_standard(8,8)
  real(dp) :: min_j, min_j_dummy, jbar, jbar_dummy
  real(dp) :: tangent_fd(8,8), relative_error, symmetry_error, scale
  real(dp) :: F11, F22
  integer :: status, local_status, dof, node, comp
  type(neo_hookean_parameters_t) :: p

  X(1,:) = [0.0_dp,0.0_dp]
  X(2,:) = [1.0_dp,0.0_dp]
  X(3,:) = [1.0_dp,1.0_dp]
  X(4,:) = [0.0_dp,1.0_dp]
  p%mu = 2.3_dp
  p%lambda = 19.0_dp

  ! Homojen affine durumda J tüm Gauss noktalarında aynı olduğundan F-bar düzeltmesi
  ! bire eşit olmalı ve internal-force residual standart Q4 ile eşleşmelidir.
  F11 = 1.10_dp
  F22 = 0.95_dp
  u(1,:) = [0.0_dp,0.0_dp]
  u(2,:) = [F11-1.0_dp,0.0_dp]
  u(3,:) = [F11-1.0_dp,F22-1.0_dp]
  u(4,:) = [0.0_dp,F22-1.0_dp]

  call evaluate_q4_plane_strain_fbar_element( &
      X,u,p,r_fbar,K_fbar,status,min_j,jbar)
  if (status /= DES_STATUS_OK) error stop 'Homojen F-bar element başarısız.'
  call evaluate_q4_plane_strain_element( &
      X,u,p,r_standard,K_standard,status,min_j_dummy)
  if (status /= DES_STATUS_OK) error stop 'Standart Q4 referansı başarısız.'

  if (abs(jbar-F11*F22) > residual_tol) error stop 'F-bar J_bar homojen referansla uyuşmuyor.'
  if (maxval(abs(r_fbar-r_standard)) > residual_tol) then
    error stop 'Homojen F-bar residualı standart Q4 ile eşleşmiyor.'
  end if

  ! Non-affine durumda ilk prototip tangent'i bağımsız daha geniş adımlı FD ile
  ! regression kontrolünden geçirilir.
  u(1,:) = [ 0.00_dp, 0.00_dp]
  u(2,:) = [ 0.08_dp,-0.01_dp]
  u(3,:) = [ 0.11_dp, 0.04_dp]
  u(4,:) = [-0.02_dp, 0.03_dp]

  call evaluate_q4_plane_strain_fbar_element( &
      X,u,p,r_fbar,K_fbar,status,min_j,jbar)
  if (status /= DES_STATUS_OK) error stop 'Non-affine F-bar element başarısız.'
  if (min_j <= 0.0_dp .or. jbar <= 0.0_dp) error stop 'F-bar J ölçüleri pozitif değil.'

  do dof = 1,8
    node = (dof+1)/2
    comp = dof - 2*(node-1)
    up = u
    um = u
    up(node,comp) = up(node,comp) + h_test
    um(node,comp) = um(node,comp) - h_test

    call evaluate_q4_plane_strain_fbar_element( &
        X,up,p,rp,Kdummy,local_status,min_j_dummy,jbar_dummy)
    if (local_status /= DES_STATUS_OK) error stop 'F-bar pozitif test perturbasyonu başarısız.'
    call evaluate_q4_plane_strain_fbar_element( &
        X,um,p,rm,Kdummy,local_status,min_j_dummy,jbar_dummy)
    if (local_status /= DES_STATUS_OK) error stop 'F-bar negatif test perturbasyonu başarısız.'

    tangent_fd(:,dof) = (rp-rm)/(2.0_dp*h_test)
  end do

  scale = max(1.0_dp,maxval(abs(tangent_fd)))
  relative_error = maxval(abs(K_fbar-tangent_fd))/scale
  symmetry_error = maxval(abs(K_fbar-transpose(K_fbar)))/scale

  if (relative_error > tangent_tol) then
    write(*,'(A,ES14.6)') 'F-bar tangent cross-FD error = ',relative_error
    error stop 'F-bar prototype tangent bağımsız FD ile uyuşmuyor.'
  end if
  if (symmetry_error > symmetry_tol) then
    write(*,'(A,ES14.6)') 'F-bar tangent symmetry error = ',symmetry_error
    error stop 'F-bar energy-consistent tangent beklenen simetriyi göstermiyor.'
  end if

  write(*,'(A,ES14.6)') 'F-bar tangent cross-FD relative error = ',relative_error
  write(*,'(A,ES14.6)') 'F-bar tangent symmetry error = ',symmetry_error
  write(*,'(A,ES14.6)') 'F-bar non-affine J_bar = ',jbar
  write(*,'(A)') 'Q4 F-bar prototype element testi BASARILI.'
end program test_q4_fbar_element
