program test_q4_shape
  use des_kinds, only : dp
  use des_q4_shape, only : q4_shape_functions
  implicit none

  real(dp) :: N(4), dN(4,2)
  real(dp), parameter :: tol = 5.0e-14_dp

  call q4_shape_functions(0.23_dp, -0.37_dp, N, dN)
  if (abs(sum(N)-1.0_dp) > tol) error stop 'Q4 partition of unity basarisiz.'
  if (abs(sum(dN(:,1))) > tol) error stop 'Q4 dN/dxi toplami sifir degil.'
  if (abs(sum(dN(:,2))) > tol) error stop 'Q4 dN/deta toplami sifir degil.'

  write(*,'(A)') 'Q4 shape function testleri BASARILI.'
end program test_q4_shape
