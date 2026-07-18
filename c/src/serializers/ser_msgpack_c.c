#include "ser_common.h"
#include <msgpack.h>

typedef struct { uint8_t *buf; size_t cap; size_t used; int overflow; } fixed_buf_t;
static int fixed_write(void *data, const char *buf, size_t len) {
    fixed_buf_t *fb = (fixed_buf_t *)data;
    if (fb->overflow || fb->used + len > fb->cap) { fb->overflow = 1; return -1; }
    memcpy(fb->buf + fb->used, buf, len); fb->used += len; return 0;
}
static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }
static int pstr(msgpack_packer *pk, const char *s) {
    size_t n = strlen(s); return msgpack_pack_str(pk, n) || msgpack_pack_str_body(pk, s, n);
}
static int pbool(msgpack_packer *pk, int v) { return v ? msgpack_pack_true(pk) : msgpack_pack_false(pk); }

static int pack_fx(msgpack_packer *pk, const test_fixture_t *fx) {
    switch (fx->kind) {
        case TD_MESSAGE: {
            const message_t *m = &fx->message;
            if (msgpack_pack_map(pk, 8)) return -1;
            if (pstr(pk, "f_bool") || pbool(pk, m->f_bool)) return -1;
            if (pstr(pk, "f_int32") || msgpack_pack_int32(pk, m->f_int32)) return -1;
            if (pstr(pk, "f_int64") || msgpack_pack_int64(pk, m->f_int64)) return -1;
            if (pstr(pk, "f_float64") || msgpack_pack_double(pk, m->f_float64)) return -1;
            if (pstr(pk, "f_string") || pstr(pk, m->f_string)) return -1;
            if (pstr(pk, "f_bool_2") || pbool(pk, m->f_bool_2)) return -1;
            if (pstr(pk, "f_int32_2") || msgpack_pack_int32(pk, m->f_int32_2)) return -1;
            if (pstr(pk, "f_string_2") || pstr(pk, m->f_string_2)) return -1;
            return 0;
        }
        case TD_DOCUMENT: {
            const document_t *d = &fx->document;
            if (msgpack_pack_map(pk, 4)) return -1;
            if (pstr(pk, "id") || pstr(pk, d->id)) return -1;
            if (pstr(pk, "status") || msgpack_pack_int32(pk, d->status)) return -1;
            if (pstr(pk, "meta") || msgpack_pack_map(pk, 2)) return -1;
            if (pstr(pk, "region") || pstr(pk, d->meta.region)) return -1;
            if (pstr(pk, "version") || msgpack_pack_int32(pk, d->meta.version)) return -1;
            if (pstr(pk, "items") || msgpack_pack_array(pk, (size_t)d->item_count)) return -1;
            for (int i = 0; i < d->item_count; i++) {
                if (msgpack_pack_map(pk, 3)) return -1;
                if (pstr(pk, "sku") || pstr(pk, d->items[i].sku)) return -1;
                if (pstr(pk, "qty") || msgpack_pack_int32(pk, d->items[i].qty)) return -1;
                if (pstr(pk, "price_minor") || msgpack_pack_int64(pk, d->items[i].price_minor)) return -1;
            }
            return 0;
        }
        case TD_TELEMETRY: {
            const telemetry_t *t = &fx->telemetry;
            if (msgpack_pack_map(pk, 4)) return -1;
            if (pstr(pk, "source") || pstr(pk, t->source)) return -1;
            if (pstr(pk, "ts") || msgpack_pack_int64(pk, t->ts)) return -1;
            if (pstr(pk, "tags") || msgpack_pack_array(pk, (size_t)t->tag_count)) return -1;
            for (int i = 0; i < t->tag_count; i++) if (pstr(pk, t->tags[i])) return -1;
            if (pstr(pk, "values") || msgpack_pack_array(pk, (size_t)t->value_count)) return -1;
            for (int i = 0; i < t->value_count; i++) if (msgpack_pack_double(pk, t->values[i])) return -1;
            return 0;
        }
        case TD_STRINGS: {
            if (msgpack_pack_map(pk, 1)) return -1;
            if (pstr(pk, "items") || msgpack_pack_array(pk, (size_t)fx->strings.count)) return -1;
            for (int i = 0; i < fx->strings.count; i++) if (pstr(pk, fx->strings.items[i])) return -1;
            return 0;
        }
        case TD_EVENT: {
            const event_t *e = &fx->event;
            if (msgpack_pack_map(pk, 5)) return -1;
            if (pstr(pk, "event_id") || pstr(pk, e->event_id)) return -1;
            if (pstr(pk, "event_type") || pstr(pk, e->event_type)) return -1;
            if (pstr(pk, "occurred_at") || msgpack_pack_int64(pk, e->occurred_at)) return -1;
            if (pstr(pk, "producer") || pstr(pk, e->producer)) return -1;
            if (pstr(pk, "attrs") || msgpack_pack_array(pk, (size_t)e->attr_count)) return -1;
            for (int i = 0; i < e->attr_count; i++) {
                if (msgpack_pack_map(pk, 2)) return -1;
                if (pstr(pk, "key") || pstr(pk, e->attrs[i].key)) return -1;
                if (pstr(pk, "value") || pstr(pk, e->attrs[i].value)) return -1;
            }
            return 0;
        }
        default: return -1;
    }
}

