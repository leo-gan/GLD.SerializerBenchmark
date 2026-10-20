#include "ser_common.h"
#include <kiln.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#if defined(__BYTE_ORDER__) && __BYTE_ORDER__ != __ORDER_LITTLE_ENDIAN__
#error "kiln bulk f32/i64 lists use host bytes and require little-endian"
#endif

/* gld-kiln positional wire. Schemas are static (no names on the wire).
 * prepare binds one struct, or a list of that struct when N>1.
 * Encode fills a reused value pool and kiln_encode_buf. Decode reuses one doc.
 * https://github.com/leo-gan/gld-kiln-c
 * https://leo-gan.github.io/gld-kiln/spec/
 */

static const kiln_schema SCH_BOOL = {KILN_BOOL, NULL, NULL, 0};
static const kiln_schema SCH_I32 = {KILN_I32, NULL, NULL, 0};
static const kiln_schema SCH_I64 = {KILN_I64, NULL, NULL, 0};
static const kiln_schema SCH_F32 = {KILN_F32, NULL, NULL, 0};
static const kiln_schema SCH_F64 = {KILN_F64, NULL, NULL, 0};
static const kiln_schema SCH_STR = {KILN_STR, NULL, NULL, 0};
static const kiln_schema SCH_LIST_STR = {KILN_LIST, &SCH_STR, NULL, 0};
static const kiln_schema SCH_LIST_F32 = {KILN_LIST, &SCH_F32, NULL, 0};
static const kiln_schema SCH_LIST_F64 = {KILN_LIST, &SCH_F64, NULL, 0};
static const kiln_schema SCH_LIST_I64 = {KILN_LIST, &SCH_I64, NULL, 0};

static const kiln_field META_FIELDS[] = {
    {"region", &SCH_STR},
    {"version", &SCH_I32},
};
static const kiln_schema SCH_META = {KILN_STRUCT, NULL, META_FIELDS, 2};

static const kiln_field ITEM_FIELDS[] = {
    {"sku", &SCH_STR},
    {"qty", &SCH_I32},
    {"price_minor", &SCH_I64},
};
static const kiln_schema SCH_ITEM = {KILN_STRUCT, NULL, ITEM_FIELDS, 3};
static const kiln_schema SCH_LIST_ITEM = {KILN_LIST, &SCH_ITEM, NULL, 0};

static const kiln_field DOC_FIELDS[] = {
    {"id", &SCH_STR},
    {"status", &SCH_I32},
    {"meta", &SCH_META},
    {"items", &SCH_LIST_ITEM},
};
static const kiln_schema SCH_DOCUMENT = {KILN_STRUCT, NULL, DOC_FIELDS, 4};
static const kiln_schema SCH_DOCUMENT_LIST = {KILN_LIST, &SCH_DOCUMENT, NULL, 0};

static const kiln_field MSG_FIELDS[] = {
    {"f_bool", &SCH_BOOL},
    {"f_int32", &SCH_I32},
    {"f_int64", &SCH_I64},
    {"f_float64", &SCH_F64},
    {"f_string", &SCH_STR},
    {"f_bool_2", &SCH_BOOL},
    {"f_int32_2", &SCH_I32},
    {"f_string_2", &SCH_STR},
};
static const kiln_schema SCH_MESSAGE = {KILN_STRUCT, NULL, MSG_FIELDS, 8};
static const kiln_schema SCH_MESSAGE_LIST = {KILN_LIST, &SCH_MESSAGE, NULL, 0};

static const kiln_field TEL_FIELDS[] = {
    {"source", &SCH_STR},
    {"ts", &SCH_I64},
    {"tags", &SCH_LIST_STR},
    {"values", &SCH_LIST_F64},
};
static const kiln_schema SCH_TELEMETRY = {KILN_STRUCT, NULL, TEL_FIELDS, 4};
static const kiln_schema SCH_TELEMETRY_LIST = {KILN_LIST, &SCH_TELEMETRY, NULL, 0};

static const kiln_field STR_FIELDS[] = {
    {"items", &SCH_LIST_STR},
};
static const kiln_schema SCH_STRINGS = {KILN_STRUCT, NULL, STR_FIELDS, 1};
static const kiln_schema SCH_STRINGS_LIST = {KILN_LIST, &SCH_STRINGS, NULL, 0};

static const kiln_field ATTR_FIELDS[] = {
    {"key", &SCH_STR},
    {"value", &SCH_STR},
};
static const kiln_schema SCH_ATTR = {KILN_STRUCT, NULL, ATTR_FIELDS, 2};
static const kiln_schema SCH_LIST_ATTR = {KILN_LIST, &SCH_ATTR, NULL, 0};

static const kiln_field EV_FIELDS[] = {
    {"event_id", &SCH_STR},
    {"event_type", &SCH_STR},
    {"occurred_at", &SCH_I64},
    {"producer", &SCH_STR},
    {"attrs", &SCH_LIST_ATTR},
};
static const kiln_schema SCH_EVENT = {KILN_STRUCT, NULL, EV_FIELDS, 5};
static const kiln_schema SCH_EVENT_LIST = {KILN_LIST, &SCH_EVENT, NULL, 0};

/* Same field order as Mojo TensorValue / PromptValue / ShardValue / RequestValue. */
static const kiln_field TENSOR_FIELDS[] = {
    {"rows", &SCH_I32},
    {"cols", &SCH_I32},
    {"values", &SCH_LIST_F32},
};
static const kiln_schema SCH_TENSOR = {KILN_STRUCT, NULL, TENSOR_FIELDS, 3};

static const kiln_field PROMPT_FIELDS[] = {
    {"batch", &SCH_I32},
    {"seq", &SCH_I32},
    {"input_ids", &SCH_LIST_I64},
    {"attention_mask", &SCH_LIST_I64},
    {"position_ids", &SCH_LIST_I64},
};
static const kiln_schema SCH_PROMPT = {KILN_STRUCT, NULL, PROMPT_FIELDS, 5};

