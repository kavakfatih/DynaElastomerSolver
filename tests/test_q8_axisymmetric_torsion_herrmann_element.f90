program test_q8_axisymmetric_torsion_herrmann_element
  use des_kinds, only : dp, i64
  use des_status, only : DES_STATUS_OK
  use des_torsion_results, only : torsion_response_point_t, &
      reaction_torque_from_residual, build_torsion_response_point
  use des_q8_axisymmetric_torsion_herrmann_neo_hookean, only : &
      Q8_TORSION_HERRMANN_U_DOF, Q8_TORSION_HERRMANN_TOTAL_DOF, &
      evaluate_q8_axisymmetric_torsion_herrmann_reduced_element
  implicit none

  real(dp), parameter :: mu = 2.5_dp
  real(dp), parameter :: compliance = 0.02_dp
  real(dp), parameter :: h = 1.0e-7_dp
  real(dp), parameter :: fd_tol = 1.0e-5_dp
  real(dp), parameter :: pi = acos(-1.0_dp)
  real(dp) :: X(8,2),u(8,3),p(3)
  real(dp) :: residual(Q8_TORSION_HERRMANN_TOTAL_DOF)
  real(dp) :: tangent(Q8_TORSION_HERRMANN_TOTAL_DOF,Q8_TORSION_HERRMANN_TOTAL_DOF)
  real(dp) :: fd(Q8_TORSION_HERRMANN_TOTAL_DOF,Q8_TORSION_HERRMANN_TOTAL_DOF)
  real(dp) :: rp(Q8_TORSION_HERRMANN_TOTAL_DOF),rm(Q8_TORSION_HERRMANN_TOTAL_DOF)
  real(dp) :: kd(Q8_TORSION_HERRMANN_TOTAL_DOF,Q8_TORSION_HERRMANN_TOTAL_DOF)
  real(dp) :: xlocal(Q8_TORSION_HERRMANN_TOTAL_DOF)
  real(dp) :: xp(Q8_TORSION_HERRMANN_TOTAL_DOF),xm(Q8_TORSION_HERRMANN_TOTAL_DOF)
  real(dp) :: uw(8,3),pw(3),j_target,min_j,min_jd,scale,fd_error,symmetry_error
  real(dp) :: alpha,computed_torque,expected_torque,torque_rel_error
  integer(i64), parameter :: top_torsion_equations(3) = [9_i64,12_i64,21_i64]
  type(torsion_response_point_t) :: torsion_point
  integer :: a,j,status,sp,sm

  call set_annulus_q8(X)

  ! Sabit ROTY gerçek rigid-body rotation'dır: phi gradientleri sıfır olduğunda
  ! F=I ve iç kuvvet/tork üretmemelidir.
  u = 0.0_dp
  u(:,3) = 0.30_dp
  p = 0.0_dp
  call evaluate_q8_axisymmetric_torsion_herrmann_reduced_element( &
      X,u,p,mu,0.0_dp,residual,tangent,status,min_j)
  call require(status == DES_STATUS_OK,'Rigid ROTY state değerlendirilemedi')
  call require(abs(min_j-1.0_dp) <= 2.0e-13_dp,'Rigid ROTY J=1 koşulunu bozdu')
  call require(maxval(abs(residual)) <= 3.0e-12_dp,'Rigid ROTY sahte iç kuvvet/tork üretti')

  ! Nonlinear axisymmetric twist state: r=1.02R, z=0.99Z,
  ! phi=0.01R+0.08Z. r*grad(phi) nedeniyle F ve B state-dependent'tir.
  do a = 1,8
    u(a,1) = 0.02_dp*X(a,1)
    u(a,2) = -0.01_dp*X(a,2)
    u(a,3) = 0.01_dp*X(a,1)+0.08_dp*X(a,2)
  end do
  j_target = 1.02_dp*1.02_dp*0.99_dp
  p = [-(j_target-1.0_dp)/compliance,0.0_dp,0.0_dp]

  call evaluate_q8_axisymmetric_torsion_herrmann_reduced_element( &
      X,u,p,mu,compliance,residual,tangent,status,min_j)
  call require(status == DES_STATUS_OK,'Q8 torsion Herrmann nonlinear state değerlendirilemedi')
  call require(abs(min_j-j_target) <= 8.0e-13_dp,'Q8 torsion constant-J state yanlış')
  call require(maxval(abs(residual(Q8_TORSION_HERRMANN_U_DOF+1:))) <= 5.0e-12_dp, &
      'Q8 torsion pressure compatibility residual sıfır değil')

  call pack_state(u,p,xlocal)
  do j = 1,Q8_TORSION_HERRMANN_TOTAL_DOF
    xp = xlocal
    xm = xlocal
    xp(j) = xp(j)+h
    xm(j) = xm(j)-h

    call unpack_state(xp,uw,pw)
    call evaluate_q8_axisymmetric_torsion_herrmann_reduced_element( &
        X,uw,pw,mu,compliance,rp,kd,sp,min_jd)
    call require(sp == DES_STATUS_OK,'Q8 torsion +FD perturbation başarısız')

    call unpack_state(xm,uw,pw)
    call evaluate_q8_axisymmetric_torsion_herrmann_reduced_element( &
        X,uw,pw,mu,compliance,rm,kd,sm,min_jd)
    call require(sm == DES_STATUS_OK,'Q8 torsion -FD perturbation başarısız')

    fd(:,j) = (rp-rm)/(2.0_dp*h)
  end do

  scale = max(1.0_dp,maxval(abs(fd)))
  fd_error = maxval(abs(tangent-fd))/scale
  symmetry_error = maxval(abs(tangent-transpose(tangent))) &
      / max(1.0_dp,maxval(abs(tangent)))
  call require(fd_error <= fd_tol,'Q8 torsion analytic tangent FD ile uyuşmuyor')
  call require(symmetry_error <= 5.0e-11_dp,'Q8 torsion tangent symmetry kaybetti')

  ! Fiziksel reaction-torque gate. Birim boylu kalın silindirde
  ! phi=alpha*Z için Neo-Hookean simple torsion sonucu:
  ! T = (pi/2)*mu*alpha*(Ro^4-Ri^4).
  u = 0.0_dp
  alpha = 0.01_dp
  do a = 1,8
    u(a,3) = alpha*X(a,2)
  end do
  p = 0.0_dp
  call evaluate_q8_axisymmetric_torsion_herrmann_reduced_element( &
      X,u,p,mu,0.0_dp,residual,tangent,status,min_j)
  call require(status == DES_STATUS_OK,'Reaction torque manufactured state çözülemedi')

  ! Üst Z=1 kenarı Q8 düğümleri: 3,4,7. Üçüncü DOF ROTY conjugate torque'tur.
  call reaction_torque_from_residual( &
      residual,top_torsion_equations,computed_torque,status)
  call require(status == DES_STATUS_OK,'Reaction torque results helper başarısız')

  expected_torque = 0.5_dp*pi*mu*alpha*(2.0_dp**4-1.0_dp**4)
  torque_rel_error = abs(computed_torque-expected_torque)/abs(expected_torque)
  call require(torque_rel_error <= 2.0e-11_dp, &
      'Q8 axisymmetric torsion reaction torque analitik değerle uyuşmuyor')

  call build_torsion_response_point(alpha,computed_torque,torsion_point,status)
  call require(status == DES_STATUS_OK,'Torque-angle response point üretilemedi')
  call require(abs(torsion_point%reaction_torque-computed_torque) <= 1.0e-14_dp, &
      'Torque-angle result reaction torque değerini değiştirdi')
  call require(abs(torsion_point%secant_torsional_stiffness-computed_torque/alpha) &
      <= 1.0e-12_dp, 'Torsional stiffness result yanlış')

  write(*,'(A,ES14.6)') 'Q8 torsion tangent FD error = ',fd_error
  write(*,'(A,ES14.6)') 'Q8 torsion symmetry error = ',symmetry_error
  write(*,'(A,ES14.6)') 'Q8 torsion reaction torque relative error = ',torque_rel_error
  write(*,'(A)') 'PASS: Q8/P1 axisymmetric torsion + torque-angle results contract'

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
    real(dp), intent(in) :: us(8,3),ps(3)
    real(dp), intent(out) :: x(Q8_TORSION_HERRMANN_TOTAL_DOF)
    integer :: node
    do node = 1,8
      x(3*node-2) = us(node,1)
      x(3*node-1) = us(node,2)
      x(3*node) = us(node,3)
    end do
    x(Q8_TORSION_HERRMANN_U_DOF+1:) = ps
  end subroutine pack_state

  subroutine unpack_state(x,us,ps)
    real(dp), intent(in) :: x(Q8_TORSION_HERRMANN_TOTAL_DOF)
    real(dp), intent(out) :: us(8,3),ps(3)
    integer :: node
    do node = 1,8
      us(node,1) = x(3*node-2)
      us(node,2) = x(3*node-1)
      us(node,3) = x(3*node)
    end do
    ps = x(Q8_TORSION_HERRMANN_U_DOF+1:)
  end subroutine unpack_state

  subroutine require(condition,message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) error stop message
  end subroutine require

end program test_q8_axisymmetric_torsion_herrmann_element
