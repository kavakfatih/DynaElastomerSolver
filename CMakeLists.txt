cmake_minimum_required(VERSION 3.25)

project(DynaElastomerSolver
  VERSION 0.3.0
  LANGUAGES Fortran
)

set(CMAKE_Fortran_STANDARD 2018)
set(CMAKE_Fortran_STANDARD_REQUIRED ON)
set(CMAKE_Fortran_EXTENSIONS OFF)

option(DES_BUILD_TESTS "DynaElastomerSolver testlerini derle" ON)

# Harici Fortran bağımlılıkları burada tek noktadan yönetilir.
include(cmake/DESDependencies.cmake)

add_subdirectory(src/fortran)

if(DES_BUILD_TESTS)
  # stdlib testleri dependency configure aşamasında kapatılır; burada yalnız
  # DynaElastomerSolver test paketi yeniden etkinleştirilir.
  set(BUILD_TESTING ON CACHE BOOL "DynaElastomerSolver testlerini etkinleştir" FORCE)
  include(CTest)
  enable_testing()
  add_subdirectory(tests)
endif()
