cmake_minimum_required(VERSION 3.16)
project(serializer_benchmark_fortran LANGUAGES C Fortran)

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

find_package(ZLIB REQUIRED)
find_package(PkgConfig QUIET)
set(FORTRAN_ZSTD "")
if(PkgConfig_FOUND)
  pkg_check_modules(ZSTD libzstd)
  if(ZSTD_FOUND)
    set(FORTRAN_ZSTD ${ZSTD_LIBRARIES})
  endif()
endif()

set(SCHED_C "${CMAKE_CURRENT_SOURCE_DIR}/../c/src/schedule.c")

function(fortran_target name)
  add_executable(${name} ${ARGN} ${SCHED_C}
    src/schedule_extra.c
    src/black_box.c
    src/compress_c.c)
  target_include_directories(${name} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/../c/include")
  target_link_libraries(${name} PRIVATE ZLIB::ZLIB ${FORTRAN_ZSTD})
  if(ZSTD_FOUND)
    target_compile_definitions(${name} PRIVATE HAS_ZSTD)
    target_include_directories(${name} PRIVATE ${ZSTD_INCLUDE_DIRS})
  endif()
  target_compile_options(${name} PRIVATE
    $<$<COMPILE_LANGUAGE:Fortran>:-O2 -fno-lto>
    $<$<COMPILE_LANGUAGE:C>:-O2 -fno-lto>)
endfunction()

# The benchmark executable is built by fpm (fortran/fpm.toml) because it links
# the Fortran package dependencies. This target is the dependency-free
# round-trip and schedule test.
fortran_target(test_roundtrip
  test/test_roundtrip.f90
  src/data.f90
  src/custom_binary.f90
  src/schedule.f90)
