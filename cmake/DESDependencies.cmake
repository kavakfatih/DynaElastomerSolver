# DynaElastomerSolver harici Fortran bağımlılıkları.
#
# Bilimsel tekrarlanabilirlik için bağımlılıklar branch adına değil,
# doğrulanmış commit SHA değerine sabitlenir.

include(FetchContent)

set(
  DES_STDLIB_REPOSITORY
  "https://github.com/kavakfatih/stdlib.git"
  CACHE STRING
  "DynaElastomerSolver tarafından kullanılan Fortran stdlib deposu"
)

set(
  DES_STDLIB_GIT_TAG
  "9a15c7772f1a76a6c497b9f3abb793841fc81f74"
  CACHE STRING
  "DynaElastomerSolver tarafından kullanılan Fortran stdlib commit'i"
)

set(
  DES_STDLIB_SOURCE_DIR
  ""
  CACHE PATH
  "İsteğe bağlı yerel kavakfatih/stdlib kaynak dizini; boşsa FetchContent kullanılır"
)

# stdlib kaynak üretimi için fypp kullanır. Bu bağımlılığı configure aşamasında
# açıkça kontrol ederek daha anlaşılır bir hata mesajı veriyoruz.
find_program(DES_FYPP_EXECUTABLE NAMES fypp)
if(NOT DES_FYPP_EXECUTABLE)
  message(FATAL_ERROR
    "DynaElastomerSolver, kavakfatih/stdlib derlemek için 'fypp' gerektirir. "
    "Önce fypp kurun ve PATH'e ekleyin."
  )
endif()
set(FYPP "${DES_FYPP_EXECUTABLE}" CACHE FILEPATH "stdlib fypp executable" FORCE)

# Dyna kendi CTest paketini yönetir. stdlib'in kapsamlı kendi test paketini
# dependency olarak her Dyna build'inde tekrar derlemiyoruz.
set(BUILD_TESTING OFF CACHE BOOL "Harici dependency testlerini devre dışı bırak" FORCE)

if(DES_STDLIB_SOURCE_DIR)
  message(STATUS "Dyna stdlib yerel kaynaktan kullanılıyor: ${DES_STDLIB_SOURCE_DIR}")
  add_subdirectory(
    "${DES_STDLIB_SOURCE_DIR}"
    "${CMAKE_BINARY_DIR}/_deps/des_stdlib-build"
    EXCLUDE_FROM_ALL
  )
else()
  message(STATUS "Dyna stdlib kaynağı: ${DES_STDLIB_REPOSITORY} @ ${DES_STDLIB_GIT_TAG}")
  FetchContent_Declare(
    des_stdlib
    GIT_REPOSITORY "${DES_STDLIB_REPOSITORY}"
    GIT_TAG "${DES_STDLIB_GIT_TAG}"
    GIT_PROGRESS TRUE
  )
  FetchContent_MakeAvailable(des_stdlib)
endif()

if(NOT TARGET fortran_stdlib)
  message(FATAL_ERROR "Fortran stdlib target'i oluşturulamadı: fortran_stdlib")
endif()

set(DES_STDLIB_TARGET fortran_stdlib)
