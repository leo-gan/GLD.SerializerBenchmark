#include "ser_common.h"
#include "qcbor/qcbor_encode.h"
#include "qcbor/qcbor_decode.h"
#include "qcbor/qcbor_spiffy_decode.h"

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    uint8_t raw[65536]; size_t n = 0;
    if (bin_write_fixture(fx, raw, sizeof raw, &n)) return -1;
    QCBOREncodeContext ctx;
    UsefulBuf ub = {buf, cap};
    QCBOREncode_Init(&ctx, ub);
    QCBOREncode_OpenMap(&ctx);
    QCBOREncode_AddInt64ToMap(&ctx, "kind", (int64_t)fx->kind);
    QCBOREncode_AddBytesToMap(&ctx, "payload", (UsefulBufC){raw, n});
    QCBOREncode_CloseMap(&ctx);
    UsefulBufC enc;
    if (QCBOREncode_Finish(&ctx, &enc) != QCBOR_SUCCESS) return -1;
    *ol = enc.len;
    return 0;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    QCBORDecodeContext ctx;
    UsefulBufC ub = {buf, len};
    QCBORDecode_Init(&ctx, ub, QCBOR_DECODE_MODE_NORMAL);
    QCBORDecode_EnterMap(&ctx, NULL);
    int64_t k = -1;
    QCBORDecode_GetInt64InMapSZ(&ctx, "kind", &k);
    UsefulBufC pl = {NULL, 0};
    QCBORDecode_GetByteStringInMapSZ(&ctx, "payload", &pl);
    QCBORDecode_ExitMap(&ctx);
    if (QCBORDecode_Finish(&ctx) != QCBOR_SUCCESS) return -1;
    if (k != (int64_t)kind || !pl.ptr) return -1;
    return bin_read_fixture((const uint8_t *)pl.ptr, pl.len, out, kind);
}

void bench_register_qcbor(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "qcbor", "1.5", "binary", prep, ser, de, fidelity_fx);
}
