program test_mixed_block_system
  use des_kinds, only : dp, i64
  use des_status, only : DES_STATUS_OK
  use des_csr_matrix, only : csr_matrix_t, initialize_csr_from_element_dof_maps_i64, &
      csr_add_local_matrix_i64, csr_matvec
  use des_2d_dof_manager, only : dof_layout_2d_t
  use des_mixed_block_system, only : mixed_block_partition_t, &
      initialize_mixed_block_partition, initialize_mixed_block_partition_from_2d_layout, &
      split_mixed_vector, join_mixed_vector, apply_mixed_block_operator, &
      apply_mixed_kuu, apply_mixed_kup, apply_mixed_kpu, apply_mixed_kpp
  implicit none

  type(csr_matrix_t) :: matrix
  type(mixed_block_partition_t) :: partition,layout_partition
  type(dof_layout_2d_t) :: layout
  integer(i64) :: element_map(1,5)
  real(dp) :: a(5,5),x(5),y_full(5),joined(5)
  real(dp) :: xu(3),xp(2),yu(3),yp(2)
  real(dp) :: yuu(3),yup(3),ypu(2),ypp(2)
  real(dp) :: expected_u(3),expected_p(2)
  integer :: status

  element_map(1,:) = [1_i64,2_i64,3_i64,4_i64,5_i64]
  call initialize_csr_from_element_dof_maps_i64( &
      matrix,5_i64,5_i64,element_map,status)
  call require(status == DES_STATUS_OK,'Mixed block test CSR graph kurulamadı')

  ! Saddle-point benzeri küçük mixed sistem. İlk 3 denklem kinematik,
  ! son 2 denklem pressure alanıdır.
  a = 0.0_dp
  a(1:3,1:3) = reshape([ &
      4.0_dp,1.0_dp,0.0_dp, &
      1.0_dp,3.0_dp,1.0_dp, &
      0.0_dp,1.0_dp,2.0_dp], [3,3])
  a(1:3,4:5) = reshape([ &
      1.0_dp,0.0_dp,1.0_dp, &
      0.0_dp,2.0_dp,1.0_dp], [3,2])
  a(4:5,1:3) = transpose(a(1:3,4:5))
  a(4:5,4:5) = reshape([0.50_dp,0.0_dp,0.0_dp,0.25_dp],[2,2])

  call csr_add_local_matrix_i64(matrix,element_map(1,:),a,status)
  call require(status == DES_STATUS_OK,'Mixed block test CSR değerleri eklenemedi')

  call initialize_mixed_block_partition(3_i64,2_i64,partition,status)
  call require(status == DES_STATUS_OK .and. partition%is_valid(), &
      'Mixed block partition kurulamadı')
  call require(partition%n_total == 5_i64,'Mixed block toplam boyutu yanlış')

  ! 2D field layout -> block partition köprüsü generalized kinematic DOF'ları
  ! pressure'a karıştırmamalıdır.
  layout%nodal_equation_count = 12_i64
  layout%generalized_equation_count = 3_i64
  layout%pressure_equation_count = 6_i64
  layout%total_equation_count = 21_i64
  call initialize_mixed_block_partition_from_2d_layout(layout,layout_partition,status)
  call require(status == DES_STATUS_OK,'2D layout mixed block partition'a çevrilemedi')
  call require(layout_partition%n_kinematic == 15_i64 .and. &
      layout_partition%n_pressure == 6_i64 .and. layout_partition%n_total == 21_i64, &
      '2D layout block cardinality sözleşmesi yanlış')

  x = [1.0_dp,2.0_dp,3.0_dp,-1.0_dp,4.0_dp]
  call split_mixed_vector(partition,x,xu,xp,status)
  call require(status == DES_STATUS_OK,'Mixed vector split başarısız')
  call join_mixed_vector(partition,xu,xp,joined,status)
  call require(status == DES_STATUS_OK,'Mixed vector join başarısız')
  call require(maxval(abs(joined-x)) <= 1.0e-14_dp,'Split/join round-trip parity bozuldu')

  call csr_matvec(matrix,x,y_full,status)
  call require(status == DES_STATUS_OK,'Monolitik CSR matvec başarısız')

  call apply_mixed_block_operator(matrix,partition,xu,xp,yu,yp,status)
  call require(status == DES_STATUS_OK,'Mixed block operator apply başarısız')
  call require(maxval(abs(yu-y_full(1:3))) <= 1.0e-13_dp, &
      'Mixed block kinematik çıktı monolitik CSR ile eşleşmiyor')
  call require(maxval(abs(yp-y_full(4:5))) <= 1.0e-13_dp, &
      'Mixed block pressure çıktı monolitik CSR ile eşleşmiyor')

  call apply_mixed_kuu(matrix,partition,xu,yuu,status)
  call require(status == DES_STATUS_OK,'Kuu operator apply başarısız')
  call apply_mixed_kup(matrix,partition,xp,yup,status)
  call require(status == DES_STATUS_OK,'Kup operator apply başarısız')
  call apply_mixed_kpu(matrix,partition,xu,ypu,status)
  call require(status == DES_STATUS_OK,'Kpu operator apply başarısız')
  call apply_mixed_kpp(matrix,partition,xp,ypp,status)
  call require(status == DES_STATUS_OK,'Kpp operator apply başarısız')

  expected_u = matmul(a(1:3,1:3),xu)+matmul(a(1:3,4:5),xp)
  expected_p = matmul(a(4:5,1:3),xu)+matmul(a(4:5,4:5),xp)

  call require(maxval(abs(yuu+yup-expected_u)) <= 1.0e-13_dp, &
      'Kuu/Kup block decomposition dense reference ile eşleşmiyor')
  call require(maxval(abs(ypu+ypp-expected_p)) <= 1.0e-13_dp, &
      'Kpu/Kpp block decomposition dense reference ile eşleşmiyor')
  call require(maxval(abs(yu-(yuu+yup))) <= 1.0e-13_dp, &
      'Kinematik block toplamı combined operator ile eşleşmiyor')
  call require(maxval(abs(yp-(ypu+ypp))) <= 1.0e-13_dp, &
      'Pressure block toplamı combined operator ile eşleşmiyor')

  ! Hatalı partition sessizce kabul edilmemeli.
  call initialize_mixed_block_partition(0_i64,2_i64,layout_partition,status)
  call require(status /= DES_STATUS_OK,'Sıfır kinematik blok reddedilmedi')

  write(*,'(A)') 'PASS: mixed u-P block partition/operator monolithic CSR parity'

contains

  subroutine require(condition,message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message

    if (.not.condition) error stop message
  end subroutine require

end program test_mixed_block_system
