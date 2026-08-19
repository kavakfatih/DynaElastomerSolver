program test_q8_herrmann_infsup_decay_diagnostic
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_herrmann_pressure_interpolation, only : herrmann_p1_pressure_basis
  use des_q8_herrmann_geometry, only : q8_reference_gradient
  use des_dense_linear, only : solve_dense_system
  implicit none

  integer, parameter :: ncases = 3
  integer, parameter :: mesh_size(ncases) = [2,3,4]
  real(dp) :: beta(ncases), refinement_ratio
  integer :: i

  do i = 1,ncases
    call evaluate_infsup_proxy(mesh_size(i),beta(i))
    write(*,'(A,I0,A,ES14.6)') 'Q8/P1 inf-sup diagnostic n=',mesh_size(i),' beta_h=',beta(i)
  end do

  refinement_ratio = beta(ncases)/beta(1)

  ! Bu test Q8/P1'i production icin kabul etmez. Tam tersine, mevcut
  ! serendipity-Q8 + element-internal P1 eslesmesinde mesh inceldikce gozlenen
  ! stability kaybini regression kaniti olarak korur. Formulation gelecekte
  ! iyilesirse bu tani testi bilincli olarak yeniden degerlendirilmelidir.
  if (.not. (beta(1) > beta(2) .and. beta(2) > beta(3))) then
    error stop 'Q8/P1 beklenen inf-sup azalma trendi yeniden degerlenmeli.'
  end if
  if (refinement_ratio >= 0.70_dp) then
    error stop 'Q8/P1 inf-sup tani davranisi degisti; formulation karari yeniden incelenmeli.'
  end if
  if (beta(3) >= 0.40_dp) then
    error stop 'Q8/P1 n=4 stability tanisi beklenen risk bolgesini gostermiyor.'
  end if

  write(*,'(A,ES14.6)') 'Q8/P1 beta(n=4)/beta(n=2) = ',refinement_ratio
  write(*,'(A)') 'Q8/P1 mesh-refinement inf-sup risk tanisi DOGRULANDI.'

