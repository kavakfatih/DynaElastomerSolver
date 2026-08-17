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
