program test_solver_state_history
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_NONPOSITIVE_J, &
                         DES_ERROR_CUTBACK_EXHAUSTED
  use des_solution_state, only : solution_state_t, initialize_solution_state, &
                                 begin_solution_trial, commit_solution_state, &
                                 revert_solution_state
  use des_material_types, only : neo_hookean_parameters_t
  use des_q4_plane_strain_newton_solver, only : newton_report_t, &
       solve_q4_plane_strain_adaptive_displacement_control
  implicit none

  type(solution_state_t) :: state
  real(dp) :: initial(2,2)
  real(dp) :: X(4,2), u(4,2), u_fail(4,2)
  real(dp) :: residual(8), residual_fail(8)
  integer :: connectivity(1,4), prescribed_dofs(6)
  integer :: i, accepted_count, failure_count
  real(dp) :: prescribed_values(6)
  type(neo_hookean_parameters_t) :: parameters
  type(newton_report_t) :: report, report_fail

  initial = 0.0_dp
  call initialize_solution_state(state, initial)
  call begin_solution_trial(state)
  state%trial(1,1) = 2.0_dp
  call commit_solution_state(state)
  if (abs(state%committed(1,1)-2.0_dp) > 1.0e-14_dp) then
    error stop 'Commit başarısız.'
  end if

  call begin_solution_trial(state)
  state%trial(1,1) = 9.0_dp
  call revert_solution_state(state)
  if (abs(state%trial(1,1)-2.0_dp) > 1.0e-14_dp) then
    error stop 'Revert başarısız.'
  end if
  if (state%commit_count /= 1 .or. state%revert_count /= 1) then
    error stop 'State sayaçları hatalı.'
  end if

  X(1,:) = [0.0_dp, 0.0_dp]
  X(2,:) = [1.0_dp, 0.0_dp]
  X(3,:) = [1.0_dp, 1.0_dp]
  X(4,:) = [0.0_dp, 1.0_dp]
  connectivity(1,:) = [1,2,3,4]
  prescribed_dofs = [1,2,4,7,3,5]
  prescribed_values = [0.0_dp,0.0_dp,0.0_dp,0.0_dp,1.0_dp,1.0_dp]

  parameters%mu = 2.3_dp
  parameters%lambda = 19.0_dp

  u = 0.0_dp
  call solve_q4_plane_strain_adaptive_displacement_control( &
       X, connectivity, parameters, prescribed_dofs, prescribed_values, &
       1.0_dp, 0.125_dp, 0.5_dp, 4, 10, 1.0e-10_dp, u, residual, report)

  if (.not. report%converged .or. report%status /= DES_STATUS_OK) then
    error stop 'Adaptive çözüm başarısız.'
  end if
  if (report%state_commit_count /= report%increments_converged) then
    error stop 'Commit sayısı kabul edilen increment sayısıyla uyuşmuyor.'
  end if
  if (report%state_revert_count /= report%cutback_count) then
    error stop 'Revert sayısı cutback sayısıyla uyuşmuyor.'
  end if
  if (report%history%count < 1) error stop 'Convergence history boş.'

  accepted_count = 0
  failure_count = 0
  do i = 1,report%history%count
    if (report%history%records(i)%accepted) accepted_count = accepted_count + 1
    if (report%history%records(i)%status == DES_ERROR_NONPOSITIVE_J) then
      failure_count = failure_count + 1
    end if
  end do

  if (accepted_count /= report%increments_converged) then
    error stop 'History içindeki accepted kayıtları hatalı.'
  end if
  if (failure_count < 1) then
    error stop 'History non-positive J olayını kaydetmedi.'
  end if

  ! Cutback hakkı verilmezse solver, başarısız trial state'i dışarı sızdırmadan
  ! son committed state'e dönmeli ve açık exhaustion durumu vermelidir.
  u_fail = 0.0_dp
  call solve_q4_plane_strain_adaptive_displacement_control( &
       X, connectivity, parameters, prescribed_dofs, prescribed_values, &
       1.0_dp, 0.125_dp, 0.5_dp, 0, 10, 1.0e-10_dp, &
       u_fail, residual_fail, report_fail)

  if (report_fail%status /= DES_ERROR_CUTBACK_EXHAUSTED) then
    error stop 'Cutback exhaustion bekleniyordu.'
  end if
  if (report_fail%last_failure_status /= DES_ERROR_NONPOSITIVE_J) then
    error stop 'Alt failure nedeni korunmadı.'
  end if
  if (report_fail%state_commit_count /= 0) then
    error stop 'Başarısız çözüm commit yapmamalı.'
  end if
  if (report_fail%state_revert_count /= 1) then
    error stop 'Başarısız çözüm bir rollback yapmalı.'
  end if
  if (maxval(abs(u_fail)) > 1.0e-14_dp) then
    error stop 'Exhaustion sonrası committed state korunmadı.'
  end if

  write(*,'(A,I0)') 'History kayıt sayısı = ', report%history%count
  write(*,'(A,I0)') 'Commit sayısı = ', report%state_commit_count
  write(*,'(A,I0)') 'Revert sayısı = ', report%state_revert_count
  write(*,'(A)') 'State/history/cutback exhaustion testi BASARILI.'
end program test_solver_state_history
