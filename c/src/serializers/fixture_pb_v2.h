#ifndef FIXTURE_PB_V2_H
#define FIXTURE_PB_V2_H
/* Standard proto3 field tags matching schemas/v2/protobuf/benchmark_v2.proto */
#include "ser_common.h"
#include <string.h>

static inline size_t pb_varint(uint8_t *b, uint64_t v) {
    size_t n = 0;
    while (v >= 0x80) { b[n++] = (uint8_t)((v & 0x7f) | 0x80); v >>= 7; }
    b[n++] = (uint8_t)v;
    return n;
}
static inline int pb_put(uint8_t *buf, size_t cap, size_t *o, const uint8_t *p, size_t n) {
    if (*o + n > cap) return -1; memcpy(buf + *o, p, n); *o += n; return 0;
}
static inline int pb_tag_varint(uint8_t *buf, size_t cap, size_t *o, uint32_t field, uint64_t v) {
    if (v == 0) return 0;
    uint8_t t[20]; size_t n = pb_varint(t, ((uint64_t)field << 3) | 0); n += pb_varint(t + n, v);
    return pb_put(buf, cap, o, t, n);
}
static inline int pb_tag_bool(uint8_t *buf, size_t cap, size_t *o, uint32_t field, int v) {
    return v ? pb_tag_varint(buf, cap, o, field, 1) : 0;
}
static inline int pb_tag_f64(uint8_t *buf, size_t cap, size_t *o, uint32_t field, double v) {
    if (v == 0.0) return 0;
    uint8_t t[12]; size_t n = pb_varint(t, ((uint64_t)field << 3) | 1);
    if (*o + n + 8 > cap) return -1;
    memcpy(buf + *o, t, n); *o += n; memcpy(buf + *o, &v, 8); *o += 8; return 0;
}
static inline int pb_tag_str(uint8_t *buf, size_t cap, size_t *o, uint32_t field, const char *s) {
    size_t len = strlen(s); if (!len) return 0;
    uint8_t t[20]; size_t n = pb_varint(t, ((uint64_t)field << 3) | 2); n += pb_varint(t + n, len);
    if (*o + n + len > cap) return -1;
    memcpy(buf + *o, t, n); *o += n; memcpy(buf + *o, s, len); *o += len; return 0;
}
static inline int pb_tag_sub(uint8_t *buf, size_t cap, size_t *o, uint32_t field, const uint8_t *inner, size_t ilen) {
    if (!ilen) return 0;
    uint8_t t[20]; size_t n = pb_varint(t, ((uint64_t)field << 3) | 2); n += pb_varint(t + n, ilen);
    if (*o + n + ilen > cap) return -1;
    memcpy(buf + *o, t, n); *o += n; memcpy(buf + *o, inner, ilen); *o += ilen; return 0;
}

