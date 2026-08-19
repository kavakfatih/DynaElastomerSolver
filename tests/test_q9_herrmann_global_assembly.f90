program test_q9_herrmann_global_assembly
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_q9_plane_strain_herrmann_neo_hookean, only : Q9_HERRMANN_QUADRATURE_3X3
  use des_q9_plane_strain_herrmann_mesh, only : &
      assemble_q9_plane_strain_herrmann_mesh, &
      assemble_q9_plane_strain_herrmann_mesh_with_quadrature
  implicit none

  integer, parameter :: nnode = 15, nelem = 2
  integer, parameter :: ndisp = 2*nnode, npres = 3*nelem, ntotal = ndisp+npres
  real(dp), parameter :: mu = 2.5_dp, compliance = 0.02_dp, h = 1.0e-7_dp
  real(dp), parameter :: fd_tol = 9.0e-6_dp
  real(dp) :: X(nnode,2), u(nnode,2), p(nelem,3)
  integer :: conn(nelem,9)
  real(dp) :: residual(ntotal), tangent(ntotal,ntotal)
  real(dp) :: residual_default(ntotal), tangent_default(ntotal,ntotal)
  real(dp) :: fd(ntotal,ntotal), rplus(ntotal), rminus(ntotal)
  real(dp) :: dummy(ntotal,ntotal), xstate(ntotal), xplus(ntotal), xminus(ntotal)
  real(dp) :: work_u(nnode,2), work_p(nelem,3)
  real(dp) :: min_j, min_j_default, min_j_dummy
  real(dp) :: fd_error, symmetry_error, scale, cross_pressure_max
  integer :: status, status_default, status_plus, status_minus
  integer :: node, j, p1_start, p1_end, p2_start, p2_end

  call build_two_element_q9_mesh(X,conn)

  do node = 1,nnode
    u(node,1) = 0.04_dp*X(node,1) + 0.03_dp*X(node,2) &
        + 0.012_dp*X(node,1)*X(node,2) + 0.008_dp*X(node,1)*X(node,1)
    u(node,2) = -0.015_dp*X(node,1) + 0.035_dp*X(node,2) &
        - 0.009_dp*X(node,1)*X(node,2) + 0.006_dp*X(node,2)*X(node,2)
  end do
  p(1,:) = [0.16_dp, 0.030_dp,-0.020_dp]
  p(2,:) = [0.12_dp,-0.025_dp, 0.018_dp]

  call assemble_q9_plane_strain_herrmann_mesh_with_quadrature( &
      X,conn,u,p,mu,compliance,Q9_HERRMANN_QUADRATURE_3X3, &
      residual,tangent,status,min_j)
  if (status /= DES_STATUS_OK) then
    error stop 'Q9/P1 global mixed assembly basarisiz.'
  end if
  if (min_j <= 0.85_dp) then
    error stop 'Q9/P1 global assembly testi gecersiz deformation uretti.'
  end if

  call assemble_q9_plane_strain_herrmann_mesh( &
      X,conn,u,p,mu,compliance,residual_default,tangent_default,status_default,min_j_default)
  if (status_default /= DES_STATUS_OK) then
    error stop 'Q9/P1 varsayilan global assembly basarisiz.'
  end if
  if (maxval(abs(residual_default-residual)) > 5.0e-13_dp .or. &
      maxval(abs(tangent_default-tangent)) > 5.0e-13_dp .or. &
      abs(min_j_default-min_j) > 5.0e-14_dp) then
    error stop 'Q9/P1 varsayilan global assembly 3x3 baseline ile uyusmuyor.'
  end if

  call pack_state(u,p,xstate)
  do j = 1,ntotal
    xplus = xstate
    xminus = xstate
    xplus(j) = xplus(j)+h
    xminus(j) = xminus(j)-h

    call unpack_state(xplus,work_u,work_p)
    call assemble_q9_plane_strain_herrmann_mesh_with_quadrature( &
        X,conn,work_u,work_p,mu,compliance,Q9_HERRMANN_QUADRATURE_3X3, &
        rplus,dummy,status_plus,min_j_dummy)
    if (status_plus /= DES_STATUS_OK) then
      error stop 'Q9/P1 global assembly pozitif FD perturbation basarisiz.'
    end if

    call unpack_state(xminus,work_u,work_p)
    call assemble_q9_plane_strain_herrmann_mesh_with_quadrature( &
        X,conn,work_u,work_p,mu,compliance,Q9_HERRMANN_QUADRATURE_3X3, &
        rminus,dummy,status_minus,min_j_dummy)
    if (status_minus /= DES_STATUS_OK) then
      error stop 'Q9/P1 global assembly negatif FD perturbation basarisiz.'
    end if

    fd(:,j) = (rplus-rminus)/(2.0_dp*h)
  end do

  scale = max(1.0_dp,maxval(abs(fd)))
  fd_error = maxval(abs(tangent-fd))/scale
  if (fd_error > fd_tol) then
    error stop 'Q9/P1 global mixed tangent merkezi FD ile uyusmuyor.'
  end if

  symmetry_error = maxval(abs(tangent-transpose(tangent))) &
      / max(1.0_dp,maxval(abs(tangent)))
  if (symmetry_error > 3.0e-11_dp) then
    error stop 'Q9/P1 global mixed tangent symmetry kaybetti.'
  end if

  ! Element-internal pressure unknown'lari birbirinden bagimsizdir. Farkli
  ! elementlerin pressure-pressure bloklari dogrudan coupling tasimamalidir.
  p1_start = ndisp+1
  p1_end = ndisp+3
  p2_start = ndisp+4
  p2_end = ndisp+6
  cross_pressure_max = maxval(abs(tangent(p1_start:p1_end,p2_start:p2_end)))
  cross_pressure_max = max(cross_pressure_max, &
      maxval(abs(tangent(p2_start:p2_end,p1_start:p1_end))))
  if (cross_pressure_max > 1.0e-14_dp) then
    error stop 'Q9/P1 farkli element pressure bloklari dogrudan coupling tasiyor.'
  end if

  write(*,'(A,I0)') 'Q9/P1 global displacement DOF = ',ndisp
  write(*,'(A,I0)') 'Q9/P1 global independent pressure DOF = ',npres
  write(*,'(A,I0)') 'Q9/P1 global total equation = ',ntotal
  write(*,'(A,ES14.6)') 'Q9/P1 global tangent FD error = ',fd_error
  write(*,'(A,ES14.6)') 'Q9/P1 global tangent symmetry error = ',symmetry_error
  write(*,'(A)') 'Q9/P1 global mixed assembly testi BASARILI.'

