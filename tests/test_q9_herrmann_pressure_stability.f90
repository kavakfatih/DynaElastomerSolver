program test_q9_herrmann_pressure_stability
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_herrmann_pressure_interpolation, only : herrmann_p1_pressure_basis
  use des_q9_herrmann_geometry, only : q9_reference_gradient
  implicit none

  integer, parameter :: nnode = 25, nelem = 4, ndof = 2*nnode, npdof = 3*nelem
  real(dp), parameter :: gp = 0.77459666924148337704_dp
  real(dp), parameter :: gauss_coordinate(3) = [-gp,0.0_dp,gp]
  real(dp), parameter :: gauss_weight(3) = [5.0_dp/9.0_dp,8.0_dp/9.0_dp,5.0_dp/9.0_dp]
  real(dp) :: X(nnode,2), B(npdof,ndof), Bfree(npdof,ndof)
  real(dp) :: N(9), dN_parent(9,2), dN_dX(9,2), Np(3)
  real(dp) :: x_point(2), Jmap(2,2), det_jac, weight
  real(dp) :: checker(npdof), coupling(ndof)
  real(dp) :: normalized_checker_coupling, b_norm, q_norm, c_norm
  integer :: conn(nelem,9), fixed_dofs(10)
  integer :: e,gx,gy,a,q,node,row,status,rank_value

  call set_structured_2x2_q9(X,conn)
  fixed_dofs = [1,2,11,12,21,22,31,32,41,42]

  B = 0.0_dp
  do e = 1,nelem
    do gy = 1,3
      do gx = 1,3
        call q9_reference_gradient( &
            X(conn(e,:),:),gauss_coordinate(gx),gauss_coordinate(gy), &
            N,dN_parent,dN_dX,x_point,Jmap,det_jac,status)
        if (status /= DES_STATUS_OK) then
          error stop 'Q9/P1 pressure stability mesh Jacobiani gecersiz.'
        end if

        call herrmann_p1_pressure_basis( &
            gauss_coordinate(gx),gauss_coordinate(gy),Np)
        weight = det_jac*gauss_weight(gx)*gauss_weight(gy)

        do q = 1,3
          row = 3*(e-1)+q
          do a = 1,9
            node = conn(e,a)
            B(row,2*node-1) = B(row,2*node-1) &
                - Np(q)*dN_dX(a,1)*weight
            B(row,2*node) = B(row,2*node) &
                - Np(q)*dN_dX(a,2)*weight
          end do
        end do
      end do
    end do
  end do

  Bfree = B
  do a = 1,size(fixed_dofs)
    Bfree(:,fixed_dofs(a)) = 0.0_dp
  end do

  rank_value = numerical_row_rank(Bfree,1.0e-11_dp)
  if (rank_value /= npdof) then
    error stop 'Q9/P1 pressure coupling tam row rank degil.'
  end if

  checker = 0.0_dp
  checker(1)  =  1.0_dp
  checker(4)  = -1.0_dp
  checker(7)  = -1.0_dp
  checker(10) =  1.0_dp

  coupling = matmul(transpose(Bfree),checker)
  b_norm = sqrt(sum(Bfree*Bfree))
  q_norm = sqrt(sum(checker*checker))
  c_norm = sqrt(sum(coupling*coupling))
  normalized_checker_coupling = c_norm/(b_norm*q_norm)

  if (normalized_checker_coupling < 0.20_dp) then
    error stop 'Q9/P1 alternating pressure mode displacement alanindan zayif baglaniyor.'
  end if

  write(*,'(A,I0,A,I0)') 'Q9/P1 pressure coupling rank = ',rank_value,' / ',npdof
  write(*,'(A,ES14.6)') 'Q9/P1 normalized checkerboard coupling = ', &
      normalized_checker_coupling
  write(*,'(A)') 'Q9/P1 pressure rank ve checkerboard stability testi BASARILI.'

contains

  subroutine set_structured_2x2_q9(coords,connectivity)
    real(dp), intent(out) :: coords(nnode,2)
    integer, intent(out) :: connectivity(nelem,9)
    integer :: ix,iy,node

    node = 0
    do iy = 0,4
      do ix = 0,4
        node = node+1
        coords(node,:) = [0.5_dp*real(ix,dp),0.5_dp*real(iy,dp)]
      end do
    end do

    connectivity(1,:) = [1,3,13,11,2,8,12,6,7]
    connectivity(2,:) = [3,5,15,13,4,10,14,8,9]
    connectivity(3,:) = [11,13,23,21,12,18,22,16,17]
    connectivity(4,:) = [13,15,25,23,14,20,24,18,19]
  end subroutine set_structured_2x2_q9

  function numerical_row_rank(matrix,tolerance) result(rank_value)
    real(dp), intent(in) :: matrix(:,:),tolerance
    integer :: rank_value
    real(dp), allocatable :: work(:,:)
    real(dp) :: pivot_value, factor, scale
    integer :: row,col,pivot_row,r,m,n

    work = matrix
    m = size(work,1)
    n = size(work,2)
    rank_value = 0
    row = 1
    scale = max(1.0_dp,maxval(abs(work)))

    do col = 1,n
      if (row > m) exit
      pivot_row = row
      do r = row+1,m
        if (abs(work(r,col)) > abs(work(pivot_row,col))) pivot_row = r
      end do
      pivot_value = work(pivot_row,col)
      if (abs(pivot_value) <= tolerance*scale) cycle

      if (pivot_row /= row) call swap_rows(work,pivot_row,row)
      pivot_value = work(row,col)
      do r = row+1,m
        factor = work(r,col)/pivot_value
        work(r,col:n) = work(r,col:n)-factor*work(row,col:n)
      end do
      rank_value = rank_value+1
      row = row+1
    end do
  end function numerical_row_rank

  subroutine swap_rows(matrix,row_a,row_b)
    real(dp), intent(inout) :: matrix(:,:)
    integer, intent(in) :: row_a,row_b
    real(dp) :: temp(size(matrix,2))

    temp = matrix(row_a,:)
    matrix(row_a,:) = matrix(row_b,:)
    matrix(row_b,:) = temp
  end subroutine swap_rows

end program test_q9_herrmann_pressure_stability
