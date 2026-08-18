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

  public :: integration_point_result_t, integration_point_results_t, &
            initialize_q4_integration_results, &
            set_derived_logj_pressure, set_independent_logj_pressure

  type :: integration_point_result_t
    integer :: element_id = 0
    integer :: point_id = 0
    real(dp) :: xi = 0.0_dp
    real(dp) :: eta = 0.0_dp
    real(dp) :: reference_weight = 0.0_dp

    ! Kinematik deformation gradient ve determinant. Bunlar gerçek geometrik
    ! state'i temsil eder; F-bar gibi formulationlarda malzeme modelinin gördüğü
    ! constitutive state ile aynı olmak zorunda değildir.
    real(dp) :: F(3,3) = 0.0_dp
    real(dp) :: J = 1.0_dp

    ! Malzeme modelinin gerçekten değerlendirildiği state.
    ! Standart displacement Q4'te constitutive_F=F ve constitutive_J=J'dir.
    ! F-bar Q4'te constitutive_F=F_bar ve constitutive_J=J_bar'dır.
    real(dp) :: constitutive_F(3,3) = 0.0_dp
    real(dp) :: constitutive_J = 1.0_dp

    real(dp) :: P(3,3) = 0.0_dp
    real(dp) :: cauchy(3,3) = 0.0_dp
    real(dp) :: strain_energy_density = 0.0_dp

    ! Pressure contract:
    !
    ! DES_PRESSURE_MEASURE_LOGJ_CONJUGATE için değer p_logJ=lambda*ln(Jc)
    ! sözleşmesini kullanır. Jc=constitutive_J'dir. Bu skaler, ln(J)'ye eşlenik
    ! volumetric constitutive diagnostic'tir; -tr(sigma)/3 hidrostatik basıncı
    ! değildir. Pozitif işaret expansion/tension tarafına karşılık gelir.
    !
    ! source alanı değerin nereden geldiğini zorunlu olarak ayırır:
    ! - DERIVED_CONSTITUTIVE: displacement/F-bar gibi bağımsız pressure DOF'u
    !   olmayan formulationlarda constitutive state'ten türetilir.
    ! - INDEPENDENT_UNKNOWN: mixed formulationın çözülen pressure unknown'udur.
    real(dp) :: pressure_value = 0.0_dp
    integer :: pressure_source = DES_PRESSURE_SOURCE_NONE
    integer :: pressure_measure = DES_PRESSURE_MEASURE_NONE
    logical :: pressure_valid = .false.

    integer :: status = DES_STATUS_NOT_EVALUATED
    logical :: valid = .false.
  end type integration_point_result_t

  type :: integration_point_results_t
    ! Ham Gauss-point verisi düz bir dizi halinde saklanır.
    ! Nodal extrapolation/averaging yapılmaz; provenance Gauss-point seviyesinde
    ! korunur.
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

    point%pressure_value = 0.0_dp
    point%pressure_source = DES_PRESSURE_SOURCE_NONE
    point%pressure_measure = DES_PRESSURE_MEASURE_NONE
    point%pressure_valid = .false.

    if (lambda_value <= 0.0_dp .or. constitutive_j_value <= 0.0_dp) return

    point%constitutive_J = constitutive_j_value
    point%pressure_value = lambda_value*log(constitutive_j_value)
    point%pressure_source = DES_PRESSURE_SOURCE_DERIVED_CONSTITUTIVE
    point%pressure_measure = DES_PRESSURE_MEASURE_LOGJ_CONJUGATE
    point%pressure_valid = .true.
  end subroutine set_derived_logj_pressure

  pure subroutine set_independent_logj_pressure(point, pressure_value)
    type(integration_point_result_t), intent(inout) :: point
    real(dp), intent(in) :: pressure_value

    point%pressure_value = pressure_value
    point%pressure_source = DES_PRESSURE_SOURCE_INDEPENDENT_UNKNOWN
    point%pressure_measure = DES_PRESSURE_MEASURE_LOGJ_CONJUGATE
    point%pressure_valid = .true.
  end subroutine set_independent_logj_pressure

  integer function integration_point_result_count(this) result(n)
    class(integration_point_results_t), intent(in) :: this
    if (allocated(this%points)) then
      n = size(this%points)
    else
      n = 0
    end if
  end function integration_point_result_count

end module des_integration_point_results
