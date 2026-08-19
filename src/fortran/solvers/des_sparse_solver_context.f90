module des_sparse_solver_context
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONSTRAINT, &
                         DES_ERROR_LINEAR_SOLVE, &
                         DES_ERROR_UNSUPPORTED_LINEAR_BACKEND
  use des_csr_matrix, only : csr_matrix_t, csr_matvec
  use des_linear_solver, only : linear_solver_settings_t, &
                                linear_solver_report_t, &
                                solve_sparse_linear_system, &
                                DES_LINEAR_BACKEND_STDLIB_CSR_GMRES, &
                                DES_LINEAR_BACKEND_MUMPS_DIRECT
  use des_mumps_backend, only : DES_MUMPS_AVAILABLE, mumps_backend_handle_t, &
                                mumps_backend_create, &
                                mumps_backend_set_pattern, &
                                mumps_backend_analyze, &
                                mumps_backend_factorize, &
                                mumps_backend_solve, &
                                mumps_backend_destroy
  implicit none
  private

  integer, parameter, public :: DES_MATRIX_CLASS_UNKNOWN = 0
  integer, parameter, public :: DES_MATRIX_CLASS_SPD = 1
  integer, parameter, public :: DES_MATRIX_CLASS_SYMMETRIC_INDEFINITE = 2
  integer, parameter, public :: DES_MATRIX_CLASS_UNSYMMETRIC = 3

  integer, parameter, public :: DES_PROBLEM_CLASS_UNKNOWN = 0
  integer, parameter, public :: DES_PROBLEM_CLASS_DISPLACEMENT = 1
  integer, parameter, public :: DES_PROBLEM_CLASS_MIXED_U_P = 2

  integer, parameter, public :: DES_INDEX_CLASS_INT32 = 1
  integer, parameter, public :: DES_INDEX_CLASS_INT64 = 2

  type, public :: sparse_solver_diagnostics_t
    integer :: backend = 0
    integer :: matrix_class = DES_MATRIX_CLASS_UNKNOWN
    integer :: problem_class = DES_PROBLEM_CLASS_UNKNOWN
    integer :: index_class = DES_INDEX_CLASS_INT32
    integer :: equation_count = 0
    integer :: nnz = 0
    integer :: pattern_analysis_count = 0
    integer :: reorder_count = 0
    integer :: factorization_count = 0
    integer :: solve_count = 0
    integer :: iterative_refinement_count = 0
    integer :: symbolic_reuse_count = 0
    integer :: backend_info_primary = 0
    integer :: backend_info_secondary = 0
    logical :: active = .false.
    logical :: pattern_analyzed = .false.
    logical :: ordering_ready = .false.
    logical :: numeric_ready = .false.
    logical :: direct_factorization_performed = .false.
    logical :: supports_int64 = .false.
    logical :: released = .false.
    type(linear_solver_report_t) :: last_linear_report
  end type sparse_solver_diagnostics_t

  type, public :: sparse_solver_context_t
    type(linear_solver_settings_t) :: settings
    integer :: matrix_class = DES_MATRIX_CLASS_UNKNOWN
    integer :: problem_class = DES_PROBLEM_CLASS_UNKNOWN
    integer :: index_class = DES_INDEX_CLASS_INT32
    integer :: equation_count = 0
    integer :: structural_nnz = 0
    integer :: pattern_analysis_count = 0
    integer :: reorder_count = 0
    integer :: factorization_count = 0
    integer :: solve_count = 0
    integer :: iterative_refinement_count = 0
    integer :: symbolic_reuse_count = 0
    integer :: backend_info_primary = 0
    integer :: backend_info_secondary = 0
    logical :: active = .false.
    logical :: pattern_analyzed = .false.
    logical :: ordering_ready = .false.
    logical :: backend_analysis_ready = .false.
    logical :: numeric_ready = .false.
    logical :: direct_factorization_performed = .false.
    logical :: supports_int64 = .false.
    logical :: released = .false.
    integer, allocatable :: pattern_row_ptr(:)
    integer, allocatable :: pattern_col_ind(:)
    type(mumps_backend_handle_t) :: mumps_handle
    type(linear_solver_report_t) :: last_linear_report
  end type sparse_solver_context_t

  public :: create_sparse_solver_context
  public :: analyze_sparse_pattern
  public :: reorder_sparse_pattern
  public :: factorize_sparse_matrix
  public :: solve_sparse_with_context
  public :: refine_sparse_solution
  public :: reuse_sparse_pattern
  public :: get_sparse_solver_diagnostics
  public :: release_sparse_solver_context

