program test_linear_solver_interface
  use des_kinds, only : dp, i64
  use des_status, only : DES_STATUS_OK, DES_ERROR_UNSUPPORTED_LINEAR_BACKEND
  use des_linear_solver, only : linear_solver_settings_t, linear_solver_report_t, &
                                solve_linear_system, DES_LINEAR_BACKEND_STDLIB_DENSE
  implicit none

  real(dp) :: A(3,3), b(3), x(3), expected(3)
  type(linear_solver_settings_t) :: settings
  type(linear_solver_report_t) :: report

  A = reshape([ &
    5.0_dp, 1.0_dp, 0.0_dp, &
    1.0_dp, 4.0_dp, 1.0_dp, &
    0.0_dp, 1.0_dp, 3.0_dp ], [3,3])
  expected = [1.0_dp, -2.0_dp, 0.5_dp]
  b = matmul(A, expected)

  settings%backend = DES_LINEAR_BACKEND_STDLIB_DENSE
  call solve_linear_system(A, b, x, settings, report)

  if (.not. report%converged) error stop 'Lineer solver interface yakınsamadı.'
  if (report%status /= DES_STATUS_OK) error stop 'Lineer solver status başarısız.'
  if (report%backend /= DES_LINEAR_BACKEND_STDLIB_DENSE) error stop 'Backend raporu yanlış.'
  if (kind(report%equation_count) /= i64) then
    error stop 'Lineer solver denklem cardinality raporu int64 degil.'
  end if
  if (report%equation_count /= 3_i64) error stop 'Denklem sayısı raporu yanlış.'
  if (maxval(abs(x-expected)) > 2.0e-13_dp) error stop 'Çözüm beklenen değerle uyuşmuyor.'
  if (report%residual_inf_norm > 2.0e-13_dp) error stop 'Lineer residual toleransı aşıldı.'

  settings%backend = 999
  call solve_linear_system(A, b, x, settings, report)
  if (report%converged) error stop 'Desteklenmeyen backend başarı dönmemeli.'
  if (report%status /= DES_ERROR_UNSUPPORTED_LINEAR_BACKEND) then
    error stop 'Desteklenmeyen backend doğru status üretmedi.'
  end if
  if (report%equation_count /= 3_i64) then
    error stop 'Desteklenmeyen backend raporunda int64 denklem sayisi kayboldu.'
  end if

  write(*,'(A,I0)') 'Linear solver equation count (int64) = ',report%equation_count
  write(*,'(A)') 'Backend-bağımsız lineer solver interface testi BAŞARILI.'
end program test_linear_solver_interface
