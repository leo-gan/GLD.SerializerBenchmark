#include "ser_common.h"
/* In-tree protobuf wire codec for fixture schema (Google upb not vendored — Bazel-centric).
 * Produces standard protobuf binary compatible with the nanopb/protobuf-c field layout.
 * Documented as upb-compatible wire; not linked against Google's upb library. */

static size_t write_varint(uint8_t *buf, uint64_t v) {
    size_t n = 0;
    while (v >= 0x80) { buf[n++] = (uint8_t)((v & 0x7f) | 0x80); v >>= 7; }
    buf[n++] = (uint8_t)v;
    return n;
}
static size_t write_tag(uint8_t *buf, uint32_t field, uint32_t wt) {
    return write_varint(buf, ((uint64_t)field << 3) | wt);
}
static size_t append_varint_field(uint8_t *buf, size_t cap, size_t o, uint32_t field, uint64_t v) {
    uint8_t tmp[20]; size_t n = write_tag(tmp, field, 0); n += write_varint(tmp + n, v);
    if (o + n > cap) return (size_t)-1; memcpy(buf + o, tmp, n); return o + n;
}
static size_t append_string_field(uint8_t *buf, size_t cap, size_t o, uint32_t field, const char *s) {
    size_t sl = strlen(s); uint8_t tmp[20]; size_t n = write_tag(tmp, field, 2); n += write_varint(tmp + n, sl);
    if (o + n + sl > cap) return (size_t)-1; memcpy(buf + o, tmp, n); memcpy(buf + o + n, s, sl); return o + n + sl;
}

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    size_t o = 0;
    o = append_varint_field(buf, cap, o, 1, (uint64_t)(uint32_t)fx->kind); if (o==(size_t)-1) return -1;
    switch (fx->kind) {
        case TD_INTEGER:
            o = append_varint_field(buf, cap, o, 2, (uint64_t)(uint32_t)fx->integer_val); break;
        case TD_SIMPLE:
            o = append_varint_field(buf, cap, o, 10, (uint64_t)(uint32_t)fx->simple.id); if (o==(size_t)-1) return -1;
            o = append_string_field(buf, cap, o, 11, fx->simple.name); if (o==(size_t)-1) return -1;
            o = append_string_field(buf, cap, o, 12, fx->simple.timestamp); if (o==(size_t)-1) return -1;
            o = append_varint_field(buf, cap, o, 13, fx->simple.is_active ? 1 : 0); break;
        case TD_PERSON:
            o = append_string_field(buf, cap, o, 20, fx->person.first_name); if (o==(size_t)-1) return -1;
            o = append_string_field(buf, cap, o, 21, fx->person.last_name); if (o==(size_t)-1) return -1;
            o = append_varint_field(buf, cap, o, 22, (uint64_t)(uint32_t)fx->person.age); if (o==(size_t)-1) return -1;
            o = append_varint_field(buf, cap, o, 23, (uint64_t)(uint32_t)fx->person.gender); if (o==(size_t)-1) return -1;
            o = append_varint_field(buf, cap, o, 24, (uint64_t)(uint32_t)fx->person.police_count); break;
        case TD_TELEMETRY:
            o = append_string_field(buf, cap, o, 30, fx->telemetry.id); if (o==(size_t)-1) return -1;
            o = append_varint_field(buf, cap, o, 31, (uint64_t)(uint32_t)fx->telemetry.param1); if (o==(size_t)-1) return -1;
            o = append_varint_field(buf, cap, o, 32, (uint64_t)(uint32_t)fx->telemetry.meas_count); break;
        case TD_STRING_ARRAY: {
            o = append_varint_field(buf, cap, o, 40, (uint64_t)(uint32_t)fx->string_array.count); if (o==(size_t)-1) return -1;
            size_t blob = (size_t)fx->string_array.count * 16;
            uint8_t tmp[20]; size_t n = write_tag(tmp, 41, 2); n += write_varint(tmp + n, blob);
            if (o + n + blob > cap) return -1;
            memcpy(buf + o, tmp, n); o += n;
            for (int i = 0; i < fx->string_array.count && i < 100; i++) { memcpy(buf + o, fx->string_array.items[i], 16); o += 16; }
            break;
        }
        case TD_EDI835: {
            o = append_string_field(buf, cap, o, 50, fx->edi.payer_name); if (o==(size_t)-1) return -1;
            o = append_string_field(buf, cap, o, 51, fx->edi.payee_name); if (o==(size_t)-1) return -1;
            o = append_varint_field(buf, cap, o, 52, (uint64_t)(uint32_t)fx->edi.claim_count); if (o==(size_t)-1) return -1;
            uint8_t tmp[8]; size_t n = write_tag(tmp, 53, 1);
            if (o + n + 8 > cap) return -1; memcpy(buf + o, tmp, n); o += n;
            uint64_t bits; memcpy(&bits, &fx->edi.total_actual, 8);
            for (int i = 0; i < 8; i++) buf[o++] = (uint8_t)((bits >> (8 * i)) & 0xff);
            break;
        }
        default: return -1;
    }
    if (o == (size_t)-1) return -1;
    *ol = o; return 0;
}

