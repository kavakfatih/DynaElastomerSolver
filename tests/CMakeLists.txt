add_executable(test_neo_hookean_material_point
  test_neo_hookean_material_point.f90
)

target_link_libraries(test_neo_hookean_material_point PRIVATE
  DynaElastomerCore
)

if(CMAKE_Fortran_COMPILER_ID STREQUAL "GNU")
  target_compile_options(test_neo_hookean_material_point PRIVATE
    -Wall -Wextra -Wimplicit-interface -Werror=implicit-interface
  )
elseif(CMAKE_Fortran_COMPILER_ID MATCHES "Intel")
  target_compile_options(test_neo_hookean_material_point PRIVATE
    -warn all
  )
endif()

add_test(
  NAME material.neo_hookean.point_tangent
  COMMAND test_neo_hookean_material_point
)
