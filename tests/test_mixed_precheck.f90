program test_mixed_precheck
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONSTRAINT
  use des_mixed_precheck, only : mixed_dof_balance_t, assess_mixed_dof_balance
  implicit none

  type(mixed_dof_balance_t) :: balance
  integer :: status
  integer :: prescribed_many(14), prescribed_duplicate(3)
  integer, allocatable :: no_constraints(:)
  integer :: i

  allocate(no_constraints(0))

  ! Düzenli 8x8 Q8 serendipity mesh için node sayısı:
  ! corner + yatay midside + dikey midside = 225.
  ! 2 displacement DOF/node ve 3 pressure DOF/element ile serbest global oran 450/192.
  call assess_mixed_dof_balance(225,64,2,3,no_constraints,balance,status)
  if (status /= DES_STATUS_OK) error stop 'Mixed Nd/Np precheck kurulamadı.'
  if (balance%displacement_equations /= 450) error stop 'Mixed Nd sayımı hatalı.'
  if (balance%pressure_equations /= 192) error stop 'Mixed Np sayımı hatalı.'
  if (abs(balance%nd_over_np-2.34375_dp) > 1.0e-14_dp) then
    error stop 'Mixed Nd/Np oranı hatalı.'
  end if
  if (balance%overconstrained_by_count) then
    error stop 'Serbest 8x8 Q8/P1 sistem yanlışlıkla overconstrained işaretlendi.'
  end if

  ! Tek Q8 elementte 16 displacement denkleminden 14'ü prescribed ise Nd=2 < Np=3.
  do i = 1,14
    prescribed_many(i) = i
  end do
  call assess_mixed_dof_balance(8,1,2,3,prescribed_many,balance,status)
  if (status /= DES_STATUS_OK) error stop 'Mixed constrained precheck çalışmadı.'
  if (balance%free_displacement_equations /= 2) error stop 'Mixed free Nd sayımı hatalı.'
  if (.not. balance%overconstrained_by_count) then
    error stop 'Nd<Np durumu precheck tarafından yakalanmadı.'
  end if

  ! Aynı prescribed DOF iki kez verilse dahi tek constraint sayılmalı.
  prescribed_duplicate = [1,1,2]
  call assess_mixed_dof_balance(8,1,2,3,prescribed_duplicate,balance,status)
  if (status /= DES_STATUS_OK) error stop 'Duplicate constraint precheck çalışmadı.'
  if (balance%prescribed_displacement_equations /= 2) then
    error stop 'Duplicate prescribed DOF iki kez sayıldı.'
  end if

  prescribed_duplicate = [1,2,17]
  call assess_mixed_dof_balance(8,1,2,3,prescribed_duplicate,balance,status)
  if (status /= DES_ERROR_INVALID_CONSTRAINT) then
    error stop 'Geçersiz prescribed displacement DOF reddedilmedi.'
  end if

  write(*,'(A,F8.5)') '8x8 Q8/P1 unrestricted Nd/Np = ',2.34375_dp
  write(*,'(A)') 'Mixed Nd/Np precheck testleri BASARILI.'
end program test_mixed_precheck
