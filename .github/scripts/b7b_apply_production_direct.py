from pathlib import Path


def replace_once(path, old, new):
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{path}: expected exactly one match, got {count}')
    p.write_text(text.replace(old, new, 1), encoding='utf-8')


# 1) Generic solver contract: production profile + first-class direct controls/diagnostics.
path = 'src/fortran/solvers/des_linear_solver.f90'
replace_once(path,
"""  integer, parameter, public :: DES_LINEAR_FALLBACK_NONE = 0
  integer, parameter, public :: DES_LINEAR_FALLBACK_MUMPS_UNAVAILABLE = 1

  public :: linear_solver_settings_t, linear_solver_report_t
  public :: solve_linear_system, solve_sparse_linear_system, linear_backend_name
  public :: linear_backend_is_sparse, linear_fallback_reason_name
""",
"""  integer, parameter, public :: DES_LINEAR_FALLBACK_NONE = 0
  integer, parameter, public :: DES_LINEAR_FALLBACK_MUMPS_UNAVAILABLE = 1

  integer, parameter, public :: DES_DIRECT_ORDERING_AUTO = 0
  integer, parameter, public :: DES_DIRECT_ORDERING_AMD = 1
  integer, parameter, public :: DES_DIRECT_ORDERING_AMF = 2
  integer, parameter, public :: DES_DIRECT_ORDERING_QAMD = 3

  public :: linear_solver_settings_t, linear_solver_report_t
  public :: solve_linear_system, solve_sparse_linear_system, linear_backend_name
  public :: linear_backend_is_sparse, linear_fallback_reason_name
  public :: production_linear_solver_settings
""")
replace_once(path,
"""    integer :: max_iterations = 200
    integer :: krylov_dimension = 50
    logical :: compact_krylov = .true.
  end type linear_solver_settings_t
""",
"""    integer :: max_iterations = 200
    integer :: krylov_dimension = 50
    logical :: compact_krylov = .true.

    ! Production sparse-direct kontrolleri vendor-bağımsız solver sözleşmesidir.
    ! GMRES/dense bu alanları görmezden gelir; MUMPS adapter bunları kendi
    ! ICNTL/CNTL parametrelerine çevirir.
    integer :: direct_ordering = DES_DIRECT_ORDERING_AUTO
    real(dp) :: direct_pivot_threshold = -1.0_dp
    integer :: direct_iterative_refinement_steps = 2
    real(dp) :: direct_refinement_tolerance = -1.0_dp
    integer :: direct_error_analysis = 2
    logical :: direct_out_of_core = .false.
    logical :: direct_null_pivot_detection = .true.
    real(dp) :: direct_null_pivot_tolerance = 0.0_dp
  end type linear_solver_settings_t
""")
replace_once(path,
"""    integer :: backend_info_primary = 0
    integer :: backend_info_secondary = 0
  end type linear_solver_report_t

contains
""",
"""    integer :: backend_info_primary = 0
    integer :: backend_info_secondary = 0

    ! First-class sparse-direct telemetry. MUMPS INFOG/RINFOG verileri generic
    ! rapora taşınır; diğer backend'lerde nötr değerlerde kalır.
    integer :: direct_ordering_used = -1
    integer :: direct_negative_pivot_count = 0
    integer :: direct_delayed_pivot_count = 0
    integer :: direct_null_pivot_count = 0
    integer :: direct_internal_refinement_steps = 0
    logical :: direct_out_of_core = .false.
    real(dp) :: direct_scaled_residual = huge(1.0_dp)
    real(dp) :: direct_backward_error_1 = huge(1.0_dp)
    real(dp) :: direct_backward_error_2 = huge(1.0_dp)
  end type linear_solver_report_t

contains

  pure function production_linear_solver_settings() result(settings)
    ! Ürün çözümleri için canonical profil. Generic type default'unun dense
    ! kalması legacy/reference API uyumluluğu içindir; production çağıran katman
    ! bu factory ile AUTO => available MUMPS Direct politikasını ister.
    type(linear_solver_settings_t) :: settings

    settings = linear_solver_settings_t()
    settings%backend = DES_LINEAR_BACKEND_AUTO
    settings%direct_ordering = DES_DIRECT_ORDERING_AUTO
    settings%direct_pivot_threshold = -1.0_dp
    settings%direct_iterative_refinement_steps = 2
    settings%direct_refinement_tolerance = -1.0_dp
    settings%direct_error_analysis = 2
    settings%direct_out_of_core = .false.
    settings%direct_null_pivot_detection = .true.
    settings%direct_null_pivot_tolerance = 0.0_dp
  end function production_linear_solver_settings
""")

