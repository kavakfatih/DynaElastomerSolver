program test_sparse_linear_solver
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_UNSUPPORTED_LINEAR_BACKEND
  use des_csr_matrix, only : csr_matrix_t, initialize_csr_from_element_dof_maps, &
                             csr_add_local_matrix
  use des_linear_solver, only : linear_solver_settings_t, linear_solver_report_t, &
                                solve_sparse_linear_system, &
                                DES_LINEAR_BACKEND_STDLIB_DENSE, &
                                DES_LINEAR_BACKEND_STDLIB_CSR_GMRES
  implicit none

  type(csr_matrix_t) :: A
  type(linear_solver_settings_t) :: settings
  type(linear_solver_report_t) :: report
  integer :: maps(1,3), status
  real(dp) :: A_dense(3,3), b(3), x(3), expected(3), sparse_residual

  ! Simetrik fakat indefinite ve sifir pressure-benzeri diagonale sahip kucuk
  ! saddle-point sistemi. Determinant -5'tir; dolayisiyla sistem tekil degildir.
  ! CG/SPD varsayimi bu sinif icin kullanilmaz; bootstrap backend GMRES'tir.
  A_dense = reshape([ &
      2.0_dp,0.0_dp,1.0_dp, &
      0.0_dp,3.0_dp,1.0_dp, &
      1.0_dp,1.0_dp,0.0_dp],shape(A_dense))
  expected = [1.0_dp,-2.0_dp,0.5_dp]
  b = matmul(A_dense,expected)

  maps(1,:) = [1,2,3]
  call initialize_csr_from_element_dof_maps(A,3,3,maps,status)
  if (status /= DES_STATUS_OK) error stop 'Sparse solver test CSR graph kuramadi.'
  call csr_add_local_matrix(A,maps(1,:),A_dense,status)
  if (status /= DES_STATUS_OK) error stop 'Sparse solver test CSR degerlerini assemble edemedi.'

  settings = linear_solver_settings_t()
  settings%backend = DES_LINEAR_BACKEND_STDLIB_CSR_GMRES
  settings%relative_tolerance = 1.0e-12_dp
  settings%absolute_tolerance = 1.0e-13_dp
  settings%max_iterations = 20
  settings%krylov_dimension = 3
  settings%compact_krylov = .true.

  call solve_sparse_linear_system(A,b,x,settings,report)

  if (.not. report%converged) error stop 'CSR GMRES indefinite sistemde yakinsamadi.'
  if (report%status /= DES_STATUS_OK) error stop 'CSR GMRES status basarisiz.'
  if (report%backend /= DES_LINEAR_BACKEND_STDLIB_CSR_GMRES) then
    error stop 'CSR GMRES backend raporu yanlis.'
  end if
  if (report%equation_count /= 3) error stop 'CSR GMRES denklem sayisi raporu yanlis.'
  if (maxval(abs(x-expected)) > 1.0e-10_dp) then
    error stop 'CSR GMRES cozum beklenen indefinite cozumle uyusmuyor.'
  end if
  if (report%residual_inf_norm > 1.0e-11_dp) then
    error stop 'CSR GMRES true residual toleransi asildi.'
  end if
  sparse_residual = report%residual_inf_norm

  ! Dense backend sparse API uzerinden sessizce kullanilmaz. Storage/backend
  ! uyumsuzlugu acik status ile raporlanir.
  settings%backend = DES_LINEAR_BACKEND_STDLIB_DENSE
  call solve_sparse_linear_system(A,b,x,settings,report)
  if (report%converged) error stop 'Sparse API dense backend secimini kabul etmemeli.'
  if (report%status /= DES_ERROR_UNSUPPORTED_LINEAR_BACKEND) then
    error stop 'Sparse API backend uyumsuzlugunu dogru status ile raporlamadi.'
  end if

  write(*,'(A,ES12.4)') 'CSR GMRES indefinite true residual = ',sparse_residual
  write(*,'(A)') 'Sparse linear solver bootstrap testi BASARILI.'
end program test_sparse_linear_solver
