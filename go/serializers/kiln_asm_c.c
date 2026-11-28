/* C bridge for Go cgo harness -> shared build/kiln-asm/libkiln_asm_bench.a.
 * All functions accept flat pointer arguments (no Go pointers inside C structs -> cgocheck=2 clean).
 * Full RFC 3629 UTF-8 validation is always active (KILN_OPT_TRUSTED is never set).
 */
#include "kiln_asm_c.h"
#include "kiln_asm_bench.h"

#include <stdlib.h>
#include <string.h>

#define KILN_DTYPE_F32 2U
#define KILN_DTYPE_I64 14U
#define KILN_LARGE_CAP (1ULL << 28)

typedef struct go_buf_t {
    uint8_t *ptr;
    size_t cap;
} go_buf_t;

struct go_kiln_ctx_t {
    go_buf_t out;
    go_buf_t arena;
    go_buf_t enc;
};

static inline uint8_t *buf_reserve(go_buf_t *b, size_t need) {
    if (need < 4096) need = 4096;
    if (b->cap >= need) return b->ptr;
    size_t next = b->cap ? b->cap * 2 : need;
    if (next < need) next = need;
    uint8_t *p = (uint8_t *)realloc(b->ptr, next);
    if (!p) return NULL;
    b->ptr = p;
    b->cap = next;
    return p;
}

static inline size_t align16(size_t n) {
    return (n + 15u) & ~(size_t)15u;
}

static inline void span_of(const uint8_t *wire, kiln_str_t s, uint32_t *dst) {
    dst[0] = (s.len > 0 && s.ptr) ? (uint32_t)(s.ptr - wire) : 0u;
    dst[1] = (uint32_t)s.len;
}

static inline void set_tensor_2d(kiln_tensor_t *t, uint16_t dtype, uint64_t d0, uint64_t d1,
                                 const void *data, size_t nbytes) {
    kiln_tensor_init(t);
    t->dtype = dtype;
    t->rank = 2;
    t->shape[0] = d0;
    t->shape[1] = d1;
    t->data = (const uint8_t *)data;
    t->data_len = (uint64_t)nbytes;
}

static inline void set_tensor_1d(kiln_tensor_t *t, uint16_t dtype, uint64_t d0,
                                 const void *data, size_t nbytes) {
    kiln_tensor_init(t);
    t->dtype = dtype;
    t->rank = 1;
    t->shape[0] = d0;
    t->data = (const uint8_t *)data;
    t->data_len = (uint64_t)nbytes;
}

go_kiln_ctx_t *go_kiln_ctx_new(void) {
    return (go_kiln_ctx_t *)calloc(1, sizeof(go_kiln_ctx_t));
}

void go_kiln_ctx_free(go_kiln_ctx_t *ctx) {
    if (!ctx) return;
    free(ctx->out.ptr);
    free(ctx->arena.ptr);
    free(ctx->enc.ptr);
    free(ctx);
}

const uint8_t *go_kiln_ctx_out_ptr(const go_kiln_ctx_t *ctx) {
    return ctx ? ctx->out.ptr : NULL;
}

const char *go_kiln_version(void) {
    return kiln_asm_version();
}

/* ==================== MESSAGE ==================== */

int go_kiln_encode_message(
    go_kiln_ctx_t *ctx,
    uint8_t b1, int32_t i1, int64_t l1, double d1,
    const uint8_t *s1, size_t n1,
    uint8_t b2, int32_t i2,
    const uint8_t *s2, size_t n2,
    size_t *out_len) {
    uint8_t *out = buf_reserve(&ctx->out, n1 + n2 + 64);
    if (!out) return -1;
    bench_message_t m;
    m.f_bool = b1 ? 1 : 0;
    m.f_int32 = i1;
    m.f_int64 = l1;
    m.f_float64 = d1;
    m.f_string.ptr = s1;
    m.f_string.len = n1;
    m.f_bool_2 = b2 ? 1 : 0;
    m.f_int32_2 = i2;
    m.f_string_2.ptr = s2;
    m.f_string_2.len = n2;
    kiln_result_t res = {0, 0};
    kiln_err_t err = kiln_asm_encode_bench_message(&m, out, ctx->out.cap, NULL, &res);
    *out_len = (size_t)res.bytes;
    return (int)err;
}

int go_kiln_encode_message_batch(
    go_kiln_ctx_t *ctx, size_t count,
    const uint8_t *bools, const int32_t *ints, const int64_t *longs, const double *doubles,
    const uint8_t *str_buf, const uint32_t *str_lens,
    size_t *out_len) {
    bench_message_t *arr = (bench_message_t *)buf_reserve(&ctx->enc, count * sizeof(bench_message_t) + 64);
    if (!arr) return -1;
    size_t off = 0;
    for (size_t i = 0; i < count; i++) {
        arr[i].f_bool = bools[2 * i] ? 1 : 0;
        arr[i].f_int32 = ints[2 * i];
        arr[i].f_int64 = longs[i];
        arr[i].f_float64 = doubles[i];
        uint32_t l1 = str_lens[2 * i];
        arr[i].f_string.ptr = l1 ? str_buf + off : NULL;
        arr[i].f_string.len = l1;
        off += l1;
        arr[i].f_bool_2 = bools[2 * i + 1] ? 1 : 0;
        arr[i].f_int32_2 = ints[2 * i + 1];
        uint32_t l2 = str_lens[2 * i + 1];
        arr[i].f_string_2.ptr = l2 ? str_buf + off : NULL;
        arr[i].f_string_2.len = l2;
        off += l2;
    }
    uint8_t *out = buf_reserve(&ctx->out, off + count * 48 + 64);
    if (!out) return -1;
    kiln_result_t res = {0, 0};
    kiln_err_t err = kiln_asm_encode_bench_message_batch(arr, count, out, ctx->out.cap, NULL, &res);
    *out_len = (size_t)res.bytes;
    return (int)err;
}

