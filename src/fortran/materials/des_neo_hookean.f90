module des_neo_hookean
  use des_kinds, only : dp
  use des_tensor3, only : inverse3, identity3
  use des_material_types, only : material_kinematics_t, material_response_t, neo_hookean_parameters_t
  implicit none
  private
  public :: evaluate_neo_hookean
contains

  pure subroutine evaluate_neo_hookean(kinematics, parameters, response)
    type(material_kinematics_t), intent(in) :: kinematics
    type(neo_hookean_parameters_t), intent(in) :: parameters
    type(material_response_t), intent(out) :: response

    real(dp) :: F(3,3), Finv(3,3), FinvT(3,3), b(3,3), I(3,3)
    real(dp) :: J, lnJ, I1, alpha
    integer :: iidx, jidx, kidx, lidx
    logical :: ok

    response = material_response_t()
    F = kinematics%F

    call inverse3(F, Finv, J, ok)
    if (.not. ok .or. J <= 0.0_dp) return

    FinvT = transpose(Finv)
    I = identity3()
    b = matmul(F, transpose(F))
    I1 = sum(F*F)
    lnJ = log(J)

    ! Sıkıştırılabilir Neo-Hookean enerji:
    ! W = mu/2 * (I1 - 3) - mu*ln(J) + lambda/2 * ln(J)^2
    response%energy = 0.5_dp*parameters%mu*(I1 - 3.0_dp) &
                    - parameters%mu*lnJ &
                    + 0.5_dp*parameters%lambda*lnJ*lnJ

    ! Birinci Piola-Kirchhoff gerilmesi:
    ! P = mu*F + (lambda*ln(J) - mu)*F^{-T}
    alpha = parameters%lambda*lnJ - parameters%mu
    response%P = parameters%mu*F + alpha*FinvT

    ! Cauchy gerilmesi:
    ! sigma = mu/J * (b - I) + lambda*ln(J)/J * I
    response%cauchy = (parameters%mu/J)*(b - I) &
                    + (parameters%lambda*lnJ/J)*I

    ! Material tangent A = dP/dF.
    ! Bu tensor V0.1 testinde merkezi finite-difference ile bağımsız kontrol edilir.
    response%tangent = 0.0_dp
    do iidx = 1,3
      do jidx = 1,3
        do kidx = 1,3
          do lidx = 1,3
            if (iidx == kidx .and. jidx == lidx) then
              response%tangent(iidx,jidx,kidx,lidx) = &
                response%tangent(iidx,jidx,kidx,lidx) + parameters%mu
            end if

            response%tangent(iidx,jidx,kidx,lidx) = &
              response%tangent(iidx,jidx,kidx,lidx) &
              + parameters%lambda*FinvT(iidx,jidx)*FinvT(kidx,lidx) &
              - alpha*FinvT(kidx,jidx)*FinvT(iidx,lidx)
          end do
        end do
      end do
    end do

    response%J = J
    response%valid = .true.
  end subroutine evaluate_neo_hookean

end module des_neo_hookean
