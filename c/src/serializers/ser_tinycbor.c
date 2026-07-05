#include "ser_common.h"
#include "tinycbor_pref.h"

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

/* Full fixture via custom binary payload in a CBOR map (kind + payload bytes). */
static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    uint8_t raw[65536]; size_t n = 0;
    if (bin_write_fixture(fx, raw, sizeof raw, &n)) return -1;
    CborEncoder enc, map;
    cbor_encoder_init(&enc, buf, cap, 0);
    if (cbor_encoder_create_map(&enc, &map, 2) != CborNoError) return -1;
    if (cbor_encode_text_stringz(&map, "kind") != CborNoError) return -1;
    if (cbor_encode_int(&map, (int64_t)fx->kind) != CborNoError) return -1;
    if (cbor_encode_text_stringz(&map, "payload") != CborNoError) return -1;
    if (cbor_encode_byte_string(&map, raw, n) != CborNoError) return -1;
    if (cbor_encoder_close_container(&enc, &map) != CborNoError) return -1;
    *ol = cbor_encoder_get_buffer_size(&enc, buf);
    return 0;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    CborParser parser; CborValue root, map, it;
    if (cbor_parser_init(buf, len, 0, &parser, &root) != CborNoError) return -1;
    if (!cbor_value_is_map(&root)) return -1;
    if (cbor_value_enter_container(&root, &map) != CborNoError) return -1;
    int k = -1; const uint8_t *payload = NULL; size_t plen = 0;
    it = map;
    while (!cbor_value_at_end(&it)) {
        char key[32]; size_t kn = sizeof key;
        if (!cbor_value_is_text_string(&it)) return -1;
        if (cbor_value_copy_text_string(&it, key, &kn, &it) != CborNoError) return -1;
        if (strcmp(key, "kind") == 0) {
            int64_t v; if (cbor_value_get_int64(&it, &v) != CborNoError) return -1;
            k = (int)v;
            if (cbor_value_advance(&it) != CborNoError) return -1;
        } else if (strcmp(key, "payload") == 0) {
            if (!cbor_value_is_byte_string(&it)) return -1;
            size_t n = 0;
            if (cbor_value_calculate_string_length(&it, &n) != CborNoError) return -1;
            /* copy into temp then bin_read — tinycbor may need advance */
            static uint8_t tmp[65536];
            if (n > sizeof tmp) return -1;
            size_t nn = sizeof tmp;
            if (cbor_value_copy_byte_string(&it, tmp, &nn, &it) != CborNoError) return -1;
            payload = tmp; plen = nn;
        } else {
            if (cbor_value_advance(&it) != CborNoError) return -1;
        }
    }
    if (k != (int)kind || !payload) return -1;
    return bin_read_fixture(payload, plen, out, kind);
}

void bench_register_tinycbor(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "tinycbor", "0.6.0", "binary", prep, ser, de, fidelity_fx);
}