int go_kiln_decode_message(
    go_kiln_ctx_t *ctx, int batch,
    const uint8_t *wire, size_t wlen,
    uint8_t *out_bools, int32_t *out_ints, int64_t *out_longs, double *out_doubles,
    size_t cap_items, size_t *out_count) {
    uint8_t *abuf = buf_reserve(&ctx->arena, wlen * 4 + 65536);
    if (!abuf) return -1;
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, ctx->arena.cap);
    kiln_result_t res = {0, 0};

    if (!batch) {
        bench_message_t m;
        kiln_err_t err = kiln_asm_decode_bench_message(wire, wlen, &m, &arena, NULL, &res);
        if (err != KILN_OK) return (int)err;
        *out_count = 1;
        if (cap_items < 1) return -2;
        out_bools[0] = m.f_bool; out_bools[1] = m.f_bool_2;
        out_ints[0] = m.f_int32; out_ints[1] = m.f_int32_2;
        span_of(wire, m.f_string, (uint32_t *)&out_ints[2]);
        span_of(wire, m.f_string_2, (uint32_t *)&out_ints[4]);
        out_longs[0] = m.f_int64;
        out_doubles[0] = m.f_float64;
        return 0;
    }

    bench_message_t *arr = NULL; size_t cnt = 0;
    kiln_err_t err = kiln_asm_decode_bench_message_batch(wire, wlen, &arr, &cnt, &arena, NULL, &res);
    if (err != KILN_OK) return (int)err;
    *out_count = cnt;
    if (cnt > cap_items) return -2;
    for (size_t i = 0; i < cnt; i++) {
        out_bools[2 * i] = arr[i].f_bool;
        out_bools[2 * i + 1] = arr[i].f_bool_2;
        out_ints[6 * i + 0] = arr[i].f_int32;
        out_ints[6 * i + 1] = arr[i].f_int32_2;
        span_of(wire, arr[i].f_string, (uint32_t *)&out_ints[6 * i + 2]);
        span_of(wire, arr[i].f_string_2, (uint32_t *)&out_ints[6 * i + 4]);
        out_longs[i] = arr[i].f_int64;
        out_doubles[i] = arr[i].f_float64;
    }
    return 0;
}

/* ==================== DOCUMENT & NESTED_ROW ==================== */

int go_kiln_encode_document(
    go_kiln_ctx_t *ctx, int is_nested, int batch, size_t n_docs,
    const int32_t *doc_ints, const uint32_t *item_counts,
    const int32_t *item_qtys, const int64_t *item_prices,
    const uint8_t *str_buf, const uint32_t *str_lens,
    size_t *out_len) {
    size_t total_items = 0;
    for (size_t i = 0; i < n_docs; i++) total_items += item_counts[i];
    size_t docs_sz = align16(n_docs * sizeof(bench_document_t));
    size_t items_sz = align16(total_items * sizeof(bench_document_document_item_t));
    uint8_t *enc = buf_reserve(&ctx->enc, docs_sz + items_sz + 64);
    if (!enc) return -1;
    bench_document_t *docs = (bench_document_t *)enc;
    bench_document_document_item_t *items = (bench_document_document_item_t *)(enc + docs_sz);

    size_t spos = 0, sl_i = 0, ipos = 0;
    for (size_t i = 0; i < n_docs; i++) {
        uint32_t l_id = str_lens[sl_i++];
        docs[i].id.ptr = l_id ? str_buf + spos : NULL;
        docs[i].id.len = l_id; spos += l_id;
        docs[i].status = doc_ints[2 * i];
        uint32_t l_reg = str_lens[sl_i++];
        docs[i].meta.region.ptr = l_reg ? str_buf + spos : NULL;
        docs[i].meta.region.len = l_reg; spos += l_reg;
        docs[i].meta.version = doc_ints[2 * i + 1];
        uint32_t ic = item_counts[i];
        docs[i].items.items = ic ? &items[ipos] : NULL;
        docs[i].items.count = ic;
        for (uint32_t j = 0; j < ic; j++) {
            uint32_t l_sku = str_lens[sl_i++];
            items[ipos].sku.ptr = l_sku ? str_buf + spos : NULL;
            items[ipos].sku.len = l_sku; spos += l_sku;
            items[ipos].qty = item_qtys[ipos];
            items[ipos].price_minor = item_prices[ipos];
            ipos++;
        }
    }

    uint8_t *out = buf_reserve(&ctx->out, spos + n_docs * 48 + total_items * 32 + 64);
    if (!out) return -1;
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    kiln_err_t err;
    if (!batch) {
        err = is_nested
            ? kiln_asm_encode_bench_nested_row((const bench_nested_row_t *)docs, out, ctx->out.cap, &opts, &res)
            : kiln_asm_encode_bench_document(docs, out, ctx->out.cap, &opts, &res);
    } else {
        err = is_nested
            ? kiln_asm_encode_bench_nested_row_batch((const bench_nested_row_t *)docs, n_docs, out, ctx->out.cap, &opts, &res)
            : kiln_asm_encode_bench_document_batch(docs, n_docs, out, ctx->out.cap, &opts, &res);
    }
    *out_len = (size_t)res.bytes;
    return (int)err;
}

