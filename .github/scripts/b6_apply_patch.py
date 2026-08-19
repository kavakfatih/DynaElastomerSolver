from pathlib import Path

# Q9 production solver: vendor adını Newton katmanına taşımadan
# mevcut sparse abstraction üzerinden GMRES ve MUMPS'u kabul et.
p = Path('src/fortran/solvers/des_q9_plane_strain_herrmann_force_solver.f90')
s = p.read_text()
old = """  use des_linear_solver, only : linear_solver_settings_t, linear_solver_report_t, &
                                solve_linear_system, &
                                DES_LINEAR_BACKEND_STDLIB_CSR_GMRES
"""
new = """  use des_linear_solver, only : linear_solver_settings_t, linear_solver_report_t, &
                                solve_linear_system, linear_backend_is_sparse
"""
assert s.count(old) == 1, 'Q9 linear solver import pattern'
s = s.replace(old, new)
old_sel = """    use_sparse_backend = &
        active_linear_settings%backend == DES_LINEAR_BACKEND_STDLIB_CSR_GMRES
"""
assert s.count(old_sel) == 2, 'Q9 sparse backend selection pattern'
s = s.replace(old_sel, "    use_sparse_backend = linear_backend_is_sparse(active_linear_settings%backend)\n")
p.write_text(s)

# Fixed parity executable: argsız yol GMRES, `mumps` argümanı direct backend.
p = Path('tests/test_q9_herrmann_sparse_force_solver.f90')
s = p.read_text()
old = """  use des_linear_solver, only : linear_solver_settings_t, &
                                DES_LINEAR_BACKEND_STDLIB_CSR_GMRES
"""
new = """  use des_linear_solver, only : linear_solver_settings_t, &
                                DES_LINEAR_BACKEND_STDLIB_CSR_GMRES, &
                                DES_LINEAR_BACKEND_MUMPS_DIRECT
"""
assert s.count(old) == 1, 'fixed import pattern'
s = s.replace(old, new)
old = """  integer :: connectivity(1,9),status
  type(internal_mesh_t) :: mesh

"""
new = """  integer :: connectivity(1,9),status,sparse_backend
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

"""
assert s.count(old) == 1, 'fixed declarations pattern'
s = s.replace(old, new)
old = """  call run_parity_case(mesh,5.0e-2_dp,.false.)
  call run_parity_case(mesh,0.0_dp,.true.)
"""
new = """  call run_parity_case(mesh,5.0e-2_dp,.false.,sparse_backend)
  call run_parity_case(mesh,0.0_dp,.true.,sparse_backend)
"""
assert s.count(old) == 1, 'fixed calls pattern'
s = s.replace(old, new)
old = """  subroutine run_parity_case(mesh,pressure_compliance,fully_incompressible)
    type(internal_mesh_t), intent(in) :: mesh
    real(dp), intent(in) :: pressure_compliance
    logical, intent(in) :: fully_incompressible
"""
new = """  subroutine run_parity_case(mesh,pressure_compliance,fully_incompressible,sparse_backend)
    type(internal_mesh_t), intent(in) :: mesh
    real(dp), intent(in) :: pressure_compliance
    logical, intent(in) :: fully_incompressible
    integer, intent(in) :: sparse_backend
"""
assert s.count(old) == 1, 'fixed subroutine pattern'
s = s.replace(old, new)
assert s.count('    sparse_settings%backend = DES_LINEAR_BACKEND_STDLIB_CSR_GMRES\n') == 1
s = s.replace('    sparse_settings%backend = DES_LINEAR_BACKEND_STDLIB_CSR_GMRES\n',
              '    sparse_settings%backend = sparse_backend\n')
old = """    if (sparse_report%last_linear_report%direct_factorization_performed) then
      error stop 'Q9 GMRES direct factorization yapmis gibi raporlandi.'
    end if
"""
new = """    if (sparse_report%last_linear_report%backend /= sparse_backend) then
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
"""
assert s.count(old) == 1, 'fixed direct flag pattern'
s = s.replace(old, new)
p.write_text(s)

