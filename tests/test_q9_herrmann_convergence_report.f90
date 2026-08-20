program test_q9_herrmann_convergence_report
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_internal_mesh, only : internal_mesh_t, initialize_q9_internal_mesh
  use des_linear_solver, only : linear_solver_settings_t, DES_LINEAR_BACKEND_STDLIB_DENSE
  use des_q9_internal_mesh_herrmann_assembly, only : assemble_q9_internal_mesh_herrmann
  use des_q9_herrmann_solver_report, only : herrmann_solver_report_t, &
      solve_q9_internal_mesh_herrmann_adaptive_reported
  implicit none

  real(dp) :: X(9,2)
  integer :: connectivity(1,9), status
  type(internal_mesh_t) :: mesh

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
  if (status /= DES_STATUS_OK) error stop 'Q9 convergence-report mesh olusturulamadi.'

  call run_case(mesh,X,5.0e-2_dp,.false.)
  call run_case(mesh,X,0.0_dp,.true.)

  write(*,'(A)') 'Q9/P1 Herrmann convergence-report testi BASARILI.'

contains

  subroutine run_case(mesh,X,pressure_compliance,fully_incompressible)
    type(internal_mesh_t), intent(in) :: mesh
    real(dp), intent(in) :: X(9,2), pressure_compliance
    logical, intent(in) :: fully_incompressible

    integer, parameter :: fixed_dofs(3) = [1,2,7]
    real(dp), parameter :: shear_modulus = 2.0_dp
    real(dp), parameter :: alpha = 2.0e-2_dp
    real(dp) :: beta,J_target,min_j
    real(dp) :: u_target(9,2),u(9,2),p_target(1,3),p(1,3)
    real(dp) :: residual_target(21),residual(21),K_target(21,21),external_force(18)
    integer :: a,local_status,h,line_search_records
    type(herrmann_solver_report_t) :: report
    type(linear_solver_settings_t) :: dense_settings

    if (fully_incompressible) then
      beta = 1.0_dp/(1.0_dp+alpha)-1.0_dp
    else
      beta = -1.0e-2_dp
    end if

    do a = 1,9
      u_target(a,1) = alpha*X(a,1)
      u_target(a,2) = beta*X(a,2)
    end do
    J_target = (1.0_dp+alpha)*(1.0_dp+beta)

    p_target = 0.0_dp
    if (fully_incompressible) then
      if (abs(J_target-1.0_dp) > 5.0e-15_dp) then
        error stop 'Fully incompressible convergence target J=1 degil.'
      end if
      p_target(1,1) = 0.15_dp
    else
      p_target(1,1) = -(J_target-1.0_dp)/pressure_compliance
    end if

    call assemble_q9_internal_mesh_herrmann( &
        mesh,u_target,p_target,shear_modulus,pressure_compliance, &
        residual_target,K_target,local_status,min_j)
    if (local_status /= DES_STATUS_OK) error stop 'Convergence target assembly basarisiz.'
    if (maxval(abs(residual_target(19:21))) > 2.0e-12_dp) then
      error stop 'Convergence target pressure residual sifir degil.'
    end if
    external_force = residual_target(1:18)
    dense_settings%backend = DES_LINEAR_BACKEND_STDLIB_DENSE

    u = 0.0_dp
    p = 0.0_dp
    call solve_q9_internal_mesh_herrmann_adaptive_reported( &
        mesh,shear_modulus,pressure_compliance,fixed_dofs,external_force, &
        0.2_dp,0.0125_dp,0.5_dp,6,40,1.0e-10_dp, &
        u,p,residual,report,linear_settings=dense_settings)

    if (.not. report%nonlinear%converged .or. &
        report%nonlinear%status /= DES_STATUS_OK) then
      error stop 'Reported Q9/P1 Herrmann solver yakinsamadi.'
    end if
    if (report%nonfinite_event_count /= 0 .or. report%last_nonfinite_stage /= 0) then
      error stop 'Basarili Q9 solve yanlis non-finite diagnostics uretmis.'
    end if

    ! B8.1: production adaptive yolunun line-search policy'sinden gerçekten geçtiğini
    ! history üzerinden doğrula. Bu manufactured durumda alpha=1 kabul edilebilir;
    ! önemli sözleşme mixed correction için pozitif ve en fazla 1 olan ölçeğin
    ! kaydedilmesi ve en az bir line-search residual denemesinin yapılmasıdır.
    line_search_records = 0
    do h = 1,report%nonlinear%history%count
      if (report%nonlinear%history%records(h)%cutback_index < 0) then
        error stop 'Q9 convergence history negatif cutback index uretti.'
      end if
      if (report%nonlinear%history%records(h)%nonfinite_stage /= 0) then
        error stop 'Basarili Q9 convergence history non-finite stage tasiyor.'
      end if
      if (report%nonlinear%history%records(h)%line_search_trials > 0) then
        line_search_records = line_search_records + 1
        if (report%nonlinear%history%records(h)%correction_scale <= 0.0_dp .or. &
            report%nonlinear%history%records(h)%correction_scale > 1.0_dp) then
          error stop 'Q9 line-search correction scale history degeri gecersiz.'
        end if
      end if
    end do
    if (line_search_records < 1) then
      error stop 'Q9 adaptive production yolu line-search residual denemesi kaydetmedi.'
    end if

    if (.not. report%metrics_valid .or. report%metrics_status /= DES_STATUS_OK) then
      error stop 'Herrmann convergence metrikleri valid degil.'
    end if
    if (report%displacement_residual_inf_norm > 1.0e-10_dp) then
      error stop 'Displacement residual metriği tolerans disi.'
    end if
    if (report%pressure_residual_inf_norm > 1.0e-10_dp) then
      error stop 'Pressure residual metriği tolerans disi.'
    end if
    if (report%volumetric_constraint_inf_norm > 2.0e-8_dp) then
      error stop 'Pointwise volumetric constraint metriği tolerans disi.'
    end if
    if (maxval(abs(u-u_target)) > 4.0e-8_dp) then
      error stop 'Reported solver displacement targeti yakalayamadi.'
    end if
    if (maxval(abs(p-p_target)) > 4.0e-8_dp) then
      error stop 'Reported solver pressure targeti yakalayamadi.'
    end if

    if (fully_incompressible) then
      write(*,'(A,ES12.4)') 'Fully incompressible volumetric norm = ', &
          report%volumetric_constraint_inf_norm
    else
      write(*,'(A,ES12.4)') 'Nearly incompressible volumetric norm = ', &
          report%volumetric_constraint_inf_norm
    end if
    write(*,'(A,ES12.4)') 'Displacement residual norm = ', &
        report%displacement_residual_inf_norm
    write(*,'(A,ES12.4)') 'Pressure residual norm = ',report%pressure_residual_inf_norm
  end subroutine run_case

end program test_q9_herrmann_convergence_report