int go_kiln_decode_document(
    go_kiln_ctx_t *ctx, int is_nested, int batch,
    const uint8_t *wire, size_t wlen,
    int32_t *doc_ints, uint32_t *item_counts, uint32_t *doc_str_spans,
    size_t cap_docs,
    int32_t *item_qtys, int64_t *item_prices, uint32_t *item_str_spans,
    size_t cap_items,
    size_t *out_docs, size_t *out_items) {
    uint8_t *abuf = buf_reserve(&ctx->arena, wlen * 6 + 131072);
    if (!abuf) return -1;
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, ctx->arena.cap);
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};

    bench_document_t single;
    bench_document_t *arr = &single;
    size_t n_docs = 1;
    kiln_err_t err;
    if (!batch) {
        err = is_nested
            ? kiln_asm_decode_bench_nested_row(wire, wlen, (bench_nested_row_t *)&single, &arena, &opts, &res)
            : kiln_asm_decode_bench_document(wire, wlen, &single, &arena, &opts, &res);
    } else {
        err = is_nested
            ? kiln_asm_decode_bench_nested_row_batch(wire, wlen, (bench_nested_row_t **)&arr, &n_docs, &arena, &opts, &res)
            : kiln_asm_decode_bench_document_batch(wire, wlen, &arr, &n_docs, &arena, &opts, &res);
    }
    if (err != KILN_OK) return (int)err;

    size_t total_items = 0;
    for (size_t i = 0; i < n_docs; i++) total_items += (size_t)arr[i].items.count;
    *out_docs = n_docs;
    *out_items = total_items;
    if (n_docs > cap_docs || total_items > cap_items) return -2;

    size_t ipos = 0;
    for (size_t i = 0; i < n_docs; i++) {
        doc_ints[2 * i] = arr[i].status;
        doc_ints[2 * i + 1] = arr[i].meta.version;
        item_counts[i] = (uint32_t)arr[i].items.count;
        span_of(wire, arr[i].id, &doc_str_spans[4 * i]);
        span_of(wire, arr[i].meta.region, &doc_str_spans[4 * i + 2]);
        for (uint64_t j = 0; j < arr[i].items.count; j++) {
            item_qtys[ipos] = arr[i].items.items[j].qty;
            item_prices[ipos] = arr[i].items.items[j].price_minor;
            span_of(wire, arr[i].items.items[j].sku, &item_str_spans[2 * ipos]);
            ipos++;
        }
    }
    return 0;
}

/* ==================== TELEMETRY ==================== */

int go_kiln_encode_telemetry(
    go_kiln_ctx_t *ctx, int batch, size_t n_rows,
    const int64_t *ts, const uint32_t *tag_counts, const uint32_t *val_counts,
    const double *all_vals,
    const uint8_t *str_buf, const uint32_t *str_lens,
    size_t *out_len) {
    size_t total_tags = 0, total_vals = 0;
    for (size_t i = 0; i < n_rows; i++) {
        total_tags += tag_counts[i];
        total_vals += val_counts[i];
    }
    size_t tels_sz = align16(n_rows * sizeof(bench_telemetry_t));
    size_t tags_sz = align16(total_tags * sizeof(kiln_str_t));
    uint8_t *enc = buf_reserve(&ctx->enc, tels_sz + tags_sz + 64);
    if (!enc) return -1;
    bench_telemetry_t *tels = (bench_telemetry_t *)enc;
    kiln_str_t *tags = (kiln_str_t *)(enc + tels_sz);

    size_t spos = 0, sl_i = 0, tpos = 0, vpos = 0;
    for (size_t i = 0; i < n_rows; i++) {
        uint32_t l_src = str_lens[sl_i++];
        tels[i].source.ptr = l_src ? str_buf + spos : NULL;
        tels[i].source.len = l_src; spos += l_src;
        tels[i].ts = ts[i];
        uint32_t tc = tag_counts[i];
        tels[i].tags.items = tc ? &tags[tpos] : NULL;
        tels[i].tags.count = tc;
        for (uint32_t j = 0; j < tc; j++) {
            uint32_t l_t = str_lens[sl_i++];
            tags[tpos].ptr = l_t ? str_buf + spos : NULL;
            tags[tpos].len = l_t; spos += l_t;
            tpos++;
        }
        uint32_t vc = val_counts[i];
        tels[i].values.items = vc ? (double *)(uintptr_t)(all_vals + vpos) : NULL;
        tels[i].values.count = vc;
        vpos += vc;
    }

    uint8_t *out = buf_reserve(&ctx->out, spos + n_rows * 32 + total_tags * 8 + total_vals * 8 + 64);
    if (!out) return -1;
    kiln_result_t res = {0, 0};
    kiln_err_t err = batch
        ? kiln_asm_encode_bench_telemetry_batch(tels, n_rows, out, ctx->out.cap, NULL, &res)
        : kiln_asm_encode_bench_telemetry(tels, out, ctx->out.cap, NULL, &res);
    *out_len = (size_t)res.bytes;
    return (int)err;
}

int go_kiln_decode_telemetry(
    go_kiln_ctx_t *ctx, int batch,
    const uint8_t *wire, size_t wlen,
    int64_t *ts, uint32_t *tag_counts, uint32_t *val_counts, uint32_t *src_spans,
    size_t cap_rows,
    uint32_t *tag_spans, size_t cap_tags,
    double *all_vals, size_t cap_vals,
    size_t *out_rows, size_t *out_tags, size_t *out_vals) {
    uint8_t *abuf = buf_reserve(&ctx->arena, wlen * 4 + 65536);
    if (!abuf) return -1;
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, ctx->arena.cap);
    kiln_result_t res = {0, 0};

    bench_telemetry_t single;
    bench_telemetry_t *arr = &single;
    size_t n_rows = 1;
    kiln_err_t err = batch
        ? kiln_asm_decode_bench_telemetry_batch(wire, wlen, &arr, &n_rows, &arena, NULL, &res)
        : kiln_asm_decode_bench_telemetry(wire, wlen, &single, &arena, NULL, &res);
    if (err != KILN_OK) return (int)err;

    size_t total_tags = 0, total_vals = 0;
    for (size_t i = 0; i < n_rows; i++) {
        total_tags += (size_t)arr[i].tags.count;
        total_vals += (size_t)arr[i].values.count;
    }
    *out_rows = n_rows; *out_tags = total_tags; *out_vals = total_vals;
    if (n_rows > cap_rows || total_tags > cap_tags || total_vals > cap_vals) return -2;

    size_t tpos = 0, vpos = 0;
    for (size_t i = 0; i < n_rows; i++) {
        ts[i] = arr[i].ts;
        tag_counts[i] = (uint32_t)arr[i].tags.count;
        val_counts[i] = (uint32_t)arr[i].values.count;
        span_of(wire, arr[i].source, &src_spans[2 * i]);
        for (uint64_t j = 0; j < arr[i].tags.count; j++) {
            span_of(wire, arr[i].tags.items[j], &tag_spans[2 * tpos++]);
        }
        if (arr[i].values.count > 0) {
            memcpy(all_vals + vpos, arr[i].values.items, (size_t)arr[i].values.count * sizeof(double));
            vpos += (size_t)arr[i].values.count;
        }
    }
    return 0;
}

