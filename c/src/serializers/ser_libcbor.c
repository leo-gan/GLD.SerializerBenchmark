#include "ser_common.h"
#include "../../../third_party/libcbor/src/cbor.h"

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    uint8_t raw[65536]; size_t n = 0;
    if (bin_write_fixture(fx, raw, sizeof raw, &n)) return -1;
    cbor_item_t *map = cbor_new_definite_map(2);
    if (!map) return -1;
    cbor_map_add(map, (struct cbor_pair){
        .key = cbor_move(cbor_build_string("kind")),
        .value = cbor_move(cbor_build_uint64((uint64_t)fx->kind))
    });
    cbor_map_add(map, (struct cbor_pair){
        .key = cbor_move(cbor_build_string("payload")),
        .value = cbor_move(cbor_build_bytestring(raw, n))
    });
    unsigned char *out = NULL;
    size_t len = cbor_serialize_alloc(map, &out, NULL);
    cbor_decref(&map);
    if (!out || len == 0 || len > cap) { free(out); return -1; }
    memcpy(buf, out, len);
    *ol = len;
    free(out);
    return 0;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    struct cbor_load_result res;
    cbor_item_t *item = cbor_load(buf, len, &res);
    if (!item || !cbor_isa_map(item)) { if (item) cbor_decref(&item); return -1; }
    int k = -1; const uint8_t *payload = NULL; size_t plen = 0;
    size_t n = cbor_map_size(item);
    struct cbor_pair *pairs = cbor_map_handle(item);
    for (size_t i = 0; i < n; i++) {
        if (!cbor_isa_string(pairs[i].key)) continue;
        size_t kl = cbor_string_length(pairs[i].key);
        const unsigned char *kp = cbor_string_handle(pairs[i].key);
        if (kl == 4 && memcmp(kp, "kind", 4) == 0 && cbor_isa_uint(pairs[i].value)) {
            k = (int)cbor_get_uint64(pairs[i].value);
        } else if (kl == 7 && memcmp(kp, "payload", 7) == 0 && cbor_isa_bytestring(pairs[i].value)) {
            payload = cbor_bytestring_handle(pairs[i].value);
            plen = cbor_bytestring_length(pairs[i].value);
        }
    }
    int rc = (k == (int)kind && payload) ? bin_read_fixture(payload, plen, out, kind) : -1;
    cbor_decref(&item);
    return rc;
}

void bench_register_libcbor(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "cbor-encode", "0.11.0", "binary", prep, ser, de, fidelity_fx);
}
