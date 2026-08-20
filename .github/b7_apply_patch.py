from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file_path = Path(path)
    text = file_path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{path}: beklenen blok sayısı 1, bulunan {count}")
    file_path.write_text(text.replace(old, new, 1), encoding="utf-8")


def replace_count(path: str, old: str, new: str, expected: int) -> None:
    file_path = Path(path)
    text = file_path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != expected:
        raise RuntimeError(f"{path}: beklenen blok sayısı {expected}, bulunan {count}")
    file_path.write_text(text.replace(old, new), encoding="utf-8")


linear = "src/fortran/solvers/des_linear_solver.f90"
replace_once(
    linear,
    "  integer, parameter, public :: DES_LINEAR_BACKEND_STDLIB_DENSE = 1\n"
    "  integer, parameter, public :: DES_LINEAR_BACKEND_STDLIB_CSR_GMRES = 2\n"
    "  integer, parameter, public :: DES_LINEAR_BACKEND_MUMPS_DIRECT = 3\n",
    "  integer, parameter, public :: DES_LINEAR_BACKEND_AUTO = 0\n"
    "  integer, parameter, public :: DES_LINEAR_BACKEND_STDLIB_DENSE = 1\n"
    "  integer, parameter, public :: DES_LINEAR_BACKEND_STDLIB_CSR_GMRES = 2\n"
    "  integer, parameter, public :: DES_LINEAR_BACKEND_MUMPS_DIRECT = 3\n\n"
    "  integer, parameter, public :: DES_LINEAR_FALLBACK_NONE = 0\n"
    "  integer, parameter, public :: DES_LINEAR_FALLBACK_MUMPS_UNAVAILABLE = 1\n",
)
replace_once(
    linear,
    "  public :: solve_linear_system, solve_sparse_linear_system, linear_backend_name\n"
    "  public :: linear_backend_is_sparse\n",
    "  public :: solve_linear_system, solve_sparse_linear_system, linear_backend_name\n"
    "  public :: linear_backend_is_sparse, linear_fallback_reason_name\n",
)
replace_once(
    linear,
    "    ! Dense LAPACK küçük doğrulama problemleri için reference/fallback olarak kalır.\n"
    "    ! CSR GMRES yolu sparse mimariyi doğrulayan portable bootstrap backend'dir.\n"
    "    ! MUMPS direct backend yalnız stateful sparse context arkasından çağrılır.\n",
    "    ! Dense LAPACK küçük doğrulama problemleri için reference/fallback olarak kalır.\n"
    "    ! CSR GMRES yolu sparse mimariyi doğrulayan portable bootstrap backend'dir.\n"
    "    ! MUMPS direct backend yalnız stateful sparse context arkasından çağrılır.\n"
    "    ! AUTO explicit seçilirse karar SparseSolverContext içinde verilir; varsayılan\n"
    "    ! dense davranış B7'de geriye uyumluluk için bilinçli olarak değiştirilmez.\n",
)
replace_once(
    linear,
    "  type :: linear_solver_report_t\n"
    "    integer :: status = DES_STATUS_OK\n"
    "    integer :: backend = DES_LINEAR_BACKEND_STDLIB_DENSE\n"
    "    integer :: equation_count = 0\n",
    "  type :: linear_solver_report_t\n"
    "    integer :: status = DES_STATUS_OK\n"
    "    integer :: requested_backend = DES_LINEAR_BACKEND_STDLIB_DENSE\n"
    "    integer :: backend = DES_LINEAR_BACKEND_STDLIB_DENSE\n"
    "    logical :: fallback_used = .false.\n"
    "    integer :: fallback_reason = DES_LINEAR_FALLBACK_NONE\n"
    "    integer :: equation_count = 0\n",
)
replace_count(
    linear,
    "    report = linear_solver_report_t()\n"
    "    report%backend = active_settings%backend\n"
    "    report%equation_count = size(b)\n",
    "    report = linear_solver_report_t()\n"
    "    report%requested_backend = active_settings%backend\n"
    "    report%backend = active_settings%backend\n"
    "    report%equation_count = size(b)\n",
    2,
)
replace_once(
    linear,
    "    linear_backend_is_sparse = &\n"
    "        backend == DES_LINEAR_BACKEND_STDLIB_CSR_GMRES .or. &\n"
    "        backend == DES_LINEAR_BACKEND_MUMPS_DIRECT\n",
    "    linear_backend_is_sparse = &\n"
    "        backend == DES_LINEAR_BACKEND_AUTO .or. &\n"
    "        backend == DES_LINEAR_BACKEND_STDLIB_CSR_GMRES .or. &\n"
    "        backend == DES_LINEAR_BACKEND_MUMPS_DIRECT\n",
)
replace_once(
    linear,
    "    select case (backend)\n"
    "    case (DES_LINEAR_BACKEND_STDLIB_DENSE)\n",
    "    select case (backend)\n"
    "    case (DES_LINEAR_BACKEND_AUTO)\n"
    "      name = 'AUTO sparse policy'\n"
    "    case (DES_LINEAR_BACKEND_STDLIB_DENSE)\n",
)
replace_once(
    linear,
    "  end function linear_backend_name\n\nend module des_linear_solver\n",
    "  end function linear_backend_name\n\n"
    "  pure function linear_fallback_reason_name(reason) result(name)\n"
    "    integer, intent(in) :: reason\n"
    "    character(len=64) :: name\n\n"
    "    select case (reason)\n"
    "    case (DES_LINEAR_FALLBACK_NONE)\n"
    "      name = 'fallback yok'\n"
    "    case (DES_LINEAR_FALLBACK_MUMPS_UNAVAILABLE)\n"
    "      name = 'MUMPS kullanilabilir degil; portable GMRES secildi'\n"
    "    case default\n"
    "      name = 'bilinmeyen fallback nedeni'\n"
    "    end select\n"
    "  end function linear_fallback_reason_name\n\n"
    "end module des_linear_solver\n",
)