/* ==================== STRINGS ==================== */

int go_kiln_encode_strings(
    go_kiln_ctx_t *ctx, int batch, size_t n_rows,
    const uint32_t *item_counts,
    const uint8_t *str_buf, const uint32_t *str_lens,
    size_t *out_len) {
    size_t total = 0;
    for (size_t i = 0; i < n_rows; i++) total += item_counts[i];
    size_t hdr_sz = align16(n_rows * sizeof(bench_strings_t));
    size_t arr_sz = align16(total * sizeof(kiln_str_t));
    uint8_t *enc = buf_reserve(&ctx->enc, hdr_sz + arr_sz + 64);
    if (!enc) return -1;
    bench_strings_t *ss = (bench_strings_t *)enc;
    kiln_str_t *all_s = (kiln_str_t *)(enc + hdr_sz);

    size_t spos = 0, pos = 0;
    for (size_t i = 0; i < n_rows; i++) {
        uint32_t ic = item_counts[i];
        ss[i].items.items = ic ? &all_s[pos] : NULL;
        ss[i].items.count = ic;
        for (uint32_t j = 0; j < ic; j++) {
            uint32_t l = str_lens[pos];
            all_s[pos].ptr = l ? str_buf + spos : NULL;
            all_s[pos].len = l;
            spos += l;
            pos++;
        }
    }
    uint8_t *out = buf_reserve(&ctx->out, spos + n_rows * 8 + total * 8 + 64);
    if (!out) return -1;
    kiln_result_t res = {0, 0};
    kiln_err_t err = batch
        ? kiln_asm_encode_bench_strings_batch(ss, n_rows, out, ctx->out.cap, NULL, &res)
        : kiln_asm_encode_bench_strings(ss, out, ctx->out.cap, NULL, &res);
    *out_len = (size_t)res.bytes;
    return (int)err;
}

int go_kiln_decode_strings(
    go_kiln_ctx_t *ctx, int batch,
    const uint8_t *wire, size_t wlen,
    uint32_t *item_counts, size_t cap_rows,
    uint32_t *str_spans, size_t cap_strs,
    size_t *out_rows, size_t *out_strs) {
    uint8_t *abuf = buf_reserve(&ctx->arena, wlen * 4 + 65536);
    if (!abuf) return -1;
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, ctx->arena.cap);
    kiln_result_t res = {0, 0};

    bench_strings_t single;
    bench_strings_t *arr = &single;
    size_t n_rows = 1;
    kiln_err_t err = batch
        ? kiln_asm_decode_bench_strings_batch(wire, wlen, &arr, &n_rows, &arena, NULL, &res)
        : kiln_asm_decode_bench_strings(wire, wlen, &single, &arena, NULL, &res);
    if (err != KILN_OK) return (int)err;

    size_t total = 0;
    for (size_t i = 0; i < n_rows; i++) total += (size_t)arr[i].items.count;
    *out_rows = n_rows; *out_strs = total;
    if (n_rows > cap_rows || total > cap_strs) return -2;

    size_t pos = 0;
    for (size_t i = 0; i < n_rows; i++) {
        item_counts[i] = (uint32_t)arr[i].items.count;
        for (uint64_t j = 0; j < arr[i].items.count; j++) {
            span_of(wire, arr[i].items.items[j], &str_spans[2 * pos++]);
        }
    }
    return 0;
}

/* ==================== EVENT ==================== */

int go_kiln_encode_event(
    go_kiln_ctx_t *ctx, int batch, size_t n_rows,
    const int64_t *occ, const uint32_t *attr_counts,
    const uint8_t *str_buf, const uint32_t *str_lens,
    size_t *out_len) {
    size_t total_attrs = 0;
    for (size_t i = 0; i < n_rows; i++) total_attrs += attr_counts[i];
    size_t ev_sz = align16(n_rows * sizeof(bench_event_t));
    size_t at_sz = align16(total_attrs * sizeof(bench_event_event_attr_t));
    uint8_t *enc = buf_reserve(&ctx->enc, ev_sz + at_sz + 64);
    if (!enc) return -1;
    bench_event_t *evs = (bench_event_t *)enc;
    bench_event_event_attr_t *attrs = (bench_event_event_attr_t *)(enc + ev_sz);

    size_t spos = 0, sl_i = 0, apos = 0;
    for (size_t i = 0; i < n_rows; i++) {
        uint32_t l0 = str_lens[sl_i++];
        evs[i].event_id.ptr = l0 ? str_buf + spos : NULL; evs[i].event_id.len = l0; spos += l0;
        uint32_t l1 = str_lens[sl_i++];
        evs[i].event_type.ptr = l1 ? str_buf + spos : NULL; evs[i].event_type.len = l1; spos += l1;
        evs[i].occurred_at = occ[i];
        uint32_t l2 = str_lens[sl_i++];
        evs[i].producer.ptr = l2 ? str_buf + spos : NULL; evs[i].producer.len = l2; spos += l2;
        uint32_t ac = attr_counts[i];
        evs[i].attrs.items = ac ? &attrs[apos] : NULL;
        evs[i].attrs.count = ac;
        for (uint32_t j = 0; j < ac; j++) {
            uint32_t lk = str_lens[sl_i++];
            attrs[apos].key.ptr = lk ? str_buf + spos : NULL; attrs[apos].key.len = lk; spos += lk;
            uint32_t lv = str_lens[sl_i++];
            attrs[apos].value.ptr = lv ? str_buf + spos : NULL; attrs[apos].value.len = lv; spos += lv;
            apos++;
        }
    }
    uint8_t *out = buf_reserve(&ctx->out, spos + n_rows * 48 + total_attrs * 16 + 64);
    if (!out) return -1;
    kiln_result_t res = {0, 0};
    kiln_err_t err = batch
        ? kiln_asm_encode_bench_event_batch(evs, n_rows, out, ctx->out.cap, NULL, &res)
        : kiln_asm_encode_bench_event(evs, out, ctx->out.cap, NULL, &res);
    *out_len = (size_t)res.bytes;
    return (int)err;
}

