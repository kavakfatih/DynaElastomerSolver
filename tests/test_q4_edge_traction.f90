program test_q4_edge_traction
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_ELEMENT_JACOBIAN, &
                         DES_ERROR_INVALID_ELEMENT_EDGE
  use des_q4_edge_traction, only : Q4_EDGE_RIGHT, q4_reference_edge_traction
  implicit none

  real(dp), parameter :: tol = 1.0e-12_dp
  real(dp) :: X(4,2), force(8), traction(2), reference_length
  real(dp) :: expected_length
  integer :: status

  ! Birim kare sağ kenarı: sabit traction iki sağ düğüme eşit dağılmalıdır.
  X(1,:) = [0.0_dp, 0.0_dp]
  X(2,:) = [1.0_dp, 0.0_dp]
  X(3,:) = [1.0_dp, 1.0_dp]
  X(4,:) = [0.0_dp, 1.0_dp]
  traction = [3.0_dp, -2.0_dp]

  call q4_reference_edge_traction(X, Q4_EDGE_RIGHT, traction, force, status, reference_length)

  if (status /= DES_STATUS_OK) error stop 'Birim kare edge traction değerlendirmesi başarısız.'
  if (abs(reference_length - 1.0_dp) > tol) error stop 'Birim kare sağ kenar uzunluğu hatalı.'
  if (maxval(abs(force - [0.0_dp, 0.0_dp, 1.5_dp, -1.0_dp, 1.5_dp, -1.0_dp, 0.0_dp, 0.0_dp])) > tol) then
    error stop 'Birim kare edge traction düğüm yükleri hatalı.'
  end if

  if (abs(sum(force(1:8:2)) - traction(1)) > tol) error stop 'Toplam x traction kuvveti korunmadı.'
  if (abs(sum(force(2:8:2)) - traction(2)) > tol) error stop 'Toplam y traction kuvveti korunmadı.'

  ! Eğik sağ kenarda toplam kuvvet traction * referans kenar uzunluğu olmalıdır.
  X(1,:) = [0.0_dp, 0.0_dp]
  X(2,:) = [2.0_dp, 0.0_dp]
  X(3,:) = [3.0_dp, 4.0_dp]
  X(4,:) = [0.0_dp, 1.0_dp]
  traction = [1.2_dp, 0.5_dp]
  expected_length = sqrt(17.0_dp)

  call q4_reference_edge_traction(X, Q4_EDGE_RIGHT, traction, force, status, reference_length)

  if (status /= DES_STATUS_OK) error stop 'Eğik kenar traction değerlendirmesi başarısız.'
  if (abs(reference_length - expected_length) > tol) error stop 'Eğik kenar uzunluğu hatalı.'
  if (abs(force(3) - 0.5_dp*traction(1)*expected_length) > tol) error stop 'Node 2 x yükü hatalı.'
  if (abs(force(4) - 0.5_dp*traction(2)*expected_length) > tol) error stop 'Node 2 y yükü hatalı.'
  if (abs(force(5) - 0.5_dp*traction(1)*expected_length) > tol) error stop 'Node 3 x yükü hatalı.'
  if (abs(force(6) - 0.5_dp*traction(2)*expected_length) > tol) error stop 'Node 3 y yükü hatalı.'
  if (maxval(abs(force([1,2,7,8]))) > tol) error stop 'Kenar dışındaki düğümlere yük sızdı.'

  ! Geçersiz yerel kenar kimliği açık durum kodu üretmelidir.
  call q4_reference_edge_traction(X, 5, traction, force, status, reference_length)
  if (status /= DES_ERROR_INVALID_ELEMENT_EDGE) error stop 'Geçersiz edge kimliği reddedilmedi.'
  if (maxval(abs(force)) > tol) error stop 'Geçersiz edge durumunda force sıfırlanmadı.'

  ! Sıfır uzunluklu kenar geometrik Jacobian hatasıdır.
  X(3,:) = X(2,:)
  call q4_reference_edge_traction(X, Q4_EDGE_RIGHT, traction, force, status, reference_length)
  if (status /= DES_ERROR_INVALID_ELEMENT_JACOBIAN) error stop 'Sıfır uzunluklu kenar reddedilmedi.'
  if (maxval(abs(force)) > tol) error stop 'Geçersiz geometride force sıfırlanmadı.'

  write(*,'(A)') 'Q4 reference edge traction testi BASARILI.'
end program test_q4_edge_traction
