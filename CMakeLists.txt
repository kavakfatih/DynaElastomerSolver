cmake_minimum_required(VERSION 3.25)

project(DynaElastomerSolver
  VERSION 0.3.0
  LANGUAGES Fortran
)

set(CMAKE_Fortran_STANDARD 2018)
set(CMAKE_Fortran_STANDARD_REQUIRED ON)
set(CMAKE_Fortran_EXTENSIONS OFF)

option(DES_BUILD_TESTS "DynaElastomerSolver testlerini derle" ON)
option(
  DES_ENABLE_MUMPS
  "MUMPS production sparse-direct backend'ini derle"
  OFF
)

# C dili yalnız MUMPS C adapter/backend'i açıldığında gerekir. Varsayılan
# Dyna build'i bugün olduğu gibi saf Fortran çekirdeği olarak kalabilir.
if(DES_ENABLE_MUMPS)
  enable_language(C)
endif()

# Harici Fortran / sparse solver bağımlılıkları burada tek noktadan yönetilir.
include(cmake/DESDependencies.cmake)

add_subdirectory(src/fortran)

if(DES_BUILD_TESTS)
  # stdlib ve optional dependency testleri configure aşamasında kapatılır;
  # burada yalnız DynaElastomerSolver test paketi yeniden etkinleştirilir.
  set(BUILD_TESTING ON CACHE BOOL "DynaElastomerSolver testlerini etkinleştir" FORCE)
  include(CTest)
  enable_testing()
  add_subdirectory(tests)
endif()