int go_kiln_decode_event(
    go_kiln_ctx_t *ctx, int batch,
    const uint8_t *wire, size_t wlen,
    int64_t *occ, uint32_t *attr_counts, uint32_t *ev_str_spans,
    size_t cap_rows,
    uint32_t *attr_str_spans, size_t cap_attrs,
    size_t *out_rows, size_t *out_attrs) {
    uint8_t *abuf = buf_reserve(&ctx->arena, wlen * 4 + 65536);
    if (!abuf) return -1;
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, ctx->arena.cap);
    kiln_result_t res = {0, 0};

    bench_event_t single;
    bench_event_t *arr = &single;
    size_t n_rows = 1;
    kiln_err_t err = batch
        ? kiln_asm_decode_bench_event_batch(wire, wlen, &arr, &n_rows, &arena, NULL, &res)
        : kiln_asm_decode_bench_event(wire, wlen, &single, &arena, NULL, &res);
    if (err != KILN_OK) return (int)err;

    size_t total_attrs = 0;
    for (size_t i = 0; i < n_rows; i++) total_attrs += (size_t)arr[i].attrs.count;
    *out_rows = n_rows; *out_attrs = total_attrs;
    if (n_rows > cap_rows || total_attrs > cap_attrs) return -2;

    size_t apos = 0;
    for (size_t i = 0; i < n_rows; i++) {
        occ[i] = arr[i].occurred_at;
        attr_counts[i] = (uint32_t)arr[i].attrs.count;
        span_of(wire, arr[i].event_id, &ev_str_spans[6 * i + 0]);
        span_of(wire, arr[i].event_type, &ev_str_spans[6 * i + 2]);
        span_of(wire, arr[i].producer, &ev_str_spans[6 * i + 4]);
        for (uint64_t j = 0; j < arr[i].attrs.count; j++) {
            span_of(wire, arr[i].attrs.items[j].key, &attr_str_spans[4 * apos + 0]);
            span_of(wire, arr[i].attrs.items[j].value, &attr_str_spans[4 * apos + 2]);
            apos++;
        }
    }
    return 0;
}

/* ==================== COLUMNAR: TABLE & TABLE_PROJECT ==================== */

int go_kiln_encode_table(
    go_kiln_ctx_t *ctx, size_t n_rows,
    const double *floats_col_major, const int64_t *ints_col_major,
    const uint8_t *str_buf, const uint32_t *str_lens,
    size_t *out_len) {
    kiln_str_t *sbuf = (kiln_str_t *)buf_reserve(&ctx->enc, n_rows * 2 * sizeof(kiln_str_t) + 64);
    if (!sbuf) return -1;
    size_t spos = 0;
    for (size_t i = 0; i < n_rows * 2; i++) {
        uint32_t l = str_lens[i];
        sbuf[i].ptr = l ? str_buf + spos : NULL;
        sbuf[i].len = l;
        spos += l;
    }

    bench_table_columns_t cols;
    bench_table_columns_list_f64_t *fc[16] = {
        &cols.f_float_0, &cols.f_float_1, &cols.f_float_2, &cols.f_float_3,
        &cols.f_float_4, &cols.f_float_5, &cols.f_float_6, &cols.f_float_7,
        &cols.f_float_8, &cols.f_float_9, &cols.f_float_10, &cols.f_float_11,
        &cols.f_float_12, &cols.f_float_13, &cols.f_float_14, &cols.f_float_15
    };
    for (int c = 0; c < 16; c++) {
        fc[c]->items = n_rows ? (double *)(uintptr_t)(floats_col_major + (size_t)c * n_rows) : NULL;
        fc[c]->count = n_rows;
    }
    bench_table_columns_list_i64_t *ic[4] = {
        &cols.f_int_0, &cols.f_int_1, &cols.f_int_2, &cols.f_int_3
    };
    for (int c = 0; c < 4; c++) {
        ic[c]->items = n_rows ? (int64_t *)(uintptr_t)(ints_col_major + (size_t)c * n_rows) : NULL;
        ic[c]->count = n_rows;
    }
    cols.f_str_0.items = n_rows ? &sbuf[0] : NULL;
    cols.f_str_0.count = n_rows;
    cols.f_str_1.items = n_rows ? &sbuf[n_rows] : NULL;
    cols.f_str_1.count = n_rows;

    uint8_t *out = buf_reserve(&ctx->out, 256 + n_rows * (16 * 8 + 4 * 8 + 2 * 4) + spos);
    if (!out) return -1;
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    kiln_err_t err = kiln_asm_encode_bench_table_columns(&cols, out, ctx->out.cap, &opts, &res);
    *out_len = (size_t)res.bytes;
    return (int)err;
}

