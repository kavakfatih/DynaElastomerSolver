cmake_minimum_required(VERSION 3.25)

project(DynaElastomerSolver
  VERSION 0.1.0
  LANGUAGES Fortran
)

set(CMAKE_Fortran_STANDARD 2018)
set(CMAKE_Fortran_STANDARD_REQUIRED ON)
set(CMAKE_Fortran_EXTENSIONS OFF)

option(DES_BUILD_TESTS "DynaElastomerSolver testlerini derle" ON)

add_subdirectory(src/fortran)

if(DES_BUILD_TESTS)
  include(CTest)
  enable_testing()
  add_subdirectory(tests)
endif()