static const kiln_field SHARD_FIELDS[] = {
    {"vocab", &SCH_I32},
    {"hidden", &SCH_I32},
    {"ffn", &SCH_I32},
    {"tok_emb", &SCH_LIST_F32},
    {"attn", &SCH_LIST_F32},
    {"ffn_weight", &SCH_LIST_F32},
    {"norm", &SCH_LIST_F32},
};
static const kiln_schema SCH_SHARD = {KILN_STRUCT, NULL, SHARD_FIELDS, 7};

static const kiln_field REQUEST_FIELDS[] = {
    {"request_id", &SCH_I64},
    {"model", &SCH_STR},
    {"temperature", &SCH_F32},
    {"inputs", &SCH_PROMPT},
};
static const kiln_schema SCH_REQUEST = {KILN_STRUCT, NULL, REQUEST_FIELDS, 4};

typedef int (*kiln_write_fn)(const test_fixture_t *fx, kiln_value *out);
typedef int (*kiln_read_fn)(const kiln_value *v, test_fixture_t *out);

static const kiln_schema *g_schema;
static kiln_write_fn g_write;
static kiln_read_fn g_read;
static kiln_buf g_buf;
static kiln_doc *g_doc;

static kiln_value *g_pool;
static size_t g_pool_used;
static size_t g_pool_cap;

static uint8_t *g_f64;
static size_t g_f64_used;
static size_t g_f64_cap;

static int pool_reserve(size_t n) {
    kiln_value *p;
    if (g_pool_cap >= n) return 0;
    p = (kiln_value *)realloc(g_pool, n * sizeof(kiln_value));
    if (!p) return -1;
    g_pool = p;
    g_pool_cap = n;
    return 0;
}

/* Pointers into the pool must stay valid for the rest of the encode. */
static kiln_value *pool_alloc(size_t n) {
    kiln_value *out;
    if (n == 0) return NULL;
    if (g_pool_used + n > g_pool_cap) return NULL;
    out = g_pool + g_pool_used;
    memset(out, 0, n * sizeof(kiln_value));
    g_pool_used += n;
    return out;
}

static void set_bool(kiln_value *v, bool b) {
    v->kind = KILN_BOOL;
    v->as.b = b ? 1 : 0;
}

static void set_i32(kiln_value *v, int32_t x) {
    v->kind = KILN_I32;
    v->as.i64 = x;
}

static void set_i64(kiln_value *v, int64_t x) {
    v->kind = KILN_I64;
    v->as.i64 = x;
}

static void set_f64(kiln_value *v, double x) {
    v->kind = KILN_F64;
    memcpy(&v->as.f64_bits, &x, 8);
}

static void set_f32(kiln_value *v, float x) {
    uint32_t bits;
    v->kind = KILN_F32;
    memcpy(&bits, &x, 4);
    v->as.f32_bits = bits;
}

static void set_str(kiln_value *v, const char *s) {
    v->kind = KILN_STR;
    v->as.bytes.ptr = (const uint8_t *)(s ? s : "");
    v->as.bytes.len = s ? strlen(s) : 0;
}

static void set_struct(kiln_value *v, kiln_value *fields, size_t n) {
    v->kind = KILN_STRUCT;
    v->as.strukt.fields = fields;
    v->as.strukt.count = n;
}

static void set_list(kiln_value *v, kiln_value *items, size_t n) {
    v->kind = KILN_LIST;
    v->as.list.items = items;
    v->as.list.count = n;
}

static int fill_str_list(kiln_value *dst, const char (*items)[V2_STR], int count) {
    kiln_value *els = NULL;
    int i;
    if (count < 0) return -1;
    if (count) {
        els = pool_alloc((size_t)count);
        if (!els) return -1;
        for (i = 0; i < count; i++) set_str(&els[i], items[i]);
    }
    set_list(dst, els, (size_t)count);
    return 0;
}

static int f64_reserve(size_t n) {
    uint8_t *p;
    if (g_f64_cap >= n) return 0;
    p = (uint8_t *)realloc(g_f64, n ? n : 1);
    if (!p) return -1;
    g_f64 = p;
    g_f64_cap = n ? n : 1;
    return 0;
}

static int fill_f64_list(kiln_value *dst, const double *src, int count) {
    size_t nbytes;
    uint8_t *raw;
    int i;
    if (count < 0) return -1;
    nbytes = (size_t)count * 8u;
    if (g_f64_used + nbytes > g_f64_cap) return -1;
    raw = g_f64 + g_f64_used;
    for (i = 0; i < count; i++) kiln_store_f64(raw + (size_t)i * 8u, src[i]);
    g_f64_used += nbytes;
    memset(dst, 0, sizeof(*dst));
    dst->kind = KILN_LIST;
    dst->as.list.count = (size_t)count;
    dst->as.list.bulk = 1;
    dst->as.list.elem_size = 8;
    dst->as.list.raw = count ? raw : NULL;
    return 0;
}

static const kiln_value *field_at(const kiln_value *v, size_t i) {
    if (!v || v->kind != KILN_STRUCT || !v->as.strukt.fields || i >= v->as.strukt.count)
        return NULL;
    return &v->as.strukt.fields[i];
}

static int copy_str(char *dst, size_t cap, const kiln_value *v) {
    if (!v || v->kind != KILN_STR || v->as.bytes.len >= cap) return -1;
    if (v->as.bytes.len) {
        if (!v->as.bytes.ptr) return -1;
        memcpy(dst, v->as.bytes.ptr, v->as.bytes.len);
    }
    dst[v->as.bytes.len] = 0;
    return 0;
}

static int read_bool(const kiln_value *v, bool *out) {
    if (!v || v->kind != KILN_BOOL) return -1;
    *out = v->as.b != 0;
    return 0;
}

