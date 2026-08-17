module des_solver_history
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  implicit none
  private

  public :: convergence_record_t, convergence_history_t
  public :: clear_convergence_history, append_convergence_record
  public :: mark_last_convergence_status

  type :: convergence_record_t
    integer :: attempt = 0
    integer :: iteration = 0
    integer :: status = DES_STATUS_OK
    real(dp) :: load_factor = 0.0_dp
    real(dp) :: increment_size = 0.0_dp
    real(dp) :: residual_norm = huge(1.0_dp)
    real(dp) :: min_j = huge(1.0_dp)
    logical :: accepted = .false.
  end type convergence_record_t

  type :: convergence_history_t
    type(convergence_record_t), allocatable :: records(:)
    integer :: count = 0
    integer :: capacity = 0
  end type convergence_history_t
contains

  subroutine clear_convergence_history(history)
    type(convergence_history_t), intent(inout) :: history

    if (allocated(history%records)) deallocate(history%records)
    history%count = 0
    history%capacity = 0
  end subroutine clear_convergence_history

  subroutine append_convergence_record(history, record)
    type(convergence_history_t), intent(inout) :: history
    type(convergence_record_t), intent(in) :: record
    type(convergence_record_t), allocatable :: expanded(:)
    integer :: new_capacity

    if (.not. allocated(history%records)) then
      history%capacity = 16
      allocate(history%records(history%capacity))
    else if (history%count >= history%capacity) then
      new_capacity = max(16, 2*history%capacity)
      allocate(expanded(new_capacity))
      expanded(1:history%count) = history%records(1:history%count)
      call move_alloc(expanded, history%records)
      history%capacity = new_capacity
    end if

    history%count = history%count + 1
    history%records(history%count) = record
  end subroutine append_convergence_record

  subroutine mark_last_convergence_status(history, status)
    type(convergence_history_t), intent(inout) :: history
    integer, intent(in) :: status

    if (history%count < 1) return
    history%records(history%count)%status = status
  end subroutine mark_last_convergence_status

end module des_solver_history