context = "src/fortran/solvers/des_sparse_solver_context.f90"
replace_once(
    context,
    "                                solve_sparse_linear_system, &\n"
    "                                DES_LINEAR_BACKEND_STDLIB_CSR_GMRES, &\n"
    "                                DES_LINEAR_BACKEND_MUMPS_DIRECT\n",
    "                                solve_sparse_linear_system, &\n"
    "                                DES_LINEAR_BACKEND_AUTO, &\n"
    "                                DES_LINEAR_BACKEND_STDLIB_CSR_GMRES, &\n"
    "                                DES_LINEAR_BACKEND_MUMPS_DIRECT, &\n"
    "                                DES_LINEAR_FALLBACK_NONE, &\n"
    "                                DES_LINEAR_FALLBACK_MUMPS_UNAVAILABLE\n",
)
replace_once(
    context,
    "  type, public :: sparse_solver_diagnostics_t\n"
    "    integer :: backend = 0\n",
    "  type, public :: sparse_solver_diagnostics_t\n"
    "    integer :: requested_backend = 0\n"
    "    integer :: backend = 0\n"
    "    logical :: fallback_used = .false.\n"
    "    integer :: fallback_reason = DES_LINEAR_FALLBACK_NONE\n",
)
replace_once(
    context,
    "  type, public :: sparse_solver_context_t\n"
    "    type(linear_solver_settings_t) :: settings\n"
    "    integer :: matrix_class = DES_MATRIX_CLASS_UNKNOWN\n",
    "  type, public :: sparse_solver_context_t\n"
    "    type(linear_solver_settings_t) :: settings\n"
    "    integer :: requested_backend = 0\n"
    "    logical :: fallback_used = .false.\n"
    "    integer :: fallback_reason = DES_LINEAR_FALLBACK_NONE\n"
    "    integer :: matrix_class = DES_MATRIX_CLASS_UNKNOWN\n",
)
replace_once(
    context,
    "    context%settings = settings\n"
    "    context%matrix_class = matrix_class\n"
    "    context%problem_class = problem_class\n"
    "    context%index_class = index_class\n"
    "    context%last_linear_report = linear_solver_report_t()\n"
    "    context%last_linear_report%backend = settings%backend\n"
    "    status = DES_STATUS_OK\n",
    "    context%settings = settings\n"
    "    context%requested_backend = settings%backend\n"
    "    context%fallback_used = .false.\n"
    "    context%fallback_reason = DES_LINEAR_FALLBACK_NONE\n"
    "    context%matrix_class = matrix_class\n"
    "    context%problem_class = problem_class\n"
    "    context%index_class = index_class\n"
    "    context%last_linear_report = linear_solver_report_t()\n"
    "    context%last_linear_report%requested_backend = settings%backend\n"
    "    context%last_linear_report%backend = settings%backend\n"
    "    status = DES_STATUS_OK\n",
)
replace_once(
    context,
    "    if (.not. valid_matrix_class(matrix_class) .or. &\n"
    "        .not. valid_problem_class(problem_class) .or. &\n"
    "        .not. valid_index_class(index_class)) then\n"
    "      status = DES_ERROR_INVALID_CONSTRAINT\n"
    "      return\n"
    "    end if\n\n"
    "    select case (settings%backend)\n",
    "    if (.not. valid_matrix_class(matrix_class) .or. &\n"
    "        .not. valid_problem_class(problem_class) .or. &\n"
    "        .not. valid_index_class(index_class)) then\n"
    "      status = DES_ERROR_INVALID_CONSTRAINT\n"
    "      return\n"
    "    end if\n\n"
    "    call resolve_sparse_backend(context,status)\n"
    "    if (status /= DES_STATUS_OK) return\n"
    "    context%last_linear_report%backend = context%settings%backend\n"
    "    context%last_linear_report%fallback_used = context%fallback_used\n"
    "    context%last_linear_report%fallback_reason = context%fallback_reason\n\n"
    "    select case (context%settings%backend)\n",
)
replace_once(
    context,
    "      if (settings%backend == DES_LINEAR_BACKEND_MUMPS_DIRECT) then\n",
    "      if (context%settings%backend == DES_LINEAR_BACKEND_MUMPS_DIRECT) then\n",
)
replace_count(
    context,
    "    report = linear_solver_report_t()\n"
    "    report%backend = context%settings%backend\n"
    "    report%equation_count = size(b)\n",
    "    report = linear_solver_report_t()\n"
    "    report%requested_backend = context%requested_backend\n"
    "    report%backend = context%settings%backend\n"
    "    report%fallback_used = context%fallback_used\n"
    "    report%fallback_reason = context%fallback_reason\n"
    "    report%equation_count = size(b)\n",
    2,
)
replace_once(
    context,
    "    diagnostics%backend = context%settings%backend\n"
    "    diagnostics%matrix_class = context%matrix_class\n",
    "    diagnostics%requested_backend = context%requested_backend\n"
    "    diagnostics%backend = context%settings%backend\n"
    "    diagnostics%fallback_used = context%fallback_used\n"
    "    diagnostics%fallback_reason = context%fallback_reason\n"
    "    diagnostics%matrix_class = context%matrix_class\n",
)
replace_once(
    context,
    "    report%pattern_analysis_count = context%pattern_analysis_count\n",
    "    report%requested_backend = context%requested_backend\n"
    "    report%backend = context%settings%backend\n"
    "    report%fallback_used = context%fallback_used\n"
    "    report%fallback_reason = context%fallback_reason\n"
    "    report%pattern_analysis_count = context%pattern_analysis_count\n",
)
replace_once(
    context,
    "  integer function mumps_symmetry_mode(matrix_class)\n",
    "  subroutine resolve_sparse_backend(context, status)\n"
    "    type(sparse_solver_context_t), intent(inout) :: context\n"
    "    integer, intent(out) :: status\n\n"
    "    status = DES_STATUS_OK\n"
    "    select case (context%requested_backend)\n"
    "    case (DES_LINEAR_BACKEND_AUTO)\n"
    "      ! B7 workstation politikasında kullanılabilir production direct backend\n"
    "      ! MUMPS'tır. Matris sınıfı MUMPS symmetry modunu belirler; MUMPS build\n"
    "      ! dışında kaldığında aynı sparse sözleşme portable GMRES'e düşer.\n"
    "      select case (context%matrix_class)\n"
    "      case (DES_MATRIX_CLASS_SPD, DES_MATRIX_CLASS_SYMMETRIC_INDEFINITE, &\n"
    "            DES_MATRIX_CLASS_UNSYMMETRIC)\n"
    "        if (DES_MUMPS_AVAILABLE) then\n"
    "          context%settings%backend = DES_LINEAR_BACKEND_MUMPS_DIRECT\n"
    "        else\n"
    "          context%settings%backend = DES_LINEAR_BACKEND_STDLIB_CSR_GMRES\n"
    "          context%fallback_used = .true.\n"
    "          context%fallback_reason = DES_LINEAR_FALLBACK_MUMPS_UNAVAILABLE\n"
    "        end if\n"
    "      case default\n"
    "        status = DES_ERROR_INVALID_CONSTRAINT\n"
    "      end select\n"
    "    case (DES_LINEAR_BACKEND_STDLIB_CSR_GMRES, DES_LINEAR_BACKEND_MUMPS_DIRECT)\n"
    "      context%settings%backend = context%requested_backend\n"
    "    case default\n"
    "      status = DES_ERROR_UNSUPPORTED_LINEAR_BACKEND\n"
    "    end select\n"
    "  end subroutine resolve_sparse_backend\n\n"
    "  integer function mumps_symmetry_mode(matrix_class)\n",
)

