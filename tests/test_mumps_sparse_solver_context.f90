program test_mumps_sparse_solver_context
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_csr_matrix, only : csr_matrix_t, &
                             initialize_csr_from_element_dof_maps, &
                             csr_add_local_matrix
  use des_linear_solver, only : linear_solver_settings_t, &
                                linear_solver_report_t, &
                                DES_LINEAR_BACKEND_MUMPS_DIRECT
  use des_sparse_solver_context, only : sparse_solver_context_t, &
      sparse_solver_diagnostics_t, create_sparse_solver_context, &
      analyze_sparse_pattern, reorder_sparse_pattern, &
      factorize_sparse_matrix, solve_sparse_with_context, &
      reuse_sparse_pattern, get_sparse_solver_diagnostics, &
      release_sparse_solver_context, &
      DES_MATRIX_CLASS_SYMMETRIC_INDEFINITE, &
      DES_PROBLEM_CLASS_MIXED_U_P, DES_INDEX_CLASS_INT32
  implicit none

  type(csr_matrix_t) :: A
  type(linear_solver_settings_t) :: settings
  type(linear_solver_report_t) :: report
  type(sparse_solver_context_t) :: context
  type(sparse_solver_diagnostics_t) :: diagnostics
  integer :: maps(1,3), status
  real(dp) :: A_dense(3,3), b(3), x(3), expected(3)
  logical :: reused

  maps(1,:) = [1,2,3]
  call initialize_csr_from_element_dof_maps(A,3,3,maps,status)
  if (status /= DES_STATUS_OK) then
    error stop 'MUMPS context CSR graph kuramadi.'
  end if

  settings = linear_solver_settings_t()
  settings%backend = DES_LINEAR_BACKEND_MUMPS_DIRECT
  settings%relative_tolerance = 1.0e-11_dp
  settings%absolute_tolerance = 1.0e-12_dp

  call create_sparse_solver_context( &
      context,settings,DES_MATRIX_CLASS_SYMMETRIC_INDEFINITE, &
      DES_PROBLEM_CLASS_MIXED_U_P,DES_INDEX_CLASS_INT32,status)
  if (status /= DES_STATUS_OK) then
    error stop 'MUMPS sparse-direct context olusturulamadi.'
  end if

  ! Pressure-benzeri üçüncü diagonal sıfır olan küçük saddle-point sistemi.
  A_dense = reshape([ &
      2.0_dp,0.0_dp,1.0_dp, &
      0.0_dp,3.0_dp,1.0_dp, &
      1.0_dp,1.0_dp,0.0_dp],shape(A_dense))
  expected = [1.0_dp,-2.0_dp,0.5_dp]
  b = matmul(A_dense,expected)

  call A%zero_values()
  call csr_add_local_matrix(A,maps(1,:),A_dense,status)
  if (status /= DES_STATUS_OK) error stop 'MUMPS ilk values assembly basarisiz.'

  call analyze_sparse_pattern(context,A,status)
  if (status /= DES_STATUS_OK) error stop 'MUMPS CSR pattern kaydi basarisiz.'
  call reorder_sparse_pattern(context,status)
  if (status /= DES_STATUS_OK) error stop 'MUMPS ordering lifecycle basarisiz.'
  call factorize_sparse_matrix(context,A,status)
  if (status /= DES_STATUS_OK) error stop 'MUMPS ilk numeric factorization basarisiz.'

  call solve_sparse_with_context(context,A,b,x,report)
  if (.not. report%converged .or. report%status /= DES_STATUS_OK) then
    error stop 'MUMPS ilk saddle-point solve basarisiz.'
  end if
  if (maxval(abs(x-expected)) > 1.0e-10_dp) then
    error stop 'MUMPS ilk cozum beklenen degerlerle uyusmuyor.'
  end if
  if (.not. report%direct_factorization_performed) then
    error stop 'MUMPS direct factorization yapildigini raporlamadi.'
  end if
  if (report%pattern_analysis_count /= 1 .or. report%reorder_count /= 1) then
    error stop 'MUMPS symbolic lifecycle bir kez calismadi.'
  end if
  if (report%factorization_count /= 1 .or. report%context_solve_count /= 1) then
    error stop 'MUMPS ilk factorization/solve sayaci yanlis.'
  end if
  if (report%backend_info_primary < 0) then
    error stop 'MUMPS basarili cozumde negatif INFOG(1) raporladi.'
  end if

  ! Aynı graph üzerinde yeni Newton values seti: symbolic analysis/order tekrar
  ! edilmemeli; yalnız numeric factorization yenilenmelidir.
  call reuse_sparse_pattern(context,A,reused,status)
  if (status /= DES_STATUS_OK .or. .not. reused) then
    error stop 'MUMPS ayni CSR pattern reuse edemedi.'
  end if

  A_dense = reshape([ &
      4.0_dp,0.0_dp,1.0_dp, &
      0.0_dp,5.0_dp,1.0_dp, &
      1.0_dp,1.0_dp,0.0_dp],shape(A_dense))
  expected = [-0.25_dp,0.75_dp,1.5_dp]
  b = matmul(A_dense,expected)

  call A%zero_values()
  call csr_add_local_matrix(A,maps(1,:),A_dense,status)
  if (status /= DES_STATUS_OK) error stop 'MUMPS ikinci values assembly basarisiz.'

  call reorder_sparse_pattern(context,status)
  if (status /= DES_STATUS_OK) error stop 'MUMPS reuse ordering lifecycle basarisiz.'
  call factorize_sparse_matrix(context,A,status)
  if (status /= DES_STATUS_OK) error stop 'MUMPS ikinci numeric factorization basarisiz.'
  call solve_sparse_with_context(context,A,b,x,report)
  if (.not. report%converged .or. report%status /= DES_STATUS_OK) then
    error stop 'MUMPS ikinci saddle-point solve basarisiz.'
  end if
  if (maxval(abs(x-expected)) > 1.0e-10_dp) then
    error stop 'MUMPS ikinci cozum beklenen degerlerle uyusmuyor.'
  end if

  call get_sparse_solver_diagnostics(context,diagnostics)
  if (diagnostics%pattern_analysis_count /= 1) then
    error stop 'MUMPS pattern analysis reuse boyunca tekrarlandi.'
  end if
  if (diagnostics%reorder_count /= 1) then
    error stop 'MUMPS ordering reuse boyunca tekrarlandi.'
  end if
  if (diagnostics%factorization_count /= 2) then
    error stop 'MUMPS numeric factorization iki values setini gormedi.'
  end if
  if (diagnostics%solve_count /= 2) then
    error stop 'MUMPS solve sayaci iki RHS cozumunu gormedi.'
  end if
  if (diagnostics%symbolic_reuse_count /= 1) then
    error stop 'MUMPS symbolic reuse sayaci yanlis.'
  end if
  if (.not. diagnostics%direct_factorization_performed) then
    error stop 'MUMPS diagnostic direct factorization flag yanlis.'
  end if

  write(*,'(A,I0)') 'MUMPS pattern analysis count = ', &
      diagnostics%pattern_analysis_count
  write(*,'(A,I0)') 'MUMPS reorder count = ',diagnostics%reorder_count
  write(*,'(A,I0)') 'MUMPS factorization count = ',diagnostics%factorization_count
  write(*,'(A,I0)') 'MUMPS solve count = ',diagnostics%solve_count
  write(*,'(A,ES12.4)') 'MUMPS final true residual inf = ', &
      report%residual_inf_norm
  write(*,'(A,I0,A,I0)') 'MUMPS INFOG(1/2) = ', &
      report%backend_info_primary,' / ',report%backend_info_secondary

  call release_sparse_solver_context(context)
  write(*,'(A)') 'MUMPS stateful sparse-direct context testi BASARILI.'
end program test_mumps_sparse_solver_context
