program test_neo_hookean_validation
  use des_kinds, only : dp
  use des_status, only : DES_ERROR_INVALID_PARAMETERS, DES_ERROR_SINGULAR_F, DES_ERROR_NONPOSITIVE_J
  use des_tensor3, only : identity3
  use des_material_types, only : material_kinematics_t, material_response_t, neo_hookean_parameters_t
  use des_neo_hookean, only : evaluate_neo_hookean, validate_neo_hookean_parameters
  implicit none

  type(material_kinematics_t) :: kin
  type(material_response_t) :: r
  type(neo_hookean_parameters_t) :: p
  logical :: valid_parameters

  ! Negatif kayma modülü fiziksel olarak kabul edilmez.
  p%mu = -1.0_dp
  p%lambda = 10.0_dp
  call validate_neo_hookean_parameters(p, valid_parameters)
  if (valid_parameters) error stop 'Negatif mu reddedilmeliydi.'
  kin%F = identity3()
  call evaluate_neo_hookean(kin, p, r)
  if (r%valid .or. r%status /= DES_ERROR_INVALID_PARAMETERS) then
    error stop 'Gecersiz parametre status kodu hatali.'
  end if

  ! Pozitif mu tek basina yetmez; bulk modulus da pozitif olmalıdır.
  p%mu = 2.0_dp
  p%lambda = -2.0_dp
  call validate_neo_hookean_parameters(p, valid_parameters)
  if (valid_parameters) error stop 'Negatif bulk modulus reddedilmeliydi.'

  ! Singular F ayri bir tanidir.
  p%mu = 2.0_dp
  p%lambda = 12.0_dp
  kin%F = 0.0_dp
  kin%F(1,1) = 1.0_dp
  kin%F(2,2) = 1.0_dp
  call evaluate_neo_hookean(kin, p, r)
  if (r%valid .or. r%status /= DES_ERROR_SINGULAR_F) then
    error stop 'Singular F dogru siniflandirilmadi.'
  end if

  ! Negatif determinant fiziksel olarak kabul edilemez ve singular durumdan ayrılır.
  kin%F = identity3()
  kin%F(1,1) = -1.0_dp
  call evaluate_neo_hookean(kin, p, r)
  if (r%valid .or. r%status /= DES_ERROR_NONPOSITIVE_J) then
    error stop 'Negatif J dogru siniflandirilmadi.'
  end if

  write(*,'(A)') 'Neo-Hookean parametre ve kinematik dogrulama testleri BASARILI.'
end program test_neo_hookean_validation