contains

  subroutine create_sparse_solver_context( &
      context, settings, matrix_class, problem_class, index_class, status)
    type(sparse_solver_context_t), intent(out) :: context
    type(linear_solver_settings_t), intent(in) :: settings
    integer, intent(in) :: matrix_class, problem_class, index_class
    integer, intent(out) :: status

    context%settings = settings
    context%matrix_class = matrix_class
    context%problem_class = problem_class
    context%index_class = index_class
    context%last_linear_report = linear_solver_report_t()
    context%last_linear_report%backend = settings%backend
    status = DES_STATUS_OK

    if (.not. valid_matrix_class(matrix_class) .or. &
        .not. valid_problem_class(problem_class) .or. &
        .not. valid_index_class(index_class)) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    select case (settings%backend)
    case (DES_LINEAR_BACKEND_STDLIB_CSR_GMRES)
      ! stdlib CSR köprüsü bugün int32 ile sınırlıdır.
      context%supports_int64 = .false.
    case (DES_LINEAR_BACKEND_MUMPS_DIRECT)
      ! B6 ilk production profili int32 Dyna CSR ile başlar.
      ! MUMPS 64-bit genişlemesi B9'da Dyna CSR int64 dönüşümüyle açılacaktır.
      context%supports_int64 = .false.
      if (.not. DES_MUMPS_AVAILABLE) then
        status = DES_ERROR_UNSUPPORTED_LINEAR_BACKEND
        return
      end if
      call mumps_backend_create( &
          context%mumps_handle,mumps_symmetry_mode(matrix_class),status, &
          context%backend_info_primary,context%backend_info_secondary)
      if (status /= DES_STATUS_OK) return
    case default
      status = DES_ERROR_UNSUPPORTED_LINEAR_BACKEND
      return
    end select

    if (index_class == DES_INDEX_CLASS_INT64 .and. &
        .not. context%supports_int64) then
      if (settings%backend == DES_LINEAR_BACKEND_MUMPS_DIRECT) then
        call mumps_backend_destroy(context%mumps_handle)
      end if
      status = DES_ERROR_UNSUPPORTED_LINEAR_BACKEND
      return
    end if

    context%active = .true.
    context%released = .false.
  end subroutine create_sparse_solver_context

  subroutine analyze_sparse_pattern(context, matrix, status)
    type(sparse_solver_context_t), intent(inout) :: context
    type(csr_matrix_t), intent(in) :: matrix
    integer, intent(out) :: status

    status = DES_STATUS_OK
    if (.not. context%active .or. context%released) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if
    if (.not. valid_csr_structure(matrix)) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    if (context%pattern_analyzed) then
      if (same_sparse_pattern(context,matrix)) then
        context%symbolic_reuse_count = context%symbolic_reuse_count + 1
        return
      end if
    end if

    if (allocated(context%pattern_row_ptr)) deallocate(context%pattern_row_ptr)
    if (allocated(context%pattern_col_ind)) deallocate(context%pattern_col_ind)
    allocate(context%pattern_row_ptr(size(matrix%row_ptr)))
    allocate(context%pattern_col_ind(size(matrix%col_ind)))
    context%pattern_row_ptr = matrix%row_ptr
    context%pattern_col_ind = matrix%col_ind
    context%equation_count = matrix%nrows
    context%structural_nnz = size(matrix%col_ind)
    context%pattern_analysis_count = context%pattern_analysis_count + 1
    context%pattern_analyzed = .true.
    context%ordering_ready = .false.
    context%backend_analysis_ready = .false.
    context%numeric_ready = .false.
    context%direct_factorization_performed = .false.

    if (context%settings%backend == DES_LINEAR_BACKEND_MUMPS_DIRECT) then
      ! CSR -> MUMPS structural mapping yalnız graph değiştiğinde kurulur.
      ! MUMPS job=1 burada çalıştırılmaz; ilk assembled Newton değerleri gelene
      ! kadar analysis/matching bilinçli olarak ertelenir.
      call mumps_backend_set_pattern( &
          context%mumps_handle,matrix,status, &
          context%backend_info_primary,context%backend_info_secondary)
    end if
  end subroutine analyze_sparse_pattern

  subroutine reuse_sparse_pattern(context, matrix, reused, status)
    type(sparse_solver_context_t), intent(inout) :: context
    type(csr_matrix_t), intent(in) :: matrix
    logical, intent(out) :: reused
    integer, intent(out) :: status

    reused = .false.
    status = DES_STATUS_OK
    if (.not. context%active .or. context%released) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    if (context%pattern_analyzed .and. same_sparse_pattern(context,matrix)) then
      context%symbolic_reuse_count = context%symbolic_reuse_count + 1
      reused = .true.
      return
    end if

    call analyze_sparse_pattern(context,matrix,status)
  end subroutine reuse_sparse_pattern

  subroutine reorder_sparse_pattern(context, status)
    type(sparse_solver_context_t), intent(inout) :: context
    integer, intent(out) :: status

    status = DES_STATUS_OK
    if (.not. context%active .or. context%released .or. &
        .not. context%pattern_analyzed) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    if (context%ordering_ready) return

    ! GMRES'te ayrı fill-reducing ordering yoktur. MUMPS'ta ise gerçek symbolic
    ! analysis/ordering ilk assembled values setiyle factorize çağrısında yapılır.
    ! Bu flag lifecycle'da ordering aşamasının bir kez talep edildiğini gösterir.
    context%ordering_ready = .true.
    context%reorder_count = context%reorder_count + 1
  end subroutine reorder_sparse_pattern

  subroutine factorize_sparse_matrix(context, matrix, status)
    type(sparse_solver_context_t), intent(inout) :: context
    type(csr_matrix_t), intent(in) :: matrix
    integer, intent(out) :: status

    status = DES_STATUS_OK
    if (.not. context%active .or. context%released .or. &
        .not. context%ordering_ready) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if
    if (.not. same_sparse_pattern(context,matrix)) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    select case (context%settings%backend)
    case (DES_LINEAR_BACKEND_STDLIB_CSR_GMRES)
      context%direct_factorization_performed = .false.

    case (DES_LINEAR_BACKEND_MUMPS_DIRECT)
      if (.not. context%backend_analysis_ready) then
        call mumps_backend_analyze( &
            context%mumps_handle,matrix,status, &
            context%backend_info_primary,context%backend_info_secondary)
        if (status /= DES_STATUS_OK) then
          context%numeric_ready = .false.
          context%direct_factorization_performed = .false.
          return
        end if
        context%backend_analysis_ready = .true.
      end if

      call mumps_backend_factorize( &
          context%mumps_handle,matrix,status, &
          context%backend_info_primary,context%backend_info_secondary)
      if (status /= DES_STATUS_OK) then
        context%numeric_ready = .false.
        context%direct_factorization_performed = .false.
        return
      end if
      context%direct_factorization_performed = .true.

    case default
      status = DES_ERROR_UNSUPPORTED_LINEAR_BACKEND
      return
    end select

    context%numeric_ready = .true.
    context%factorization_count = context%factorization_count + 1
  end subroutine factorize_sparse_matrix

  subroutine solve_sparse_with_context(context, matrix, b, x, report)
    type(sparse_solver_context_t), intent(inout) :: context
    type(csr_matrix_t), intent(in) :: matrix
    real(dp), intent(in) :: b(:)
    real(dp), intent(out) :: x(:)
    type(linear_solver_report_t), intent(out) :: report

    real(dp), allocatable :: ax(:)
    real(dp) :: rhs_scale, residual_limit
    integer :: matvec_status, backend_status

    report = linear_solver_report_t()
    report%backend = context%settings%backend
    report%equation_count = size(b)
    x = 0.0_dp

    if (.not. context%active .or. context%released .or. &
        .not. context%numeric_ready .or. &
        .not. same_sparse_pattern(context,matrix) .or. &
        size(b) /= matrix%nrows .or. size(x) /= size(b)) then
      report%status = DES_ERROR_INVALID_CONSTRAINT
      call attach_context_counters(context,report)
      context%last_linear_report = report
      return
    end if

    select case (context%settings%backend)
    case (DES_LINEAR_BACKEND_STDLIB_CSR_GMRES)
      call solve_sparse_linear_system(matrix,b,x,context%settings,report)

    case (DES_LINEAR_BACKEND_MUMPS_DIRECT)
      call mumps_backend_solve( &
          context%mumps_handle,b,x,backend_status, &
          context%backend_info_primary,context%backend_info_secondary)
      if (backend_status /= DES_STATUS_OK) then
        report%status = backend_status
        report%converged = .false.
      else
        allocate(ax(size(b)))
        call csr_matvec(matrix,x,ax,matvec_status)
        if (matvec_status /= DES_STATUS_OK) then
          report%status = matvec_status
          report%converged = .false.
        else
          report%residual_inf_norm = maxval(abs(ax-b))
          rhs_scale = max(1.0_dp,maxval(abs(b)))
          residual_limit = max( &
              context%settings%absolute_tolerance, &
              context%settings%relative_tolerance*rhs_scale)
          if (report%residual_inf_norm <= residual_limit) then
            report%status = DES_STATUS_OK
            report%converged = .true.
          else
            report%status = DES_ERROR_LINEAR_SOLVE
            report%converged = .false.
          end if
        end if
      end if

    case default
      report%status = DES_ERROR_UNSUPPORTED_LINEAR_BACKEND
      report%converged = .false.
    end select

    context%solve_count = context%solve_count + 1
    call attach_context_counters(context,report)
    context%last_linear_report = report
  end subroutine solve_sparse_with_context

  subroutine refine_sparse_solution( &
      context, matrix, b, x, max_steps, tolerance, report)
    type(sparse_solver_context_t), intent(inout) :: context
    type(csr_matrix_t), intent(in) :: matrix
    real(dp), intent(in) :: b(:)
    real(dp), intent(inout) :: x(:)
    integer, intent(in) :: max_steps
    real(dp), intent(in) :: tolerance
    type(linear_solver_report_t), intent(out) :: report

    real(dp), allocatable :: ax(:), correction(:), residual(:)
    type(linear_solver_report_t) :: correction_report
    integer :: step, matvec_status

    report = linear_solver_report_t()
    report%backend = context%settings%backend
    report%equation_count = size(b)

    if (max_steps < 0 .or. tolerance <= 0.0_dp .or. &
        size(x) /= size(b) .or. .not. context%numeric_ready) then
      report%status = DES_ERROR_INVALID_CONSTRAINT
      call attach_context_counters(context,report)
      context%last_linear_report = report
      return
    end if

    allocate(ax(size(b)),correction(size(b)),residual(size(b)))

    do step = 0,max_steps
      call csr_matvec(matrix,x,ax,matvec_status)
      if (matvec_status /= DES_STATUS_OK) then
        report%status = matvec_status
        call attach_context_counters(context,report)
        context%last_linear_report = report
        return
      end if

      residual = b-ax
      report%residual_inf_norm = maxval(abs(residual))
      if (report%residual_inf_norm <= tolerance) then
        report%status = DES_STATUS_OK
        report%converged = .true.
        call attach_context_counters(context,report)
        context%last_linear_report = report
        return
      end if

      if (step == max_steps) exit

      call solve_sparse_with_context( &
          context,matrix,residual,correction,correction_report)
      if (.not. correction_report%converged) then
        report = correction_report
        context%last_linear_report = report
        return
      end if

      x = x+correction
      context%iterative_refinement_count = &
          context%iterative_refinement_count + 1
    end do

    report%status = DES_ERROR_LINEAR_SOLVE
    report%converged = .false.
    call attach_context_counters(context,report)
    context%last_linear_report = report
  end subroutine refine_sparse_solution

  subroutine get_sparse_solver_diagnostics(context, diagnostics)
    type(sparse_solver_context_t), intent(in) :: context
    type(sparse_solver_diagnostics_t), intent(out) :: diagnostics

    diagnostics%backend = context%settings%backend
    diagnostics%matrix_class = context%matrix_class
    diagnostics%problem_class = context%problem_class
    diagnostics%index_class = context%index_class
    diagnostics%equation_count = context%equation_count
    diagnostics%nnz = context%structural_nnz
    diagnostics%pattern_analysis_count = context%pattern_analysis_count
    diagnostics%reorder_count = context%reorder_count
    diagnostics%factorization_count = context%factorization_count
    diagnostics%solve_count = context%solve_count
    diagnostics%iterative_refinement_count = &
        context%iterative_refinement_count
    diagnostics%symbolic_reuse_count = context%symbolic_reuse_count
    diagnostics%backend_info_primary = context%backend_info_primary
    diagnostics%backend_info_secondary = context%backend_info_secondary
    diagnostics%active = context%active
    diagnostics%pattern_analyzed = context%pattern_analyzed
    diagnostics%ordering_ready = context%ordering_ready
    diagnostics%numeric_ready = context%numeric_ready
    diagnostics%direct_factorization_performed = &
        context%direct_factorization_performed
    diagnostics%supports_int64 = context%supports_int64
    diagnostics%released = context%released
    diagnostics%last_linear_report = context%last_linear_report
  end subroutine get_sparse_solver_diagnostics

  subroutine release_sparse_solver_context(context)
    type(sparse_solver_context_t), intent(inout) :: context

    if (context%settings%backend == DES_LINEAR_BACKEND_MUMPS_DIRECT) then
      call mumps_backend_destroy(context%mumps_handle)
    end if

    if (allocated(context%pattern_row_ptr)) deallocate(context%pattern_row_ptr)
    if (allocated(context%pattern_col_ind)) deallocate(context%pattern_col_ind)
    context%active = .false.
    context%pattern_analyzed = .false.
    context%ordering_ready = .false.
    context%backend_analysis_ready = .false.
    context%numeric_ready = .false.
    context%released = .true.
  end subroutine release_sparse_solver_context

  subroutine attach_context_counters(context, report)
    type(sparse_solver_context_t), intent(in) :: context
    type(linear_solver_report_t), intent(inout) :: report

    report%pattern_analysis_count = context%pattern_analysis_count
    report%reorder_count = context%reorder_count
    report%factorization_count = context%factorization_count
    report%context_solve_count = context%solve_count
    report%iterative_refinement_count = context%iterative_refinement_count
    report%symbolic_reuse_count = context%symbolic_reuse_count
    report%direct_factorization_performed = &
        context%direct_factorization_performed
    report%backend_info_primary = context%backend_info_primary
    report%backend_info_secondary = context%backend_info_secondary
  end subroutine attach_context_counters

  logical function same_sparse_pattern(context, matrix)
    type(sparse_solver_context_t), intent(in) :: context
    type(csr_matrix_t), intent(in) :: matrix

    same_sparse_pattern = .false.
    if (.not. context%pattern_analyzed) return
    if (.not. valid_csr_structure(matrix)) return
    if (matrix%nrows /= context%equation_count) return
    if (size(matrix%col_ind) /= context%structural_nnz) return
    if (size(matrix%row_ptr) /= size(context%pattern_row_ptr)) return
    if (size(matrix%col_ind) /= size(context%pattern_col_ind)) return
    if (any(matrix%row_ptr /= context%pattern_row_ptr)) return
    if (any(matrix%col_ind /= context%pattern_col_ind)) return
    same_sparse_pattern = .true.
  end function same_sparse_pattern

  logical function valid_csr_structure(matrix)
    type(csr_matrix_t), intent(in) :: matrix

    valid_csr_structure = .false.
    if (matrix%nrows < 1 .or. matrix%nrows /= matrix%ncols) return
    if (.not. allocated(matrix%row_ptr)) return
    if (.not. allocated(matrix%col_ind)) return
    if (.not. allocated(matrix%values)) return
    if (size(matrix%row_ptr) /= matrix%nrows+1) return
    if (size(matrix%col_ind) /= size(matrix%values)) return
    if (matrix%row_ptr(1) /= 1) return
    if (matrix%row_ptr(matrix%nrows+1) /= size(matrix%col_ind)+1) return
    if (any(matrix%col_ind < 1) .or. any(matrix%col_ind > matrix%ncols)) return
    valid_csr_structure = .true.
  end function valid_csr_structure

  logical function valid_matrix_class(matrix_class)
    integer, intent(in) :: matrix_class

    select case (matrix_class)
    case (DES_MATRIX_CLASS_SPD, DES_MATRIX_CLASS_SYMMETRIC_INDEFINITE, &
          DES_MATRIX_CLASS_UNSYMMETRIC)
      valid_matrix_class = .true.
    case default
      valid_matrix_class = .false.
    end select
  end function valid_matrix_class

  logical function valid_problem_class(problem_class)
    integer, intent(in) :: problem_class

    select case (problem_class)
    case (DES_PROBLEM_CLASS_DISPLACEMENT, DES_PROBLEM_CLASS_MIXED_U_P)
      valid_problem_class = .true.
    case default
      valid_problem_class = .false.
    end select
  end function valid_problem_class

  logical function valid_index_class(index_class)
    integer, intent(in) :: index_class

    valid_index_class = index_class == DES_INDEX_CLASS_INT32 .or. &
                        index_class == DES_INDEX_CLASS_INT64
  end function valid_index_class

  integer function mumps_symmetry_mode(matrix_class)
    integer, intent(in) :: matrix_class

    select case (matrix_class)
    case (DES_MATRIX_CLASS_SPD)
      mumps_symmetry_mode = 1
    case (DES_MATRIX_CLASS_SYMMETRIC_INDEFINITE)
      mumps_symmetry_mode = 2
    case (DES_MATRIX_CLASS_UNSYMMETRIC)
      mumps_symmetry_mode = 0
    case default
      mumps_symmetry_mode = -1
    end select
  end function mumps_symmetry_mode

end module des_sparse_solver_context
