cmake_minimum_required(VERSION 3.16)
project(serializer_benchmark_cpp LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_C_STANDARD 11)
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()
add_compile_options($<$<COMPILE_LANGUAGE:CXX>:-O2> $<$<COMPILE_LANGUAGE:C>:-O2> -Wall)

include(FetchContent)
set(FETCHCONTENT_QUIET OFF)
set(CPP_TP "${CMAKE_CURRENT_SOURCE_DIR}/third_party")
set(FETCHCONTENT_BASE_DIR "${CPP_TP}/_fetch")

# ---- Dependencies (pinned) ----
# nlohmann/json
FetchContent_Declare(nlohmann_json
  GIT_REPOSITORY https://github.com/nlohmann/json.git
  GIT_TAG v3.11.3
  GIT_SHALLOW TRUE
  SOURCE_DIR ${CPP_TP}/nlohmann_json
)
set(JSON_BuildTests OFF CACHE BOOL "" FORCE)
set(JSON_Install OFF CACHE BOOL "" FORCE)

# RapidJSON (header-only)
FetchContent_Declare(rapidjson
  GIT_REPOSITORY https://github.com/Tencent/rapidjson.git
  GIT_TAG v1.1.0
  GIT_SHALLOW TRUE
  SOURCE_DIR ${CPP_TP}/rapidjson
)
set(RAPIDJSON_BUILD_DOC OFF CACHE BOOL "" FORCE)
set(RAPIDJSON_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(RAPIDJSON_BUILD_TESTS OFF CACHE BOOL "" FORCE)

# simdjson
FetchContent_Declare(simdjson
  GIT_REPOSITORY https://github.com/simdjson/simdjson.git
  GIT_TAG v3.10.1
  GIT_SHALLOW TRUE
  SOURCE_DIR ${CPP_TP}/simdjson
)
set(SIMDJSON_JUST_LIBRARY ON CACHE INTERNAL "")
set(SIMDJSON_BUILD_STATIC ON CACHE INTERNAL "")


# ArduinoJson
FetchContent_Declare(ArduinoJson
  GIT_REPOSITORY https://github.com/bblanchon/ArduinoJson.git
  GIT_TAG v7.2.1
  GIT_SHALLOW TRUE
  SOURCE_DIR ${CPP_TP}/ArduinoJson
)

# yyjson (C — dual C/C++ suite entry)
FetchContent_Declare(yyjson
  GIT_REPOSITORY https://github.com/ibireme/yyjson.git
  GIT_TAG 0.10.0
  GIT_SHALLOW TRUE
  SOURCE_DIR ${CPP_TP}/yyjson
)

# msgpack-c (C++ headers, MSG PACK_USE_DEFINE_MAP path)
FetchContent_Declare(msgpack
  GIT_REPOSITORY https://github.com/msgpack/msgpack-c.git
  GIT_TAG cpp-6.1.1
  GIT_SHALLOW TRUE
  SOURCE_DIR ${CPP_TP}/msgpack-c
)
set(MSGPACK_USE_BOOST OFF CACHE BOOL "" FORCE)
set(MSGPACK_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(MSGPACK_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)

# cereal
FetchContent_Declare(cereal
  GIT_REPOSITORY https://github.com/USCiLab/cereal.git
  GIT_TAG v1.3.2
  GIT_SHALLOW TRUE
  SOURCE_DIR ${CPP_TP}/cereal
)
set(BUILD_DOC OFF CACHE BOOL "" FORCE)
set(BUILD_SANDBOX OFF CACHE BOOL "" FORCE)
set(SKIP_PERFORMANCE_COMPARISON ON CACHE BOOL "" FORCE)
set(BUILD_TESTS OFF CACHE BOOL "" FORCE)

# bitsery
FetchContent_Declare(bitsery
  GIT_REPOSITORY https://github.com/fraillt/bitsery.git
  GIT_TAG v5.2.4
  GIT_SHALLOW TRUE
  SOURCE_DIR ${CPP_TP}/bitsery
)

# zpp_bits (header-only single file)
FetchContent_Declare(zpp_bits
  GIT_REPOSITORY https://github.com/eyalz800/zpp_bits.git
  GIT_TAG v4.4.25
  GIT_SHALLOW TRUE
  SOURCE_DIR ${CPP_TP}/zpp_bits
)

# jsoncons
FetchContent_Declare(jsoncons
  GIT_REPOSITORY https://github.com/danielaparker/jsoncons.git
  GIT_TAG v0.177.0
  GIT_SHALLOW TRUE
  SOURCE_DIR ${CPP_TP}/jsoncons
)


# YAS — ultra-fast binary (header-only)
FetchContent_Declare(yas
  GIT_REPOSITORY https://github.com/niXman/yas.git
  GIT_TAG 7.1.0
  GIT_SHALLOW TRUE
  SOURCE_DIR ${CPP_TP}/yas
)

# Cista++ — high-performance offset serialization
FetchContent_Declare(cista
  GIT_REPOSITORY https://github.com/felixguendling/cista.git
  GIT_TAG v0.15
  GIT_SHALLOW TRUE
  SOURCE_DIR ${CPP_TP}/cista
)

# flatbuffers (flexbuffers + builder)
FetchContent_Declare(flatbuffers
  GIT_REPOSITORY https://github.com/google/flatbuffers.git
  GIT_TAG v24.3.25
  GIT_SHALLOW TRUE
  SOURCE_DIR ${CPP_TP}/flatbuffers
)
set(FLATBUFFERS_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(FLATBUFFERS_INSTALL OFF CACHE BOOL "" FORCE)
set(FLATBUFFERS_BUILD_FLATC ON CACHE BOOL "" FORCE)

message(STATUS "Fetching C++ serializer dependencies (first run may take several minutes)...")
FetchContent_MakeAvailable(
  nlohmann_json rapidjson simdjson ArduinoJson yyjson msgpack cereal bitsery zpp_bits jsoncons yas cista flatbuffers
)

# rapidjson does not always export a target on old tags — ensure include
if(NOT TARGET rapidjson)
  add_library(rapidjson INTERFACE)
  target_include_directories(rapidjson INTERFACE ${CPP_TP}/rapidjson/include)
endif()

# zpp_bits header path
add_library(zpp_bits_hdr INTERFACE)
target_include_directories(zpp_bits_hdr INTERFACE ${CPP_TP}/zpp_bits)

add_library(yas_hdr INTERFACE)
target_include_directories(yas_hdr INTERFACE ${CPP_TP}/yas/include)

add_library(cista_hdr INTERFACE)
target_include_directories(cista_hdr INTERFACE ${CPP_TP}/cista/include)
# single-header layout fallback
if(EXISTS ${CPP_TP}/cista/include/cista.h)
  # ok
elseif(EXISTS ${CPP_TP}/cista/cista.h)
  target_include_directories(cista_hdr INTERFACE ${CPP_TP}/cista)
endif()


# ---- Harness ----
set(BENCH_SOURCES
  src/main.cpp
  src/data_v2.cpp
  src/csv_log.cpp
  src/cells.cpp
  src/register.cpp
  src/serializers/ser_json.cpp
  src/serializers/ser_binary.cpp
  src/serializers/ser_cereal.cpp
  src/serializers/ser_bitsery.cpp
  src/serializers/ser_zpp_bits.cpp
  src/serializers/ser_nlohmann_bin.cpp
  src/serializers/ser_yas.cpp
  src/serializers/ser_cista.cpp
  src/serializers/ser_avro.cpp
  src/serializers/ser_avro_c.cpp
  src/serializers/ser_thrift.cpp
  src/serializers/ser_boost.cpp
  src/serializers/ser_capnp.cpp
  src/serializers/ser_schema.cpp
)

add_executable(serializer_benchmark_cpp ${BENCH_SOURCES})
target_include_directories(serializer_benchmark_cpp PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/include
  ${CPP_TP}/rapidjson/include
  ${CPP_TP}/zpp_bits
  ${CPP_TP}/msgpack-c/include
  ${CMAKE_CURRENT_BINARY_DIR}/generated
)
target_link_libraries(serializer_benchmark_cpp PRIVATE
  nlohmann_json::nlohmann_json
  simdjson
  ArduinoJson
  yyjson
  cereal::cereal
  Bitsery::bitsery
  jsoncons
  flatbuffers
  zpp_bits_hdr
  yas_hdr
  cista_hdr
  pthread
)

# msgpack-cxx is header-only in cpp-6.x
if(TARGET msgpack-cxx)
  target_link_libraries(serializer_benchmark_cpp PRIVATE msgpack-cxx)
elseif(TARGET msgpackc-cxx)
  target_link_libraries(serializer_benchmark_cpp PRIVATE msgpackc-cxx)
endif()

# Generate flatbuffers headers when flatc is available
if(TARGET flatc)
  set(FBS ${CMAKE_CURRENT_SOURCE_DIR}/schemas/benchmark.fbs)
  set(GEN_DIR ${CMAKE_CURRENT_BINARY_DIR}/generated)
  file(MAKE_DIRECTORY ${GEN_DIR})
  add_custom_command(
    OUTPUT ${GEN_DIR}/benchmark_generated.h
    COMMAND flatc --cpp -o ${GEN_DIR} ${FBS}
    DEPENDS flatc ${FBS}
    COMMENT "Generating FlatBuffers C++ headers"
  )
  add_custom_target(cpp_fbs_gen DEPENDS ${GEN_DIR}/benchmark_generated.h)
  add_dependencies(serializer_benchmark_cpp cpp_fbs_gen)
  target_compile_definitions(serializer_benchmark_cpp PRIVATE HAS_FLATBUFFERS_GENERATED=1)
endif()

# ---- Tests ----
add_executable(cpp_serializer_tests
  tests/test_roundtrip.cpp
  src/data_v2.cpp
  src/register.cpp
  src/serializers/ser_json.cpp
  src/serializers/ser_binary.cpp
  src/serializers/ser_cereal.cpp
  src/serializers/ser_bitsery.cpp
  src/serializers/ser_zpp_bits.cpp
  src/serializers/ser_nlohmann_bin.cpp
  src/serializers/ser_yas.cpp
  src/serializers/ser_cista.cpp
  src/serializers/ser_avro.cpp
  src/serializers/ser_avro_c.cpp
  src/serializers/ser_thrift.cpp
  src/serializers/ser_boost.cpp
  src/serializers/ser_capnp.cpp
  src/serializers/ser_schema.cpp
)
target_include_directories(cpp_serializer_tests PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/include
  ${CPP_TP}/rapidjson/include
  ${CPP_TP}/zpp_bits
  ${CPP_TP}/msgpack-c/include
  ${CMAKE_CURRENT_BINARY_DIR}/generated
)
target_link_libraries(cpp_serializer_tests PRIVATE
  nlohmann_json::nlohmann_json
  simdjson
  ArduinoJson
  yyjson
  cereal::cereal
  Bitsery::bitsery
  jsoncons
  flatbuffers
  zpp_bits_hdr
  yas_hdr
  cista_hdr
  pthread
)
if(TARGET msgpack-cxx)
  target_link_libraries(cpp_serializer_tests PRIVATE msgpack-cxx)
elseif(TARGET msgpackc-cxx)
  target_link_libraries(cpp_serializer_tests PRIVATE msgpackc-cxx)
endif()

# ---- Optional: Boost.Serialization ----
find_package(Boost QUIET COMPONENTS serialization)
find_library(BOOST_SERIALIZATION_LIB NAMES boost_serialization boost_serialization-mt)
if(Boost_FOUND AND BOOST_SERIALIZATION_LIB)
  if(NOT TARGET Boost::serialization)
    add_library(Boost::serialization UNKNOWN IMPORTED)
    set_target_properties(Boost::serialization PROPERTIES IMPORTED_LOCATION "${BOOST_SERIALIZATION_LIB}")
    if(Boost_INCLUDE_DIRS)
      set_target_properties(Boost::serialization PROPERTIES INTERFACE_INCLUDE_DIRECTORIES "${Boost_INCLUDE_DIRS}")
    endif()
  endif()
  message(STATUS "serializer: boost_serialization REAL")
  target_compile_definitions(serializer_benchmark_cpp PRIVATE HAS_BOOST_SERIALIZATION=1)
  target_compile_definitions(cpp_serializer_tests PRIVATE HAS_BOOST_SERIALIZATION=1)
  target_link_libraries(serializer_benchmark_cpp PRIVATE Boost::serialization)
  target_link_libraries(cpp_serializer_tests PRIVATE Boost::serialization)
else()
  # Still compile ser_boost.cpp only when found — use empty stub otherwise
  message(STATUS "serializer: boost_serialization SKIPPED (install libboost-serialization-dev)")
  target_compile_definitions(serializer_benchmark_cpp PRIVATE HAS_BOOST_SERIALIZATION=0)
  target_compile_definitions(cpp_serializer_tests PRIVATE HAS_BOOST_SERIALIZATION=0)
endif()

# ---- Optional: avro-c (prefer monorepo C third_party static lib) ----
set(AVRO_C_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../c/third_party")
set(AVRO_C_LIB "${AVRO_C_ROOT}/_build/avro-c/src/libavro.a")
set(AVRO_C_INC "${AVRO_C_ROOT}/avro/lang/c/src")
if(EXISTS "${AVRO_C_LIB}" AND EXISTS "${AVRO_C_INC}/avro.h")
  message(STATUS "serializer: avro_c REAL (${AVRO_C_LIB})")
  target_compile_definitions(serializer_benchmark_cpp PRIVATE HAS_AVRO_C=1)
  target_compile_definitions(cpp_serializer_tests PRIVATE HAS_AVRO_C=1)
  target_include_directories(serializer_benchmark_cpp PRIVATE ${AVRO_C_INC})
  target_include_directories(cpp_serializer_tests PRIVATE ${AVRO_C_INC})
  set(_avro_link ${AVRO_C_LIB} z lzma m)
  if(EXISTS "${AVRO_C_ROOT}/_prefix/lib/libjansson.a")
    list(APPEND _avro_link ${AVRO_C_ROOT}/_prefix/lib/libjansson.a)
  else()
    list(APPEND _avro_link jansson)
  endif()
  target_link_libraries(serializer_benchmark_cpp PRIVATE ${_avro_link})
  target_link_libraries(cpp_serializer_tests PRIVATE ${_avro_link})
else()
  message(STATUS "serializer: avro_c SKIPPED (build c/ third_party avro first: c/scripts/fetch-and-build-deps.sh)")
  target_compile_definitions(serializer_benchmark_cpp PRIVATE HAS_AVRO_C=0)
  target_compile_definitions(cpp_serializer_tests PRIVATE HAS_AVRO_C=0)
endif()


# ---- Optional: Cap'n Proto (FetchContent) ----
option(BENCH_CPP_CAPNP "Build Cap'n Proto serializer (FetchContent)" ON)
if(BENCH_CPP_CAPNP)
  FetchContent_Declare(capnproto
    GIT_REPOSITORY https://github.com/capnproto/capnproto.git
    GIT_TAG v1.0.2
    GIT_SHALLOW TRUE
    SOURCE_DIR ${CPP_TP}/capnproto
  )
  set(BUILD_TESTING OFF CACHE BOOL "" FORCE)
  FetchContent_GetProperties(capnproto)
  if(NOT capnproto_POPULATED)
    FetchContent_Populate(capnproto)
    add_subdirectory(${capnproto_SOURCE_DIR}/c++ ${capnproto_BINARY_DIR} EXCLUDE_FROM_ALL)
  endif()
  if(TARGET capnp AND TARGET kj AND TARGET capnp_tool AND TARGET capnpc_cpp)
    message(STATUS "serializer: capnproto REAL")
    set(CAPNP_SCHEMA ${CMAKE_CURRENT_SOURCE_DIR}/schemas/benchmark.capnp)
    set(CAPNP_GEN_DIR ${CMAKE_CURRENT_BINARY_DIR}/generated)
    file(MAKE_DIRECTORY ${CAPNP_GEN_DIR})
    add_custom_command(
      OUTPUT ${CAPNP_GEN_DIR}/benchmark.capnp.h ${CAPNP_GEN_DIR}/benchmark.capnp.c++
      COMMAND ${CMAKE_COMMAND} -E make_directory ${CAPNP_GEN_DIR}
      COMMAND $<TARGET_FILE:capnp_tool>
              compile
              -o$<TARGET_FILE:capnpc_cpp>:${CAPNP_GEN_DIR}
              --src-prefix=${CMAKE_CURRENT_SOURCE_DIR}/schemas
              ${CAPNP_SCHEMA}
      DEPENDS capnp_tool capnpc_cpp ${CAPNP_SCHEMA}
      COMMENT "Generating Cap'n Proto C++ for benchmark.capnp"
      VERBATIM
    )
    add_custom_target(cpp_capnp_gen DEPENDS ${CAPNP_GEN_DIR}/benchmark.capnp.h ${CAPNP_GEN_DIR}/benchmark.capnp.c++)
    target_sources(serializer_benchmark_cpp PRIVATE ${CAPNP_GEN_DIR}/benchmark.capnp.c++)
    target_sources(cpp_serializer_tests PRIVATE ${CAPNP_GEN_DIR}/benchmark.capnp.c++)
    add_dependencies(serializer_benchmark_cpp cpp_capnp_gen)
    add_dependencies(cpp_serializer_tests cpp_capnp_gen)
    target_compile_definitions(serializer_benchmark_cpp PRIVATE HAS_CAPNP=1)
    target_compile_definitions(cpp_serializer_tests PRIVATE HAS_CAPNP=1)
    target_include_directories(serializer_benchmark_cpp PRIVATE ${CAPNP_GEN_DIR})
    target_include_directories(cpp_serializer_tests PRIVATE ${CAPNP_GEN_DIR})
    target_link_libraries(serializer_benchmark_cpp PRIVATE capnp kj)
    target_link_libraries(cpp_serializer_tests PRIVATE capnp kj)
  else()
    message(STATUS "serializer: capnproto SKIPPED (targets missing)")
    target_compile_definitions(serializer_benchmark_cpp PRIVATE HAS_CAPNP=0)
    target_compile_definitions(cpp_serializer_tests PRIVATE HAS_CAPNP=0)
  endif()
else()
  message(STATUS "serializer: capnproto disabled (BENCH_CPP_CAPNP=OFF)")
  target_compile_definitions(serializer_benchmark_cpp PRIVATE HAS_CAPNP=0)
  target_compile_definitions(cpp_serializer_tests PRIVATE HAS_CAPNP=0)
endif()


enable_testing()
add_test(NAME cpp_roundtrip COMMAND cpp_serializer_tests)


message(STATUS "C++ serializer benchmark configured (23 codecs)")
