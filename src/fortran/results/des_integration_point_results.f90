module des_integration_point_results
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_NOT_EVALUATED
  implicit none
  private

  public :: integration_point_result_t, integration_point_results_t, &
            initialize_q4_integration_results

  type :: integration_point_result_t
    integer :: element_id = 0
    integer :: point_id = 0
    real(dp) :: xi = 0.0_dp
    real(dp) :: eta = 0.0_dp
    real(dp) :: reference_weight = 0.0_dp
    real(dp) :: F(3,3) = 0.0_dp
    real(dp) :: J = 1.0_dp
    real(dp) :: P(3,3) = 0.0_dp
    real(dp) :: cauchy(3,3) = 0.0_dp
    real(dp) :: strain_energy_density = 0.0_dp
    integer :: status = DES_STATUS_NOT_EVALUATED
    logical :: valid = .false.
  end type integration_point_result_t

  type :: integration_point_results_t
    ! Ham Gauss-point verisi düz bir dizi halinde saklanır.
    ! V0.2'de nodal extrapolation/averaging yapılmaz.
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

  integer function integration_point_result_count(this) result(n)
    class(integration_point_results_t), intent(in) :: this
    if (allocated(this%points)) then
      n = size(this%points)
    else
      n = 0
    end if
  end function integration_point_result_count

end module des_integration_point_results
