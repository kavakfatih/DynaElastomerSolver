function(des_add_fortran_test target test_name source)
  add_executable(${target} ${source})
  target_link_libraries(${target} PRIVATE DynaElastomerCore)

  if(CMAKE_Fortran_COMPILER_ID STREQUAL "GNU")
    target_compile_options(${target} PRIVATE
      -Wall -Wextra -Wimplicit-interface -Werror=implicit-interface
    )
  elseif(CMAKE_Fortran_COMPILER_ID MATCHES "Intel")
    target_compile_options(${target} PRIVATE -warn all)
  endif()

  add_test(NAME ${test_name} COMMAND ${target})
endfunction()

des_add_fortran_test(
  test_tensor3
  core.tensor3
  test_tensor3.f90
)

des_add_fortran_test(
  test_finite_strain
  core.finite_strain
  test_finite_strain.f90
)

des_add_fortran_test(
  test_neo_hookean_reference_states
  material.neo_hookean.reference_states
  test_neo_hookean_reference_states.f90
)

des_add_fortran_test(
  test_neo_hookean_validation
  material.neo_hookean.validation
  test_neo_hookean_validation.f90
)

des_add_fortran_test(
  test_neo_hookean_material_point
  material.neo_hookean.point_tangent
  test_neo_hookean_material_point.f90
)

des_add_fortran_test(
  test_q4_shape
  fem.q4.shape
  test_q4_shape.f90
)

des_add_fortran_test(
  test_q4_plane_strain_element
  fem.q4.plane_strain.element_tangent
  test_q4_plane_strain_element.f90
)

des_add_fortran_test(
  test_q4_plane_strain_newton
  fem.q4.plane_strain.incremental_newton
  test_q4_plane_strain_newton.f90
)

des_add_fortran_test(
  test_dense_linear
  solver.dense_linear
  test_dense_linear.f90
)

des_add_fortran_test(
  test_q4_plane_strain_mesh_newton
  fem.q4.plane_strain.mesh_incremental_newton
  test_q4_plane_strain_mesh_newton.f90
)

des_add_fortran_test(
  test_q4_solver_api
  solver.q4.plane_strain.displacement_control
  test_q4_solver_api.f90
)

des_add_fortran_test(
  test_q4_nonlinear_patch
  fem.q4.plane_strain.nonlinear_patch
  test_q4_nonlinear_patch.f90
)

des_add_fortran_test(
  test_q4_mesh_refinement
  fem.q4.plane_strain.mesh_refinement
  test_q4_mesh_refinement.f90
)

des_add_fortran_test(
  test_q4_adaptive_cutback
  solver.q4.plane_strain.adaptive_cutback
  test_q4_adaptive_cutback.f90
)

des_add_fortran_test(
  test_solver_state_history
  solver.state_history_cutback_exhaustion
  test_solver_state_history.f90
)

des_add_fortran_test(
  test_status_message
  core.status_message
  test_status_message.f90
)