static int read_i32(const kiln_value *v, int32_t *out) {
    if (!v || v->kind != KILN_I32) return -1;
    *out = (int32_t)v->as.i64;
    return 0;
}

static int read_i64(const kiln_value *v, int64_t *out) {
    if (!v || v->kind != KILN_I64) return -1;
    *out = v->as.i64;
    return 0;
}

static int read_f64(const kiln_value *v, double *out) {
    if (!v || v->kind != KILN_F64) return -1;
    memcpy(out, &v->as.f64_bits, 8);
    return 0;
}

static int read_f32(const kiln_value *v, float *out) {
    if (!v || v->kind != KILN_F32) return -1;
    memcpy(out, &v->as.f32_bits, 4);
    return 0;
}

/* Host is little-endian, so float32 and int64 memory is the wire image. */
static int fill_bulk(kiln_value *dst, const void *src, size_t count, size_t elem) {
    if (count && !src) return -1;
    memset(dst, 0, sizeof(*dst));
    dst->kind = KILN_LIST;
    dst->as.list.count = count;
    dst->as.list.bulk = 1;
    dst->as.list.elem_size = elem;
    dst->as.list.raw = count ? (const uint8_t *)src : NULL;
    return 0;
}

static int prod_int(int a, int b, int *out) {
    long long n;
    if (a < 0 || b < 0) return -1;
    n = (long long)a * (long long)b;
    if (n > 0x7fffffffLL) return -1;
    *out = (int)n;
    return 0;
}

/* copy == 0 borrows the payload. copy == 1 owns a new float32 buffer. */
static int take_f32_list(const kiln_value *v, float **dst, int *n_out, int expect, int copy) {
    size_t n;
    float *p;
    if (!v || v->kind != KILN_LIST || !v->as.list.bulk || v->as.list.elem_size != 4) return -1;
    n = v->as.list.count;
    if (expect >= 0 && n != (size_t)expect) return -1;
    if (n > 0x7fffffffU) return -1;
    if (n && !v->as.list.raw) return -1;
    if (!copy || n == 0) {
        *dst = (n && !copy) ? (float *)(uintptr_t)v->as.list.raw : NULL;
        *n_out = (int)n;
        return 0;
    }
    p = (float *)malloc(n * 4u);
    if (!p) return -1;
    memcpy(p, v->as.list.raw, n * 4u);
    *dst = p;
    *n_out = (int)n;
    return 0;
}

static int take_i64_list(const kiln_value *v, int64_t **dst, int expect) {
    size_t n;
    int64_t *p;
    if (!v || v->kind != KILN_LIST || !v->as.list.bulk || v->as.list.elem_size != 8) return -1;
    n = v->as.list.count;
    if (n != (size_t)expect) return -1;
    if (!n) {
        *dst = NULL;
        return 0;
    }
    if (!v->as.list.raw) return -1;
    p = (int64_t *)malloc(n * 8u);
    if (!p) return -1;
    memcpy(p, v->as.list.raw, n * 8u);
    *dst = p;
    return 0;
}

/* expect < 0 skips the count check. Bulk lists (f64) are rejected here. */
static int list_items(const kiln_value *v, const kiln_value **items, int *n, int expect) {
    size_t count;
    if (!v || v->kind != KILN_LIST || v->as.list.bulk) return -1;
    count = v->as.list.count;
    if (count > 1000000u) return -1;
    if (expect >= 0 && (int)count != expect) return -1;
    if (count && !v->as.list.items) return -1;
    *items = v->as.list.items;
    *n = (int)count;
    return 0;
}

static int read_f64_list(const kiln_value *v, double *dst, int *count, int maxn) {
    int n;
    int i;
    if (!v || v->kind != KILN_LIST) return -1;
    if (v->as.list.count > (size_t)maxn) return -1;
    n = (int)v->as.list.count;
    if (v->as.list.bulk) {
        if (n && (v->as.list.elem_size != 8 || !v->as.list.raw)) return -1;
        for (i = 0; i < n; i++) dst[i] = kiln_load_f64(v->as.list.raw + (size_t)i * 8u);
    } else {
        if (n && !v->as.list.items) return -1;
        for (i = 0; i < n; i++)
            if (read_f64(&v->as.list.items[i], &dst[i])) return -1;
    }
    *count = n;
    return 0;
}

static int read_str_list(const kiln_value *v, char (*dst)[V2_STR], int *count, int maxn) {
    const kiln_value *els = NULL;
    int n = 0;
    int i;
    if (list_items(v, &els, &n, -1)) return -1;
    if (n > maxn) return -1;
    for (i = 0; i < n; i++)
        if (copy_str(dst[i], V2_STR, &els[i])) return -1;
    *count = n;
    return 0;
}

static int write_message_one(const message_t *m, kiln_value *out) {
    kiln_value *f = pool_alloc(8);
    if (!f) return -1;
    set_bool(&f[0], m->f_bool);
    set_i32(&f[1], m->f_int32);
    set_i64(&f[2], m->f_int64);
    set_f64(&f[3], m->f_float64);
    set_str(&f[4], m->f_string);
    set_bool(&f[5], m->f_bool_2);
    set_i32(&f[6], m->f_int32_2);
    set_str(&f[7], m->f_string_2);
    set_struct(out, f, 8);
    return 0;
}

static int read_message_one(const kiln_value *v, message_t *m) {
    memset(m, 0, sizeof(*m));
    if (read_bool(field_at(v, 0), &m->f_bool)) return -1;
    if (read_i32(field_at(v, 1), &m->f_int32)) return -1;
    if (read_i64(field_at(v, 2), &m->f_int64)) return -1;
    if (read_f64(field_at(v, 3), &m->f_float64)) return -1;
    if (copy_str(m->f_string, sizeof m->f_string, field_at(v, 4))) return -1;
    if (read_bool(field_at(v, 5), &m->f_bool_2)) return -1;
    if (read_i32(field_at(v, 6), &m->f_int32_2)) return -1;
    if (copy_str(m->f_string_2, sizeof m->f_string_2, field_at(v, 7))) return -1;
    return 0;
}

