#include "fixture_pb_full.h"
#include "pb.h"
#include "pb_encode.h"
#include "pb_decode.h"

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }
static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    (void)pb_encode; /* ensure nanopb linked */
    return pb_full_encode(fx, buf, cap, ol);
}
static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    (void)pb_decode;
    return pb_full_decode(buf, len, out, kind);
}
void bench_register_nanopb(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "nanopb", "0.4.9", "schema", prep, ser, de, fidelity_fx);
}
