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
} qcw;

static int w_begin_map(void *ctx, int n) {
    (void)n;
    QCBOREncode_OpenMap(((qcw *)ctx)->ctx);
    return 0;
}
static int w_end_map(void *ctx) {
    QCBOREncode_CloseMap(((qcw *)ctx)->ctx);
    return 0;
}
static int w_begin_array(void *ctx, int n) {
    (void)n;
    QCBOREncode_OpenArray(((qcw *)ctx)->ctx);
    return 0;
}
static int w_end_array(void *ctx) {
    QCBOREncode_CloseArray(((qcw *)ctx)->ctx);
    return 0;
}
static int w_key(void *ctx, const char *k) {
    QCBOREncode_AddSZString(((qcw *)ctx)->ctx, k);
    return 0;
}
static int w_bool(void *ctx, int v) {
    QCBOREncode_AddBool(((qcw *)ctx)->ctx, v);
    return 0;
}
static int w_i64(void *ctx, int64_t v) {
    QCBOREncode_AddInt64(((qcw *)ctx)->ctx, v);
    return 0;
}
static int w_f64(void *ctx, double v) {
    QCBOREncode_AddDouble(((qcw *)ctx)->ctx, v);
    return 0;
}
static int w_str(void *ctx, const char *s) {
    QCBOREncode_AddSZString(((qcw *)ctx)->ctx, s ? s : "");
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
