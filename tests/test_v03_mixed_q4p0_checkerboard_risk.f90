program test_v03_mixed_q4p0_checkerboard_risk
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_material_types, only : neo_hookean_parameters_t
  use des_q4_plane_strain_mixed_up_mesh, only : &
      assemble_q4_plane_strain_mixed_up_mesh
  implicit none

  integer, parameter :: n = 4
  integer, parameter :: nnode = (n+1)*(n+1)
  integer, parameter :: nelem = n*n
  integer, parameter :: ndisp = 2*nnode
  integer, parameter :: ntotal = ndisp + nelem
  real(dp), parameter :: null_mode_tol = 1.0e-12_dp
  real(dp), parameter :: coupled_mode_floor = 1.0e-4_dp

  real(dp) :: X(nnode,2), u(nnode,2), pressure(nelem)
  integer :: connectivity(nelem,4)
  real(dp) :: residual(ntotal), tangent(ntotal,ntotal)
  real(dp) :: checkerboard(nelem), probe(nelem)
  real(dp) :: checker_force(ndisp), probe_force(ndisp)
  real(dp) :: b_norm_sq, checker_norm_sq, probe_norm_sq
  real(dp) :: checker_force_norm_sq, probe_force_norm_sq
  real(dp) :: checker_ratio, probe_ratio, min_j
  integer :: i, j, e, node, row_x, row_y, status
  type(neo_hookean_parameters_t) :: parameters

  call build_structured_mesh(X, connectivity)

  u = 0.0_dp
  pressure = 0.0_dp
  parameters%mu = 1.0_dp
  parameters%lambda = 1.0e8_dp

  call assemble_q4_plane_strain_mixed_up_mesh( &
      X, connectivity, u, pressure, parameters, residual, tangent, status, min_j)

  if (status /= DES_STATUS_OK) then
    error stop 'Q4/P0 checkerboard testi için mixed mesh assembly başarısız.'
  end if

  ! Structured 4x4 quadrilateral mesh üzerinde klasik mean-zero checkerboard
  ! pressure paterni. Sabit pressure gauge modundan farklı olarak bu modun
  ! ortalaması sıfırdır; dolayısıyla serbest displacement alanına kuplajının
  ! kaybolması ek bir pressure null mode olduğuna işaret eder.
  do j = 0,n-1
    do i = 0,n-1
      e = j*n + i + 1
      if (mod(i+j,2) == 0) then
        checkerboard(e) = 1.0_dp
      else
        checkerboard(e) = -1.0_dp
      end if
    end do
  end do

  if (abs(sum(checkerboard)) > 100.0_dp*epsilon(1.0_dp)) then
    error stop 'Checkerboard pressure modu mean-zero değil.'
  end if

  ! Kontrol modu: mean-zero fakat checkerboard olmayan bir pressure dağılımı.
  ! Bu modun serbest displacement DOF'larına belirgin biçimde kuple olması,
  ! ölçümün tüm pressure alanları için yapay olarak sıfır olmadığını doğrular.
  do e = 1,nelem
    probe(e) = real(e,dp) - 0.5_dp*real(nelem+1,dp)
  end do

  checker_force = 0.0_dp
  probe_force = 0.0_dp
  b_norm_sq = 0.0_dp
  checker_force_norm_sq = 0.0_dp
  probe_force_norm_sq = 0.0_dp

  ! Homojen Dirichlet sınır koşulunda admissible displacement alanı yalnız
  ! interior node DOF'larından oluşur. B = K_up bloğunun bu serbest satırlarını
  ! kullanarak pressure-to-displacement kuplajını ölçüyoruz.
  do j = 1,n-1
    do i = 1,n-1
      node = j*(n+1) + i + 1
      row_x = 2*(node-1) + 1
      row_y = row_x + 1

      checker_force(row_x) = dot_product( &
          tangent(row_x,ndisp+1:ntotal), checkerboard)
      checker_force(row_y) = dot_product( &
          tangent(row_y,ndisp+1:ntotal), checkerboard)
      probe_force(row_x) = dot_product( &
          tangent(row_x,ndisp+1:ntotal), probe)
      probe_force(row_y) = dot_product( &
          tangent(row_y,ndisp+1:ntotal), probe)

      checker_force_norm_sq = checker_force_norm_sq &
        + checker_force(row_x)**2 + checker_force(row_y)**2
      probe_force_norm_sq = probe_force_norm_sq &
        + probe_force(row_x)**2 + probe_force(row_y)**2

      b_norm_sq = b_norm_sq &
        + sum(tangent(row_x,ndisp+1:ntotal)**2) &
        + sum(tangent(row_y,ndisp+1:ntotal)**2)
    end do
  end do

  checker_norm_sq = sum(checkerboard**2)
  probe_norm_sq = sum(probe**2)

  if (b_norm_sq <= tiny(1.0_dp)) then
    error stop 'Mixed K_up serbest coupling bloğu beklenmedik biçimde sıfır.'
  end if

  checker_ratio = sqrt(checker_force_norm_sq) &
    / sqrt(b_norm_sq*checker_norm_sq)
  probe_ratio = sqrt(probe_force_norm_sq) &
    / sqrt(b_norm_sq*probe_norm_sq)

  if (checker_ratio > null_mode_tol) then
    write(*,'(A,ES14.6)') 'Checkerboard normalized coupling = ', checker_ratio
    error stop 'Beklenen Q4/P0 checkerboard null pressure modu doğrulanamadı.'
  end if

  if (probe_ratio < coupled_mode_floor) then
    write(*,'(A,ES14.6)') 'Probe normalized coupling = ', probe_ratio
    error stop 'Kontrol pressure modu yeterince displacement alanına kuple değil.'
  end if

  write(*,'(A,ES14.6)') 'Checkerboard normalized coupling = ', checker_ratio
  write(*,'(A,ES14.6)') 'Probe normalized coupling        = ', probe_ratio
  write(*,'(A)') 'Q4/P0 checkerboard risk testi BASARILI: mean-zero null pressure mode doğrulandı.'

contains

  subroutine build_structured_mesh(coords, conn)
    real(dp), intent(out) :: coords(nnode,2)
    integer, intent(out) :: conn(nelem,4)
    integer :: ix, iy, local_e, n1

    do iy = 0,n
      do ix = 0,n
        n1 = iy*(n+1) + ix + 1
        coords(n1,1) = real(ix,dp)/real(n,dp)
        coords(n1,2) = real(iy,dp)/real(n,dp)
      end do
    end do

    do iy = 0,n-1
      do ix = 0,n-1
        local_e = iy*n + ix + 1
        n1 = iy*(n+1) + ix + 1
        conn(local_e,:) = [n1, n1+1, n1+(n+1)+1, n1+(n+1)]
      end do
    end do
  end subroutine build_structured_mesh

end program test_v03_mixed_q4p0_checkerboard_risk
