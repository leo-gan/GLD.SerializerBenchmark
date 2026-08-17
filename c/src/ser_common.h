#ifndef SER_COMMON_H
#define SER_COMMON_H
#include "bench.h"
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

static inline bool supports_all(test_data_kind_t k) { (void)k; return true; }

static inline bool f64_close(double a, double b) {
    double d = a - b; if (d < 0) d = -d;
    double s = a >= 0 ? a : -a; if (b > s) s = b >= 0 ? b : -b;
    return d <= 1e-9 || d <= 1e-6 * (s + 1.0);
}

static inline bool fidelity_message(const message_t *a, const message_t *b) {
    return a->f_bool == b->f_bool && a->f_int32 == b->f_int32 && a->f_int64 == b->f_int64 &&
           f64_close(a->f_float64, b->f_float64) && strcmp(a->f_string, b->f_string) == 0 &&
           a->f_bool_2 == b->f_bool_2 && a->f_int32_2 == b->f_int32_2 &&
           strcmp(a->f_string_2, b->f_string_2) == 0;
}

static inline bool fidelity_document(const document_t *a, const document_t *b) {
    if (strcmp(a->id, b->id) || a->status != b->status) return false;
    if (strcmp(a->meta.region, b->meta.region) || a->meta.version != b->meta.version) return false;
    if (a->item_count != b->item_count) return false;
    for (int i = 0; i < a->item_count; i++) {
        if (strcmp(a->items[i].sku, b->items[i].sku) || a->items[i].qty != b->items[i].qty ||
            a->items[i].price_minor != b->items[i].price_minor)
            return false;
    }
    return true;
}

static inline bool fidelity_telemetry(const telemetry_t *a, const telemetry_t *b) {
    if (strcmp(a->source, b->source) || a->ts != b->ts) return false;
    if (a->tag_count != b->tag_count || a->value_count != b->value_count) return false;
    for (int i = 0; i < a->tag_count; i++)
        if (strcmp(a->tags[i], b->tags[i])) return false;
    for (int i = 0; i < a->value_count; i++)
        if (!f64_close(a->values[i], b->values[i])) return false;
    return true;
}

static inline bool fidelity_strings(const strings_t *a, const strings_t *b) {
    if (a->count != b->count) return false;
    for (int i = 0; i < a->count; i++)
        if (strcmp(a->items[i], b->items[i])) return false;
    return true;
}

static inline bool fidelity_event(const event_t *a, const event_t *b) {
    if (strcmp(a->event_id, b->event_id) || strcmp(a->event_type, b->event_type)) return false;
    if (a->occurred_at != b->occurred_at || strcmp(a->producer, b->producer)) return false;
    if (a->attr_count != b->attr_count) return false;
    for (int i = 0; i < a->attr_count; i++)
        if (strcmp(a->attrs[i].key, b->attrs[i].key) || strcmp(a->attrs[i].value, b->attrs[i].value))
            return false;
    return true;
}

static inline bool fidelity_fx(const test_fixture_t *a, const test_fixture_t *b) {
    if (a->kind != b->kind) return false;
    switch (a->kind) {
        case TD_MESSAGE: return fidelity_message(&a->message, &b->message);
        case TD_DOCUMENT: return fidelity_document(&a->document, &b->document);
        case TD_TELEMETRY: return fidelity_telemetry(&a->telemetry, &b->telemetry);
        case TD_STRINGS: return fidelity_strings(&a->strings, &b->strings);
        case TD_EVENT: return fidelity_event(&a->event, &b->event);
        default: return false;
    }
}

/* V2 custom-binary baseline (kind byte + little-endian fields / length-prefixed strings) */
static inline int bin_wr_str(uint8_t *buf, size_t cap, size_t *o, const char *s) {
    size_t n = strlen(s);
    if (*o + 2 + n > cap) return -1;
    buf[(*o)++] = (uint8_t)(n & 0xff);
    buf[(*o)++] = (uint8_t)((n >> 8) & 0xff);
    memcpy(buf + *o, s, n);
    *o += n;
    return 0;
}
static inline int bin_rd_str(const uint8_t *buf, size_t len, size_t *o, char *dst, size_t dcap) {
    if (*o + 2 > len) return -1;
    size_t n = (size_t)buf[*o] | ((size_t)buf[*o + 1] << 8);
    *o += 2;
    if (*o + n > len || n >= dcap) return -1;
    memcpy(dst, buf + *o, n);
    dst[n] = 0;
    *o += n;
    return 0;
}
#define BIN_WR_I32(buf, cap, o, v) do { \
    if (*(o) + 4 > (cap)) return -1; \
    int32_t _v = (v); memcpy((buf) + *(o), &_v, 4); *(o) += 4; \
} while (0)
#define BIN_WR_I64(buf, cap, o, v) do { \
    if (*(o) + 8 > (cap)) return -1; \
    int64_t _v = (v); memcpy((buf) + *(o), &_v, 8); *(o) += 8; \
} while (0)
#define BIN_WR_F64(buf, cap, o, v) do { \
    if (*(o) + 8 > (cap)) return -1; \
    double _v = (v); memcpy((buf) + *(o), &_v, 8); *(o) += 8; \
} while (0)
#define BIN_WR_U8(buf, cap, o, v) do { \
    if (*(o) + 1 > (cap)) return -1; \
    (buf)[(*(o))++] = (uint8_t)(v); \
} while (0)

