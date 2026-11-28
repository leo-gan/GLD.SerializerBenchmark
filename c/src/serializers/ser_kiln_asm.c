#include "ser_common.h"
#include "kiln_asm_bench.h"
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#if defined(__BYTE_ORDER__) && __BYTE_ORDER__ != __ORDER_LITTLE_ENDIAN__
#error "gld-kiln-asm requires little-endian x86-64"
#endif

/* gld-kiln-asm: pure x86-64 Assembly Kiln Wire Format v2 codec (MODE=cabi).
 * Uses shared libkiln_asm_bench.a built from gld-kiln-asm 0.2.0 core kernels
 * plus AOT-generated Kiln v2 JSON Schemas (schemas/v2/kiln/) via gld_kilngen_asm.py.
 * Covers all 4 supported Data Sets: suite, columnar, array, and tensor.
 * Full RFC 3629 UTF-8 validation is always active (no KILN_OPT_TRUSTED).
 */

#define KILN_DTYPE_F64 1U
#define KILN_DTYPE_F32 2U
#define KILN_DTYPE_I64 14U

static test_data_kind_t g_kind = TD_MESSAGE;
static int g_batch = 0;
static int g_nx = 0, g_ny = 0, g_x0 = 0, g_y0 = 0, g_wx = 0, g_wy = 0;

/* Reused bump arena for decoded list headers & tensor descriptors (never freed per trial). */
static uint8_t *g_arena_buf = NULL;
static size_t g_arena_cap = 0;

/* Reused encode scratch buffer for flat C-ABI input arrays and columnar transpose buffers. */
static uint8_t *g_enc_buf = NULL;
static size_t g_enc_cap = 0;

static int reserve_buf(uint8_t **buf, size_t *cap, size_t need) {
    uint8_t *p;
    if (need < 4096) need = 4096;
    if (*cap >= need) return 0;
    p = (uint8_t *)realloc(*buf, need);
    if (!p) return -1;
    *buf = p;
    *cap = need;
    return 0;
}

static inline kiln_str_t kstr(const char *s) {
    kiln_str_t out;
    out.ptr = (const uint8_t *)(s ? s : "");
    out.len = s ? strlen(s) : 0;
    return out;
}

static inline int copy_kstr(char *dst, size_t cap, kiln_str_t s) {
    if (s.len >= cap) return -1;
    if (s.len) {
        if (!s.ptr) return -1;
        memcpy(dst, s.ptr, s.len);
    }
    dst[s.len] = 0;
    return 0;
}

static inline size_t align16(size_t n) {
    return (n + 15u) & ~(size_t)15u;
}

static void stamp_one(test_fixture_t *out, test_data_kind_t kind) {
    out->kind = kind;
    out->name = test_data_name(kind);
    out->batch_n = 1;
    out->batch = NULL;
}

static int finish_batch(test_fixture_t *out, test_data_kind_t kind,
                        test_fixture_t *items, int n) {
    out->kind = kind;
    out->name = test_data_name(kind);
    out->batch_n = n;
    out->batch = items;
    if (n > 0) {
        switch (kind) {
            case TD_MESSAGE:      out->message = items[0].message; break;
            case TD_DOCUMENT:     out->document = items[0].document; break;
            case TD_TELEMETRY:    out->telemetry = items[0].telemetry; break;
            case TD_STRINGS:      out->strings = items[0].strings; break;
            case TD_EVENT:        out->event = items[0].event; break;
            case TD_NESTED_TABLE: out->nested_table = items[0].nested_table; break;
            case TD_SIGNAL:       out->signal = items[0].signal; break;
            default: break;
        }
    }
    return 0;
}

/* ---------- Domain <-> Generated C-ABI struct converters ---------- */

static void fill_msg(const message_t *m, bench_message_t *dst) {
    dst->f_bool = m->f_bool ? 1 : 0;
    dst->f_int32 = m->f_int32;
    dst->f_int64 = m->f_int64;
    dst->f_float64 = m->f_float64;
    dst->f_string = kstr(m->f_string);
    dst->f_bool_2 = m->f_bool_2 ? 1 : 0;
    dst->f_int32_2 = m->f_int32_2;
    dst->f_string_2 = kstr(m->f_string_2);
}

static int read_msg(const bench_message_t *src, message_t *m) {
    m->f_bool = src->f_bool != 0;
    m->f_int32 = src->f_int32;
    m->f_int64 = src->f_int64;
    m->f_float64 = src->f_float64;
    if (copy_kstr(m->f_string, sizeof m->f_string, src->f_string)) return -1;
    m->f_bool_2 = src->f_bool_2 != 0;
    m->f_int32_2 = src->f_int32_2;
    if (copy_kstr(m->f_string_2, sizeof m->f_string_2, src->f_string_2)) return -1;
    return 0;
}

static void fill_doc(const document_t *d, bench_document_t *dst,
                     bench_document_document_item_t *item_buf) {
    int i;
    dst->id = kstr(d->id);
    dst->status = d->status;
    dst->meta.region = kstr(d->meta.region);
    dst->meta.version = d->meta.version;
    dst->items.items = d->item_count ? item_buf : NULL;
    dst->items.count = (uint64_t)d->item_count;
    for (i = 0; i < d->item_count; i++) {
        item_buf[i].sku = kstr(d->items[i].sku);
        item_buf[i].qty = d->items[i].qty;
        item_buf[i].price_minor = d->items[i].price_minor;
    }
}

static int read_doc(const bench_document_t *src, document_t *d) {
    uint64_t i;
    if (copy_kstr(d->id, sizeof d->id, src->id)) return -1;
    d->status = src->status;
    if (copy_kstr(d->meta.region, sizeof d->meta.region, src->meta.region)) return -1;
    d->meta.version = src->meta.version;
    if (src->items.count > (uint64_t)V2_MAX_CHILDREN) return -1;
    d->item_count = (int)src->items.count;
    for (i = 0; i < src->items.count; i++) {
        if (copy_kstr(d->items[i].sku, sizeof d->items[i].sku, src->items.items[i].sku))
            return -1;
        d->items[i].qty = src->items.items[i].qty;
        d->items[i].price_minor = src->items.items[i].price_minor;
    }
    return 0;
}