int go_kiln_decode_table(
    go_kiln_ctx_t *ctx,
    const uint8_t *wire, size_t wlen,
    double *floats_col_major, int64_t *ints_col_major, uint32_t *str_spans,
    size_t cap_rows, size_t *out_rows) {
    uint8_t *abuf = buf_reserve(&ctx->arena, wlen * 4 + 131072);
    if (!abuf) return -1;
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, ctx->arena.cap);
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    bench_table_columns_t cols;
    kiln_err_t err = kiln_asm_decode_bench_table_columns(wire, wlen, &cols, &arena, &opts, &res);
    if (err != KILN_OK) return (int)err;

    const bench_table_columns_list_f64_t *fc[16] = {
        &cols.f_float_0, &cols.f_float_1, &cols.f_float_2, &cols.f_float_3,
        &cols.f_float_4, &cols.f_float_5, &cols.f_float_6, &cols.f_float_7,
        &cols.f_float_8, &cols.f_float_9, &cols.f_float_10, &cols.f_float_11,
        &cols.f_float_12, &cols.f_float_13, &cols.f_float_14, &cols.f_float_15
    };
    const bench_table_columns_list_i64_t *ic[4] = {
        &cols.f_int_0, &cols.f_int_1, &cols.f_int_2, &cols.f_int_3
    };
    size_t n = (size_t)cols.f_float_0.count;
    *out_rows = n;
    if (n > cap_rows) return -2;

    if (n > 0) {
        for (int c = 0; c < 16; c++) memcpy(floats_col_major + (size_t)c * n, fc[c]->items, n * sizeof(double));
        for (int c = 0; c < 4; c++) memcpy(ints_col_major + (size_t)c * n, ic[c]->items, n * sizeof(int64_t));
        for (size_t r = 0; r < n; r++) {
            span_of(wire, cols.f_str_0.items[r], &str_spans[4 * r + 0]);
            span_of(wire, cols.f_str_1.items[r], &str_spans[4 * r + 2]);
        }
    }
    return 0;
}

int go_kiln_decode_table_project(
    go_kiln_ctx_t *ctx,
    const uint8_t *wire, size_t wlen,
    double *out_f0, size_t cap_rows, size_t *out_rows) {
    uint8_t *abuf = buf_reserve(&ctx->arena, wlen + 65536);
    if (!abuf) return -1;
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, ctx->arena.cap);
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, KILN_OPT_EMBEDDED };
    kiln_result_t res = {0, 0};
    bench_table_project_t proj;
    kiln_err_t err = kiln_asm_decode_bench_table_project(wire, wlen, &proj, &arena, &opts, &res);
    if (err != KILN_OK) return (int)err;

    size_t n = (size_t)proj.f_float_0.count;
    *out_rows = n;
    if (n > cap_rows) return -2;
    if (n > 0) memcpy(out_f0, proj.f_float_0.items, n * sizeof(double));
    return 0;
}

/* ==================== SIGNAL ==================== */

int go_kiln_encode_signal(
    go_kiln_ctx_t *ctx, int batch, size_t n_rows,
    const int64_t *sig_i64, const int32_t *sig_i32, const uint32_t *leg_counts,
    const int64_t *leg_ids, const int32_t *leg_i32,
    const uint8_t *str_buf, const uint32_t *str_lens,
    size_t *out_len) {
    size_t total_legs = 0;
    for (size_t i = 0; i < n_rows; i++) total_legs += leg_counts[i];
    size_t sig_sz = align16(n_rows * sizeof(bench_signal_t));
    size_t leg_sz = align16(total_legs * sizeof(bench_signal_signal_leg_t));
    uint8_t *enc = buf_reserve(&ctx->enc, sig_sz + leg_sz + 64);
    if (!enc) return -1;
    bench_signal_t *sigs = (bench_signal_t *)enc;
    bench_signal_signal_leg_t *legs = (bench_signal_signal_leg_t *)(enc + sig_sz);

    size_t spos = 0, lpos = 0;
    for (size_t i = 0; i < n_rows; i++) {
        sigs[i].seq = sig_i64[3 * i + 0];
        sigs[i].ts = sig_i64[3 * i + 1];
        sigs[i].price_mantissa = sig_i64[3 * i + 2];
        sigs[i].qty = sig_i32[2 * i + 0];
        sigs[i].flags = sig_i32[2 * i + 1];
        uint32_t l0 = str_lens[2 * i + 0];
        sigs[i].symbol.ptr = l0 ? str_buf + spos : NULL; sigs[i].symbol.len = l0; spos += l0;
        uint32_t l1 = str_lens[2 * i + 1];
        sigs[i].venue.ptr = l1 ? str_buf + spos : NULL; sigs[i].venue.len = l1; spos += l1;
        uint32_t lc = leg_counts[i];
        sigs[i].legs.items = lc ? &legs[lpos] : NULL;
        sigs[i].legs.count = lc;
        for (uint32_t j = 0; j < lc; j++) {
            legs[lpos].leg_id = leg_ids[lpos];
            legs[lpos].leg_qty = leg_i32[2 * lpos + 0];
            legs[lpos].leg_pad = leg_i32[2 * lpos + 1];
            lpos++;
        }
    }

    uint8_t *out = buf_reserve(&ctx->out, spos + n_rows * 64 + total_legs * 20 + 64);
    if (!out) return -1;
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    kiln_err_t err = batch
        ? kiln_asm_encode_bench_signal_batch(sigs, n_rows, out, ctx->out.cap, &opts, &res)
        : kiln_asm_encode_bench_signal(sigs, out, ctx->out.cap, &opts, &res);
    *out_len = (size_t)res.bytes;
    return (int)err;
}

