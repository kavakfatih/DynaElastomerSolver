set(DES_MUMPS_BACKEND_SOURCE solvers/des_mumps_backend_stub.f90)
if(DES_ENABLE_MUMPS)
  set(DES_MUMPS_BACKEND_SOURCE solvers/des_mumps_backend.f90)
endif()

add_library(DynaElastomerCore STATIC
  core/des_kinds.f90
  core/des_status.f90
  math/des_tensor3.f90
  math/des_finite_strain.f90
  math/des_csr_matrix.f90
  materials/des_material_types.f90
  materials/des_neo_hookean.f90
  materials/des_neo_hookean_isochoric.f90
  mesh/des_internal_mesh.f90
  results/des_integration_point_results.f90
  results/des_pressure_diagnostics.f90
  fem/des_q4_shape.f90
  fem/des_herrmann_pressure_interpolation.f90
  fem/des_q8_herrmann_interpolation.f90
  fem/des_q8_herrmann_geometry.f90
  fem/des_q9_herrmann_interpolation.f90
  fem/des_q9_herrmann_geometry.f90
  fem/des_mixed_dof_layout.f90
  fem/des_mixed_precheck.f90
  fem/des_herrmann_pressure_constraint.f90
  fem/des_q8_plane_strain_herrmann_neo_hookean.f90
  fem/des_q9_plane_strain_herrmann_neo_hookean.f90
  fem/des_q9_plane_strain_herrmann_mesh.f90
  fem/des_q9_plane_strain_herrmann_sparse_mesh.f90
  fem/des_q9_internal_mesh_herrmann_assembly.f90
  fem/des_q4_edge_traction.f90
  fem/des_q4_mesh_edge_traction.f90
  fem/des_q4_plane_strain_neo_hookean.f90
  fem/des_q4_plane_strain_mixed_up_neo_hookean.f90
  fem/des_q4_plane_strain_fbar_neo_hookean.f90
  fem/des_q4_plane_strain_mesh_neo_hookean.f90
  fem/des_q4_plane_strain_mixed_up_mesh.f90
  fem/des_q4_plane_strain_fbar_mesh.f90
  solvers/des_linear_solver.f90
  ${DES_MUMPS_BACKEND_SOURCE}
  solvers/des_sparse_solver_context.f90
  solvers/des_dense_linear.f90
  solvers/des_solution_state.f90
  solvers/des_solver_history.f90
  solvers/des_q4_plane_strain_newton_solver.f90
  solvers/des_q4_plane_strain_force_solver.f90
  solvers/des_q4_plane_strain_mixed_up_force_solver.f90
  solvers/des_q4_plane_strain_fbar_force_solver.f90
  solvers/des_q9_plane_strain_herrmann_force_solver.f90
  solvers/des_q9_herrmann_solver_report.f90
  solvers/des_q4_internal_mesh_solver.f90
)

if(DES_ENABLE_MUMPS)
  target_sources(DynaElastomerCore PRIVATE
    solvers/des_mumps_adapter.c
  )
endif()

set_target_properties(DynaElastomerCore PROPERTIES
  Fortran_MODULE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/modules"
)

target_include_directories(DynaElastomerCore PUBLIC
  "$<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/modules>"
)

# stdlib Dyna bilimsel çekirdeğinin aktif bağımlılığıdır.
# Lineer cebir erişimi FEM/Newton kodundan değil solver abstraction sınırından yapılır.
target_link_libraries(DynaElastomerCore PUBLIC ${DES_STDLIB_TARGET})

if(DES_ENABLE_MUMPS)
  # MUMPS tipleri Dyna public Fortran API'sine taşınmaz; ancak static core'u
  # kullanan executable'ların MUMPS ve sequential MPI/libseq link bağımlılığını
  # alması gerekir. MPI::MPI_C burada gerçek MPI değil, B6 workstation profilinde
  # pinned MUMPS build'inin PUBLIC mpiseq_c alias'ıdır; mpi.h include yolu da bu
  # target üzerinden adapter'a taşınır.
  target_link_libraries(DynaElastomerCore PUBLIC
    ${DES_MUMPS_TARGET}
    MPI::MPI_C
  )
endif()

if(CMAKE_Fortran_COMPILER_ID STREQUAL "GNU")
  target_compile_options(DynaElastomerCore PRIVATE
    "$<$<COMPILE_LANGUAGE:Fortran>:-Wall;-Wextra;-Wimplicit-interface;-Werror=implicit-interface>"
  )
elseif(CMAKE_Fortran_COMPILER_ID MATCHES "Intel")
  target_compile_options(DynaElastomerCore PRIVATE
    "$<$<COMPILE_LANGUAGE:Fortran>:-warn;all>"
  )
endif()
