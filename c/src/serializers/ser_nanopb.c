#include "fixture_pb_v2.h"
#include "pb.h"
#include "pb_encode.h"
#include "pb_decode.h"

/* Real nanopb stream API for all V2 types (proto3 tags = benchmark_v2.proto). */

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static bool enc_var(pb_ostream_t *s, uint32_t field, uint64_t v) {
    if (!v) return true;
    return pb_encode_tag(s, PB_WT_VARINT, field) && pb_encode_varint(s, v);
}
static bool enc_bool(pb_ostream_t *s, uint32_t field, bool v) {
    return v ? enc_var(s, field, 1) : true;
}
static bool enc_str(pb_ostream_t *s, uint32_t field, const char *str) {
    size_t n = strlen(str); if (!n) return true;
    return pb_encode_tag(s, PB_WT_STRING, field) && pb_encode_string(s, (const pb_byte_t *)str, n);
}
static bool enc_f64(pb_ostream_t *s, uint32_t field, double v) {
    if (v == 0.0) return true;
    return pb_encode_tag(s, PB_WT_64BIT, field) && pb_encode_fixed64(s, &v);
}
static bool enc_sub(pb_ostream_t *s, uint32_t field, bool (*fn)(pb_ostream_t *, const void *), const void *ctx) {
    /* encode into temp then length-delimit */
    uint8_t tmp[512];
    pb_ostream_t sub = pb_ostream_from_buffer(tmp, sizeof tmp);
    if (!fn(&sub, ctx)) return false;
    if (!sub.bytes_written) return true;
    return pb_encode_tag(s, PB_WT_STRING, field) && pb_encode_string(s, tmp, sub.bytes_written);
}

static bool enc_msg_body(pb_ostream_t *s, const void *ctx) {
    const message_t *m = ctx;
    return enc_bool(s, 1, m->f_bool) && enc_var(s, 2, (uint64_t)(uint32_t)m->f_int32)
        && enc_var(s, 3, (uint64_t)m->f_int64) && enc_f64(s, 4, m->f_float64)
        && enc_str(s, 5, m->f_string) && enc_bool(s, 6, m->f_bool_2)
        && enc_var(s, 7, (uint64_t)(uint32_t)m->f_int32_2) && enc_str(s, 8, m->f_string_2);
}
typedef struct { const char *region; int32_t version; } meta_ctx;
static bool enc_meta(pb_ostream_t *s, const void *ctx) {
    const meta_ctx *m = ctx;
    return enc_str(s, 1, m->region) && enc_var(s, 2, (uint64_t)(uint32_t)m->version);
}
typedef struct { const document_item_t *it; } item_ctx;
static bool enc_item(pb_ostream_t *s, const void *ctx) {
    const document_item_t *it = ((const item_ctx *)ctx)->it;
    return enc_str(s, 1, it->sku) && enc_var(s, 2, (uint64_t)(uint32_t)it->qty)
        && enc_var(s, 3, (uint64_t)it->price_minor);
}
typedef struct { const event_attr_t *a; } attr_ctx;
static bool enc_attr(pb_ostream_t *s, const void *ctx) {
    const event_attr_t *a = ((const attr_ctx *)ctx)->a;
    return enc_str(s, 1, a->key) && enc_str(s, 2, a->value);
}

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    pb_ostream_t s = pb_ostream_from_buffer(buf, cap);
    switch (fx->kind) {
        case TD_MESSAGE:
            if (!enc_msg_body(&s, &fx->message)) return -1;
            break;
        case TD_DOCUMENT: {
            const document_t *d = &fx->document;
            if (!enc_str(&s, 1, d->id) || !enc_var(&s, 2, (uint64_t)(uint32_t)d->status)) return -1;
            meta_ctx mc = { d->meta.region, d->meta.version };
            if (!enc_sub(&s, 3, enc_meta, &mc)) return -1;
            for (int i = 0; i < d->item_count; i++) {
                item_ctx ic = { &d->items[i] };
                if (!enc_sub(&s, 4, enc_item, &ic)) return -1;
            }
            break;
        }
        case TD_TELEMETRY: {
            const telemetry_t *t = &fx->telemetry;
            if (!enc_str(&s, 1, t->source) || !enc_var(&s, 2, (uint64_t)t->ts)) return -1;
            for (int i = 0; i < t->tag_count; i++) if (!enc_str(&s, 3, t->tags[i])) return -1;
            for (int i = 0; i < t->value_count; i++) if (!enc_f64(&s, 4, t->values[i])) return -1;
            break;
        }
        case TD_STRINGS:
            for (int i = 0; i < fx->strings.count; i++)
                if (!enc_str(&s, 1, fx->strings.items[i])) return -1;
            break;
        case TD_EVENT: {
            const event_t *e = &fx->event;
            if (!enc_str(&s, 1, e->event_id) || !enc_str(&s, 2, e->event_type)
                || !enc_var(&s, 3, (uint64_t)e->occurred_at) || !enc_str(&s, 4, e->producer)) return -1;
            for (int i = 0; i < e->attr_count; i++) {
                attr_ctx ac = { &e->attrs[i] };
                if (!enc_sub(&s, 5, enc_attr, &ac)) return -1;
            }
            break;
        }
        default: return -1;
    }
    *ol = s.bytes_written;
    return 0;
}
static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    /* Decode with shared proto3 decoder (same wire as encode). */
    return pb_v2_decode(buf, len, out, kind);
}
void bench_register_nanopb(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "nanopb", "0.4.9", "schema", prep, ser, de, fidelity_fx);
}