# 2) Real MUMPS C adapter controls + rich diagnostics.
path = 'src/fortran/solvers/des_mumps_adapter.c'
replace_once(path,
"""int des_mumps_c_set_pattern(
""",
"""int des_mumps_c_configure(
    void *opaque_handle, int ordering, double pivot_threshold,
    int refinement_steps, double refinement_tolerance, int error_analysis,
    int out_of_core, int null_pivot_detection, double null_pivot_tolerance,
    int *info_primary, int *info_secondary)
{
  des_mumps_handle_t *handle = (des_mumps_handle_t *)opaque_handle;

  if (handle == NULL || refinement_steps < 0 ||
      error_analysis < 0 || error_analysis > 2 ||
      (out_of_core != 0 && out_of_core != 1) ||
      (null_pivot_detection != 0 && null_pivot_detection != 1)) {
    return -1;
  }

  /* ICNTL(7), CNTL(1), ICNTL(10), CNTL(2), ICNTL(11), ICNTL(22),
   * ICNTL(24), CNTL(3). Bu ayarlar analyze/factorize öncesi yapılır. */
  handle->id.icntl[6] = (MUMPS_INT)ordering;
  handle->id.cntl[0] = pivot_threshold;
  handle->id.icntl[9] = (MUMPS_INT)refinement_steps;
  handle->id.cntl[1] = refinement_tolerance;
  handle->id.icntl[10] = (MUMPS_INT)error_analysis;
  handle->id.icntl[21] = (MUMPS_INT)out_of_core;
  handle->id.icntl[23] = (MUMPS_INT)null_pivot_detection;
  handle->id.cntl[2] = null_pivot_tolerance;

  des_mumps_copy_info(handle, info_primary, info_secondary);
  return 0;
}

int des_mumps_c_get_diagnostics(
    void *opaque_handle, int *ordering_used, int *negative_pivots,
    int *delayed_pivots, int *null_pivots, int *refinement_steps,
    int *out_of_core, double *scaled_residual, double *backward_error_1,
    double *backward_error_2)
{
  des_mumps_handle_t *handle = (des_mumps_handle_t *)opaque_handle;
  if (handle == NULL || ordering_used == NULL || negative_pivots == NULL ||
      delayed_pivots == NULL || null_pivots == NULL ||
      refinement_steps == NULL || out_of_core == NULL ||
      scaled_residual == NULL || backward_error_1 == NULL ||
      backward_error_2 == NULL) {
    return -1;
  }

  *ordering_used = (int)handle->id.infog[6];       /* INFOG(7)  */
  *negative_pivots = (int)handle->id.infog[11];   /* INFOG(12) */
  *delayed_pivots = (int)handle->id.infog[12];    /* INFOG(13) */
  *refinement_steps = (int)handle->id.infog[14];  /* INFOG(15) */
  *null_pivots = (int)handle->id.infog[27];       /* INFOG(28) */
  *out_of_core = (handle->id.icntl[21] == 1) ? 1 : 0;
  *scaled_residual = handle->id.rinfog[5];         /* RINFOG(6) */
  *backward_error_1 = handle->id.rinfog[6];        /* RINFOG(7) */
  *backward_error_2 = handle->id.rinfog[7];        /* RINFOG(8) */
  return 0;
}

int des_mumps_c_set_pattern(
""")