static void fill_tel(const telemetry_t *t, bench_telemetry_t *dst, kiln_str_t *tag_buf) {
    int i;
    dst->source = kstr(t->source);
    dst->ts = t->ts;
    dst->tags.items = t->tag_count ? tag_buf : NULL;
    dst->tags.count = (uint64_t)t->tag_count;
    for (i = 0; i < t->tag_count; i++) tag_buf[i] = kstr(t->tags[i]);
    dst->values.items = t->value_count ? (double *)(uintptr_t)t->values : NULL;
    dst->values.count = (uint64_t)t->value_count;
}

static int read_tel(const bench_telemetry_t *src, telemetry_t *t) {
    uint64_t i;
    if (copy_kstr(t->source, sizeof t->source, src->source)) return -1;
    t->ts = src->ts;
    if (src->tags.count > (uint64_t)V2_MAX_TAGS) return -1;
    t->tag_count = (int)src->tags.count;
    for (i = 0; i < src->tags.count; i++) {
        if (copy_kstr(t->tags[i], V2_STR, src->tags.items[i])) return -1;
    }
    if (src->values.count > (uint64_t)V2_MAX_POINTS) return -1;
    t->value_count = (int)src->values.count;
    if (src->values.count) {
        memcpy(t->values, src->values.items, (size_t)src->values.count * sizeof(double));
    }
    return 0;
}

static void fill_strs(const strings_t *s, bench_strings_t *dst, kiln_str_t *str_buf) {
    int i;
    dst->items.items = s->count ? str_buf : NULL;
    dst->items.count = (uint64_t)s->count;
    for (i = 0; i < s->count; i++) str_buf[i] = kstr(s->items[i]);
}

static int read_strs(const bench_strings_t *src, strings_t *s) {
    uint64_t i;
    if (src->items.count > (uint64_t)V2_MAX_STRINGS) return -1;
    s->count = (int)src->items.count;
    for (i = 0; i < src->items.count; i++) {
        if (copy_kstr(s->items[i], V2_STR, src->items.items[i])) return -1;
    }
    return 0;
}

static void fill_ev(const event_t *e, bench_event_t *dst, bench_event_event_attr_t *attr_buf) {
    int i;
    dst->event_id = kstr(e->event_id);
    dst->event_type = kstr(e->event_type);
    dst->occurred_at = e->occurred_at;
    dst->producer = kstr(e->producer);
    dst->attrs.items = e->attr_count ? attr_buf : NULL;
    dst->attrs.count = (uint64_t)e->attr_count;
    for (i = 0; i < e->attr_count; i++) {
        attr_buf[i].key = kstr(e->attrs[i].key);
        attr_buf[i].value = kstr(e->attrs[i].value);
    }
}

static int read_ev(const bench_event_t *src, event_t *e) {
    uint64_t i;
    if (copy_kstr(e->event_id, sizeof e->event_id, src->event_id)) return -1;
    if (copy_kstr(e->event_type, sizeof e->event_type, src->event_type)) return -1;
    e->occurred_at = src->occurred_at;
    if (copy_kstr(e->producer, sizeof e->producer, src->producer)) return -1;
    if (src->attrs.count > (uint64_t)V2_MAX_ATTRS) return -1;
    e->attr_count = (int)src->attrs.count;
    for (i = 0; i < src->attrs.count; i++) {
        if (copy_kstr(e->attrs[i].key, sizeof e->attrs[i].key, src->attrs.items[i].key))
            return -1;
        if (copy_kstr(e->attrs[i].value, sizeof e->attrs[i].value, src->attrs.items[i].value))
            return -1;
    }
    return 0;
}

static void fill_nested(const nested_row_t *d, bench_nested_row_t *dst,
                        bench_nested_table_nested_item_t *item_buf) {
    int i;
    dst->id = kstr(d->id);
    dst->status = d->status;
    dst->meta.region = kstr(d->meta.region);
    dst->meta.version = d->meta.version;
    dst->items.items = d->item_count ? item_buf : NULL;
    dst->items.count = (uint64_t)d->item_count;
    for (i = 0; i < d->item_count; i++) {
        item_buf[i].sku = kstr(d->items[i].sku);
        item_buf[i].qty = d->items[i].qty;
        item_buf[i].price_minor = d->items[i].price_minor;
    }
}

static int read_nested(const bench_nested_row_t *src, nested_row_t *d) {
    uint64_t i;
    if (copy_kstr(d->id, sizeof d->id, src->id)) return -1;
    d->status = src->status;
    if (copy_kstr(d->meta.region, sizeof d->meta.region, src->meta.region)) return -1;
    d->meta.version = src->meta.version;
    if (src->items.count > (uint64_t)V2_MAX_CHILDREN) return -1;
    d->item_count = (int)src->items.count;
    for (i = 0; i < src->items.count; i++) {
        if (copy_kstr(d->items[i].sku, sizeof d->items[i].sku, src->items.items[i].sku))
            return -1;
        d->items[i].qty = src->items.items[i].qty;
        d->items[i].price_minor = src->items.items[i].price_minor;
    }
    return 0;
}

static void fill_signal(const signal_t *s, bench_signal_t *dst,
                        bench_signal_signal_leg_t *leg_buf) {
    int i;
    dst->seq = s->seq;
    dst->ts = s->ts;
    dst->price_mantissa = s->price_mantissa;
    dst->qty = s->qty;
    dst->flags = s->flags;
    dst->symbol = kstr(s->symbol);
    dst->venue = kstr(s->venue);
    dst->legs.items = s->leg_count ? leg_buf : NULL;
    dst->legs.count = (uint64_t)s->leg_count;
    for (i = 0; i < s->leg_count; i++) {
        leg_buf[i].leg_id = s->legs[i].leg_id;
        leg_buf[i].leg_qty = s->legs[i].leg_qty;
        leg_buf[i].leg_pad = s->legs[i].leg_pad;
    }
}

