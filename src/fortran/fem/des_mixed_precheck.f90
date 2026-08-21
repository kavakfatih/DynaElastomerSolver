module des_mixed_precheck
  use des_kinds, only : dp, i64
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONSTRAINT
  use des_2d_dof_manager, only : dof_layout_2d_t
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

  type, public :: mixed_dof_balance_i64_t
    ! Yeni 2D field-based numbering için canonical i64 precheck raporu.
    integer(i64) :: kinematic_equations = 0_i64
    integer(i64) :: pressure_equations = 0_i64
    integer(i64) :: prescribed_kinematic_equations = 0_i64
    integer(i64) :: free_kinematic_equations = 0_i64
    real(dp) :: nd_over_np = 0.0_dp
    logical :: overconstrained_by_count = .false.
  end type mixed_dof_balance_i64_t

  public :: assess_mixed_dof_balance
  public :: assess_2d_mixed_dof_balance_i64

contains

  subroutine assess_mixed_dof_balance( &
      node_count, element_count, displacement_components, pressure_dofs_per_element, &
      prescribed_displacement_dofs, balance, status)
    ! Legacy ANSYS Nd/Np-benzeri precheck metriği. Bu API mevcut Q4/Q9
    ! regression çağrılarını korur; yeni 2D database yolu aşağıdaki i64 helper'ı
    ! kullanır.
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

  subroutine assess_2d_mixed_dof_balance_i64( &
      layout, prescribed_kinematic_equations, balance, status)
    type(dof_layout_2d_t), intent(in) :: layout
    integer(i64), intent(in) :: prescribed_kinematic_equations(:)
    type(mixed_dof_balance_i64_t), intent(out) :: balance
    integer, intent(out) :: status

    integer(i64) :: kinematic_equations
    integer :: i, j

    balance = mixed_dof_balance_i64_t()
    status = DES_ERROR_INVALID_CONSTRAINT

    if (layout%nodal_equation_count < 0_i64 .or. &
        layout%generalized_equation_count < 0_i64 .or. &
        layout%pressure_equation_count <= 0_i64) return

    if (layout%nodal_equation_count > &
        huge(0_i64)-layout%generalized_equation_count) return
    kinematic_equations = layout%nodal_equation_count + layout%generalized_equation_count
    if (kinematic_equations <= 0_i64) return

    ! BC listesi model cardinality'sine göre küçüktür; dev logical mask allocate
    ! etmek yerine i64 equation ID'lerini doğrudan doğrulayıp duplicate saymayız.
    do i = 1,size(prescribed_kinematic_equations)
      if (prescribed_kinematic_equations(i) < 1_i64 .or. &
          prescribed_kinematic_equations(i) > kinematic_equations) return
      do j = i+1,size(prescribed_kinematic_equations)
        if (prescribed_kinematic_equations(i) == prescribed_kinematic_equations(j)) return
      end do
    end do

    balance%kinematic_equations = kinematic_equations
    balance%pressure_equations = layout%pressure_equation_count
    balance%prescribed_kinematic_equations = &
        size(prescribed_kinematic_equations,kind=i64)
    balance%free_kinematic_equations = balance%kinematic_equations &
        - balance%prescribed_kinematic_equations
    balance%nd_over_np = real(balance%free_kinematic_equations,dp) &
        / real(balance%pressure_equations,dp)
    balance%overconstrained_by_count = &
        balance%free_kinematic_equations < balance%pressure_equations

    status = DES_STATUS_OK
  end subroutine assess_2d_mixed_dof_balance_i64

end module des_mixed_precheck