# 3) Fortran MUMPS bridge.
path = 'src/fortran/solvers/des_mumps_backend.f90'
replace_once(path,
"""  type, public :: mumps_backend_handle_t
    type(c_ptr) :: ptr = c_null_ptr
  end type mumps_backend_handle_t

  public :: mumps_backend_create
  public :: mumps_backend_set_pattern
""",
"""  type, public :: mumps_backend_handle_t
    type(c_ptr) :: ptr = c_null_ptr
  end type mumps_backend_handle_t

  type, public :: mumps_backend_diagnostics_t
    integer :: ordering_used = -1
    integer :: negative_pivot_count = 0
    integer :: delayed_pivot_count = 0
    integer :: null_pivot_count = 0
    integer :: internal_refinement_steps = 0
    logical :: out_of_core = .false.
    real(dp) :: scaled_residual = huge(1.0_dp)
    real(dp) :: backward_error_1 = huge(1.0_dp)
    real(dp) :: backward_error_2 = huge(1.0_dp)
  end type mumps_backend_diagnostics_t

  public :: mumps_backend_create
  public :: mumps_backend_configure
  public :: mumps_backend_get_diagnostics
  public :: mumps_backend_set_pattern
""")
replace_once(path,
"""    function des_mumps_c_set_pattern( &
""",
"""    function des_mumps_c_configure( &
        handle,ordering,pivot_threshold,refinement_steps,refinement_tolerance, &
        error_analysis,out_of_core,null_pivot_detection,null_pivot_tolerance, &
        info_primary,info_secondary) &
        bind(C,name='des_mumps_c_configure') result(rc)
      import :: c_double, c_int, c_ptr
      type(c_ptr), value :: handle
      integer(c_int), value :: ordering, refinement_steps, error_analysis
      integer(c_int), value :: out_of_core, null_pivot_detection
      real(c_double), value :: pivot_threshold, refinement_tolerance
      real(c_double), value :: null_pivot_tolerance
      integer(c_int), intent(out) :: info_primary, info_secondary
      integer(c_int) :: rc
    end function des_mumps_c_configure

    function des_mumps_c_get_diagnostics( &
        handle,ordering_used,negative_pivots,delayed_pivots,null_pivots, &
        refinement_steps,out_of_core,scaled_residual,backward_error_1, &
        backward_error_2) bind(C,name='des_mumps_c_get_diagnostics') result(rc)
      import :: c_double, c_int, c_ptr
      type(c_ptr), value :: handle
      integer(c_int), intent(out) :: ordering_used, negative_pivots
      integer(c_int), intent(out) :: delayed_pivots, null_pivots
      integer(c_int), intent(out) :: refinement_steps, out_of_core
      real(c_double), intent(out) :: scaled_residual, backward_error_1
      real(c_double), intent(out) :: backward_error_2
      integer(c_int) :: rc
    end function des_mumps_c_get_diagnostics

    function des_mumps_c_set_pattern( &
""")
replace_once(path,
"""  subroutine mumps_backend_set_pattern(handle,matrix,status,info_primary,info_secondary)
""",
"""  subroutine mumps_backend_configure( &
      handle,ordering,pivot_threshold,refinement_steps,refinement_tolerance, &
      error_analysis,out_of_core,null_pivot_detection,null_pivot_tolerance, &
      status,info_primary,info_secondary)
    type(mumps_backend_handle_t), intent(inout) :: handle
    integer, intent(in) :: ordering, refinement_steps, error_analysis
    real(dp), intent(in) :: pivot_threshold, refinement_tolerance
    logical, intent(in) :: out_of_core, null_pivot_detection
    real(dp), intent(in) :: null_pivot_tolerance
    integer, intent(out) :: status, info_primary, info_secondary

    integer(c_int) :: rc, c_info_primary, c_info_secondary

    status = DES_STATUS_OK
    info_primary = 0
    info_secondary = 0
    if (.not. c_associated(handle%ptr)) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    rc = des_mumps_c_configure( &
        handle%ptr,int(ordering,c_int),real(pivot_threshold,c_double), &
        int(refinement_steps,c_int),real(refinement_tolerance,c_double), &
        int(error_analysis,c_int),merge(1_c_int,0_c_int,out_of_core), &
        merge(1_c_int,0_c_int,null_pivot_detection), &
        real(null_pivot_tolerance,c_double),c_info_primary,c_info_secondary)
    info_primary = int(c_info_primary)
    info_secondary = int(c_info_secondary)
    if (rc /= 0_c_int) status = DES_ERROR_INVALID_CONSTRAINT
  end subroutine mumps_backend_configure

  subroutine mumps_backend_get_diagnostics(handle,diagnostics,status)
    type(mumps_backend_handle_t), intent(in) :: handle
    type(mumps_backend_diagnostics_t), intent(out) :: diagnostics
    integer, intent(out) :: status

    integer(c_int) :: rc, ordering, negative_pivots, delayed_pivots
    integer(c_int) :: null_pivots, refinement_steps, out_of_core
    real(c_double) :: scaled_residual, backward_error_1, backward_error_2

    diagnostics = mumps_backend_diagnostics_t()
    status = DES_STATUS_OK
    if (.not. c_associated(handle%ptr)) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    rc = des_mumps_c_get_diagnostics( &
        handle%ptr,ordering,negative_pivots,delayed_pivots,null_pivots, &
        refinement_steps,out_of_core,scaled_residual,backward_error_1, &
        backward_error_2)
    if (rc /= 0_c_int) then
      status = DES_ERROR_LINEAR_SOLVE
      return
    end if

    diagnostics%ordering_used = int(ordering)
    diagnostics%negative_pivot_count = int(negative_pivots)
    diagnostics%delayed_pivot_count = int(delayed_pivots)
    diagnostics%null_pivot_count = int(null_pivots)
    diagnostics%internal_refinement_steps = int(refinement_steps)
    diagnostics%out_of_core = out_of_core /= 0_c_int
    diagnostics%scaled_residual = real(scaled_residual,dp)
    diagnostics%backward_error_1 = real(backward_error_1,dp)
    diagnostics%backward_error_2 = real(backward_error_2,dp)
  end subroutine mumps_backend_get_diagnostics

  subroutine mumps_backend_set_pattern(handle,matrix,status,info_primary,info_secondary)
""")

