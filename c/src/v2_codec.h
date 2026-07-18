#ifndef V2_CODEC_H
#define V2_CODEC_H
/*
 * Domain shape (Data Model v2) lives here once.
 * Serializer wrappers only implement these ops with native library APIs.
 */
#include "bench.h"

typedef struct v2_writer {
    void *ctx;
    /** n_pairs >= 0 fixed size; -1 if library uses indefinite/build-map. */
    int (*begin_map)(void *ctx, int n_pairs);
    int (*end_map)(void *ctx);
    int (*begin_array)(void *ctx, int n);
    int (*end_array)(void *ctx);
    int (*key)(void *ctx, const char *k);
    int (*put_bool)(void *ctx, int v);
    int (*put_i64)(void *ctx, int64_t v);
    int (*put_f64)(void *ctx, double v);
    int (*put_str)(void *ctx, const char *s);
} v2_writer_t;

/** Walk fixture domain shape; call writer ops only (no library knowledge). */
int v2_write_fixture(const test_fixture_t *fx, const v2_writer_t *w);

/**
 * Keyed / DOM-style reader. Context is a "current object".
 * enter_object/enter_array push nested context; leave_* pops.
 * Array length via enter_array; elements via enter_elem(i) / leave_elem.
 */
typedef struct v2_reader {
    void *ctx;
    int (*get_bool)(void *ctx, const char *key, int *out);
    int (*get_i64)(void *ctx, const char *key, int64_t *out);
    int (*get_f64)(void *ctx, const char *key, double *out);
    /** Copy UTF-8 string; empty if missing. Return 0 ok, -1 hard error. */
    int (*get_str)(void *ctx, const char *key, char *buf, size_t buflen);
    int (*enter_object)(void *ctx, const char *key);
    int (*leave_object)(void *ctx);
    int (*enter_array)(void *ctx, const char *key, int *len_out);
    int (*leave_array)(void *ctx);
    int (*enter_elem)(void *ctx, int index);
    int (*leave_elem)(void *ctx);
} v2_reader_t;

/** Fill out from reader using domain shape for kind. */
int v2_read_fixture(test_data_kind_t kind, test_fixture_t *out, const v2_reader_t *r);

#endif
