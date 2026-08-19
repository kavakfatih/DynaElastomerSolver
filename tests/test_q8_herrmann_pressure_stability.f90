program test_q8_herrmann_pressure_stability
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_q8_herrmann_interpolation, only : herrmann_p1_pressure_basis
  use des_q8_herrmann_geometry, only : q8_reference_gradient
  implicit none

  integer, parameter :: nnode = 21, nelem = 4, ndof = 2*nnode, npdof = 3*nelem
  real(dp), parameter :: gp = 0.77459666924148337704_dp
  real(dp), parameter :: gauss_coordinate(3) = [-gp,0.0_dp,gp]
  real(dp), parameter :: gauss_weight(3) = [5.0_dp/9.0_dp,8.0_dp/9.0_dp,5.0_dp/9.0_dp]
  real(dp) :: X(nnode,2), B(npdof,ndof), Bfree(npdof,ndof)
  real(dp) :: N(8), dN_parent(8,2), dN_dX(8,2), Np(3)
  real(dp) :: x_point(2), Jmap(2,2), det_jac, weight
  real(dp) :: checker(npdof), coupling(ndof)
  real(dp) :: normalized_checker_coupling, b_norm, q_norm, c_norm
  integer :: conn(nelem,8), fixed_dofs(10)
  integer :: e,gx,gy,a,q,node,row,status,rank_value

  call set_structured_2x2_q8(X,conn)
  fixed_dofs = [1,2,11,12,17,18,27,28,33,34]

  B = 0.0_dp
  do e = 1,nelem
    do gy = 1,3
      do gx = 1,3
        call q8_reference_gradient( &
            X(conn(e,:),:),gauss_coordinate(gx),gauss_coordinate(gy), &
            N,dN_parent,dN_dX,x_point,Jmap,det_jac,status)
        if (status /= DES_STATUS_OK) then
          error stop 'Q8/P1 pressure stability mesh Jacobiani gecersiz.'
        end if
        call herrmann_p1_pressure_basis( &
            gauss_coordinate(gx),gauss_coordinate(gy),Np)
        weight = det_jac*gauss_weight(gx)*gauss_weight(gy)

        do q = 1,3
          row = 3*(e-1)+q
          do a = 1,8
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
    error stop 'Q8/P1 pressure coupling tam row rank degil; spurious pressure mode riski.'
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
    error stop 'Q8/P1 alternating pressure mode displacement alanindan zayif baglaniyor.'
  end if

  write(*,'(A,I0,A,I0)') 'Q8/P1 pressure coupling rank = ',rank_value,' / ',npdof
  write(*,'(A,ES14.6)') 'Q8/P1 normalized checkerboard coupling = ', &
      normalized_checker_coupling
  write(*,'(A)') 'Q8/P1 pressure rank ve checkerboard stability testi BASARILI.'

contains

  subroutine set_structured_2x2_q8(coords,connectivity)
    real(dp), intent(out) :: coords(nnode,2)
    integer, intent(out) :: connectivity(nelem,8)

    coords(1,:)  = [0.0_dp,0.0_dp]
    coords(2,:)  = [0.5_dp,0.0_dp]
    coords(3,:)  = [1.0_dp,0.0_dp]
    coords(4,:)  = [1.5_dp,0.0_dp]
    coords(5,:)  = [2.0_dp,0.0_dp]
    coords(6,:)  = [0.0_dp,0.5_dp]
    coords(7,:)  = [1.0_dp,0.5_dp]
    coords(8,:)  = [2.0_dp,0.5_dp]
    coords(9,:)  = [0.0_dp,1.0_dp]
    coords(10,:) = [0.5_dp,1.0_dp]
    coords(11,:) = [1.0_dp,1.0_dp]
    coords(12,:) = [1.5_dp,1.0_dp]
    coords(13,:) = [2.0_dp,1.0_dp]
    coords(14,:) = [0.0_dp,1.5_dp]
    coords(15,:) = [1.0_dp,1.5_dp]
    coords(16,:) = [2.0_dp,1.5_dp]
    coords(17,:) = [0.0_dp,2.0_dp]
    coords(18,:) = [0.5_dp,2.0_dp]
    coords(19,:) = [1.0_dp,2.0_dp]
    coords(20,:) = [1.5_dp,2.0_dp]
    coords(21,:) = [2.0_dp,2.0_dp]

    connectivity(1,:) = [1,3,11,9,2,7,10,6]
    connectivity(2,:) = [3,5,13,11,4,8,12,7]
    connectivity(3,:) = [9,11,19,17,10,15,18,14]
    connectivity(4,:) = [11,13,21,19,12,16,20,15]
  end subroutine set_structured_2x2_q8

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

end program test_q8_herrmann_pressure_stability
