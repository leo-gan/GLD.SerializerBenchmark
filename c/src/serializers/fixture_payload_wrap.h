#ifndef FIXTURE_PAYLOAD_WRAP_H
#define FIXTURE_PAYLOAD_WRAP_H
/* Encode full fixture via bin_write into a single bytes/blob field for map formats. */
#include "ser_common.h"
static inline int full_payload_bytes(const test_fixture_t *fx, uint8_t *raw, size_t raw_cap, size_t *n) {
    return bin_write_fixture(fx, raw, raw_cap, n);
}
#endif
