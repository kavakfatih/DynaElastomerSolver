module des_adaptive_increment
  use des_kinds, only : dp
  use, intrinsic :: ieee_arithmetic, only : ieee_is_finite
  implicit none
  private

  type, public :: adaptive_increment_settings_t
    ! Geriye uyumluluk icin growth varsayilan olarak kapali kalir. Production
    ! caller kontrollu buyutmeyi acikca etkinlestirir.
    logical :: growth_enabled = .false.
    real(dp) :: growth_factor = 1.5_dp
    integer :: growth_iteration_threshold = 4
    real(dp) :: maximum_increment = 1.0_dp
  end type adaptive_increment_settings_t

  public :: adaptive_increment_settings_valid
  public :: select_next_adaptive_increment

contains

  pure logical function adaptive_increment_settings_valid(settings)
    type(adaptive_increment_settings_t), intent(in) :: settings

    adaptive_increment_settings_valid = &
        ieee_is_finite(settings%growth_factor) .and. &
        ieee_is_finite(settings%maximum_increment) .and. &
        settings%growth_factor > 1.0_dp .and. &
        settings%growth_iteration_threshold >= 0 .and. &
        settings%maximum_increment > 0.0_dp .and. &
        settings%maximum_increment <= 1.0_dp
  end function adaptive_increment_settings_valid

  pure subroutine select_next_adaptive_increment( &
      current_increment,remaining_load,converged_iterations,had_cutback, &
      settings,next_increment,growth_applied)
    ! Bir increment ancak committed basari sonrasinda bu policy'ye gelir.
    ! Cutback gecmisi veya zor Newton yakinsamasi varsa buyutme yapilmaz.
    real(dp), intent(in) :: current_increment, remaining_load
    integer, intent(in) :: converged_iterations
    logical, intent(in) :: had_cutback
    type(adaptive_increment_settings_t), intent(in) :: settings
    real(dp), intent(out) :: next_increment
    logical, intent(out) :: growth_applied

    real(dp) :: base_increment, candidate_increment, comparison_tol

    next_increment = 0.0_dp
    growth_applied = .false.

    if (.not. ieee_is_finite(current_increment) .or. &
        .not. ieee_is_finite(remaining_load) .or. &
        current_increment <= 0.0_dp .or. remaining_load < 0.0_dp .or. &
        converged_iterations < 0 .or. &
        .not. adaptive_increment_settings_valid(settings)) return

    base_increment = min(current_increment,remaining_load)
    next_increment = base_increment
    if (remaining_load <= 0.0_dp) return
    if (.not. settings%growth_enabled) return
    if (had_cutback) return
    if (converged_iterations > settings%growth_iteration_threshold) return

    ! Carpim tasmasini onlemek icin maximum cap'e ulasacak durumda dogrudan
    ! cap kullanilir. Ardindan kalan yuk degeri ikinci kesin sinirdir.
    if (current_increment >= settings%maximum_increment/settings%growth_factor) then
      candidate_increment = settings%maximum_increment
    else
      candidate_increment = current_increment*settings%growth_factor
    end if
    candidate_increment = min(candidate_increment,settings%maximum_increment)
    candidate_increment = min(candidate_increment,remaining_load)

    comparison_tol = 100.0_dp*epsilon(1.0_dp)*max(1.0_dp,abs(base_increment))
    if (candidate_increment > base_increment+comparison_tol) then
      next_increment = candidate_increment
      growth_applied = .true.
    end if
  end subroutine select_next_adaptive_increment

end module des_adaptive_increment
