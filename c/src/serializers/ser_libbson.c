#include "ser_common.h"
#include "v2_codec.h"
#include <bson/bson.h>

/* Wrapper: only libbson ops. Domain shape is v2_write/read_fixture. */

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

typedef struct {
    bson_t docs[32];
    int sp;
    char pending_key[64];
    int has_key;
    int arr_idx[32];
    int is_array[32];
    int err;
} bw;

static const char *next_key(bw *c, char *tmp, size_t tmpsz) {
    if (c->has_key) {
        c->has_key = 0;
        return c->pending_key;
    }
    if (c->is_array[c->sp - 1]) {
        snprintf(tmp, tmpsz, "%d", c->arr_idx[c->sp - 1]++);
        return tmp;
    }
    return "";
}

static int w_begin_map(void *ctx, int n) {
    (void)n;
    bw *c = ctx;
    if (c->sp == 0) {
        bson_init(&c->docs[0]);
        c->is_array[0] = 0;
        c->arr_idx[0] = 0;
        c->sp = 1;
        return 0;
    }
    char tmp[16];
    const char *k = next_key(c, tmp, sizeof tmp);
    bson_t *parent = &c->docs[c->sp - 1];
    bson_t *child = &c->docs[c->sp];
    if (!BSON_APPEND_DOCUMENT_BEGIN(parent, k, child)) { c->err = 1; return -1; }
    c->is_array[c->sp] = 0;
    c->arr_idx[c->sp] = 0;
    c->sp++;
    return 0;
}
static int w_end_map(void *ctx) {
    bw *c = ctx;
    if (c->sp <= 0) return -1;
    if (c->sp == 1) return 0; /* keep root open until serialize */
    bson_t *child = &c->docs[c->sp - 1];
    bson_t *parent = &c->docs[c->sp - 2];
    if (!bson_append_document_end(parent, child)) { c->err = 1; return -1; }
    c->sp--;
    return 0;
}
static int w_begin_array(void *ctx, int n) {
    (void)n;
    bw *c = ctx;
    char tmp[16];
    const char *k = next_key(c, tmp, sizeof tmp);
    bson_t *parent = &c->docs[c->sp - 1];
    bson_t *child = &c->docs[c->sp];
    if (!BSON_APPEND_ARRAY_BEGIN(parent, k, child)) { c->err = 1; return -1; }
    c->is_array[c->sp] = 1;
    c->arr_idx[c->sp] = 0;
    c->sp++;
    return 0;
}
static int w_end_array(void *ctx) {
    bw *c = ctx;
    if (c->sp < 2) return -1;
    bson_t *child = &c->docs[c->sp - 1];
    bson_t *parent = &c->docs[c->sp - 2];
    if (!bson_append_array_end(parent, child)) { c->err = 1; return -1; }
    c->sp--;
    return 0;
}
static int w_key(void *ctx, const char *k) {
    bw *c = ctx;
    snprintf(c->pending_key, sizeof c->pending_key, "%s", k);
    c->has_key = 1;
    return 0;
}
static int w_bool(void *ctx, int v) {
    bw *c = ctx;
    char tmp[16];
    const char *k = next_key(c, tmp, sizeof tmp);
    if (!BSON_APPEND_BOOL(&c->docs[c->sp - 1], k, v)) { c->err = 1; return -1; }
    return 0;
}
static int w_i64(void *ctx, int64_t v) {
    bw *c = ctx;
    char tmp[16];
    const char *k = next_key(c, tmp, sizeof tmp);
    /* prefer int64 for full range; int32 when fits is optional */
    if (!BSON_APPEND_INT64(&c->docs[c->sp - 1], k, v)) { c->err = 1; return -1; }
    return 0;
}
static int w_f64(void *ctx, double v) {
    bw *c = ctx;
    char tmp[16];
    const char *k = next_key(c, tmp, sizeof tmp);
    if (!BSON_APPEND_DOUBLE(&c->docs[c->sp - 1], k, v)) { c->err = 1; return -1; }
    return 0;
}
static int w_str(void *ctx, const char *s) {
    bw *c = ctx;
    char tmp[16];
    const char *k = next_key(c, tmp, sizeof tmp);
    if (!BSON_APPEND_UTF8(&c->docs[c->sp - 1], k, s ? s : "")) { c->err = 1; return -1; }
    return 0;
}

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    bw c = {0};
    v2_writer_t w = {
        .ctx = &c, .begin_map = w_begin_map, .end_map = w_end_map,
        .begin_array = w_begin_array, .end_array = w_end_array,
        .key = w_key, .put_bool = w_bool, .put_i64 = w_i64, .put_f64 = w_f64, .put_str = w_str,
    };
    if (v2_write_fixture(fx, &w) != 0 || c.err) {
        if (c.sp > 0) bson_destroy(&c.docs[0]);
        return -1;
    }
    const uint8_t *data = bson_get_data(&c.docs[0]);
    uint32_t len = c.docs[0].len;
    if (len > cap) { bson_destroy(&c.docs[0]); return -1; }
    memcpy(buf, data, len);
    *ol = len;
    bson_destroy(&c.docs[0]);
    return 0;
}

