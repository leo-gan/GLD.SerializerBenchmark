#include "ser_common.h"
#include "v2_codec.h"
#include "zcbor_encode.h"
#include "zcbor_decode.h"
#include "zcbor_common.h"

/* Wrapper: only zcbor encode ops. Domain shape is v2_write_fixture.
 * Decode: interoperable CBOR maps via tinycbor visitor reader. */

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

typedef struct {
    zcbor_state_t *s;
    size_t max_stack[32];
    int msp;
    int err;
} zw;

static int w_begin_map(void *ctx, int n) {
    zw *c = ctx;
    size_t max_num = n >= 0 ? (size_t)n : 0;
    if (c->msp >= 32) return -1;
    c->max_stack[c->msp++] = max_num;
    if (!zcbor_map_start_encode(c->s, max_num)) { c->err = 1; return -1; }
    return 0;
}
static int w_end_map(void *ctx) {
    zw *c = ctx;
    if (c->msp <= 0) return -1;
    size_t max_num = c->max_stack[--c->msp];
    if (!zcbor_map_end_encode(c->s, max_num)) { c->err = 1; return -1; }
    return 0;
}
static int w_begin_array(void *ctx, int n) {
    zw *c = ctx;
    size_t max_num = n >= 0 ? (size_t)n : 0;
    if (c->msp >= 32) return -1;
    c->max_stack[c->msp++] = max_num;
    if (!zcbor_list_start_encode(c->s, max_num)) { c->err = 1; return -1; }
    return 0;
}
static int w_end_array(void *ctx) {
    zw *c = ctx;
    if (c->msp <= 0) return -1;
    size_t max_num = c->max_stack[--c->msp];
    if (!zcbor_list_end_encode(c->s, max_num)) { c->err = 1; return -1; }
    return 0;
}
static int w_key(void *ctx, const char *k) {
    zw *c = ctx;
    if (!zcbor_tstr_put_term(c->s, k, 64)) { c->err = 1; return -1; }
    return 0;
}
static int w_bool(void *ctx, int v) {
    zw *c = ctx;
    if (!zcbor_bool_put(c->s, v)) { c->err = 1; return -1; }
    return 0;
}
static int w_i64(void *ctx, int64_t v) {
    zw *c = ctx;
    if (!zcbor_int64_put(c->s, v)) { c->err = 1; return -1; }
    return 0;
}
static int w_f64(void *ctx, double v) {
    zw *c = ctx;
    if (!zcbor_float64_put(c->s, v)) { c->err = 1; return -1; }
    return 0;
}
static int w_str(void *ctx, const char *s) {
    zw *c = ctx;
    if (!zcbor_tstr_put_term(c->s, s ? s : "", 256)) { c->err = 1; return -1; }
    return 0;
}

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    zcbor_state_t states[8];
    zcbor_new_state(states, 8, buf, cap, 1, NULL, 0);
    zw c = { .s = states };
    v2_writer_t w = {
        .ctx = &c, .begin_map = w_begin_map, .end_map = w_end_map,
        .begin_array = w_begin_array, .end_array = w_end_array,
        .key = w_key, .put_bool = w_bool, .put_i64 = w_i64, .put_f64 = w_f64, .put_str = w_str,
    };
    if (v2_write_fixture(fx, &w) != 0 || c.err) return -1;
    *ol = (size_t)(states[0].payload - buf);
    return 0;
}
static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    return bench_tinycbor_de(buf, len, out, kind);
}
void bench_register_zcbor(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "zcbor", "0.9", "schema", prep, ser, de, fidelity_fx);
}
