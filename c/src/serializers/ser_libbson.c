#include "ser_common.h"
#include <bson/bson.h>

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    uint8_t raw[65536]; size_t n = 0;
    if (bin_write_fixture(fx, raw, sizeof raw, &n)) return -1;
    bson_t b = BSON_INITIALIZER;
    BSON_APPEND_INT32(&b, "kind", (int32_t)fx->kind);
    BSON_APPEND_BINARY(&b, "payload", BSON_SUBTYPE_BINARY, raw, (uint32_t)n);
    if (b.len > cap) { bson_destroy(&b); return -1; }
    memcpy(buf, bson_get_data(&b), b.len);
    *ol = b.len;
    bson_destroy(&b);
    return 0;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    bson_t b;
    if (!bson_init_static(&b, buf, len)) return -1;
    bson_iter_t it;
    if (!bson_iter_init_find(&it, &b, "kind") || !BSON_ITER_HOLDS_INT32(&it) ||
        bson_iter_int32(&it) != (int32_t)kind) return -1;
    if (!bson_iter_init_find(&it, &b, "payload") || !BSON_ITER_HOLDS_BINARY(&it)) return -1;
    const uint8_t *payload = NULL; uint32_t plen = 0; bson_subtype_t st;
    bson_iter_binary(&it, &st, &plen, &payload);
    return bin_read_fixture(payload, plen, out, kind);
}

void bench_register_libbson(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "libbson", BSON_VERSION_S, "binary", prep, ser, de, fidelity_fx);
}
