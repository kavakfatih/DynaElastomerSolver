program test_auto_sparse_solver_policy
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_UNSUPPORTED_LINEAR_BACKEND
  use des_csr_matrix, only : csr_matrix_t, &
      initialize_csr_from_element_dof_maps, csr_add_local_matrix
  use des_linear_solver, only : linear_solver_settings_t, linear_solver_report_t, &
      production_linear_solver_settings, &
      DES_LINEAR_BACKEND_AUTO, DES_LINEAR_BACKEND_STDLIB_CSR_GMRES, &
      DES_LINEAR_BACKEND_MUMPS_DIRECT, DES_LINEAR_FALLBACK_NONE, &
      DES_LINEAR_FALLBACK_MUMPS_UNAVAILABLE
  use des_mumps_backend, only : DES_MUMPS_AVAILABLE
  use des_sparse_solver_context, only : sparse_solver_context_t, &
      sparse_solver_diagnostics_t, create_sparse_solver_context, &
      analyze_sparse_pattern, reorder_sparse_pattern, factorize_sparse_matrix, &
      solve_sparse_with_context, get_sparse_solver_diagnostics, &
      release_sparse_solver_context, DES_MATRIX_CLASS_SYMMETRIC_INDEFINITE, &
      DES_PROBLEM_CLASS_MIXED_U_P, DES_INDEX_CLASS_INT32
  implicit none

  ! B7/B7b kabul kapısı aynı testi iki build profilinde çalıştırır:
  ! MUMPS-enabled -> gerçek sparse direct; MUMPS-disabled -> portable GMRES fallback.
  ! Explicit MUMPS isteği ise unavailable durumda sessiz fallback yapamaz.
  ! Bu dosya B7b final dört-platform acceptance matrisinin ortak policy gate'idir.
  ! Final acceptance SHA Git data API fast-forward push ile üretilir.
  type(csr_matrix_t) :: A
  type(linear_solver_settings_t) :: settings
  type(linear_solver_report_t) :: report
  type(sparse_solver_context_t) :: context
  type(sparse_solver_diagnostics_t) :: diagnostics
  integer :: maps(1,3), status, expected_backend
  real(dp) :: A_dense(3,3), b(3), x(3), expected(3)

  maps(1,:) = [1,2,3]
  call initialize_csr_from_element_dof_maps(A,3,3,maps,status)
  if (status /= DES_STATUS_OK) error stop 'AUTO policy CSR graph kuramadi.'

  A_dense = reshape([ &
      2.0_dp,0.0_dp,1.0_dp, &
      0.0_dp,3.0_dp,1.0_dp, &
      1.0_dp,1.0_dp,0.0_dp],shape(A_dense))
  expected = [1.0_dp,-2.0_dp,0.5_dp]
  b = matmul(A_dense,expected)
  call csr_add_local_matrix(A,maps(1,:),A_dense,status)
  if (status /= DES_STATUS_OK) error stop 'AUTO policy CSR values assemble edemedi.'

  settings = production_linear_solver_settings()
  if (settings%backend /= DES_LINEAR_BACKEND_AUTO .or. &
      settings%direct_iterative_refinement_steps < 1 .or. &
      settings%direct_error_analysis /= 2 .or. &
      .not. settings%direct_null_pivot_detection) then
    error stop 'Production solver profili direct-first kontrolleri tasimiyor.'
  end if
  settings%relative_tolerance = 1.0e-11_dp
  settings%absolute_tolerance = 1.0e-12_dp
  settings%max_iterations = 30
  settings%krylov_dimension = 3

  call create_sparse_solver_context( &
      context,settings,DES_MATRIX_CLASS_SYMMETRIC_INDEFINITE, &
      DES_PROBLEM_CLASS_MIXED_U_P,DES_INDEX_CLASS_INT32,status)
  if (status /= DES_STATUS_OK) error stop 'AUTO sparse context olusturulamadi.'

  call get_sparse_solver_diagnostics(context,diagnostics)
  if (diagnostics%requested_backend /= DES_LINEAR_BACKEND_AUTO) then
    error stop 'AUTO policy requested backend bilgisini korumadi.'
  end if

  if (DES_MUMPS_AVAILABLE) then
    expected_backend = DES_LINEAR_BACKEND_MUMPS_DIRECT
    if (diagnostics%fallback_used) then
      error stop 'MUMPS varken AUTO gereksiz fallback raporladi.'
    end if
    if (diagnostics%fallback_reason /= DES_LINEAR_FALLBACK_NONE) then
      error stop 'MUMPS varken AUTO fallback nedeni sifir olmaliydi.'
    end if
  else
    expected_backend = DES_LINEAR_BACKEND_STDLIB_CSR_GMRES
    if (.not. diagnostics%fallback_used) then
      error stop 'MUMPS yokken AUTO GMRES fallback raporlamadi.'
    end if
    if (diagnostics%fallback_reason /= DES_LINEAR_FALLBACK_MUMPS_UNAVAILABLE) then
      error stop 'AUTO GMRES fallback nedeni yanlis.'
    end if
  end if

  if (diagnostics%backend /= expected_backend) then
    error stop 'AUTO policy beklenen sparse backend secimini yapmadi.'
  end if

  call analyze_sparse_pattern(context,A,status)
  if (status /= DES_STATUS_OK) error stop 'AUTO policy pattern analysis basarisiz.'
  call reorder_sparse_pattern(context,status)
  if (status /= DES_STATUS_OK) error stop 'AUTO policy reorder basarisiz.'
  call factorize_sparse_matrix(context,A,status)
  if (status /= DES_STATUS_OK) error stop 'AUTO policy factorization basarisiz.'
  call solve_sparse_with_context(context,A,b,x,report)
  if (.not. report%converged .or. report%status /= DES_STATUS_OK) then
    error stop 'AUTO policy sparse solve yakinsamadi.'
  end if
  if (maxval(abs(x-expected)) > 1.0e-10_dp) then
    error stop 'AUTO policy sparse solve beklenen cozumle uyusmuyor.'
  end if
  if (report%requested_backend /= DES_LINEAR_BACKEND_AUTO) then
    error stop 'AUTO solve report requested backend bilgisini kaybetti.'
  end if
  if (report%backend /= expected_backend) then
    error stop 'AUTO solve report selected backend bilgisini kaybetti.'
  end if
  if (report%fallback_used .neqv. diagnostics%fallback_used) then
    error stop 'AUTO solve report fallback flag diagnostics ile uyusmuyor.'
  end if
  if (report%fallback_reason /= diagnostics%fallback_reason) then
    error stop 'AUTO solve report fallback nedeni diagnostics ile uyusmuyor.'
  end if

  if (DES_MUMPS_AVAILABLE) then
    if (.not. report%direct_factorization_performed) then
      error stop 'AUTO MUMPS direct factorization flag raporlanmadi.'
    end if
    if (report%direct_null_pivot_count /= 0) then
      error stop 'AUTO MUMPS nonsingular testte null pivot raporladi.'
    end if
  else
    if (report%direct_factorization_performed) then
      error stop 'AUTO GMRES direct factorization yapmis gibi raporlandi.'
    end if
  end if

  call release_sparse_solver_context(context)

  if (.not. DES_MUMPS_AVAILABLE) then
    settings = production_linear_solver_settings()
    settings%backend = DES_LINEAR_BACKEND_MUMPS_DIRECT
    call create_sparse_solver_context( &
        context,settings,DES_MATRIX_CLASS_SYMMETRIC_INDEFINITE, &
        DES_PROBLEM_CLASS_MIXED_U_P,DES_INDEX_CLASS_INT32,status)
    if (status /= DES_ERROR_UNSUPPORTED_LINEAR_BACKEND) then
      error stop 'Explicit MUMPS unavailable durumda fail-fast yapmadi.'
    end if
    if (context%fallback_used) then
      error stop 'Explicit MUMPS istegi sessiz GMRES fallback yapti.'
    end if
  end if

  write(*,'(A,I0)') 'AUTO requested backend = ',DES_LINEAR_BACKEND_AUTO
  write(*,'(A,I0)') 'AUTO selected backend = ',expected_backend
  write(*,'(A,L1)') 'AUTO fallback used = ',diagnostics%fallback_used
  write(*,'(A)') 'B7b AUTO/production sparse solver policy testi BASARILI.'
end program test_auto_sparse_solver_policy