contains

  subroutine evaluate_infsup_proxy(mesh_n,beta_h)
    integer, intent(in) :: mesh_n
    real(dp), intent(out) :: beta_h

    real(dp), parameter :: gp = 0.77459666924148337704_dp
    real(dp), parameter :: gauss_coordinate(3) = [-gp,0.0_dp,gp]
    real(dp), parameter :: gauss_weight(3) = [5.0_dp/9.0_dp,8.0_dp/9.0_dp,5.0_dp/9.0_dp]

    integer :: ngrid,nnode,nelem,ndof,npdof
    real(dp), allocatable :: X(:,:),Kdisp(:,:),Bcouple(:,:),Mp(:,:),response(:,:)
    real(dp), allocatable :: Schur(:,:),L(:,:),Y(:,:),Z(:,:),C(:,:)
    real(dp), allocatable :: rhs(:),solution(:),eigenvalues(:)
    integer, allocatable :: conn(:,:),node_map(:,:)
    real(dp) :: Nshape(8),dN_parent(8,2),dN_dX(8,2),Np(3)
    real(dp) :: x_point(2),Jmap(2,2),det_jac,weight,k_ab
    integer :: e,gx,gy,ia,ib,q,r,node_a,node_b,row,col,status,iy,dof
    logical :: ok

    ngrid = 2*mesh_n+1
    nnode = ngrid*ngrid-mesh_n*mesh_n
    nelem = mesh_n*mesh_n
    ndof = 2*nnode
    npdof = 3*nelem

    allocate(X(nnode,2),conn(nelem,8),node_map(0:2*mesh_n,0:2*mesh_n))
    allocate(Kdisp(ndof,ndof),Bcouple(npdof,ndof),Mp(npdof,npdof))
    allocate(response(ndof,npdof),Schur(npdof,npdof))
    allocate(L(npdof,npdof),Y(npdof,npdof),Z(npdof,npdof),C(npdof,npdof))
    allocate(rhs(ndof),solution(ndof),eigenvalues(npdof))

    call build_structured_q8_mesh(mesh_n,X,conn,node_map)
    Kdisp = 0.0_dp
    Bcouple = 0.0_dp
    Mp = 0.0_dp

    do e = 1,nelem
      do gy = 1,3
        do gx = 1,3
          call q8_reference_gradient( &
              X(conn(e,:),:),gauss_coordinate(gx),gauss_coordinate(gy), &
              Nshape,dN_parent,dN_dX,x_point,Jmap,det_jac,status)
          if (status /= DES_STATUS_OK) then
            error stop 'Q8/P1 inf-sup diagnostic mesh Jacobiani gecersiz.'
          end if

          call herrmann_p1_pressure_basis( &
              gauss_coordinate(gx),gauss_coordinate(gy),Np)
          weight = det_jac*gauss_weight(gx)*gauss_weight(gy)

          do ia = 1,8
            node_a = conn(e,ia)
            do ib = 1,8
              node_b = conn(e,ib)
              k_ab = dot_product(dN_dX(ia,:),dN_dX(ib,:))*weight
              Kdisp(2*node_a-1,2*node_b-1) = Kdisp(2*node_a-1,2*node_b-1)+k_ab
              Kdisp(2*node_a,2*node_b) = Kdisp(2*node_a,2*node_b)+k_ab
            end do

            do q = 1,3
              row = 3*(e-1)+q
              Bcouple(row,2*node_a-1) = Bcouple(row,2*node_a-1) &
                  - Np(q)*dN_dX(ia,1)*weight
              Bcouple(row,2*node_a) = Bcouple(row,2*node_a) &
                  - Np(q)*dN_dX(ia,2)*weight
            end do
          end do

          do q = 1,3
            row = 3*(e-1)+q
            do r = 1,3
              col = 3*(e-1)+r
              Mp(row,col) = Mp(row,col)+Np(q)*Np(r)*weight
            end do
          end do
        end do
      end do
    end do

    ! Sol sinirda mevcut tum Q8 dugumlerinin iki displacement component'i sabitlenir.
    do iy = 0,2*mesh_n
      node_a = node_map(0,iy)
      do dof = 2*node_a-1,2*node_a
        Bcouple(:,dof) = 0.0_dp
        Kdisp(dof,:) = 0.0_dp
        Kdisp(:,dof) = 0.0_dp
        Kdisp(dof,dof) = 1.0_dp
      end do
    end do

    do q = 1,npdof
      rhs = Bcouple(q,:)
      call solve_dense_system(Kdisp,rhs,solution,ok)
      if (.not. ok) then
        error stop 'Q8/P1 inf-sup diagnostic displacement norm sistemi cozulmedi.'
      end if
      response(:,q) = solution
    end do

    Schur = matmul(Bcouple,response)
    Schur = 0.5_dp*(Schur+transpose(Schur))

    call cholesky_lower(Mp,L,ok)
    if (.not. ok) error stop 'Q8/P1 pressure mass matrisi pozitif tanimli degil.'

    do col = 1,npdof
      call forward_solve(L,Schur(:,col),Y(:,col))
    end do
    do row = 1,npdof
      call forward_solve(L,Y(row,:),Z(:,row))
    end do
    C = transpose(Z)
    C = 0.5_dp*(C+transpose(C))

    call symmetric_jacobi_eigenvalues(C,eigenvalues,ok)
    if (.not. ok) error stop 'Q8/P1 inf-sup eigenvalue iterasyonu yakinsamadi.'
    if (minval(eigenvalues) <= 1.0e-12_dp) then
      error stop 'Q8/P1 pressure space beklenmedik sifir/null eigenvalue uretti.'
    end if

    beta_h = sqrt(minval(eigenvalues))
  end subroutine evaluate_infsup_proxy

  subroutine build_structured_q8_mesh(n,coords,connectivity,node_map)
    integer, intent(in) :: n
    real(dp), intent(out) :: coords(:,:)
    integer, intent(out) :: connectivity(:,:),node_map(0:,0:)
    integer :: ix,iy,ex,ey,e,i0,j0,node
    real(dp) :: scale

    scale = 1.0_dp/real(2*n,dp)
    node_map = -1
    node = 0
    do iy = 0,2*n
      do ix = 0,2*n
        ! Q8 serendipity meshte element merkezleri displacement dugumu degildir.
        if (mod(ix,2) == 1 .and. mod(iy,2) == 1) cycle
        node = node+1
        node_map(ix,iy) = node
        coords(node,:) = [scale*real(ix,dp),scale*real(iy,dp)]
      end do
    end do

    e = 0
    do ey = 0,n-1
      do ex = 0,n-1
        e = e+1
        i0 = 2*ex
        j0 = 2*ey
        connectivity(e,1) = node_map(i0,  j0)
        connectivity(e,2) = node_map(i0+2,j0)
        connectivity(e,3) = node_map(i0+2,j0+2)
        connectivity(e,4) = node_map(i0,  j0+2)
        connectivity(e,5) = node_map(i0+1,j0)
        connectivity(e,6) = node_map(i0+2,j0+1)
        connectivity(e,7) = node_map(i0+1,j0+2)
        connectivity(e,8) = node_map(i0,  j0+1)
      end do
    end do
  end subroutine build_structured_q8_mesh

  subroutine cholesky_lower(A,L,ok)
    real(dp), intent(in) :: A(:,:)
    real(dp), intent(out) :: L(:,:)
    logical, intent(out) :: ok
    real(dp) :: value
    integer :: i,j,k,n

    n = size(A,1)
    L = 0.0_dp
    ok = .true.
    do i = 1,n
      do j = 1,i
        value = A(i,j)
        do k = 1,j-1
          value = value-L(i,k)*L(j,k)
        end do
        if (i == j) then
          if (value <= 100.0_dp*epsilon(1.0_dp)) then
            ok = .false.
            return
          end if
          L(i,j) = sqrt(value)
        else
          L(i,j) = value/L(j,j)
        end if
      end do
    end do
  end subroutine cholesky_lower

  subroutine forward_solve(L,b,x)
    real(dp), intent(in) :: L(:,:),b(:)
    real(dp), intent(out) :: x(:)
    real(dp) :: value
    integer :: i,k,n

    n = size(b)
    do i = 1,n
      value = b(i)
      do k = 1,i-1
        value = value-L(i,k)*x(k)
      end do
      x(i) = value/L(i,i)
    end do
  end subroutine forward_solve

  subroutine symmetric_jacobi_eigenvalues(A,eigenvalues,ok)
    real(dp), intent(inout) :: A(:,:)
    real(dp), intent(out) :: eigenvalues(:)
    logical, intent(out) :: ok
    real(dp), parameter :: tol = 2.0e-12_dp
    real(dp) :: app,aqq,apq,tau,t,c,s,akp,akq,max_off,diag_scale
    integer :: sweep,p,q,k,n

    n = size(A,1)
    ok = .false.
    do sweep = 1,80
      max_off = 0.0_dp
      do p = 1,n-1
        do q = p+1,n
          apq = A(p,q)
          max_off = max(max_off,abs(apq))
          if (abs(apq) <= tol) cycle

          app = A(p,p)
          aqq = A(q,q)
          tau = (aqq-app)/(2.0_dp*apq)
          if (abs(tau) <= epsilon(1.0_dp)) then
            t = 1.0_dp
          else
            t = sign(1.0_dp,tau)/(abs(tau)+sqrt(1.0_dp+tau*tau))
          end if
          c = 1.0_dp/sqrt(1.0_dp+t*t)
          s = t*c

          do k = 1,n
            if (k == p .or. k == q) cycle
            akp = A(k,p)
            akq = A(k,q)
            A(k,p) = c*akp-s*akq
            A(p,k) = A(k,p)
            A(k,q) = s*akp+c*akq
            A(q,k) = A(k,q)
          end do

          A(p,p) = c*c*app-2.0_dp*s*c*apq+s*s*aqq
          A(q,q) = s*s*app+2.0_dp*s*c*apq+c*c*aqq
          A(p,q) = 0.0_dp
          A(q,p) = 0.0_dp
        end do
      end do

      diag_scale = max(1.0_dp,maxval(abs([(A(k,k),k=1,n)])))
      if (max_off <= tol*diag_scale) then
        ok = .true.
        exit
      end if
    end do

    do k = 1,n
      eigenvalues(k) = A(k,k)
    end do
  end subroutine symmetric_jacobi_eigenvalues

end program test_q8_herrmann_infsup_decay_diagnostic
