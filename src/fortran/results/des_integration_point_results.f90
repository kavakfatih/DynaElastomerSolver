module des_integration_point_results
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_NOT_EVALUATED
  implicit none
  private

  integer, parameter, public :: DES_PRESSURE_SOURCE_NONE = 0
  integer, parameter, public :: DES_PRESSURE_SOURCE_DERIVED_CONSTITUTIVE = 1
  integer, parameter, public :: DES_PRESSURE_SOURCE_INDEPENDENT_UNKNOWN = 2

  integer, parameter, public :: DES_PRESSURE_MEASURE_NONE = 0
  integer, parameter, public :: DES_PRESSURE_MEASURE_LOGJ_CONJUGATE = 1
  integer, parameter, public :: DES_PRESSURE_MEASURE_HERRMANN_HYDROSTATIC = 2

  public :: integration_point_result_t, integration_point_results_t, &
            initialize_q4_integration_results, &
            set_derived_logj_pressure, set_independent_logj_pressure, &
            set_independent_herrmann_pressure

  type :: integration_point_result_t
    integer :: element_id = 0
    integer :: point_id = 0
    real(dp) :: xi = 0.0_dp
    real(dp) :: eta = 0.0_dp
    real(dp) :: reference_weight = 0.0_dp

    real(dp) :: F(3,3) = 0.0_dp
    real(dp) :: J = 1.0_dp

    real(dp) :: constitutive_F(3,3) = 0.0_dp
    real(dp) :: constitutive_J = 1.0_dp

    real(dp) :: P(3,3) = 0.0_dp
    real(dp) :: cauchy(3,3) = 0.0_dp
    real(dp) :: strain_energy_density = 0.0_dp

    ! Pressure contract:
    !
    ! LOGJ_CONJUGATE, displacement/F-bar gibi formulationlarda constitutive
    ! volumetric diagnostic degerini tasir: p_logJ=lambda*ln(Jc).
    !
    ! HERRMANN_HYDROSTATIC ise mixed u-p formulationinda bagimsiz cozulmus
    ! hydrostatic pressure unknown'udur. Dyna isaret sozlesmesinde p>0 sikismadir
    ! ve Cauchy gerilme katkisi -p I seklindedir.
    !
    ! Bu iki pressure measure birbirinin yerine kullanilmaz.
    real(dp) :: pressure_value = 0.0_dp
    integer :: pressure_source = DES_PRESSURE_SOURCE_NONE
    integer :: pressure_measure = DES_PRESSURE_MEASURE_NONE
    logical :: pressure_valid = .false.

    integer :: status = DES_STATUS_NOT_EVALUATED
    logical :: valid = .false.
  end type integration_point_result_t

  type :: integration_point_results_t
    type(integration_point_result_t), allocatable :: points(:)
    integer :: points_per_element = 4
  contains
    procedure :: count => integration_point_result_count
  end type integration_point_results_t

contains

  subroutine initialize_q4_integration_results(results, element_count)
    type(integration_point_results_t), intent(out) :: results
    integer, intent(in) :: element_count

    results%points_per_element = 4
    if (element_count > 0) then
      allocate(results%points(4*element_count))
    else
      allocate(results%points(0))
    end if
  end subroutine initialize_q4_integration_results

  pure subroutine set_derived_logj_pressure(point, lambda_value, constitutive_j_value)
    type(integration_point_result_t), intent(inout) :: point
    real(dp), intent(in) :: lambda_value, constitutive_j_value

    call clear_pressure(point)
    if (lambda_value <= 0.0_dp .or. constitutive_j_value <= 0.0_dp) return

    point%constitutive_J = constitutive_j_value
    point%pressure_value = lambda_value*log(constitutive_j_value)
    point%pressure_source = DES_PRESSURE_SOURCE_DERIVED_CONSTITUTIVE
    point%pressure_measure = DES_PRESSURE_MEASURE_LOGJ_CONJUGATE
    point%pressure_valid = .true.
  end subroutine set_derived_logj_pressure

  pure subroutine set_independent_logj_pressure(point, pressure_value)
    ! Legacy mixed prototipler icin korunur. Yeni Herrmann yolu bu setter'i kullanmaz.
    type(integration_point_result_t), intent(inout) :: point
    real(dp), intent(in) :: pressure_value

    call clear_pressure(point)
    point%pressure_value = pressure_value
    point%pressure_source = DES_PRESSURE_SOURCE_INDEPENDENT_UNKNOWN
    point%pressure_measure = DES_PRESSURE_MEASURE_LOGJ_CONJUGATE
    point%pressure_valid = .true.
  end subroutine set_independent_logj_pressure

  pure subroutine set_independent_herrmann_pressure(point, pressure_value)
    ! Herrmann/mixed u-p pressure unknown'u: p>0 sikisma, sigma_p=-p I.
    type(integration_point_result_t), intent(inout) :: point
    real(dp), intent(in) :: pressure_value

    call clear_pressure(point)
    point%pressure_value = pressure_value
    point%pressure_source = DES_PRESSURE_SOURCE_INDEPENDENT_UNKNOWN
    point%pressure_measure = DES_PRESSURE_MEASURE_HERRMANN_HYDROSTATIC
    point%pressure_valid = .true.
  end subroutine set_independent_herrmann_pressure

  pure subroutine clear_pressure(point)
    type(integration_point_result_t), intent(inout) :: point

    point%pressure_value = 0.0_dp
    point%pressure_source = DES_PRESSURE_SOURCE_NONE
    point%pressure_measure = DES_PRESSURE_MEASURE_NONE
    point%pressure_valid = .false.
  end subroutine clear_pressure

  integer function integration_point_result_count(this) result(n)
    class(integration_point_results_t), intent(in) :: this
    if (allocated(this%points)) then
      n = size(this%points)
    else
      n = 0
    end if
  end function integration_point_result_count

end module des_integration_point_results
