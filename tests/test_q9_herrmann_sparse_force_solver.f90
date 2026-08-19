program test_q9_herrmann_sparse_force_solver
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_internal_mesh, only : internal_mesh_t, initialize_q9_internal_mesh
  use des_q4_plane_strain_newton_solver, only : newton_report_t
  use des_linear_solver, only : linear_solver_settings_t, &
                                DES_LINEAR_BACKEND_STDLIB_CSR_GMRES, &
                                DES_LINEAR_BACKEND_MUMPS_DIRECT
  use des_q9_internal_mesh_herrmann_assembly, only : assemble_q9_internal_mesh_herrmann
  use des_q9_plane_strain_herrmann_force_solver, only : &
      solve_q9_internal_mesh_herrmann_force_control
  implicit none

  real(dp) :: X(9,2)
  integer :: connectivity(1,9),status,sparse_backend
  character(len=32) :: backend_argument
  type(internal_mesh_t) :: mesh

  sparse_backend = DES_LINEAR_BACKEND_STDLIB_CSR_GMRES
  if (command_argument_count() > 0) then
    call get_command_argument(1,backend_argument)
    select case (trim(backend_argument))
    case ('mumps')
      sparse_backend = DES_LINEAR_BACKEND_MUMPS_DIRECT
    case default
      error stop 'Q9 sparse parity bilinmeyen backend argumani.'
    end select
  end if

  X(1,:) = [0.0_dp,0.0_dp]
  X(2,:) = [1.0_dp,0.0_dp]
  X(3,:) = [1.0_dp,1.0_dp]
  X(4,:) = [0.0_dp,1.0_dp]
  X(5,:) = [0.5_dp,0.0_dp]
  X(6,:) = [1.0_dp,0.5_dp]
  X(7,:) = [0.5_dp,1.0_dp]
  X(8,:) = [0.0_dp,0.5_dp]
  X(9,:) = [0.5_dp,0.5_dp]
  connectivity(1,:) = [1,2,3,4,5,6,7,8,9]

  call initialize_q9_internal_mesh(mesh,X,connectivity,status)
  if (status /= DES_STATUS_OK) error stop 'Sparse Q9 nonlinear parity mesh kurulamadi.'

  call run_parity_case(mesh,5.0e-2_dp,.false.,sparse_backend)
  call run_parity_case(mesh,0.0_dp,.true.,sparse_backend)

  write(*,'(A)') 'Q9/P1 Herrmann dense-sparse nonlinear parity testi BASARILI.'