int go_kiln_decode_signal(
    go_kiln_ctx_t *ctx, int batch,
    const uint8_t *wire, size_t wlen,
    int64_t *sig_i64, int32_t *sig_i32, uint32_t *leg_counts, uint32_t *sig_str_spans,
    size_t cap_rows,
    int64_t *leg_ids, int32_t *leg_i32, size_t cap_legs,
    size_t *out_rows, size_t *out_legs) {
    uint8_t *abuf = buf_reserve(&ctx->arena, wlen * 4 + 131072);
    if (!abuf) return -1;
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, ctx->arena.cap);
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};

    bench_signal_t single;
    bench_signal_t *arr = &single;
    size_t n_rows = 1;
    kiln_err_t err = batch
        ? kiln_asm_decode_bench_signal_batch(wire, wlen, &arr, &n_rows, &arena, &opts, &res)
        : kiln_asm_decode_bench_signal(wire, wlen, &single, &arena, &opts, &res);
    if (err != KILN_OK) return (int)err;

    size_t total_legs = 0;
    for (size_t i = 0; i < n_rows; i++) total_legs += (size_t)arr[i].legs.count;
    *out_rows = n_rows; *out_legs = total_legs;
    if (n_rows > cap_rows || total_legs > cap_legs) return -2;

    size_t lpos = 0;
    for (size_t i = 0; i < n_rows; i++) {
        sig_i64[3 * i + 0] = arr[i].seq;
        sig_i64[3 * i + 1] = arr[i].ts;
        sig_i64[3 * i + 2] = arr[i].price_mantissa;
        sig_i32[2 * i + 0] = arr[i].qty;
        sig_i32[2 * i + 1] = arr[i].flags;
        leg_counts[i] = (uint32_t)arr[i].legs.count;
        span_of(wire, arr[i].symbol, &sig_str_spans[4 * i + 0]);
        span_of(wire, arr[i].venue, &sig_str_spans[4 * i + 2]);
        for (uint64_t j = 0; j < arr[i].legs.count; j++) {
            leg_ids[lpos] = arr[i].legs.items[j].leg_id;
            leg_i32[2 * lpos + 0] = arr[i].legs.items[j].leg_qty;
            leg_i32[2 * lpos + 1] = arr[i].legs.items[j].leg_pad;
            lpos++;
        }
    }
    return 0;
}

/* ==================== TENSOR, PROMPT, SHARD, REQUEST (KLNT v2) ==================== */

int go_kiln_encode_tensor(
    go_kiln_ctx_t *ctx, int32_t rows, int32_t cols,
    const float *vals, size_t n_vals, size_t *out_len) {
    size_t nbytes = n_vals * sizeof(float);
    uint8_t *out = buf_reserve(&ctx->out, nbytes + 512);
    if (!out) return -1;
    kiln_tensor_t t;
    set_tensor_2d(&t, KILN_DTYPE_F32, (uint64_t)rows, (uint64_t)cols, vals, nbytes);
    kiln_tensor_dir_t dir = { &t, 1, 0, 2, 2 };
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    kiln_err_t err = kiln_asm_encode_tensors(&dir, out, ctx->out.cap, &opts, &res);
    *out_len = (size_t)res.bytes;
    return (int)err;
}

int go_kiln_decode_tensor_meta(
    go_kiln_ctx_t *ctx, const uint8_t *wire, size_t wlen,
    int32_t *out_rows, int32_t *out_cols, size_t *out_off, size_t *out_nbytes) {
    uint8_t *abuf = buf_reserve(&ctx->arena, 4096);
    if (!abuf) return -1;
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, ctx->arena.cap);
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    kiln_tensor_dir_t dir;
    kiln_err_t err = kiln_asm_decode_tensors(wire, wlen, &dir, &arena, &opts, &res);
    if (err != KILN_OK) return (int)err;
    if (dir.count != 1 || dir.items[0].dtype != KILN_DTYPE_F32 || dir.items[0].rank != 2) return KILN_ERR_TYPE;
    *out_rows = (int32_t)dir.items[0].shape[0];
    *out_cols = (int32_t)dir.items[0].shape[1];
    *out_off = dir.items[0].data ? (size_t)(dir.items[0].data - wire) : 0;
    *out_nbytes = (size_t)dir.items[0].data_len;
    return 0;
}

int go_kiln_encode_prompt(
    go_kiln_ctx_t *ctx, int32_t batch, int32_t seq,
    const int64_t *a0, const int64_t *a1, const int64_t *a2, size_t n_elems,
    size_t *out_len) {
    size_t nb = n_elems * sizeof(int64_t);
    uint8_t *out = buf_reserve(&ctx->out, nb * 3 + 1024);
    if (!out) return -1;
    kiln_tensor_t ts[3];
    set_tensor_2d(&ts[0], KILN_DTYPE_I64, (uint64_t)batch, (uint64_t)seq, a0, nb);
    set_tensor_2d(&ts[1], KILN_DTYPE_I64, (uint64_t)batch, (uint64_t)seq, a1, nb);
    set_tensor_2d(&ts[2], KILN_DTYPE_I64, (uint64_t)batch, (uint64_t)seq, a2, nb);
    kiln_tensor_dir_t dir = { ts, 3, 0, 2, 2 };
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    kiln_err_t err = kiln_asm_encode_tensors(&dir, out, ctx->out.cap, &opts, &res);
    *out_len = (size_t)res.bytes;
    return (int)err;
}

int go_kiln_decode_prompt_meta(
    go_kiln_ctx_t *ctx, const uint8_t *wire, size_t wlen,
    int32_t *out_batch, int32_t *out_seq, size_t out_offs[3], size_t *out_nbytes) {
    uint8_t *abuf = buf_reserve(&ctx->arena, 4096);
    if (!abuf) return -1;
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, ctx->arena.cap);
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    kiln_tensor_dir_t dir;
    kiln_err_t err = kiln_asm_decode_tensors(wire, wlen, &dir, &arena, &opts, &res);
    if (err != KILN_OK) return (int)err;
    if (dir.count != 3 || dir.items[0].dtype != KILN_DTYPE_I64 || dir.items[0].rank != 2) return KILN_ERR_TYPE;
    *out_batch = (int32_t)dir.items[0].shape[0];
    *out_seq = (int32_t)dir.items[0].shape[1];
    *out_nbytes = (size_t)dir.items[0].data_len;
    for (int i = 0; i < 3; i++) {
        out_offs[i] = dir.items[i].data ? (size_t)(dir.items[i].data - wire) : 0;
    }
    return 0;
}

