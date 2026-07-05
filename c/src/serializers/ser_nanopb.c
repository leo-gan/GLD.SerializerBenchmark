#include "ser_common.h"
#include "pb.h"
#include "pb_encode.h"
#include "pb_decode.h"

/* Manual nanopb field list for a compact Fixture message (proto3-style tags). */
typedef struct {
    int32_t kind;
    int32_t integer_val;
    char first_name[32];
    char last_name[32];
    int32_t age;
    int32_t gender;
    int32_t police_count;
    char simple_name[32];
    char simple_ts[32];
    int32_t simple_id;
    bool simple_active;
    char telem_id[24];
    int32_t param1;
    int32_t meas_count;
    int32_t str_count;
    char payer[32];
    char payee[32];
    int32_t claim_count;
    double total_actual;
    /* string array packed as length-delimited blob of fixed 16-byte slots */
    pb_bytes_array_t *items_blob;
    uint8_t items_storage[4 + 100 * 16];
} FixtureMsg;

static bool enc_string(pb_ostream_t *stream, const pb_field_t *field, void * const *arg) {
    const char *str = (const char *)(*arg);
    if (!pb_encode_tag_for_field(stream, field)) return false;
    return pb_encode_string(stream, (const pb_byte_t *)str, strlen(str));
}

/* Use low-level encode without full PB_BIND: encode fields by tag */
static bool encode_fixture(pb_ostream_t *stream, const FixtureMsg *m) {
    if (!pb_encode_tag(stream, PB_WT_VARINT, 1) || !pb_encode_varint(stream, (uint64_t)(uint32_t)m->kind)) return false;
    switch (m->kind) {
        case TD_INTEGER:
            if (!pb_encode_tag(stream, PB_WT_VARINT, 2) || !pb_encode_varint(stream, (uint64_t)(uint32_t)m->integer_val)) return false;
            break;
        case TD_SIMPLE:
            if (!pb_encode_tag(stream, PB_WT_VARINT, 10) || !pb_encode_varint(stream, (uint64_t)(uint32_t)m->simple_id)) return false;
            if (!pb_encode_tag(stream, PB_WT_STRING, 11) || !pb_encode_string(stream, (pb_byte_t *)m->simple_name, strlen(m->simple_name))) return false;
            if (!pb_encode_tag(stream, PB_WT_STRING, 12) || !pb_encode_string(stream, (pb_byte_t *)m->simple_ts, strlen(m->simple_ts))) return false;
            if (!pb_encode_tag(stream, PB_WT_VARINT, 13) || !pb_encode_varint(stream, m->simple_active ? 1 : 0)) return false;
            break;
        case TD_PERSON:
            if (!pb_encode_tag(stream, PB_WT_STRING, 20) || !pb_encode_string(stream, (pb_byte_t *)m->first_name, strlen(m->first_name))) return false;
            if (!pb_encode_tag(stream, PB_WT_STRING, 21) || !pb_encode_string(stream, (pb_byte_t *)m->last_name, strlen(m->last_name))) return false;
            if (!pb_encode_tag(stream, PB_WT_VARINT, 22) || !pb_encode_varint(stream, (uint64_t)(uint32_t)m->age)) return false;
            if (!pb_encode_tag(stream, PB_WT_VARINT, 23) || !pb_encode_varint(stream, (uint64_t)(uint32_t)m->gender)) return false;
            if (!pb_encode_tag(stream, PB_WT_VARINT, 24) || !pb_encode_varint(stream, (uint64_t)(uint32_t)m->police_count)) return false;
            break;
        case TD_TELEMETRY:
            if (!pb_encode_tag(stream, PB_WT_STRING, 30) || !pb_encode_string(stream, (pb_byte_t *)m->telem_id, strlen(m->telem_id))) return false;
            if (!pb_encode_tag(stream, PB_WT_VARINT, 31) || !pb_encode_varint(stream, (uint64_t)(uint32_t)m->param1)) return false;
            if (!pb_encode_tag(stream, PB_WT_VARINT, 32) || !pb_encode_varint(stream, (uint64_t)(uint32_t)m->meas_count)) return false;
            break;
        case TD_STRING_ARRAY: {
            if (!pb_encode_tag(stream, PB_WT_VARINT, 40) || !pb_encode_varint(stream, (uint64_t)(uint32_t)m->str_count)) return false;
            size_t blob = (size_t)m->str_count * 16;
            if (!pb_encode_tag(stream, PB_WT_STRING, 41) || !pb_encode_string(stream, m->items_storage + 4, blob)) return false;
            break;
        }
        case TD_EDI835:
            if (!pb_encode_tag(stream, PB_WT_STRING, 50) || !pb_encode_string(stream, (pb_byte_t *)m->payer, strlen(m->payer))) return false;
            if (!pb_encode_tag(stream, PB_WT_STRING, 51) || !pb_encode_string(stream, (pb_byte_t *)m->payee, strlen(m->payee))) return false;
            if (!pb_encode_tag(stream, PB_WT_VARINT, 52) || !pb_encode_varint(stream, (uint64_t)(uint32_t)m->claim_count)) return false;
            {
                uint64_t bits; memcpy(&bits, &m->total_actual, 8);
                if (!pb_encode_tag(stream, PB_WT_64BIT, 53) || !pb_encode_fixed64(stream, &bits)) return false;
            }
            break;
        default: return false;
    }
    return true;
}

