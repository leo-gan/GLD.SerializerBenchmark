#include "ser_common.h"
#include "v2_codec.h"
#include "tinycbor_pref.h"

/* Wrapper: only tinycbor ops. Domain shape is v2_write/read_fixture. */

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

typedef struct {
    CborEncoder stack[32];
    int sp;
    int err;
} tcw;

static int w_begin_map(void *ctx, int n) {
    tcw *c = ctx;
    if (c->sp >= 31) return -1;
    CborEncoder *parent = &c->stack[c->sp - 1];
    CborEncoder *child = &c->stack[c->sp];
    if (cbor_encoder_create_map(parent, child, n >= 0 ? (size_t)n : CborIndefiniteLength) != CborNoError) {
        c->err = 1; return -1;
    }
    c->sp++;
    return 0;
}
static int w_end_map(void *ctx) {
    tcw *c = ctx;
    if (c->sp < 2) return -1;
    CborEncoder *child = &c->stack[c->sp - 1];
    CborEncoder *parent = &c->stack[c->sp - 2];
    if (cbor_encoder_close_container(parent, child) != CborNoError) { c->err = 1; return -1; }
    c->sp--;
    return 0;
}
static int w_begin_array(void *ctx, int n) {
    tcw *c = ctx;
    if (c->sp >= 31) return -1;
    CborEncoder *parent = &c->stack[c->sp - 1];
    CborEncoder *child = &c->stack[c->sp];
    if (cbor_encoder_create_array(parent, child, n >= 0 ? (size_t)n : CborIndefiniteLength) != CborNoError) {
        c->err = 1; return -1;
    }
    c->sp++;
    return 0;
}
static int w_end_array(void *ctx) {
    tcw *c = ctx;
    if (c->sp < 2) return -1;
    CborEncoder *child = &c->stack[c->sp - 1];
    CborEncoder *parent = &c->stack[c->sp - 2];
    if (cbor_encoder_close_container(parent, child) != CborNoError) { c->err = 1; return -1; }
    c->sp--;
    return 0;
}
static int w_key(void *ctx, const char *k) {
    tcw *c = ctx;
    if (cbor_encode_text_stringz(&c->stack[c->sp - 1], k) != CborNoError) { c->err = 1; return -1; }
    return 0;
}
static int w_bool(void *ctx, int v) {
    tcw *c = ctx;
    if (cbor_encode_boolean(&c->stack[c->sp - 1], v) != CborNoError) { c->err = 1; return -1; }
    return 0;
}
static int w_i64(void *ctx, int64_t v) {
    tcw *c = ctx;
    if (cbor_encode_int(&c->stack[c->sp - 1], v) != CborNoError) { c->err = 1; return -1; }
    return 0;
}
static int w_f64(void *ctx, double v) {
    tcw *c = ctx;
    if (cbor_encode_double(&c->stack[c->sp - 1], v) != CborNoError) { c->err = 1; return -1; }
    return 0;
}
static int w_str(void *ctx, const char *s) {
    tcw *c = ctx;
    if (cbor_encode_text_stringz(&c->stack[c->sp - 1], s ? s : "") != CborNoError) { c->err = 1; return -1; }
    return 0;
}

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    tcw c = {0};
    cbor_encoder_init(&c.stack[0], buf, cap, 0);
    c.sp = 1;
    v2_writer_t w = {
        .ctx = &c, .begin_map = w_begin_map, .end_map = w_end_map,
        .begin_array = w_begin_array, .end_array = w_end_array,
        .key = w_key, .put_bool = w_bool, .put_i64 = w_i64, .put_f64 = w_f64, .put_str = w_str,
    };
    if (v2_write_fixture(fx, &w) != 0 || c.err) return -1;
    *ol = cbor_encoder_get_buffer_size(&c.stack[0], buf);
    return 0;
}

/* Reader stack: map/array CborValue containers (not entered iterators for maps). */
typedef struct {
    CborValue stack[32];
    int sp;
} tcr;

static CborValue *rtop(tcr *c) { return &c->stack[c->sp - 1]; }