static inline int bin_write_fixture(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *out_len) {
    size_t o = 0;
    BIN_WR_U8(buf, cap, &o, fx->kind);
    switch (fx->kind) {
        case TD_MESSAGE: {
            const message_t *m = &fx->message;
            BIN_WR_U8(buf, cap, &o, m->f_bool ? 1 : 0);
            BIN_WR_I32(buf, cap, &o, m->f_int32);
            BIN_WR_I64(buf, cap, &o, m->f_int64);
            BIN_WR_F64(buf, cap, &o, m->f_float64);
            if (bin_wr_str(buf, cap, &o, m->f_string)) return -1;
            BIN_WR_U8(buf, cap, &o, m->f_bool_2 ? 1 : 0);
            BIN_WR_I32(buf, cap, &o, m->f_int32_2);
            if (bin_wr_str(buf, cap, &o, m->f_string_2)) return -1;
            break;
        }
        case TD_DOCUMENT: {
            const document_t *d = &fx->document;
            if (bin_wr_str(buf, cap, &o, d->id)) return -1;
            BIN_WR_I32(buf, cap, &o, d->status);
            if (bin_wr_str(buf, cap, &o, d->meta.region)) return -1;
            BIN_WR_I32(buf, cap, &o, d->meta.version);
            BIN_WR_I32(buf, cap, &o, d->item_count);
            for (int i = 0; i < d->item_count; i++) {
                if (bin_wr_str(buf, cap, &o, d->items[i].sku)) return -1;
                BIN_WR_I32(buf, cap, &o, d->items[i].qty);
                BIN_WR_I64(buf, cap, &o, d->items[i].price_minor);
            }
            break;
        }
        case TD_TELEMETRY: {
            const telemetry_t *t = &fx->telemetry;
            if (bin_wr_str(buf, cap, &o, t->source)) return -1;
            BIN_WR_I64(buf, cap, &o, t->ts);
            BIN_WR_I32(buf, cap, &o, t->tag_count);
            for (int i = 0; i < t->tag_count; i++)
                if (bin_wr_str(buf, cap, &o, t->tags[i])) return -1;
            BIN_WR_I32(buf, cap, &o, t->value_count);
            for (int i = 0; i < t->value_count; i++) BIN_WR_F64(buf, cap, &o, t->values[i]);
            break;
        }
        case TD_STRINGS: {
            const strings_t *s = &fx->strings;
            BIN_WR_I32(buf, cap, &o, s->count);
            for (int i = 0; i < s->count; i++)
                if (bin_wr_str(buf, cap, &o, s->items[i])) return -1;
            break;
        }
        case TD_EVENT: {
            const event_t *e = &fx->event;
            if (bin_wr_str(buf, cap, &o, e->event_id)) return -1;
            if (bin_wr_str(buf, cap, &o, e->event_type)) return -1;
            BIN_WR_I64(buf, cap, &o, e->occurred_at);
            if (bin_wr_str(buf, cap, &o, e->producer)) return -1;
            BIN_WR_I32(buf, cap, &o, e->attr_count);
            for (int i = 0; i < e->attr_count; i++) {
                if (bin_wr_str(buf, cap, &o, e->attrs[i].key)) return -1;
                if (bin_wr_str(buf, cap, &o, e->attrs[i].value)) return -1;
            }
            break;
        }
        default: return -1;
    }
    *out_len = o;
    return 0;
}