static void fx_to_msg(const test_fixture_t *fx, FixtureMsg *m) {
    memset(m, 0, sizeof *m);
    m->kind = (int32_t)fx->kind;
    switch (fx->kind) {
        case TD_INTEGER: m->integer_val = fx->integer_val; break;
        case TD_SIMPLE:
            m->simple_id = fx->simple.id;
            snprintf(m->simple_name, sizeof m->simple_name, "%s", fx->simple.name);
            snprintf(m->simple_ts, sizeof m->simple_ts, "%s", fx->simple.timestamp);
            m->simple_active = fx->simple.is_active;
            break;
        case TD_PERSON:
            snprintf(m->first_name, sizeof m->first_name, "%s", fx->person.first_name);
            snprintf(m->last_name, sizeof m->last_name, "%s", fx->person.last_name);
            m->age = fx->person.age; m->gender = fx->person.gender; m->police_count = fx->person.police_count;
            break;
        case TD_TELEMETRY:
            snprintf(m->telem_id, sizeof m->telem_id, "%s", fx->telemetry.id);
            m->param1 = fx->telemetry.param1; m->meas_count = fx->telemetry.meas_count;
            break;
        case TD_STRING_ARRAY:
            m->str_count = fx->string_array.count;
            for (int i = 0; i < m->str_count && i < 100; i++)
                memcpy(m->items_storage + 4 + i * 16, fx->string_array.items[i], 16);
            break;
        case TD_EDI835:
            snprintf(m->payer, sizeof m->payer, "%s", fx->edi.payer_name);
            snprintf(m->payee, sizeof m->payee, "%s", fx->edi.payee_name);
            m->claim_count = fx->edi.claim_count; m->total_actual = fx->edi.total_actual;
            break;
        default: break;
    }
}

static bool decode_fixture(pb_istream_t *stream, FixtureMsg *m) {
    memset(m, 0, sizeof *m);
    while (stream->bytes_left) {
        pb_wire_type_t wt;
        uint32_t field;
        bool eof = false;
        if (!pb_decode_tag(stream, &wt, &field, &eof)) {
            if (eof) break;
            return false;
        }
        switch (field) {
            case 1: { uint64_t v; if (!pb_decode_varint(stream, &v)) return false; m->kind = (int32_t)v; break; }
            case 2: { uint64_t v; if (!pb_decode_varint(stream, &v)) return false; m->integer_val = (int32_t)v; break; }
            case 10: { uint64_t v; if (!pb_decode_varint(stream, &v)) return false; m->simple_id = (int32_t)v; break; }
            case 11: { pb_istream_t sub; if (!pb_make_string_substream(stream, &sub)) return false;
                size_t n = sub.bytes_left < sizeof m->simple_name - 1 ? sub.bytes_left : sizeof m->simple_name - 1;
                if (!pb_read(&sub, (pb_byte_t *)m->simple_name, n)) return false; m->simple_name[n]=0;
                if (!pb_close_string_substream(stream, &sub)) return false; break; }
            case 12: { pb_istream_t sub; if (!pb_make_string_substream(stream, &sub)) return false;
                size_t n = sub.bytes_left < sizeof m->simple_ts - 1 ? sub.bytes_left : sizeof m->simple_ts - 1;
                if (!pb_read(&sub, (pb_byte_t *)m->simple_ts, n)) return false; m->simple_ts[n]=0;
                if (!pb_close_string_substream(stream, &sub)) return false; break; }
            case 13: { uint64_t v; if (!pb_decode_varint(stream, &v)) return false; m->simple_active = v != 0; break; }
            case 20: { pb_istream_t sub; if (!pb_make_string_substream(stream, &sub)) return false;
                size_t n = sub.bytes_left < sizeof m->first_name - 1 ? sub.bytes_left : sizeof m->first_name - 1;
                if (!pb_read(&sub, (pb_byte_t *)m->first_name, n)) return false; m->first_name[n]=0;
                if (!pb_close_string_substream(stream, &sub)) return false; break; }
            case 21: { pb_istream_t sub; if (!pb_make_string_substream(stream, &sub)) return false;
                size_t n = sub.bytes_left < sizeof m->last_name - 1 ? sub.bytes_left : sizeof m->last_name - 1;
                if (!pb_read(&sub, (pb_byte_t *)m->last_name, n)) return false; m->last_name[n]=0;
                if (!pb_close_string_substream(stream, &sub)) return false; break; }
            case 22: { uint64_t v; if (!pb_decode_varint(stream, &v)) return false; m->age = (int32_t)v; break; }
            case 23: { uint64_t v; if (!pb_decode_varint(stream, &v)) return false; m->gender = (int32_t)v; break; }
            case 24: { uint64_t v; if (!pb_decode_varint(stream, &v)) return false; m->police_count = (int32_t)v; break; }
            case 30: { pb_istream_t sub; if (!pb_make_string_substream(stream, &sub)) return false;
                size_t n = sub.bytes_left < sizeof m->telem_id - 1 ? sub.bytes_left : sizeof m->telem_id - 1;
                if (!pb_read(&sub, (pb_byte_t *)m->telem_id, n)) return false; m->telem_id[n]=0;
                if (!pb_close_string_substream(stream, &sub)) return false; break; }
            case 31: { uint64_t v; if (!pb_decode_varint(stream, &v)) return false; m->param1 = (int32_t)v; break; }
            case 32: { uint64_t v; if (!pb_decode_varint(stream, &v)) return false; m->meas_count = (int32_t)v; break; }
            case 40: { uint64_t v; if (!pb_decode_varint(stream, &v)) return false; m->str_count = (int32_t)v; break; }
            case 41: { pb_istream_t sub; if (!pb_make_string_substream(stream, &sub)) return false;
                size_t n = sub.bytes_left < 100*16 ? sub.bytes_left : 100*16;
                if (!pb_read(&sub, m->items_storage + 4, n)) return false;
                if (!pb_close_string_substream(stream, &sub)) return false; break; }
            case 50: { pb_istream_t sub; if (!pb_make_string_substream(stream, &sub)) return false;
                size_t n = sub.bytes_left < sizeof m->payer - 1 ? sub.bytes_left : sizeof m->payer - 1;
                if (!pb_read(&sub, (pb_byte_t *)m->payer, n)) return false; m->payer[n]=0;
                if (!pb_close_string_substream(stream, &sub)) return false; break; }
            case 51: { pb_istream_t sub; if (!pb_make_string_substream(stream, &sub)) return false;
                size_t n = sub.bytes_left < sizeof m->payee - 1 ? sub.bytes_left : sizeof m->payee - 1;
                if (!pb_read(&sub, (pb_byte_t *)m->payee, n)) return false; m->payee[n]=0;
                if (!pb_close_string_substream(stream, &sub)) return false; break; }
            case 52: { uint64_t v; if (!pb_decode_varint(stream, &v)) return false; m->claim_count = (int32_t)v; break; }
            case 53: { uint64_t bits; if (!pb_decode_fixed64(stream, &bits)) return false; memcpy(&m->total_actual, &bits, 8); break; }
            default:
                if (!pb_skip_field(stream, wt)) return false;
                break;
        }
    }
    return true;
}

