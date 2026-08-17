add_library(DynaElastomerCore STATIC
  core/des_kinds.f90
  core/des_status.f90
  math/des_tensor3.f90
  math/des_finite_strain.f90
  materials/des_material_types.f90
  materials/des_neo_hookean.f90
  fem/des_q4_shape.f90
  fem/des_q4_plane_strain_neo_hookean.f90
  fem/des_q4_plane_strain_mesh_neo_hookean.f90
  solvers/des_dense_linear.f90
  solvers/des_q4_plane_strain_newton_solver.f90
)

set_target_properties(DynaElastomerCore PROPERTIES
  Fortran_MODULE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/modules"
)

target_include_directories(DynaElastomerCore PUBLIC
  "$<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/modules>"
)

if(CMAKE_Fortran_COMPILER_ID STREQUAL "GNU")
  target_compile_options(DynaElastomerCore PRIVATE
    -Wall -Wextra -Wimplicit-interface -Werror=implicit-interface
  )
elseif(CMAKE_Fortran_COMPILER_ID MATCHES "Intel")
  target_compile_options(DynaElastomerCore PRIVATE
    -warn all
  )
endif()