static inline int pb_enc_message(const message_t *m, uint8_t *buf, size_t cap, size_t *ol) {
    size_t o = 0;
    if (pb_tag_bool(buf, cap, &o, 1, m->f_bool)) return -1;
    if (pb_tag_varint(buf, cap, &o, 2, (uint64_t)(uint32_t)m->f_int32)) return -1;
    if (pb_tag_varint(buf, cap, &o, 3, (uint64_t)m->f_int64)) return -1;
    if (pb_tag_f64(buf, cap, &o, 4, m->f_float64)) return -1;
    if (pb_tag_str(buf, cap, &o, 5, m->f_string)) return -1;
    if (pb_tag_bool(buf, cap, &o, 6, m->f_bool_2)) return -1;
    if (pb_tag_varint(buf, cap, &o, 7, (uint64_t)(uint32_t)m->f_int32_2)) return -1;
    if (pb_tag_str(buf, cap, &o, 8, m->f_string_2)) return -1;
    *ol = o; return 0;
}
static inline int pb_enc_document(const document_t *d, uint8_t *buf, size_t cap, size_t *ol) {
    size_t o = 0;
    if (pb_tag_str(buf, cap, &o, 1, d->id)) return -1;
    if (pb_tag_varint(buf, cap, &o, 2, (uint64_t)(uint32_t)d->status)) return -1;
    { uint8_t inner[128]; size_t io = 0;
      if (pb_tag_str(inner, sizeof inner, &io, 1, d->meta.region)) return -1;
      if (pb_tag_varint(inner, sizeof inner, &io, 2, (uint64_t)(uint32_t)d->meta.version)) return -1;
      if (pb_tag_sub(buf, cap, &o, 3, inner, io)) return -1;
    }
    for (int i = 0; i < d->item_count; i++) {
        uint8_t inner[128]; size_t io = 0;
        if (pb_tag_str(inner, sizeof inner, &io, 1, d->items[i].sku)) return -1;
        if (pb_tag_varint(inner, sizeof inner, &io, 2, (uint64_t)(uint32_t)d->items[i].qty)) return -1;
        if (pb_tag_varint(inner, sizeof inner, &io, 3, (uint64_t)d->items[i].price_minor)) return -1;
        if (pb_tag_sub(buf, cap, &o, 4, inner, io)) return -1;
    }
    *ol = o; return 0;
}
static inline int pb_enc_telemetry(const telemetry_t *t, uint8_t *buf, size_t cap, size_t *ol) {
    size_t o = 0;
    if (pb_tag_str(buf, cap, &o, 1, t->source)) return -1;
    if (pb_tag_varint(buf, cap, &o, 2, (uint64_t)t->ts)) return -1;
    for (int i = 0; i < t->tag_count; i++) if (pb_tag_str(buf, cap, &o, 3, t->tags[i])) return -1;
    for (int i = 0; i < t->value_count; i++) if (pb_tag_f64(buf, cap, &o, 4, t->values[i])) return -1;
    *ol = o; return 0;
}
static inline int pb_enc_strings(const strings_t *s, uint8_t *buf, size_t cap, size_t *ol) {
    size_t o = 0;
    for (int i = 0; i < s->count; i++) if (pb_tag_str(buf, cap, &o, 1, s->items[i])) return -1;
    *ol = o; return 0;
}
static inline int pb_enc_event(const event_t *e, uint8_t *buf, size_t cap, size_t *ol) {
    size_t o = 0;
    if (pb_tag_str(buf, cap, &o, 1, e->event_id)) return -1;
    if (pb_tag_str(buf, cap, &o, 2, e->event_type)) return -1;
    if (pb_tag_varint(buf, cap, &o, 3, (uint64_t)e->occurred_at)) return -1;
    if (pb_tag_str(buf, cap, &o, 4, e->producer)) return -1;
    for (int i = 0; i < e->attr_count; i++) {
        uint8_t inner[128]; size_t io = 0;
        if (pb_tag_str(inner, sizeof inner, &io, 1, e->attrs[i].key)) return -1;
        if (pb_tag_str(inner, sizeof inner, &io, 2, e->attrs[i].value)) return -1;
        if (pb_tag_sub(buf, cap, &o, 5, inner, io)) return -1;
    }
    *ol = o; return 0;
}

static inline int pb_v2_encode(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    switch (fx->kind) {
        case TD_MESSAGE: return pb_enc_message(&fx->message, buf, cap, ol);
        case TD_DOCUMENT: return pb_enc_document(&fx->document, buf, cap, ol);
        case TD_TELEMETRY: return pb_enc_telemetry(&fx->telemetry, buf, cap, ol);
        case TD_STRINGS: return pb_enc_strings(&fx->strings, buf, cap, ol);
        case TD_EVENT: return pb_enc_event(&fx->event, buf, cap, ol);
        default: return -1;
    }
}

/* Generic proto3 decoder for suite V2 messages */
static inline int pb_rd_varint(const uint8_t *buf, size_t len, size_t *o, uint64_t *out) {
    uint64_t v = 0; int shift = 0;
    while (*o < len) {
        uint8_t b = buf[(*o)++];
        v |= (uint64_t)(b & 0x7f) << shift;
        if ((b & 0x80) == 0) { *out = v; return 0; }
        shift += 7; if (shift > 63) return -1;
    }
    return -1;
}
static inline int pb_skip(const uint8_t *buf, size_t len, size_t *o, uint32_t wt) {
    uint64_t n;
    switch (wt) {
        case 0: return pb_rd_varint(buf, len, o, &n);
        case 1: if (*o + 8 > len) return -1; *o += 8; return 0;
        case 2: if (pb_rd_varint(buf, len, o, &n)) return -1; if (*o + n > len) return -1; *o += (size_t)n; return 0;
        case 5: if (*o + 4 > len) return -1; *o += 4; return 0;
        default: return -1;
    }
}
static inline int pb_rd_str(const uint8_t *buf, size_t len, size_t *o, char *dst, size_t dcap) {
    uint64_t n; if (pb_rd_varint(buf, len, o, &n)) return -1;
    if (*o + n > len || n >= dcap) return -1;
    memcpy(dst, buf + *o, (size_t)n); dst[n] = 0; *o += (size_t)n; return 0;
}

