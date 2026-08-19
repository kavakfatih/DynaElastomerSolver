program test_q8_herrmann_interpolation
  use des_kinds, only : dp
  use des_q8_herrmann_interpolation, only : q8_shape_functions, &
                                             herrmann_p1_pressure_basis
  implicit none

  real(dp), parameter :: tol = 2.0e-14_dp
  real(dp), parameter :: xi_node(8) = [-1.0_dp, 1.0_dp, 1.0_dp, -1.0_dp, &
                                        0.0_dp, 1.0_dp, 0.0_dp, -1.0_dp]
  real(dp), parameter :: eta_node(8) = [-1.0_dp,-1.0_dp, 1.0_dp, 1.0_dp, &
                                        -1.0_dp, 0.0_dp, 1.0_dp, 0.0_dp]
  real(dp) :: N(8), dN(8,2), Np(3), expected
  real(dp) :: sample_xi(4), sample_eta(4)
  integer :: a, b, s

  ! Q8 nodal Kronecker özelliği.
  do a = 1,8
    call q8_shape_functions(xi_node(a),eta_node(a),N,dN)
    do b = 1,8
      expected = 0.0_dp
      if (a == b) expected = 1.0_dp
      if (abs(N(b)-expected) > tol) then
        error stop 'Q8 Kronecker interpolation identity basarisiz.'
      end if
    end do
    if (abs(sum(N)-1.0_dp) > tol) then
      error stop 'Q8 partition of unity basarisiz.'
    end if
    if (maxval(abs(sum(dN,dim=1))) > 5.0e-14_dp) then
      error stop 'Q8 shape derivative toplami sifir degil.'
    end if
  end do

  sample_xi = [0.0_dp,0.2_dp,-0.47_dp,0.5773502691896258_dp]
  sample_eta = [0.0_dp,-0.3_dp,0.61_dp,-0.21_dp]

  do s = 1,size(sample_xi)
    call q8_shape_functions(sample_xi(s),sample_eta(s),N,dN)
    if (abs(sum(N)-1.0_dp) > tol) then
      error stop 'Q8 ic noktada partition of unity basarisiz.'
    end if
    if (maxval(abs(sum(dN,dim=1))) > 5.0e-14_dp) then
      error stop 'Q8 ic noktada derivative consistency basarisiz.'
    end if

    call herrmann_p1_pressure_basis(sample_xi(s),sample_eta(s),Np)
    if (abs(Np(1)-1.0_dp) > tol .or. &
        abs(Np(2)-sample_xi(s)) > tol .or. &
        abs(Np(3)-sample_eta(s)) > tol) then
      error stop 'Herrmann P1 pressure basis lineer alan uretmiyor.'
    end if

    ! p(xi,eta)=2-3*xi+4*eta lineer alanı üç coefficient ile tam temsil edilir.
    expected = 2.0_dp-3.0_dp*sample_xi(s)+4.0_dp*sample_eta(s)
    if (abs(dot_product([2.0_dp,-3.0_dp,4.0_dp],Np)-expected) > tol) then
      error stop 'Herrmann P1 pressure exact-linear testi basarisiz.'
    end if
  end do

  call q8_shape_functions(0.0_dp,0.0_dp,N,dN)
  if (maxval(abs(N(1:4)+0.25_dp)) > tol) then
    error stop 'Q8 merkez corner shape degerleri yanlis.'
  end if
  if (maxval(abs(N(5:8)-0.50_dp)) > tol) then
    error stop 'Q8 merkez midside shape degerleri yanlis.'
  end if

  write(*,'(A)') 'Q8 displacement + Herrmann P1 pressure interpolation testleri BASARILI.'
end program test_q8_herrmann_interpolation