static int read_signal(const bench_signal_t *src, signal_t *s) {
    uint64_t i;
    s->seq = src->seq;
    s->ts = src->ts;
    s->price_mantissa = src->price_mantissa;
    s->qty = src->qty;
    s->flags = src->flags;
    if (copy_kstr(s->symbol, sizeof s->symbol, src->symbol)) return -1;
    if (copy_kstr(s->venue, sizeof s->venue, src->venue)) return -1;
    if (src->legs.count > (uint64_t)V2_MAX_LEGS) return -1;
    s->leg_count = (int)src->legs.count;
    for (i = 0; i < src->legs.count; i++) {
        s->legs[i].leg_id = src->legs.items[i].leg_id;
        s->legs[i].leg_qty = src->legs.items[i].leg_qty;
        s->legs[i].leg_pad = src->legs.items[i].leg_pad;
    }
    return 0;
}

/* ---------- KLNT v2 helpers ---------- */

static void set_tensor_2d(kiln_tensor_t *t, uint16_t dtype, uint64_t d0, uint64_t d1,
                          const void *data, size_t nbytes) {
    kiln_tensor_init(t);
    t->dtype = dtype;
    t->rank = 2;
    t->shape[0] = d0;
    t->shape[1] = d1;
    t->data = (const uint8_t *)data;
    t->data_len = (uint64_t)nbytes;
}

static void set_tensor_1d(kiln_tensor_t *t, uint16_t dtype, uint64_t d0,
                          const void *data, size_t nbytes) {
    kiln_tensor_init(t);
    t->dtype = dtype;
    t->rank = 1;
    t->shape[0] = d0;
    t->data = (const uint8_t *)data;
    t->data_len = (uint64_t)nbytes;
}

static void fill_prompt_tensors(const prompt_t *p, kiln_tensor_t ts[3], kiln_tensor_dir_t *dir) {
    size_t nbytes = (size_t)p->n * sizeof(int64_t);
    set_tensor_2d(&ts[0], KILN_DTYPE_I64, (uint64_t)p->batch, (uint64_t)p->seq, p->input_ids, nbytes);
    set_tensor_2d(&ts[1], KILN_DTYPE_I64, (uint64_t)p->batch, (uint64_t)p->seq, p->attention_mask, nbytes);
    set_tensor_2d(&ts[2], KILN_DTYPE_I64, (uint64_t)p->batch, (uint64_t)p->seq, p->position_ids, nbytes);
    dir->items = ts;
    dir->count = 3;
    dir->block_length = 0;
    dir->flags = 2;
    dir->version = 2;
}

static int read_prompt_tensors(const kiln_tensor_dir_t *dir, prompt_t *p) {
    uint64_t batch, seq, n64;
    size_t nbytes;
    int64_t *ids = NULL, *mask = NULL, *pos = NULL;
    if (dir->count != 3 || !dir->items) return -1;
    if (dir->items[0].dtype != KILN_DTYPE_I64 || dir->items[0].rank != 2) return -1;
    batch = dir->items[0].shape[0];
    seq = dir->items[0].shape[1];
    n64 = batch * seq;
    if (batch > 0x7fffffffULL || seq > 0x7fffffffULL || n64 > 0x7fffffffULL) return -1;
    nbytes = (size_t)n64 * sizeof(int64_t);
    for (int i = 0; i < 3; i++) {
        if (dir->items[i].dtype != KILN_DTYPE_I64 || dir->items[i].rank != 2) return -1;
        if (dir->items[i].shape[0] != batch || dir->items[i].shape[1] != seq) return -1;
        if (dir->items[i].data_len != (uint64_t)nbytes) return -1;
    }
    if (nbytes) {
        ids = (int64_t *)malloc(nbytes);
        mask = (int64_t *)malloc(nbytes);
        pos = (int64_t *)malloc(nbytes);
        if (!ids || !mask || !pos) {
            free(ids); free(mask); free(pos);
            return -1;
        }
        memcpy(ids, dir->items[0].data, nbytes);
        memcpy(mask, dir->items[1].data, nbytes);
        memcpy(pos, dir->items[2].data, nbytes);
    }
    p->batch = (int32_t)batch;
    p->seq = (int32_t)seq;
    p->n = (int)n64;
    p->input_ids = ids;
    p->attention_mask = mask;
    p->position_ids = pos;
    return 0;
}

/* ---------- Serializer callbacks ---------- */

