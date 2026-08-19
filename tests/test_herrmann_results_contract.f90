program test_herrmann_results_contract
  use des_kinds, only : dp
  use des_integration_point_results, only : integration_point_result_t, &
      DES_PRESSURE_SOURCE_DERIVED_CONSTITUTIVE, &
      DES_PRESSURE_SOURCE_INDEPENDENT_UNKNOWN, &
      DES_PRESSURE_MEASURE_LOGJ_CONJUGATE, &
      DES_PRESSURE_MEASURE_HERRMANN_HYDROSTATIC, &
      set_derived_logj_pressure, set_independent_logj_pressure, &
      set_independent_herrmann_pressure
  implicit none

  type(integration_point_result_t) :: point
  real(dp), parameter :: tol = 1.0e-14_dp

  call set_independent_herrmann_pressure(point,0.75_dp)
  if (.not. point%pressure_valid) error stop 'Herrmann pressure sonucu valid degil.'
  if (point%pressure_source /= DES_PRESSURE_SOURCE_INDEPENDENT_UNKNOWN) then
    error stop 'Herrmann pressure source independent unknown olmali.'
  end if
  if (point%pressure_measure /= DES_PRESSURE_MEASURE_HERRMANN_HYDROSTATIC) then
    error stop 'Herrmann pressure measure hydrostatic olmali.'
  end if
  if (abs(point%pressure_value-0.75_dp) > tol) then
    error stop 'Herrmann pressure degeri korunmadi.'
  end if

  call set_derived_logj_pressure(point,10.0_dp,exp(0.02_dp))
  if (point%pressure_source /= DES_PRESSURE_SOURCE_DERIVED_CONSTITUTIVE) then
    error stop 'Derived logJ pressure source bozuldu.'
  end if
  if (point%pressure_measure /= DES_PRESSURE_MEASURE_LOGJ_CONJUGATE) then
    error stop 'Derived logJ pressure measure bozuldu.'
  end if
  if (abs(point%pressure_value-0.2_dp) > 5.0e-14_dp) then
    error stop 'Derived logJ pressure degeri bozuldu.'
  end if

  call set_independent_logj_pressure(point,-0.4_dp)
  if (point%pressure_source /= DES_PRESSURE_SOURCE_INDEPENDENT_UNKNOWN) then
    error stop 'Legacy independent logJ source bozuldu.'
  end if
  if (point%pressure_measure /= DES_PRESSURE_MEASURE_LOGJ_CONJUGATE) then
    error stop 'Legacy independent logJ measure bozuldu.'
  end if

  write(*,'(A)') 'Herrmann independent pressure Results contract testi BASARILI.'
end program test_herrmann_results_contract
