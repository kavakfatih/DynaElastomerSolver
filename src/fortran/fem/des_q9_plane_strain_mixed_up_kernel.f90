!=======================================================================
! DynaElastomerSolver
! Q9/P1 Mixed u-P element kernel foundation
!
! Amaç:
!   Herrmann mixed displacement-pressure formulasyonu için Q9/P1
!   eleman çekirdeğinin temel altyapısını oluşturmak.
!
! Q9 : quadratic displacement interpolation (9 node)
! P1 : linear pressure interpolation (element pressure field)
!
! Bu modül ilk aşamada:
!   - shape function altyapısı
!   - determinant kontrolü
!   - mixed DOF boyut sözleşmesi
! sağlar.
!
! Tam nonlinear tangent ve residual hesabı Neo-Hookean constitutive
! katmanı ile sonraki adımda bağlanacaktır.
!=======================================================================

module des_q9_plane_strain_mixed_up_kernel
  use des_kinds
  implicit none
  private

  public :: q9p1_shape_functions
  public :: q9p1_mixed_dof_count
  public :: q9p1_check_jacobian

contains

  integer function q9p1_mixed_dof_count() result(ndof)
    ! 9 displacement nodes x 2 displacement DOF
    ! + 1 element pressure DOF
    ndof = 19
  end function q9p1_mixed_dof_count


  subroutine q9p1_shape_functions(xi, eta, n, dn_dxi)
    real(dp), intent(in) :: xi, eta
    real(dp), intent(out) :: n(9)
    real(dp), intent(out) :: dn_dxi(2,9)

    real(dp) :: lx(3), ly(3)
    real(dp) :: dlx(3), dly(3)

    ! 1D quadratic Lagrange basis
    lx(1)=0.5_dp*xi*(xi-1.0_dp)
    lx(2)=1.0_dp-xi*xi
    lx(3)=0.5_dp*xi*(xi+1.0_dp)

    ly(1)=0.5_dp*eta*(eta-1.0_dp)
    ly(2)=1.0_dp-eta*eta
    ly(3)=0.5_dp*eta*(eta+1.0_dp)

    dlx(1)=xi-0.5_dp
    dlx(2)=-2.0_dp*xi
    dlx(3)=xi+0.5_dp

    dly(1)=eta-0.5_dp
    dly(2)=-2.0_dp*eta
    dly(3)=eta+0.5_dp

    n(1)=lx(1)*ly(1)
    n(2)=lx(2)*ly(1)
    n(3)=lx(3)*ly(1)
    n(4)=lx(3)*ly(2)
    n(5)=lx(3)*ly(3)
    n(6)=lx(2)*ly(3)
    n(7)=lx(1)*ly(3)
    n(8)=lx(1)*ly(2)
    n(9)=lx(2)*ly(2)

    dn_dxi=0.0_dp

    dn_dxi(1,1)=dlx(1)*ly(1); dn_dxi(2,1)=lx(1)*dly(1)
    dn_dxi(1,2)=dlx(2)*ly(1); dn_dxi(2,2)=lx(2)*dly(1)
    dn_dxi(1,3)=dlx(3)*ly(1); dn_dxi(2,3)=lx(3)*dly(1)
    dn_dxi(1,4)=dlx(3)*ly(2); dn_dxi(2,4)=lx(3)*dly(2)
    dn_dxi(1,5)=dlx(3)*ly(3); dn_dxi(2,5)=lx(3)*dly(3)
    dn_dxi(1,6)=dlx(2)*ly(3); dn_dxi(2,6)=lx(2)*dly(3)
    dn_dxi(1,7)=dlx(1)*ly(3); dn_dxi(2,7)=lx(1)*dly(3)
    dn_dxi(1,8)=dlx(1)*ly(2); dn_dxi(2,8)=lx(1)*dly(2)
    dn_dxi(1,9)=dlx(2)*ly(2); dn_dxi(2,9)=lx(2)*dly(2)

  end subroutine q9p1_shape_functions


  logical function q9p1_check_jacobian(det_j) result(ok)
    real(dp), intent(in) :: det_j

    ok = det_j > tiny(1.0_dp)
  end function q9p1_check_jacobian

end module des_q9_plane_strain_mixed_up_kernel
