module des_herrmann_pressure_constraint
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_PARAMETERS, &
                         DES_ERROR_SINGULAR_F, DES_ERROR_NONPOSITIVE_J
  use des_tensor3, only : inverse3, identity3
  implicit none
  private

  type, public :: herrmann_constraint_response_t
    real(dp) :: potential = 0.0_dp
    real(dp) :: P(3,3) = 0.0_dp
    real(dp) :: cauchy(3,3) = 0.0_dp
    real(dp) :: tangent_F(3,3,3,3) = 0.0_dp
    real(dp) :: dP_dp(3,3) = 0.0_dp
    real(dp) :: constraint = 0.0_dp
    real(dp) :: dconstraint_dF(3,3) = 0.0_dp
    real(dp) :: dconstraint_dp = 0.0_dp
    real(dp) :: J = 1.0_dp
    integer :: status = 1
    logical :: valid = .false.
  end type herrmann_constraint_response_t

  public :: evaluate_herrmann_pressure_constraint

contains

  pure subroutine evaluate_herrmann_pressure_constraint( &
      F, pressure, pressure_compliance, response)
    ! Herrmann/mixed u-p hacimsel kısıt cevabı.
    ! Sign convention: pressure > 0 sıkışmayı ifade eder ve Cauchy katkısı -p I'dir.
    !
    ! Pi_p = -p (J-1) - 1/2 c_p p^2
    !
    ! R_p = dPi_p/dp = -(J-1) - c_p p
    ! P_p = dPi_p/dF  = -p J F^(-T)
    !
    ! Nearly incompressible: c_p > 0 (yaklaşık 1/K mertebesi)
    ! Fully incompressible:  c_p = 0 -> J=1 ve K_pp=0 saddle-point limiti.
    real(dp), intent(in) :: F(3,3), pressure, pressure_compliance
    type(herrmann_constraint_response_t), intent(out) :: response

    real(dp) :: Finv(3,3), H(3,3), I(3,3), J
    integer :: iidx, jidx, kidx, lidx
    logical :: inverse_ok

    response = herrmann_constraint_response_t()

    if (pressure_compliance < 0.0_dp) then
      response%status = DES_ERROR_INVALID_PARAMETERS
      return
    end if

    call inverse3(F,Finv,J,inverse_ok)
    response%J = J
    if (.not. inverse_ok) then
      response%status = DES_ERROR_SINGULAR_F
      return
    end if
    if (J <= 0.0_dp) then
      response%status = DES_ERROR_NONPOSITIVE_J
      return
    end if

    H = transpose(Finv)
    I = identity3()

    response%potential = -pressure*(J-1.0_dp) &
                       - 0.5_dp*pressure_compliance*pressure*pressure
    response%P = -pressure*J*H
    response%cauchy = -pressure*I
    response%dP_dp = -J*H

    response%constraint = -(J-1.0_dp) - pressure_compliance*pressure
    response%dconstraint_dF = -J*H
    response%dconstraint_dp = -pressure_compliance

    ! d[-p J H(iJ)]/dF(kL)
    response%tangent_F = 0.0_dp
    do iidx = 1,3
      do jidx = 1,3
        do kidx = 1,3
          do lidx = 1,3
            response%tangent_F(iidx,jidx,kidx,lidx) = &
                -pressure*J*( &
                  H(kidx,lidx)*H(iidx,jidx) &
                  - H(kidx,jidx)*H(iidx,lidx))
          end do
        end do
      end do
    end do

    response%status = DES_STATUS_OK
    response%valid = .true.
  end subroutine evaluate_herrmann_pressure_constraint

end module des_herrmann_pressure_constraint
