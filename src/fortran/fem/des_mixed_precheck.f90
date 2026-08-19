module des_mixed_precheck
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONSTRAINT
  implicit none
  private

  type, public :: mixed_dof_balance_t
    integer :: displacement_equations = 0
    integer :: pressure_equations = 0
    integer :: prescribed_displacement_equations = 0
    integer :: free_displacement_equations = 0
    real(dp) :: nd_over_np = 0.0_dp
    logical :: overconstrained_by_count = .false.
  end type mixed_dof_balance_t

  public :: assess_mixed_dof_balance

contains

  subroutine assess_mixed_dof_balance( &
      node_count, element_count, displacement_components, pressure_dofs_per_element, &
      prescribed_displacement_dofs, balance, status)
    ! ANSYS'teki Nd/Np yaklaşımına benzer bir ilk global mixed-system precheck metriği.
    ! Bu test inf-sup stability kanıtının yerine geçmez; yalnız displacement constraint
    ! sayısının pressure unknown sayısına göre açık biçimde yetersiz olduğu durumları
    ! çözüm başlamadan görünür kılar.
    integer, intent(in) :: node_count, element_count
    integer, intent(in) :: displacement_components, pressure_dofs_per_element
    integer, intent(in) :: prescribed_displacement_dofs(:)
    type(mixed_dof_balance_t), intent(out) :: balance
    integer, intent(out) :: status

    logical, allocatable :: is_prescribed(:)
    integer :: i, dof

    balance = mixed_dof_balance_t()

    if (node_count <= 0 .or. element_count <= 0 .or. &
        displacement_components <= 0 .or. pressure_dofs_per_element <= 0) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    balance%displacement_equations = node_count*displacement_components
    balance%pressure_equations = element_count*pressure_dofs_per_element
    allocate(is_prescribed(balance%displacement_equations))
    is_prescribed = .false.

    do i = 1,size(prescribed_displacement_dofs)
      dof = prescribed_displacement_dofs(i)
      if (dof < 1 .or. dof > balance%displacement_equations) then
        status = DES_ERROR_INVALID_CONSTRAINT
        return
      end if
      is_prescribed(dof) = .true.
    end do

    balance%prescribed_displacement_equations = count(is_prescribed)
    balance%free_displacement_equations = balance%displacement_equations &
                                        - balance%prescribed_displacement_equations
    balance%nd_over_np = real(balance%free_displacement_equations,dp) &
                       / real(balance%pressure_equations,dp)
    balance%overconstrained_by_count = &
        balance%free_displacement_equations < balance%pressure_equations

    status = DES_STATUS_OK
  end subroutine assess_mixed_dof_balance

end module des_mixed_precheck
