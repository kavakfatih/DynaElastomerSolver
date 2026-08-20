module des_nonlinear_solver
  use des_kinds, only : dp
  implicit none
  private

  public :: nonlinear_solver_settings_t
  public :: nonlinear_solver_settings_valid
  public :: line_search_residual_accepted
  public :: next_residual_growth_streak

  type :: nonlinear_solver_settings_t
    ! Production adaptive Newton yolu için kontrollü damping/backtracking ayarları.
    ! Full Newton ilk adaydır; yalnız residual merit koşulu sağlanmazsa küçültülür.
    logical :: line_search_enabled = .true.
    real(dp) :: line_search_reduction = 0.5_dp
    real(dp) :: line_search_min_scale = 1.5625e-2_dp
    real(dp) :: line_search_armijo = 1.0e-4_dp
    integer :: line_search_max_trials = 8

    ! Kabul edilmiş Newton iterasyonları arasında açık residual patlamasını
    ! deterministic biçimde yakalamak için ardışık büyüme sayacı kullanılır.
    logical :: residual_growth_detection_enabled = .true.
    real(dp) :: residual_growth_factor = 4.0_dp
    integer :: residual_growth_patience = 2
  end type nonlinear_solver_settings_t

contains

  pure logical function nonlinear_solver_settings_valid(settings) result(valid)
    type(nonlinear_solver_settings_t), intent(in) :: settings

    valid = settings%line_search_reduction > 0.0_dp .and. &
            settings%line_search_reduction < 1.0_dp .and. &
            settings%line_search_min_scale > 0.0_dp .and. &
            settings%line_search_min_scale <= 1.0_dp .and. &
            settings%line_search_armijo >= 0.0_dp .and. &
            settings%line_search_armijo < 1.0_dp .and. &
            settings%line_search_max_trials >= 1 .and. &
            settings%residual_growth_factor > 1.0_dp .and. &
            settings%residual_growth_patience >= 1
  end function nonlinear_solver_settings_valid

  pure logical function line_search_residual_accepted( &
      baseline_norm,candidate_norm,scale,settings) result(accepted)
    real(dp), intent(in) :: baseline_norm,candidate_norm,scale
    type(nonlinear_solver_settings_t), intent(in) :: settings
    real(dp) :: target_norm

    accepted = .false.
    if (baseline_norm < 0.0_dp .or. candidate_norm < 0.0_dp) return
    if (scale <= 0.0_dp .or. scale > 1.0_dp) return

    ! Mixed u-P saddle-point sistemi için energy minimization varsaymıyoruz.
    ! Merit ölçüsü free-equation residual infinity normudur. Armijo benzeri
    ! yeterli azalma koşulu tam Newton adımını öncelikli tutar.
    target_norm = baseline_norm*(1.0_dp-settings%line_search_armijo*scale)
    accepted = candidate_norm <= target_norm
  end function line_search_residual_accepted

  pure integer function next_residual_growth_streak( &
      previous_norm,current_norm,previous_streak,settings) result(streak)
    real(dp), intent(in) :: previous_norm,current_norm
    integer, intent(in) :: previous_streak
    type(nonlinear_solver_settings_t), intent(in) :: settings

    streak = 0
    if (.not. settings%residual_growth_detection_enabled) return
    if (previous_streak < 0) return
    if (previous_norm <= 0.0_dp) return

    if (current_norm > settings%residual_growth_factor*previous_norm) then
      streak = previous_streak + 1
    end if
  end function next_residual_growth_streak

end module des_nonlinear_solver
