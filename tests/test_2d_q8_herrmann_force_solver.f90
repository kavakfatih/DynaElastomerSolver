program test_2d_q8_herrmann_force_solver
  use des_kinds, only : dp, i64
  use des_status, only : DES_STATUS_OK
  use des_2d_analysis_contract, only : DES_2D_AXISYMMETRIC_TORSION, &
      DES_TOPOLOGY_Q8, DES_FORMULATION_MIXED_UP, DES_PRESSURE_SPACE_P1, &
      DES_ELEMENT_TECH_UNIFORM_REDUCED
  use des_2d_mesh_database, only : mesh_database_2d_t
  use des_2d_dof_manager, only : dof_layout_2d_t, build_2d_dof_layout
  use des_2d_q8_herrmann_assembly, only : initialize_2d_q8_herrmann_csr_pattern, &
      assemble_2d_q8_herrmann_csr
  use des_csr_matrix, only : csr_matrix_t
  use des_linear_solver, only : linear_solver_settings_t, &
      DES_LINEAR_BACKEND_STDLIB_CSR_GMRES, DES_LINEAR_BACKEND_MUMPS_DIRECT
  use des_q4_plane_strain_newton_solver, only : newton_report_t
  use des_nonlinear_solver, only : nonlinear_solver_settings_t
  use des_2d_q8_herrmann_force_solver, only : solve_2d_q8_herrmann_force_control, &
      solve_2d_q8_herrmann_adaptive_force_control
  implicit none

  real(dp), parameter :: mu = 2.5_dp
  real(dp), parameter :: compliance = 0.05_dp
  real(dp), parameter :: alpha = 1.0e-2_dp
  type(mesh_database_2d_t) :: mesh
  type(dof_layout_2d_t) :: layout
  type(csr_matrix_t) :: tangent
  type(newton_report_t) :: report,adaptive_report
  type(linear_solver_settings_t) :: settings
  type(nonlinear_solver_settings_t) :: nonlinear_settings
  real(dp), allocatable :: target_state(:),state(:),adaptive_state(:)
  real(dp), allocatable :: target_residual(:),residual(:),adaptive_residual(:)
  real(dp), allocatable :: external_load(:)
  integer(i64), allocatable :: fixed_equations(:),free_equations(:)
  character(len=32) :: backend_argument
  integer :: backend,status,i,cursor
  real(dp) :: min_j,state_error,adaptive_state_error
  logical :: line_search_seen

  backend = DES_LINEAR_BACKEND_STDLIB_CSR_GMRES
  if (command_argument_count() > 0) then
    call get_command_argument(1,backend_argument)
    select case (trim(backend_argument))
    case ('mumps')
      backend = DES_LINEAR_BACKEND_MUMPS_DIRECT
    case ('gmres')
      backend = DES_LINEAR_BACKEND_STDLIB_CSR_GMRES
    case default
      error stop '2D Q8 sparse Newton bilinmeyen backend argumani.'
    end select
  end if

  call build_torsion_mesh(mesh)
  call build_2d_dof_layout(mesh,layout,status)
  call require(status == DES_STATUS_OK,'Q8 torsion solver DOF layout kurulamadı')
  call require(layout%total_equation_count == 27_i64,'Q8 torsion solver 27 equation bekliyor')

  allocate(target_state(layout%total_equation_count),state(layout%total_equation_count))
  allocate(adaptive_state(layout%total_equation_count))
  allocate(target_residual(layout%total_equation_count),residual(layout%total_equation_count))
  allocate(adaptive_residual(layout%total_equation_count))
  allocate(external_load(layout%total_equation_count))
  target_state = 0.0_dp

  ! Manufactured torsion state: phi=alpha*Z, radial/axial displacement sıfır.
  ! Finite pressure compliance pressure block'unu regular tutar ve target p=0'dır.
  do i = 1,size(mesh%nodes)
    target_state(layout%nodal_equations(3,i)) = alpha*mesh%nodes(i)%y
  end do

  call initialize_2d_q8_herrmann_csr_pattern(mesh,layout,tangent,status)
  call require(status == DES_STATUS_OK,'Q8 torsion target CSR graph kurulamadı')
  call assemble_2d_q8_herrmann_csr( &
      mesh,layout,target_state,mu,compliance,target_residual,tangent,status,min_j)
  call require(status == DES_STATUS_OK,'Q8 torsion manufactured target assemble edilemedi')
  call require(abs(min_j-1.0_dp) <= 5.0e-13_dp,'Q8 torsion target J=1 koşulunu bozdu')

  ! Radial ve axial DOF'ların tamamı sıfır tutulur; alt Z=0 kenarındaki ROTY
  ! DOF'ları ayrıca ankastre edilir. Kalan ROTY + pressure unknown'ları çözülür.
  allocate(fixed_equations(19))
  cursor = 0
  do i = 1,size(mesh%nodes)
    cursor = cursor+1
    fixed_equations(cursor) = layout%nodal_equations(1,i)
    cursor = cursor+1
    fixed_equations(cursor) = layout%nodal_equations(2,i)
  end do
  do i = 1,size(mesh%nodes)
    if (abs(mesh%nodes(i)%y) <= 1.0e-14_dp) then
      cursor = cursor+1
      fixed_equations(cursor) = layout%nodal_equations(3,i)
    end if
  end do
  call require(cursor == size(fixed_equations),'Q8 torsion fixed-equation sayısı yanlış')

  external_load = target_residual
  external_load(fixed_equations) = 0.0_dp
  ! Constraint equations fiziksel external pressure load taşımaz.
  external_load(layout%pressure_equations(1:3,1)) = 0.0_dp

  call build_free_equations(layout%total_equation_count,fixed_equations,free_equations)

  settings = linear_solver_settings_t()
  settings%backend = backend
  settings%relative_tolerance = 1.0e-11_dp
  settings%absolute_tolerance = 1.0e-12_dp
  settings%max_iterations = 120
  settings%krylov_dimension = 27

  ! Sabit-increment sparse Newton recovery.
  state = 0.0_dp
  call solve_2d_q8_herrmann_force_control( &
      mesh,layout,mu,compliance,fixed_equations,external_load, &
      4,30,1.0e-10_dp,state,residual,report,linear_settings=settings)

  call require(report%status == DES_STATUS_OK .and. report%converged, &
      'Field-based Q8 torsion sparse Newton yakinsamadi')
  call require(report%final_load_factor == 1.0_dp,'Q8 torsion final load factor 1 değil')
  call require(report%increments_converged == 4,'Q8 torsion dört increment tamamlamadı')
  call require(report%state_commit_count == 4,'Q8 torsion commit sayacı increment sayısıyla uyuşmuyor')
  call require(report%state_revert_count == 0,'Nominal Q8 torsion solve rollback üretmemeli')
  call require(report%linear_solve_count > 0,'Q8 torsion Newton lineer çözüm çalıştırmadı')
  call require(report%max_linear_equation_count == 27_i64, &
      'Q8 torsion Newton 27-equation mixed sistem raporlamadı')
  call check_sparse_lifecycle(report,backend,'fixed')

  state_error = maxval(abs(state(free_equations)-target_state(free_equations)))
  call require(state_error <= 2.0e-8_dp,'Q8 torsion manufactured state kurtarılamadı')
  call require(maxval(abs(residual(free_equations))) <= 1.0e-10_dp, &
      'Q8 torsion final free residual toleransı aşıldı')

  ! Adaptive production yolunda aynı mixed state iki 0.5 load step ile çözülür.
  ! Line-search varsayılan açık tutulur ve bütün transaction tek flat u/p/twist
  ! state üzerinde commit edilir. Nominal vaka cutback üretmemelidir.
  nonlinear_settings = nonlinear_solver_settings_t()
  adaptive_state = 0.0_dp
  call solve_2d_q8_herrmann_adaptive_force_control( &
      mesh,layout,mu,compliance,fixed_equations,external_load, &
      0.5_dp,0.125_dp,0.5_dp,4,30,1.0e-10_dp,adaptive_state,adaptive_residual, &
      adaptive_report,linear_settings=settings,nonlinear_settings=nonlinear_settings)

  call require(adaptive_report%status == DES_STATUS_OK .and. adaptive_report%converged, &
      'Q8 torsion adaptive sparse Newton yakinsamadi')
  call require(abs(adaptive_report%final_load_factor-1.0_dp) <= 1.0e-14_dp, &
      'Q8 torsion adaptive final load factor 1 değil')
  call require(adaptive_report%increments_converged == 2, &
      'Q8 torsion adaptive iki nominal increment tamamlamadı')
  call require(adaptive_report%state_commit_count == 2, &
      'Q8 torsion adaptive commit sayacı yanlış')
  call require(adaptive_report%state_revert_count == 0, &
      'Nominal Q8 torsion adaptive solve rollback üretmemeli')
  call require(adaptive_report%cutback_count == 0, &
      'Nominal Q8 torsion adaptive solve cutback üretmemeli')
  call require(adaptive_report%history%count > 0, &
      'Q8 torsion adaptive convergence history boş')
  call check_sparse_lifecycle(adaptive_report,backend,'adaptive')

  line_search_seen = .false.
  do i = 1,adaptive_report%history%count
    if (adaptive_report%history%records(i)%line_search_trials > 0) then
      line_search_seen = .true.
      exit
    end if
  end do
  call require(line_search_seen,'Q8 torsion adaptive line-search gate çalışmadı')

  adaptive_state_error = maxval(abs(adaptive_state(free_equations)-target_state(free_equations)))
  call require(adaptive_state_error <= 2.0e-8_dp, &
      'Q8 torsion adaptive manufactured state kurtarılamadı')
  call require(maxval(abs(adaptive_residual(free_equations))) <= 1.0e-10_dp, &
      'Q8 torsion adaptive final free residual toleransı aşıldı')
  call require(maxval(abs(adaptive_state-state)) <= 2.0e-8_dp, &
      'Q8 torsion fixed/adaptive final mixed state parity bozuldu')

  write(*,'(A,ES14.6)') 'Q8 torsion fixed state max error = ',state_error
  write(*,'(A,ES14.6)') 'Q8 torsion adaptive state max error = ',adaptive_state_error
  write(*,'(A,I0)') 'Q8 torsion adaptive history count = ',adaptive_report%history%count
  write(*,'(A)') 'PASS: field-based Q8/P1 torsion fixed + adaptive sparse Newton recovery'

