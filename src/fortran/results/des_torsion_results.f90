module des_torsion_results
  use, intrinsic :: ieee_arithmetic, only : ieee_is_finite
  use des_kinds, only : dp, i64
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_PARAMETERS, &
      DES_ERROR_INVALID_CONSTRAINT
  implicit none
  private

  real(dp), parameter :: radians_to_degrees = 180.0_dp/acos(-1.0_dp)

  type, public :: torsion_response_point_t
    real(dp) :: angle_radians = 0.0_dp
    real(dp) :: angle_degrees = 0.0_dp
    real(dp) :: reaction_torque = 0.0_dp
    real(dp) :: secant_torsional_stiffness = 0.0_dp
  end type torsion_response_point_t

  public :: reaction_torque_from_residual
  public :: build_torsion_response_point

contains

  subroutine reaction_torque_from_residual( &
      residual, torsion_equations, reaction_torque, status)
    ! ROTY/twist DOF boyutsuz açı [rad] olduğundan conjugate residual doğrudan
    ! torque birimindedir. Bu helper, constrained torsion equation reaksiyonlarını
    ! full-360 axisymmetric element sözleşmesine göre toplar.
    real(dp), intent(in) :: residual(:)
    integer(i64), intent(in) :: torsion_equations(:)
    real(dp), intent(out) :: reaction_torque
    integer, intent(out) :: status
    integer :: i

    reaction_torque = 0.0_dp
    status = DES_ERROR_INVALID_CONSTRAINT

    if (size(torsion_equations) < 1) return
    if (.not. all(ieee_is_finite(residual))) then
      status = DES_ERROR_INVALID_PARAMETERS
      return
    end if

    do i = 1,size(torsion_equations)
      if (torsion_equations(i) < 1_i64 .or. &
          torsion_equations(i) > size(residual,kind=i64)) return
      reaction_torque = reaction_torque + residual(torsion_equations(i))
    end do

    status = DES_STATUS_OK
  end subroutine reaction_torque_from_residual

  subroutine build_torsion_response_point( &
      angle_radians, reaction_torque, response, status)
    real(dp), intent(in) :: angle_radians, reaction_torque
    type(torsion_response_point_t), intent(out) :: response
    integer, intent(out) :: status

    response = torsion_response_point_t()
    status = DES_ERROR_INVALID_PARAMETERS

    if (.not. ieee_is_finite(angle_radians) .or. &
        .not. ieee_is_finite(reaction_torque)) return

    response%angle_radians = angle_radians
    response%angle_degrees = angle_radians*radians_to_degrees
    response%reaction_torque = reaction_torque

    if (abs(angle_radians) > sqrt(epsilon(1.0_dp))) then
      response%secant_torsional_stiffness = reaction_torque/angle_radians
    else
      response%secant_torsional_stiffness = 0.0_dp
    end if

    status = DES_STATUS_OK
  end subroutine build_torsion_response_point

end module des_torsion_results
