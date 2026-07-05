#include "ser_common.h"
#include <msgpack.h>

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    uint8_t raw[65536]; size_t n = 0;
    if (bin_write_fixture(fx, raw, sizeof raw, &n)) return -1;
    msgpack_sbuffer sbuf; msgpack_sbuffer_init(&sbuf);
    msgpack_packer pk; msgpack_packer_init(&pk, &sbuf, msgpack_sbuffer_write);
    msgpack_pack_map(&pk, 2);
    msgpack_pack_str(&pk, 4); msgpack_pack_str_body(&pk, "kind", 4);
    msgpack_pack_int(&pk, (int)fx->kind);
    msgpack_pack_str(&pk, 7); msgpack_pack_str_body(&pk, "payload", 7);
    msgpack_pack_bin(&pk, n); msgpack_pack_bin_body(&pk, raw, n);
    if (sbuf.size > cap) { msgpack_sbuffer_destroy(&sbuf); return -1; }
    memcpy(buf, sbuf.data, sbuf.size); *ol = sbuf.size;
    msgpack_sbuffer_destroy(&sbuf);
    return 0;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    msgpack_unpacked result; msgpack_unpacked_init(&result);
    if (msgpack_unpack_next(&result, (const char *)buf, len, NULL) != MSGPACK_UNPACK_SUCCESS) {
        msgpack_unpacked_destroy(&result); return -1;
    }
    msgpack_object root = result.data;
    if (root.type != MSGPACK_OBJECT_MAP) { msgpack_unpacked_destroy(&result); return -1; }
    int k = -1; const char *payload = NULL; size_t plen = 0;
    for (uint32_t i = 0; i < root.via.map.size; i++) {
        msgpack_object key = root.via.map.ptr[i].key;
        msgpack_object val = root.via.map.ptr[i].val;
        if (key.type != MSGPACK_OBJECT_STR) continue;
        if (key.via.str.size == 4 && memcmp(key.via.str.ptr, "kind", 4) == 0) {
            if (val.type == MSGPACK_OBJECT_POSITIVE_INTEGER) k = (int)val.via.u64;
            else if (val.type == MSGPACK_OBJECT_NEGATIVE_INTEGER) k = (int)val.via.i64;
        } else if (key.via.str.size == 7 && memcmp(key.via.str.ptr, "payload", 7) == 0) {
            if (val.type == MSGPACK_OBJECT_BIN) { payload = val.via.bin.ptr; plen = val.via.bin.size; }
        }
    }
    int rc = (k == (int)kind && payload) ? bin_read_fixture((const uint8_t *)payload, plen, out, kind) : -1;
    msgpack_unpacked_destroy(&result);
    return rc;
}

void bench_register_msgpack_c(serializer_t *o, int *c) {
    static char ver_s[32];
    snprintf(ver_s, sizeof ver_s, "%d.%d.%d", MSGPACK_VERSION_MAJOR, MSGPACK_VERSION_MINOR, MSGPACK_VERSION_REVISION);
    BENCH_ADD(o, c, "msgpack-c", ver_s, "binary", prep, ser, de, fidelity_fx);
}
