!=======================================================================
! DynaElastomerSolver
! Q9/P1 mixed u-P compatibility kernel
!
! Bu modül yeni bir Q9 interpolation veya pressure formulation tanımlamaz.
! Repository'nin doğrulanmış Herrmann sözleşmesini tek noktadan yeniden kullanır:
!
!   Q9 displacement : 9 node x 2 DOF = 18 kinematik DOF
!   P1 pressure      : [1, xi, eta]   =  3 bağımsız pressure DOF
!   Toplam           :                  21 local unknown
!
! Böylece eski/deneysel bir-node-order veya tek-pressure-DOF tanımının production
! Herrmann hattına sızması engellenir. Q9 displacement interpolation
! des_q9_herrmann_interpolation, pressure basis ise
! des_herrmann_pressure_interpolation tarafından sahiplenilir.
!=======================================================================

module des_q9_plane_strain_mixed_up_kernel
  use des_kinds, only : dp
  use des_q9_herrmann_interpolation, only : q9_shape_functions
  use des_herrmann_pressure_interpolation, only : herrmann_p1_pressure_basis
  implicit none
  private

  integer, parameter, public :: Q9P1_DISPLACEMENT_DOF = 18
  integer, parameter, public :: Q9P1_PRESSURE_DOF = 3
  integer, parameter, public :: Q9P1_TOTAL_DOF = 21

  public :: q9p1_shape_functions
  public :: q9p1_pressure_basis
  public :: q9p1_mixed_dof_count
  public :: q9p1_check_jacobian

contains

  pure integer function q9p1_mixed_dof_count() result(ndof)
    ndof = Q9P1_TOTAL_DOF
  end function q9p1_mixed_dof_count

  pure subroutine q9p1_shape_functions(xi, eta, n, dn_dxi)
    ! Compatibility API'si 2x9 derivative düzenini korur; canonical Q9 routine
    ! 9x2 döndürdüğü için yalnız transpose edilir. Node ordering değiştirilmez.
    real(dp), intent(in) :: xi, eta
    real(dp), intent(out) :: n(9)
    real(dp), intent(out) :: dn_dxi(2,9)
    real(dp) :: canonical_derivatives(9,2)

    call q9_shape_functions(xi, eta, n, canonical_derivatives)
    dn_dxi = transpose(canonical_derivatives)
  end subroutine q9p1_shape_functions

  pure subroutine q9p1_pressure_basis(xi, eta, np)
    real(dp), intent(in) :: xi, eta
    real(dp), intent(out) :: np(3)

    call herrmann_p1_pressure_basis(xi, eta, np)
  end subroutine q9p1_pressure_basis

  pure logical function q9p1_check_jacobian(det_j) result(ok)
    real(dp), intent(in) :: det_j

    ok = det_j > tiny(1.0_dp)
  end function q9p1_check_jacobian

end module des_q9_plane_strain_mixed_up_kernel