int go_kiln_encode_shard(
    go_kiln_ctx_t *ctx, int32_t vocab, int32_t hidden, int32_t ffn,
    const float *t0, size_t n0, const float *t1, size_t n1,
    const float *t2, size_t n2, const float *t3, size_t n3,
    size_t *out_len) {
    size_t b0 = n0 * 4, b1 = n1 * 4, b2 = n2 * 4, b3 = n3 * 4;
    uint8_t *out = buf_reserve(&ctx->out, b0 + b1 + b2 + b3 + 2048);
    if (!out) return -1;
    kiln_tensor_t ts[4];
    set_tensor_2d(&ts[0], KILN_DTYPE_F32, (uint64_t)vocab, (uint64_t)hidden, t0, b0);
    set_tensor_2d(&ts[1], KILN_DTYPE_F32, (uint64_t)hidden, (uint64_t)hidden, t1, b1);
    set_tensor_2d(&ts[2], KILN_DTYPE_F32, (uint64_t)ffn, (uint64_t)hidden, t2, b2);
    set_tensor_1d(&ts[3], KILN_DTYPE_F32, (uint64_t)hidden, t3, b3);
    kiln_tensor_dir_t dir = { ts, 4, 0, 2, 2 };
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    kiln_err_t err = kiln_asm_encode_tensors(&dir, out, ctx->out.cap, &opts, &res);
    *out_len = (size_t)res.bytes;
    return (int)err;
}

int go_kiln_decode_shard_meta(
    go_kiln_ctx_t *ctx, const uint8_t *wire, size_t wlen,
    int32_t *out_vocab, int32_t *out_hidden, int32_t *out_ffn,
    size_t out_offs[4], size_t out_nbytes[4]) {
    uint8_t *abuf = buf_reserve(&ctx->arena, 4096);
    if (!abuf) return -1;
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, ctx->arena.cap);
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    kiln_tensor_dir_t dir;
    kiln_err_t err = kiln_asm_decode_tensors(wire, wlen, &dir, &arena, &opts, &res);
    if (err != KILN_OK) return (int)err;
    if (dir.count != 4) return KILN_ERR_TYPE;
    *out_vocab = (int32_t)dir.items[0].shape[0];
    *out_hidden = (int32_t)dir.items[0].shape[1];
    *out_ffn = (int32_t)dir.items[2].shape[0];
    for (int i = 0; i < 4; i++) {
        out_offs[i] = dir.items[i].data ? (size_t)(dir.items[i].data - wire) : 0;
        out_nbytes[i] = (size_t)dir.items[i].data_len;
    }
    return 0;
}

int go_kiln_encode_request(
    go_kiln_ctx_t *ctx, int64_t req_id, const uint8_t *model, size_t model_len,
    float temperature, int32_t batch, int32_t seq,
    const int64_t *a0, const int64_t *a1, const int64_t *a2, size_t n_elems,
    size_t *out_len) {
    size_t nb = n_elems * sizeof(int64_t);
    uint8_t *out = buf_reserve(&ctx->out, model_len + nb * 3 + 1024);
    if (!out) return -1;
    kiln_tensor_t ts[3];
    set_tensor_2d(&ts[0], KILN_DTYPE_I64, (uint64_t)batch, (uint64_t)seq, a0, nb);
    set_tensor_2d(&ts[1], KILN_DTYPE_I64, (uint64_t)batch, (uint64_t)seq, a1, nb);
    set_tensor_2d(&ts[2], KILN_DTYPE_I64, (uint64_t)batch, (uint64_t)seq, a2, nb);
    bench_request_t req;
    req.request_id = req_id;
    req.model.ptr = model_len ? model : NULL;
    req.model.len = model_len;
    req.temperature = temperature;
    req.inputs.items = ts;
    req.inputs.count = 3;
    req.inputs.block_length = 0;
    req.inputs.flags = 2;
    req.inputs.version = 2;
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    kiln_err_t err = kiln_asm_encode_bench_request(&req, out, ctx->out.cap, &opts, &res);
    *out_len = (size_t)res.bytes;
    return (int)err;
}

int go_kiln_decode_request_meta(
    go_kiln_ctx_t *ctx, const uint8_t *wire, size_t wlen,
    int64_t *out_req_id, size_t *out_model_off, size_t *out_model_len,
    float *out_temp, int32_t *out_batch, int32_t *out_seq,
    size_t out_offs[3], size_t *out_nbytes) {
    uint8_t *abuf = buf_reserve(&ctx->arena, 4096);
    if (!abuf) return -1;
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, ctx->arena.cap);
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    bench_request_t req;
    kiln_err_t err = kiln_asm_decode_bench_request(wire, wlen, &req, &arena, &opts, &res);
    if (err != KILN_OK) return (int)err;
    if (req.inputs.count != 3 || req.inputs.items[0].dtype != KILN_DTYPE_I64) return KILN_ERR_TYPE;
    *out_req_id = req.request_id;
    *out_model_off = req.model.ptr ? (size_t)(req.model.ptr - wire) : 0;
    *out_model_len = (size_t)req.model.len;
    *out_temp = req.temperature;
    *out_batch = (int32_t)req.inputs.items[0].shape[0];
    *out_seq = (int32_t)req.inputs.items[0].shape[1];
    *out_nbytes = (size_t)req.inputs.items[0].data_len;
    for (int i = 0; i < 3; i++) {
        out_offs[i] = req.inputs.items[i].data ? (size_t)(req.inputs.items[i].data - wire) : 0;
    }
    return 0;
}
