#include "ser_common.h"

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }
static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    return bin_write_fixture(fx, buf, cap, ol);
}
static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    return bin_read_fixture(buf, len, out, kind);
}
void bench_register_msgpack_c(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "msgpack-c", "6.0.1", "binary", prep, ser, de, fidelity_fx);
}
