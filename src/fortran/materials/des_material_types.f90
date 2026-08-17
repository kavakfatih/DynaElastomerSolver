module des_material_types
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_NOT_EVALUATED
  implicit none
  private
  public :: material_kinematics_t, material_response_t, neo_hookean_parameters_t

  type :: material_kinematics_t
    ! Deformasyon gradyanı F, material-point değerlendirmesinin kanonik girdisidir.
    real(dp) :: F(3,3) = 0.0_dp
  end type material_kinematics_t

  type :: material_response_t
    ! V0.1 için minimal cevap seti: enerji, gerilme, tangent, J ve açık durum kodu.
    real(dp) :: energy = 0.0_dp
    real(dp) :: P(3,3) = 0.0_dp
    real(dp) :: cauchy(3,3) = 0.0_dp
    real(dp) :: tangent(3,3,3,3) = 0.0_dp
    real(dp) :: J = 1.0_dp
    integer :: status = DES_STATUS_NOT_EVALUATED
    logical :: valid = .false.
  end type material_response_t

  type :: neo_hookean_parameters_t
    real(dp) :: mu = 0.0_dp
    real(dp) :: lambda = 0.0_dp
  end type neo_hookean_parameters_t
end module des_material_types