typedef struct {
    bson_t docs[32]; /* nested docs/arrays (static views or owned wrappers) */
    int is_array[32];
    int sp;
    int own[32]; /* whether docs[i] needs destroy */
} br;

static bson_t *rtop(br *c) { return &c->docs[c->sp - 1]; }

static int find_key(br *c, const char *key, bson_iter_t *out) {
    bson_iter_t it;
    if (!bson_iter_init(&it, rtop(c))) return 0;
    if (!bson_iter_find(&it, key)) return 0;
    *out = it;
    return 1;
}

static int r_get_bool(void *ctx, const char *key, int *out) {
    br *c = ctx;
    if (key && key[0]) {
        bson_iter_t it;
        if (!find_key(c, key, &it) || !BSON_ITER_HOLDS_BOOL(&it)) return 1;
        *out = bson_iter_bool(&it);
        return 0;
    }
    /* bare value on stack: re-init as single? For array elems we store the sub-doc/value differently */
    return 1;
}
static int r_get_i64(void *ctx, const char *key, int64_t *out) {
    br *c = ctx;
    if (!(key && key[0])) return 1;
    bson_iter_t it;
    if (!find_key(c, key, &it)) return 1;
    if (BSON_ITER_HOLDS_INT64(&it)) { *out = bson_iter_int64(&it); return 0; }
    if (BSON_ITER_HOLDS_INT32(&it)) { *out = bson_iter_int32(&it); return 0; }
    if (BSON_ITER_HOLDS_DOUBLE(&it)) { *out = (int64_t)bson_iter_double(&it); return 0; }
    return 1;
}
static int r_get_f64(void *ctx, const char *key, double *out) {
    br *c = ctx;
    if (!(key && key[0])) {
        /* bare double array element stored as docs? use iters */
        return 1;
    }
    bson_iter_t it;
    if (!find_key(c, key, &it)) return 1;
    if (BSON_ITER_HOLDS_DOUBLE(&it)) { *out = bson_iter_double(&it); return 0; }
    if (BSON_ITER_HOLDS_INT64(&it)) { *out = (double)bson_iter_int64(&it); return 0; }
    if (BSON_ITER_HOLDS_INT32(&it)) { *out = (double)bson_iter_int32(&it); return 0; }
    return 1;
}
static int r_get_str(void *ctx, const char *key, char *buf, size_t buflen) {
    br *c = ctx;
    if (!(key && key[0])) {
        /* bare string array elem: stored as utf8 in a synthetic wrapper is hard;
           use array element approach below */
        return -1;
    }
    bson_iter_t it;
    if (!find_key(c, key, &it)) { if (buflen) buf[0] = 0; return 0; }
    if (!BSON_ITER_HOLDS_UTF8(&it)) return -1;
    uint32_t len = 0;
    const char *s = bson_iter_utf8(&it, &len);
    if (!s) return -1;
    snprintf(buf, buflen, "%.*s", (int)len, s);
    return 0;
}

/* For bare array elements we push a tiny synthetic document {"$": value} - too heavy.
 * Better: keep array bson_t and index on enter_elem by looking up "%d". */

