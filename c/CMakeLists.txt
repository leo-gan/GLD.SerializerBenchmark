cmake_minimum_required(VERSION 3.14)
project(serializer_benchmark_c C)
set(CMAKE_C_STANDARD 11)
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()
add_compile_options(-O2 -Wall)
add_executable(serializer_benchmark_c
  src/main.c
  src/data.c
  src/csv_log.c
  src/runner.c
  src/register_serializers.c
)
target_include_directories(serializer_benchmark_c PRIVATE include src)
target_link_libraries(serializer_benchmark_c m)