# 4) Non-MUMPS stub keeps exactly the same public contract.
path = 'src/fortran/solvers/des_mumps_backend_stub.f90'
replace_once(path,
"""  type, public :: mumps_backend_handle_t
    integer :: placeholder = 0
  end type mumps_backend_handle_t

  public :: mumps_backend_create
  public :: mumps_backend_set_pattern
""",
"""  type, public :: mumps_backend_handle_t
    integer :: placeholder = 0
  end type mumps_backend_handle_t

  type, public :: mumps_backend_diagnostics_t
    integer :: ordering_used = -1
    integer :: negative_pivot_count = 0
    integer :: delayed_pivot_count = 0
    integer :: null_pivot_count = 0
    integer :: internal_refinement_steps = 0
    logical :: out_of_core = .false.
    real(dp) :: scaled_residual = huge(1.0_dp)
    real(dp) :: backward_error_1 = huge(1.0_dp)
    real(dp) :: backward_error_2 = huge(1.0_dp)
  end type mumps_backend_diagnostics_t

  public :: mumps_backend_create
  public :: mumps_backend_configure
  public :: mumps_backend_get_diagnostics
  public :: mumps_backend_set_pattern
""")
replace_once(path,
"""  subroutine mumps_backend_set_pattern(handle,matrix,status,info_primary,info_secondary)
""",
"""  subroutine mumps_backend_configure( &
      handle,ordering,pivot_threshold,refinement_steps,refinement_tolerance, &
      error_analysis,out_of_core,null_pivot_detection,null_pivot_tolerance, &
      status,info_primary,info_secondary)
    type(mumps_backend_handle_t), intent(inout) :: handle
    integer, intent(in) :: ordering, refinement_steps, error_analysis
    real(dp), intent(in) :: pivot_threshold, refinement_tolerance
    logical, intent(in) :: out_of_core, null_pivot_detection
    real(dp), intent(in) :: null_pivot_tolerance
    integer, intent(out) :: status, info_primary, info_secondary

    handle%placeholder = handle%placeholder + ordering + 0*refinement_steps + &
        0*error_analysis + 0*int(pivot_threshold+refinement_tolerance+ &
        null_pivot_tolerance) + 0*merge(1,0,out_of_core) + &
        0*merge(1,0,null_pivot_detection)
    info_primary = 0
    info_secondary = 0
    status = DES_ERROR_UNSUPPORTED_LINEAR_BACKEND
  end subroutine mumps_backend_configure

  subroutine mumps_backend_get_diagnostics(handle,diagnostics,status)
    type(mumps_backend_handle_t), intent(in) :: handle
    type(mumps_backend_diagnostics_t), intent(out) :: diagnostics
    integer, intent(out) :: status

    diagnostics = mumps_backend_diagnostics_t()
    diagnostics%ordering_used = handle%placeholder - handle%placeholder - 1
    status = DES_ERROR_UNSUPPORTED_LINEAR_BACKEND
  end subroutine mumps_backend_get_diagnostics

  subroutine mumps_backend_set_pattern(handle,matrix,status,info_primary,info_secondary)
""")

