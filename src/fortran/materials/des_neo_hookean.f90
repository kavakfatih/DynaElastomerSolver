module des_neo_hookean
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_PARAMETERS, &
                         DES_ERROR_SINGULAR_F, DES_ERROR_NONPOSITIVE_J
  use des_tensor3, only : inverse3, identity3
  use des_material_types, only : material_kinematics_t, material_response_t, neo_hookean_parameters_t
  implicit none
  private
  public :: evaluate_neo_hookean, validate_neo_hookean_parameters
contains

  pure subroutine validate_neo_hookean_parameters(parameters, valid)
    type(neo_hookean_parameters_t), intent(in) :: parameters
    logical, intent(out) :: valid
    real(dp) :: bulk_modulus

    ! 3B = 3*lambda + 2*mu olduğundan bulk modulus pozitif olmalıdır.
    bulk_modulus = parameters%lambda + (2.0_dp/3.0_dp)*parameters%mu
    valid = parameters%mu > 0.0_dp .and. bulk_modulus > 0.0_dp
  end subroutine validate_neo_hookean_parameters

  pure subroutine evaluate_neo_hookean(kinematics, parameters, response)
    type(material_kinematics_t), intent(in) :: kinematics
    type(neo_hookean_parameters_t), intent(in) :: parameters
    type(material_response_t), intent(out) :: response

    real(dp) :: F(3,3), Finv(3,3), FinvT(3,3), b(3,3), I(3,3)
    real(dp) :: J, lnJ, I1, alpha
    integer :: iidx, jidx, kidx, lidx
    logical :: ok, parameters_valid

    response = material_response_t()
    F = kinematics%F

    call validate_neo_hookean_parameters(parameters, parameters_valid)
    if (.not. parameters_valid) then
      response%status = DES_ERROR_INVALID_PARAMETERS
      return
    end if

    call inverse3(F, Finv, J, ok)
    response%J = J
    if (.not. ok) then
      response%status = DES_ERROR_SINGULAR_F
      return
    end if
    if (J <= 0.0_dp) then
      response%status = DES_ERROR_NONPOSITIVE_J
      return
    end if

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
    ! Bu tensör material-point testinde merkezi finite-difference ile bağımsız kontrol edilir.
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

    response%status = DES_STATUS_OK
    response%valid = .true.
  end subroutine evaluate_neo_hookean

end module des_neo_hookean
