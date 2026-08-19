program test_neo_hookean_isochoric
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_PARAMETERS
  use des_material_types, only : material_kinematics_t, material_response_t
  use des_neo_hookean_isochoric, only : evaluate_neo_hookean_isochoric
  implicit none

  real(dp), parameter :: mu = 2.5_dp
  real(dp), parameter :: h = 1.0e-7_dp
  real(dp), parameter :: tangent_tol = 2.0e-7_dp
  type(material_kinematics_t) :: kin, kin_plus, kin_minus
  type(material_response_t) :: response, plus_response, minus_response
  real(dp) :: fd(3,3,3,3), tangent_error, tangent_scale
  real(dp) :: trace_sigma, symmetry_error
  real(dp) :: stretch
  integer :: i,j,k,l

  ! Reference state.
  kin%F = 0.0_dp
  do i = 1,3
    kin%F(i,i) = 1.0_dp
  end do
  call evaluate_neo_hookean_isochoric(kin,mu,response)
  if (.not. response%valid .or. response%status /= DES_STATUS_OK) then
    error stop 'Isochoric Neo-Hookean reference state degerlendirilemedi.'
  end if
  if (abs(response%energy) > 1.0e-14_dp) then
    error stop 'Isochoric Neo-Hookean reference energy sifir degil.'
  end if
  if (maxval(abs(response%P)) > 1.0e-14_dp) then
    error stop 'Isochoric Neo-Hookean reference P sifir degil.'
  end if

  ! Saf hacimsel stretch isochoric enerjiyi ve gerilmeyi degistirmemelidir.
  stretch = 1.18_dp
  kin%F = 0.0_dp
  do i = 1,3
    kin%F(i,i) = stretch
  end do
  call evaluate_neo_hookean_isochoric(kin,mu,response)
  if (.not. response%valid) error stop 'Saf hacimsel isochoric state gecersiz.'
  if (abs(response%energy) > 2.0e-13_dp) then
    error stop 'Saf hacimsel deformation isochoric enerji uretti.'
  end if
  if (maxval(abs(response%P)) > 2.0e-13_dp) then
    error stop 'Saf hacimsel deformation isochoric P uretti.'
  end if
  if (maxval(abs(response%cauchy)) > 2.0e-13_dp) then
    error stop 'Saf hacimsel deformation deviatorik Cauchy gerilmesi uretti.'
  end if

  ! Genel finite deformation: Cauchy cevabi traceless olmali ve tangent FD ile uyusmali.
  kin%F = reshape([ &
      1.15_dp,0.03_dp,0.01_dp, &
      0.08_dp,0.92_dp,0.04_dp, &
      0.02_dp,0.05_dp,1.07_dp], [3,3])
  call evaluate_neo_hookean_isochoric(kin,mu,response)
  if (.not. response%valid .or. response%status /= DES_STATUS_OK) then
    error stop 'Genel isochoric Neo-Hookean state degerlendirilemedi.'
  end if

  trace_sigma = response%cauchy(1,1)+response%cauchy(2,2)+response%cauchy(3,3)
  if (abs(trace_sigma) > 2.0e-12_dp) then
    error stop 'Isochoric Cauchy gerilmesinin izi sifir degil.'
  end if

  fd = 0.0_dp
  do k = 1,3
    do l = 1,3
      kin_plus = kin
      kin_minus = kin
      kin_plus%F(k,l) = kin_plus%F(k,l)+h
      kin_minus%F(k,l) = kin_minus%F(k,l)-h
      call evaluate_neo_hookean_isochoric(kin_plus,mu,plus_response)
      call evaluate_neo_hookean_isochoric(kin_minus,mu,minus_response)
      if (.not. plus_response%valid .or. .not. minus_response%valid) then
        error stop 'Isochoric tangent FD perturbation state gecersiz.'
      end if
      fd(:,:,k,l) = (plus_response%P-minus_response%P)/(2.0_dp*h)
    end do
  end do

  tangent_scale = max(1.0_dp,maxval(abs(fd)))
  tangent_error = maxval(abs(response%tangent-fd))/tangent_scale
  if (tangent_error > tangent_tol) then
    error stop 'Isochoric Neo-Hookean analytic tangent FD ile uyusmuyor.'
  end if

  symmetry_error = 0.0_dp
  do i = 1,3
    do j = 1,3
      do k = 1,3
        do l = 1,3
          symmetry_error = max(symmetry_error, &
              abs(response%tangent(i,j,k,l)-response%tangent(k,l,i,j)))
        end do
      end do
    end do
  end do
  if (symmetry_error > 2.0e-12_dp) then
    error stop 'Isochoric hyperelastic tangent major symmetry kaybetti.'
  end if

  call evaluate_neo_hookean_isochoric(kin,-1.0_dp,response)
  if (response%status /= DES_ERROR_INVALID_PARAMETERS .or. response%valid) then
    error stop 'Gecersiz shear modulus reddedilmedi.'
  end if

  write(*,'(A,ES14.6)') 'Isochoric tangent normalized FD error = ',tangent_error
  write(*,'(A,ES14.6)') 'Isochoric tangent major symmetry = ',symmetry_error
  write(*,'(A)') 'Isochoric Neo-Hookean material contract testi BASARILI.'
end program test_neo_hookean_isochoric
