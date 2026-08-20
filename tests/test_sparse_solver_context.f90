program test_sparse_solver_context
  use des_kinds, only : dp, i64
  use des_status, only : DES_STATUS_OK, &
                         DES_ERROR_UNSUPPORTED_LINEAR_BACKEND
  use des_csr_matrix, only : csr_matrix_t, &
                             initialize_csr_from_element_dof_maps, &
                             csr_add_local_matrix
  use des_linear_solver, only : linear_solver_settings_t, &
                                linear_solver_report_t, &
                                DES_LINEAR_BACKEND_STDLIB_CSR_GMRES
  use des_sparse_solver_context, only : sparse_solver_context_t, &
      sparse_solver_diagnostics_t, create_sparse_solver_context, &
      analyze_sparse_pattern, reorder_sparse_pattern, &
      factorize_sparse_matrix, solve_sparse_with_context, &
      refine_sparse_solution, reuse_sparse_pattern, &
      get_sparse_solver_diagnostics, release_sparse_solver_context, &
      DES_MATRIX_CLASS_SYMMETRIC_INDEFINITE, &
      DES_PROBLEM_CLASS_MIXED_U_P, DES_INDEX_CLASS_INT32, &
      DES_INDEX_CLASS_INT64
  implicit none

  type(csr_matrix_t) :: A
  type(linear_solver_settings_t) :: settings
  type(linear_solver_report_t) :: report
  type(sparse_solver_context_t) :: context, int64_context
  type(sparse_solver_diagnostics_t) :: diagnostics
  integer :: maps(1,3), status
  real(dp) :: A_dense(3,3), b(3), x(3), expected(3)
  logical :: reused

  ! Küçük symmetric-indefinite saddle-point sistemi B4 lifecycle testinde de
  ! kullanılır. Pressure-benzeri üçüncü diagonal sıfırdır.
  A_dense = reshape([ &
      2.0_dp,0.0_dp,1.0_dp, &
      0.0_dp,3.0_dp,1.0_dp, &
      1.0_dp,1.0_dp,0.0_dp],shape(A_dense))
  expected = [1.0_dp,-2.0_dp,0.5_dp]
  b = matmul(A_dense,expected)

  maps(1,:) = [1,2,3]
  call initialize_csr_from_element_dof_maps(A,3,3,maps,status)
  if (status /= DES_STATUS_OK) then
    error stop 'B4 context CSR graph kuramadi.'
  end if
  call csr_add_local_matrix(A,maps(1,:),A_dense,status)
  if (status /= DES_STATUS_OK) then
    error stop 'B4 context CSR values assemble edemedi.'
  end if

  settings = linear_solver_settings_t()
  settings%backend = DES_LINEAR_BACKEND_STDLIB_CSR_GMRES
  settings%relative_tolerance = 1.0e-12_dp
  settings%absolute_tolerance = 1.0e-13_dp
  settings%max_iterations = 20
  settings%krylov_dimension = 3

  call create_sparse_solver_context( &
      context,settings,DES_MATRIX_CLASS_SYMMETRIC_INDEFINITE, &
      DES_PROBLEM_CLASS_MIXED_U_P,DES_INDEX_CLASS_INT32,status)
  if (status /= DES_STATUS_OK) then
    error stop 'B4 sparse context olusturulamadi.'
  end if

  call analyze_sparse_pattern(context,A,status)
  if (status /= DES_STATUS_OK) error stop 'Pattern analysis basarisiz.'
  call reorder_sparse_pattern(context,status)
  if (status /= DES_STATUS_OK) error stop 'Reorder lifecycle basarisiz.'
  call factorize_sparse_matrix(context,A,status)
  if (status /= DES_STATUS_OK) error stop 'Numeric lifecycle basarisiz.'

  call solve_sparse_with_context(context,A,b,x,report)
  if (.not. report%converged) error stop 'Context solve yakinsamadi.'
  if (report%status /= DES_STATUS_OK) error stop 'Context solve status basarisiz.'
  if (maxval(abs(x-expected)) > 1.0e-10_dp) then
    error stop 'Context solve beklenen cozumle uyusmuyor.'
  end if
  if (report%pattern_analysis_count /= 1) then
    error stop 'Pattern bir kez analiz edilmeliydi.'
  end if
  if (report%reorder_count /= 1) then
    error stop 'Ordering bir kez hazirlanmaliydi.'
  end if
  if (report%factorization_count /= 1) then
    error stop 'Ilk numeric lifecycle sayaci yanlis.'
  end if
  if (report%direct_factorization_performed) then
    error stop 'GMRES direct factorization yapmis gibi raporlanamaz.'
  end if

  ! Aynı CSR graph yeni Newton values setinde symbolic analysis'i tekrar
  ! tetiklememeli. Explicit reuse kapısı bunun sayaç davranışını doğrular.
  call reuse_sparse_pattern(context,A,reused,status)
  if (status /= DES_STATUS_OK .or. .not. reused) then
    error stop 'Ayni sparse pattern reuse edilemedi.'
  end if
  call reorder_sparse_pattern(context,status)
  if (status /= DES_STATUS_OK) error stop 'Reuse sonrasi reorder basarisiz.'
  call factorize_sparse_matrix(context,A,status)
  if (status /= DES_STATUS_OK) error stop 'Reuse sonrasi numeric stage basarisiz.'

  ! Çözümü bilinçli bozup generic iterative-refinement katmanının gerçek
  ! residual üzerinden düzeltme yaptığını doğrula.
  x = expected + [1.0e-5_dp,-2.0e-5_dp,3.0e-5_dp]
  call refine_sparse_solution(context,A,b,x,2,1.0e-11_dp,report)
  if (.not. report%converged) error stop 'Iterative refinement yakinsamadi.'
  if (maxval(abs(x-expected)) > 1.0e-10_dp) then
    error stop 'Iterative refinement beklenen cozumu geri kazanamadi.'
  end if

  call get_sparse_solver_diagnostics(context,diagnostics)
  if (diagnostics%equation_count /= 3_i64 .or. diagnostics%nnz /= 9_i64) then
    error stop 'Sparse context 64-bit cardinality metadata yanlis.'
  end if
  if (diagnostics%pattern_analysis_count /= 1) then
    error stop 'Symbolic analysis Newton reuse boyunca tekrarlandi.'
  end if
  if (diagnostics%reorder_count /= 1) then
    error stop 'Ordering Newton reuse boyunca tekrarlandi.'
  end if
  if (diagnostics%factorization_count /= 2) then
    error stop 'Numeric lifecycle sayaci beklenen iki values setini gormedi.'
  end if
  if (diagnostics%symbolic_reuse_count /= 1) then
    error stop 'Symbolic reuse sayaci yanlis.'
  end if
  if (diagnostics%solve_count /= 2) then
    error stop 'Solve sayaci ilk cozum + refinement duzeltmesini gostermeli.'
  end if
  if (diagnostics%iterative_refinement_count /= 1) then
    error stop 'Iterative refinement sayaci yanlis.'
  end if
  if (diagnostics%direct_factorization_performed) then
    error stop 'Bootstrap GMRES direct factorization iddia etmemeli.'
  end if
  if (diagnostics%supports_int64) then
    error stop 'Mevcut stdlib CSR GMRES int64 destegi iddia etmemeli.'
  end if

  call release_sparse_solver_context(context)
  call get_sparse_solver_diagnostics(context,diagnostics)
  if (diagnostics%active .or. .not. diagnostics%released) then
    error stop 'Context release lifecycle yanlis.'
  end if

  ! B4 metadata int64 sinifini tanir; fakat stdlib köprüsü halen int32 olduğu
  ! için desteklenmeyen kapasite fail-fast ve açık status ile reddedilir.
  call create_sparse_solver_context( &
      int64_context,settings,DES_MATRIX_CLASS_SYMMETRIC_INDEFINITE, &
      DES_PROBLEM_CLASS_MIXED_U_P,DES_INDEX_CLASS_INT64,status)
  if (status /= DES_ERROR_UNSUPPORTED_LINEAR_BACKEND) then
    error stop 'GMRES int64 kapasite sinirini dogru raporlamadi.'
  end if

  write(*,'(A,I0)') 'B4 context equation count (int64) = ', &
      diagnostics%equation_count
  write(*,'(A,I0)') 'B4 context structural nnz (int64) = ',diagnostics%nnz
  write(*,'(A,I0)') 'B4 pattern analysis count = ', &
      diagnostics%pattern_analysis_count
  write(*,'(A,I0)') 'B4 symbolic reuse count = ', &
      diagnostics%symbolic_reuse_count
  write(*,'(A,I0)') 'B4 solve count = ',diagnostics%solve_count
  write(*,'(A)') 'Stateful sparse solver context lifecycle testi BASARILI.'
end program test_sparse_solver_context
