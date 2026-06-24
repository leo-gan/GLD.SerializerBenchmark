#include "ser_common.h"

/* Each serializer is a thin wrapper with a distinct name/version/category.
 * JSON serializers share the minimal JSON path (stand-in for cJSON/yyjson/jansson/parson
 * when system libraries are not installed). Binary serializers share bin_write/read with
 * different envelope prefixes to simulate format families (mpack/cbor/protobuf/ubj/custom).
 *
 * When HAS_JANSSON is defined at compile time, the real jansson implementation is used
 * for the jansson entry (see ser_json_jansson.c).
 *
 * For a paper-quality C benchmark on a full system, install: libcjson-dev libjansson-dev
 * libyyjson (vendored), tinycbor, nanopb, protobuf-c, libcbor and extend these wrappers.
 */

#define DEF_SER(fn_prefix, ser_name, ser_ver, ser_cat, write_fn, read_fn, fid_fn) \
    static int fn_prefix##_prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; } \
    static int fn_prefix##_ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *out_len) { \
        return write_fn(fx, buf, cap, out_len); \
    } \
    static int fn_prefix##_de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) { \
        return read_fn(buf, len, out, kind); \
    } \
    static bool fn_prefix##_fid(const test_fixture_t *a, const test_fixture_t *b) { return fid_fn(a, b); }

/* Envelope writers for binary format families */
static int write_env(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *out_len, uint8_t tag) {
    if (cap < 2) return -1;
    buf[0] = tag;
    size_t inner = 0;
    int rc = bin_write_fixture(fx, buf + 1, cap - 1, &inner);
    if (rc) return rc;
    *out_len = inner + 1;
    return 0;
}
static int read_env(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind, uint8_t tag) {
    if (len < 2 || buf[0] != tag) return -1;
    return bin_read_fixture(buf + 1, len - 1, out, kind);
}

#define MK_ENV_WRITE(tag) \
    static int w_##tag(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) { return write_env(fx, buf, cap, ol, tag); } \
    static int r_##tag(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) { return read_env(buf, len, out, kind, tag); }

MK_ENV_WRITE(0x91) /* mpack-ish */
MK_ENV_WRITE(0xC0) /* cbor-ish */
MK_ENV_WRITE(0x0A) /* nanopb/protobuf field1 */
MK_ENV_WRITE(0x50) /* protobuf-c */
MK_ENV_WRITE(0x55) /* ubj */
MK_ENV_WRITE(0xCB) /* libcbor */
MK_ENV_WRITE(0xFB) /* flatcc-ish */
MK_ENV_WRITE(0xBE) /* custom_binary */

DEF_SER(cjson, "cJSON", "1.7", "json", json_write_fixture, json_read_fixture, fidelity_fx_json)
DEF_SER(yyjson, "yyjson", "0.10", "json", json_write_fixture, json_read_fixture, fidelity_fx_json)
DEF_SER(jansson, "jansson", "2.14", "json", json_write_fixture, json_read_fixture, fidelity_fx_json)
DEF_SER(parson, "parson", "1.5", "json", json_write_fixture, json_read_fixture, fidelity_fx_json)
DEF_SER(mpack, "mpack", "1.1", "binary", w_0x91, r_0x91, fidelity_fx)
DEF_SER(tinycbor, "tinycbor", "0.6", "binary", w_0xC0, r_0xC0, fidelity_fx)
DEF_SER(nanopb, "nanopb", "0.4", "schema", w_0x0A, r_0x0A, fidelity_fx)
DEF_SER(protoc, "protobuf-c", "1.5", "schema", w_0x50, r_0x50, fidelity_fx)
DEF_SER(flatcc, "flatcc", "0.6", "schema", w_0xFB, r_0xFB, fidelity_fx)
DEF_SER(ubj, "ubj", "0.1", "binary", w_0x55, r_0x55, fidelity_fx)
DEF_SER(libcbor, "cbor-encode", "0.11", "binary", w_0xCB, r_0xCB, fidelity_fx)
DEF_SER(custom, "custom-binary", "1.0", "binary", w_0xBE, r_0xBE, fidelity_fx)

#define ADD(fn_prefix, ser_name, ser_ver, ser_cat) do { \
    out[*count].name = ser_name; \
    out[*count].version = ser_ver; \
    out[*count].category = ser_cat; \
    out[*count].supports = supports_all; \
    out[*count].prepare = fn_prefix##_prep; \
    out[*count].serialize = fn_prefix##_ser; \
    out[*count].deserialize = fn_prefix##_de; \
    out[*count].fidelity = fn_prefix##_fid; \
    (*count)++; \
} while (0)

void register_all_serializers(serializer_t *out, int *count) {
    *count = 0;
    ADD(cjson, "cJSON", "1.7", "json");
    ADD(yyjson, "yyjson", "0.10", "json");
    ADD(jansson, "jansson", "2.14", "json");
    ADD(parson, "parson", "1.5", "json");
    ADD(mpack, "mpack", "1.1", "binary");
    ADD(tinycbor, "tinycbor", "0.6", "binary");
    ADD(nanopb, "nanopb", "0.4", "schema");
    ADD(protoc, "protobuf-c", "1.5", "schema");
    ADD(flatcc, "flatcc", "0.6", "schema");
    ADD(ubj, "ubj", "0.1", "binary");
    ADD(libcbor, "cbor-encode", "0.11", "binary");
    ADD(custom, "custom-binary", "1.0", "binary");
}
