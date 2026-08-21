program test_q8_axisymmetric_herrmann_element
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_q8_axisymmetric_herrmann_neo_hookean, only : &
      Q8_AXISYM_HERRMANN_U_DOF, Q8_AXISYM_HERRMANN_TOTAL_DOF, &
      evaluate_q8_axisymmetric_herrmann_reduced_element
  implicit none

  real(dp), parameter :: mu = 2.5_dp
  real(dp), parameter :: compliance = 0.02_dp
  real(dp), parameter :: h = 1.0e-7_dp
  real(dp), parameter :: fd_tol = 7.0e-6_dp
  real(dp) :: X(8,2),u(8,2),p(3)
  real(dp) :: residual(Q8_AXISYM_HERRMANN_TOTAL_DOF)
  real(dp) :: tangent(Q8_AXISYM_HERRMANN_TOTAL_DOF,Q8_AXISYM_HERRMANN_TOTAL_DOF)
  real(dp) :: fd(Q8_AXISYM_HERRMANN_TOTAL_DOF,Q8_AXISYM_HERRMANN_TOTAL_DOF)
  real(dp) :: rp(Q8_AXISYM_HERRMANN_TOTAL_DOF),rm(Q8_AXISYM_HERRMANN_TOTAL_DOF)
  real(dp) :: kd(Q8_AXISYM_HERRMANN_TOTAL_DOF,Q8_AXISYM_HERRMANN_TOTAL_DOF)
  real(dp) :: xlocal(Q8_AXISYM_HERRMANN_TOTAL_DOF)
  real(dp) :: xp(Q8_AXISYM_HERRMANN_TOTAL_DOF),xm(Q8_AXISYM_HERRMANN_TOTAL_DOF)
  real(dp) :: uw(8,2),pw(3),j_target,min_j,min_jd,scale,fd_error,symmetry_error
  integer :: a,j,status,sp,sm

  call set_annulus_q8(X)

  ! Constant axisymmetric finite deformation:
  ! r=1.05 R, z=0.01 R + 1.02 Z.
  do a = 1,8
    u(a,1) = 0.05_dp*X(a,1)
    u(a,2) = 0.01_dp*X(a,1)+0.02_dp*X(a,2)
  end do
  j_target = 1.05_dp*1.05_dp*1.02_dp
  p = [-(j_target-1.0_dp)/compliance,0.0_dp,0.0_dp]

  call evaluate_q8_axisymmetric_herrmann_reduced_element( &
      X,u,p,mu,compliance,residual,tangent,status,min_j)
  call require(status == DES_STATUS_OK,'Q8 axisymmetric Herrmann element değerlendirilemedi')
  call require(abs(min_j-j_target) <= 5.0e-13_dp,'Axisymmetric constant F için J yanlış')
  call require(maxval(abs(residual(Q8_AXISYM_HERRMANN_U_DOF+1: &
      Q8_AXISYM_HERRMANN_TOTAL_DOF))) <= 3.0e-12_dp, &
      'Axisymmetric pressure compatibility residual sıfır değil')

  call pack_state(u,p,xlocal)
  do j = 1,Q8_AXISYM_HERRMANN_TOTAL_DOF
    xp = xlocal
    xm = xlocal
    xp(j) = xp(j)+h
    xm(j) = xm(j)-h

    call unpack_state(xp,uw,pw)
    call evaluate_q8_axisymmetric_herrmann_reduced_element( &
        X,uw,pw,mu,compliance,rp,kd,sp,min_jd)
    call require(sp == DES_STATUS_OK,'Axisymmetric +FD perturbation başarısız')

    call unpack_state(xm,uw,pw)
    call evaluate_q8_axisymmetric_herrmann_reduced_element( &
        X,uw,pw,mu,compliance,rm,kd,sm,min_jd)
    call require(sm == DES_STATUS_OK,'Axisymmetric -FD perturbation başarısız')

    fd(:,j) = (rp-rm)/(2.0_dp*h)
  end do

  scale = max(1.0_dp,maxval(abs(fd)))
  fd_error = maxval(abs(tangent-fd))/scale
  symmetry_error = maxval(abs(tangent-transpose(tangent))) &
      / max(1.0_dp,maxval(abs(tangent)))
  call require(fd_error <= fd_tol,'Axisymmetric analytic tangent FD ile uyuşmuyor')
  call require(symmetry_error <= 3.0e-11_dp,'Axisymmetric tangent symmetry kaybetti')

  p = [0.4_dp,0.03_dp,-0.02_dp]
  call evaluate_q8_axisymmetric_herrmann_reduced_element( &
      X,u,p,mu,0.0_dp,residual,tangent,status,min_j)
  call require(status == DES_STATUS_OK,'Axisymmetric incompressible limit başarısız')
  call require(maxval(abs(tangent(Q8_AXISYM_HERRMANN_U_DOF+1:, &
                                   Q8_AXISYM_HERRMANN_U_DOF+1:))) <= 1.0e-14_dp, &
      'Axisymmetric fully incompressible K_pp sıfır değil')

  write(*,'(A,ES14.6)') 'Q8 axisymmetric tangent FD error = ',fd_error
  write(*,'(A,ES14.6)') 'Q8 axisymmetric symmetry error = ',symmetry_error
  write(*,'(A)') 'PASS: Q8/P1 finite-strain axisymmetric Herrmann element'

contains

  subroutine set_annulus_q8(coords)
    real(dp), intent(out) :: coords(8,2)
    coords(1,:) = [1.0_dp,0.0_dp]
    coords(2,:) = [2.0_dp,0.0_dp]
    coords(3,:) = [2.0_dp,1.0_dp]
    coords(4,:) = [1.0_dp,1.0_dp]
    coords(5,:) = [1.5_dp,0.0_dp]
    coords(6,:) = [2.0_dp,0.5_dp]
    coords(7,:) = [1.5_dp,1.0_dp]
    coords(8,:) = [1.0_dp,0.5_dp]
  end subroutine set_annulus_q8

  subroutine pack_state(us,ps,x)
    real(dp), intent(in) :: us(8,2),ps(3)
    real(dp), intent(out) :: x(Q8_AXISYM_HERRMANN_TOTAL_DOF)
    integer :: node
    do node = 1,8
      x(2*node-1) = us(node,1)
      x(2*node) = us(node,2)
    end do
    x(Q8_AXISYM_HERRMANN_U_DOF+1:) = ps
  end subroutine pack_state

  subroutine unpack_state(x,us,ps)
    real(dp), intent(in) :: x(Q8_AXISYM_HERRMANN_TOTAL_DOF)
    real(dp), intent(out) :: us(8,2),ps(3)
    integer :: node
    do node = 1,8
      us(node,1) = x(2*node-1)
      us(node,2) = x(2*node)
    end do
    ps = x(Q8_AXISYM_HERRMANN_U_DOF+1:)
  end subroutine unpack_state

  subroutine require(condition,message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) error stop message
  end subroutine require

end program test_q8_axisymmetric_herrmann_element
