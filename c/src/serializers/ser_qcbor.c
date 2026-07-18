#include "ser_common.h"
#include "v2_codec.h"
#include "qcbor/qcbor_encode.h"
#include "qcbor/qcbor_decode.h"
#include "qcbor/qcbor_spiffy_decode.h"

/* Wrapper: only QCBOR encode ops. Domain shape is v2_write_fixture.
 * Decode: interoperable CBOR maps via tinycbor visitor reader. */

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

typedef struct {
    QCBOREncodeContext *ctx;
    char pending_key[64];
    int has_key;
    int in_array_depth; /* when >0 and no key, add bare value */
} qcw;

static int w_begin_map(void *ctx, int n) {
    (void)n;
    qcw *c = ctx;
    if (c->has_key) {
        QCBOREncode_OpenMapInMapSZ(c->ctx, c->pending_key);
        c->has_key = 0;
    } else if (c->in_array_depth > 0) {
        QCBOREncode_OpenMap(c->ctx);
    } else {
        QCBOREncode_OpenMap(c->ctx);
    }
    return 0;
}
static int w_end_map(void *ctx) {
    qcw *c = ctx;
    QCBOREncode_CloseMap(c->ctx);
    return 0;
}
static int w_begin_array(void *ctx, int n) {
    (void)n;
    qcw *c = ctx;
    if (c->has_key) {
        QCBOREncode_OpenArrayInMapSZ(c->ctx, c->pending_key);
        c->has_key = 0;
    } else {
        QCBOREncode_OpenArray(c->ctx);
    }
    c->in_array_depth++;
    return 0;
}
static int w_end_array(void *ctx) {
    qcw *c = ctx;
    QCBOREncode_CloseArray(c->ctx);
    if (c->in_array_depth > 0) c->in_array_depth--;
    return 0;
}
static int w_key(void *ctx, const char *k) {
    qcw *c = ctx;
    snprintf(c->pending_key, sizeof c->pending_key, "%s", k);
    c->has_key = 1;
    return 0;
}
static int w_bool(void *ctx, int v) {
    qcw *c = ctx;
    if (c->has_key) {
        QCBOREncode_AddBoolToMapSZ(c->ctx, c->pending_key, v);
        c->has_key = 0;
    } else {
        QCBOREncode_AddBool(c->ctx, v);
    }
    return 0;
}
static int w_i64(void *ctx, int64_t v) {
    qcw *c = ctx;
    if (c->has_key) {
        QCBOREncode_AddInt64ToMapSZ(c->ctx, c->pending_key, v);
        c->has_key = 0;
    } else {
        QCBOREncode_AddInt64(c->ctx, v);
    }
    return 0;
}
static int w_f64(void *ctx, double v) {
    qcw *c = ctx;
    if (c->has_key) {
        QCBOREncode_AddDoubleToMapSZ(c->ctx, c->pending_key, v);
        c->has_key = 0;
    } else {
        QCBOREncode_AddDouble(c->ctx, v);
    }
    return 0;
}
static int w_str(void *ctx, const char *s) {
    qcw *c = ctx;
    if (c->has_key) {
        QCBOREncode_AddSZStringToMapSZ(c->ctx, c->pending_key, s ? s : "");
        c->has_key = 0;
    } else {
        QCBOREncode_AddSZString(c->ctx, s ? s : "");
    }
    return 0;
}

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    UsefulBuf ub = { buf, cap };
    QCBOREncodeContext enc;
    QCBOREncode_Init(&enc, ub);
    qcw c = { .ctx = &enc };
    v2_writer_t w = {
        .ctx = &c, .begin_map = w_begin_map, .end_map = w_end_map,
        .begin_array = w_begin_array, .end_array = w_end_array,
        .key = w_key, .put_bool = w_bool, .put_i64 = w_i64, .put_f64 = w_f64, .put_str = w_str,
    };
    if (v2_write_fixture(fx, &w) != 0) return -1;
    UsefulBufC out;
    if (QCBOREncode_Finish(&enc, &out) != QCBOR_SUCCESS) return -1;
    *ol = out.len;
    return 0;
}
static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    return bench_tinycbor_de(buf, len, out, kind);
}
void bench_register_qcbor(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "qcbor", "1.5.1", "binary", prep, ser, de, fidelity_fx);
}
