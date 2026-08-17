program test_finite_strain
  use des_kinds, only : dp
  use des_tensor3, only : identity3
  use des_finite_strain, only : right_cauchy_green, left_cauchy_green, &
                                first_invariant_from_F, invariants3
  implicit none

  real(dp) :: F(3,3), C(3,3), b(3,3)
  real(dp) :: I1, I2, I3, gamma
  real(dp), parameter :: tol = 5.0e-13_dp

  gamma = 0.4_dp
  F = identity3()
  F(1,2) = gamma

  C = right_cauchy_green(F)
  b = left_cauchy_green(F)

  call assert_close(C(1,1), 1.0_dp, 'C11')
  call assert_close(C(1,2), gamma, 'C12')
  call assert_close(C(2,2), 1.0_dp + gamma*gamma, 'C22')

  call assert_close(b(1,1), 1.0_dp + gamma*gamma, 'b11')
  call assert_close(b(1,2), gamma, 'b12')
  call assert_close(b(2,2), 1.0_dp, 'b22')

  call assert_close(first_invariant_from_F(F), 3.0_dp + gamma*gamma, 'I1(F)')

  call invariants3(C, I1, I2, I3)
  call assert_close(I1, 3.0_dp + gamma*gamma, 'I1(C)')
  call assert_close(I2, 3.0_dp + gamma*gamma, 'I2(C)')
  call assert_close(I3, 1.0_dp, 'I3(C)')

  write(*,'(A)') 'Finite-strain kinematik testleri BASARILI.'
contains
  subroutine assert_close(actual, expected, label)
    real(dp), intent(in) :: actual, expected
    character(len=*), intent(in) :: label
    if (abs(actual-expected) > tol*max(1.0_dp, abs(expected))) then
      write(*,'(A,2ES18.8)') trim(label)//' actual/expected: ', actual, expected
      error stop 'Finite-strain kinematik testi basarisiz.'
    end if
  end subroutine assert_close
end program test_finite_strain
