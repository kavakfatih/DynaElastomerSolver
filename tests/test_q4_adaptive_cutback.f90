program test_q4_adaptive_cutback
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_NONPOSITIVE_J
  use des_material_types, only : neo_hookean_parameters_t
  use des_q4_plane_strain_newton_solver, only : newton_report_t, &
       solve_q4_plane_strain_adaptive_displacement_control, &
       solve_q4_plane_strain_displacement_control
  implicit none

  real(dp) :: X(4,2), u(4,2), u_ref(4,2), residual(8), residual_ref(8)
  integer :: connectivity(1,4), prescribed_dofs(6)
  real(dp) :: prescribed_values(6)
  type(neo_hookean_parameters_t) :: parameters
  type(newton_report_t) :: report, report_ref

  X(1,:) = [0.0_dp, 0.0_dp]
  X(2,:) = [1.0_dp, 0.0_dp]
  X(3,:) = [1.0_dp, 1.0_dp]
  X(4,:) = [0.0_dp, 1.0_dp]
  connectivity(1,:) = [1,2,3,4]

  ! Büyük tek adım Newton'u non-positive J durumuna sürüklüyor.
  ! Adaptive yol son yakınsayan state'e dönüp increment'i yarıya indirerek devam etmeli.
  prescribed_dofs = [1,2,4,7,3,5]
  prescribed_values = [0.0_dp,0.0_dp,0.0_dp,0.0_dp,1.0_dp,1.0_dp]

  parameters%mu = 2.3_dp
  parameters%lambda = 19.0_dp
  u = 0.0_dp
  u_ref = 0.0_dp

  call solve_q4_plane_strain_adaptive_displacement_control( &
       X, connectivity, parameters, prescribed_dofs, prescribed_values, &
       1.0_dp, 0.125_dp, 0.5_dp, 4, 10, 1.0e-10_dp, u, residual, report)

  if (.not. report%converged .or. report%status /= DES_STATUS_OK) then
    error stop 'Adaptive solver yakınsamadı.'
  end if
  if (report%cutback_count < 1) error stop 'Beklenen cutback oluşmadı.'
  if (report%last_failure_status /= DES_ERROR_NONPOSITIVE_J) then
    error stop 'İlk başarısızlık nedeni non-positive J değil.'
  end if
  if (abs(report%final_load_factor-1.0_dp) > 1.0e-14_dp) then
    error stop 'Final load factor 1.0 değil.'
  end if

  ! Aynı final state, güvenli iki sabit increment'li referans çözümle karşılaştırılır.
  call solve_q4_plane_strain_displacement_control( &
       X, connectivity, parameters, prescribed_dofs, prescribed_values, &
       2, 10, 1.0e-10_dp, u_ref, residual_ref, report_ref)

  if (.not. report_ref%converged) error stop 'Fixed-step referans çözüm yakınsamadı.'
  if (maxval(abs(u-u_ref)) > 1.0e-10_dp) then
    error stop 'Adaptive ve referans displacement sonuçları farklı.'
  end if
  if (maxval(abs(residual-residual_ref)) > 1.0e-10_dp) then
    error stop 'Adaptive ve referans reaksiyon sonuçları farklı.'
  end if

  write(*,'(A,I0)') 'Cutback sayısı = ', report%cutback_count
  write(*,'(A,I0)') 'Kabul edilen increment = ', report%increments_converged
  write(*,'(A,ES12.4)') 'Final residual = ', report%final_residual_norm
  write(*,'(A)') 'Adaptive rollback/cutback testi BASARILI.'
end program test_q4_adaptive_cutback
