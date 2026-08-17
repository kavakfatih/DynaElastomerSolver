program test_tensor3
  use des_kinds, only : dp
  use des_tensor3, only : determinant3, inverse3, identity3
  implicit none

  real(dp) :: A(3,3), Ainv(3,3), detA, residual(3,3)
  logical :: ok
  real(dp), parameter :: tol = 5.0e-13_dp

  A = 0.0_dp
  A(1,1) = 1.2_dp; A(1,2) = 0.1_dp; A(1,3) = -0.2_dp
  A(2,1) = 0.3_dp; A(2,2) = 0.9_dp; A(2,3) = 0.05_dp
  A(3,1) = 0.0_dp; A(3,2) = 0.2_dp; A(3,3) = 1.1_dp

  call inverse3(A, Ainv, detA, ok)
  if (.not. ok) error stop 'Terslenebilir matris singular olarak isaretlendi.'
  if (abs(detA-determinant3(A)) > tol) error stop 'Determinant tutarsiz.'

  residual = matmul(A, Ainv) - identity3()
  if (maxval(abs(residual)) > tol) then
    write(*,'(A,ES12.4)') 'Inverse residual = ', maxval(abs(residual))
    error stop '3x3 inverse testi basarisiz.'
  end if

  write(*,'(A,ES12.4)') 'Inverse residual = ', maxval(abs(residual))
  write(*,'(A)') 'Tensor3 testleri BASARILI.'
end program test_tensor3
