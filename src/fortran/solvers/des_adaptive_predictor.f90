module des_adaptive_predictor
  use des_kinds, only : dp
  use, intrinsic :: ieee_arithmetic, only : ieee_is_finite
  implicit none
  private

  type, public :: adaptive_predictor_settings_t
    ! Predictor varsayilan olarak kapali tutulur. Boylece mevcut adaptive
    ! production davranisi caller acikca istemedikce degismez.
    logical :: enabled = .false.
    real(dp) :: maximum_scale = 2.0_dp
  end type adaptive_predictor_settings_t

  public :: adaptive_predictor_settings_valid
  public :: select_secant_predictor_scale
  public :: build_mixed_secant_predictor

contains

  pure logical function adaptive_predictor_settings_valid(settings)
    type(adaptive_predictor_settings_t), intent(in) :: settings

    adaptive_predictor_settings_valid = &
        ieee_is_finite(settings%maximum_scale) .and. &
        settings%maximum_scale > 0.0_dp
  end function adaptive_predictor_settings_valid

  pure subroutine select_secant_predictor_scale( &
      next_increment,previous_increment,history_available,retry_after_cutback, &
      settings,predictor_scale,predictor_applied)
    real(dp), intent(in) :: next_increment, previous_increment
    logical, intent(in) :: history_available, retry_after_cutback
    type(adaptive_predictor_settings_t), intent(in) :: settings
    real(dp), intent(out) :: predictor_scale
    logical, intent(out) :: predictor_applied

    predictor_scale = 0.0_dp
    predictor_applied = .false.

    if (.not. adaptive_predictor_settings_valid(settings)) return
    if (.not. settings%enabled) return
    if (.not. history_available) return
    if (retry_after_cutback) return
    if (.not. ieee_is_finite(next_increment) .or. &
        .not. ieee_is_finite(previous_increment)) return
    if (next_increment <= 0.0_dp .or. previous_increment <= 0.0_dp) return

    predictor_scale = min(next_increment/previous_increment,settings%maximum_scale)
    predictor_applied = predictor_scale > 0.0_dp
  end subroutine select_secant_predictor_scale

  pure subroutine build_mixed_secant_predictor( &
      previous_u,current_u,previous_pressure,current_pressure,predictor_scale, &
      trial_u,trial_pressure,candidate_valid)
    real(dp), intent(in) :: previous_u(:,:), current_u(:,:)
    real(dp), intent(in) :: previous_pressure(:,:), current_pressure(:,:)
    real(dp), intent(in) :: predictor_scale
    real(dp), intent(out) :: trial_u(:,:), trial_pressure(:,:)
    logical, intent(out) :: candidate_valid

    candidate_valid = .false.
    trial_u = 0.0_dp
    trial_pressure = 0.0_dp

    if (size(previous_u,1) /= size(current_u,1) .or. &
        size(previous_u,2) /= size(current_u,2) .or. &
        size(trial_u,1) /= size(current_u,1) .or. &
        size(trial_u,2) /= size(current_u,2) .or. &
        size(previous_pressure,1) /= size(current_pressure,1) .or. &
        size(previous_pressure,2) /= size(current_pressure,2) .or. &
        size(trial_pressure,1) /= size(current_pressure,1) .or. &
        size(trial_pressure,2) /= size(current_pressure,2)) return

    trial_u = current_u
    trial_pressure = current_pressure

    if (.not. ieee_is_finite(predictor_scale) .or. predictor_scale <= 0.0_dp) return
    if (.not. all(ieee_is_finite(previous_u)) .or. &
        .not. all(ieee_is_finite(current_u)) .or. &
        .not. all(ieee_is_finite(previous_pressure)) .or. &
        .not. all(ieee_is_finite(current_pressure))) return

    trial_u = current_u + predictor_scale*(current_u-previous_u)
    trial_pressure = current_pressure + &
        predictor_scale*(current_pressure-previous_pressure)

    if (.not. all(ieee_is_finite(trial_u)) .or. &
        .not. all(ieee_is_finite(trial_pressure))) then
      trial_u = current_u
      trial_pressure = current_pressure
      return
    end if

    candidate_valid = .true.
  end subroutine build_mixed_secant_predictor

end module des_adaptive_predictor
