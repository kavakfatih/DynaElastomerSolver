program test_neo_hookean_material_point
  use des_kinds, only : dp
  use des_material_types, only : material_kinematics_t, material_response_t, neo_hookean_parameters_t
  use des_neo_hookean, only : evaluate_neo_hookean
  implicit none

  type(material_kinematics_t) :: kin, kin_plus, kin_minus
  type(material_response_t) :: r, rp, rm
  type(neo_hookean_parameters_t) :: p
  real(dp) :: eps, max_abs_error, scale, error
  integer :: i, j, k, l

  p%mu = 2.3_dp
  p%lambda = 19.0_dp

  ! Genel bir finite-strain state seçilir; diagonal olmayan terimler de özellikle vardır.
  kin%F = reshape([ &
    1.12_dp, 0.03_dp, 0.00_dp, &
    0.08_dp, 0.94_dp, 0.02_dp, &
    0.00_dp, 0.04_dp, 1.05_dp ], [3,3])

  call evaluate_neo_hookean(kin, p, r)

  if (.not. r%valid) error stop 'Neo-Hookean response gecersiz.'
  if (r%energy <= 0.0_dp) error stop 'Enerji pozitif olmali.'

  ! Analitik dP/dF tensörü merkezi finite-difference ile kontrol edilir.
  eps = 1.0e-7_dp
  max_abs_error = 0.0_dp
  scale = max(1.0_dp, maxval(abs(r%tangent)))

  do k = 1,3
    do l = 1,3
      kin_plus = kin
      kin_minus = kin

      kin_plus%F(k,l) = kin_plus%F(k,l) + eps
      kin_minus%F(k,l) = kin_minus%F(k,l) - eps

      call evaluate_neo_hookean(kin_plus, p, rp)
      call evaluate_neo_hookean(kin_minus, p, rm)

      if (.not. rp%valid .or. .not. rm%valid) then
        error stop 'Finite-difference perturbasyonu gecersiz state uretti.'
      end if

      do i = 1,3
        do j = 1,3
          error = abs((rp%P(i,j)-rm%P(i,j))/(2.0_dp*eps) - r%tangent(i,j,k,l))
          max_abs_error = max(max_abs_error, error)
        end do
      end do
    end do
  end do

  if (max_abs_error/scale > 2.0e-7_dp) then
    write(*,'(A,ES12.4)') 'Normalize tangent hatasi: ', max_abs_error/scale
    error stop 'Analitik tangent finite-difference kontrolunu gecemedi.'
  end if

  write(*,'(A,F12.8)') 'J = ', r%J
  write(*,'(A,ES12.4)') 'Normalize tangent hatasi = ', max_abs_error/scale
  write(*,'(A)') 'Neo-Hookean material-point testi BASARILI.'
end program test_neo_hookean_material_point
