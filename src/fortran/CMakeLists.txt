add_library(DynaElastomerCore STATIC
  core/des_kinds.f90
  math/des_tensor3.f90
  materials/des_material_types.f90
  materials/des_neo_hookean.f90
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
