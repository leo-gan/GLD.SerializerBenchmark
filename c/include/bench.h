#ifndef BENCH_H
#define BENCH_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>

#define BENCH_MAX_SERIALIZERS 16
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

typedef enum {
    TD_PERSON = 0,
    TD_INTEGER,
    TD_TELEMETRY,
    TD_SIMPLE,
    TD_STRING_ARRAY,
    TD_EDI835,
    TD_COUNT
} test_data_kind_t;

typedef struct {
    test_data_kind_t kind;
    const char *name;
    person_t person;
    int integer_val;
    telemetry_t telemetry;
    simple_object_t simple;
    string_array_t string_array;
    edi835_t edi;
} test_fixture_t;

typedef struct {
    const char *name;
    const char *version;
    const char *category;
    bool (*supports)(test_data_kind_t kind);
    /* prepare: untimed setup for this data kind */
    int (*prepare)(test_data_kind_t kind, const test_fixture_t *fx);
    /* serialize into caller buffer; sets *out_len; returns 0 on success */
    int (*serialize)(const test_fixture_t *fx, uint8_t *buf, size_t buf_cap, size_t *out_len);
    /* deserialize from buf; result stored in out_fx; returns 0 on success */
    int (*deserialize)(const uint8_t *buf, size_t len, test_fixture_t *out_fx, test_data_kind_t kind);
    /* semantic compare original vs deserialized */
    bool (*fidelity)(const test_fixture_t *a, const test_fixture_t *b);
} serializer_t;

/* data.c */
void data_init_all(test_fixture_t *out, int count, uint64_t seed);
const char *test_data_name(test_data_kind_t k);

/* csv_log.c */
typedef struct csv_logger csv_logger_t;
csv_logger_t *csv_logger_create(const char *path);
void csv_logger_write(csv_logger_t *L, const char *mode, const char *td,
                      int reps, int rep_idx, const char *ser,
                      uint64_t ser_ns, uint64_t deser_ns, size_t size,
                      double fidelity, const char *version);
void csv_logger_close(csv_logger_t *L);

/* runner.c */
int run_benchmarks(int repetitions, const char *ser_filter, const char *data_filter,
                   const char *log_dir);

/* serializer registries implemented in ser_*.c */
void register_all_serializers(serializer_t *out, int *count);

/* timing */
uint64_t bench_now_ns(void);

#endif