contains

  subroutine build_two_element_q9_mesh(coords,connectivity)
    real(dp), intent(out) :: coords(nnode,2)
    integer, intent(out) :: connectivity(nelem,9)
    integer :: ix,iy,id

    id = 0
    do iy = 0,2
      do ix = 0,4
        id = id+1
        coords(id,:) = [0.5_dp*real(ix,dp),0.5_dp*real(iy,dp)]
      end do
    end do

    connectivity(1,:) = [1,3,13,11,2,8,12,6,7]
    connectivity(2,:) = [3,5,15,13,4,10,14,8,9]
  end subroutine build_two_element_q9_mesh

  subroutine pack_state(u_state,p_state,x)
    real(dp), intent(in) :: u_state(nnode,2),p_state(nelem,3)
    real(dp), intent(out) :: x(ntotal)
    integer :: a,e,q,cursor

    do a = 1,nnode
      x(2*a-1) = u_state(a,1)
      x(2*a) = u_state(a,2)
    end do

    cursor = ndisp
    do e = 1,nelem
      do q = 1,3
        cursor = cursor+1
        x(cursor) = p_state(e,q)
      end do
    end do
  end subroutine pack_state

  subroutine unpack_state(x,u_state,p_state)
    real(dp), intent(in) :: x(ntotal)
    real(dp), intent(out) :: u_state(nnode,2),p_state(nelem,3)
    integer :: a,e,q,cursor

    do a = 1,nnode
      u_state(a,1) = x(2*a-1)
      u_state(a,2) = x(2*a)
    end do

    cursor = ndisp
    do e = 1,nelem
      do q = 1,3
        cursor = cursor+1
        p_state(e,q) = x(cursor)
      end do
    end do
  end subroutine unpack_state

end program test_q9_herrmann_global_assembly
