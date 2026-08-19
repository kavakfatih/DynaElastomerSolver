# DynaElastomerSolver harici bilimsel bağımlılıkları.
#
# Bilimsel tekrarlanabilirlik için bağımlılıklar branch adına değil,
# doğrulanmış commit SHA / release checksum değerlerine sabitlenir.

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

# Dyna kendi CTest paketini yönetir. Dependency test paketleri her Dyna
# configure işleminde yeniden derlenmez.
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

# ---------------------------------------------------------------------------
# Optional MUMPS production sparse-direct backend
# ---------------------------------------------------------------------------
#
# Runtime/FEM katmanı scivision/mumps-superbuild API'sine bağımlı değildir.
# Bu proje yalnız upstream MUMPS'un CMake ile tekrarlanabilir biçimde
# derlenmesini sağlayan build-orchestration katmanıdır. Dyna adapter doğrudan
# MUMPS::MUMPS target'ına ve MUMPS C interface'ine bağlanır.
if(DES_ENABLE_MUMPS)
  set(
    DES_MUMPS_VERSION
    "5.9.1"
    CACHE STRING
    "Dyna tarafından kullanılan upstream MUMPS sürümü"
  )
  set(
    DES_MUMPS_SHA256
    "659c9b57646b5a003ac618baa1faf9dd2044e46c732b3daaccbc7158003e1b46"
    CACHE STRING
    "Upstream MUMPS release arşivi SHA-256 değeri"
  )
  set(
    DES_MUMPS_SUPERBUILD_REPOSITORY
    "https://github.com/scivision/mumps-superbuild.git"
    CACHE STRING
    "MUMPS için build-only CMake orchestration deposu"
  )
  set(
    DES_MUMPS_SUPERBUILD_GIT_TAG
    "2c86c7e8fdfe12d97bc0096c171c08f30ea981d6"
    CACHE STRING
    "Pinlenen mumps-superbuild commit'i"
  )

  # B6 workstation profili: single-process/libseq, double precision, static.
  # MPI/distributed ve int64 yolları B9/HPC genişlemesinde ayrıca açılacaktır.
  set(MUMPS_UPSTREAM_VERSION "${DES_MUMPS_VERSION}")
  set(MUMPS_sha256 "${DES_MUMPS_SHA256}")
  set(MUMPS_hash URL_HASH "SHA256=${DES_MUMPS_SHA256}")
  set(MUMPS_parallel OFF CACHE BOOL "B6: MPI yerine libseq kullan" FORCE)
  set(MUMPS_scalapack OFF CACHE BOOL "B6: ScaLAPACK kullanma" FORCE)
  set(MUMPS_intsize64 OFF CACHE BOOL "B6: MUMPS int32 profile" FORCE)
  set(MUMPS_openmp OFF CACHE BOOL "B6a: OpenMP daha sonra ölçülecek" FORCE)
  set(MUMPS_gpu OFF CACHE BOOL "B6: GPU backend kapalı" FORCE)
  set(MUMPS_xkblas OFF CACHE BOOL "B6: xKBLAS kapalı" FORCE)
  set(MUMPS_scotch OFF CACHE BOOL "B6: SCOTCH kapalı" FORCE)
  set(MUMPS_ptscotch OFF CACHE BOOL "B6: PT-SCOTCH kapalı" FORCE)
  set(MUMPS_metis OFF CACHE BOOL "B6: METIS kapalı" FORCE)
  set(MUMPS_parmetis OFF CACHE BOOL "B6: ParMETIS kapalı" FORCE)
  set(MUMPS_gemmt OFF CACHE BOOL "B6a: GEMMT opsiyonel optimizasyon kapalı" FORCE)
  set(MUMPS_BUILD_TESTING OFF CACHE BOOL "MUMPS upstream testleri kapalı" FORCE)
  set(BUILD_SINGLE OFF CACHE BOOL "MUMPS single precision kapalı" FORCE)
  set(BUILD_DOUBLE ON CACHE BOOL "MUMPS double precision açık" FORCE)
  set(BUILD_COMPLEX OFF CACHE BOOL "MUMPS complex kapalı" FORCE)
  set(BUILD_COMPLEX16 OFF CACHE BOOL "MUMPS complex16 kapalı" FORCE)
  set(BUILD_SHARED_LIBS OFF CACHE BOOL "B6: static dependency build" FORCE)

  # GNU ld Linux ve GNU/MinGW Windows'ta statik arşivleri tek geçişte tarar.
  # stdlib BLAS'ı MUMPS/LAPACK zincirinden önce linklediğinde liblapack.a'nın
  # BLAS sembolleri çözümsüz kalabilir. Numeric kütüphaneleri gerçek dosya
  # seviyesinde RESCAN grubuna alarak bu yalnız-build/link sırası problemini
  # vendor/FEM katmanına sızdırmadan çözüyoruz. Apple linker ve Intel ifx bu
  # workaround'a ihtiyaç duymadığından mevcut davranışları aynen korunur.
  set(DES_MUMPS_NUMERIC_LINK_TARGET "")
  if(CMAKE_Fortran_COMPILER_ID STREQUAL "GNU" AND NOT APPLE)
    find_package(BLAS REQUIRED)
    find_package(LAPACK REQUIRED)

    set(_des_mumps_numeric_libraries ${LAPACK_LIBRARIES} ${BLAS_LIBRARIES})
    list(REMOVE_DUPLICATES _des_mumps_numeric_libraries)
    string(JOIN "," _des_mumps_numeric_group ${_des_mumps_numeric_libraries})

    add_library(des_mumps_numeric_rescan INTERFACE)
    target_link_libraries(des_mumps_numeric_rescan INTERFACE
      "$<LINK_GROUP:RESCAN,${_des_mumps_numeric_group}>"
    )
    set(DES_MUMPS_NUMERIC_LINK_TARGET des_mumps_numeric_rescan)
  endif()

  message(STATUS
    "Dyna MUMPS backend: upstream ${DES_MUMPS_VERSION}, "
    "SHA256=${DES_MUMPS_SHA256}"
  )
  message(STATUS
    "Dyna MUMPS build orchestration: "
    "${DES_MUMPS_SUPERBUILD_REPOSITORY} @ ${DES_MUMPS_SUPERBUILD_GIT_TAG}"
  )

  FetchContent_Declare(
    des_mumps_superbuild
    GIT_REPOSITORY "${DES_MUMPS_SUPERBUILD_REPOSITORY}"
    GIT_TAG "${DES_MUMPS_SUPERBUILD_GIT_TAG}"
    GIT_PROGRESS TRUE
  )
  FetchContent_MakeAvailable(des_mumps_superbuild)

  if(NOT TARGET MUMPS::MUMPS)
    message(FATAL_ERROR "MUMPS::MUMPS target'i oluşturulamadı.")
  endif()

  set(DES_MUMPS_TARGET MUMPS::MUMPS)
endif()