static const msgpack_object *map_get(const msgpack_object *m, const char *key) {
    if (m->type != MSGPACK_OBJECT_MAP) return NULL;
    size_t kn = strlen(key);
    for (uint32_t i = 0; i < m->via.map.size; i++) {
        const msgpack_object *k = &m->via.map.ptr[i].key;
        if (k->type == MSGPACK_OBJECT_STR && k->via.str.size == kn && memcmp(k->via.str.ptr, key, kn) == 0)
            return &m->via.map.ptr[i].val;
    }
    return NULL;
}
static int cpy_str(const msgpack_object *o, char *dst, size_t dcap) {
    if (!o || o->type != MSGPACK_OBJECT_STR || o->via.str.size >= dcap) return -1;
    memcpy(dst, o->via.str.ptr, o->via.str.size); dst[o->via.str.size] = 0; return 0;
}
static int64_t as_i64(const msgpack_object *o) {
    if (!o) return 0;
    if (o->type == MSGPACK_OBJECT_POSITIVE_INTEGER) return (int64_t)o->via.u64;
    if (o->type == MSGPACK_OBJECT_NEGATIVE_INTEGER) return o->via.i64;
    return 0;
}
static double as_f64(const msgpack_object *o) {
    if (!o) return 0;
    if (o->type == MSGPACK_OBJECT_FLOAT64 || o->type == MSGPACK_OBJECT_FLOAT) return o->via.f64;
    return (double)as_i64(o);
}
static int as_bool(const msgpack_object *o) {
    return o && o->type == MSGPACK_OBJECT_BOOLEAN && o->via.boolean;
}