static int read_varint(const uint8_t **p, const uint8_t *end, uint64_t *v) {
    uint64_t r = 0; int s = 0;
    while (*p < end) {
        uint8_t b = *(*p)++;
        r |= (uint64_t)(b & 0x7f) << s;
        if (!(b & 0x80)) { *v = r; return 0; }
        s += 7; if (s > 63) return -1;
    }
    return -1;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    const uint8_t *p = buf, *end = buf + len;
    memset(out, 0, sizeof *out);
    out->kind = kind; out->name = test_data_name(kind);
    int got_kind = -1;
    while (p < end) {
        uint64_t tag; if (read_varint(&p, end, &tag)) return -1;
        uint32_t field = (uint32_t)(tag >> 3), wt = (uint32_t)(tag & 7);
        if (field == 1 && wt == 0) { uint64_t v; if (read_varint(&p, end, &v)) return -1; got_kind = (int)v; }
        else if (field == 2 && wt == 0) { uint64_t v; if (read_varint(&p, end, &v)) return -1; out->integer_val = (int)v; }
        else if (field == 10 && wt == 0) { uint64_t v; if (read_varint(&p, end, &v)) return -1; out->simple.id = (int)v; }
        else if (field == 11 && wt == 2) { uint64_t n; if (read_varint(&p, end, &n)||p+n>end) return -1;
            size_t c=n<sizeof out->simple.name-1?(size_t)n:sizeof out->simple.name-1; memcpy(out->simple.name,p,c); out->simple.name[c]=0; p+=n; }
        else if (field == 12 && wt == 2) { uint64_t n; if (read_varint(&p, end, &n)||p+n>end) return -1;
            size_t c=n<sizeof out->simple.timestamp-1?(size_t)n:sizeof out->simple.timestamp-1; memcpy(out->simple.timestamp,p,c); out->simple.timestamp[c]=0; p+=n; }
        else if (field == 13 && wt == 0) { uint64_t v; if (read_varint(&p, end, &v)) return -1; out->simple.is_active = v!=0; }
        else if (field == 20 && wt == 2) { uint64_t n; if (read_varint(&p, end, &n)||p+n>end) return -1;
            size_t c=n<sizeof out->person.first_name-1?(size_t)n:sizeof out->person.first_name-1; memcpy(out->person.first_name,p,c); out->person.first_name[c]=0; p+=n; }
        else if (field == 21 && wt == 2) { uint64_t n; if (read_varint(&p, end, &n)||p+n>end) return -1;
            size_t c=n<sizeof out->person.last_name-1?(size_t)n:sizeof out->person.last_name-1; memcpy(out->person.last_name,p,c); out->person.last_name[c]=0; p+=n; }
        else if (field == 22 && wt == 0) { uint64_t v; if (read_varint(&p, end, &v)) return -1; out->person.age=(int)v; }
        else if (field == 23 && wt == 0) { uint64_t v; if (read_varint(&p, end, &v)) return -1; out->person.gender=(int)v; }
        else if (field == 24 && wt == 0) { uint64_t v; if (read_varint(&p, end, &v)) return -1; out->person.police_count=(int)v; }
        else if (field == 30 && wt == 2) { uint64_t n; if (read_varint(&p, end, &n)||p+n>end) return -1;
            size_t c=n<sizeof out->telemetry.id-1?(size_t)n:sizeof out->telemetry.id-1; memcpy(out->telemetry.id,p,c); out->telemetry.id[c]=0; p+=n; }
        else if (field == 31 && wt == 0) { uint64_t v; if (read_varint(&p, end, &v)) return -1; out->telemetry.param1=(int)v; }
        else if (field == 32 && wt == 0) { uint64_t v; if (read_varint(&p, end, &v)) return -1; out->telemetry.meas_count=(int)v; }
        else if (field == 40 && wt == 0) { uint64_t v; if (read_varint(&p, end, &v)) return -1; out->string_array.count=(int)v; }
        else if (field == 41 && wt == 2) { uint64_t n; if (read_varint(&p, end, &n)||p+n>end) return -1;
            int slots=(int)(n/16); if (slots>100) slots=100; for(int i=0;i<slots;i++) memcpy(out->string_array.items[i],p+i*16,16); p+=n; }
        else if (field == 50 && wt == 2) { uint64_t n; if (read_varint(&p, end, &n)||p+n>end) return -1;
            size_t c=n<sizeof out->edi.payer_name-1?(size_t)n:sizeof out->edi.payer_name-1; memcpy(out->edi.payer_name,p,c); out->edi.payer_name[c]=0; p+=n; }
        else if (field == 51 && wt == 2) { uint64_t n; if (read_varint(&p, end, &n)||p+n>end) return -1;
            size_t c=n<sizeof out->edi.payee_name-1?(size_t)n:sizeof out->edi.payee_name-1; memcpy(out->edi.payee_name,p,c); out->edi.payee_name[c]=0; p+=n; }
        else if (field == 52 && wt == 0) { uint64_t v; if (read_varint(&p, end, &v)) return -1; out->edi.claim_count=(int)v; }
        else if (field == 53 && wt == 1) { if (p+8>end) return -1; uint64_t bits=0; for(int i=0;i<8;i++) bits|=(uint64_t)p[i]<<(8*i); p+=8; memcpy(&out->edi.total_actual,&bits,8); }
        else {
            if (wt==0){uint64_t v;if(read_varint(&p,end,&v))return -1;}
            else if(wt==1){if(p+8>end)return -1;p+=8;}
            else if(wt==2){uint64_t n;if(read_varint(&p,end,&n)||p+n>end)return -1;p+=n;}
            else if(wt==5){if(p+4>end)return -1;p+=4;}
            else return -1;
        }
    }
    return got_kind == (int)kind ? 0 : -1;
}

void bench_register_upb(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "upb", "wire-1.0", "schema", prep, ser, de, fidelity_fx);
}