# 5) Sparse context maps generic production settings to MUMPS and exports telemetry.
path = 'src/fortran/solvers/des_sparse_solver_context.f90'
replace_once(path,
"""                                DES_LINEAR_BACKEND_MUMPS_DIRECT, &
                                DES_LINEAR_FALLBACK_NONE, &
                                DES_LINEAR_FALLBACK_MUMPS_UNAVAILABLE
""",
"""                                DES_LINEAR_BACKEND_MUMPS_DIRECT, &
                                DES_LINEAR_FALLBACK_NONE, &
                                DES_LINEAR_FALLBACK_MUMPS_UNAVAILABLE, &
                                DES_DIRECT_ORDERING_AUTO, DES_DIRECT_ORDERING_AMD, &
                                DES_DIRECT_ORDERING_AMF, DES_DIRECT_ORDERING_QAMD
""")
replace_once(path,
"""  use des_mumps_backend, only : DES_MUMPS_AVAILABLE, mumps_backend_handle_t, &
                                mumps_backend_create, &
                                mumps_backend_set_pattern, &
                                mumps_backend_analyze, &
                                mumps_backend_factorize, &
                                mumps_backend_solve, &
                                mumps_backend_destroy
""",
"""  use des_mumps_backend, only : DES_MUMPS_AVAILABLE, mumps_backend_handle_t, &
                                mumps_backend_diagnostics_t, &
                                mumps_backend_create, mumps_backend_configure, &
                                mumps_backend_get_diagnostics, &
                                mumps_backend_set_pattern, &
                                mumps_backend_analyze, &
                                mumps_backend_factorize, &
                                mumps_backend_solve, &
                                mumps_backend_destroy
""")
replace_once(path,
"""    integer :: backend_info_primary = 0
    integer :: backend_info_secondary = 0
    logical :: active = .false.
""",
"""    integer :: backend_info_primary = 0
    integer :: backend_info_secondary = 0
    integer :: direct_ordering_used = -1
    integer :: direct_negative_pivot_count = 0
    integer :: direct_delayed_pivot_count = 0
    integer :: direct_null_pivot_count = 0
    integer :: direct_internal_refinement_steps = 0
    logical :: direct_out_of_core = .false.
    real(dp) :: direct_scaled_residual = huge(1.0_dp)
    real(dp) :: direct_backward_error_1 = huge(1.0_dp)
    real(dp) :: direct_backward_error_2 = huge(1.0_dp)
    logical :: active = .false.
""")
# same block occurs a second time for context; replace next once
replace_once(path,
"""    integer :: backend_info_primary = 0
    integer :: backend_info_secondary = 0
    logical :: active = .false.
""",
"""    integer :: backend_info_primary = 0
    integer :: backend_info_secondary = 0
    integer :: direct_ordering_used = -1
    integer :: direct_negative_pivot_count = 0
    integer :: direct_delayed_pivot_count = 0
    integer :: direct_null_pivot_count = 0
    integer :: direct_internal_refinement_steps = 0
    logical :: direct_out_of_core = .false.
    real(dp) :: direct_scaled_residual = huge(1.0_dp)
    real(dp) :: direct_backward_error_1 = huge(1.0_dp)
    real(dp) :: direct_backward_error_2 = huge(1.0_dp)
    logical :: active = .false.
""")
replace_once(path,
"""      call mumps_backend_create( &
          context%mumps_handle,mumps_symmetry_mode(matrix_class),status, &
          context%backend_info_primary,context%backend_info_secondary)
      if (status /= DES_STATUS_OK) return
""",
"""      call mumps_backend_create( &
          context%mumps_handle,mumps_symmetry_mode(matrix_class),status, &
          context%backend_info_primary,context%backend_info_secondary)
      if (status /= DES_STATUS_OK) return
      call mumps_backend_configure( &
          context%mumps_handle,mumps_ordering_code(context%settings%direct_ordering), &
          context%settings%direct_pivot_threshold, &
          context%settings%direct_iterative_refinement_steps, &
          context%settings%direct_refinement_tolerance, &
          context%settings%direct_error_analysis,context%settings%direct_out_of_core, &
          context%settings%direct_null_pivot_detection, &
          context%settings%direct_null_pivot_tolerance,status, &
          context%backend_info_primary,context%backend_info_secondary)
      if (status /= DES_STATUS_OK) then
        call mumps_backend_destroy(context%mumps_handle)
        return
      end if
""")
replace_once(path,
"""      context%direct_factorization_performed = .true.

    case default
""",
"""      context%direct_factorization_performed = .true.
      call refresh_mumps_diagnostics(context,status)
      if (status /= DES_STATUS_OK) then
        context%numeric_ready = .false.
        context%direct_factorization_performed = .false.
        return
      end if
      ! Null-pivot detection production'da sessiz singular solve yerine nonlinear
      ! cutback/failure zincirini tetikler.
      if (context%direct_null_pivot_count > 0) then
        status = DES_ERROR_LINEAR_SOLVE
        context%numeric_ready = .false.
        context%direct_factorization_performed = .false.
        return
      end if

    case default
""")
replace_once(path,
"""      if (backend_status /= DES_STATUS_OK) then
        report%status = backend_status
        report%converged = .false.
      else
""",
"""      if (backend_status /= DES_STATUS_OK) then
        report%status = backend_status
        report%converged = .false.
      else
        call refresh_mumps_diagnostics(context,backend_status)
        if (backend_status /= DES_STATUS_OK) then
          report%status = backend_status
          report%converged = .false.
          call attach_context_counters(context,report)
          context%last_linear_report = report
          return
        end if
""")
replace_once(path,
"""    diagnostics%backend_info_primary = context%backend_info_primary
    diagnostics%backend_info_secondary = context%backend_info_secondary
    diagnostics%active = context%active
""",
"""    diagnostics%backend_info_primary = context%backend_info_primary
    diagnostics%backend_info_secondary = context%backend_info_secondary
    diagnostics%direct_ordering_used = context%direct_ordering_used
    diagnostics%direct_negative_pivot_count = context%direct_negative_pivot_count
    diagnostics%direct_delayed_pivot_count = context%direct_delayed_pivot_count
    diagnostics%direct_null_pivot_count = context%direct_null_pivot_count
    diagnostics%direct_internal_refinement_steps = &
        context%direct_internal_refinement_steps
    diagnostics%direct_out_of_core = context%direct_out_of_core
    diagnostics%direct_scaled_residual = context%direct_scaled_residual
    diagnostics%direct_backward_error_1 = context%direct_backward_error_1
    diagnostics%direct_backward_error_2 = context%direct_backward_error_2
    diagnostics%active = context%active
""")
replace_once(path,
"""    report%backend_info_primary = context%backend_info_primary
    report%backend_info_secondary = context%backend_info_secondary
  end subroutine attach_context_counters
""",
"""    report%backend_info_primary = context%backend_info_primary
    report%backend_info_secondary = context%backend_info_secondary
    report%direct_ordering_used = context%direct_ordering_used
    report%direct_negative_pivot_count = context%direct_negative_pivot_count
    report%direct_delayed_pivot_count = context%direct_delayed_pivot_count
    report%direct_null_pivot_count = context%direct_null_pivot_count
    report%direct_internal_refinement_steps = context%direct_internal_refinement_steps
    report%direct_out_of_core = context%direct_out_of_core
    report%direct_scaled_residual = context%direct_scaled_residual
    report%direct_backward_error_1 = context%direct_backward_error_1
    report%direct_backward_error_2 = context%direct_backward_error_2
  end subroutine attach_context_counters

  subroutine refresh_mumps_diagnostics(context,status)
    type(sparse_solver_context_t), intent(inout) :: context
    integer, intent(out) :: status
    type(mumps_backend_diagnostics_t) :: diagnostics

    call mumps_backend_get_diagnostics(context%mumps_handle,diagnostics,status)
    if (status /= DES_STATUS_OK) return
    context%direct_ordering_used = diagnostics%ordering_used
    context%direct_negative_pivot_count = diagnostics%negative_pivot_count
    context%direct_delayed_pivot_count = diagnostics%delayed_pivot_count
    context%direct_null_pivot_count = diagnostics%null_pivot_count
    context%direct_internal_refinement_steps = diagnostics%internal_refinement_steps
    context%direct_out_of_core = diagnostics%out_of_core
    context%direct_scaled_residual = diagnostics%scaled_residual
    context%direct_backward_error_1 = diagnostics%backward_error_1
    context%direct_backward_error_2 = diagnostics%backward_error_2
  end subroutine refresh_mumps_diagnostics
""")
replace_once(path,
"""  integer function mumps_symmetry_mode(matrix_class)
""",
"""  integer function mumps_ordering_code(ordering)
    integer, intent(in) :: ordering

    select case (ordering)
    case (DES_DIRECT_ORDERING_AUTO)
      mumps_ordering_code = 7
    case (DES_DIRECT_ORDERING_AMD)
      mumps_ordering_code = 0
    case (DES_DIRECT_ORDERING_AMF)
      mumps_ordering_code = 2
    case (DES_DIRECT_ORDERING_QAMD)
      mumps_ordering_code = 6
    case default
      mumps_ordering_code = 7
    end select
  end function mumps_ordering_code

  integer function mumps_symmetry_mode(matrix_class)
""")