static int r_enter_object(void *ctx, const char *key) {
    br *c = ctx;
    bson_iter_t it;
    if (!find_key(c, key, &it) || !BSON_ITER_HOLDS_DOCUMENT(&it)) return 1;
    const uint8_t *data = NULL;
    uint32_t len = 0;
    bson_iter_document(&it, &len, &data);
    if (!bson_init_static(&c->docs[c->sp], data, len)) return -1;
    c->own[c->sp] = 0;
    c->is_array[c->sp] = 0;
    c->sp++;
    return 0;
}
static int r_leave_object(void *ctx) {
    br *c = ctx;
    if (c->sp <= 1) return -1;
    if (c->own[c->sp - 1]) bson_destroy(&c->docs[c->sp - 1]);
    c->sp--;
    return 0;
}
static int r_enter_array(void *ctx, const char *key, int *len_out) {
    br *c = ctx;
    bson_iter_t it;
    if (!find_key(c, key, &it) || !BSON_ITER_HOLDS_ARRAY(&it)) return 1;
    const uint8_t *data = NULL;
    uint32_t len = 0;
    bson_iter_array(&it, &len, &data);
    if (!bson_init_static(&c->docs[c->sp], data, len)) return -1;
    c->own[c->sp] = 0;
    c->is_array[c->sp] = 1;
    /* count keys */
    bson_iter_t ait;
    int n = 0;
    if (bson_iter_init(&ait, &c->docs[c->sp]))
        while (bson_iter_next(&ait)) n++;
    *len_out = n;
    c->sp++;
    return 0;
}
static int r_leave_array(void *ctx) {
    br *c = ctx;
    if (c->sp <= 1) return -1;
    if (c->own[c->sp - 1]) bson_destroy(&c->docs[c->sp - 1]);
    c->sp--;
    return 0;
}
static int r_enter_elem(void *ctx, int index) {
    br *c = ctx;
    char key[16];
    snprintf(key, sizeof key, "%d", index);
    bson_iter_t it;
    if (!bson_iter_init_find(&it, rtop(c), key)) return -1;
    if (BSON_ITER_HOLDS_DOCUMENT(&it)) {
        const uint8_t *data = NULL; uint32_t len = 0;
        bson_iter_document(&it, &len, &data);
        if (!bson_init_static(&c->docs[c->sp], data, len)) return -1;
        c->own[c->sp] = 0;
        c->is_array[c->sp] = 0;
        c->sp++;
        return 0;
    }
    /* scalar array element: wrap in owned doc with empty key "" not valid.
       Use a side-channel: store iter on stack as "value-only" via a owned empty doc + flag.
       Simpler approach: create owned bson with key "_" for the value. */
    bson_t *wrap = &c->docs[c->sp];
    bson_init(wrap);
    if (BSON_ITER_HOLDS_UTF8(&it)) {
        uint32_t len = 0; const char *s = bson_iter_utf8(&it, &len);
        BSON_APPEND_UTF8(wrap, "", s);
    } else if (BSON_ITER_HOLDS_DOUBLE(&it)) {
        BSON_APPEND_DOUBLE(wrap, "", bson_iter_double(&it));
    } else if (BSON_ITER_HOLDS_INT64(&it)) {
        BSON_APPEND_INT64(wrap, "", bson_iter_int64(&it));
    } else if (BSON_ITER_HOLDS_INT32(&it)) {
        BSON_APPEND_INT32(wrap, "", bson_iter_int32(&it));
    } else if (BSON_ITER_HOLDS_BOOL(&it)) {
        BSON_APPEND_BOOL(wrap, "", bson_iter_bool(&it));
    } else {
        bson_destroy(wrap);
        return -1;
    }
    c->own[c->sp] = 1;
    c->is_array[c->sp] = 0;
    c->sp++;
    return 0;
}
static int r_leave_elem(void *ctx) {
    br *c = ctx;
    if (c->sp <= 1) return -1;
    if (c->own[c->sp - 1]) bson_destroy(&c->docs[c->sp - 1]);
    c->sp--;
    return 0;
}

/* Fix get_* for bare "" key on scalar wrappers */
static int r_get_bool2(void *ctx, const char *key, int *out) {
    br *c = ctx;
    const char *k = (key && key[0]) ? key : "";
    bson_iter_t it;
    if (!find_key(c, k, &it) || !BSON_ITER_HOLDS_BOOL(&it)) return 1;
    *out = bson_iter_bool(&it);
    return 0;
}
static int r_get_i642(void *ctx, const char *key, int64_t *out) {
    br *c = ctx;
    const char *k = (key && key[0]) ? key : "";
    bson_iter_t it;
    if (!find_key(c, k, &it)) return 1;
    if (BSON_ITER_HOLDS_INT64(&it)) { *out = bson_iter_int64(&it); return 0; }
    if (BSON_ITER_HOLDS_INT32(&it)) { *out = bson_iter_int32(&it); return 0; }
    if (BSON_ITER_HOLDS_DOUBLE(&it)) { *out = (int64_t)bson_iter_double(&it); return 0; }
    return 1;
}
static int r_get_f642(void *ctx, const char *key, double *out) {
    br *c = ctx;
    const char *k = (key && key[0]) ? key : "";
    bson_iter_t it;
    if (!find_key(c, k, &it)) return 1;
    if (BSON_ITER_HOLDS_DOUBLE(&it)) { *out = bson_iter_double(&it); return 0; }
    if (BSON_ITER_HOLDS_INT64(&it)) { *out = (double)bson_iter_int64(&it); return 0; }
    if (BSON_ITER_HOLDS_INT32(&it)) { *out = (double)bson_iter_int32(&it); return 0; }
    return 1;
}
static int r_get_str2(void *ctx, const char *key, char *buf, size_t buflen) {
    br *c = ctx;
    const char *k = (key && key[0]) ? key : "";
    bson_iter_t it;
    if (!find_key(c, k, &it)) { if (buflen) buf[0] = 0; return 0; }
    if (!BSON_ITER_HOLDS_UTF8(&it)) return -1;
    uint32_t len = 0;
    const char *s = bson_iter_utf8(&it, &len);
    if (!s) return -1;
    snprintf(buf, buflen, "%.*s", (int)len, s);
    return 0;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    br rc = {0};
    if (!bson_init_static(&rc.docs[0], buf, (uint32_t)len)) return -1;
    rc.own[0] = 0;
    rc.sp = 1;
    v2_reader_t r = {
        .ctx = &rc,
        .get_bool = r_get_bool2, .get_i64 = r_get_i642, .get_f64 = r_get_f642, .get_str = r_get_str2,
        .enter_object = r_enter_object, .leave_object = r_leave_object,
        .enter_array = r_enter_array, .leave_array = r_leave_array,
        .enter_elem = r_enter_elem, .leave_elem = r_leave_elem,
    };
    return v2_read_fixture(kind, out, &r);
}

void bench_register_libbson(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "libbson", BSON_VERSION_S, "binary", prep, ser, de, fidelity_fx);
}