static bool supports_kiln_asm(test_data_kind_t kind) {
    switch (kind) {
        case TD_MESSAGE:
        case TD_DOCUMENT:
        case TD_TELEMETRY:
        case TD_STRINGS:
        case TD_EVENT:
        case TD_TABLE:
        case TD_TABLE_PROJECT:
        case TD_NESTED_TABLE:
        case TD_SIGNAL:
        case TD_GRID:
        case TD_GRID_WINDOW:
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

static int prep(test_data_kind_t kind, const test_fixture_t *fx) {
    size_t n = 1;
    size_t arena_need = 65536;
    size_t enc_need = 65536;
    if (!supports_kiln_asm(kind) || !fx) return -1;
    g_kind = kind;
    g_batch = (fx->batch_n > 1 && fx->batch != NULL);
    if (kind == TD_GRID || kind == TD_GRID_WINDOW) {
        if (!fx->grid.values) return -1;
        g_nx = fx->grid.nx;
        g_ny = fx->grid.ny;
        g_x0 = fx->grid.x0;
        g_y0 = fx->grid.y0;
        g_wx = fx->grid.wx;
        g_wy = fx->grid.wy;
    } else if (kind == TD_TABLE || kind == TD_TABLE_PROJECT) {
        if (!fx->table_rows.rows || fx->table_rows.count < 1) return -1;
        n = (size_t)fx->table_rows.count;
        /* 16*f64 + 4*i64 + 2*kiln_str_t = 192 bytes/row for columnar transpose. */
        enc_need = n * 192u + 4096u;
        /* Decoded string lists: 2 * n * sizeof(kiln_str_t) + headroom. */
        arena_need = n * 48u + 65536u;
    } else if (g_batch) {
        n = (size_t)fx->batch_n;
        enc_need = n * 2048u + 4096u;
        arena_need = n * 2048u + 65536u;
    }
    if (reserve_buf(&g_arena_buf, &g_arena_cap, arena_need)) return -1;
    if (reserve_buf(&g_enc_buf, &g_enc_cap, enc_need)) return -1;
    return 0;
}

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *out_len) {
    kiln_result_t res = {0, 0};
    kiln_err_t err = KILN_ERR_TYPE;
    if (!fx || !buf || !out_len) return -1;

    switch (g_kind) {
        case TD_MESSAGE:
            if (g_batch) {
                size_t n = (size_t)fx->batch_n;
                bench_message_t *arr = (bench_message_t *)g_enc_buf;
                for (size_t i = 0; i < n; i++) fill_msg(&fx->batch[i].message, &arr[i]);
                err = kiln_asm_encode_bench_message_batch(arr, n, buf, cap, NULL, &res);
            } else {
                bench_message_t m;
                fill_msg(&fx->message, &m);
                err = kiln_asm_encode_bench_message(&m, buf, cap, NULL, &res);
            }
            break;

        case TD_DOCUMENT:
            if (g_batch) {
                size_t n = (size_t)fx->batch_n;
                bench_document_t *arr = (bench_document_t *)g_enc_buf;
                bench_document_document_item_t *pool =
                    (bench_document_document_item_t *)(g_enc_buf + align16(n * sizeof(bench_document_t)));
                for (size_t i = 0; i < n; i++) {
                    fill_doc(&fx->batch[i].document, &arr[i], pool);
                    pool += fx->batch[i].document.item_count;
                }
                err = kiln_asm_encode_bench_document_batch(arr, n, buf, cap, NULL, &res);
            } else {
                bench_document_t d;
                bench_document_document_item_t items[V2_MAX_CHILDREN];
                fill_doc(&fx->document, &d, items);
                err = kiln_asm_encode_bench_document(&d, buf, cap, NULL, &res);
            }
            break;

        case TD_TELEMETRY:
            if (g_batch) {
                size_t n = (size_t)fx->batch_n;
                bench_telemetry_t *arr = (bench_telemetry_t *)g_enc_buf;
                kiln_str_t *pool =
                    (kiln_str_t *)(g_enc_buf + align16(n * sizeof(bench_telemetry_t)));
                for (size_t i = 0; i < n; i++) {
                    fill_tel(&fx->batch[i].telemetry, &arr[i], pool);
                    pool += fx->batch[i].telemetry.tag_count;
                }
                err = kiln_asm_encode_bench_telemetry_batch(arr, n, buf, cap, NULL, &res);
            } else {
                bench_telemetry_t t;
                kiln_str_t tags[V2_MAX_TAGS];
                fill_tel(&fx->telemetry, &t, tags);
                err = kiln_asm_encode_bench_telemetry(&t, buf, cap, NULL, &res);
            }
            break;

        case TD_STRINGS:
            if (g_batch) {
                size_t n = (size_t)fx->batch_n;
                bench_strings_t *arr = (bench_strings_t *)g_enc_buf;
                kiln_str_t *pool =
                    (kiln_str_t *)(g_enc_buf + align16(n * sizeof(bench_strings_t)));
                for (size_t i = 0; i < n; i++) {
                    fill_strs(&fx->batch[i].strings, &arr[i], pool);
                    pool += fx->batch[i].strings.count;
                }
                err = kiln_asm_encode_bench_strings_batch(arr, n, buf, cap, NULL, &res);
            } else {
                bench_strings_t s;
                kiln_str_t items[V2_MAX_STRINGS];
                fill_strs(&fx->strings, &s, items);
                err = kiln_asm_encode_bench_strings(&s, buf, cap, NULL, &res);
            }
            break;

        case TD_EVENT:
            if (g_batch) {
                size_t n = (size_t)fx->batch_n;
                bench_event_t *arr = (bench_event_t *)g_enc_buf;
                bench_event_event_attr_t *pool =
                    (bench_event_event_attr_t *)(g_enc_buf + align16(n * sizeof(bench_event_t)));
                for (size_t i = 0; i < n; i++) {
                    fill_ev(&fx->batch[i].event, &arr[i], pool);
                    pool += fx->batch[i].event.attr_count;
                }
                err = kiln_asm_encode_bench_event_batch(arr, n, buf, cap, NULL, &res);
            } else {
                bench_event_t e;
                bench_event_event_attr_t attrs[V2_MAX_ATTRS];
                fill_ev(&fx->event, &e, attrs);
                err = kiln_asm_encode_bench_event(&e, buf, cap, NULL, &res);
            }
            break;

        case TD_TABLE:
        case TD_TABLE_PROJECT: {
            /* Transpose rows -> 22 column arrays on the clock, then encode in one ASM call. */
            size_t n = (size_t)fx->table_rows.count;
            const table_row_t *rows = fx->table_rows.rows;
            double *fbase = (double *)g_enc_buf;
            int64_t *ibase = (int64_t *)(fbase + 16u * n);
            kiln_str_t *sbase = (kiln_str_t *)(ibase + 4u * n);
            kiln_str_t *s0 = sbase;
            kiln_str_t *s1 = sbase + n;
            bench_table_columns_t tc;
            bench_table_columns_list_f64_t *fcols = &tc.f_float_0;
            bench_table_columns_list_i64_t *icols = &tc.f_int_0;

            for (size_t r = 0; r < n; r++) {
                const table_row_t *row = &rows[r];
                for (int c = 0; c < 16; c++) fbase[(size_t)c * n + r] = row->f_float[c];
                for (int c = 0; c < 4; c++) ibase[(size_t)c * n + r] = row->f_int[c];
                s0[r] = kstr(row->f_str_0);
                s1[r] = kstr(row->f_str_1);
            }
            for (int c = 0; c < 16; c++) {
                fcols[c].items = fbase + (size_t)c * n;
                fcols[c].count = (uint64_t)n;
            }
            for (int c = 0; c < 4; c++) {
                icols[c].items = ibase + (size_t)c * n;
                icols[c].count = (uint64_t)n;
            }
            tc.f_str_0.items = s0;
            tc.f_str_0.count = (uint64_t)n;
            tc.f_str_1.items = s1;
            tc.f_str_1.count = (uint64_t)n;
            err = kiln_asm_encode_bench_table_columns(&tc, buf, cap, NULL, &res);
            break;
        }

        case TD_NESTED_TABLE:
            if (g_batch) {
                size_t n = (size_t)fx->batch_n;
                bench_nested_row_t *arr = (bench_nested_row_t *)g_enc_buf;
                bench_nested_table_nested_item_t *pool =
                    (bench_nested_table_nested_item_t *)(g_enc_buf + align16(n * sizeof(bench_nested_row_t)));
                for (size_t i = 0; i < n; i++) {
                    fill_nested(&fx->batch[i].nested_table, &arr[i], pool);
                    pool += fx->batch[i].nested_table.item_count;
                }
                err = kiln_asm_encode_bench_nested_row_batch(arr, n, buf, cap, NULL, &res);
            } else {
                bench_nested_row_t nr;
                bench_nested_table_nested_item_t items[V2_MAX_CHILDREN];
                fill_nested(&fx->nested_table, &nr, items);
                err = kiln_asm_encode_bench_nested_row(&nr, buf, cap, NULL, &res);
            }
            break;

        case TD_SIGNAL:
            if (g_batch) {
                size_t n = (size_t)fx->batch_n;
                bench_signal_t *arr = (bench_signal_t *)g_enc_buf;
                bench_signal_signal_leg_t *pool =
                    (bench_signal_signal_leg_t *)(g_enc_buf + align16(n * sizeof(bench_signal_t)));
                for (size_t i = 0; i < n; i++) {
                    fill_signal(&fx->batch[i].signal, &arr[i], pool);
                    pool += fx->batch[i].signal.leg_count;
                }
                err = kiln_asm_encode_bench_signal_batch(arr, n, buf, cap, NULL, &res);
            } else {
                bench_signal_t sg;
                bench_signal_signal_leg_t legs[V2_MAX_LEGS];
                fill_signal(&fx->signal, &sg, legs);
                err = kiln_asm_encode_bench_signal(&sg, buf, cap, NULL, &res);
            }
            break;

        case TD_GRID:
        case TD_GRID_WINDOW: {
            const grid_t *g = &fx->grid;
            kiln_tensor_t t;
            kiln_tensor_dir_t dir = {&t, 1, 0, 2, 2};
            set_tensor_2d(&t, KILN_DTYPE_F64, (uint64_t)g->ny, (uint64_t)g->nx,
                          g->values, (size_t)g->nvalues * sizeof(double));
            err = kiln_asm_encode_tensors(&dir, buf, cap, NULL, &res);
            break;
        }

        case TD_TENSOR:
        case TD_TENSOR_VIEW: {
            const tensor_t *tx = &fx->tensor;
            kiln_tensor_t t;
            kiln_tensor_dir_t dir = {&t, 1, 0, 2, 2};
            set_tensor_2d(&t, KILN_DTYPE_F32, (uint64_t)tx->rows, (uint64_t)tx->cols,
                          tx->values, (size_t)tx->nvalues * sizeof(float));
            err = kiln_asm_encode_tensors(&dir, buf, cap, NULL, &res);
            break;
        }

        case TD_PROMPT: {
            kiln_tensor_t ts[3];
            kiln_tensor_dir_t dir;
            fill_prompt_tensors(&fx->prompt, ts, &dir);
            err = kiln_asm_encode_tensors(&dir, buf, cap, NULL, &res);
            break;
        }

        case TD_SHARD: {
            const shard_t *s = &fx->shard;
            kiln_tensor_t ts[4];
            kiln_tensor_dir_t dir = {ts, 4, 0, 2, 2};
            set_tensor_2d(&ts[0], KILN_DTYPE_F32, (uint64_t)s->vocab, (uint64_t)s->hidden,
                          s->tok_emb, (size_t)s->n_tok * sizeof(float));
            set_tensor_2d(&ts[1], KILN_DTYPE_F32, (uint64_t)s->hidden, (uint64_t)s->hidden,
                          s->attn, (size_t)s->n_attn * sizeof(float));
            set_tensor_2d(&ts[2], KILN_DTYPE_F32, (uint64_t)s->ffn, (uint64_t)s->hidden,
                          s->ffn_weight, (size_t)s->n_ffn * sizeof(float));
            set_tensor_1d(&ts[3], KILN_DTYPE_F32, (uint64_t)s->hidden,
                          s->norm, (size_t)s->n_norm * sizeof(float));
            err = kiln_asm_encode_tensors(&dir, buf, cap, NULL, &res);
            break;
        }

        case TD_REQUEST: {
            const request_t *q = &fx->request;
            kiln_tensor_t ts[3];
            bench_request_t rq;
            rq.request_id = q->request_id;
            rq.model = kstr(q->model);
            rq.temperature = q->temperature;
            fill_prompt_tensors(&q->inputs, ts, &rq.inputs);
            err = kiln_asm_encode_bench_request(&rq, buf, cap, NULL, &res);
            break;
        }

        default:
            return -1;
    }

    if (err != KILN_OK) return -1;
    *out_len = (size_t)res.bytes;
    return 0;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    kiln_arena_t arena;
    kiln_result_t res = {0, 0};
    kiln_err_t err;
    int expect_n;

    if (!buf || !out) return -1;
    expect_n = out->batch_n;
    kiln_arena_init(&arena, g_arena_buf, g_arena_cap);

    switch (kind) {
        case TD_MESSAGE:
            if (g_batch) {
                bench_message_t *arr = NULL;
                size_t cnt = 0;
                test_fixture_t *items;
                err = kiln_asm_decode_bench_message_batch(buf, len, &arr, &cnt, &arena, NULL, &res);
                if (err != KILN_OK || cnt < 1 || (expect_n > 1 && (int)cnt != expect_n)) return -1;
                items = (test_fixture_t *)calloc(cnt, sizeof(test_fixture_t));
                if (!items) return -1;
                for (size_t i = 0; i < cnt; i++) {
                    stamp_one(&items[i], kind);
                    if (read_msg(&arr[i], &items[i].message)) { free(items); return -1; }
                }
                return finish_batch(out, kind, items, (int)cnt);
            } else {
                bench_message_t m;
                err = kiln_asm_decode_bench_message(buf, len, &m, &arena, NULL, &res);
                if (err != KILN_OK) return -1;
                stamp_one(out, kind);
                return read_msg(&m, &out->message);
            }

        case TD_DOCUMENT:
            if (g_batch) {
                bench_document_t *arr = NULL;
                size_t cnt = 0;
                test_fixture_t *items;
                err = kiln_asm_decode_bench_document_batch(buf, len, &arr, &cnt, &arena, NULL, &res);
                if (err != KILN_OK || cnt < 1 || (expect_n > 1 && (int)cnt != expect_n)) return -1;
                items = (test_fixture_t *)calloc(cnt, sizeof(test_fixture_t));
                if (!items) return -1;
                for (size_t i = 0; i < cnt; i++) {
                    stamp_one(&items[i], kind);
                    if (read_doc(&arr[i], &items[i].document)) { free(items); return -1; }
                }
                return finish_batch(out, kind, items, (int)cnt);
            } else {
                bench_document_t d;
                err = kiln_asm_decode_bench_document(buf, len, &d, &arena, NULL, &res);
                if (err != KILN_OK) return -1;
                stamp_one(out, kind);
                return read_doc(&d, &out->document);
            }

        case TD_TELEMETRY:
            if (g_batch) {
                bench_telemetry_t *arr = NULL;
                size_t cnt = 0;
                test_fixture_t *items;
                err = kiln_asm_decode_bench_telemetry_batch(buf, len, &arr, &cnt, &arena, NULL, &res);
                if (err != KILN_OK || cnt < 1 || (expect_n > 1 && (int)cnt != expect_n)) return -1;
                items = (test_fixture_t *)calloc(cnt, sizeof(test_fixture_t));
                if (!items) return -1;
                for (size_t i = 0; i < cnt; i++) {
                    stamp_one(&items[i], kind);
                    if (read_tel(&arr[i], &items[i].telemetry)) { free(items); return -1; }
                }
                return finish_batch(out, kind, items, (int)cnt);
            } else {
                bench_telemetry_t t;
                err = kiln_asm_decode_bench_telemetry(buf, len, &t, &arena, NULL, &res);
                if (err != KILN_OK) return -1;
                stamp_one(out, kind);
                return read_tel(&t, &out->telemetry);
            }

        case TD_STRINGS:
            if (g_batch) {
                bench_strings_t *arr = NULL;
                size_t cnt = 0;
                test_fixture_t *items;
                err = kiln_asm_decode_bench_strings_batch(buf, len, &arr, &cnt, &arena, NULL, &res);
                if (err != KILN_OK || cnt < 1 || (expect_n > 1 && (int)cnt != expect_n)) return -1;
                items = (test_fixture_t *)calloc(cnt, sizeof(test_fixture_t));
                if (!items) return -1;
                for (size_t i = 0; i < cnt; i++) {
                    stamp_one(&items[i], kind);
                    if (read_strs(&arr[i], &items[i].strings)) { free(items); return -1; }
                }
                return finish_batch(out, kind, items, (int)cnt);
            } else {
                bench_strings_t s;
                err = kiln_asm_decode_bench_strings(buf, len, &s, &arena, NULL, &res);
                if (err != KILN_OK) return -1;
                stamp_one(out, kind);
                return read_strs(&s, &out->strings);
            }

        case TD_EVENT:
            if (g_batch) {
                bench_event_t *arr = NULL;
                size_t cnt = 0;
                test_fixture_t *items;
                err = kiln_asm_decode_bench_event_batch(buf, len, &arr, &cnt, &arena, NULL, &res);
                if (err != KILN_OK || cnt < 1 || (expect_n > 1 && (int)cnt != expect_n)) return -1;
                items = (test_fixture_t *)calloc(cnt, sizeof(test_fixture_t));
                if (!items) return -1;
                for (size_t i = 0; i < cnt; i++) {
                    stamp_one(&items[i], kind);
                    if (read_ev(&arr[i], &items[i].event)) { free(items); return -1; }
                }
                return finish_batch(out, kind, items, (int)cnt);
            } else {
                bench_event_t e;
                err = kiln_asm_decode_bench_event(buf, len, &e, &arena, NULL, &res);
                if (err != KILN_OK) return -1;
                stamp_one(out, kind);
                return read_ev(&e, &out->event);
            }

        case TD_TABLE: {
            bench_table_columns_t tc;
            bench_table_columns_list_f64_t *fcols;
            bench_table_columns_list_i64_t *icols;
            size_t n;
            table_row_t *rows;
            err = kiln_asm_decode_bench_table_columns(buf, len, &tc, &arena, NULL, &res);
            if (err != KILN_OK) return -1;
            n = (size_t)tc.f_float_0.count;
            if (n < 1 || (expect_n > 0 && (int)n != expect_n)) return -1;
            fcols = &tc.f_float_0;
            icols = &tc.f_int_0;
            for (int c = 1; c < 16; c++) if (fcols[c].count != n) return -1;
            for (int c = 0; c < 4; c++) if (icols[c].count != n) return -1;
            if (tc.f_str_0.count != n || tc.f_str_1.count != n) return -1;
            rows = (table_row_t *)malloc(n * sizeof(table_row_t));
            if (!rows) return -1;
            /* POD list items point directly into wire buffer (4-byte aligned); use memcpy. */
            for (int c = 0; c < 16; c++) {
                const uint8_t *p = (const uint8_t *)fcols[c].items;
                for (size_t r = 0; r < n; r++) {
                    memcpy(&rows[r].f_float[c], p + r * 8u, 8u);
                }
            }
            for (int c = 0; c < 4; c++) {
                const uint8_t *p = (const uint8_t *)icols[c].items;
                for (size_t r = 0; r < n; r++) {
                    memcpy(&rows[r].f_int[c], p + r * 8u, 8u);
                }
            }
            for (size_t r = 0; r < n; r++) {
                if (copy_kstr(rows[r].f_str_0, V2_STR, tc.f_str_0.items[r]) ||
                    copy_kstr(rows[r].f_str_1, V2_STR, tc.f_str_1.items[r])) {
                    free(rows);
                    return -1;
                }
            }
            data_free_grid(out);
            out->kind = TD_TABLE;
            out->name = test_data_name(TD_TABLE);
            out->batch_n = (int)n;
            out->batch = NULL;
            out->table_rows.count = (int)n;
            out->table_rows.rows = rows;
            return 0;
        }

        case TD_TABLE_PROJECT: {
            /* Decode ONLY column 0 (f_float_0) via KILN_OPT_EMBEDDED; skip columns 1..21 in O(1). */
            kiln_read_opts_t opts = {0, 0, 0, KILN_OPT_EMBEDDED};
            bench_table_project_t proj;
            size_t n;
            double *vals;
            err = kiln_asm_decode_bench_table_project(buf, len, &proj, &arena, &opts, &res);
            if (err != KILN_OK) return -1;
            n = (size_t)proj.f_float_0.count;
            if (n < 1 || (expect_n > 0 && (int)n != expect_n)) return -1;
            vals = (double *)malloc(n * sizeof(double));
            if (!vals) return -1;
            memcpy(vals, proj.f_float_0.items, n * sizeof(double));
            data_free_grid(out);
            out->kind = TD_TABLE_PROJECT;
            out->name = test_data_name(TD_TABLE_PROJECT);
            out->batch_n = (int)n;
            out->batch = NULL;
            out->table_project.count = (int)n;
            out->table_project.values = vals;
            return 0;
        }

        case TD_NESTED_TABLE:
            if (g_batch) {
                bench_nested_row_t *arr = NULL;
                size_t cnt = 0;
                test_fixture_t *items;
                err = kiln_asm_decode_bench_nested_row_batch(buf, len, &arr, &cnt, &arena, NULL, &res);
                if (err != KILN_OK || cnt < 1 || (expect_n > 1 && (int)cnt != expect_n)) return -1;
                items = (test_fixture_t *)calloc(cnt, sizeof(test_fixture_t));
                if (!items) return -1;
                for (size_t i = 0; i < cnt; i++) {
                    stamp_one(&items[i], kind);
                    if (read_nested(&arr[i], &items[i].nested_table)) { free(items); return -1; }
                }
                return finish_batch(out, kind, items, (int)cnt);
            } else {
                bench_nested_row_t nr;
                err = kiln_asm_decode_bench_nested_row(buf, len, &nr, &arena, NULL, &res);
                if (err != KILN_OK) return -1;
                stamp_one(out, kind);
                return read_nested(&nr, &out->nested_table);
            }

        case TD_SIGNAL:
            if (g_batch) {
                bench_signal_t *arr = NULL;
                size_t cnt = 0;
                test_fixture_t *items;
                err = kiln_asm_decode_bench_signal_batch(buf, len, &arr, &cnt, &arena, NULL, &res);
                if (err != KILN_OK || cnt < 1 || (expect_n > 1 && (int)cnt != expect_n)) return -1;
                items = (test_fixture_t *)calloc(cnt, sizeof(test_fixture_t));
                if (!items) return -1;
                for (size_t i = 0; i < cnt; i++) {
                    stamp_one(&items[i], kind);
                    if (read_signal(&arr[i], &items[i].signal)) { free(items); return -1; }
                }
                return finish_batch(out, kind, items, (int)cnt);
            } else {
                bench_signal_t sg;
                err = kiln_asm_decode_bench_signal(buf, len, &sg, &arena, NULL, &res);
                if (err != KILN_OK) return -1;
                stamp_one(out, kind);
                return read_signal(&sg, &out->signal);
            }

        case TD_GRID:
        case TD_GRID_WINDOW: {
            kiln_tensor_dir_t dir;
            const kiln_tensor_t *t;
            int ny, nx, read_nx, read_ny;
            size_t nread;
            double *values;
            err = kiln_asm_decode_tensors(buf, len, &dir, &arena, NULL, &res);
            if (err != KILN_OK || dir.count != 1 || !dir.items) return -1;
            t = &dir.items[0];
            if (t->dtype != KILN_DTYPE_F64 || t->rank != 2) return -1;
            ny = (int)t->shape[0];
            nx = (int)t->shape[1];
            if (ny <= 0 || nx <= 0 || t->data_len != (uint64_t)ny * (uint64_t)nx * 8ULL)
                return -1;
            if (kind == TD_GRID_WINDOW) {
                if (g_x0 < 0 || g_y0 < 0 || g_wx <= 0 || g_wy <= 0) return -1;
                if (g_x0 + g_wx > nx || g_y0 + g_wy > ny) return -1;
                read_nx = g_wx;
                read_ny = g_wy;
                nread = (size_t)read_nx * (size_t)read_ny;
                values = (double *)malloc(nread * sizeof(double));
                if (!values) return -1;
                size_t row_bytes = (size_t)g_wx * sizeof(double);
                for (int r = 0; r < g_wy; r++) {
                    size_t src_off = ((size_t)(g_y0 + r) * (size_t)nx + (size_t)g_x0) * sizeof(double);
                    memcpy(values + (size_t)r * (size_t)g_wx, t->data + src_off, row_bytes);
                }
            } else {
                read_nx = nx;
                read_ny = ny;
                nread = (size_t)nx * (size_t)ny;
                values = (double *)malloc(nread * sizeof(double));
                if (!values) return -1;
                memcpy(values, t->data, nread * sizeof(double));
            }
            data_free_grid(out);
            stamp_one(out, kind);
            out->grid.nx = read_nx;
            out->grid.ny = read_ny;
            out->grid.nvalues = (int)nread;
            out->grid.values = values;
            return 0;
        }

        case TD_TENSOR:
        case TD_TENSOR_VIEW: {
            kiln_tensor_dir_t dir;
            const kiln_tensor_t *t;
            uint64_t rows, cols, n64;
            size_t nbytes;
            err = kiln_asm_decode_tensors(buf, len, &dir, &arena, NULL, &res);
            if (err != KILN_OK || dir.count != 1 || !dir.items) return -1;
            t = &dir.items[0];
            if (t->dtype != KILN_DTYPE_F32 || t->rank != 2) return -1;
            rows = t->shape[0];
            cols = t->shape[1];
            n64 = rows * cols;
            if (rows > 0x7fffffffULL || cols > 0x7fffffffULL || n64 > 0x7fffffffULL) return -1;
            nbytes = (size_t)n64 * sizeof(float);
            if (t->data_len != (uint64_t)nbytes) return -1;
            data_free_grid(out);
            stamp_one(out, kind);
            out->tensor.rows = (int32_t)rows;
            out->tensor.cols = (int32_t)cols;
            out->tensor.nvalues = (int)n64;
            if (kind == TD_TENSOR_VIEW) {
                /* Verify zero-copy borrowed pointer lies within [buf, buf + len]. */
                uintptr_t b0 = (uintptr_t)buf;
                uintptr_t b1 = b0 + len;
                uintptr_t p0 = (uintptr_t)t->data;
                if (nbytes > 0 && (p0 < b0 || p0 > b1 || nbytes > b1 - p0)) return -1;
                out->tensor.values = (float *)(uintptr_t)t->data;
                out->tensor.values_owned = 0;
            } else {
                float *vals = nbytes ? (float *)malloc(nbytes) : NULL;
                if (nbytes && !vals) return -1;
                if (nbytes) memcpy(vals, t->data, nbytes);
                out->tensor.values = vals;
                out->tensor.values_owned = 1;
            }
            return 0;
        }

        case TD_PROMPT: {
            kiln_tensor_dir_t dir;
            err = kiln_asm_decode_tensors(buf, len, &dir, &arena, NULL, &res);
            if (err != KILN_OK) return -1;
            data_free_grid(out);
            stamp_one(out, kind);
            return read_prompt_tensors(&dir, &out->prompt);
        }

        case TD_SHARD: {
            kiln_tensor_dir_t dir;
            uint64_t vocab, hidden, ffn;
            size_t b_tok, b_attn, b_ffn, b_norm;
            float *tok = NULL, *attn = NULL, *ffnw = NULL, *norm = NULL;
            err = kiln_asm_decode_tensors(buf, len, &dir, &arena, NULL, &res);
            if (err != KILN_OK || dir.count != 4 || !dir.items) return -1;
            for (int i = 0; i < 4; i++) {
                if (dir.items[i].dtype != KILN_DTYPE_F32) return -1;
            }
            if (dir.items[0].rank != 2 || dir.items[1].rank != 2 ||
                dir.items[2].rank != 2 || dir.items[3].rank != 1)
                return -1;
            vocab = dir.items[0].shape[0];
            hidden = dir.items[0].shape[1];
            ffn = dir.items[2].shape[0];
            if (dir.items[1].shape[0] != hidden || dir.items[1].shape[1] != hidden ||
                dir.items[2].shape[1] != hidden || dir.items[3].shape[0] != hidden)
                return -1;
            b_tok = (size_t)dir.items[0].data_len;
            b_attn = (size_t)dir.items[1].data_len;
            b_ffn = (size_t)dir.items[2].data_len;
            b_norm = (size_t)dir.items[3].data_len;
            tok = b_tok ? (float *)malloc(b_tok) : NULL;
            attn = b_attn ? (float *)malloc(b_attn) : NULL;
            ffnw = b_ffn ? (float *)malloc(b_ffn) : NULL;
            norm = b_norm ? (float *)malloc(b_norm) : NULL;
            if ((b_tok && !tok) || (b_attn && !attn) || (b_ffn && !ffnw) || (b_norm && !norm)) {
                free(tok); free(attn); free(ffnw); free(norm);
                return -1;
            }
            if (b_tok) memcpy(tok, dir.items[0].data, b_tok);
            if (b_attn) memcpy(attn, dir.items[1].data, b_attn);
            if (b_ffn) memcpy(ffnw, dir.items[2].data, b_ffn);
            if (b_norm) memcpy(norm, dir.items[3].data, b_norm);
            data_free_grid(out);
            stamp_one(out, kind);
            out->shard.vocab = (int32_t)vocab;
            out->shard.hidden = (int32_t)hidden;
            out->shard.ffn = (int32_t)ffn;
            out->shard.n_tok = (int)(b_tok / sizeof(float));
            out->shard.n_attn = (int)(b_attn / sizeof(float));
            out->shard.n_ffn = (int)(b_ffn / sizeof(float));
            out->shard.n_norm = (int)(b_norm / sizeof(float));
            out->shard.tok_emb = tok;
            out->shard.attn = attn;
            out->shard.ffn_weight = ffnw;
            out->shard.norm = norm;
            return 0;
        }

        case TD_REQUEST: {
            bench_request_t rq;
            err = kiln_asm_decode_bench_request(buf, len, &rq, &arena, NULL, &res);
            if (err != KILN_OK) return -1;
            data_free_grid(out);
            stamp_one(out, kind);
            out->request.request_id = rq.request_id;
            if (copy_kstr(out->request.model, sizeof out->request.model, rq.model)) return -1;
            out->request.temperature = rq.temperature;
            return read_prompt_tensors(&rq.inputs, &out->request.inputs);
        }

        default:
            return -1;
    }
}

/* ---------- Bit-exact fidelity ---------- */

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

static bool fid_grid(const test_fixture_t *a, const test_fixture_t *b) {
    const grid_t *src = &a->grid;
    const grid_t *got = &b->grid;
    if (!src->values || !got->values) return false;
    if (a->kind == TD_GRID_WINDOW) {
        int expect = src->wx * src->wy;
        int i = 0;
        if (got->nvalues != expect) return false;
        for (int y = src->y0; y < src->y0 + src->wy; y++) {
            for (int x = src->x0; x < src->x0 + src->wx; x++) {
                double want = src->values[(size_t)y * (size_t)src->nx + (size_t)x];
                if (got->values[i] != want) return false;
                i++;
            }
        }
        return true;
    }
    if (got->nvalues != src->nx * src->ny) return false;
    return memcmp(src->values, got->values, (size_t)got->nvalues * sizeof(double)) == 0;
}

static bool kiln_asm_fidelity(const test_fixture_t *a, const test_fixture_t *b) {
    if (!a || !b || a->kind != b->kind) return false;
    switch (a->kind) {
        case TD_GRID:
        case TD_GRID_WINDOW:
            return fid_grid(a, b);
        case TD_TENSOR:
        case TD_TENSOR_VIEW:
            if (a->tensor.rows != b->tensor.rows || a->tensor.cols != b->tensor.cols ||
                a->tensor.nvalues != b->tensor.nvalues)
                return false;
            return same_f32_bits(a->tensor.values, b->tensor.values, a->tensor.nvalues);
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

void bench_register_kiln_asm(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "gld-kiln-asm", kiln_asm_version(), "binary", prep, ser, de, kiln_asm_fidelity);
    o[*c - 1].owns_batch = 1;
    o[*c - 1].supports = supports_kiln_asm;
}
