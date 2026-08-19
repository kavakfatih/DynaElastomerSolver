program test_q9_herrmann_interpolation
  use des_kinds, only : dp
  use des_q9_herrmann_interpolation, only : q9_shape_functions
  implicit none

  real(dp), parameter :: tol = 5.0e-14_dp
  real(dp), parameter :: xi_node(9) = [-1.0_dp,1.0_dp,1.0_dp,-1.0_dp, &
                                        0.0_dp,1.0_dp,0.0_dp,-1.0_dp,0.0_dp]
  real(dp), parameter :: eta_node(9) = [-1.0_dp,-1.0_dp,1.0_dp,1.0_dp, &
                                        -1.0_dp,0.0_dp,1.0_dp,0.0_dp,0.0_dp]
  real(dp), parameter :: sample_xi(4) = [0.0_dp,0.23_dp,-0.47_dp,0.71_dp]
  real(dp), parameter :: sample_eta(4) = [0.0_dp,-0.41_dp,0.61_dp,0.19_dp]
  real(dp) :: N(9), dN(9,2), expected, reproduced(2)
  integer :: a,b,s

  do a = 1,9
    call q9_shape_functions(xi_node(a),eta_node(a),N,dN)
    do b = 1,9
      expected = 0.0_dp
      if (a == b) expected = 1.0_dp
      if (abs(N(b)-expected) > tol) then
        error stop 'Q9 Kronecker interpolation identity basarisiz.'
      end if
    end do
    if (abs(sum(N)-1.0_dp) > tol) then
      error stop 'Q9 partition of unity basarisiz.'
    end if
    if (maxval(abs(sum(dN,dim=1))) > tol) then
      error stop 'Q9 shape derivative toplami sifir degil.'
    end if
  end do

  do s = 1,size(sample_xi)
    call q9_shape_functions(sample_xi(s),sample_eta(s),N,dN)
    if (abs(sum(N)-1.0_dp) > tol) then
      error stop 'Q9 ic noktada partition of unity basarisiz.'
    end if
    if (maxval(abs(sum(dN,dim=1))) > tol) then
      error stop 'Q9 ic noktada derivative consistency basarisiz.'
    end if

    reproduced(1) = dot_product(N,xi_node)
    reproduced(2) = dot_product(N,eta_node)
    if (maxval(abs(reproduced-[sample_xi(s),sample_eta(s)])) > tol) then
      error stop 'Q9 lineer parent-coordinate reproduction basarisiz.'
    end if
  end do

  call q9_shape_functions(0.0_dp,0.0_dp,N,dN)
  if (abs(N(9)-1.0_dp) > tol .or. maxval(abs(N(1:8))) > tol) then
    error stop 'Q9 merkez dugum Kronecker degeri yanlis.'
  end if

  write(*,'(A)') 'Q9 quadratic displacement interpolation testleri BASARILI.'
end program test_q9_herrmann_interpolation
