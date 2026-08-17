program test_dense_linear
  use des_kinds, only : dp
  use des_dense_linear, only : solve_dense_system
  implicit none

  real(dp) :: A(4,4), b(4), x(4), expected(4), residual(4)
  logical :: ok

  A = reshape([ &
    4.0_dp, 1.0_dp, 0.0_dp, 2.0_dp, &
    1.0_dp, 5.0_dp, 1.0_dp, 0.0_dp, &
    0.0_dp, 1.0_dp, 3.0_dp, 1.0_dp, &
    2.0_dp, 0.0_dp, 1.0_dp, 6.0_dp ], [4,4])
  expected = [0.5_dp, -1.0_dp, 2.0_dp, 0.75_dp]
  b = matmul(A, expected)

  call solve_dense_system(A, b, x, ok)
  if (.not. ok) error stop 'Dense lineer cozum basarisiz.'
  residual = matmul(A,x)-b
  if (maxval(abs(x-expected)) > 2.0e-13_dp) error stop 'Dense cozum beklenen x ile uyusmuyor.'
  if (maxval(abs(residual)) > 2.0e-13_dp) error stop 'Dense cozum residual toleransi asti.'

  write(*,'(A,ES12.4)') 'Dense residual = ', maxval(abs(residual))
  write(*,'(A)') 'Dense linear solver testi BASARILI.'
end program test_dense_linear