static int r_get_bool(void *ctx, const char *key, int *out) {
    tcr *c = ctx;
    CborValue v;
    if (key && key[0]) {
        if (cbor_value_map_find_value(rtop(c), key, &v) != CborNoError || !cbor_value_is_boolean(&v)) return 1;
    } else {
        v = *rtop(c);
        if (!cbor_value_is_boolean(&v)) return 1;
    }
    bool b = false;
    cbor_value_get_boolean(&v, &b);
    *out = b;
    return 0;
}
static int r_get_i64(void *ctx, const char *key, int64_t *out) {
    tcr *c = ctx;
    CborValue v;
    if (key && key[0]) {
        if (cbor_value_map_find_value(rtop(c), key, &v) != CborNoError || !cbor_value_is_integer(&v)) return 1;
    } else {
        v = *rtop(c);
        if (!cbor_value_is_integer(&v)) return 1;
    }
    cbor_value_get_int64(&v, out);
    return 0;
}
static int r_get_f64(void *ctx, const char *key, double *out) {
    tcr *c = ctx;
    CborValue v;
    if (key && key[0]) {
        if (cbor_value_map_find_value(rtop(c), key, &v) != CborNoError) return 1;
    } else {
        v = *rtop(c);
    }
    if (cbor_value_is_double(&v)) { cbor_value_get_double(&v, out); return 0; }
    if (cbor_value_is_integer(&v)) { int64_t i; cbor_value_get_int64(&v, &i); *out = (double)i; return 0; }
    return 1;
}
static int r_get_str(void *ctx, const char *key, char *buf, size_t buflen) {
    tcr *c = ctx;
    CborValue v;
    if (key && key[0]) {
        if (cbor_value_map_find_value(rtop(c), key, &v) != CborNoError || !cbor_value_is_text_string(&v)) {
            if (buflen) buf[0] = 0; return 0;
        }
    } else {
        v = *rtop(c);
        if (!cbor_value_is_text_string(&v)) return -1;
    }
    size_t n = buflen;
    if (cbor_value_copy_text_string(&v, buf, &n, NULL) != CborNoError) return -1;
    if (n >= buflen) n = buflen - 1;
    buf[n] = 0;
    return 0;
}
static int r_enter_object(void *ctx, const char *key) {
    tcr *c = ctx;
    CborValue v;
    if (cbor_value_map_find_value(rtop(c), key, &v) != CborNoError || !cbor_value_is_map(&v)) return 1;
    c->stack[c->sp++] = v;
    return 0;
}
static int r_leave_object(void *ctx) { tcr *c = ctx; if (c->sp <= 1) return -1; c->sp--; return 0; }
static int r_enter_array(void *ctx, const char *key, int *len_out) {
    tcr *c = ctx;
    CborValue v;
    if (cbor_value_map_find_value(rtop(c), key, &v) != CborNoError || !cbor_value_is_array(&v)) return 1;
    size_t n = 0;
    if (cbor_value_get_array_length(&v, &n) != CborNoError) {
        /* Indefinite-length arrays (e.g. non-canonical zcbor): count by walking. */
        CborValue it;
        if (cbor_value_enter_container(&v, &it) != CborNoError) return 1;
        n = 0;
        while (!cbor_value_at_end(&it)) {
            if (cbor_value_advance(&it) != CborNoError) return -1;
            n++;
        }
        if (cbor_value_leave_container(&v, &it) != CborNoError) return -1;
        /* re-resolve array value after leave */
        if (cbor_value_map_find_value(rtop(c), key, &v) != CborNoError) return -1;
    }
    *len_out = (int)n;
    c->stack[c->sp++] = v;
    return 0;
}
static int r_leave_array(void *ctx) { tcr *c = ctx; if (c->sp <= 1) return -1; c->sp--; return 0; }
static int r_enter_elem(void *ctx, int index) {
    tcr *c = ctx;
    CborValue arr = *rtop(c);
    CborValue it;
    if (cbor_value_enter_container(&arr, &it) != CborNoError) return -1;
    for (int i = 0; i < index; i++) {
        if (cbor_value_at_end(&it)) return -1;
        if (cbor_value_advance(&it) != CborNoError) return -1;
    }
    if (cbor_value_at_end(&it)) return -1;
    c->stack[c->sp++] = it;
    return 0;
}
static int r_leave_elem(void *ctx) { tcr *c = ctx; if (c->sp <= 1) return -1; c->sp--; return 0; }

int bench_tinycbor_de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    CborParser parser;
    CborValue root;
    if (cbor_parser_init(buf, len, 0, &parser, &root) != CborNoError) return -1;
    if (!cbor_value_is_map(&root)) return -1;
    tcr rc = {0}; rc.stack[0] = root; rc.sp = 1;
    v2_reader_t r = {
        .ctx = &rc, .get_bool = r_get_bool, .get_i64 = r_get_i64, .get_f64 = r_get_f64,
        .get_str = r_get_str, .enter_object = r_enter_object, .leave_object = r_leave_object,
        .enter_array = r_enter_array, .leave_array = r_leave_array,
        .enter_elem = r_enter_elem, .leave_elem = r_leave_elem,
    };
    return v2_read_fixture(kind, out, &r);
}

void bench_register_tinycbor(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "tinycbor", "0.6.0", "binary", prep, ser, bench_tinycbor_de, fidelity_fx);
}
