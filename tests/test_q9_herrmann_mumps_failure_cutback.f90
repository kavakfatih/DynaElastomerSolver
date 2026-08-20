program test_q9_herrmann_mumps_failure_cutback
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_LINEAR_SOLVE, &
                         DES_ERROR_CUTBACK_EXHAUSTED
  use des_internal_mesh, only : internal_mesh_t, initialize_q9_internal_mesh
  use des_linear_solver, only : linear_solver_settings_t, &
                                production_linear_solver_settings, &
                                DES_LINEAR_BACKEND_MUMPS_DIRECT
  use des_q4_plane_strain_newton_solver, only : newton_report_t
  use des_q9_plane_strain_herrmann_force_solver, only : &
      solve_q9_internal_mesh_herrmann_adaptive_force_control
  implicit none

  ! B7b fault-path regression:
  ! - Q9/P1 fully incompressible Kpp=0 kullanilir.
  ! - Yalniz bir displacement DOF serbest birakilir; 3 pressure DOF ile kalan
  !   free mixed blok rank-deficient olur.
  ! - MUMPS null-pivot regularization bu testte bilincli kapatilir. Böylece
  !   numeric factorization gercek DES_ERROR_LINEAR_SOLVE ile durur.
  ! - Adaptive solver her basarisiz trial'i revert etmeli, cutback uygulamali
  !   ve max_cutbacks+1 denemeden sonra committed u/p state'ini bozmadan
  !   DES_ERROR_CUTBACK_EXHAUSTED ile cikmalidir.

  real(dp) :: X(9,2),u(9,2),p(1,3),external_force(18),residual(21)
  integer :: connectivity(1,9),status
  integer, parameter :: fixed_dofs(17) = [ &
      1,2,3,5,6,7,8,9,10,11,12,13,14,15,16,17,18 ]
  integer, parameter :: max_cutbacks = 2
  type(internal_mesh_t) :: mesh
  type(newton_report_t) :: report
  type(linear_solver_settings_t) :: settings

  X(1,:) = [0.0_dp,0.0_dp]
  X(2,:) = [1.0_dp,0.0_dp]
  X(3,:) = [1.0_dp,1.0_dp]
  X(4,:) = [0.0_dp,1.0_dp]
  X(5,:) = [0.5_dp,0.0_dp]
  X(6,:) = [1.0_dp,0.5_dp]
  X(7,:) = [0.5_dp,1.0_dp]
  X(8,:) = [0.0_dp,0.5_dp]
  X(9,:) = [0.5_dp,0.5_dp]
  connectivity(1,:) = [1,2,3,4,5,6,7,8,9]

  call initialize_q9_internal_mesh(mesh,X,connectivity,status)
  if (status /= DES_STATUS_OK) then
    error stop 'MUMPS failure-cutback Q9 mesh kurulamadi.'
  end if

  u = 0.0_dp
  p = 0.0_dp
  external_force = 0.0_dp
  external_force(4) = 1.0e-2_dp

  settings = production_linear_solver_settings()
  settings%backend = DES_LINEAR_BACKEND_MUMPS_DIRECT

  ! Production default null-pivot detection singular sistemleri diagnostics ile
  ! ele alabilir. Bu fault-injection testi ise MUMPS'in gerçek factorization error
  ! yolunu deterministik olarak zorlamak icin regularization/detection'i kapatir.
  settings%direct_null_pivot_detection = .false.

  call solve_q9_internal_mesh_herrmann_adaptive_force_control( &
      mesh,2.0_dp,0.0_dp,fixed_dofs,external_force, &
      1.0_dp,0.125_dp,0.5_dp,max_cutbacks,5,1.0e-12_dp, &
      u,p,residual,report,linear_settings=settings)

  if (report%status /= DES_ERROR_CUTBACK_EXHAUSTED) then
    error stop 'MUMPS factorization failure cutback exhaustion statusu yanlis.'
  end if
  if (report%last_failure_status /= DES_ERROR_LINEAR_SOLVE) then
    error stop 'MUMPS factorization failure nonlinear rapora tasinmadi.'
  end if
  if (report%converged) then
    error stop 'MUMPS factorization failure sonrasi solver converged raporladi.'
  end if
  if (report%cutback_count /= max_cutbacks+1) then
    error stop 'MUMPS factorization failure cutback sayisi hatali.'
  end if
  if (report%state_commit_count /= 0) then
    error stop 'MUMPS factorization failure trial state commit edildi.'
  end if
  if (report%state_revert_count /= max_cutbacks+1) then
    error stop 'MUMPS factorization failure revert sayisi hatali.'
  end if
  if (report%increments_attempted /= max_cutbacks+1) then
    error stop 'MUMPS factorization failure retry sayisi hatali.'
  end if
  if (report%linear_solve_count /= 0) then
    error stop 'Factorization failure sonrasi solve asamasina gecildi.'
  end if
  if (abs(report%final_load_factor) > 1.0e-14_dp) then
    error stop 'MUMPS factorization failure committed load factoru bozdu.'
  end if
  if (maxval(abs(u)) > 1.0e-14_dp) then
    error stop 'MUMPS factorization failure committed displacement stateini bozdu.'
  end if
  if (maxval(abs(p)) > 1.0e-14_dp) then
    error stop 'MUMPS factorization failure committed pressure stateini bozdu.'
  end if

  write(*,'(A,I0)') 'MUMPS factorization failure cutback count = ',report%cutback_count
  write(*,'(A,I0)') 'MUMPS factorization failure revert count = ',report%state_revert_count
  write(*,'(A,I0)') 'MUMPS factorization failure commit count = ',report%state_commit_count
  write(*,'(A)') 'Q9/P1 MUMPS factorization failure -> rollback/cutback testi BASARILI.'
end program test_q9_herrmann_mumps_failure_cutback
