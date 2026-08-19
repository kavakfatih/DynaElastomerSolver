module des_neo_hookean_isochoric
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_PARAMETERS, &
                         DES_ERROR_SINGULAR_F, DES_ERROR_NONPOSITIVE_J
  use des_tensor3, only : inverse3, identity3
  use des_material_types, only : material_kinematics_t, material_response_t
  implicit none
  private

  public :: evaluate_neo_hookean_isochoric

contains

  pure subroutine evaluate_neo_hookean_isochoric(kinematics, shear_modulus, response)
    ! Mixed u-p / Herrmann formulationı için yalnız isochoric Neo-Hookean cevap.
    ! Hacimsel kısıt ve hydrostatic pressure bu modülün sorumluluğu değildir.
    !
    ! W_iso = mu/2 * (J^(-2/3) I1 - 3)
    !
    ! P_iso = mu J^(-2/3) [F - (I1/3) F^(-T)]
    !
    ! Cauchy cevabının izi sıfırdır. Bu ayrım sayesinde independent pressure
    ! unknown daha sonra sigma = sigma_iso - p I biçiminde açıkça eklenebilir.
    type(material_kinematics_t), intent(in) :: kinematics
    real(dp), intent(in) :: shear_modulus
    type(material_response_t), intent(out) :: response

    real(dp) :: F(3,3), Finv(3,3), H(3,3), b(3,3), I(3,3)
    real(dp) :: J, I1, j_m23, c
    integer :: iidx, jidx, kidx, lidx
    logical :: inverse_ok

    response = material_response_t()
    F = kinematics%F

    if (shear_modulus <= 0.0_dp) then
      response%status = DES_ERROR_INVALID_PARAMETERS
      return
    end if

    call inverse3(F, Finv, J, inverse_ok)
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
    b = matmul(F,transpose(F))
    I1 = sum(F*F)
    j_m23 = J**(-2.0_dp/3.0_dp)
    c = I1/3.0_dp

    response%energy = 0.5_dp*shear_modulus*(j_m23*I1-3.0_dp)
    response%P = shear_modulus*j_m23*(F-c*H)
    response%cauchy = (shear_modulus*j_m23/J)*(b-c*I)

    ! A_iso(iJ,kL) = dP_iso(iJ)/dF(kL).
    ! Bu consistent tangent merkezi finite-difference ile bağımsız test edilir.
    response%tangent = 0.0_dp
    do iidx = 1,3
      do jidx = 1,3
        do kidx = 1,3
          do lidx = 1,3
            if (iidx == kidx .and. jidx == lidx) then
              response%tangent(iidx,jidx,kidx,lidx) = &
                  response%tangent(iidx,jidx,kidx,lidx) + shear_modulus*j_m23
            end if

            response%tangent(iidx,jidx,kidx,lidx) = &
                response%tangent(iidx,jidx,kidx,lidx) &
                + shear_modulus*j_m23*( &
                    -(2.0_dp/3.0_dp)*H(kidx,lidx)*(F(iidx,jidx)-c*H(iidx,jidx)) &
                    -(2.0_dp/3.0_dp)*F(kidx,lidx)*H(iidx,jidx) &
                    + c*H(kidx,jidx)*H(iidx,lidx))
          end do
        end do
      end do
    end do

    response%status = DES_STATUS_OK
    response%valid = .true.
  end subroutine evaluate_neo_hookean_isochoric

end module des_neo_hookean_isochoric