# Adaptive parity: finite-cp, cp=0 ve deliberate cutback exhaustion.
p = Path('tests/test_q9_herrmann_sparse_adaptive_force_solver.f90')
s = p.read_text()
old = """  use des_linear_solver, only : linear_solver_settings_t, &
                                DES_LINEAR_BACKEND_STDLIB_CSR_GMRES
"""
new = """  use des_linear_solver, only : linear_solver_settings_t, &
                                DES_LINEAR_BACKEND_STDLIB_CSR_GMRES, &
                                DES_LINEAR_BACKEND_MUMPS_DIRECT
"""
assert s.count(old) == 1, 'adaptive import pattern'
s = s.replace(old, new)
old = """  integer :: connectivity(1,9), status
  type(internal_mesh_t) :: mesh

"""
new = """  integer :: connectivity(1,9), status, sparse_backend
  character(len=32) :: backend_argument
  type(internal_mesh_t) :: mesh

  sparse_backend = DES_LINEAR_BACKEND_STDLIB_CSR_GMRES
  if (command_argument_count() > 0) then
    call get_command_argument(1,backend_argument)
    select case (trim(backend_argument))
    case ('mumps')
      sparse_backend = DES_LINEAR_BACKEND_MUMPS_DIRECT
    case default
      error stop 'Q9 adaptive sparse parity bilinmeyen backend argumani.'
    end select
  end if

"""
assert s.count(old) == 1, 'adaptive declarations pattern'
s = s.replace(old, new)
old = """  call run_adaptive_parity_case(mesh,5.0e-2_dp,.false.)
  call run_adaptive_parity_case(mesh,0.0_dp,.true.)
  call run_cutback_exhaustion_parity(mesh)
"""
new = """  call run_adaptive_parity_case(mesh,5.0e-2_dp,.false.,sparse_backend)
  call run_adaptive_parity_case(mesh,0.0_dp,.true.,sparse_backend)
  call run_cutback_exhaustion_parity(mesh,sparse_backend)
"""
assert s.count(old) == 1, 'adaptive calls pattern'
s = s.replace(old, new)
old = """  subroutine run_adaptive_parity_case(mesh,pressure_compliance,fully_incompressible)
    type(internal_mesh_t), intent(in) :: mesh
    real(dp), intent(in) :: pressure_compliance
    logical, intent(in) :: fully_incompressible
"""
new = """  subroutine run_adaptive_parity_case( &
      mesh,pressure_compliance,fully_incompressible,sparse_backend)
    type(internal_mesh_t), intent(in) :: mesh
    real(dp), intent(in) :: pressure_compliance
    logical, intent(in) :: fully_incompressible
    integer, intent(in) :: sparse_backend
"""
assert s.count(old) == 1, 'adaptive subroutine pattern'
s = s.replace(old, new)
assert s.count('    call configure_sparse_settings(sparse_settings)\n') == 2
s = s.replace('    call configure_sparse_settings(sparse_settings)\n',
              '    call configure_sparse_settings(sparse_settings,sparse_backend)\n')
old = """    if (sparse_report%last_linear_report%direct_factorization_performed) then
      error stop 'Q9 adaptive GMRES direct factorization iddia etti.'
    end if
"""
new = """    if (sparse_report%last_linear_report%backend /= sparse_backend) then
      error stop 'Q9 adaptive sparse backend raporu secimle uyusmuyor.'
    end if
    if (sparse_backend == DES_LINEAR_BACKEND_MUMPS_DIRECT) then
      if (.not. sparse_report%last_linear_report%direct_factorization_performed) then
        error stop 'Q9 adaptive MUMPS direct factorization raporlanmadi.'
      end if
    else
      if (sparse_report%last_linear_report%direct_factorization_performed) then
        error stop 'Q9 adaptive GMRES direct factorization iddia etti.'
      end if
    end if
"""
assert s.count(old) == 1, 'adaptive direct flag pattern'
s = s.replace(old, new)
old = """  subroutine run_cutback_exhaustion_parity(mesh)
    type(internal_mesh_t), intent(in) :: mesh
"""
new = """  subroutine run_cutback_exhaustion_parity(mesh,sparse_backend)
    type(internal_mesh_t), intent(in) :: mesh
    integer, intent(in) :: sparse_backend
"""
assert s.count(old) == 1, 'adaptive exhaustion signature'
s = s.replace(old, new)
needle = """    if (sparse_report%last_linear_report%reorder_count /= 1) then
      error stop 'Q9 exhaustion sparse context ordering tekrarlandi.'
    end if

    write(*,'(A,I0,A,I0,A,I0)') &
"""
insert = """    if (sparse_report%last_linear_report%reorder_count /= 1) then
      error stop 'Q9 exhaustion sparse context ordering tekrarlandi.'
    end if
    if (sparse_report%last_linear_report%backend /= sparse_backend) then
      error stop 'Q9 exhaustion sparse backend raporu secimle uyusmuyor.'
    end if
    if (sparse_backend == DES_LINEAR_BACKEND_MUMPS_DIRECT .and. &
        .not. sparse_report%last_linear_report%direct_factorization_performed) then
      error stop 'Q9 exhaustion MUMPS direct factorization raporlanmadi.'
    end if

    write(*,'(A,I0,A,I0,A,I0)') &
"""
assert s.count(needle) == 1, 'adaptive exhaustion report pattern'
s = s.replace(needle, insert)
old = """  subroutine configure_sparse_settings(settings)
    type(linear_solver_settings_t), intent(out) :: settings

    settings = linear_solver_settings_t()
    settings%backend = DES_LINEAR_BACKEND_STDLIB_CSR_GMRES
"""
new = """  subroutine configure_sparse_settings(settings,sparse_backend)
    type(linear_solver_settings_t), intent(out) :: settings
    integer, intent(in) :: sparse_backend

    settings = linear_solver_settings_t()
    settings%backend = sparse_backend
"""
assert s.count(old) == 1, 'adaptive settings helper'
s = s.replace(old, new)
p.write_text(s)

