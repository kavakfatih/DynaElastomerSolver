module des_solution_state
  use des_kinds, only : dp
  implicit none
  private

  public :: solution_state_t
  public :: initialize_solution_state, begin_solution_trial
  public :: commit_solution_state, revert_solution_state

  type :: solution_state_t
    real(dp), allocatable :: committed(:,:)
    real(dp), allocatable :: trial(:,:)
    integer :: commit_count = 0
    integer :: revert_count = 0
    logical :: initialized = .false.
  end type solution_state_t
contains

  subroutine initialize_solution_state(state, initial_values)
    type(solution_state_t), intent(inout) :: state
    real(dp), intent(in) :: initial_values(:,:)

    if (allocated(state%committed)) deallocate(state%committed)
    if (allocated(state%trial)) deallocate(state%trial)

    allocate(state%committed(size(initial_values,1), size(initial_values,2)))
    allocate(state%trial(size(initial_values,1), size(initial_values,2)))

    state%committed = initial_values
    state%trial = initial_values
    state%commit_count = 0
    state%revert_count = 0
    state%initialized = .true.
  end subroutine initialize_solution_state

  subroutine begin_solution_trial(state)
    type(solution_state_t), intent(inout) :: state

    if (.not. state%initialized) return
    state%trial = state%committed
  end subroutine begin_solution_trial

  subroutine commit_solution_state(state)
    type(solution_state_t), intent(inout) :: state

    if (.not. state%initialized) return
    state%committed = state%trial
    state%commit_count = state%commit_count + 1
  end subroutine commit_solution_state

  subroutine revert_solution_state(state)
    type(solution_state_t), intent(inout) :: state

    if (.not. state%initialized) return
    state%trial = state%committed
    state%revert_count = state%revert_count + 1
  end subroutine revert_solution_state

end module des_solution_state
