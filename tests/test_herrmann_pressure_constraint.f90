program test_herrmann_pressure_constraint
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_PARAMETERS
  use des_herrmann_pressure_constraint, only : herrmann_constraint_response_t, &
                                                evaluate_herrmann_pressure_constraint
  implicit none

  real(dp), parameter :: h = 1.0e-7_dp
  real(dp), parameter :: tol_fd = 3.0e-7_dp
  real(dp) :: F(3,3), F_plus(3,3), F_minus(3,3)
  real(dp) :: fd_tangent(3,3,3,3), fd_constraint(3,3), fd_dp(3,3)
  real(dp) :: tangent_error, constraint_error, dp_error, scale
  real(dp) :: pressure, compliance, constraint_fd_p
  type(herrmann_constraint_response_t) :: response, plus_response, minus_response
  integer :: i,j,k,l

  ! Fully incompressible reference state: J=1 constraint sifirdir ve K_pp=0'dir.
  F = 0.0_dp
  do i = 1,3
    F(i,i) = 1.0_dp
  end do
  pressure = 4.25_dp
  compliance = 0.0_dp
  call evaluate_herrmann_pressure_constraint(F,pressure,compliance,response)

  if (.not. response%valid .or. response%status /= DES_STATUS_OK) then
    error stop 'Fully incompressible Herrmann reference state gecersiz.'
  end if
  if (abs(response%constraint) > 1.0e-14_dp) then
    error stop 'J=1 fully incompressible constraint sifir degil.'
  end if
  if (abs(response%dconstraint_dp) > 1.0e-14_dp) then
    error stop 'Fully incompressible Herrmann K_pp point termi sifir degil.'
  end if
  do i = 1,3
    do j = 1,3
      if (i == j) then
        if (abs(response%cauchy(i,j)+pressure) > 1.0e-14_dp) then
          error stop 'Herrmann hydrostatic Cauchy pressure isareti hatali.'
        end if
      else
        if (abs(response%cauchy(i,j)) > 1.0e-14_dp) then
          error stop 'Herrmann hydrostatic Cauchy off-diagonal sifir degil.'
        end if
      end if
    end do
  end do

  ! Nearly incompressible uyumluluk: J=0.98 ve c_p=0.01 icin p=2 constraint'i saglar.
  F = 0.0_dp
  F(1,1) = 0.98_dp
  F(2,2) = 1.0_dp
  F(3,3) = 1.0_dp
  pressure = 2.0_dp
  compliance = 0.01_dp
  call evaluate_herrmann_pressure_constraint(F,pressure,compliance,response)
  if (abs(response%constraint) > 2.0e-14_dp) then
    error stop 'Nearly incompressible Herrmann compatibility constraint saglanmadi.'
  end if

  ! Genel finite deformation: pressure Piola/tangent ve constraint derivatives FD ile kontrol edilir.
  F = reshape([ &
      1.15_dp,0.03_dp,0.01_dp, &
      0.08_dp,0.92_dp,0.04_dp, &
      0.02_dp,0.05_dp,1.07_dp], [3,3])
  pressure = 3.2_dp
  compliance = 0.004_dp
  call evaluate_herrmann_pressure_constraint(F,pressure,compliance,response)
  if (.not. response%valid) error stop 'Genel Herrmann pressure state gecersiz.'

  fd_tangent = 0.0_dp
  fd_constraint = 0.0_dp
  do k = 1,3
    do l = 1,3
      F_plus = F
      F_minus = F
      F_plus(k,l) = F_plus(k,l)+h
      F_minus(k,l) = F_minus(k,l)-h
      call evaluate_herrmann_pressure_constraint( &
          F_plus,pressure,compliance,plus_response)
      call evaluate_herrmann_pressure_constraint( &
          F_minus,pressure,compliance,minus_response)
      if (.not. plus_response%valid .or. .not. minus_response%valid) then
        error stop 'Herrmann pressure FD perturbation state gecersiz.'
      end if
      fd_tangent(:,:,k,l) = (plus_response%P-minus_response%P)/(2.0_dp*h)
      fd_constraint(k,l) = (plus_response%constraint-minus_response%constraint)/(2.0_dp*h)
    end do
  end do

  scale = max(1.0_dp,maxval(abs(fd_tangent)))
  tangent_error = maxval(abs(response%tangent_F-fd_tangent))/scale
  if (tangent_error > tol_fd) then
    error stop 'Herrmann pressure analytic F tangent FD ile uyusmuyor.'
  end if

  scale = max(1.0_dp,maxval(abs(fd_constraint)))
  constraint_error = maxval(abs(response%dconstraint_dF-fd_constraint))/scale
  if (constraint_error > tol_fd) then
    error stop 'Herrmann constraint dR_p/dF FD ile uyusmuyor.'
  end if

  call evaluate_herrmann_pressure_constraint(F,pressure+h,compliance,plus_response)
  call evaluate_herrmann_pressure_constraint(F,pressure-h,compliance,minus_response)
  fd_dp = (plus_response%P-minus_response%P)/(2.0_dp*h)
  dp_error = maxval(abs(response%dP_dp-fd_dp))/max(1.0_dp,maxval(abs(fd_dp)))
  if (dp_error > 5.0e-9_dp) then
    error stop 'Herrmann dP/dp coupling FD ile uyusmuyor.'
  end if
  constraint_fd_p = (plus_response%constraint-minus_response%constraint)/(2.0_dp*h)
  if (abs(constraint_fd_p-response%dconstraint_dp) > 5.0e-9_dp) then
    error stop 'Herrmann K_pp point derivative FD ile uyusmuyor.'
  end if

  ! Hyperelastic mixed potentialin pressure tangent'i major-symmetric olmali.
  do i = 1,3
    do j = 1,3
      do k = 1,3
        do l = 1,3
          if (abs(response%tangent_F(i,j,k,l)-response%tangent_F(k,l,i,j)) &
              > 2.0e-12_dp) then
            error stop 'Herrmann pressure F tangent major symmetry kaybetti.'
          end if
        end do
      end do
    end do
  end do

  call evaluate_herrmann_pressure_constraint(F,pressure,-0.01_dp,response)
  if (response%status /= DES_ERROR_INVALID_PARAMETERS .or. response%valid) then
    error stop 'Negatif pressure compliance reddedilmedi.'
  end if

  write(*,'(A,ES14.6)') 'Herrmann pressure tangent FD error = ',tangent_error
  write(*,'(A,ES14.6)') 'Herrmann constraint FD error = ',constraint_error
  write(*,'(A,ES14.6)') 'Herrmann dP/dp FD error = ',dp_error
  write(*,'(A)') 'Herrmann hydrostatic pressure constraint testi BASARILI.'
end program test_herrmann_pressure_constraint
