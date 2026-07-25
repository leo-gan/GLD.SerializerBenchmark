cmake_minimum_required(VERSION 3.14)
project(serializer_benchmark_c C CXX)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()
add_compile_options(-O2 -Wall -Wno-unused-function)

set(TP ${CMAKE_CURRENT_SOURCE_DIR}/third_party)
set(TP_BUILD ${TP}/_build)
set(TP_PREFIX ${TP}/_prefix)

set(BENCH_SOURCES
  src/main.c
  src/data.c
  src/data_v2.c
  src/run_v2.c
  src/schedule.c
  src/csv_log.c
  src/batch_cell.c
  src/runner.c
  src/register_serializers.c
  src/v2_codec.c
  src/serializers/ser_custom_binary.c
)
set(BENCH_LIBS m)
set(BENCH_INCLUDES
  ${CMAKE_CURRENT_SOURCE_DIR}/include
  ${CMAKE_CURRENT_SOURCE_DIR}/src
)
add_compile_definitions(HAS_CUSTOM_BINARY=1)

if(EXISTS ${TP}/cJSON/cJSON.c)
  list(APPEND BENCH_SOURCES ${TP}/cJSON/cJSON.c src/serializers/ser_cjson.c)
  list(APPEND BENCH_INCLUDES ${TP}/cJSON)
  add_compile_definitions(HAS_CJSON=1)
  message(STATUS "serializer: cJSON REAL")
endif()

if(EXISTS ${TP}/yyjson/src/yyjson.c)
  list(APPEND BENCH_SOURCES ${TP}/yyjson/src/yyjson.c src/serializers/ser_yyjson.c)
  list(APPEND BENCH_INCLUDES ${TP}/yyjson/src)
  add_compile_definitions(HAS_YYJSON=1)
  message(STATUS "serializer: yyjson REAL")
endif()

if(EXISTS ${TP_BUILD}/parson_pref/libparson_pref.a)
  list(APPEND BENCH_SOURCES src/serializers/ser_parson.c)
  list(APPEND BENCH_INCLUDES ${TP}/parson)
  list(APPEND BENCH_LIBS ${TP_BUILD}/parson_pref/libparson_pref.a)
  add_compile_definitions(HAS_PARSON=1)
  message(STATUS "serializer: parson REAL (prefixed)")
endif()

if(EXISTS ${TP_PREFIX}/lib/libjansson.a)
  list(APPEND BENCH_SOURCES src/serializers/ser_jansson.c)
  list(APPEND BENCH_INCLUDES ${TP_PREFIX}/include)
  list(APPEND BENCH_LIBS ${TP_PREFIX}/lib/libjansson.a)
  add_compile_definitions(HAS_JANSSON=1)
  message(STATUS "serializer: jansson REAL")
endif()

find_package(PkgConfig QUIET)
if(PkgConfig_FOUND)
  pkg_check_modules(JSONC QUIET json-c)
endif()
if(JSONC_FOUND)
  list(APPEND BENCH_SOURCES src/serializers/ser_json_c.c)
  list(APPEND BENCH_INCLUDES ${JSONC_INCLUDE_DIRS})
  list(APPEND BENCH_LIBS ${JSONC_LIBRARIES})
  add_compile_definitions(HAS_JSON_C=1)
  message(STATUS "serializer: json-c REAL")
endif()

if(EXISTS ${TP}/mpack/src/mpack/mpack-common.c)
  file(GLOB MPACK_SRC ${TP}/mpack/src/mpack/mpack-*.c)
  list(APPEND BENCH_SOURCES ${MPACK_SRC} src/serializers/ser_mpack.c)
  list(APPEND BENCH_INCLUDES ${TP}/mpack/src)
  add_compile_definitions(HAS_MPACK=1)
  message(STATUS "serializer: mpack REAL")
endif()

if(EXISTS ${TP_BUILD}/msgpack-c/libmsgpack-c.a)
  list(APPEND BENCH_SOURCES src/serializers/ser_msgpack_c.c)
  list(APPEND BENCH_INCLUDES ${TP}/msgpack-c/include ${TP}/msgpack-c/include/msgpack ${TP_BUILD}/msgpack-c/include/msgpack ${TP_BUILD}/msgpack-c/include)
  list(APPEND BENCH_LIBS ${TP_BUILD}/msgpack-c/libmsgpack-c.a)
  add_compile_definitions(HAS_MSGPACK_C=1)
  message(STATUS "serializer: msgpack-c REAL")
endif()

if(EXISTS ${TP_BUILD}/tinycbor_pref/libtinycbor_tc.a)
  list(APPEND BENCH_SOURCES src/serializers/ser_tinycbor.c)
  list(APPEND BENCH_INCLUDES ${TP}/tinycbor/src)
  list(APPEND BENCH_LIBS ${TP_BUILD}/tinycbor_pref/libtinycbor_tc.a)
  add_compile_definitions(HAS_TINYCBOR=1)
  message(STATUS "serializer: tinycbor REAL (prefixed)")
