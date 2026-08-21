program test_csr_i64_interface
  use des_kinds, only : dp, i64
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONSTRAINT
  use des_csr_matrix, only : csr_matrix_t, initialize_csr_from_element_dof_maps_i64, &
      csr_add_local_matrix_i64, csr_apply_zero_dirichlet_i64, csr_to_dense
  implicit none

  type(csr_matrix_t) :: A
  integer(i64) :: maps(2,3),fixed(2),invalid_large_map(1,1)
  real(dp) :: K1(3,3),K2(3,3),dense(5,5),expected(5,5),rhs(5)
  integer :: status

  maps(1,:) = [1_i64,2_i64,3_i64]
  maps(2,:) = [3_i64,4_i64,5_i64]
  call initialize_csr_from_element_dof_maps_i64(A,5_i64,5_i64,maps,status)
  call require(status == DES_STATUS_OK,'Canonical i64 CSR graph initialization başarısız')
  call require(A%nrows == 5_i64 .and. A%ncols == 5_i64,'Canonical i64 CSR dimension yanlış')
  call require(A%nnz_i64() == 17_i64,'Canonical i64 CSR nnz yanlış')

  K1 = reshape([1.0_dp,2.0_dp,3.0_dp,4.0_dp,5.0_dp,6.0_dp, &
                7.0_dp,8.0_dp,9.0_dp],shape(K1))
  K2 = 0.5_dp*K1
  call csr_add_local_matrix_i64(A,maps(1,:),K1,status)
  call require(status == DES_STATUS_OK,'Canonical i64 CSR ilk scatter başarısız')
  call csr_add_local_matrix_i64(A,maps(2,:),K2,status)
  call require(status == DES_STATUS_OK,'Canonical i64 CSR ikinci scatter başarısız')

  expected = 0.0_dp
  call add_dense_i64(expected,maps(1,:),K1)
  call add_dense_i64(expected,maps(2,:),K2)
  call csr_to_dense(A,dense,status)
  call require(status == DES_STATUS_OK,'Canonical i64 CSR dense conversion başarısız')
  call require(maxval(abs(dense-expected)) <= 1.0e-14_dp, &
      'Canonical i64 scatter legacy matematiğiyle uyuşmuyor')

  fixed = [2_i64,4_i64]
  rhs = [1.0_dp,2.0_dp,3.0_dp,4.0_dp,5.0_dp]
  call csr_apply_zero_dirichlet_i64(A,rhs,fixed,status)
  call require(status == DES_STATUS_OK,'Canonical i64 Dirichlet başarısız')
  call require(rhs(2) == 0.0_dp .and. rhs(4) == 0.0_dp, &
      'Canonical i64 Dirichlet RHS sıfırlamadı')

  ! Büyük equation label küçük dimension içinde sessizce default integer'a
  ! daraltılmamalı; allocation yapılmadan explicit invalid constraint dönmeli.
  invalid_large_map(1,1) = 3000000000_i64
  call initialize_csr_from_element_dof_maps_i64( &
      A,5_i64,5_i64,invalid_large_map,status)
  call require(status == DES_ERROR_INVALID_CONSTRAINT, &
      'i64 CSR büyük label sınır kontrolü sessiz narrowing yaptı')

  print '(a)', 'PASS: canonical i64 CSR constructor/scatter/Dirichlet interface'

contains

  subroutine add_dense_i64(global_matrix,dof_map,local_matrix)
    real(dp), intent(inout) :: global_matrix(:,:)
    integer(i64), intent(in) :: dof_map(:)
    real(dp), intent(in) :: local_matrix(:,:)
    integer :: i,j

    do i=1,size(dof_map)
      do j=1,size(dof_map)
        global_matrix(dof_map(i),dof_map(j)) = &
            global_matrix(dof_map(i),dof_map(j))+local_matrix(i,j)
      end do
    end do
  end subroutine add_dense_i64

  subroutine require(condition,message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) error stop message
  end subroutine require

end program test_csr_i64_interface
