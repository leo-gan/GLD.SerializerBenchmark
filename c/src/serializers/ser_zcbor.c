#include "ser_common.h"
#include "zcbor_encode.h"
#include "zcbor_decode.h"
#include "zcbor_common.h"

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    uint8_t raw[65536]; size_t n = 0;
    if (bin_write_fixture(fx, raw, sizeof raw, &n)) return -1;
    ZCBOR_STATE_E(state, 4, buf, cap, 0);
    bool ok = zcbor_map_start_encode(state, 2);
    ok = ok && zcbor_tstr_put_lit(state, "kind") && zcbor_int32_put(state, (int32_t)fx->kind);
    ok = ok && zcbor_tstr_put_lit(state, "payload") && zcbor_bstr_encode(state, &(struct zcbor_string){.value = raw, .len = n});
    ok = ok && zcbor_map_end_encode(state, 2);
    if (!ok) return -1;
    *ol = (size_t)(state->payload - buf);
    return 0;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    ZCBOR_STATE_D(state, 4, buf, len, 16, 0);
    struct zcbor_string key;
    int32_t k = -1;
    struct zcbor_string pl = {0};
    if (!zcbor_map_start_decode(state)) return -1;
    while (!zcbor_array_at_end(state)) {
        if (!zcbor_tstr_decode(state, &key)) return -1;
        char keybuf[32];
        size_t kl = key.len < sizeof keybuf - 1 ? key.len : sizeof keybuf - 1;
        memcpy(keybuf, key.value, kl); keybuf[kl] = 0;
        if (strcmp(keybuf, "kind") == 0) {
            if (!zcbor_int32_decode(state, &k)) return -1;
        } else if (strcmp(keybuf, "payload") == 0) {
            if (!zcbor_bstr_decode(state, &pl)) return -1;
        } else {
            if (!zcbor_any_skip(state, NULL)) return -1;
        }
    }
    if (!zcbor_map_end_decode(state)) return -1;
    if (k != (int32_t)kind || !pl.value) return -1;
    return bin_read_fixture(pl.value, pl.len, out, kind);
}

void bench_register_zcbor(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "zcbor", "0.9", "schema", prep, ser, de, fidelity_fx);
}