endif()

if(EXISTS ${TP_BUILD}/libcbor/src/libcbor.a)
  list(APPEND BENCH_SOURCES src/serializers/ser_libcbor.c)
  list(APPEND BENCH_INCLUDES ${TP}/libcbor/src ${TP_BUILD}/libcbor ${TP_BUILD}/libcbor/src)
  list(APPEND BENCH_LIBS ${TP_BUILD}/libcbor/src/libcbor.a)
  add_compile_definitions(HAS_LIBCBOR=1)
  message(STATUS "serializer: libcbor/cbor-encode REAL")
endif()

if(EXISTS ${TP}/QCBOR/src/qcbor_encode.c)
  list(APPEND BENCH_SOURCES
    ${TP}/QCBOR/src/UsefulBuf.c
    ${TP}/QCBOR/src/qcbor_encode.c
    ${TP}/QCBOR/src/qcbor_decode.c
    ${TP}/QCBOR/src/ieee754.c
    src/serializers/ser_qcbor.c)
  list(APPEND BENCH_INCLUDES ${TP}/QCBOR/inc)
  add_compile_definitions(HAS_QCBOR=1)
  message(STATUS "serializer: qcbor REAL")
endif()

list(APPEND BENCH_SOURCES src/serializers/ser_ubj.c)
add_compile_definitions(HAS_UBJ=1)
message(STATUS "serializer: ubj REAL (spec-min)")

if(EXISTS ${TP_BUILD}/libbson/src/libbson/libbson-static-1.0.a)
  list(APPEND BENCH_SOURCES src/serializers/ser_libbson.c)
  list(APPEND BENCH_INCLUDES
    ${TP}/mongo-c-driver/src/libbson/src
    ${TP_BUILD}/libbson/src/libbson/src
    ${TP_BUILD}/libbson/src/libbson)
  list(APPEND BENCH_LIBS ${TP_BUILD}/libbson/src/libbson/libbson-static-1.0.a)
  add_compile_definitions(HAS_LIBBSON=1)
  message(STATUS "serializer: libbson REAL")
endif()

if(EXISTS ${TP}/nanopb/pb_encode.c)
  list(APPEND BENCH_SOURCES
    ${TP}/nanopb/pb_common.c
    ${TP}/nanopb/pb_encode.c
    ${TP}/nanopb/pb_decode.c
    src/serializers/ser_nanopb.c)
  list(APPEND BENCH_INCLUDES ${TP}/nanopb)
  add_compile_definitions(HAS_NANOPB=1)
  message(STATUS "serializer: nanopb REAL")
endif()

if(EXISTS ${TP}/protobuf-c/protobuf-c/protobuf-c.c)
  list(APPEND BENCH_SOURCES ${TP}/protobuf-c/protobuf-c/protobuf-c.c src/serializers/ser_protobuf_c.c)
  list(APPEND BENCH_INCLUDES ${TP}/protobuf-c)
  add_compile_definitions(HAS_PROTOBUF_C=1)
  message(STATUS "serializer: protobuf-c REAL")
endif()

list(APPEND BENCH_SOURCES src/serializers/ser_upb.c)
add_compile_definitions(HAS_UPB_WIRE=1)
message(STATUS "serializer: protobuf-wire (in-tree; historical log name was upb)")

# ---- Official Google libprotobuf (reuse cpp suite sysroot or system) ----
set(PB_SYSROOT "${CMAKE_CURRENT_SOURCE_DIR}/../cpp/third_party/protobuf-sysroot")
set(PB_SYSROOT_PROTOC "${PB_SYSROOT}/usr/bin/protoc")
set(PB_SYSROOT_INC "${PB_SYSROOT}/usr/include")
set(PB_SYSROOT_LIBDIR "${PB_SYSROOT}/usr/lib/x86_64-linux-gnu")
set(PB_SYSROOT_LIB "${PB_SYSROOT_LIBDIR}/libprotobuf.a")
set(BENCH_HAS_LIBPROTOBUF 0)
if(EXISTS "${PB_SYSROOT_PROTOC}" AND EXISTS "${PB_SYSROOT_INC}/google/protobuf/message.h" AND EXISTS "${PB_SYSROOT_LIB}")
  set(BENCH_HAS_LIBPROTOBUF 1)
  set(BENCH_PROTOC "${PB_SYSROOT_PROTOC}")
  set(BENCH_PROTOBUF_INC "${PB_SYSROOT_INC}")
  set(BENCH_PROTOBUF_LIB "${PB_SYSROOT_LIB}")
  set(BENCH_PROTOBUF_LIBDIR "${PB_SYSROOT_LIBDIR}")
  message(STATUS "serializer: protobuf (Google libprotobuf) REAL via ${PB_SYSROOT}")