# MUMPS-enabled CTest: direct context + fixed + adaptive parity.
p = Path('tests/CMakeLists.txt')
s = p.read_text()
old = """if(DES_ENABLE_MUMPS)
  des_add_fortran_test(
    test_mumps_sparse_solver_context
    solver.sparse.mumps_direct_context
    test_mumps_sparse_solver_context.f90
  )
endif()
"""
new = """if(DES_ENABLE_MUMPS)
  des_add_fortran_test(
    test_mumps_sparse_solver_context
    solver.sparse.mumps_direct_context
    test_mumps_sparse_solver_context.f90
  )

  # Aynı Q9/P1 parity executable'ları varsayılan olarak GMRES'i korur. MUMPS
  # build'inde `mumps` argümanı ile direct backend'i aynı fizik ve lifecycle
  # kabul kriterlerinden geçirerek test mantığının kopyalanmasını önlüyoruz.
  add_test(
    NAME solver.q9.plane_strain.herrmann.mumps_force_parity
    COMMAND test_q9_herrmann_sparse_force_solver mumps
  )
  add_test(
    NAME solver.q9.plane_strain.herrmann.mumps_adaptive_force_parity
    COMMAND test_q9_herrmann_sparse_adaptive_force_solver mumps
  )
endif()
"""
assert s.count(old) == 1, 'CTest MUMPS block'
s = s.replace(old, new)
p.write_text(s)

# Dört-platform MUMPS CI artık Q9/P1 fixed/adaptive acceptance'ı da kapsar.
p = Path('.github/workflows/mumps-direct-ci.yml')
s = p.read_text()
assert s.count("      - 'tests/test_mumps*.f90'\n") == 2, 'workflow path filters'
s = s.replace("      - 'tests/test_mumps*.f90'\n",
              "      - 'tests/test_mumps*.f90'\n      - 'tests/test_q9_herrmann_sparse*_force_solver.f90'\n")
old = r"""      - name: MUMPS context target derle
        id: build
        shell: bash
        run: |
          set -o pipefail
          cmake --build build-mumps --target test_mumps_sparse_solver_context --parallel 2 --verbose \
            2>&1 | tee mumps-build.log

      - name: MUMPS direct context regression
        id: ctest
        shell: bash
        run: |
          ctest --test-dir build-mumps \
            -R '^solver\.sparse\.mumps_direct_context$' \
            --output-on-failure --build-config Debug
"""
new = r"""      - name: MUMPS context ve Q9/P1 parity targetlarini derle
        id: build
        shell: bash
        run: |
          set -o pipefail
          cmake --build build-mumps --target \
            test_mumps_sparse_solver_context \
            test_q9_herrmann_sparse_force_solver \
            test_q9_herrmann_sparse_adaptive_force_solver \
            --parallel 2 --verbose 2>&1 | tee mumps-build.log

      - name: MUMPS direct context ve Q9/P1 parity regression
        id: ctest
        shell: bash
        run: |
          ctest --test-dir build-mumps \
            -R '^(solver\.sparse\.mumps_direct_context|solver\.q9\.plane_strain\.herrmann\.mumps_force_parity|solver\.q9\.plane_strain\.herrmann\.mumps_adaptive_force_parity)$' \
            --output-on-failure --build-config Debug
"""
assert s.count(old) == 1, 'workflow build/ctest block'
s = s.replace(old, new)
p.write_text(s)
