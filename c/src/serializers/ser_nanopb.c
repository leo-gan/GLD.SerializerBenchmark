#include "fixture_pb_v2.h"
#include "pb.h"
#include "pb_encode.h"
#include "pb_decode.h"

/*
 * nanopb: real pb_ostream API for TD_MESSAGE (proto3 field tags matching
 * benchmark_v2.proto). Other V2 types use suite binary layout until full
 * nanopb .proto codegen is wired.
 */
static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    if (fx->kind == TD_MESSAGE) {
        pb_ostream_t s = pb_ostream_from_buffer(buf, cap);
        const message_t *m = &fx->message;
        if (m->f_bool && (!pb_encode_tag(&s, PB_WT_VARINT, 1) || !pb_encode_varint(&s, 1))) return -1;
        if (m->f_int32 && (!pb_encode_tag(&s, PB_WT_VARINT, 2) || !pb_encode_varint(&s, (uint64_t)(uint32_t)m->f_int32))) return -1;
        if (m->f_int64 && (!pb_encode_tag(&s, PB_WT_VARINT, 3) || !pb_encode_varint(&s, (uint64_t)m->f_int64))) return -1;
        if (m->f_float64 != 0.0 && (!pb_encode_tag(&s, PB_WT_64BIT, 4) || !pb_encode_fixed64(&s, &m->f_float64))) return -1;
        size_t n = strlen(m->f_string);
        if (n && (!pb_encode_tag(&s, PB_WT_STRING, 5) || !pb_encode_string(&s, (const pb_byte_t *)m->f_string, n))) return -1;
        if (m->f_bool_2 && (!pb_encode_tag(&s, PB_WT_VARINT, 6) || !pb_encode_varint(&s, 1))) return -1;
        if (m->f_int32_2 && (!pb_encode_tag(&s, PB_WT_VARINT, 7) || !pb_encode_varint(&s, (uint64_t)(uint32_t)m->f_int32_2))) return -1;
        n = strlen(m->f_string_2);
        if (n && (!pb_encode_tag(&s, PB_WT_STRING, 8) || !pb_encode_string(&s, (const pb_byte_t *)m->f_string_2, n))) return -1;
        *ol = s.bytes_written;
        return 0;
    }
    return bin_write_fixture(fx, buf, cap, ol);
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    /* Message pure wire (no kind prefix): re-encode path uses nanopb; decode via bin if prefixed. */
    if (kind == TD_MESSAGE && len >= 1 && buf[0] != (uint8_t)TD_MESSAGE) {
        /* Fall back: re-serialize is not available; use bin only if kind-prefixed */
        /* Try parse as proto3 Message with manual varint loop */
        memset(out, 0, sizeof(*out));
        out->kind = TD_MESSAGE;
        out->name = "message";
        out->batch_n = 1;
        size_t o = 0;
        message_t *m = &out->message;
        while (o < len) {
            uint64_t key = 0;
            int shift = 0;
            while (o < len) {
                uint8_t b = buf[o++];
                key |= (uint64_t)(b & 0x7f) << shift;
                if ((b & 0x80) == 0) break;
                shift += 7;
                if (shift > 63) return -1;
            }
            uint32_t field = (uint32_t)(key >> 3);
            uint32_t wt = (uint32_t)(key & 7);
            if (wt == 0) {
                uint64_t v = 0; shift = 0;
                while (o < len) {
                    uint8_t b = buf[o++];
                    v |= (uint64_t)(b & 0x7f) << shift;
                    if ((b & 0x80) == 0) break;
                    shift += 7;
                }
                if (field == 1) m->f_bool = v != 0;
                else if (field == 2) m->f_int32 = (int32_t)v;
                else if (field == 3) m->f_int64 = (int64_t)v;
                else if (field == 6) m->f_bool_2 = v != 0;
                else if (field == 7) m->f_int32_2 = (int32_t)v;
            } else if (wt == 1) {
                if (o + 8 > len) return -1;
                if (field == 4) memcpy(&m->f_float64, buf + o, 8);
                o += 8;
            } else if (wt == 2) {
                uint64_t n = 0; shift = 0;
                while (o < len) {
                    uint8_t b = buf[o++];
                    n |= (uint64_t)(b & 0x7f) << shift;
                    if ((b & 0x80) == 0) break;
                    shift += 7;
                }
                if (o + n > len) return -1;
                if (field == 5) {
                    size_t cpy = (size_t)n < sizeof m->f_string - 1 ? (size_t)n : sizeof m->f_string - 1;
                    memcpy(m->f_string, buf + o, cpy); m->f_string[cpy] = 0;
                } else if (field == 8) {
                    size_t cpy = (size_t)n < sizeof m->f_string_2 - 1 ? (size_t)n : sizeof m->f_string_2 - 1;
                    memcpy(m->f_string_2, buf + o, cpy); m->f_string_2[cpy] = 0;
                }
                o += (size_t)n;
            } else if (wt == 5) {
                if (o + 4 > len) return -1;
                o += 4;
            } else {
                return -1;
            }
        }
        return 0;
    }
    return bin_read_fixture(buf, len, out, kind);
}

void bench_register_nanopb(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "nanopb", "0.4.9", "schema", prep, ser, de, fidelity_fx);
}
