module des_herrmann_pressure_interpolation
  use des_kinds, only : dp
  implicit none
  private

  public :: herrmann_p1_pressure_basis

contains

  pure subroutine herrmann_p1_pressure_basis(xi, eta, Np)
    ! Herrmann/mixed u-p ailesinin element-internal 3-DOF lineer pressure alani.
    ! Modal basis: [1, xi, eta].
    !
    ! Bu pressure alani Q8 veya Q9 displacement interpolasyonuna ait degildir;
    ! formulation seviyesinde ortaktir. Hangi displacement ailesiyle production
    ! kullanilacagi inf-sup, distortion ve nonlinear benchmark kapilariyla belirlenir.
    real(dp), intent(in) :: xi, eta
    real(dp), intent(out) :: Np(3)

    Np = [1.0_dp, xi, eta]
  end subroutine herrmann_p1_pressure_basis

end module des_herrmann_pressure_interpolation