contains

  subroutine build_torsion_mesh(mesh)
    type(mesh_database_2d_t), intent(out) :: mesh

    allocate(mesh%nodes(8),mesh%elements(1))
    mesh%nodes(1)%id=101_i64; mesh%nodes(1)%x=1.0_dp; mesh%nodes(1)%y=0.0_dp
    mesh%nodes(2)%id=102_i64; mesh%nodes(2)%x=2.0_dp; mesh%nodes(2)%y=0.0_dp
    mesh%nodes(3)%id=103_i64; mesh%nodes(3)%x=2.0_dp; mesh%nodes(3)%y=1.0_dp
    mesh%nodes(4)%id=104_i64; mesh%nodes(4)%x=1.0_dp; mesh%nodes(4)%y=1.0_dp
    mesh%nodes(5)%id=105_i64; mesh%nodes(5)%x=1.5_dp; mesh%nodes(5)%y=0.0_dp
    mesh%nodes(6)%id=106_i64; mesh%nodes(6)%x=2.0_dp; mesh%nodes(6)%y=0.5_dp
    mesh%nodes(7)%id=107_i64; mesh%nodes(7)%x=1.5_dp; mesh%nodes(7)%y=1.0_dp
    mesh%nodes(8)%id=108_i64; mesh%nodes(8)%x=1.0_dp; mesh%nodes(8)%y=0.5_dp

    mesh%elements(1)%id = 501_i64
    mesh%elements(1)%topology = DES_TOPOLOGY_Q8
    mesh%elements(1)%analysis_mode = DES_2D_AXISYMMETRIC_TORSION
    mesh%elements(1)%formulation = DES_FORMULATION_MIXED_UP
    mesh%elements(1)%pressure_space = DES_PRESSURE_SPACE_P1
    mesh%elements(1)%element_technology = DES_ELEMENT_TECH_UNIFORM_REDUCED
    mesh%elements(1)%material_id = 1_i64
    mesh%elements(1)%connectivity = [101_i64,102_i64,103_i64,104_i64, &
                                     105_i64,106_i64,107_i64,108_i64]
  end subroutine build_torsion_mesh

  subroutine build_free_equations(ntotal,fixed,free)
    integer(i64), intent(in) :: ntotal,fixed(:)
    integer(i64), allocatable, intent(out) :: free(:)
    logical, allocatable :: is_fixed(:)
    integer(i64) :: dof,cursor

    allocate(is_fixed(ntotal))
    is_fixed = .false.
    is_fixed(fixed) = .true.
    allocate(free(count(.not.is_fixed)))
    cursor = 0_i64
    do dof = 1_i64,ntotal
      if (.not.is_fixed(dof)) then
        cursor = cursor+1_i64
        free(cursor) = dof
      end if
    end do
  end subroutine build_free_equations

  subroutine check_sparse_lifecycle(local_report,expected_backend,label)
    type(newton_report_t), intent(in) :: local_report
    integer, intent(in) :: expected_backend
    character(len=*), intent(in) :: label

    call require(local_report%last_linear_report%pattern_analysis_count == 1, &
        trim(label)//': sparse pattern birden fazla analyze edildi')
    call require(local_report%last_linear_report%reorder_count == 1, &
        trim(label)//': sparse ordering birden fazla çalıştı')
    call require(local_report%last_linear_report%factorization_count == &
        local_report%linear_solve_count, &
        trim(label)//': factorization sayısı Newton solve sayısıyla uyuşmuyor')
    call require(local_report%last_linear_report%context_solve_count == &
        local_report%linear_solve_count, &
        trim(label)//': context solve sayısı Newton solve sayısıyla uyuşmuyor')
    call require(local_report%last_linear_report%backend == expected_backend, &
        trim(label)//': sparse backend raporu seçimle uyuşmuyor')

    if (expected_backend == DES_LINEAR_BACKEND_MUMPS_DIRECT) then
      call require(local_report%last_linear_report%direct_factorization_performed, &
          trim(label)//': MUMPS direct factorization raporlanmadı')
    else
      call require(.not. local_report%last_linear_report%direct_factorization_performed, &
          trim(label)//': GMRES direct factorization yapmış gibi raporlandı')
    end if
  end subroutine check_sparse_lifecycle

  subroutine require(condition,message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not.condition) error stop message
  end subroutine require

end program test_2d_q8_herrmann_force_solver