static int write_item(const document_item_t *it, kiln_value *out) {
    kiln_value *f = pool_alloc(3);
    if (!f) return -1;
    set_str(&f[0], it->sku);
    set_i32(&f[1], it->qty);
    set_i64(&f[2], it->price_minor);
    set_struct(out, f, 3);
    return 0;
}

static int read_item(const kiln_value *v, document_item_t *it) {
    memset(it, 0, sizeof(*it));
    if (copy_str(it->sku, sizeof it->sku, field_at(v, 0))) return -1;
    if (read_i32(field_at(v, 1), &it->qty)) return -1;
    if (read_i64(field_at(v, 2), &it->price_minor)) return -1;
    return 0;
}

static int write_document_one(const document_t *d, kiln_value *out) {
    kiln_value *f = pool_alloc(4);
    kiln_value *meta;
    kiln_value *items = NULL;
    int i;
    if (!f) return -1;
    if (d->item_count < 0 || d->item_count > V2_MAX_CHILDREN) return -1;
    set_str(&f[0], d->id);
    set_i32(&f[1], d->status);
    meta = pool_alloc(2);
    if (!meta) return -1;
    set_str(&meta[0], d->meta.region);
    set_i32(&meta[1], d->meta.version);
    set_struct(&f[2], meta, 2);
    if (d->item_count) {
        items = pool_alloc((size_t)d->item_count);
        if (!items) return -1;
        for (i = 0; i < d->item_count; i++)
            if (write_item(&d->items[i], &items[i])) return -1;
    }
    set_list(&f[3], items, (size_t)d->item_count);
    set_struct(out, f, 4);
    return 0;
}

static int read_document_one(const kiln_value *v, document_t *d) {
    const kiln_value *meta;
    const kiln_value *items_v;
    const kiln_value *els = NULL;
    int n = 0;
    int i;
    memset(d, 0, sizeof(*d));
    if (copy_str(d->id, sizeof d->id, field_at(v, 0))) return -1;
    if (read_i32(field_at(v, 1), &d->status)) return -1;
    meta = field_at(v, 2);
    if (copy_str(d->meta.region, sizeof d->meta.region, field_at(meta, 0))) return -1;
    if (read_i32(field_at(meta, 1), &d->meta.version)) return -1;
    items_v = field_at(v, 3);
    if (list_items(items_v, &els, &n, -1) || n > V2_MAX_CHILDREN) return -1;
    d->item_count = n;
    for (i = 0; i < n; i++)
        if (read_item(&els[i], &d->items[i])) return -1;
    return 0;
}

static int write_telemetry_one(const telemetry_t *t, kiln_value *out) {
    kiln_value *f = pool_alloc(4);
    if (!f) return -1;
    if (t->tag_count < 0 || t->tag_count > V2_MAX_TAGS) return -1;
    if (t->value_count < 0 || t->value_count > V2_MAX_POINTS) return -1;
    set_str(&f[0], t->source);
    set_i64(&f[1], t->ts);
    if (fill_str_list(&f[2], t->tags, t->tag_count)) return -1;
    if (fill_f64_list(&f[3], t->values, t->value_count)) return -1;
    set_struct(out, f, 4);
    return 0;
}

static int read_telemetry_one(const kiln_value *v, telemetry_t *t) {
    memset(t, 0, sizeof(*t));
    if (copy_str(t->source, sizeof t->source, field_at(v, 0))) return -1;
    if (read_i64(field_at(v, 1), &t->ts)) return -1;
    if (read_str_list(field_at(v, 2), t->tags, &t->tag_count, V2_MAX_TAGS)) return -1;
    if (read_f64_list(field_at(v, 3), t->values, &t->value_count, V2_MAX_POINTS)) return -1;
    return 0;
}

static int write_strings_one(const strings_t *s, kiln_value *out) {
    kiln_value *f = pool_alloc(1);
    if (!f) return -1;
    if (s->count < 0 || s->count > V2_MAX_STRINGS) return -1;
    if (fill_str_list(&f[0], s->items, s->count)) return -1;
    set_struct(out, f, 1);
    return 0;
}

static int read_strings_one(const kiln_value *v, strings_t *s) {
    memset(s, 0, sizeof(*s));
    if (read_str_list(field_at(v, 0), s->items, &s->count, V2_MAX_STRINGS)) return -1;
    return 0;
}

static int write_attr(const event_attr_t *a, kiln_value *out) {
    kiln_value *f = pool_alloc(2);
    if (!f) return -1;
    set_str(&f[0], a->key);
    set_str(&f[1], a->value);
    set_struct(out, f, 2);
    return 0;
}

static int read_attr(const kiln_value *v, event_attr_t *a) {
    memset(a, 0, sizeof(*a));
    if (copy_str(a->key, sizeof a->key, field_at(v, 0))) return -1;
    if (copy_str(a->value, sizeof a->value, field_at(v, 1))) return -1;
    return 0;
}

static int write_event_one(const event_t *e, kiln_value *out) {
    kiln_value *f = pool_alloc(5);
    kiln_value *attrs = NULL;
    int i;
    if (!f) return -1;
    if (e->attr_count < 0 || e->attr_count > V2_MAX_ATTRS) return -1;
    set_str(&f[0], e->event_id);
    set_str(&f[1], e->event_type);
    set_i64(&f[2], e->occurred_at);
    set_str(&f[3], e->producer);
    if (e->attr_count) {
        attrs = pool_alloc((size_t)e->attr_count);
        if (!attrs) return -1;
        for (i = 0; i < e->attr_count; i++)
            if (write_attr(&e->attrs[i], &attrs[i])) return -1;
    }
    set_list(&f[4], attrs, (size_t)e->attr_count);
    set_struct(out, f, 5);
    return 0;
}