static void msg_to_fx(const FixtureMsg *m, test_fixture_t *out, test_data_kind_t kind) {
    out->kind = kind;
    out->name = test_data_name(kind);
    switch (kind) {
        case TD_INTEGER: out->integer_val = m->integer_val; break;
        case TD_SIMPLE:
            out->simple.id = m->simple_id;
            snprintf(out->simple.name, sizeof out->simple.name, "%s", m->simple_name);
            snprintf(out->simple.timestamp, sizeof out->simple.timestamp, "%s", m->simple_ts);
            out->simple.is_active = m->simple_active;
            break;
        case TD_PERSON:
            snprintf(out->person.first_name, sizeof out->person.first_name, "%s", m->first_name);
            snprintf(out->person.last_name, sizeof out->person.last_name, "%s", m->last_name);
            out->person.age = m->age; out->person.gender = m->gender; out->person.police_count = m->police_count;
            break;
        case TD_TELEMETRY:
            snprintf(out->telemetry.id, sizeof out->telemetry.id, "%s", m->telem_id);
            out->telemetry.param1 = m->param1; out->telemetry.meas_count = m->meas_count;
            break;
        case TD_STRING_ARRAY:
            out->string_array.count = m->str_count;
            for (int i = 0; i < m->str_count && i < 100; i++)
                memcpy(out->string_array.items[i], m->items_storage + 4 + i * 16, 16);
            break;
        case TD_EDI835:
            snprintf(out->edi.payer_name, sizeof out->edi.payer_name, "%s", m->payer);
            snprintf(out->edi.payee_name, sizeof out->edi.payee_name, "%s", m->payee);
            out->edi.claim_count = m->claim_count; out->edi.total_actual = m->total_actual;
            break;
        default: break;
    }
}

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    FixtureMsg m; fx_to_msg(fx, &m);
    pb_ostream_t stream = pb_ostream_from_buffer(buf, cap);
    if (!encode_fixture(&stream, &m)) return -1;
    *ol = stream.bytes_written;
    return 0;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    FixtureMsg m;
    pb_istream_t stream = pb_istream_from_buffer(buf, len);
    if (!decode_fixture(&stream, &m)) return -1;
    if (m.kind != (int32_t)kind) return -1;
    msg_to_fx(&m, out, kind);
    return 0;
}

void bench_register_nanopb(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "nanopb", "0.4.9", "schema", prep, ser, de, fidelity_fx);
}