# 6) AUTO test validates canonical production profile and explicit-direct fail-fast.
path = 'tests/test_auto_sparse_solver_policy.f90'
replace_once(path,
"""  use des_status, only : DES_STATUS_OK
""",
"""  use des_status, only : DES_STATUS_OK, DES_ERROR_UNSUPPORTED_LINEAR_BACKEND
""")
replace_once(path,
"""  use des_linear_solver, only : linear_solver_settings_t, linear_solver_report_t, &
      DES_LINEAR_BACKEND_AUTO, DES_LINEAR_BACKEND_STDLIB_CSR_GMRES, &
""",
"""  use des_linear_solver, only : linear_solver_settings_t, linear_solver_report_t, &
      production_linear_solver_settings, &
      DES_LINEAR_BACKEND_AUTO, DES_LINEAR_BACKEND_STDLIB_CSR_GMRES, &
""")
replace_once(path,
"""  settings = linear_solver_settings_t()
  settings%backend = DES_LINEAR_BACKEND_AUTO
""",
"""  settings = production_linear_solver_settings()
  if (settings%backend /= DES_LINEAR_BACKEND_AUTO .or. &
      settings%direct_iterative_refinement_steps < 1 .or. &
      settings%direct_error_analysis /= 2 .or. &
      .not. settings%direct_null_pivot_detection) then
    error stop 'Production solver profili direct-first kontrolleri tasimiyor.'
  end if
""")
replace_once(path,
"""  call release_sparse_solver_context(context)
  write(*,'(A,I0)') 'AUTO requested backend = ',DES_LINEAR_BACKEND_AUTO
""",
"""  call release_sparse_solver_context(context)

  if (.not. DES_MUMPS_AVAILABLE) then
    settings = production_linear_solver_settings()
    settings%backend = DES_LINEAR_BACKEND_MUMPS_DIRECT
    call create_sparse_solver_context( &
        context,settings,DES_MATRIX_CLASS_SYMMETRIC_INDEFINITE, &
        DES_PROBLEM_CLASS_MIXED_U_P,DES_INDEX_CLASS_INT32,status)
    if (status /= DES_ERROR_UNSUPPORTED_LINEAR_BACKEND) then
      error stop 'Explicit MUMPS unavailable durumda fail-fast yapmadi.'
    end if
    if (context%fallback_used) then
      error stop 'Explicit MUMPS istegi sessiz GMRES fallback yapti.'
    end if
  end if

  write(*,'(A,I0)') 'AUTO requested backend = ',DES_LINEAR_BACKEND_AUTO
""")

