#include "ser_common.h"
#include "v2_codec.h"
/* Disambiguate from tinycbor's cbor.h (earlier on include path). */
#include "../../third_party/libcbor/src/cbor.h"

/* Wrapper: only libcbor ops for encode. Domain shape is v2_write_fixture.
 * Decode: interoperable CBOR maps via tinycbor visitor reader. */

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

typedef struct {
    cbor_item_t *stack[32];
    int sp;
    cbor_item_t *root;
    char pending_key[64];
    int has_key;
    int err;
} lcw;

static cbor_item_t *mk_str(const char *s) { return cbor_build_string(s ? s : ""); }
static cbor_item_t *mk_sint(int64_t v) {
    if (v >= 0) return cbor_build_uint64((uint64_t)v);
    return cbor_build_negint64((uint64_t)(-1 - v));
}

static int attach(lcw *c, cbor_item_t *item) {
    if (!item) { c->err = 1; return -1; }
    if (c->sp == 0) {
        c->root = item;
        c->stack[c->sp++] = item;
        return 0;
    }
    cbor_item_t *parent = c->stack[c->sp - 1];
    if (c->has_key) {
        if (!cbor_map_add(parent, (struct cbor_pair){
                .key = cbor_move(mk_str(c->pending_key)),
                .value = cbor_move(item)})) {
            c->err = 1; return -1;
        }
        c->has_key = 0;
        /* item pointer still valid after cbor_move */
        return 0;
    }
    if (cbor_isa_array(parent)) {
        if (!cbor_array_push(parent, cbor_move(item))) { c->err = 1; return -1; }
        return 0;
    }
    cbor_decref(&item);
    c->err = 1;
    return -1;
}

static int w_begin_map(void *ctx, int n) {
    lcw *c = ctx;
    cbor_item_t *m = cbor_new_definite_map(n >= 0 ? (size_t)n : 0);
    if (!m) { c->err = 1; return -1; }
    if (c->sp == 0) {
        c->root = m;
        c->stack[c->sp++] = m;
        return 0;
    }
    cbor_item_t *parent = c->stack[c->sp - 1];
    if (c->has_key) {
        if (!cbor_map_add(parent, (struct cbor_pair){
                .key = cbor_move(mk_str(c->pending_key)),
                .value = cbor_move(m)})) { c->err = 1; return -1; }
        c->has_key = 0;
    } else if (cbor_isa_array(parent)) {
        if (!cbor_array_push(parent, cbor_move(m))) { c->err = 1; return -1; }
    } else { cbor_decref(&m); c->err = 1; return -1; }
    c->stack[c->sp++] = m;
    return 0;
}
static int w_end_map(void *ctx) {
    lcw *c = ctx;
    if (c->sp <= 0) return -1;
    c->sp--;
    return 0;
}
static int w_begin_array(void *ctx, int n) {
    lcw *c = ctx;
    cbor_item_t *a = cbor_new_definite_array(n >= 0 ? (size_t)n : 0);
    if (!a) { c->err = 1; return -1; }
    cbor_item_t *parent = c->stack[c->sp - 1];
    if (c->has_key) {
        if (!cbor_map_add(parent, (struct cbor_pair){
                .key = cbor_move(mk_str(c->pending_key)),
                .value = cbor_move(a)})) { c->err = 1; return -1; }
        c->has_key = 0;
    } else { cbor_decref(&a); c->err = 1; return -1; }
    c->stack[c->sp++] = a;
    return 0;
}
static int w_end_array(void *ctx) {
    lcw *c = ctx;
    if (c->sp <= 0) return -1;
    c->sp--;
    return 0;
}
static int w_key(void *ctx, const char *k) {
    lcw *c = ctx;
    snprintf(c->pending_key, sizeof c->pending_key, "%s", k);
    c->has_key = 1;
    return 0;
}
static int w_bool(void *ctx, int v) { return attach(ctx, cbor_build_bool(v)); }
static int w_i64(void *ctx, int64_t v) { return attach(ctx, mk_sint(v)); }
static int w_f64(void *ctx, double v) { return attach(ctx, cbor_build_float8(v)); }
static int w_str(void *ctx, const char *s) { return attach(ctx, mk_str(s)); }

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    lcw c = {0};
    v2_writer_t w = {
        .ctx = &c, .begin_map = w_begin_map, .end_map = w_end_map,
        .begin_array = w_begin_array, .end_array = w_end_array,
        .key = w_key, .put_bool = w_bool, .put_i64 = w_i64, .put_f64 = w_f64, .put_str = w_str,
    };
    if (v2_write_fixture(fx, &w) != 0 || c.err || !c.root) {
        if (c.root) cbor_decref(&c.root);
        return -1;
    }
    size_t len = cbor_serialize(c.root, buf, cap);
    cbor_decref(&c.root);
    if (len == 0 || len > cap) return -1;
    *ol = len;
    return 0;
}
static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    return bench_tinycbor_de(buf, len, out, kind);
}
void bench_register_libcbor(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "cbor-encode", "0.11.0", "binary", prep, ser, de, fidelity_fx);
}
