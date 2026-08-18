program test_pressure_diagnostics
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONSTRAINT
  use des_pressure_diagnostics, only : pressure_diagnostics_t, &
                                       evaluate_q4_pressure_diagnostics
  implicit none

  integer :: connectivity(4,4), status
  real(dp) :: pressure(4), constant_pressure(4)
  type(pressure_diagnostics_t) :: d
  real(dp), parameter :: tol = 1.0e-12_dp

  ! Düzenli 2x2 Q4 mesh eleman bağlantıları.
  connectivity(1,:) = [1,2,5,4]
  connectivity(2,:) = [2,3,6,5]
  connectivity(3,:) = [4,5,8,7]
  connectivity(4,:) = [5,6,9,8]

  pressure = [1.0_dp,2.0_dp,3.0_dp,4.0_dp]
  call evaluate_q4_pressure_diagnostics(connectivity,pressure,d,status)

  if (status /= DES_STATUS_OK .or. .not. d%valid) error stop 'Pressure diagnostics başarısız.'
  if (d%neighbor_pair_count /= 4) error stop '2x2 mesh neighbor pair sayısı hatalı.'
  if (abs(d%mean-2.5_dp) > tol) error stop 'Pressure mean hatalı.'
  if (abs(d%minimum-1.0_dp) > tol .or. abs(d%maximum-4.0_dp) > tol) then
    error stop 'Pressure min/max hatalı.'
  end if
  if (abs(d%neighbor_jump_rms-sqrt(2.5_dp)) > tol) then
    error stop 'Pressure neighbor jump RMS hatalı.'
  end if
  if (abs(d%maximum_neighbor_jump-2.0_dp) > tol) then
    error stop 'Maximum neighbor pressure jump hatalı.'
  end if
  if (d%normalized_neighbor_jump_rms <= 0.0_dp) then
    error stop 'Normalize pressure jump pozitif değil.'
  end if

  constant_pressure = 7.0_dp
  call evaluate_q4_pressure_diagnostics(connectivity,constant_pressure,d,status)
  if (status /= DES_STATUS_OK) error stop 'Constant pressure diagnostics başarısız.'
  if (abs(d%standard_deviation) > tol) error stop 'Constant pressure std sıfır değil.'
  if (abs(d%neighbor_jump_rms) > tol) error stop 'Constant pressure jump sıfır değil.'
  if (abs(d%normalized_neighbor_jump_rms) > tol) error stop 'Constant pressure normalized jump sıfır değil.'

  call check_wrong_pressure_size(connectivity)

  write(*,'(A)') 'Pressure diagnostics testi BASARILI.'

contains

  subroutine check_wrong_pressure_size(conn)
    integer, intent(in) :: conn(:,:)
    real(dp) :: bad_pressure(3)
    type(pressure_diagnostics_t) :: local_d
    integer :: local_status

    bad_pressure = 0.0_dp
    call evaluate_q4_pressure_diagnostics(conn,bad_pressure,local_d,local_status)
    if (local_status /= DES_ERROR_INVALID_CONSTRAINT) then
      error stop 'Yanlış pressure boyutu reddedilmedi.'
    end if
  end subroutine check_wrong_pressure_size

end program test_pressure_diagnostics
