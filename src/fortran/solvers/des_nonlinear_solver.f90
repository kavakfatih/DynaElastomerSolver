module des_nonlinear_solver
  use des_kinds, only : dp
  use, intrinsic :: ieee_arithmetic, only : ieee_is_finite
  implicit none
  private

  integer, parameter, public :: DES_NONFINITE_STAGE_NONE = 0
  integer, parameter, public :: DES_NONFINITE_STAGE_RESIDUAL = 1
  integer, parameter, public :: DES_NONFINITE_STAGE_CORRECTION = 2
  integer, parameter, public :: DES_NONFINITE_STAGE_TRIAL_STATE = 3

  public :: nonlinear_solver_settings_t
  public :: nonlinear_solver_settings_valid
  public :: line_search_residual_accepted
  public :: next_residual_growth_streak
  public :: nonlinear_values_finite

  interface nonlinear_values_finite
    module procedure nonlinear_scalar_finite
    module procedure nonlinear_vector_finite
    module procedure nonlinear_matrix_finite
  end interface nonlinear_values_finite

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

    ! B8.2: range kontrolü tek başına yeterli değildir. Özellikle +Inf bazı
    ! eşitsizlikleri geçebileceği için bütün real policy girdileri önce finite
    ! olmalıdır; NaN/Inf solver davranışını sessizce değiştiremez.
    valid = ieee_is_finite(settings%line_search_reduction) .and. &
            ieee_is_finite(settings%line_search_min_scale) .and. &
            ieee_is_finite(settings%line_search_armijo) .and. &
            ieee_is_finite(settings%residual_growth_factor) .and. &
            settings%line_search_reduction > 0.0_dp .and. &
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
    if (.not. ieee_is_finite(baseline_norm) .or. &
        .not. ieee_is_finite(candidate_norm) .or. &
        .not. ieee_is_finite(scale)) return
    if (baseline_norm < 0.0_dp .or. candidate_norm < 0.0_dp) return
    if (scale <= 0.0_dp .or. scale > 1.0_dp) return

    ! Mixed u-P saddle-point sistemi için energy minimization varsaymıyoruz.
    ! Merit ölçüsü free-equation residual infinity normudur. Armijo benzeri
    ! yeterli azalma koşulu tam Newton adımını öncelikli tutar.
    target_norm = baseline_norm*(1.0_dp-settings%line_search_armijo*scale)
    accepted = ieee_is_finite(target_norm) .and. candidate_norm <= target_norm
  end function line_search_residual_accepted

  pure integer function next_residual_growth_streak( &
      previous_norm,current_norm,previous_streak,settings) result(streak)
    real(dp), intent(in) :: previous_norm,current_norm
    integer, intent(in) :: previous_streak
    type(nonlinear_solver_settings_t), intent(in) :: settings

    streak = 0
    if (.not. settings%residual_growth_detection_enabled) return
    if (.not. ieee_is_finite(previous_norm) .or. &
        .not. ieee_is_finite(current_norm)) return
    if (previous_streak < 0) return
    if (previous_norm <= 0.0_dp) return

    if (current_norm > settings%residual_growth_factor*previous_norm) then
      streak = previous_streak + 1
    end if
  end function next_residual_growth_streak

  pure logical function nonlinear_scalar_finite(value) result(finite)
    real(dp), intent(in) :: value

    finite = ieee_is_finite(value)
  end function nonlinear_scalar_finite

  pure logical function nonlinear_vector_finite(values) result(finite)
    real(dp), intent(in) :: values(:)

    finite = all(ieee_is_finite(values))
  end function nonlinear_vector_finite

  pure logical function nonlinear_matrix_finite(values) result(finite)
    real(dp), intent(in) :: values(:,:)

    finite = all(ieee_is_finite(values))
  end function nonlinear_matrix_finite

end module des_nonlinear_solver