static inline int pb_dec_message(const uint8_t *buf, size_t len, message_t *m) {
    memset(m, 0, sizeof *m);
    size_t o = 0;
    while (o < len) {
        uint64_t key; if (pb_rd_varint(buf, len, &o, &key)) return -1;
        uint32_t field = (uint32_t)(key >> 3), wt = (uint32_t)(key & 7);
        if (field == 1 && wt == 0) { uint64_t v; if (pb_rd_varint(buf, len, &o, &v)) return -1; m->f_bool = v != 0; }
        else if (field == 2 && wt == 0) { uint64_t v; if (pb_rd_varint(buf, len, &o, &v)) return -1; m->f_int32 = (int32_t)v; }
        else if (field == 3 && wt == 0) { uint64_t v; if (pb_rd_varint(buf, len, &o, &v)) return -1; m->f_int64 = (int64_t)v; }
        else if (field == 4 && wt == 1) { if (o + 8 > len) return -1; memcpy(&m->f_float64, buf + o, 8); o += 8; }
        else if (field == 5 && wt == 2) { if (pb_rd_str(buf, len, &o, m->f_string, sizeof m->f_string)) return -1; }
        else if (field == 6 && wt == 0) { uint64_t v; if (pb_rd_varint(buf, len, &o, &v)) return -1; m->f_bool_2 = v != 0; }
        else if (field == 7 && wt == 0) { uint64_t v; if (pb_rd_varint(buf, len, &o, &v)) return -1; m->f_int32_2 = (int32_t)v; }
        else if (field == 8 && wt == 2) { if (pb_rd_str(buf, len, &o, m->f_string_2, sizeof m->f_string_2)) return -1; }
        else if (pb_skip(buf, len, &o, wt)) return -1;
    }
    return 0;
}
static inline int pb_dec_document(const uint8_t *buf, size_t len, document_t *d) {
    memset(d, 0, sizeof *d);
    size_t o = 0;
    while (o < len) {
        uint64_t key; if (pb_rd_varint(buf, len, &o, &key)) return -1;
        uint32_t field = (uint32_t)(key >> 3), wt = (uint32_t)(key & 7);
        if (field == 1 && wt == 2) { if (pb_rd_str(buf, len, &o, d->id, sizeof d->id)) return -1; }
        else if (field == 2 && wt == 0) { uint64_t v; if (pb_rd_varint(buf, len, &o, &v)) return -1; d->status = (int32_t)v; }
        else if (field == 3 && wt == 2) {
            uint64_t n; if (pb_rd_varint(buf, len, &o, &n)) return -1;
            size_t end = o + (size_t)n; if (end > len) return -1;
            while (o < end) {
                uint64_t k2; if (pb_rd_varint(buf, len, &o, &k2)) return -1;
                uint32_t f2 = (uint32_t)(k2 >> 3), w2 = (uint32_t)(k2 & 7);
                if (f2 == 1 && w2 == 2) { if (pb_rd_str(buf, len, &o, d->meta.region, sizeof d->meta.region)) return -1; }
                else if (f2 == 2 && w2 == 0) { uint64_t v; if (pb_rd_varint(buf, len, &o, &v)) return -1; d->meta.version = (int32_t)v; }
                else if (pb_skip(buf, len, &o, w2)) return -1;
            }
        } else if (field == 4 && wt == 2) {
            if (d->item_count >= V2_MAX_CHILDREN) { if (pb_skip(buf, len, &o, wt)) return -1; continue; }
            int i = d->item_count++;
            uint64_t n; if (pb_rd_varint(buf, len, &o, &n)) return -1;
            size_t end = o + (size_t)n; if (end > len) return -1;
            while (o < end) {
                uint64_t k2; if (pb_rd_varint(buf, len, &o, &k2)) return -1;
                uint32_t f2 = (uint32_t)(k2 >> 3), w2 = (uint32_t)(k2 & 7);
                if (f2 == 1 && w2 == 2) { if (pb_rd_str(buf, len, &o, d->items[i].sku, sizeof d->items[i].sku)) return -1; }
                else if (f2 == 2 && w2 == 0) { uint64_t v; if (pb_rd_varint(buf, len, &o, &v)) return -1; d->items[i].qty = (int32_t)v; }
                else if (f2 == 3 && w2 == 0) { uint64_t v; if (pb_rd_varint(buf, len, &o, &v)) return -1; d->items[i].price_minor = (int64_t)v; }
                else if (pb_skip(buf, len, &o, w2)) return -1;
            }
        } else if (pb_skip(buf, len, &o, wt)) return -1;
    }
    return 0;
}
static inline int pb_dec_telemetry(const uint8_t *buf, size_t len, telemetry_t *t) {
    memset(t, 0, sizeof *t);
    size_t o = 0;
    while (o < len) {
        uint64_t key; if (pb_rd_varint(buf, len, &o, &key)) return -1;
        uint32_t field = (uint32_t)(key >> 3), wt = (uint32_t)(key & 7);
        if (field == 1 && wt == 2) { if (pb_rd_str(buf, len, &o, t->source, sizeof t->source)) return -1; }
        else if (field == 2 && wt == 0) { uint64_t v; if (pb_rd_varint(buf, len, &o, &v)) return -1; t->ts = (int64_t)v; }
        else if (field == 3 && wt == 2) {
            if (t->tag_count >= V2_MAX_TAGS) { if (pb_skip(buf, len, &o, wt)) return -1; continue; }
            if (pb_rd_str(buf, len, &o, t->tags[t->tag_count], sizeof t->tags[0])) return -1;
            t->tag_count++;
        } else if (field == 4 && wt == 1) {
            if (t->value_count >= V2_MAX_POINTS) { o += 8; continue; }
            if (o + 8 > len) return -1; memcpy(&t->values[t->value_count++], buf + o, 8); o += 8;
        } else if (pb_skip(buf, len, &o, wt)) return -1;
    }
    return 0;
}
static inline int pb_dec_strings(const uint8_t *buf, size_t len, strings_t *s) {
    memset(s, 0, sizeof *s);
    size_t o = 0;
    while (o < len) {
        uint64_t key; if (pb_rd_varint(buf, len, &o, &key)) return -1;
        uint32_t field = (uint32_t)(key >> 3), wt = (uint32_t)(key & 7);
        if (field == 1 && wt == 2) {
            if (s->count >= V2_MAX_STRINGS) { if (pb_skip(buf, len, &o, wt)) return -1; continue; }
            if (pb_rd_str(buf, len, &o, s->items[s->count], sizeof s->items[0])) return -1;
            s->count++;
        } else if (pb_skip(buf, len, &o, wt)) return -1;
    }
    return 0;
}
static inline int pb_dec_event(const uint8_t *buf, size_t len, event_t *e) {
    memset(e, 0, sizeof *e);
    size_t o = 0;
    while (o < len) {
        uint64_t key; if (pb_rd_varint(buf, len, &o, &key)) return -1;
        uint32_t field = (uint32_t)(key >> 3), wt = (uint32_t)(key & 7);
        if (field == 1 && wt == 2) { if (pb_rd_str(buf, len, &o, e->event_id, sizeof e->event_id)) return -1; }
        else if (field == 2 && wt == 2) { if (pb_rd_str(buf, len, &o, e->event_type, sizeof e->event_type)) return -1; }
        else if (field == 3 && wt == 0) { uint64_t v; if (pb_rd_varint(buf, len, &o, &v)) return -1; e->occurred_at = (int64_t)v; }
        else if (field == 4 && wt == 2) { if (pb_rd_str(buf, len, &o, e->producer, sizeof e->producer)) return -1; }
        else if (field == 5 && wt == 2) {
            if (e->attr_count >= V2_MAX_ATTRS) { if (pb_skip(buf, len, &o, wt)) return -1; continue; }
            int i = e->attr_count++;
            uint64_t n; if (pb_rd_varint(buf, len, &o, &n)) return -1;
            size_t end = o + (size_t)n; if (end > len) return -1;
            while (o < end) {
                uint64_t k2; if (pb_rd_varint(buf, len, &o, &k2)) return -1;
                uint32_t f2 = (uint32_t)(k2 >> 3), w2 = (uint32_t)(k2 & 7);
                if (f2 == 1 && w2 == 2) { if (pb_rd_str(buf, len, &o, e->attrs[i].key, sizeof e->attrs[i].key)) return -1; }
                else if (f2 == 2 && w2 == 2) { if (pb_rd_str(buf, len, &o, e->attrs[i].value, sizeof e->attrs[i].value)) return -1; }
                else if (pb_skip(buf, len, &o, w2)) return -1;
            }
        } else if (pb_skip(buf, len, &o, wt)) return -1;
    }
    return 0;
}

static inline int pb_v2_decode(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    memset(out, 0, sizeof *out);
    out->kind = kind;
    out->name = test_data_name(kind);
    out->batch_n = 1;
    switch (kind) {
        case TD_MESSAGE: return pb_dec_message(buf, len, &out->message);
        case TD_DOCUMENT: return pb_dec_document(buf, len, &out->document);
        case TD_TELEMETRY: return pb_dec_telemetry(buf, len, &out->telemetry);
        case TD_STRINGS: return pb_dec_strings(buf, len, &out->strings);
        case TD_EVENT: return pb_dec_event(buf, len, &out->event);
        default: return -1;
    }
}
#endif