static int read_event_one(const kiln_value *v, event_t *e) {
    const kiln_value *els = NULL;
    int n = 0;
    int i;
    memset(e, 0, sizeof(*e));
    if (copy_str(e->event_id, sizeof e->event_id, field_at(v, 0))) return -1;
    if (copy_str(e->event_type, sizeof e->event_type, field_at(v, 1))) return -1;
    if (read_i64(field_at(v, 2), &e->occurred_at)) return -1;
    if (copy_str(e->producer, sizeof e->producer, field_at(v, 3))) return -1;
    if (list_items(field_at(v, 4), &els, &n, -1) || n > V2_MAX_ATTRS) return -1;
    e->attr_count = n;
    for (i = 0; i < n; i++)
        if (read_attr(&els[i], &e->attrs[i])) return -1;
    return 0;
}

static int write_message_fx(const test_fixture_t *fx, kiln_value *out) {
    return write_message_one(&fx->message, out);
}
static int write_document_fx(const test_fixture_t *fx, kiln_value *out) {
    return write_document_one(&fx->document, out);
}
static int write_telemetry_fx(const test_fixture_t *fx, kiln_value *out) {
    return write_telemetry_one(&fx->telemetry, out);
}
static int write_strings_fx(const test_fixture_t *fx, kiln_value *out) {
    return write_strings_one(&fx->strings, out);
}
static int write_event_fx(const test_fixture_t *fx, kiln_value *out) {
    return write_event_one(&fx->event, out);
}

static int finish_batch(test_fixture_t *out, test_data_kind_t kind, test_fixture_t *items, int n) {
    memset(out, 0, sizeof(*out));
    out->kind = kind;
    out->name = test_data_name(kind);
    out->batch_n = n;
    out->batch = items;
    if (n > 0) {
        out->message = items[0].message;
        out->document = items[0].document;
        out->telemetry = items[0].telemetry;
        out->strings = items[0].strings;
        out->event = items[0].event;
    }
    return 0;
}

static int write_list(const test_fixture_t *fx, kiln_value *out,
                      int (*write_row)(const test_fixture_t *row, kiln_value *dst)) {
    int n;
    kiln_value *items;
    int i;
    n = fx->batch_n;
    if (n <= 1 || !fx->batch) return -1;
    items = pool_alloc((size_t)n);
    if (!items) return -1;
    for (i = 0; i < n; i++)
        if (write_row(&fx->batch[i], &items[i])) return -1;
    set_list(out, items, (size_t)n);
    return 0;
}

static int write_message_list_fx(const test_fixture_t *fx, kiln_value *out) {
    return write_list(fx, out, write_message_fx);
}
static int write_document_list_fx(const test_fixture_t *fx, kiln_value *out) {
    return write_list(fx, out, write_document_fx);
}
static int write_telemetry_list_fx(const test_fixture_t *fx, kiln_value *out) {
    return write_list(fx, out, write_telemetry_fx);
}
static int write_strings_list_fx(const test_fixture_t *fx, kiln_value *out) {
    return write_list(fx, out, write_strings_fx);
}
static int write_event_list_fx(const test_fixture_t *fx, kiln_value *out) {
    return write_list(fx, out, write_event_fx);
}

static void stamp_one(test_fixture_t *out, test_data_kind_t kind) {
    out->kind = kind;
    out->name = test_data_name(kind);
    out->batch_n = 1;
    out->batch = NULL;
}

static int read_message_fx(const kiln_value *v, test_fixture_t *out) {
    message_t row;
    if (read_message_one(v, &row)) return -1;
    memset(out, 0, sizeof(*out));
    stamp_one(out, TD_MESSAGE);
    out->message = row;
    return 0;
}
static int read_document_fx(const kiln_value *v, test_fixture_t *out) {
    document_t row;
    if (read_document_one(v, &row)) return -1;
    memset(out, 0, sizeof(*out));
    stamp_one(out, TD_DOCUMENT);
    out->document = row;
    return 0;
}
static int read_telemetry_fx(const kiln_value *v, test_fixture_t *out) {
    telemetry_t row;
    if (read_telemetry_one(v, &row)) return -1;
    memset(out, 0, sizeof(*out));
    stamp_one(out, TD_TELEMETRY);
    out->telemetry = row;
    return 0;
}
static int read_strings_fx(const kiln_value *v, test_fixture_t *out) {
    strings_t row;
    if (read_strings_one(v, &row)) return -1;
    memset(out, 0, sizeof(*out));
    stamp_one(out, TD_STRINGS);
    out->strings = row;
    return 0;
}
static int read_event_fx(const kiln_value *v, test_fixture_t *out) {
    event_t row;
    if (read_event_one(v, &row)) return -1;
    memset(out, 0, sizeof(*out));
    stamp_one(out, TD_EVENT);
    out->event = row;
    return 0;
}

static int read_list_fx(const kiln_value *v, test_fixture_t *out, test_data_kind_t kind,
                        int (*read_row)(const kiln_value *, test_fixture_t *)) {
    const kiln_value *els = NULL;
    int expect;
    int n = 0;
    int i;
    test_fixture_t *items;
    expect = out->batch_n;
    if (list_items(v, &els, &n, expect > 1 ? expect : -1)) return -1;
    if (n < 1) return -1;
    items = (test_fixture_t *)calloc((size_t)n, sizeof(test_fixture_t));
    if (!items) return -1;
    for (i = 0; i < n; i++) {
        if (read_row(&els[i], &items[i])) {
            free(items);
            return -1;
        }
        items[i].kind = kind;
        items[i].name = test_data_name(kind);
        items[i].batch_n = 1;
        items[i].batch = NULL;
    }
    return finish_batch(out, kind, items, n);
}

