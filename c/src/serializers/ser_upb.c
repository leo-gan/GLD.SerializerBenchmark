#include "fixture_pb_v2.h"
/* Native path: standard proto3 wire (benchmark_v2 field tags). */
static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }
static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    return pb_v2_encode(fx, buf, cap, ol);
}
static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    return pb_v2_decode(buf, len, out, kind);
}
void bench_register_upb(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "protobuf-wire", "wire-v2", "schema", prep, ser, de, fidelity_fx);
}
