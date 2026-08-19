program test_q9_herrmann_geometry
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_ELEMENT_JACOBIAN
  use des_q9_herrmann_geometry, only : q9_reference_gradient
  implicit none

  real(dp), parameter :: tol = 7.0e-13_dp
  real(dp) :: X(9,2), X_bad(9,2)
  real(dp) :: N(9), dN_parent(9,2), dN_dX(9,2)
  real(dp) :: x_point(2), Jmap(2,2), det_jac
  real(dp) :: grad_x(2), grad_y(2), xi, eta
  integer :: status,a

  call set_affine_q9_coordinates(X)
  xi = 0.23_dp
  eta = -0.41_dp

  call q9_reference_gradient( &
      X,xi,eta,N,dN_parent,dN_dX,x_point,Jmap,det_jac,status)

  if (status /= DES_STATUS_OK) error stop 'Q9 geometri Jacobiani gecerli olmali.'
  if (abs(x_point(1)-(2.0_dp+1.5_dp*xi+0.2_dp*eta)) > tol) then
    error stop 'Q9 isoparametric x mapping affine alani tam uretmiyor.'
  end if
  if (abs(x_point(2)-(-1.0_dp+0.3_dp*xi+0.9_dp*eta)) > tol) then
    error stop 'Q9 isoparametric y mapping affine alani tam uretmiyor.'
  end if

  if (abs(Jmap(1,1)-1.5_dp) > tol .or. abs(Jmap(1,2)-0.3_dp) > tol .or. &
      abs(Jmap(2,1)-0.2_dp) > tol .or. abs(Jmap(2,2)-0.9_dp) > tol) then
    error stop 'Q9 geometrik Jacobian beklenen affine mapping ile uyusmuyor.'
  end if
  if (abs(det_jac-1.29_dp) > tol) then
    error stop 'Q9 geometrik Jacobian determinanti hatali.'
  end if

  if (maxval(abs(sum(dN_dX,dim=1))) > tol) then
    error stop 'Q9 global shape gradient toplami sifir degil.'
  end if

  grad_x = 0.0_dp
  grad_y = 0.0_dp
  do a = 1,9
    grad_x = grad_x + X(a,1)*dN_dX(a,:)
    grad_y = grad_y + X(a,2)*dN_dX(a,:)
  end do

  if (maxval(abs(grad_x-[1.0_dp,0.0_dp])) > tol) then
    error stop 'Q9 global gradient x koordinatini tam uretmiyor.'
  end if
  if (maxval(abs(grad_y-[0.0_dp,1.0_dp])) > tol) then
    error stop 'Q9 global gradient y koordinatini tam uretmiyor.'
  end if

  X_bad = X
  X_bad(:,1) = -X_bad(:,1)
  call q9_reference_gradient( &
      X_bad,0.0_dp,0.0_dp,N,dN_parent,dN_dX,x_point,Jmap,det_jac,status)
  if (status /= DES_ERROR_INVALID_ELEMENT_JACOBIAN) then
    error stop 'Ters orientation Q9 elementi reddedilmedi.'
  end if

  write(*,'(A,ES14.6)') 'Q9 affine det(Jmap) = ',1.29_dp
  write(*,'(A)') 'Q9 Herrmann geometri/gradient testleri BASARILI.'

contains

  subroutine set_affine_q9_coordinates(coords)
    real(dp), intent(out) :: coords(9,2)
    real(dp), parameter :: xi_node(9) = [-1.0_dp,1.0_dp,1.0_dp,-1.0_dp, &
                                         0.0_dp,1.0_dp,0.0_dp,-1.0_dp,0.0_dp]
    real(dp), parameter :: eta_node(9) = [-1.0_dp,-1.0_dp,1.0_dp,1.0_dp, &
                                         -1.0_dp,0.0_dp,1.0_dp,0.0_dp,0.0_dp]
    integer :: i

    do i = 1,9
      coords(i,1) = 2.0_dp + 1.5_dp*xi_node(i) + 0.2_dp*eta_node(i)
      coords(i,2) = -1.0_dp + 0.3_dp*xi_node(i) + 0.9_dp*eta_node(i)
    end do
  end subroutine set_affine_q9_coordinates

end program test_q9_herrmann_geometry
