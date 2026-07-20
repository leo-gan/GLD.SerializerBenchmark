#ifndef BENCH_H
#define BENCH_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>

#define BENCH_MAX_SERIALIZERS 32
#define BENCH_MAX_NAME 64

/* Data Model v2 only — message / document / telemetry / strings / event */

#define V2_MAX_CHILDREN 16
#define V2_MAX_POINTS 64
#define V2_MAX_STRINGS 64
#define V2_MAX_TAGS 8
#define V2_MAX_ATTRS 16
#define V2_STR 48

typedef enum {
    TD_MESSAGE = 0,
    TD_DOCUMENT,
    TD_TELEMETRY,
    TD_STRINGS,
    TD_EVENT,
    TD_COUNT
} test_data_kind_t;

typedef struct {
    bool f_bool;
    int32_t f_int32;
    int64_t f_int64;
    double f_float64;
    char f_string[V2_STR];
    bool f_bool_2;
    int32_t f_int32_2;
    char f_string_2[V2_STR];
} message_t;

typedef struct {
    char region[V2_STR];
    int32_t version;
} document_meta_t;

typedef struct {
    char sku[V2_STR];
    int32_t qty;
    int64_t price_minor;
} document_item_t;

typedef struct {
    char id[V2_STR];
    int32_t status;
    document_meta_t meta;
    int item_count;
    document_item_t items[V2_MAX_CHILDREN];
} document_t;

typedef struct {
    char source[V2_STR];
    int64_t ts;
    int tag_count;
    char tags[V2_MAX_TAGS][V2_STR];
    int value_count;
    double values[V2_MAX_POINTS];
} telemetry_t;

typedef struct {
    int count;
    char items[V2_MAX_STRINGS][V2_STR];
} strings_t;

typedef struct {
    char key[V2_STR];
    char value[V2_STR];
} event_attr_t;

typedef struct {
    char event_id[V2_STR];
    char event_type[V2_STR];
    int64_t occurred_at;
    char producer[V2_STR];
    int attr_count;
    event_attr_t attrs[V2_MAX_ATTRS];
} event_t;

typedef struct test_fixture test_fixture_t;
struct test_fixture {
    test_data_kind_t kind;
    const char *name;
    message_t message;
    document_t document;
    telemetry_t telemetry;
    strings_t strings;
    event_t event;
    /* Batch cell: batch_n==1 uses fields above; batch_n>1 uses heap array. */
    int batch_n;
    test_fixture_t *batch;
};

typedef struct {
    const char *name;
    const char *version;
    const char *category;
    bool (*supports)(test_data_kind_t kind);
    int (*prepare)(test_data_kind_t kind, const test_fixture_t *fx);
    int (*serialize)(const test_fixture_t *fx, uint8_t *buf, size_t buf_cap, size_t *out_len);
    int (*deserialize)(const uint8_t *buf, size_t len, test_fixture_t *out_fx, test_data_kind_t kind);
    bool (*fidelity)(const test_fixture_t *a, const test_fixture_t *b);
} serializer_t;

#ifdef __cplusplus
extern "C" {
#endif
void data_init_all(test_fixture_t *out, int count, uint64_t seed);
void data_make_one(test_fixture_t *out, test_data_kind_t kind, uint64_t seed, int instance_index,
                   int children, int points, int str_count, int attr_count);
const char *test_data_name(test_data_kind_t k);
#ifdef __cplusplus
}
#endif

typedef struct csv_logger csv_logger_t;
csv_logger_t *csv_logger_create(const char *path);
void csv_logger_write(csv_logger_t *L, const char *mode, const char *td,
                      int reps, int rep_idx, const char *ser,
                      uint64_t ser_ns, uint64_t deser_ns, size_t size,
                      double fidelity, const char *version,
                      int instance_count, const char *type_config_hash);
void csv_logger_close(csv_logger_t *L);

int bench_serialize_cell(const serializer_t *S, const test_fixture_t *fx,
                         uint8_t *buf, size_t buf_cap, size_t *out_len);
int bench_deserialize_cell(const serializer_t *S, const uint8_t *buf, size_t len,
                           test_fixture_t *out_fx, test_data_kind_t kind);

void register_all_serializers(serializer_t *out, int *count);

void bench_register_cjson(serializer_t *out, int *count);
void bench_register_yyjson(serializer_t *out, int *count);
void bench_register_jansson(serializer_t *out, int *count);
void bench_register_parson(serializer_t *out, int *count);
void bench_register_json_c(serializer_t *out, int *count);
void bench_register_mpack(serializer_t *out, int *count);
void bench_register_msgpack_c(serializer_t *out, int *count);
void bench_register_tinycbor(serializer_t *out, int *count);
void bench_register_libcbor(serializer_t *out, int *count);
void bench_register_qcbor(serializer_t *out, int *count);
void bench_register_ubj(serializer_t *out, int *count);
void bench_register_libbson(serializer_t *out, int *count);
void bench_register_custom_binary(serializer_t *out, int *count);
void bench_register_nanopb(serializer_t *out, int *count);
void bench_register_protobuf_c(serializer_t *out, int *count);
void bench_register_upb(serializer_t *out, int *count);
#ifdef __cplusplus
extern "C" {
#endif
void bench_register_protobuf_google(serializer_t *out, int *count);
#ifdef __cplusplus
}
#endif
void bench_register_flatcc(serializer_t *out, int *count);
void bench_register_avro_c(serializer_t *out, int *count);
void bench_register_zcbor(serializer_t *out, int *count);

int bench_stream_write_all(const uint8_t *buf, size_t len);
int bench_stream_read_all(uint8_t *buf, size_t cap, size_t expect_len);

/* Optimization barrier (issue #59): prevent the compiler from DCE'ing timed work. */
static inline void bench_do_not_optimize(const void *p) {
#if defined(__GNUC__) || defined(__clang__)
    __asm__ __volatile__("" : : "g"(p) : "memory");
#else
    (void)p;
#endif
}
static inline void bench_clobber_memory(void) {
#if defined(__GNUC__) || defined(__clang__)
    __asm__ __volatile__("" : : : "memory");
#endif
}

#endif
