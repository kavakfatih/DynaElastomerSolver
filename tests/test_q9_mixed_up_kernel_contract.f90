program test_q9_mixed_up_kernel_contract
  use des_kinds, only : dp
  use des_q9_plane_strain_mixed_up_kernel, only : &
      Q9P1_DISPLACEMENT_DOF, Q9P1_PRESSURE_DOF, Q9P1_TOTAL_DOF, &
      q9p1_shape_functions, q9p1_pressure_basis, q9p1_mixed_dof_count, &
      q9p1_check_jacobian
  implicit none

  real(dp) :: n(9),dn(2,9),np(3)

  call require(Q9P1_DISPLACEMENT_DOF == 18, &
      'Q9/P1 displacement DOF sayısı 18 olmalı')
  call require(Q9P1_PRESSURE_DOF == 3, &
      'Herrmann P1 pressure alanı üç bağımsız DOF taşımalı')
  call require(Q9P1_TOTAL_DOF == 21 .and. q9p1_mixed_dof_count() == 21, &
      'Q9/P1 local mixed DOF sayısı 21 olmalı')

  ! Canonical Q9 node ordering: node 2 = (1,-1), node 9 = (0,0).
  call q9p1_shape_functions(1.0_dp,-1.0_dp,n,dn)
  call require(abs(n(2)-1.0_dp) <= 1.0e-14_dp, &
      'Q9 compatibility kernel canonical node ordering kullanmıyor')
  call require(maxval(abs(n([1,3,4,5,6,7,8,9]))) <= 1.0e-14_dp, &
      'Q9 nodal interpolation Kronecker özelliğini bozdu')

  call q9p1_shape_functions(0.0_dp,0.0_dp,n,dn)
  call require(abs(n(9)-1.0_dp) <= 1.0e-14_dp, &
      'Q9 merkez node interpolation değeri yanlış')
  call require(abs(sum(n)-1.0_dp) <= 1.0e-14_dp, &
      'Q9 partition of unity korunmuyor')
  call require(maxval(abs(sum(dn,dim=2))) <= 1.0e-14_dp, &
      'Q9 shape derivative partition özelliği korunmuyor')

  call q9p1_pressure_basis(0.25_dp,-0.50_dp,np)
  call require(maxval(abs(np-[1.0_dp,0.25_dp,-0.50_dp])) <= 1.0e-14_dp, &
      'Q9/P1 pressure basis complete-linear [1,xi,eta] değil')

  call require(q9p1_check_jacobian(1.0_dp), &
      'Pozitif Q9 Jacobian geçerli olmalı')
  call require(.not.q9p1_check_jacobian(0.0_dp), &
      'Sıfır Q9 Jacobian reddedilmeli')
  call require(.not.q9p1_check_jacobian(-1.0_dp), &
      'Negatif Q9 Jacobian reddedilmeli')

  write(*,'(A)') 'PASS: Q9/P1 compatibility kernel canonical 18u+3p contract'

contains

  subroutine require(condition,message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message

    if (.not.condition) error stop message
  end subroutine require

end program test_q9_mixed_up_kernel_contract