static inline int bin_read_fixture(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    size_t o = 0;
    if (o >= len) return -1;
    test_data_kind_t k = (test_data_kind_t)buf[o++];
    if (k != kind) return -1;
    memset(out, 0, sizeof(*out));
    out->kind = kind;
    out->name = test_data_name(kind);
    out->batch_n = 1;
    switch (kind) {
        case TD_MESSAGE: {
            message_t *m = &out->message;
            if (o >= len) return -1;
            m->f_bool = buf[o++] != 0;
            if (o + 4 > len) return -1; memcpy(&m->f_int32, buf + o, 4); o += 4;
            if (o + 8 > len) return -1; memcpy(&m->f_int64, buf + o, 8); o += 8;
            if (o + 8 > len) return -1; memcpy(&m->f_float64, buf + o, 8); o += 8;
            if (bin_rd_str(buf, len, &o, m->f_string, sizeof m->f_string)) return -1;
            if (o >= len) return -1;
            m->f_bool_2 = buf[o++] != 0;
            if (o + 4 > len) return -1; memcpy(&m->f_int32_2, buf + o, 4); o += 4;
            if (bin_rd_str(buf, len, &o, m->f_string_2, sizeof m->f_string_2)) return -1;
            break;
        }
        case TD_DOCUMENT: {
            document_t *d = &out->document;
            if (bin_rd_str(buf, len, &o, d->id, sizeof d->id)) return -1;
            if (o + 4 > len) return -1; memcpy(&d->status, buf + o, 4); o += 4;
            if (bin_rd_str(buf, len, &o, d->meta.region, sizeof d->meta.region)) return -1;
            if (o + 4 > len) return -1; memcpy(&d->meta.version, buf + o, 4); o += 4;
            if (o + 4 > len) return -1; memcpy(&d->item_count, buf + o, 4); o += 4;
            if (d->item_count < 0 || d->item_count > V2_MAX_CHILDREN) return -1;
            for (int i = 0; i < d->item_count; i++) {
                if (bin_rd_str(buf, len, &o, d->items[i].sku, sizeof d->items[i].sku)) return -1;
                if (o + 4 > len) return -1; memcpy(&d->items[i].qty, buf + o, 4); o += 4;
                if (o + 8 > len) return -1; memcpy(&d->items[i].price_minor, buf + o, 8); o += 8;
            }
            break;
        }
        case TD_TELEMETRY: {
            telemetry_t *t = &out->telemetry;
            if (bin_rd_str(buf, len, &o, t->source, sizeof t->source)) return -1;
            if (o + 8 > len) return -1; memcpy(&t->ts, buf + o, 8); o += 8;
            if (o + 4 > len) return -1; memcpy(&t->tag_count, buf + o, 4); o += 4;
            if (t->tag_count < 0 || t->tag_count > V2_MAX_TAGS) return -1;
            for (int i = 0; i < t->tag_count; i++)
                if (bin_rd_str(buf, len, &o, t->tags[i], sizeof t->tags[i])) return -1;
            if (o + 4 > len) return -1; memcpy(&t->value_count, buf + o, 4); o += 4;
            if (t->value_count < 0 || t->value_count > V2_MAX_POINTS) return -1;
            for (int i = 0; i < t->value_count; i++) {
                if (o + 8 > len) return -1; memcpy(&t->values[i], buf + o, 8); o += 8;
            }
            break;
        }
        case TD_STRINGS: {
            strings_t *s = &out->strings;
            if (o + 4 > len) return -1; memcpy(&s->count, buf + o, 4); o += 4;
            if (s->count < 0 || s->count > V2_MAX_STRINGS) return -1;
            for (int i = 0; i < s->count; i++)
                if (bin_rd_str(buf, len, &o, s->items[i], sizeof s->items[i])) return -1;
            break;
        }
        case TD_EVENT: {
            event_t *e = &out->event;
            if (bin_rd_str(buf, len, &o, e->event_id, sizeof e->event_id)) return -1;
            if (bin_rd_str(buf, len, &o, e->event_type, sizeof e->event_type)) return -1;
            if (o + 8 > len) return -1; memcpy(&e->occurred_at, buf + o, 8); o += 8;
            if (bin_rd_str(buf, len, &o, e->producer, sizeof e->producer)) return -1;
            if (o + 4 > len) return -1; memcpy(&e->attr_count, buf + o, 4); o += 4;
            if (e->attr_count < 0 || e->attr_count > V2_MAX_ATTRS) return -1;
            for (int i = 0; i < e->attr_count; i++) {
                if (bin_rd_str(buf, len, &o, e->attrs[i].key, sizeof e->attrs[i].key)) return -1;
                if (bin_rd_str(buf, len, &o, e->attrs[i].value, sizeof e->attrs[i].value)) return -1;
            }
            break;
        }
        default: return -1;
    }
    return 0;
}

/* Shared CBOR map decoder (tinycbor) for codecs that emit standard CBOR maps. */
int bench_tinycbor_de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind);

#define BENCH_ADD(out, count, nm, ver, cat, prep, ser, de, fid) do { \
    (out)[*(count)].name = (nm); \
    (out)[*(count)].version = (ver); \
    (out)[*(count)].category = (cat); \
    (out)[*(count)].supports = supports_all; \
    (out)[*(count)].prepare = (prep); \
    (out)[*(count)].serialize = (ser); \
    (out)[*(count)].deserialize = (de); \
    (out)[*(count)].fidelity = (fid); \
    (out)[*(count)].serialize_fp = NULL; \
    (out)[*(count)].deserialize_fp = NULL; \
    (*(count))++; \
} while (0)

#endif
