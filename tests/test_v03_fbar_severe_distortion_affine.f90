program test_v03_fbar_severe_distortion_affine
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_material_types, only : neo_hookean_parameters_t
  use des_internal_mesh, only : internal_mesh_t, initialize_q4_internal_mesh
  use des_q4_shape, only : q4_shape_functions
  use des_q4_edge_traction, only : Q4_EDGE_BOTTOM, Q4_EDGE_RIGHT, &
                                   Q4_EDGE_TOP, Q4_EDGE_LEFT
  use des_q4_mesh_edge_traction, only : add_q4_reference_edge_traction
  use des_q4_plane_strain_fbar_mesh, only : assemble_q4_plane_strain_fbar_mesh
  use des_q4_plane_strain_fbar_force_solver, only : &
      solve_q4_plane_strain_fbar_force_control
  use des_q4_plane_strain_newton_solver, only : newton_report_t
  implicit none

  real(dp), parameter :: displacement_tol = 2.0e-7_dp
  real(dp), parameter :: exact_equilibrium_tol = 5.0e-10_dp
  real(dp), parameter :: final_residual_tol = 5.0e-9_dp
  real(dp), parameter :: j_tol = 5.0e-10_dp
  integer, parameter :: fixed_dofs(3) = [1,2,4]

  real(dp) :: X(9,2), u(9,2), expected_u(9,2)
  real(dp) :: external_force(18), internal_force(18), residual(18)
  real(dp) :: tangent(18,18), H(2,2), F(3,3), P(3,3)
  real(dp) :: traction_left(2), traction_right(2)
  real(dp) :: traction_bottom(2), traction_top(2)
  real(dp) :: J, min_j, min_j_bar, max_j_bar
  real(dp) :: weight_ratio, min_weight, max_weight, total_area
  real(dp) :: exact_free_residual, displacement_error
  integer :: connectivity(4,4), status, node
  type(neo_hookean_parameters_t) :: parameters
  type(internal_mesh_t) :: mesh
  type(newton_report_t) :: report

  ! V0.2 severe-distortion benchmarkıyla aynı 2x2 Q4 geometri.
  ! Merkez düğüm kasıtlı olarak sağ-alt yöne taşınmıştır.
  X(1,:) = [0.0_dp,0.0_dp]
  X(2,:) = [1.0_dp,0.0_dp]
  X(3,:) = [2.0_dp,0.0_dp]
  X(4,:) = [0.0_dp,1.0_dp]
  X(5,:) = [1.45_dp,0.55_dp]
  X(6,:) = [2.0_dp,1.0_dp]
  X(7,:) = [0.0_dp,2.0_dp]
  X(8,:) = [1.0_dp,2.0_dp]
  X(9,:) = [2.0_dp,2.0_dp]

  connectivity(1,:) = [1,2,5,4]
  connectivity(2,:) = [2,3,6,5]
  connectivity(3,:) = [4,5,8,7]
  connectivity(4,:) = [5,6,9,8]

  call initialize_q4_internal_mesh(mesh,X,connectivity,status)
  if (status /= DES_STATUS_OK) then
    error stop 'F-bar severe-distortion mesh oluşturulamadı.'
  end if

  call reference_distortion_metrics( &
      X,connectivity,min_weight,max_weight,weight_ratio,total_area)

  if (min_weight <= 0.05_dp) then
    error stop 'F-bar distortion benchmarkında reference Jacobian fazla küçük/geçersiz.'
  end if
  if (weight_ratio >= 0.20_dp) then
    error stop 'F-bar benchmark geometrisi hedeflenen severe-distortion seviyesine ulaşmadı.'
  end if
  if (abs(total_area-4.0_dp) > 5.0e-12_dp) then
    error stop 'F-bar distortion mesh toplam referans alanını korumadı.'
  end if

  ! Büyük fakat tam isochoric affine finite-strain alanı:
  ! F11*F22-F12*F21 = 1.0. Böylece nearly-incompressible lambda=1000
  ! altında volumetric stress patlamadan geometri/assembly/Newton yolu sınanır.
  H = 0.0_dp
  H(1,1) = 0.20_dp
  H(1,2) = 0.25_dp
  H(2,1) = 0.00_dp
  H(2,2) = -1.0_dp/6.0_dp

  F = 0.0_dp
  F(1,1) = 1.0_dp + H(1,1)
  F(1,2) = H(1,2)
  F(2,1) = H(2,1)
  F(2,2) = 1.0_dp + H(2,2)
  F(3,3) = 1.0_dp

  parameters%mu = 2.7_dp
  parameters%lambda = 1000.0_dp

  call neo_hookean_closed_form(F,parameters%mu,parameters%lambda,P,J)
  if (abs(J-1.0_dp) > 5.0e-14_dp) then
    error stop 'F-bar severe-distortion hedef deformation tam isochoric değil.'
  end if

  do node = 1,9
    expected_u(node,1) = H(1,1)*X(node,1) + H(1,2)*X(node,2)
    expected_u(node,2) = H(2,1)*X(node,1) + H(2,2)*X(node,2)
  end do

  ! Rijit hareketleri kaldırmak için solver yalnız dof 1,2,4'ü sıfıra sabitler.
  ! Seçilen affine alan bu DOF'larda zaten tam sıfırdır.
  if (maxval(abs([expected_u(1,1),expected_u(1,2),expected_u(2,2)])) &
      > 100.0_dp*epsilon(1.0_dp)) then
    error stop 'Affine referans seçilen zero-constraint DOF'larla uyumsuz.'
  end if

  ! Kapalı-form first Piola stress'ten nominal boundary traction: t0 = P*N0.
  traction_left   = -P(1:2,1)
  traction_right  =  P(1:2,1)
  traction_bottom = -P(1:2,2)
  traction_top    =  P(1:2,2)

  external_force = 0.0_dp
  call add_boundary_edge(mesh,1,Q4_EDGE_BOTTOM,traction_bottom,external_force)
  call add_boundary_edge(mesh,2,Q4_EDGE_BOTTOM,traction_bottom,external_force)
  call add_boundary_edge(mesh,2,Q4_EDGE_RIGHT, traction_right, external_force)
  call add_boundary_edge(mesh,4,Q4_EDGE_RIGHT, traction_right, external_force)
  call add_boundary_edge(mesh,3,Q4_EDGE_TOP,   traction_top,   external_force)
  call add_boundary_edge(mesh,4,Q4_EDGE_TOP,   traction_top,   external_force)
  call add_boundary_edge(mesh,1,Q4_EDGE_LEFT,  traction_left,  external_force)
  call add_boundary_edge(mesh,3,Q4_EDGE_LEFT,  traction_left,  external_force)

  if (abs(sum(external_force(1:18:2))) > 5.0e-12_dp .or. &
      abs(sum(external_force(2:18:2))) > 5.0e-12_dp) then
    error stop 'Kapalı-form F-bar boundary traction global kuvvet dengesini kapatmıyor.'
  end if

  ! Newton'dan bağımsız olarak exact affine alanın F-bar global equilibrium
  ! denklemini sağlaması gerekir. Bu kontrol traction/assembly sözleşmesini ayırır.
  call assemble_q4_plane_strain_fbar_mesh( &
      X,connectivity,expected_u,parameters,internal_force,tangent,status, &
      min_j,min_j_bar,max_j_bar)
  if (status /= DES_STATUS_OK) then
    error stop 'Exact affine F-bar assembly başarısız.'
  end if

  residual = internal_force-external_force
  exact_free_residual = max_free_residual(residual)
  if (exact_free_residual > exact_equilibrium_tol) then
    write(*,'(A,ES14.6)') 'Exact affine free residual = ',exact_free_residual
    error stop 'Distorsiyonlu F-bar mesh kapalı-form affine equilibriumu sağlamadı.'
  end if
  if (abs(min_j-1.0_dp) > j_tol .or. &
      abs(min_j_bar-1.0_dp) > j_tol .or. abs(max_j_bar-1.0_dp) > j_tol) then
    error stop 'Exact affine F-bar J/J_bar isochoric referansla uyuşmuyor.'
  end if

  ! Asıl production-yol testi: sıfır başlangıçtan force-control Full Newton.
  u = 0.0_dp
  call solve_q4_plane_strain_fbar_force_control( &
      X,connectivity,parameters,fixed_dofs,external_force, &
      8,40,final_residual_tol,u,residual,report)

  if (.not. report%converged .or. report%status /= DES_STATUS_OK) then
    error stop 'F-bar severe-distortion force-control çözümü yakınsamadı.'
  end if
  if (report%increments_converged /= 8) then
    error stop 'F-bar severe-distortion tüm load incrementlerini tamamlamadı.'
  end if
  if (report%min_j <= 0.0_dp) then
    error stop 'F-bar severe-distortion Newton yolu non-positive J gördü.'
  end if
  if (report%linear_solve_count <= 0) then
    error stop 'F-bar severe-distortion lineer solve diagnostics üretmedi.'
  end if
  if (report%max_linear_residual_inf_norm > 1.0e-9_dp) then
    error stop 'F-bar severe-distortion lineer residual toleransı aştı.'
  end if

  displacement_error = maxval(abs(u-expected_u))
  if (displacement_error > displacement_tol) then
    write(*,'(A,ES14.6)') 'F-bar severe-distortion displacement error = ',displacement_error
    error stop 'F-bar severe-distortion solver affine exact alanı geri üretemedi.'
  end if

  ! Son state'te J_bar ve free residual tekrar doğrulanır.
  call assemble_q4_plane_strain_fbar_mesh( &
      X,connectivity,u,parameters,internal_force,tangent,status, &
      min_j,min_j_bar,max_j_bar)
  if (status /= DES_STATUS_OK) error stop 'F-bar final distortion assembly başarısız.'

  residual = internal_force-external_force
  if (max_free_residual(residual) > 2.0_dp*final_residual_tol) then
    error stop 'F-bar severe-distortion final free residual kapanmadı.'
  end if

  write(*,'(A,ES14.6)') 'Reference min weight        = ',min_weight
  write(*,'(A,ES14.6)') 'Reference weight ratio      = ',weight_ratio
  write(*,'(A,ES14.6)') 'Exact affine free residual  = ',exact_free_residual
  write(*,'(A,ES14.6)') 'Recovered displacement err  = ',displacement_error
  write(*,'(A,ES14.6)') 'Final minimum J             = ',min_j
  write(*,'(A,ES14.6)') 'Final minimum J_bar         = ',min_j_bar
  write(*,'(A,ES14.6)') 'Final maximum J_bar         = ',max_j_bar
  write(*,'(A,I0)')      'Newton linear solve count   = ',report%linear_solve_count
  write(*,'(A)') 'F-bar severe-distortion affine force-control benchmark BASARILI.'

