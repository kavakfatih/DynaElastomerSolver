program test_q8_herrmann_geometry
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_ELEMENT_JACOBIAN
  use des_q8_herrmann_geometry, only : q8_reference_gradient
  implicit none

  real(dp), parameter :: tol = 5.0e-13_dp
  real(dp) :: X(8,2), X_bad(8,2)
  real(dp) :: N(8), dN_parent(8,2), dN_dX(8,2)
  real(dp) :: x_point(2), Jmap(2,2), det_jac
  real(dp) :: grad_x(2), grad_y(2)
  real(dp) :: xi, eta
  integer :: status, a

  ! Affine ama skew bir Q8 geometri: x=1+xi+0.2*eta, y=0.5+0.1*xi+0.5*eta.
  call set_affine_q8_coordinates(X)

  xi = 0.31_dp
  eta = -0.27_dp
  call q8_reference_gradient( &
      X,xi,eta,N,dN_parent,dN_dX,x_point,Jmap,det_jac,status)

  if (status /= DES_STATUS_OK) error stop 'Q8 geometri Jacobiani gecerli olmali.'
  if (abs(x_point(1)-(1.0_dp+xi+0.2_dp*eta)) > tol) then
    error stop 'Q8 isoparametric x mapping affine alani tam uretmiyor.'
  end if
  if (abs(x_point(2)-(0.5_dp+0.1_dp*xi+0.5_dp*eta)) > tol) then
    error stop 'Q8 isoparametric y mapping affine alani tam uretmiyor.'
  end if

  if (abs(Jmap(1,1)-1.0_dp) > tol .or. abs(Jmap(1,2)-0.1_dp) > tol .or. &
      abs(Jmap(2,1)-0.2_dp) > tol .or. abs(Jmap(2,2)-0.5_dp) > tol) then
    error stop 'Q8 geometrik Jacobian beklenen affine mapping ile uyusmuyor.'
  end if
  if (abs(det_jac-0.48_dp) > tol) then
    error stop 'Q8 geometrik Jacobian determinanti hatali.'
  end if

  if (maxval(abs(sum(dN_dX,dim=1))) > tol) then
    error stop 'Q8 global shape gradient toplami sifir degil.'
  end if

  grad_x = 0.0_dp
  grad_y = 0.0_dp
  do a = 1,8
    grad_x = grad_x + X(a,1)*dN_dX(a,:)
    grad_y = grad_y + X(a,2)*dN_dX(a,:)
  end do

  if (maxval(abs(grad_x-[1.0_dp,0.0_dp])) > tol) then
    error stop 'Q8 global gradient x koordinatini tam uretmiyor.'
  end if
  if (maxval(abs(grad_y-[0.0_dp,1.0_dp])) > tol) then
    error stop 'Q8 global gradient y koordinatini tam uretmiyor.'
  end if

  ! Aynalama orientation'i tersine cevirir ve production geometri kapisindan gecmemelidir.
  X_bad = X
  X_bad(:,1) = -X_bad(:,1)
  call q8_reference_gradient( &
      X_bad,0.0_dp,0.0_dp,N,dN_parent,dN_dX,x_point,Jmap,det_jac,status)
  if (status /= DES_ERROR_INVALID_ELEMENT_JACOBIAN) then
    error stop 'Ters orientation Q8 elementi reddedilmedi.'
  end if

  write(*,'(A,ES14.6)') 'Q8 affine det(Jmap) = ',0.48_dp
  write(*,'(A)') 'Q8 Herrmann geometri/gradient testleri BASARILI.'

contains

  subroutine set_affine_q8_coordinates(coords)
    real(dp), intent(out) :: coords(8,2)
    real(dp), parameter :: xi_node(8) = [-1.0_dp,1.0_dp,1.0_dp,-1.0_dp, &
                                         0.0_dp,1.0_dp,0.0_dp,-1.0_dp]
    real(dp), parameter :: eta_node(8) = [-1.0_dp,-1.0_dp,1.0_dp,1.0_dp, &
                                         -1.0_dp,0.0_dp,1.0_dp,0.0_dp]
    integer :: i

    do i = 1,8
      coords(i,1) = 1.0_dp + xi_node(i) + 0.2_dp*eta_node(i)
      coords(i,2) = 0.5_dp + 0.1_dp*xi_node(i) + 0.5_dp*eta_node(i)
    end do
  end subroutine set_affine_q8_coordinates

end program test_q8_herrmann_geometry
