program test_neo_hookean_reference_states
  use des_kinds, only : dp
  use des_tensor3, only : identity3
  use des_material_types, only : material_kinematics_t, material_response_t, neo_hookean_parameters_t
  use des_neo_hookean, only : evaluate_neo_hookean
  implicit none

  type(material_kinematics_t) :: kin
  type(material_response_t) :: r
  type(neo_hookean_parameters_t) :: p
  real(dp) :: gamma, stretch, expected_energy, expected_sigma12, expected_sigma11
  real(dp) :: expected_pdiag, expected_j, ln_j
  real(dp), parameter :: tol = 5.0e-12_dp

  p%mu = 2.5_dp
  p%lambda = 18.0_dp

  ! 1) Referans konfigurasyon: F=I -> W=0, P=0, sigma=0, J=1.
  kin%F = identity3()
  call evaluate_neo_hookean(kin, p, r)
  call assert_true(r%valid, 'Referans konfigurasyon gecerli olmali.')
  call assert_close(r%J, 1.0_dp, tol, 'Referans J')
  call assert_close(r%energy, 0.0_dp, tol, 'Referans enerji')
  call assert_close(maxval(abs(r%P)), 0.0_dp, tol, 'Referans P')
  call assert_close(maxval(abs(r%cauchy)), 0.0_dp, tol, 'Referans Cauchy')

  ! 2) Basit kayma: det(F)=1. Bu durumda W=mu*gamma^2/2,
  ! sigma_12=mu*gamma ve sigma_11=mu*gamma^2 olmalıdır.
  gamma = 0.35_dp
  kin%F = identity3()
  kin%F(1,2) = gamma
  call evaluate_neo_hookean(kin, p, r)
  expected_energy = 0.5_dp*p%mu*gamma*gamma
  expected_sigma12 = p%mu*gamma
  expected_sigma11 = p%mu*gamma*gamma
  call assert_true(r%valid, 'Basit kayma state gecerli olmali.')
  call assert_close(r%J, 1.0_dp, tol, 'Basit kayma J')
  call assert_close(r%energy, expected_energy, tol, 'Basit kayma enerjisi')
  call assert_close(r%cauchy(1,2), expected_sigma12, tol, 'Basit kayma sigma12')
  call assert_close(r%cauchy(2,1), expected_sigma12, tol, 'Basit kayma sigma21')
  call assert_close(r%cauchy(1,1), expected_sigma11, tol, 'Basit kayma sigma11')

  ! 3) Es yonlu hacimsel uzama: F=s*I. P diyagonalinin kapali formu kontrol edilir.
  stretch = 1.08_dp
  kin%F = stretch*identity3()
  call evaluate_neo_hookean(kin, p, r)
  expected_j = stretch**3
  ln_j = log(expected_j)
  expected_pdiag = p%mu*stretch + (p%lambda*ln_j - p%mu)/stretch
  call assert_true(r%valid, 'Hacimsel uzama state gecerli olmali.')
  call assert_close(r%J, expected_j, tol, 'Hacimsel J')
  call assert_close(r%P(1,1), expected_pdiag, tol, 'Hacimsel P11')
  call assert_close(r%P(2,2), expected_pdiag, tol, 'Hacimsel P22')
  call assert_close(r%P(3,3), expected_pdiag, tol, 'Hacimsel P33')
  call assert_close(r%P(1,2), 0.0_dp, tol, 'Hacimsel P12')

  write(*,'(A)') 'Neo-Hookean referans state testleri BASARILI.'
contains
  subroutine assert_close(actual, expected, tolerance, label)
    real(dp), intent(in) :: actual, expected, tolerance
    character(len=*), intent(in) :: label
    if (abs(actual-expected) > tolerance*max(1.0_dp, abs(expected))) then
      write(*,'(A,2ES18.8)') trim(label)//' actual/expected: ', actual, expected
      error stop 'Referans state karsilastirmasi basarisiz.'
    end if
  end subroutine assert_close

  subroutine assert_true(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) error stop message
  end subroutine assert_true
end program test_neo_hookean_reference_states
