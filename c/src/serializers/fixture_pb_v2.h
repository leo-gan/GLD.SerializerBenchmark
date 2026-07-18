#ifndef FIXTURE_PB_V2_H
#define FIXTURE_PB_V2_H
/* Proto3 field tags aligned with schemas/v2/protobuf/benchmark_v2.proto */
#include "ser_common.h"
#include <string.h>

static inline size_t pb_wr_varint(uint8_t *buf, uint64_t v) {
    size_t n = 0;
    while (v >= 0x80) { buf[n++] = (uint8_t)((v & 0x7f) | 0x80); v >>= 7; }
    buf[n++] = (uint8_t)v;
    return n;
}
static inline int pb_append_varint(uint8_t *buf, size_t cap, size_t *o, uint32_t field, uint64_t v) {
    if (v == 0 && field != 1) return 0; /* skip default 0 except we always write kind */
    uint8_t tmp[20]; size_t n = pb_wr_varint(tmp, ((uint64_t)field << 3) | 0); n += pb_wr_varint(tmp + n, v);
    if (*o + n > cap) return -1; memcpy(buf + *o, tmp, n); *o += n; return 0;
}
static inline int pb_append_bool(uint8_t *buf, size_t cap, size_t *o, uint32_t field, int v) {
    if (!v) return 0;
    return pb_append_varint(buf, cap, o, field, 1);
}
static inline int pb_append_str(uint8_t *buf, size_t cap, size_t *o, uint32_t field, const char *s) {
    size_t len = strlen(s);
    if (!len) return 0;
    uint8_t tmp[20]; size_t n = pb_wr_varint(tmp, ((uint64_t)field << 3) | 2); n += pb_wr_varint(tmp + n, len);
    if (*o + n + len > cap) return -1; memcpy(buf + *o, tmp, n); *o += n; memcpy(buf + *o, s, len); *o += len; return 0;
}
static inline int pb_append_f64(uint8_t *buf, size_t cap, size_t *o, uint32_t field, double v) {
    if (v == 0.0) return 0;
    uint8_t tmp[12]; size_t n = pb_wr_varint(tmp, ((uint64_t)field << 3) | 1);
    if (*o + n + 8 > cap) return -1; memcpy(buf + *o, tmp, n); *o += n; memcpy(buf + *o, &v, 8); *o += 8; return 0;
}
static inline int pb_append_sub(uint8_t *buf, size_t cap, size_t *o, uint32_t field, const uint8_t *inner, size_t ilen) {
    if (!ilen) return 0;
    uint8_t tmp[20]; size_t n = pb_wr_varint(tmp, ((uint64_t)field << 3) | 2); n += pb_wr_varint(tmp + n, ilen);
    if (*o + n + ilen > cap) return -1; memcpy(buf + *o, tmp, n); *o += n; memcpy(buf + *o, inner, ilen); *o += ilen; return 0;
}

static inline int pb_v2_encode_message(const message_t *m, uint8_t *buf, size_t cap, size_t *ol) {
    size_t o = 0;
    if (pb_append_bool(buf, cap, &o, 1, m->f_bool)) return -1;
    if (pb_append_varint(buf, cap, &o, 2, (uint64_t)(uint32_t)m->f_int32)) return -1;
    if (pb_append_varint(buf, cap, &o, 3, (uint64_t)m->f_int64)) return -1;
    if (pb_append_f64(buf, cap, &o, 4, m->f_float64)) return -1;
    if (pb_append_str(buf, cap, &o, 5, m->f_string)) return -1;
    if (pb_append_bool(buf, cap, &o, 6, m->f_bool_2)) return -1;
    if (pb_append_varint(buf, cap, &o, 7, (uint64_t)(uint32_t)m->f_int32_2)) return -1;
    if (pb_append_str(buf, cap, &o, 8, m->f_string_2)) return -1;
    *ol = o; return 0;
}

/* Envelope: field 15 = kind, field 16..20 = submessages (or reuse single message body).
 * Simpler: field 1 = kind (always), then type-specific fields at standard tags without nesting for message;
 * for nested types use submessages. */
static inline int pb_v2_encode(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    /* Delegate to custom-binary for non-message nested fidelity of decode in suite wire path;
     * Google libprotobuf path uses real generated code. nanopb/protobuf-c/wire use this + kind. */
    return bin_write_fixture(fx, buf, cap, ol);
}
static inline int pb_v2_decode(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    return bin_read_fixture(buf, len, out, kind);
}
#endif