new_test = Path("tests/test_auto_sparse_solver_policy.f90")
if new_test.exists():
    raise RuntimeError("AUTO policy test dosyası zaten var; one-shot patch durduruldu.")
new_test.write_text(
    """program test_auto_sparse_solver_policy
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK
  use des_csr_matrix, only : csr_matrix_t, &
      initialize_csr_from_element_dof_maps, csr_add_local_matrix
  use des_linear_solver, only : linear_solver_settings_t, linear_solver_report_t, &
      DES_LINEAR_BACKEND_AUTO, DES_LINEAR_BACKEND_STDLIB_CSR_GMRES, &
      DES_LINEAR_BACKEND_MUMPS_DIRECT, DES_LINEAR_FALLBACK_NONE, &
      DES_LINEAR_FALLBACK_MUMPS_UNAVAILABLE
  use des_mumps_backend, only : DES_MUMPS_AVAILABLE
  use des_sparse_solver_context, only : sparse_solver_context_t, &
      sparse_solver_diagnostics_t, create_sparse_solver_context, &
      analyze_sparse_pattern, reorder_sparse_pattern, factorize_sparse_matrix, &
      solve_sparse_with_context, get_sparse_solver_diagnostics, &
      release_sparse_solver_context, DES_MATRIX_CLASS_SYMMETRIC_INDEFINITE, &
      DES_PROBLEM_CLASS_MIXED_U_P, DES_INDEX_CLASS_INT32
  implicit none

  type(csr_matrix_t) :: A
  type(linear_solver_settings_t) :: settings
  type(linear_solver_report_t) :: report
  type(sparse_solver_context_t) :: context
  type(sparse_solver_diagnostics_t) :: diagnostics
  integer :: maps(1,3), status, expected_backend
  real(dp) :: A_dense(3,3), b(3), x(3), expected(3)

  maps(1,:) = [1,2,3]
  call initialize_csr_from_element_dof_maps(A,3,3,maps,status)
  if (status /= DES_STATUS_OK) error stop 'AUTO policy CSR graph kuramadi.'

  A_dense = reshape([ &
      2.0_dp,0.0_dp,1.0_dp, &
      0.0_dp,3.0_dp,1.0_dp, &
      1.0_dp,1.0_dp,0.0_dp],shape(A_dense))
  expected = [1.0_dp,-2.0_dp,0.5_dp]
  b = matmul(A_dense,expected)
  call csr_add_local_matrix(A,maps(1,:),A_dense,status)
  if (status /= DES_STATUS_OK) error stop 'AUTO policy CSR values assemble edemedi.'

  settings = linear_solver_settings_t()
  settings%backend = DES_LINEAR_BACKEND_AUTO
  settings%relative_tolerance = 1.0e-11_dp
  settings%absolute_tolerance = 1.0e-12_dp
  settings%max_iterations = 30
  settings%krylov_dimension = 3

  call create_sparse_solver_context( &
      context,settings,DES_MATRIX_CLASS_SYMMETRIC_INDEFINITE, &
      DES_PROBLEM_CLASS_MIXED_U_P,DES_INDEX_CLASS_INT32,status)
  if (status /= DES_STATUS_OK) error stop 'AUTO sparse context olusturulamadi.'

  call get_sparse_solver_diagnostics(context,diagnostics)
  if (diagnostics%requested_backend /= DES_LINEAR_BACKEND_AUTO) then
    error stop 'AUTO policy requested backend bilgisini korumadi.'
  end if

  if (DES_MUMPS_AVAILABLE) then
    expected_backend = DES_LINEAR_BACKEND_MUMPS_DIRECT
    if (diagnostics%fallback_used) then
      error stop 'MUMPS varken AUTO gereksiz fallback raporladi.'
    end if
    if (diagnostics%fallback_reason /= DES_LINEAR_FALLBACK_NONE) then
      error stop 'MUMPS varken AUTO fallback nedeni sifir olmaliydi.'
    end if
  else
    expected_backend = DES_LINEAR_BACKEND_STDLIB_CSR_GMRES
    if (.not. diagnostics%fallback_used) then
      error stop 'MUMPS yokken AUTO GMRES fallback raporlamadi.'
    end if
    if (diagnostics%fallback_reason /= DES_LINEAR_FALLBACK_MUMPS_UNAVAILABLE) then
      error stop 'AUTO GMRES fallback nedeni yanlis.'
    end if
  end if

  if (diagnostics%backend /= expected_backend) then
    error stop 'AUTO policy beklenen sparse backend secimini yapmadi.'
  end if

  call analyze_sparse_pattern(context,A,status)
  if (status /= DES_STATUS_OK) error stop 'AUTO policy pattern analysis basarisiz.'
  call reorder_sparse_pattern(context,status)
  if (status /= DES_STATUS_OK) error stop 'AUTO policy reorder basarisiz.'
  call factorize_sparse_matrix(context,A,status)
  if (status /= DES_STATUS_OK) error stop 'AUTO policy factorization basarisiz.'
  call solve_sparse_with_context(context,A,b,x,report)
  if (.not. report%converged .or. report%status /= DES_STATUS_OK) then
    error stop 'AUTO policy sparse solve yakinsamadi.'
  end if
  if (maxval(abs(x-expected)) > 1.0e-10_dp) then
    error stop 'AUTO policy sparse solve beklenen cozumle uyusmuyor.'
  end if
  if (report%requested_backend /= DES_LINEAR_BACKEND_AUTO) then
    error stop 'AUTO solve report requested backend bilgisini kaybetti.'
  end if
  if (report%backend /= expected_backend) then
    error stop 'AUTO solve report selected backend bilgisini kaybetti.'
  end if
  if (report%fallback_used .neqv. diagnostics%fallback_used) then
    error stop 'AUTO solve report fallback flag diagnostics ile uyusmuyor.'
  end if
  if (report%fallback_reason /= diagnostics%fallback_reason) then
    error stop 'AUTO solve report fallback nedeni diagnostics ile uyusmuyor.'
  end if

  if (DES_MUMPS_AVAILABLE) then
    if (.not. report%direct_factorization_performed) then
      error stop 'AUTO MUMPS direct factorization flag raporlanmadi.'
    end if
  else
    if (report%direct_factorization_performed) then
      error stop 'AUTO GMRES direct factorization yapmis gibi raporlandi.'
    end if
  end if

  call release_sparse_solver_context(context)
  write(*,'(A,I0)') 'AUTO requested backend = ',DES_LINEAR_BACKEND_AUTO
  write(*,'(A,I0)') 'AUTO selected backend = ',expected_backend
  write(*,'(A,L1)') 'AUTO fallback used = ',diagnostics%fallback_used
  write(*,'(A)') 'B7 AUTO sparse solver policy testi BASARILI.'
end program test_auto_sparse_solver_policy
""",
    encoding="utf-8",
)