static int read_message_list_fx(const kiln_value *v, test_fixture_t *out) {
    return read_list_fx(v, out, TD_MESSAGE, read_message_fx);
}
static int read_document_list_fx(const kiln_value *v, test_fixture_t *out) {
    return read_list_fx(v, out, TD_DOCUMENT, read_document_fx);
}
static int read_telemetry_list_fx(const kiln_value *v, test_fixture_t *out) {
    return read_list_fx(v, out, TD_TELEMETRY, read_telemetry_fx);
}
static int read_strings_list_fx(const kiln_value *v, test_fixture_t *out) {
    return read_list_fx(v, out, TD_STRINGS, read_strings_fx);
}
static int read_event_list_fx(const kiln_value *v, test_fixture_t *out) {
    return read_list_fx(v, out, TD_EVENT, read_event_fx);
}

static int write_tensor_fx(const test_fixture_t *fx, kiln_value *out) {
    kiln_value *f;
    const tensor_t *t = &fx->tensor;
    if (t->nvalues < 0) return -1;
    f = pool_alloc(3);
    if (!f) return -1;
    set_i32(&f[0], t->rows);
    set_i32(&f[1], t->cols);
    if (fill_bulk(&f[2], t->values, (size_t)t->nvalues, 4)) return -1;
    set_struct(out, f, 3);
    return 0;
}

static int read_tensor_one(const kiln_value *v, test_fixture_t *out, int borrow) {
    tensor_t t;
    int32_t rows = 0, cols = 0;
    int expect = 0;
    int n = 0;
    memset(&t, 0, sizeof t);
    if (read_i32(field_at(v, 0), &rows) || read_i32(field_at(v, 1), &cols)) return -1;
    if (prod_int(rows, cols, &expect)) return -1;
    if (take_f32_list(field_at(v, 2), &t.values, &n, expect, borrow ? 0 : 1)) return -1;
    t.rows = rows;
    t.cols = cols;
    t.nvalues = n;
    t.values_owned = (!borrow && n) ? 1 : 0;
    memset(out, 0, sizeof(*out));
    stamp_one(out, borrow ? TD_TENSOR_VIEW : TD_TENSOR);
    out->tensor = t;
    return 0;
}

static int read_tensor_fx(const kiln_value *v, test_fixture_t *out) {
    return read_tensor_one(v, out, 0);
}

static int read_tensor_view_fx(const kiln_value *v, test_fixture_t *out) {
    return read_tensor_one(v, out, 1);
}

static int write_prompt_value(const prompt_t *p, kiln_value *out) {
    kiln_value *f;
    if (!p || p->n < 0) return -1;
    f = pool_alloc(5);
    if (!f) return -1;
    set_i32(&f[0], p->batch);
    set_i32(&f[1], p->seq);
    if (fill_bulk(&f[2], p->input_ids, (size_t)p->n, 8)) return -1;
    if (fill_bulk(&f[3], p->attention_mask, (size_t)p->n, 8)) return -1;
    if (fill_bulk(&f[4], p->position_ids, (size_t)p->n, 8)) return -1;
    set_struct(out, f, 5);
    return 0;
}

static void free_prompt_local(prompt_t *p) {
    if (!p) return;
    free(p->input_ids);
    free(p->attention_mask);
    free(p->position_ids);
    p->input_ids = NULL;
    p->attention_mask = NULL;
    p->position_ids = NULL;
}

static int read_prompt_value(const kiln_value *v, prompt_t *p) {
    int32_t batch = 0, seq = 0;
    int expect = 0;
    memset(p, 0, sizeof(*p));
    if (read_i32(field_at(v, 0), &batch) || read_i32(field_at(v, 1), &seq)) return -1;
    if (prod_int(batch, seq, &expect)) return -1;
    if (take_i64_list(field_at(v, 2), &p->input_ids, expect)) return -1;
    if (take_i64_list(field_at(v, 3), &p->attention_mask, expect)) {
        free_prompt_local(p);
        return -1;
    }
    if (take_i64_list(field_at(v, 4), &p->position_ids, expect)) {
        free_prompt_local(p);
        return -1;
    }
    p->batch = batch;
    p->seq = seq;
    p->n = expect;
    return 0;
}

static int write_prompt_fx(const test_fixture_t *fx, kiln_value *out) {
    return write_prompt_value(&fx->prompt, out);
}

static int read_prompt_fx(const kiln_value *v, test_fixture_t *out) {
    prompt_t p;
    if (read_prompt_value(v, &p)) return -1;
    memset(out, 0, sizeof(*out));
    stamp_one(out, TD_PROMPT);
    out->prompt = p;
    return 0;
}

static int write_shard_fx(const test_fixture_t *fx, kiln_value *out) {
    kiln_value *f;
    const shard_t *s = &fx->shard;
    if (s->n_tok < 0 || s->n_attn < 0 || s->n_ffn < 0 || s->n_norm < 0) return -1;
    f = pool_alloc(7);
    if (!f) return -1;
    set_i32(&f[0], s->vocab);
    set_i32(&f[1], s->hidden);
    set_i32(&f[2], s->ffn);
    if (fill_bulk(&f[3], s->tok_emb, (size_t)s->n_tok, 4)) return -1;
    if (fill_bulk(&f[4], s->attn, (size_t)s->n_attn, 4)) return -1;
    if (fill_bulk(&f[5], s->ffn_weight, (size_t)s->n_ffn, 4)) return -1;
    if (fill_bulk(&f[6], s->norm, (size_t)s->n_norm, 4)) return -1;
    set_struct(out, f, 7);
    return 0;
}