static int unpack_fx(const msgpack_object *root, test_fixture_t *out, test_data_kind_t kind) {
    memset(out, 0, sizeof *out);
    out->kind = kind; out->name = test_data_name(kind); out->batch_n = 1;
    switch (kind) {
        case TD_MESSAGE: {
            message_t *m = &out->message;
            m->f_bool = as_bool(map_get(root, "f_bool"));
            m->f_int32 = (int32_t)as_i64(map_get(root, "f_int32"));
            m->f_int64 = as_i64(map_get(root, "f_int64"));
            m->f_float64 = as_f64(map_get(root, "f_float64"));
            cpy_str(map_get(root, "f_string"), m->f_string, sizeof m->f_string);
            m->f_bool_2 = as_bool(map_get(root, "f_bool_2"));
            m->f_int32_2 = (int32_t)as_i64(map_get(root, "f_int32_2"));
            cpy_str(map_get(root, "f_string_2"), m->f_string_2, sizeof m->f_string_2);
            break;
        }
        case TD_DOCUMENT: {
            document_t *d = &out->document;
            cpy_str(map_get(root, "id"), d->id, sizeof d->id);
            d->status = (int32_t)as_i64(map_get(root, "status"));
            const msgpack_object *meta = map_get(root, "meta");
            if (meta) {
                cpy_str(map_get(meta, "region"), d->meta.region, sizeof d->meta.region);
                d->meta.version = (int32_t)as_i64(map_get(meta, "version"));
            }
            const msgpack_object *items = map_get(root, "items");
            if (items && items->type == MSGPACK_OBJECT_ARRAY) {
                int n = (int)items->via.array.size; if (n > V2_MAX_CHILDREN) n = V2_MAX_CHILDREN;
                d->item_count = n;
                for (int i = 0; i < n; i++) {
                    const msgpack_object *it = &items->via.array.ptr[i];
                    cpy_str(map_get(it, "sku"), d->items[i].sku, sizeof d->items[i].sku);
                    d->items[i].qty = (int32_t)as_i64(map_get(it, "qty"));
                    d->items[i].price_minor = as_i64(map_get(it, "price_minor"));
                }
            }
            break;
        }
        case TD_TELEMETRY: {
            telemetry_t *t = &out->telemetry;
            cpy_str(map_get(root, "source"), t->source, sizeof t->source);
            t->ts = as_i64(map_get(root, "ts"));
            const msgpack_object *tags = map_get(root, "tags");
            if (tags && tags->type == MSGPACK_OBJECT_ARRAY) {
                int n = (int)tags->via.array.size; if (n > V2_MAX_TAGS) n = V2_MAX_TAGS;
                t->tag_count = n;
                for (int i = 0; i < n; i++) cpy_str(&tags->via.array.ptr[i], t->tags[i], sizeof t->tags[i]);
            }
            const msgpack_object *vals = map_get(root, "values");
            if (vals && vals->type == MSGPACK_OBJECT_ARRAY) {
                int n = (int)vals->via.array.size; if (n > V2_MAX_POINTS) n = V2_MAX_POINTS;
                t->value_count = n;
                for (int i = 0; i < n; i++) t->values[i] = as_f64(&vals->via.array.ptr[i]);
            }
            break;
        }
        case TD_STRINGS: {
            const msgpack_object *items = map_get(root, "items");
            if (items && items->type == MSGPACK_OBJECT_ARRAY) {
                int n = (int)items->via.array.size; if (n > V2_MAX_STRINGS) n = V2_MAX_STRINGS;
                out->strings.count = n;
                for (int i = 0; i < n; i++) cpy_str(&items->via.array.ptr[i], out->strings.items[i], sizeof out->strings.items[i]);
            }
            break;
        }
        case TD_EVENT: {
            event_t *e = &out->event;
            cpy_str(map_get(root, "event_id"), e->event_id, sizeof e->event_id);
            cpy_str(map_get(root, "event_type"), e->event_type, sizeof e->event_type);
            e->occurred_at = as_i64(map_get(root, "occurred_at"));
            cpy_str(map_get(root, "producer"), e->producer, sizeof e->producer);
            const msgpack_object *attrs = map_get(root, "attrs");
            if (attrs && attrs->type == MSGPACK_OBJECT_ARRAY) {
                int n = (int)attrs->via.array.size; if (n > V2_MAX_ATTRS) n = V2_MAX_ATTRS;
                e->attr_count = n;
                for (int i = 0; i < n; i++) {
                    const msgpack_object *a = &attrs->via.array.ptr[i];
                    cpy_str(map_get(a, "key"), e->attrs[i].key, sizeof e->attrs[i].key);
                    cpy_str(map_get(a, "value"), e->attrs[i].value, sizeof e->attrs[i].value);
                }
            }
            break;
        }
        default: return -1;
    }
    return 0;
}

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    fixed_buf_t fb = { buf, cap, 0, 0 };
    msgpack_packer pk;
    msgpack_packer_init(&pk, &fb, fixed_write);
    if (pack_fx(&pk, fx) || fb.overflow) return -1;
    *ol = fb.used;
    return 0;
}
static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    msgpack_unpacked result;
    msgpack_unpacked_init(&result);
    size_t off = 0;
    if (msgpack_unpack_next(&result, (const char *)buf, len, &off) != MSGPACK_UNPACK_SUCCESS) {
        msgpack_unpacked_destroy(&result); return -1;
    }
    int rc = unpack_fx(&result.data, out, kind);
    msgpack_unpacked_destroy(&result);
    return rc;
}
void bench_register_msgpack_c(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "msgpack-c", "6.0.1", "binary", prep, ser, de, fidelity_fx);
}