# 7) Direct context test validates production telemetry.
path = 'tests/test_mumps_sparse_solver_context.f90'
replace_once(path,
"""program test_mumps_sparse_solver_context
  use des_kinds, only : dp
""",
"""program test_mumps_sparse_solver_context
  use, intrinsic :: ieee_arithmetic, only : ieee_is_finite
  use des_kinds, only : dp
""")
replace_once(path,
"""  use des_linear_solver, only : linear_solver_settings_t, &
                                linear_solver_report_t, &
                                DES_LINEAR_BACKEND_MUMPS_DIRECT
""",
"""  use des_linear_solver, only : linear_solver_settings_t, &
                                linear_solver_report_t, &
                                production_linear_solver_settings, &
                                DES_LINEAR_BACKEND_MUMPS_DIRECT
""")
replace_once(path,
"""  settings = linear_solver_settings_t()
  settings%backend = DES_LINEAR_BACKEND_MUMPS_DIRECT
""",
"""  settings = production_linear_solver_settings()
  settings%backend = DES_LINEAR_BACKEND_MUMPS_DIRECT
""")
replace_once(path,
"""  if (report%backend_info_primary < 0) then
    error stop 'MUMPS basarili cozumde negatif INFOG(1) raporladi.'
  end if
""",
"""  if (report%backend_info_primary < 0) then
    error stop 'MUMPS basarili cozumde negatif INFOG(1) raporladi.'
  end if
  if (report%direct_ordering_used < 0) then
    error stop 'MUMPS production ordering telemetry raporlanmadi.'
  end if
  if (report%direct_null_pivot_count /= 0) then
    error stop 'Nonsingular saddle-point sistemde null pivot raporlandi.'
  end if
  if (report%direct_negative_pivot_count < 0 .or. &
      report%direct_delayed_pivot_count < 0 .or. &
      report%direct_internal_refinement_steps < 0) then
    error stop 'MUMPS pivot/refinement telemetry gecersiz.'
  end if
  if (.not. ieee_is_finite(report%direct_scaled_residual) .or. &
      .not. ieee_is_finite(report%direct_backward_error_1) .or. &
      .not. ieee_is_finite(report%direct_backward_error_2)) then
    error stop 'MUMPS backward-error telemetry finite degil.'
  end if
  if (report%direct_out_of_core) then
    error stop 'Production workstation default beklenmedik OOC kullandi.'
  end if
""")
replace_once(path,
"""  if (.not. diagnostics%direct_factorization_performed) then
    error stop 'MUMPS diagnostic direct factorization flag yanlis.'
  end if
""",
"""  if (.not. diagnostics%direct_factorization_performed) then
    error stop 'MUMPS diagnostic direct factorization flag yanlis.'
  end if
  if (diagnostics%direct_null_pivot_count /= 0) then
    error stop 'MUMPS diagnostic null pivot sayaci sifir olmaliydi.'
  end if
  if (diagnostics%direct_ordering_used < 0) then
    error stop 'MUMPS diagnostic ordering bilgisi eksik.'
  end if
""")
replace_once(path,
"""  write(*,'(A,I0,A,I0)') 'MUMPS INFOG(1/2) = ', &
      report%backend_info_primary,' / ',report%backend_info_secondary
""",
"""  write(*,'(A,I0,A,I0)') 'MUMPS INFOG(1/2) = ', &
      report%backend_info_primary,' / ',report%backend_info_secondary
  write(*,'(A,I0)') 'MUMPS ordering used = ',report%direct_ordering_used
  write(*,'(A,I0)') 'MUMPS negative pivots = ',report%direct_negative_pivot_count
  write(*,'(A,I0)') 'MUMPS delayed pivots = ',report%direct_delayed_pivot_count
  write(*,'(A,I0)') 'MUMPS null pivots = ',report%direct_null_pivot_count
  write(*,'(A,I0)') 'MUMPS internal refinement steps = ', &
      report%direct_internal_refinement_steps
  write(*,'(A,ES12.4)') 'MUMPS scaled residual = ',report%direct_scaled_residual
  write(*,'(A,ES12.4)') 'MUMPS backward error 1 = ',report%direct_backward_error_1
  write(*,'(A,ES12.4)') 'MUMPS backward error 2 = ',report%direct_backward_error_2
""")

# Basic hygiene.
for f in [
    'src/fortran/solvers/des_linear_solver.f90',
    'src/fortran/solvers/des_mumps_backend.f90',
    'src/fortran/solvers/des_mumps_backend_stub.f90',
    'src/fortran/solvers/des_sparse_solver_context.f90',
    'tests/test_auto_sparse_solver_policy.f90',
    'tests/test_mumps_sparse_solver_context.f90',
]:
    for i, line in enumerate(Path(f).read_text(encoding='utf-8').splitlines(), 1):
        if len(line) > 132:
            raise RuntimeError(f'{f}:{i}: Fortran line exceeds 132 columns ({len(line)})')

print('B7b production sparse-direct patch applied successfully.')
