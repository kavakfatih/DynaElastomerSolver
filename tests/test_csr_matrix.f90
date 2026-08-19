program test_csr_matrix
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_csr_matrix, only : csr_matrix_t, initialize_csr_from_element_dof_maps, &
                             csr_add_local_matrix, csr_to_dense, csr_matvec, &
                             csr_apply_zero_dirichlet
  implicit none

  type(csr_matrix_t) :: A
  integer :: maps(2,3), status, row, k
  integer :: fixed_dofs(2)
  real(dp) :: K1(3,3), K2(3,3), dense(5,5), expected(5,5)
  real(dp) :: constrained_expected(5,5)
  real(dp) :: x_probe(5), y_sparse(5), y_expected(5), rhs(5), rhs_expected(5)

  maps(1,:) = [1,2,3]
  maps(2,:) = [3,4,5]

  call initialize_csr_from_element_dof_maps(A,5,5,maps,status)
  if (status /= DES_STATUS_OK) error stop 'CSR graph initialization basarisiz.'
  if (A%nnz() /= 17) error stop 'CSR graph beklenen unique nnz sayisini vermedi.'

  if (A%row_ptr(1) /= 1 .or. A%row_ptr(6) /= 18) then
    error stop 'CSR row_ptr 1-based sozlesmesi bozuldu.'
  end if

  do row = 1,A%nrows
    do k = A%row_ptr(row)+1,A%row_ptr(row+1)-1
      if (A%col_ind(k) <= A%col_ind(k-1)) then
        error stop 'CSR kolon indeksleri satir icinde strictly sorted degil.'
      end if
    end do
  end do

  K1 = reshape([ &
      1.0_dp,2.0_dp,3.0_dp, &
      4.0_dp,5.0_dp,6.0_dp, &
      7.0_dp,8.0_dp,9.0_dp],shape(K1))
  K2 = 0.5_dp*K1

  call csr_add_local_matrix(A,maps(1,:),K1,status)
  if (status /= DES_STATUS_OK) error stop 'CSR ilk local scatter basarisiz.'
  call csr_add_local_matrix(A,maps(2,:),K2,status)
  if (status /= DES_STATUS_OK) error stop 'CSR ikinci local scatter basarisiz.'

  expected = 0.0_dp
  call add_dense_block(expected,maps(1,:),K1)
  call add_dense_block(expected,maps(2,:),K2)

  call csr_to_dense(A,dense,status)
  if (status /= DES_STATUS_OK) error stop 'CSR dense conversion basarisiz.'
  if (maxval(abs(dense-expected)) > 1.0e-14_dp) then
    error stop 'CSR local scatter dense referans ile uyusmuyor.'
  end if

  if (abs(A%get_value(3,3)-expected(3,3)) > 1.0e-14_dp) then
    error stop 'CSR get_value ortak element contribution toplamadi.'
  end if

  x_probe = [1.0_dp,-1.0_dp,0.5_dp,2.0_dp,-0.25_dp]
  y_expected = matmul(expected,x_probe)
  call csr_matvec(A,x_probe,y_sparse,status)
  if (status /= DES_STATUS_OK) error stop 'CSR matvec status basarisiz.'
  if (maxval(abs(y_sparse-y_expected)) > 1.0e-14_dp) then
    error stop 'CSR matvec dense referans ile uyusmuyor.'
  end if

  fixed_dofs = [2,4]
  rhs = [1.0_dp,2.0_dp,3.0_dp,4.0_dp,5.0_dp]
  rhs_expected = rhs
  rhs_expected(fixed_dofs) = 0.0_dp

  constrained_expected = expected
  constrained_expected(fixed_dofs,:) = 0.0_dp
  constrained_expected(:,fixed_dofs) = 0.0_dp
  constrained_expected(2,2) = 1.0_dp
  constrained_expected(4,4) = 1.0_dp

  call csr_apply_zero_dirichlet(A,rhs,fixed_dofs,status)
  if (status /= DES_STATUS_OK) error stop 'CSR zero-Dirichlet uygulamasi basarisiz.'
  call csr_to_dense(A,dense,status)
  if (status /= DES_STATUS_OK) error stop 'Dirichlet sonrasi CSR dense conversion basarisiz.'
  if (maxval(abs(dense-constrained_expected)) > 1.0e-14_dp) then
    error stop 'CSR zero-Dirichlet matris sozlesmesi bozuldu.'
  end if
  if (maxval(abs(rhs-rhs_expected)) > 0.0_dp) then
    error stop 'CSR zero-Dirichlet RHS sozlesmesi bozuldu.'
  end if

  call A%zero_values()
  if (maxval(abs(A%values)) > 0.0_dp) error stop 'CSR zero_values basarisiz.'

  write(*,'(A,I0)') 'CSR structural nnz = ',A%nnz()
  write(*,'(A)') 'CSR sparse matrix foundation testi BASARILI.'

contains

  subroutine add_dense_block(global_matrix,dof_map,local_matrix)
    real(dp), intent(inout) :: global_matrix(:,:)
    integer, intent(in) :: dof_map(:)
    real(dp), intent(in) :: local_matrix(:,:)
    integer :: i,j

    do i = 1,size(dof_map)
      do j = 1,size(dof_map)
        global_matrix(dof_map(i),dof_map(j)) = &
            global_matrix(dof_map(i),dof_map(j))+local_matrix(i,j)
      end do
    end do
  end subroutine add_dense_block

end program test_csr_matrix