contains

  subroutine run_parity_case(mesh,pressure_compliance,fully_incompressible,sparse_backend)
    type(internal_mesh_t), intent(in) :: mesh
    real(dp), intent(in) :: pressure_compliance
    logical, intent(in) :: fully_incompressible
    integer, intent(in) :: sparse_backend

    integer, parameter :: fixed_dofs(3) = [1,2,7]
    real(dp), parameter :: shear_modulus = 2.0_dp
    real(dp), parameter :: alpha = 2.0e-2_dp
    real(dp) :: beta,J_target,min_j
    real(dp) :: u_target(9,2),u_dense(9,2),u_sparse(9,2)
    real(dp) :: p_target(1,3),p_dense(1,3),p_sparse(1,3)
    real(dp) :: residual_target(21),residual_dense(21),residual_sparse(21)
    real(dp) :: K_target(21,21),external_force(18)
    real(dp) :: u_gap,p_gap,residual_gap
    integer :: a,local_status
    type(newton_report_t) :: dense_report,sparse_report
    type(linear_solver_settings_t) :: sparse_settings

    if (fully_incompressible) then
      ! J=1 tam olarak korunur; pressure bilinmeyeni hydrostatic stress seviyesini
      ! taşır. Bu durum Kpp=0 gerçek saddle-point lineer sistemini zorlar.
      beta = 1.0_dp/(1.0_dp+alpha)-1.0_dp
    else
      beta = -1.0e-2_dp
    end if

    do a = 1,9
      u_target(a,1) = alpha*mesh%coordinates(a,1)
      u_target(a,2) = beta*mesh%coordinates(a,2)
    end do
    J_target = (1.0_dp+alpha)*(1.0_dp+beta)

    p_target = 0.0_dp
    if (fully_incompressible) then
      p_target(1,1) = 3.0e-2_dp
    else
      p_target(1,1) = -(J_target-1.0_dp)/pressure_compliance
    end if

    call assemble_q9_internal_mesh_herrmann( &
        mesh,u_target,p_target,shear_modulus,pressure_compliance, &
        residual_target,K_target,local_status,min_j)
    if (local_status /= DES_STATUS_OK) then
      error stop 'Sparse Q9 parity target assembly basarisiz.'
    end if
    if (maxval(abs(residual_target(19:21))) > 2.0e-12_dp) then
      error stop 'Sparse Q9 parity target pressure weak residual sifir degil.'
    end if
    external_force = residual_target(1:18)

    u_dense = 0.0_dp
    p_dense = 0.0_dp
    call solve_q9_internal_mesh_herrmann_force_control( &
        mesh,shear_modulus,pressure_compliance,fixed_dofs,external_force, &
        5,40,1.0e-10_dp,u_dense,p_dense,residual_dense,dense_report)
    if (.not. dense_report%converged .or. dense_report%status /= DES_STATUS_OK) then
      error stop 'Q9 dense nonlinear parity referansi yakinsamadi.'
    end if

    sparse_settings = linear_solver_settings_t()
    sparse_settings%backend = sparse_backend
    sparse_settings%relative_tolerance = 1.0e-11_dp
    sparse_settings%absolute_tolerance = 1.0e-12_dp
    sparse_settings%max_iterations = 100
    sparse_settings%krylov_dimension = 21
    sparse_settings%compact_krylov = .true.

    u_sparse = 0.0_dp
    p_sparse = 0.0_dp
    call solve_q9_internal_mesh_herrmann_force_control( &
        mesh,shear_modulus,pressure_compliance,fixed_dofs,external_force, &
        5,40,1.0e-10_dp,u_sparse,p_sparse,residual_sparse,sparse_report, &
        linear_settings=sparse_settings)
    if (.not. sparse_report%converged .or. sparse_report%status /= DES_STATUS_OK) then
      error stop 'Q9 CSR-GMRES nonlinear solver yakinsamadi.'
    end if

    u_gap = maxval(abs(u_sparse-u_dense))
    p_gap = maxval(abs(p_sparse-p_dense))
    residual_gap = maxval(abs(residual_sparse-residual_dense))

    if (u_gap > 5.0e-8_dp) then
      error stop 'Q9 dense-sparse nonlinear displacement parity toleransi asildi.'
    end if
    if (p_gap > 5.0e-8_dp) then
      error stop 'Q9 dense-sparse nonlinear pressure parity toleransi asildi.'
    end if
    if (residual_gap > 2.0e-8_dp) then
      error stop 'Q9 dense-sparse final residual parity toleransi asildi.'
    end if
    if (sparse_report%max_linear_equation_count /= 21) then
      error stop 'Q9 sparse nonlinear solve tam mixed equation count raporlamadi.'
    end if
    if (sparse_report%linear_solve_count < 1) then
      error stop 'Q9 sparse nonlinear parity lineer solve calistirmadi.'
    end if
    if (sparse_report%max_linear_residual_inf_norm > 2.0e-10_dp) then
      error stop 'Q9 sparse nonlinear lineer true residual toleransi asildi.'
    end if

    ! B4: Newton boyunca aynı CSR graph için symbolic analysis ve ordering yalnız
    ! bir kez yapılmalı; numeric stage ve solve ise her gerçek lineer çözümde yenilenmeli.
    if (sparse_report%last_linear_report%pattern_analysis_count /= 1) then
      error stop 'Q9 sparse context pattern analysis birden fazla calisti.'
    end if
    if (sparse_report%last_linear_report%reorder_count /= 1) then
      error stop 'Q9 sparse context ordering birden fazla calisti.'
    end if
    if (sparse_report%last_linear_report%factorization_count /= &
        sparse_report%linear_solve_count) then
      error stop 'Q9 sparse context numeric lifecycle solve sayisiyla uyusmuyor.'
    end if
    if (sparse_report%last_linear_report%context_solve_count /= &
        sparse_report%linear_solve_count) then
      error stop 'Q9 sparse context solve sayaci Newton sayaciyla uyusmuyor.'
    end if
    if (sparse_report%last_linear_report%backend /= sparse_backend) then
      error stop 'Q9 sparse parity backend raporu secimle uyusmuyor.'
    end if
    if (sparse_backend == DES_LINEAR_BACKEND_MUMPS_DIRECT) then
      if (.not. sparse_report%last_linear_report%direct_factorization_performed) then
        error stop 'Q9 MUMPS direct factorization raporlanmadi.'
      end if
    else
      if (sparse_report%last_linear_report%direct_factorization_performed) then
        error stop 'Q9 GMRES direct factorization yapmis gibi raporlandi.'
      end if
    end if

    if (fully_incompressible) then
      if (maxval(abs(u_sparse-u_target)) > 5.0e-8_dp) then
        error stop 'Q9 fully-incompressible sparse displacement hedefi kurtarilamadi.'
      end if
      if (maxval(abs(p_sparse-p_target)) > 5.0e-8_dp) then
        error stop 'Q9 fully-incompressible sparse pressure hedefi kurtarilamadi.'
      end if
      write(*,'(A,ES12.4,A,ES12.4)') &
          'Fully-incompressible sparse parity u/p gap = ',u_gap,' / ',p_gap
    else
      write(*,'(A,ES12.4,A,ES12.4)') &
          'Finite-compliance sparse parity u/p gap = ',u_gap,' / ',p_gap
    end if
  end subroutine run_parity_case

end program test_q9_herrmann_sparse_force_solver