#ifndef BENCH_H
#define BENCH_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>

#define BENCH_MAX_SERIALIZERS 32
#define BENCH_MAX_NAME 64

typedef struct {
    char first_name[32];
    char last_name[32];
    int age;
    int gender;
    char passport_number[24];
    char passport_authority[24];
    int police_count;
    int police_ids[8];
    char police_codes[8][16];
} person_t;

typedef struct {
    int id;
    char name[32];
    char timestamp[32];
    bool is_active;
} simple_object_t;

typedef struct {
    int count;
    char items[100][16];
} string_array_t;

typedef struct {
    char id[24];
    char data_source[24];
    char time_stamp[32];
    int param1;
    int param2;
    int meas_count;
    double measurements[100];
    int problem_id;
    int log_id;
    bool was_processed;
} telemetry_t;

typedef struct {
    char service_code[16];
    double charge;
    double adjudicated;
} service_line_t;

typedef struct {
    char claim_id[16];
    char patient_name[32];
    double total_charge;
    double payment;
    int line_count;
    service_line_t lines[4];
} claim_t;

typedef struct {
    char payer_name[32];
    char payee_name[32];
    char payment_date[32];
    double total_actual;
    char tcn[24];
    int claim_count;
    claim_t claims[6];
} edi835_t;

/* ObjectGraph: fixed 3-node circular graph matching C#/Python fixtures.
 * Edges stored as node indices (-1 = null). Storage is dense nodes[0..node_count). */
#define GRAPH_MAX_NODES 8
#define GRAPH_MAX_CHILDREN 4
#define GRAPH_NULL_IDX (-1)

typedef struct {
    char name[32];
    int parent;                          /* index or GRAPH_NULL_IDX */
    int related;                         /* index or GRAPH_NULL_IDX */
    int child_count;
    int children[GRAPH_MAX_CHILDREN];    /* indices into nodes[] */
} graph_node_t;

typedef struct {
    int root;                            /* index of root node */
    int node_count;
    graph_node_t nodes[GRAPH_MAX_NODES];
} object_graph_t;

typedef enum {
    TD_PERSON = 0,
    TD_INTEGER,
    TD_TELEMETRY,
    TD_SIMPLE,
    TD_STRING_ARRAY,
    TD_EDI835,
    TD_OBJECT_GRAPH,
    TD_COUNT
} test_data_kind_t;

typedef struct test_fixture test_fixture_t;
struct test_fixture {
    test_data_kind_t kind;
    const char *name;
    person_t person;
    int integer_val;
    telemetry_t telemetry;
    simple_object_t simple;
    string_array_t string_array;
    edi835_t edi;
    object_graph_t graph;
    /* Batch cell (data_type_instance_count): batch_n==1 uses fields above;
     * batch_n>1 uses heap array batch[0..batch_n) of single-instance fixtures. */
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

void data_init_all(test_fixture_t *out, int count, uint64_t seed);
const char *test_data_name(test_data_kind_t k);

typedef struct csv_logger csv_logger_t;
csv_logger_t *csv_logger_create(const char *path);
void csv_logger_write(csv_logger_t *L, const char *mode, const char *td,
                      int reps, int rep_idx, const char *ser,
                      uint64_t ser_ns, uint64_t deser_ns, size_t size,
                      double fidelity, const char *version,
                      int instance_count, const char *type_config_hash);
void csv_logger_close(csv_logger_t *L);

/* Batch-aware encode/decode: when fx->batch_n > 1, frames N single-item
 * codec outputs (u32 n + for each: u32 len + bytes). N=1 is a thin passthrough. */
int bench_serialize_cell(const serializer_t *S, const test_fixture_t *fx,
                         uint8_t *buf, size_t buf_cap, size_t *out_len);
int bench_deserialize_cell(const serializer_t *S, const uint8_t *buf, size_t len,
                           test_fixture_t *out_fx, test_data_kind_t kind);
bool bench_fidelity_cell(const serializer_t *S, const test_fixture_t *a,
                         const test_fixture_t *b);

int run_benchmarks(int repetitions, const char *ser_filter, const char *data_filter,
                   const char *log_dir);

void register_all_serializers(serializer_t *out, int *count);

uint64_t bench_now_ns(void);

/* Per-serializer registration helpers (defined when HAS_* is set) */
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
void bench_register_flatcc(serializer_t *out, int *count);
void bench_register_avro_c(serializer_t *out, int *count);
void bench_register_zcbor(serializer_t *out, int *count);

#endif

/* Adapted stream sink (Python stream_mode=adapted parity): not a free alias of bytes. */
int bench_stream_write_all(const uint8_t *buf, size_t len);
int bench_stream_read_all(uint8_t *buf, size_t cap, size_t expect_len);
