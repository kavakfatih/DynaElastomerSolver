program test_v03_mixed_pressure_uniformity
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_material_types, only : neo_hookean_parameters_t
  use des_q4_plane_strain_mixed_up_mesh, only : &
      assemble_q4_plane_strain_mixed_up_mesh
  use des_pressure_diagnostics, only : pressure_diagnostics_t, &
                                       evaluate_q4_pressure_diagnostics
  implicit none

  integer, parameter :: nnode = 9, nelem = 4
  integer, parameter :: ndisp = 2*nnode, ntotal = ndisp + nelem
  real(dp), parameter :: tol = 2.0e-11_dp
  real(dp) :: X(nnode,2), u(nnode,2), pressure(nelem)
  integer :: connectivity(nelem,4)
  real(dp) :: residual(ntotal), tangent(ntotal,ntotal), min_j
  real(dp) :: F2(2,2), det_f, exact_pressure
  integer :: node, status
  type(neo_hookean_parameters_t) :: parameters
  type(pressure_diagnostics_t) :: diagnostics

  ! Düzenli 2x2 Q4 mesh: 3x3 node.
  X(1,:) = [0.0_dp,0.0_dp]
  X(2,:) = [1.0_dp,0.0_dp]
  X(3,:) = [2.0_dp,0.0_dp]
  X(4,:) = [0.0_dp,1.0_dp]
  X(5,:) = [1.0_dp,1.0_dp]
  X(6,:) = [2.0_dp,1.0_dp]
  X(7,:) = [0.0_dp,2.0_dp]
  X(8,:) = [1.0_dp,2.0_dp]
  X(9,:) = [2.0_dp,2.0_dp]

  connectivity(1,:) = [1,2,5,4]
  connectivity(2,:) = [2,3,6,5]
  connectivity(3,:) = [4,5,8,7]
  connectivity(4,:) = [5,6,9,8]

  parameters%mu = 2.3_dp
  parameters%lambda = 19.0_dp

  ! Exact homojen affine deformasyon. Q4 bu alanı tam temsil eder.
  F2(1,:) = [1.10_dp,0.08_dp]
  F2(2,:) = [0.03_dp,0.94_dp]
  det_f = F2(1,1)*F2(2,2) - F2(1,2)*F2(2,1)
  exact_pressure = parameters%lambda*log(det_f)

  do node = 1,nnode
    u(node,1) = (F2(1,1)-1.0_dp)*X(node,1) + F2(1,2)*X(node,2)
    u(node,2) = F2(2,1)*X(node,1) + (F2(2,2)-1.0_dp)*X(node,2)
  end do
  pressure = exact_pressure

  call assemble_q4_plane_strain_mixed_up_mesh( &
      X,connectivity,u,pressure,parameters,residual,tangent,status,min_j)
  if (status /= DES_STATUS_OK) then
    error stop 'Homojen mixed pressure benchmark assembly başarısız.'
  end if

  ! R_p = integral[ln(J)-p/lambda] dV0 olduğundan exact sabit pressure ile
  ! bütün element pressure residual'ları sıfır olmalıdır.
  if (maxval(abs(residual(ndisp+1:ntotal))) > tol) then
    write(*,'(A,ES14.6)') 'Maksimum pressure residual = ', &
      maxval(abs(residual(ndisp+1:ntotal)))
    error stop 'Homojen mixed pressure stationarity sağlanmadı.'
  end if

  if (abs(min_j-det_f) > tol) then
    write(*,'(A,ES14.6)') 'min J farkı = ',abs(min_j-det_f)
    error stop 'Homojen mixed benchmark J değeri exact referansla uyuşmuyor.'
  end if

  call evaluate_q4_pressure_diagnostics( &
      connectivity,pressure,diagnostics,status)
  if (status /= DES_STATUS_OK .or. .not. diagnostics%valid) then
    error stop 'Homojen pressure diagnostics başarısız.'
  end if

  if (abs(diagnostics%mean-exact_pressure) > tol) then
    error stop 'Homojen pressure ortalaması exact değerden farklı.'
  end if
  if (diagnostics%neighbor_pair_count /= 4) then
    error stop 'Homojen 2x2 mesh pressure komşuluk sayısı hatalı.'
  end if
  if (abs(diagnostics%standard_deviation) > tol) then
    error stop 'Homojen pressure standard deviation sıfır değil.'
  end if
  if (abs(diagnostics%neighbor_jump_rms) > tol .or. &
      abs(diagnostics%maximum_neighbor_jump) > tol .or. &
      abs(diagnostics%normalized_neighbor_jump_rms) > tol .or. &
      abs(diagnostics%neighbor_jump_to_std) > tol .or. &
      abs(diagnostics%graph_roughness) > tol) then
    error stop 'Homojen pressure alanı sıfır roughness üretmedi.'
  end if

  write(*,'(A,ES14.6)') 'Exact J = ',det_f
  write(*,'(A,ES14.6)') 'Exact pressure = ',exact_pressure
  write(*,'(A,ES14.6)') 'Maximum pressure residual = ', &
    maxval(abs(residual(ndisp+1:ntotal)))
  write(*,'(A,ES14.6)') 'Pressure graph roughness = ',diagnostics%graph_roughness
  write(*,'(A)') 'V0.3 mixed homojen pressure uniformity benchmark BASARILI.'
end program test_v03_mixed_pressure_uniformity