static int read_shard_fx(const kiln_value *v, test_fixture_t *out) {
    shard_t s;
    int32_t vocab = 0, hidden = 0, ffn = 0;
    int et = 0, ea = 0, ef = 0;
    memset(&s, 0, sizeof s);
    if (read_i32(field_at(v, 0), &vocab) || read_i32(field_at(v, 1), &hidden) ||
        read_i32(field_at(v, 2), &ffn))
        return -1;
    if (hidden < 0 || prod_int(vocab, hidden, &et) || prod_int(hidden, hidden, &ea) ||
        prod_int(ffn, hidden, &ef))
        return -1;
    if (take_f32_list(field_at(v, 3), &s.tok_emb, &s.n_tok, et, 1)) return -1;
    if (take_f32_list(field_at(v, 4), &s.attn, &s.n_attn, ea, 1)) goto fail;
    if (take_f32_list(field_at(v, 5), &s.ffn_weight, &s.n_ffn, ef, 1)) goto fail;
    if (take_f32_list(field_at(v, 6), &s.norm, &s.n_norm, hidden, 1)) goto fail;
    s.vocab = vocab;
    s.hidden = hidden;
    s.ffn = ffn;
    memset(out, 0, sizeof(*out));
    stamp_one(out, TD_SHARD);
    out->shard = s;
    return 0;
fail:
    free(s.tok_emb);
    free(s.attn);
    free(s.ffn_weight);
    free(s.norm);
    return -1;
}

static int write_request_fx(const test_fixture_t *fx, kiln_value *out) {
    kiln_value *f;
    const request_t *q = &fx->request;
    f = pool_alloc(4);
    if (!f) return -1;
    set_i64(&f[0], q->request_id);
    set_str(&f[1], q->model);
    set_f32(&f[2], q->temperature);
    if (write_prompt_value(&q->inputs, &f[3])) return -1;
    set_struct(out, f, 4);
    return 0;
}

static int read_request_fx(const kiln_value *v, test_fixture_t *out) {
    request_t q;
    memset(&q, 0, sizeof q);
    if (read_i64(field_at(v, 0), &q.request_id)) return -1;
    if (copy_str(q.model, sizeof q.model, field_at(v, 1))) return -1;
    if (read_f32(field_at(v, 2), &q.temperature)) return -1;
    if (read_prompt_value(field_at(v, 3), &q.inputs)) return -1;
    memset(out, 0, sizeof(*out));
    stamp_one(out, TD_REQUEST);
    out->request = q;
    return 0;
}

static size_t payload_need(test_data_kind_t kind, const test_fixture_t *fx) {
    if (!fx) return 0;
    switch (kind) {
        case TD_TENSOR:
        case TD_TENSOR_VIEW:
            if (fx->tensor.nvalues < 0) return 0;
            return 16u + (size_t)fx->tensor.nvalues * 4u;
        case TD_PROMPT:
            if (fx->prompt.n < 0) return 0;
            return 32u + (size_t)fx->prompt.n * 24u;
        case TD_SHARD:
            return 64u + ((size_t)fx->shard.n_tok + (size_t)fx->shard.n_attn +
                          (size_t)fx->shard.n_ffn + (size_t)fx->shard.n_norm) *
                             4u;
        case TD_REQUEST:
            if (fx->request.inputs.n < 0) return 0;
            return 128u + (size_t)fx->request.inputs.n * 24u;
        default:
            return 0;
    }
}

static int prep(test_data_kind_t kind, const test_fixture_t *fx) {
    int batch = fx && fx->batch_n > 1 && fx->batch;
    g_write = NULL;
    g_read = NULL;
    g_schema = NULL;
    switch (kind) {
        case TD_MESSAGE:
            g_schema = batch ? &SCH_MESSAGE_LIST : &SCH_MESSAGE;
            g_write = batch ? write_message_list_fx : write_message_fx;
            g_read = batch ? read_message_list_fx : read_message_fx;
            break;
        case TD_DOCUMENT:
            g_schema = batch ? &SCH_DOCUMENT_LIST : &SCH_DOCUMENT;
            g_write = batch ? write_document_list_fx : write_document_fx;
            g_read = batch ? read_document_list_fx : read_document_fx;
            break;
        case TD_TELEMETRY:
            g_schema = batch ? &SCH_TELEMETRY_LIST : &SCH_TELEMETRY;
            g_write = batch ? write_telemetry_list_fx : write_telemetry_fx;
            g_read = batch ? read_telemetry_list_fx : read_telemetry_fx;
            break;
        case TD_STRINGS:
            g_schema = batch ? &SCH_STRINGS_LIST : &SCH_STRINGS;
            g_write = batch ? write_strings_list_fx : write_strings_fx;
            g_read = batch ? read_strings_list_fx : read_strings_fx;
            break;
        case TD_EVENT:
            g_schema = batch ? &SCH_EVENT_LIST : &SCH_EVENT;
            g_write = batch ? write_event_list_fx : write_event_fx;
            g_read = batch ? read_event_list_fx : read_event_fx;
            break;
        case TD_TENSOR:
        case TD_TENSOR_VIEW:
        case TD_PROMPT:
        case TD_SHARD:
        case TD_REQUEST:
            if (batch) return -1;
            if (kind == TD_TENSOR || kind == TD_TENSOR_VIEW) {
                g_schema = &SCH_TENSOR;
                g_write = write_tensor_fx;
                g_read = kind == TD_TENSOR_VIEW ? read_tensor_view_fx : read_tensor_fx;
            } else if (kind == TD_PROMPT) {
                g_schema = &SCH_PROMPT;
                g_write = write_prompt_fx;
                g_read = read_prompt_fx;
            } else if (kind == TD_SHARD) {
                g_schema = &SCH_SHARD;
                g_write = write_shard_fx;
                g_read = read_shard_fx;
            } else {
                g_schema = &SCH_REQUEST;
                g_write = write_request_fx;
                g_read = read_request_fx;
            }
            break;
        default:
            return -1;
    }
    {
        size_t need = payload_need(kind, fx);
        if (need) {
            g_buf.len = 0;
            if (kiln_buf_reserve(&g_buf, need) != KILN_OK) return -1;
            g_buf.len = 0;
        }
    }
    return 0;
}

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    kiln_value root;
    if (!g_schema || !g_write || !fx || !buf || !ol) return -1;
    {
        size_t nbatch = (fx->batch_n > 1 && fx->batch) ? (size_t)fx->batch_n : 1;
        if (pool_reserve(nbatch * 96u + 64u)) return -1;
        if (f64_reserve(nbatch * (size_t)V2_MAX_POINTS * 8u + 8u)) return -1;
    }
    g_pool_used = 0;
    g_f64_used = 0;
    memset(&root, 0, sizeof root);
    if (g_write(fx, &root)) return -1;
    if (kiln_encode_buf(g_schema, &root, &g_buf) != KILN_OK) return -1;
    if (g_buf.len > cap) return -1;
    if (g_buf.len) memcpy(buf, g_buf.data, g_buf.len);
    *ol = g_buf.len;
    return 0;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    kiln_read_opts opts;
    kiln_err err;
    (void)kind;
    if (!g_schema || !g_read || !buf || !out) return -1;
    memset(&opts, 0, sizeof opts);
    opts.standalone = 1;
    if (!g_doc)
        err = kiln_decode(g_schema, buf, len, &opts, &g_doc);
    else
        err = kiln_decode_reuse(g_doc, g_schema, buf, len, &opts);
    if (err != KILN_OK || !g_doc) return -1;
    if (g_read(&g_doc->root, out)) return -1;
    if (kind == TD_TENSOR_VIEW) {
        const uint8_t *p;
        size_t nbytes;
        uintptr_t b0, b1, p0;
        if (out->tensor.values_owned) return -1;
        if (out->tensor.nvalues < 0) return -1;
        if (out->tensor.nvalues == 0) return 0;
        p = (const uint8_t *)out->tensor.values;
        nbytes = (size_t)out->tensor.nvalues * 4u;
        if (!p || !buf) return -1;
        b0 = (uintptr_t)buf;
        b1 = b0 + len;
        p0 = (uintptr_t)p;
        /* Borrowed f32 payload. A copy would land outside this buffer. */
        if (p0 < b0 || p0 > b1 || nbytes > b1 - p0) return -1;
    }
    return 0;
}