else()
  find_package(Protobuf QUIET)
  if(Protobuf_FOUND AND Protobuf_PROTOC_EXECUTABLE)
    set(BENCH_HAS_LIBPROTOBUF 1)
    set(BENCH_PROTOC "${Protobuf_PROTOC_EXECUTABLE}")
    set(BENCH_PROTOBUF_INC "${Protobuf_INCLUDE_DIRS}")
    set(BENCH_PROTOBUF_LIB "${Protobuf_LIBRARIES}")
    message(STATUS "serializer: protobuf (Google libprotobuf) REAL via find_package")
  else()
    message(STATUS "serializer: protobuf (Google libprotobuf) SKIPPED — run cpp/scripts/setup-protobuf-sysroot.sh")
  endif()
endif()

if(BENCH_HAS_LIBPROTOBUF)
  set(PB_PROTO "${CMAKE_CURRENT_SOURCE_DIR}/../schemas/v2/protobuf/benchmark_v2.proto")
  set(PB_GEN_DIR "${CMAKE_CURRENT_BINARY_DIR}/generated")
  file(MAKE_DIRECTORY ${PB_GEN_DIR})
  set(PB_GEN_CC "${PB_GEN_DIR}/benchmark_v2.pb.cc")
  set(PB_GEN_H "${PB_GEN_DIR}/benchmark_v2.pb.h")
  add_custom_command(
    OUTPUT ${PB_GEN_CC} ${PB_GEN_H}
    COMMAND ${CMAKE_COMMAND} -E env
            "LD_LIBRARY_PATH=${BENCH_PROTOBUF_LIBDIR}:$ENV{LD_LIBRARY_PATH}"
            ${BENCH_PROTOC}
            --cpp_out=${PB_GEN_DIR}
            -I ${CMAKE_CURRENT_SOURCE_DIR}/../schemas/v2/protobuf
            ${PB_PROTO}
    DEPENDS ${PB_PROTO}
    COMMENT "Generating Google libprotobuf C++ stubs (benchmark_v2.proto)"
    VERBATIM
  )
  list(APPEND BENCH_SOURCES src/serializers/ser_protobuf_google.cpp ${PB_GEN_CC})
  list(APPEND BENCH_INCLUDES ${PB_GEN_DIR} ${BENCH_PROTOBUF_INC})
  list(APPEND BENCH_LIBS ${BENCH_PROTOBUF_LIB} pthread stdc++)
  add_compile_definitions(HAS_LIBPROTOBUF=1)
endif()

if(EXISTS ${TP}/flatcc/src/runtime/builder.c)
  list(APPEND BENCH_SOURCES
    ${TP}/flatcc/src/runtime/builder.c
    ${TP}/flatcc/src/runtime/emitter.c
    ${TP}/flatcc/src/runtime/refmap.c
    src/serializers/ser_flatcc.c)
  list(APPEND BENCH_INCLUDES ${TP}/flatcc/include)
  add_compile_definitions(HAS_FLATCC=1)
  message(STATUS "serializer: flatcc REAL")
endif()

if(EXISTS ${TP_BUILD}/avro-c/src/libavro.a)
  list(APPEND BENCH_SOURCES src/serializers/ser_avro_c.c)
  list(APPEND BENCH_INCLUDES ${TP}/avro/lang/c/src ${TP_PREFIX}/include)
  list(APPEND BENCH_LIBS ${TP_BUILD}/avro-c/src/libavro.a ${TP_PREFIX}/lib/libjansson.a z)
  find_library(LZMA_LIB lzma)
  if(LZMA_LIB)
    list(APPEND BENCH_LIBS ${LZMA_LIB})
  endif()
  add_compile_definitions(HAS_AVRO_C=1)
  message(STATUS "serializer: avro-c REAL")
endif()

if(EXISTS ${TP}/zcbor/src/zcbor_encode.c)
  list(APPEND BENCH_SOURCES
    ${TP}/zcbor/src/zcbor_common.c
    ${TP}/zcbor/src/zcbor_encode.c
    ${TP}/zcbor/src/zcbor_decode.c
    src/serializers/ser_zcbor.c)
  list(APPEND BENCH_INCLUDES ${TP}/zcbor/include)
  add_compile_definitions(HAS_ZCBOR=1)
  message(STATUS "serializer: zcbor REAL")
endif()

add_executable(serializer_benchmark_c ${BENCH_SOURCES})
target_include_directories(serializer_benchmark_c PRIVATE ${BENCH_INCLUDES})
target_link_libraries(serializer_benchmark_c PRIVATE ${BENCH_LIBS})

# Unit / round-trip tests (same library graph as the benchmark harness)
set(TEST_SOURCES ${BENCH_SOURCES})
list(REMOVE_ITEM TEST_SOURCES src/main.c)
list(APPEND TEST_SOURCES tests/test_roundtrip.c)
add_executable(c_serializer_tests ${TEST_SOURCES})
target_include_directories(c_serializer_tests PRIVATE ${BENCH_INCLUDES})
target_link_libraries(c_serializer_tests PRIVATE ${BENCH_LIBS})
enable_testing()
add_test(NAME c_serializer_roundtrip COMMAND c_serializer_tests)