tests_cmake = "tests/CMakeLists.txt"
replace_once(
    tests_cmake,
    "des_add_fortran_test(test_sparse_solver_context solver.sparse.context_lifecycle test_sparse_solver_context.f90)\n",
    "des_add_fortran_test(test_sparse_solver_context solver.sparse.context_lifecycle test_sparse_solver_context.f90)\n"
    "des_add_fortran_test(test_auto_sparse_solver_policy solver.sparse.auto_policy test_auto_sparse_solver_policy.f90)\n",
)

workflow = ".github/workflows/mumps-direct-ci.yml"
replace_once(
    workflow,
    "      - 'tests/test_mumps*.f90'\n"
    "      - 'tests/test_q9_herrmann_sparse*_force_solver.f90'\n",
    "      - 'tests/test_mumps*.f90'\n"
    "      - 'tests/test_auto_sparse_solver_policy.f90'\n"
    "      - 'tests/test_q9_herrmann_sparse*_force_solver.f90'\n",
)
replace_once(
    workflow,
    "      - 'tests/test_mumps*.f90'\n"
    "      - 'tests/test_q9_herrmann_sparse*_force_solver.f90'\n"
    "      - '.github/workflows/mumps-direct-ci.yml'\n",
    "      - 'tests/test_mumps*.f90'\n"
    "      - 'tests/test_auto_sparse_solver_policy.f90'\n"
    "      - 'tests/test_q9_herrmann_sparse*_force_solver.f90'\n"
    "      - '.github/workflows/mumps-direct-ci.yml'\n",
)
replace_once(
    workflow,
    "            test_mumps_sparse_solver_context \\\n"
    "            test_q9_herrmann_sparse_force_solver \\\n",
    "            test_mumps_sparse_solver_context \\\n"
    "            test_auto_sparse_solver_policy \\\n"
    "            test_q9_herrmann_sparse_force_solver \\\n",
)
replace_once(
    workflow,
    "            -R '^(solver\\.sparse\\.mumps_direct_context|solver\\.q9\\.plane_strain\\.herrmann\\.mumps_force_parity|solver\\.q9\\.plane_strain\\.herrmann\\.mumps_adaptive_force_parity)$' \\\n",
    "            -R '^(solver\\.sparse\\.mumps_direct_context|solver\\.sparse\\.auto_policy|solver\\.q9\\.plane_strain\\.herrmann\\.mumps_force_parity|solver\\.q9\\.plane_strain\\.herrmann\\.mumps_adaptive_force_parity)$' \\\n",
)

print("B7 AUTO policy patch başarıyla hazırlandı.")