static bool same_f32_bits(const float *a, const float *b, int n) {
    if (n < 0) return false;
    if (n == 0) return true;
    if (!a || !b) return false;
    return memcmp(a, b, (size_t)n * 4u) == 0;
}

static bool same_i64_bits(const int64_t *a, const int64_t *b, int n) {
    if (n < 0) return false;
    if (n == 0) return true;
    if (!a || !b) return false;
    return memcmp(a, b, (size_t)n * 8u) == 0;
}

static bool same_one_f32(float a, float b) {
    uint32_t xa, xb;
    memcpy(&xa, &a, 4);
    memcpy(&xb, &b, 4);
    return xa == xb;
}

static bool fid_prompt(const prompt_t *a, const prompt_t *b) {
    if (a->batch != b->batch || a->seq != b->seq || a->n != b->n) return false;
    return same_i64_bits(a->input_ids, b->input_ids, a->n) &&
           same_i64_bits(a->attention_mask, b->attention_mask, a->n) &&
           same_i64_bits(a->position_ids, b->position_ids, a->n);
}

static bool fid_tensor(const tensor_t *a, const tensor_t *b) {
    if (a->rows != b->rows || a->cols != b->cols || a->nvalues != b->nvalues) return false;
    return same_f32_bits(a->values, b->values, a->nvalues);
}

static bool kiln_fidelity(const test_fixture_t *a, const test_fixture_t *b) {
    if (!a || !b || a->kind != b->kind) return false;
    switch (a->kind) {
        case TD_TENSOR:
        case TD_TENSOR_VIEW:
            return fid_tensor(&a->tensor, &b->tensor);
        case TD_PROMPT:
            return fid_prompt(&a->prompt, &b->prompt);
        case TD_SHARD:
            if (a->shard.vocab != b->shard.vocab || a->shard.hidden != b->shard.hidden ||
                a->shard.ffn != b->shard.ffn)
                return false;
            if (a->shard.n_tok != b->shard.n_tok || a->shard.n_attn != b->shard.n_attn ||
                a->shard.n_ffn != b->shard.n_ffn || a->shard.n_norm != b->shard.n_norm)
                return false;
            return same_f32_bits(a->shard.tok_emb, b->shard.tok_emb, a->shard.n_tok) &&
                   same_f32_bits(a->shard.attn, b->shard.attn, a->shard.n_attn) &&
                   same_f32_bits(a->shard.ffn_weight, b->shard.ffn_weight, a->shard.n_ffn) &&
                   same_f32_bits(a->shard.norm, b->shard.norm, a->shard.n_norm);
        case TD_REQUEST:
            if (a->request.request_id != b->request.request_id) return false;
            if (strcmp(a->request.model, b->request.model) != 0) return false;
            if (!same_one_f32(a->request.temperature, b->request.temperature)) return false;
            return fid_prompt(&a->request.inputs, &b->request.inputs);
        default:
            return fidelity_fx(a, b);
    }
}

static bool supports_kiln(test_data_kind_t kind) {
    switch (kind) {
        case TD_MESSAGE:
        case TD_DOCUMENT:
        case TD_TELEMETRY:
        case TD_STRINGS:
        case TD_EVENT:
        case TD_TENSOR:
        case TD_TENSOR_VIEW:
        case TD_PROMPT:
        case TD_SHARD:
        case TD_REQUEST:
            return true;
        default:
            return false;
    }
}

void bench_register_kiln(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "gld-kiln", "0.2.0", "binary", prep, ser, de, kiln_fidelity);
    o[*c - 1].owns_batch = 1;
    o[*c - 1].supports = supports_kiln;
}