contains

  subroutine add_boundary_edge(local_mesh,element_id,edge_id,traction,force)
    type(internal_mesh_t), intent(in) :: local_mesh
    integer, intent(in) :: element_id,edge_id
    real(dp), intent(in) :: traction(2)
    real(dp), intent(inout) :: force(18)
    integer :: local_status

    call add_q4_reference_edge_traction( &
        local_mesh,element_id,edge_id,traction,force,local_status)
    if (local_status /= DES_STATUS_OK) then
      error stop 'F-bar severe-distortion boundary traction assembly başarısız.'
    end if
  end subroutine add_boundary_edge

  function max_free_residual(r) result(value)
    real(dp), intent(in) :: r(18)
    real(dp) :: value
    integer :: dof

    value = 0.0_dp
    do dof = 1,18
      if (all(dof /= fixed_dofs)) value = max(value,abs(r(dof)))
    end do
  end function max_free_residual

  subroutine reference_distortion_metrics( &
      coords,conn,min_w,max_w,ratio,total_reference_area)
    real(dp), intent(in) :: coords(9,2)
    integer, intent(in) :: conn(4,4)
    real(dp), intent(out) :: min_w,max_w,ratio,total_reference_area
    real(dp), parameter :: gp = 0.57735026918962576451_dp
    real(dp) :: N(4),dN_parent(4,2),Xe(4,2)
    real(dp) :: xi,eta,dx_dxi,dx_deta,dy_dxi,dy_deta,detJ0
    integer :: e,a,ig,jg

    min_w = huge(1.0_dp)
    max_w = 0.0_dp
    total_reference_area = 0.0_dp

    do e = 1,4
      do a = 1,4
        Xe(a,:) = coords(conn(e,a),:)
      end do
      do jg = 1,2
        if (jg == 1) then
          eta = -gp
        else
          eta = gp
        end if
        do ig = 1,2
          if (ig == 1) then
            xi = -gp
          else
            xi = gp
          end if

          call q4_shape_functions(xi,eta,N,dN_parent)
          dx_dxi  = sum(dN_parent(:,1)*Xe(:,1))
          dx_deta = sum(dN_parent(:,2)*Xe(:,1))
          dy_dxi  = sum(dN_parent(:,1)*Xe(:,2))
          dy_deta = sum(dN_parent(:,2)*Xe(:,2))
          detJ0 = dx_dxi*dy_deta-dx_deta*dy_dxi

          if (detJ0 <= 0.0_dp) then
            error stop 'F-bar severe-distortion reference Jacobian non-positive.'
          end if

          min_w = min(min_w,detJ0)
          max_w = max(max_w,detJ0)
          total_reference_area = total_reference_area+detJ0
        end do
      end do
    end do

    ratio = min_w/max_w
  end subroutine reference_distortion_metrics

  pure subroutine neo_hookean_closed_form(F_value,mu,lame_lambda,P_value,J_value)
    real(dp), intent(in) :: F_value(3,3),mu,lame_lambda
    real(dp), intent(out) :: P_value(3,3),J_value
    real(dp) :: FinvT(3,3),alpha,lnJ

    J_value = F_value(1,1)*F_value(2,2)-F_value(1,2)*F_value(2,1)
    if (J_value <= 0.0_dp) then
      P_value = 0.0_dp
      return
    end if

    FinvT = 0.0_dp
    FinvT(1,1) =  F_value(2,2)/J_value
    FinvT(1,2) = -F_value(2,1)/J_value
    FinvT(2,1) = -F_value(1,2)/J_value
    FinvT(2,2) =  F_value(1,1)/J_value
    FinvT(3,3) = 1.0_dp

    lnJ = log(J_value)
    alpha = lame_lambda*lnJ-mu
    P_value = mu*F_value+alpha*FinvT
  end subroutine neo_hookean_closed_form

end program test_v03_fbar_severe_distortion_affine
