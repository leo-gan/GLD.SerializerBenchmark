/* Thin Node.js N-API C addon for gld-kiln-asm 0.2.0.
 * Statically links build/kiln-asm/libkiln_asm_bench.a into build/kiln-asm/kiln_asm_napi.node.
 *
 * Covers:
 *   - suite:    message, document, telemetry, strings, event (single + batch)
 *   - columnar: table (TableColumns), table_project (KILN_OPT_EMBEDDED O(1) skip),
 *               nested_table, signal (single + batch; row<->column transpose timed)
 *   - array:    grid, grid_window (KLNT v2 float64 [ny, nx], strided interior window copy)
 *   - tensor:   tensor, tensor_view (validates KLNT v2 + returns payload offset/len for zero-copy subarray),
 *               prompt, shard, request (KLNT v2)
 *   - compliance: all 46 Kiln wire v2 vectors with exact JSON decoded output
 *
 * Full RFC 3629 UTF-8 validation is always active (KILN_OPT_TRUSTED is never set).
 */
#define NAPI_VERSION 8
#include <node_api.h>
#include "kiln_asm_bench.h"

#include <inttypes.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define KILN_DTYPE_F64 1U
#define KILN_DTYPE_F32 2U
#define KILN_DTYPE_I64 14U
#define KILN_LARGE_CAP (1ULL << 28)

typedef struct buf_t {
    uint8_t *ptr;
    size_t cap;
} buf_t;

static buf_t g_out = {NULL, 0};
static buf_t g_arena = {NULL, 0};
static buf_t g_enc = {NULL, 0};
static buf_t g_str = {NULL, 0};

static inline uint8_t *buf_reserve(buf_t *b, size_t need) {
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

static napi_value throw_err(napi_env env, const char *op, kiln_err_t err) {
    char msg[160];
    snprintf(msg, sizeof msg, "gld-kiln-asm %s failed (err=%d: %s)",
             op, (int)err, kiln_asm_err_name(err));
    napi_throw_error(env, NULL, msg);
    return NULL;
}

static napi_value throw_msg(napi_env env, const char *msg) {
    napi_throw_error(env, NULL, msg);
    return NULL;
}

static napi_value make_buffer_copy(napi_env env, const uint8_t *src, size_t n) {
    void *data = NULL;
    napi_value out = NULL;
    if (napi_create_buffer_copy(env, n, src, &data, &out) != napi_ok) return NULL;
    return out;
}

/* Append UTF-8 string from napi_value into g_str; store offset in out->ptr (as uintptr_t) and len in out->len.
 * Caller calls str_fixup() on all kiln_str_t entries once string collection finishes (safe across realloc). */
typedef struct str_arena_t {
    size_t used;
} str_arena_t;

static int append_js_str(napi_env env, napi_value val, str_arena_t *sa, kiln_str_t *out) {
    size_t len = 0;
    if (napi_get_value_string_utf8(env, val, NULL, 0, &len) != napi_ok) return -1;
    uint8_t *base = buf_reserve(&g_str, sa->used + len + 1);
    if (!base) { napi_throw_error(env, NULL, "oom"); return -1; }
    size_t written = 0;
    if (len > 0) {
        if (napi_get_value_string_utf8(env, val, (char *)(base + sa->used), len + 1, &written) != napi_ok) return -1;
    }
    out->ptr = (const uint8_t *)(uintptr_t)sa->used;
    out->len = (uint64_t)written;
    sa->used += written;
    return 0;
}

static inline void fixup_str(kiln_str_t *s) {
    if (s->len > 0) s->ptr = g_str.ptr + (uintptr_t)s->ptr;
    else s->ptr = NULL;
}

static inline int get_prop_str(napi_env env, napi_value obj, napi_value key, str_arena_t *sa, kiln_str_t *out) {
    napi_value v;
    if (napi_get_property(env, obj, key, &v) != napi_ok) return -1;
    return append_js_str(env, v, sa, out);
}

static inline int get_prop_bool(napi_env env, napi_value obj, napi_value key, uint8_t *out) {
    napi_value v;
    bool b = false;
    if (napi_get_property(env, obj, key, &v) != napi_ok) return -1;
    if (napi_get_value_bool(env, v, &b) != napi_ok) return -1;
    *out = b ? 1 : 0;
    return 0;
}

static inline int get_prop_i32(napi_env env, napi_value obj, napi_value key, int32_t *out) {
    napi_value v;
    if (napi_get_property(env, obj, key, &v) != napi_ok) return -1;
    if (napi_get_value_int32(env, v, out) != napi_ok) return -1;
    return 0;
}

static inline int get_prop_i64(napi_env env, napi_value obj, napi_value key, int64_t *out) {
    napi_value v;
    if (napi_get_property(env, obj, key, &v) != napi_ok) return -1;
    napi_valuetype vt;
    if (napi_typeof(env, v, &vt) != napi_ok) return -1;
    if (vt == napi_bigint) {
        bool lossless = false;
        if (napi_get_value_bigint_int64(env, v, out, &lossless) != napi_ok) return -1;
        return 0;
    }
    int64_t iv = 0;
    if (napi_get_value_int64(env, v, &iv) != napi_ok) return -1;
    *out = iv;
    return 0;
}

static inline int get_prop_f64(napi_env env, napi_value obj, napi_value key, double *out) {
    napi_value v;
    if (napi_get_property(env, obj, key, &v) != napi_ok) return -1;
    if (napi_get_value_double(env, v, out) != napi_ok) return -1;
    return 0;
}

static inline napi_value mk_key(napi_env env, const char *s) {
    napi_value k = NULL;
    napi_create_string_utf8(env, s, NAPI_AUTO_LENGTH, &k);
    return k;
}

static inline napi_value mk_str(napi_env env, kiln_str_t s) {
    napi_value v = NULL;
    napi_create_string_utf8(env, (const char *)s.ptr, (size_t)s.len, &v);
    return v;
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

/* Extract raw bytes from Buffer / Uint8Array / TypedArray (zero-copy pointer). */
static int get_raw_bytes(napi_env env, napi_value val, const uint8_t **ptr, size_t *len) {
    bool is_buf = false;
    if (napi_is_buffer(env, val, &is_buf) == napi_ok && is_buf) {
        void *p = NULL;
        if (napi_get_buffer_info(env, val, &p, len) != napi_ok) return -1;
        *ptr = (const uint8_t *)p;
        return 0;
    }
    bool is_ta = false;
    if (napi_is_typedarray(env, val, &is_ta) == napi_ok && is_ta) {
        napi_typedarray_type tt;
        size_t elem_count = 0;
        void *p = NULL;
        napi_value ab = NULL;
        size_t byte_off = 0;
        if (napi_get_typedarray_info(env, val, &tt, &elem_count, &p, &ab, &byte_off) != napi_ok) return -1;
        size_t esz = 1;
        switch (tt) {
            case napi_int8_array: case napi_uint8_array: case napi_uint8_clamped_array: esz = 1; break;
            case napi_int16_array: case napi_uint16_array: esz = 2; break;
            case napi_int32_array: case napi_uint32_array: case napi_float32_array: esz = 4; break;
            case napi_float64_array: case napi_bigint64_array: case napi_biguint64_array: esz = 8; break;
            default: esz = 1; break;
        }
        *ptr = (const uint8_t *)p;
        *len = elem_count * esz;
        return 0;
    }
    return -1;
}

/* ==================== MESSAGE ==================== */

static napi_value napi_encode_message(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value argv[2];
    if (napi_get_cb_info(env, info, &argc, argv, NULL, NULL) != napi_ok || argc < 2)
        return throw_msg(env, "encodeMessage expects (obj, batch)");
    bool batch = false;
    if (napi_get_value_bool(env, argv[1], &batch) != napi_ok) return NULL;

    napi_value k0 = mk_key(env, "f_bool"), k1 = mk_key(env, "f_int32"),
               k2 = mk_key(env, "f_int64"), k3 = mk_key(env, "f_float64"),
               k4 = mk_key(env, "f_string"), k5 = mk_key(env, "f_bool_2"),
               k6 = mk_key(env, "f_int32_2"), k7 = mk_key(env, "f_string_2");

    uint32_t n = 1;
    if (batch && napi_get_array_length(env, argv[0], &n) != napi_ok) return NULL;

    bench_message_t *arr = (bench_message_t *)buf_reserve(&g_enc, (size_t)n * sizeof(bench_message_t) + 64);
    if (!arr) return throw_msg(env, "oom");
    str_arena_t sa = {0};

    for (uint32_t i = 0; i < n; i++) {
        napi_handle_scope scope;
        napi_open_handle_scope(env, &scope);
        napi_value row = argv[0];
        if (batch && napi_get_element(env, argv[0], i, &row) != napi_ok) {
            napi_close_handle_scope(env, scope); return NULL;
        }
        int rc = get_prop_bool(env, row, k0, &arr[i].f_bool) |
                 get_prop_i32(env, row, k1, &arr[i].f_int32) |
                 get_prop_i64(env, row, k2, &arr[i].f_int64) |
                 get_prop_f64(env, row, k3, &arr[i].f_float64) |
                 get_prop_str(env, row, k4, &sa, &arr[i].f_string) |
                 get_prop_bool(env, row, k5, &arr[i].f_bool_2) |
                 get_prop_i32(env, row, k6, &arr[i].f_int32_2) |
                 get_prop_str(env, row, k7, &sa, &arr[i].f_string_2);
        napi_close_handle_scope(env, scope);
        if (rc < 0) return NULL;
    }
    for (uint32_t i = 0; i < n; i++) {
        fixup_str(&arr[i].f_string);
        fixup_str(&arr[i].f_string_2);
    }

    uint8_t *out = buf_reserve(&g_out, sa.used + (size_t)n * 48 + 64);
    if (!out) return throw_msg(env, "oom");
    kiln_result_t res = {0, 0};
    kiln_err_t err = batch
        ? kiln_asm_encode_bench_message_batch(arr, (size_t)n, out, g_out.cap, NULL, &res)
        : kiln_asm_encode_bench_message(&arr[0], out, g_out.cap, NULL, &res);
    if (err != KILN_OK) return throw_err(env, "encodeMessage", err);
    return make_buffer_copy(env, out, (size_t)res.bytes);
}

static napi_value unpack_message_one(napi_env env, const bench_message_t *m, napi_value *k) {
    napi_value obj, v;
    napi_create_object(env, &obj);
    napi_get_boolean(env, m->f_bool != 0, &v); napi_set_property(env, obj, k[0], v);
    napi_create_int32(env, m->f_int32, &v); napi_set_property(env, obj, k[1], v);
    napi_create_double(env, (double)m->f_int64, &v); napi_set_property(env, obj, k[2], v);
    napi_create_double(env, m->f_float64, &v); napi_set_property(env, obj, k[3], v);
    napi_set_property(env, obj, k[4], mk_str(env, m->f_string));
    napi_get_boolean(env, m->f_bool_2 != 0, &v); napi_set_property(env, obj, k[5], v);
    napi_create_int32(env, m->f_int32_2, &v); napi_set_property(env, obj, k[6], v);
    napi_set_property(env, obj, k[7], mk_str(env, m->f_string_2));
    return obj;
}

static napi_value napi_decode_message(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value argv[2];
    if (napi_get_cb_info(env, info, &argc, argv, NULL, NULL) != napi_ok || argc < 2)
        return throw_msg(env, "decodeMessage expects (buf, batch)");
    const uint8_t *w = NULL; size_t wlen = 0; bool batch = false;
    if (get_raw_bytes(env, argv[0], &w, &wlen) < 0 || napi_get_value_bool(env, argv[1], &batch) != napi_ok)
        return throw_msg(env, "decodeMessage invalid args");

    uint8_t *abuf = buf_reserve(&g_arena, wlen * 4 + 65536);
    if (!abuf) return throw_msg(env, "oom");
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);
    kiln_result_t res = {0, 0};

    napi_value k[8] = {
        mk_key(env, "f_bool"), mk_key(env, "f_int32"), mk_key(env, "f_int64"), mk_key(env, "f_float64"),
        mk_key(env, "f_string"), mk_key(env, "f_bool_2"), mk_key(env, "f_int32_2"), mk_key(env, "f_string_2")
    };

    if (!batch) {
        bench_message_t m;
        kiln_err_t err = kiln_asm_decode_bench_message(w, wlen, &m, &arena, NULL, &res);
        if (err != KILN_OK) return throw_err(env, "decodeMessage", err);
        return unpack_message_one(env, &m, k);
    }

    bench_message_t *arr = NULL; size_t cnt = 0;
    kiln_err_t err = kiln_asm_decode_bench_message_batch(w, wlen, &arr, &cnt, &arena, NULL, &res);
    if (err != KILN_OK) return throw_err(env, "decodeMessageBatch", err);
    napi_value out;
    napi_create_array_with_length(env, cnt, &out);
    for (size_t i = 0; i < cnt; i++) {
        napi_handle_scope scope;
        napi_open_handle_scope(env, &scope);
        napi_set_element(env, out, (uint32_t)i, unpack_message_one(env, &arr[i], k));
        napi_close_handle_scope(env, scope);
    }
    return out;
}

/* ==================== DOCUMENT & NESTED_TABLE ==================== */

static napi_value encode_doc_common(napi_env env, napi_value arg0, bool batch, int is_nested) {
    napi_value k_id = mk_key(env, "id"), k_status = mk_key(env, "status"),
               k_meta = mk_key(env, "meta"), k_items = mk_key(env, "items"),
               k_region = mk_key(env, "region"), k_version = mk_key(env, "version"),
               k_sku = mk_key(env, "sku"), k_qty = mk_key(env, "qty"),
               k_price = mk_key(env, "price_minor");

    uint32_t n = 1;
    if (batch && napi_get_array_length(env, arg0, &n) != napi_ok) return NULL;

    size_t total_items = 0;
    for (uint32_t i = 0; i < n; i++) {
        napi_handle_scope scope;
        napi_open_handle_scope(env, &scope);
        napi_value row = arg0, items;
        uint32_t ic = 0;
        if (batch) napi_get_element(env, arg0, i, &row);
        napi_get_property(env, row, k_items, &items);
        napi_get_array_length(env, items, &ic);
        total_items += ic;
        napi_close_handle_scope(env, scope);
    }

    size_t docs_sz = align16((size_t)n * sizeof(bench_document_t));
    size_t items_sz = align16(total_items * sizeof(bench_document_document_item_t));
    uint8_t *enc = buf_reserve(&g_enc, docs_sz + items_sz + 64);
    if (!enc) return throw_msg(env, "oom");
    bench_document_t *docs = (bench_document_t *)enc;
    bench_document_document_item_t *all_items = (bench_document_document_item_t *)(enc + docs_sz);

    str_arena_t sa = {0};
    size_t pos = 0;
    for (uint32_t i = 0; i < n; i++) {
        napi_handle_scope scope;
        napi_open_handle_scope(env, &scope);
        napi_value row = arg0, meta, items;
        if (batch) napi_get_element(env, arg0, i, &row);
        int rc = get_prop_str(env, row, k_id, &sa, &docs[i].id) |
                 get_prop_i32(env, row, k_status, &docs[i].status);
        napi_get_property(env, row, k_meta, &meta);
        rc |= get_prop_str(env, meta, k_region, &sa, &docs[i].meta.region) |
              get_prop_i32(env, meta, k_version, &docs[i].meta.version);
        napi_get_property(env, row, k_items, &items);
        uint32_t ic = 0;
        napi_get_array_length(env, items, &ic);
        docs[i].items.items = ic > 0 ? &all_items[pos] : NULL;
        docs[i].items.count = ic;
        for (uint32_t j = 0; j < ic && rc == 0; j++) {
            napi_value it;
            napi_get_element(env, items, j, &it);
            bench_document_document_item_t *di = &all_items[pos++];
            rc |= get_prop_str(env, it, k_sku, &sa, &di->sku) |
                  get_prop_i32(env, it, k_qty, &di->qty) |
                  get_prop_i64(env, it, k_price, &di->price_minor);
        }
        napi_close_handle_scope(env, scope);
        if (rc < 0) return NULL;
    }

    for (uint32_t i = 0; i < n; i++) {
        fixup_str(&docs[i].id);
        fixup_str(&docs[i].meta.region);
    }
    for (size_t j = 0; j < pos; j++) fixup_str(&all_items[j].sku);

    uint8_t *out = buf_reserve(&g_out, sa.used + (size_t)n * 48 + pos * 32 + 64);
    if (!out) return throw_msg(env, "oom");
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    kiln_err_t err;
    if (!batch) {
        err = is_nested
            ? kiln_asm_encode_bench_nested_row((const bench_nested_row_t *)docs, out, g_out.cap, &opts, &res)
            : kiln_asm_encode_bench_document(docs, out, g_out.cap, &opts, &res);
    } else {
        err = is_nested
            ? kiln_asm_encode_bench_nested_row_batch((const bench_nested_row_t *)docs, (size_t)n, out, g_out.cap, &opts, &res)
            : kiln_asm_encode_bench_document_batch(docs, (size_t)n, out, g_out.cap, &opts, &res);
    }
    if (err != KILN_OK) return throw_err(env, is_nested ? "encodeNestedTable" : "encodeDocument", err);
    return make_buffer_copy(env, out, (size_t)res.bytes);
}

static napi_value unpack_doc_one(napi_env env, const bench_document_t *doc, napi_value *k) {
    napi_value obj, meta, items, v;
    napi_create_object(env, &obj);
    napi_set_property(env, obj, k[0], mk_str(env, doc->id));
    napi_create_int32(env, doc->status, &v); napi_set_property(env, obj, k[1], v);

    napi_create_object(env, &meta);
    napi_set_property(env, meta, k[4], mk_str(env, doc->meta.region));
    napi_create_int32(env, doc->meta.version, &v); napi_set_property(env, meta, k[5], v);
    napi_set_property(env, obj, k[2], meta);

    napi_create_array_with_length(env, (size_t)doc->items.count, &items);
    for (uint64_t j = 0; j < doc->items.count; j++) {
        const bench_document_document_item_t *di = &doc->items.items[j];
        napi_value it;
        napi_create_object(env, &it);
        napi_set_property(env, it, k[6], mk_str(env, di->sku));
        napi_create_int32(env, di->qty, &v); napi_set_property(env, it, k[7], v);
        napi_create_double(env, (double)di->price_minor, &v); napi_set_property(env, it, k[8], v);
        napi_set_element(env, items, (uint32_t)j, it);
    }
    napi_set_property(env, obj, k[3], items);
    return obj;
}

static napi_value decode_doc_common(napi_env env, const uint8_t *w, size_t wlen, bool batch, int is_nested) {
    uint8_t *abuf = buf_reserve(&g_arena, wlen * 6 + 131072);
    if (!abuf) return throw_msg(env, "oom");
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};

    napi_value k[9] = {
        mk_key(env, "id"), mk_key(env, "status"), mk_key(env, "meta"), mk_key(env, "items"),
        mk_key(env, "region"), mk_key(env, "version"), mk_key(env, "sku"), mk_key(env, "qty"), mk_key(env, "price_minor")
    };

    if (!batch) {
        bench_document_t doc;
        kiln_err_t err = is_nested
            ? kiln_asm_decode_bench_nested_row(w, wlen, (bench_nested_row_t *)&doc, &arena, &opts, &res)
            : kiln_asm_decode_bench_document(w, wlen, &doc, &arena, &opts, &res);
        if (err != KILN_OK) return throw_err(env, is_nested ? "decodeNestedTable" : "decodeDocument", err);
        return unpack_doc_one(env, &doc, k);
    }

    bench_document_t *arr = NULL; size_t cnt = 0;
    kiln_err_t err = is_nested
        ? kiln_asm_decode_bench_nested_row_batch(w, wlen, (bench_nested_row_t **)&arr, &cnt, &arena, &opts, &res)
        : kiln_asm_decode_bench_document_batch(w, wlen, &arr, &cnt, &arena, &opts, &res);
    if (err != KILN_OK) return throw_err(env, is_nested ? "decodeNestedTableBatch" : "decodeDocumentBatch", err);
    napi_value out;
    napi_create_array_with_length(env, cnt, &out);
    for (size_t i = 0; i < cnt; i++) {
        napi_handle_scope scope;
        napi_open_handle_scope(env, &scope);
        napi_set_element(env, out, (uint32_t)i, unpack_doc_one(env, &arr[i], k));
        napi_close_handle_scope(env, scope);
    }
    return out;
}

static napi_value napi_encode_document(napi_env env, napi_callback_info info) {
    size_t argc = 2; napi_value argv[2]; bool batch = false;
    if (napi_get_cb_info(env, info, &argc, argv, NULL, NULL) != napi_ok || argc < 2 ||
        napi_get_value_bool(env, argv[1], &batch) != napi_ok) return throw_msg(env, "invalid args");
    return encode_doc_common(env, argv[0], batch, 0);
}

static napi_value napi_decode_document(napi_env env, napi_callback_info info) {
    size_t argc = 2; napi_value argv[2]; const uint8_t *w; size_t wlen; bool batch = false;
    if (napi_get_cb_info(env, info, &argc, argv, NULL, NULL) != napi_ok || argc < 2 ||
        get_raw_bytes(env, argv[0], &w, &wlen) < 0 || napi_get_value_bool(env, argv[1], &batch) != napi_ok)
        return throw_msg(env, "invalid args");
    return decode_doc_common(env, w, wlen, batch, 0);
}

static napi_value napi_encode_nested_table(napi_env env, napi_callback_info info) {
    size_t argc = 2; napi_value argv[2]; bool batch = false;
    if (napi_get_cb_info(env, info, &argc, argv, NULL, NULL) != napi_ok || argc < 2 ||
        napi_get_value_bool(env, argv[1], &batch) != napi_ok) return throw_msg(env, "invalid args");
    return encode_doc_common(env, argv[0], batch, 1);
}

static napi_value napi_decode_nested_table(napi_env env, napi_callback_info info) {
    size_t argc = 2; napi_value argv[2]; const uint8_t *w; size_t wlen; bool batch = false;
    if (napi_get_cb_info(env, info, &argc, argv, NULL, NULL) != napi_ok || argc < 2 ||
        get_raw_bytes(env, argv[0], &w, &wlen) < 0 || napi_get_value_bool(env, argv[1], &batch) != napi_ok)
        return throw_msg(env, "invalid args");
    return decode_doc_common(env, w, wlen, batch, 1);
}

/* ==================== TELEMETRY ==================== */

static napi_value napi_encode_telemetry(napi_env env, napi_callback_info info) {
    size_t argc = 2; napi_value argv[2]; bool batch = false;
    if (napi_get_cb_info(env, info, &argc, argv, NULL, NULL) != napi_ok || argc < 2 ||
        napi_get_value_bool(env, argv[1], &batch) != napi_ok) return throw_msg(env, "invalid args");

    napi_value k_src = mk_key(env, "source"), k_ts = mk_key(env, "ts"),
               k_tags = mk_key(env, "tags"), k_vals = mk_key(env, "values");

    uint32_t n = 1;
    if (batch && napi_get_array_length(env, argv[0], &n) != napi_ok) return NULL;

    size_t total_tags = 0, total_vals = 0;
    for (uint32_t i = 0; i < n; i++) {
        napi_handle_scope scope;
        napi_open_handle_scope(env, &scope);
        napi_value row = argv[0], tags, vals;
        uint32_t tc = 0, vc = 0;
        if (batch) napi_get_element(env, argv[0], i, &row);
        napi_get_property(env, row, k_tags, &tags);
        napi_get_array_length(env, tags, &tc);
        napi_get_property(env, row, k_vals, &vals);
        bool is_ta = false;
        if (napi_is_typedarray(env, vals, &is_ta) == napi_ok && is_ta) {
            size_t len = 0;
            napi_get_typedarray_info(env, vals, NULL, &len, NULL, NULL, NULL);
            vc = (uint32_t)len;
        } else {
            napi_get_array_length(env, vals, &vc);
        }
        total_tags += tc;
        total_vals += vc;
        napi_close_handle_scope(env, scope);
    }

    size_t tels_sz = align16((size_t)n * sizeof(bench_telemetry_t));
    size_t tags_sz = align16(total_tags * sizeof(kiln_str_t));
    size_t vals_sz = align16(total_vals * sizeof(double));
    uint8_t *enc = buf_reserve(&g_enc, tels_sz + tags_sz + vals_sz + 64);
    if (!enc) return throw_msg(env, "oom");
    bench_telemetry_t *tels = (bench_telemetry_t *)enc;
    kiln_str_t *all_tags = (kiln_str_t *)(enc + tels_sz);
    double *all_vals = (double *)(enc + tels_sz + tags_sz);

    str_arena_t sa = {0};
    size_t tpos = 0, vpos = 0;
    for (uint32_t i = 0; i < n; i++) {
        napi_handle_scope scope;
        napi_open_handle_scope(env, &scope);
        napi_value row = argv[0], tags, vals;
        if (batch) napi_get_element(env, argv[0], i, &row);
        int rc = get_prop_str(env, row, k_src, &sa, &tels[i].source) |
                 get_prop_i64(env, row, k_ts, &tels[i].ts);
        napi_get_property(env, row, k_tags, &tags);
        uint32_t tc = 0; napi_get_array_length(env, tags, &tc);
        tels[i].tags.items = tc > 0 ? &all_tags[tpos] : NULL;
        tels[i].tags.count = tc;
        for (uint32_t j = 0; j < tc && rc == 0; j++) {
            napi_value s; napi_get_element(env, tags, j, &s);
            rc |= append_js_str(env, s, &sa, &all_tags[tpos++]);
        }
        napi_get_property(env, row, k_vals, &vals);
        bool is_ta = false;
        if (napi_is_typedarray(env, vals, &is_ta) == napi_ok && is_ta) {
            size_t len = 0; void *p = NULL;
            napi_get_typedarray_info(env, vals, NULL, &len, &p, NULL, NULL);
            if (len > 0) memcpy(&all_vals[vpos], p, len * sizeof(double));
            tels[i].values.items = len > 0 ? &all_vals[vpos] : NULL;
            tels[i].values.count = len;
            vpos += len;
        } else {
            uint32_t vc = 0; napi_get_array_length(env, vals, &vc);
            tels[i].values.items = vc > 0 ? &all_vals[vpos] : NULL;
            tels[i].values.count = vc;
            for (uint32_t j = 0; j < vc && rc == 0; j++) {
                napi_value fv; napi_get_element(env, vals, j, &fv);
                if (napi_get_value_double(env, fv, &all_vals[vpos++]) != napi_ok) rc = -1;
            }
        }
        napi_close_handle_scope(env, scope);
        if (rc < 0) return NULL;
    }
    for (uint32_t i = 0; i < n; i++) fixup_str(&tels[i].source);
    for (size_t j = 0; j < tpos; j++) fixup_str(&all_tags[j]);

    uint8_t *out = buf_reserve(&g_out, sa.used + (size_t)n * 32 + tpos * 8 + vpos * 8 + 64);
    if (!out) return throw_msg(env, "oom");
    kiln_result_t res = {0, 0};
    kiln_err_t err = batch
        ? kiln_asm_encode_bench_telemetry_batch(tels, (size_t)n, out, g_out.cap, NULL, &res)
        : kiln_asm_encode_bench_telemetry(tels, out, g_out.cap, NULL, &res);
    if (err != KILN_OK) return throw_err(env, "encodeTelemetry", err);
    return make_buffer_copy(env, out, (size_t)res.bytes);
}

static napi_value unpack_telemetry_one(napi_env env, const bench_telemetry_t *t, napi_value *k) {
    napi_value obj, tags, vals, v;
    napi_create_object(env, &obj);
    napi_set_property(env, obj, k[0], mk_str(env, t->source));
    napi_create_double(env, (double)t->ts, &v); napi_set_property(env, obj, k[1], v);
    napi_create_array_with_length(env, (size_t)t->tags.count, &tags);
    for (uint64_t j = 0; j < t->tags.count; j++) napi_set_element(env, tags, (uint32_t)j, mk_str(env, t->tags.items[j]));
    napi_set_property(env, obj, k[2], tags);
    napi_create_array_with_length(env, (size_t)t->values.count, &vals);
    for (uint64_t j = 0; j < t->values.count; j++) {
        napi_create_double(env, t->values.items[j], &v);
        napi_set_element(env, vals, (uint32_t)j, v);
    }
    napi_set_property(env, obj, k[3], vals);
    return obj;
}

static napi_value napi_decode_telemetry(napi_env env, napi_callback_info info) {
    size_t argc = 2; napi_value argv[2]; const uint8_t *w; size_t wlen; bool batch = false;
    if (napi_get_cb_info(env, info, &argc, argv, NULL, NULL) != napi_ok || argc < 2 ||
        get_raw_bytes(env, argv[0], &w, &wlen) < 0 || napi_get_value_bool(env, argv[1], &batch) != napi_ok)
        return throw_msg(env, "invalid args");

    uint8_t *abuf = buf_reserve(&g_arena, wlen * 4 + 65536);
    if (!abuf) return throw_msg(env, "oom");
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);
    kiln_result_t res = {0, 0};
    napi_value k[4] = { mk_key(env, "source"), mk_key(env, "ts"), mk_key(env, "tags"), mk_key(env, "values") };

    if (!batch) {
        bench_telemetry_t t;
        kiln_err_t err = kiln_asm_decode_bench_telemetry(w, wlen, &t, &arena, NULL, &res);
        if (err != KILN_OK) return throw_err(env, "decodeTelemetry", err);
        return unpack_telemetry_one(env, &t, k);
    }
    bench_telemetry_t *arr = NULL; size_t cnt = 0;
    kiln_err_t err = kiln_asm_decode_bench_telemetry_batch(w, wlen, &arr, &cnt, &arena, NULL, &res);
    if (err != KILN_OK) return throw_err(env, "decodeTelemetryBatch", err);
    napi_value out;
    napi_create_array_with_length(env, cnt, &out);
    for (size_t i = 0; i < cnt; i++) {
        napi_handle_scope scope;
        napi_open_handle_scope(env, &scope);
        napi_set_element(env, out, (uint32_t)i, unpack_telemetry_one(env, &arr[i], k));
        napi_close_handle_scope(env, scope);
    }
    return out;
}

/* ==================== STRINGS ==================== */

static napi_value napi_encode_strings(napi_env env, napi_callback_info info) {
    size_t argc = 2; napi_value argv[2]; bool batch = false;
    if (napi_get_cb_info(env, info, &argc, argv, NULL, NULL) != napi_ok || argc < 2 ||
        napi_get_value_bool(env, argv[1], &batch) != napi_ok) return throw_msg(env, "invalid args");

    napi_value k_items = mk_key(env, "items");
    uint32_t n = 1;
    if (batch && napi_get_array_length(env, argv[0], &n) != napi_ok) return NULL;

    size_t total = 0;
    for (uint32_t i = 0; i < n; i++) {
        napi_handle_scope scope; napi_open_handle_scope(env, &scope);
        napi_value row = argv[0], items; uint32_t ic = 0;
        if (batch) napi_get_element(env, argv[0], i, &row);
        napi_get_property(env, row, k_items, &items);
        napi_get_array_length(env, items, &ic);
        total += ic;
        napi_close_handle_scope(env, scope);
    }

    size_t hdr_sz = align16((size_t)n * sizeof(bench_strings_t));
    size_t arr_sz = align16(total * sizeof(kiln_str_t));
    uint8_t *enc = buf_reserve(&g_enc, hdr_sz + arr_sz + 64);
    if (!enc) return throw_msg(env, "oom");
    bench_strings_t *ss = (bench_strings_t *)enc;
    kiln_str_t *all_s = (kiln_str_t *)(enc + hdr_sz);

    str_arena_t sa = {0};
    size_t pos = 0;
    for (uint32_t i = 0; i < n; i++) {
        napi_handle_scope scope; napi_open_handle_scope(env, &scope);
        napi_value row = argv[0], items; uint32_t ic = 0;
        if (batch) napi_get_element(env, argv[0], i, &row);
        napi_get_property(env, row, k_items, &items);
        napi_get_array_length(env, items, &ic);
        ss[i].items.items = ic > 0 ? &all_s[pos] : NULL;
        ss[i].items.count = ic;
        int rc = 0;
        for (uint32_t j = 0; j < ic && rc == 0; j++) {
            napi_value s; napi_get_element(env, items, j, &s);
            rc |= append_js_str(env, s, &sa, &all_s[pos++]);
        }
        napi_close_handle_scope(env, scope);
        if (rc < 0) return NULL;
    }
    for (size_t j = 0; j < pos; j++) fixup_str(&all_s[j]);

    uint8_t *out = buf_reserve(&g_out, sa.used + (size_t)n * 8 + pos * 8 + 64);
    if (!out) return throw_msg(env, "oom");
    kiln_result_t res = {0, 0};
    kiln_err_t err = batch
        ? kiln_asm_encode_bench_strings_batch(ss, (size_t)n, out, g_out.cap, NULL, &res)
        : kiln_asm_encode_bench_strings(ss, out, g_out.cap, NULL, &res);
    if (err != KILN_OK) return throw_err(env, "encodeStrings", err);
    return make_buffer_copy(env, out, (size_t)res.bytes);
}

static napi_value unpack_strings_one(napi_env env, const bench_strings_t *s, napi_value k_items) {
    napi_value obj, items;
    napi_create_object(env, &obj);
    napi_create_array_with_length(env, (size_t)s->items.count, &items);
    for (uint64_t j = 0; j < s->items.count; j++) napi_set_element(env, items, (uint32_t)j, mk_str(env, s->items.items[j]));
    napi_set_property(env, obj, k_items, items);
    return obj;
}

static napi_value napi_decode_strings(napi_env env, napi_callback_info info) {
    size_t argc = 2; napi_value argv[2]; const uint8_t *w; size_t wlen; bool batch = false;
    if (napi_get_cb_info(env, info, &argc, argv, NULL, NULL) != napi_ok || argc < 2 ||
        get_raw_bytes(env, argv[0], &w, &wlen) < 0 || napi_get_value_bool(env, argv[1], &batch) != napi_ok)
        return throw_msg(env, "invalid args");

    uint8_t *abuf = buf_reserve(&g_arena, wlen * 4 + 65536);
    if (!abuf) return throw_msg(env, "oom");
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);
    kiln_result_t res = {0, 0};
    napi_value k_items = mk_key(env, "items");

    if (!batch) {
        bench_strings_t s;
        kiln_err_t err = kiln_asm_decode_bench_strings(w, wlen, &s, &arena, NULL, &res);
        if (err != KILN_OK) return throw_err(env, "decodeStrings", err);
        return unpack_strings_one(env, &s, k_items);
    }
    bench_strings_t *arr = NULL; size_t cnt = 0;
    kiln_err_t err = kiln_asm_decode_bench_strings_batch(w, wlen, &arr, &cnt, &arena, NULL, &res);
    if (err != KILN_OK) return throw_err(env, "decodeStringsBatch", err);
    napi_value out;
    napi_create_array_with_length(env, cnt, &out);
    for (size_t i = 0; i < cnt; i++) {
        napi_handle_scope scope; napi_open_handle_scope(env, &scope);
        napi_set_element(env, out, (uint32_t)i, unpack_strings_one(env, &arr[i], k_items));
        napi_close_handle_scope(env, scope);
    }
    return out;
}

/* ==================== EVENT ==================== */

static napi_value napi_encode_event(napi_env env, napi_callback_info info) {
    size_t argc = 2; napi_value argv[2]; bool batch = false;
    if (napi_get_cb_info(env, info, &argc, argv, NULL, NULL) != napi_ok || argc < 2 ||
        napi_get_value_bool(env, argv[1], &batch) != napi_ok) return throw_msg(env, "invalid args");

    napi_value k_eid = mk_key(env, "event_id"), k_et = mk_key(env, "event_type"),
               k_occ = mk_key(env, "occurred_at"), k_prod = mk_key(env, "producer"),
               k_attrs = mk_key(env, "attrs"), k_key = mk_key(env, "key"), k_val = mk_key(env, "value");

    uint32_t n = 1;
    if (batch && napi_get_array_length(env, argv[0], &n) != napi_ok) return NULL;

    size_t total_attrs = 0;
    for (uint32_t i = 0; i < n; i++) {
        napi_handle_scope scope; napi_open_handle_scope(env, &scope);
        napi_value row = argv[0], attrs; uint32_t ac = 0;
        if (batch) napi_get_element(env, argv[0], i, &row);
        napi_get_property(env, row, k_attrs, &attrs);
        napi_get_array_length(env, attrs, &ac);
        total_attrs += ac;
        napi_close_handle_scope(env, scope);
    }

    size_t ev_sz = align16((size_t)n * sizeof(bench_event_t));
    size_t at_sz = align16(total_attrs * sizeof(bench_event_event_attr_t));
    uint8_t *enc = buf_reserve(&g_enc, ev_sz + at_sz + 64);
    if (!enc) return throw_msg(env, "oom");
    bench_event_t *evs = (bench_event_t *)enc;
    bench_event_event_attr_t *all_at = (bench_event_event_attr_t *)(enc + ev_sz);

    str_arena_t sa = {0};
    size_t pos = 0;
    for (uint32_t i = 0; i < n; i++) {
        napi_handle_scope scope; napi_open_handle_scope(env, &scope);
        napi_value row = argv[0], attrs;
        if (batch) napi_get_element(env, argv[0], i, &row);
        int rc = get_prop_str(env, row, k_eid, &sa, &evs[i].event_id) |
                 get_prop_str(env, row, k_et, &sa, &evs[i].event_type) |
                 get_prop_i64(env, row, k_occ, &evs[i].occurred_at) |
                 get_prop_str(env, row, k_prod, &sa, &evs[i].producer);
        napi_get_property(env, row, k_attrs, &attrs);
        uint32_t ac = 0; napi_get_array_length(env, attrs, &ac);
        evs[i].attrs.items = ac > 0 ? &all_at[pos] : NULL;
        evs[i].attrs.count = ac;
        for (uint32_t j = 0; j < ac && rc == 0; j++) {
            napi_value a; napi_get_element(env, attrs, j, &a);
            bench_event_event_attr_t *ea = &all_at[pos++];
            rc |= get_prop_str(env, a, k_key, &sa, &ea->key) |
                  get_prop_str(env, a, k_val, &sa, &ea->value);
        }
        napi_close_handle_scope(env, scope);
        if (rc < 0) return NULL;
    }
    for (uint32_t i = 0; i < n; i++) {
        fixup_str(&evs[i].event_id); fixup_str(&evs[i].event_type); fixup_str(&evs[i].producer);
    }
    for (size_t j = 0; j < pos; j++) { fixup_str(&all_at[j].key); fixup_str(&all_at[j].value); }

    uint8_t *out = buf_reserve(&g_out, sa.used + (size_t)n * 48 + pos * 16 + 64);
    if (!out) return throw_msg(env, "oom");
    kiln_result_t res = {0, 0};
    kiln_err_t err = batch
        ? kiln_asm_encode_bench_event_batch(evs, (size_t)n, out, g_out.cap, NULL, &res)
        : kiln_asm_encode_bench_event(evs, out, g_out.cap, NULL, &res);
    if (err != KILN_OK) return throw_err(env, "encodeEvent", err);
    return make_buffer_copy(env, out, (size_t)res.bytes);
}

static napi_value unpack_event_one(napi_env env, const bench_event_t *e, napi_value *k) {
    napi_value obj, attrs, v;
    napi_create_object(env, &obj);
    napi_set_property(env, obj, k[0], mk_str(env, e->event_id));
    napi_set_property(env, obj, k[1], mk_str(env, e->event_type));
    napi_create_double(env, (double)e->occurred_at, &v); napi_set_property(env, obj, k[2], v);
    napi_set_property(env, obj, k[3], mk_str(env, e->producer));
    napi_create_array_with_length(env, (size_t)e->attrs.count, &attrs);
    for (uint64_t j = 0; j < e->attrs.count; j++) {
        napi_value ad;
        napi_create_object(env, &ad);
        napi_set_property(env, ad, k[5], mk_str(env, e->attrs.items[j].key));
        napi_set_property(env, ad, k[6], mk_str(env, e->attrs.items[j].value));
        napi_set_element(env, attrs, (uint32_t)j, ad);
    }
    napi_set_property(env, obj, k[4], attrs);
    return obj;
}

static napi_value napi_decode_event(napi_env env, napi_callback_info info) {
    size_t argc = 2; napi_value argv[2]; const uint8_t *w; size_t wlen; bool batch = false;
    if (napi_get_cb_info(env, info, &argc, argv, NULL, NULL) != napi_ok || argc < 2 ||
        get_raw_bytes(env, argv[0], &w, &wlen) < 0 || napi_get_value_bool(env, argv[1], &batch) != napi_ok)
        return throw_msg(env, "invalid args");

    uint8_t *abuf = buf_reserve(&g_arena, wlen * 4 + 65536);
    if (!abuf) return throw_msg(env, "oom");
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);
    kiln_result_t res = {0, 0};
    napi_value k[7] = {
        mk_key(env, "event_id"), mk_key(env, "event_type"), mk_key(env, "occurred_at"),
        mk_key(env, "producer"), mk_key(env, "attrs"), mk_key(env, "key"), mk_key(env, "value")
    };

    if (!batch) {
        bench_event_t e;
        kiln_err_t err = kiln_asm_decode_bench_event(w, wlen, &e, &arena, NULL, &res);
        if (err != KILN_OK) return throw_err(env, "decodeEvent", err);
        return unpack_event_one(env, &e, k);
    }
    bench_event_t *arr = NULL; size_t cnt = 0;
    kiln_err_t err = kiln_asm_decode_bench_event_batch(w, wlen, &arr, &cnt, &arena, NULL, &res);
    if (err != KILN_OK) return throw_err(env, "decodeEventBatch", err);
    napi_value out;
    napi_create_array_with_length(env, cnt, &out);
    for (size_t i = 0; i < cnt; i++) {
        napi_handle_scope scope; napi_open_handle_scope(env, &scope);
        napi_set_element(env, out, (uint32_t)i, unpack_event_one(env, &arr[i], k));
        napi_close_handle_scope(env, scope);
    }
    return out;
}

/* ==================== COLUMNAR: TABLE & TABLE_PROJECT ==================== */

static napi_value napi_encode_table(napi_env env, napi_callback_info info) {
    size_t argc = 2; napi_value argv[2]; bool batch = false;
    if (napi_get_cb_info(env, info, &argc, argv, NULL, NULL) != napi_ok || argc < 2 ||
        napi_get_value_bool(env, argv[1], &batch) != napi_ok) return throw_msg(env, "invalid args");

    napi_value kf[16], ki[4], ks[2];
    for (int c = 0; c < 16; c++) { char b[16]; snprintf(b, sizeof b, "f_float_%d", c); kf[c] = mk_key(env, b); }
    for (int c = 0; c < 4; c++) { char b[16]; snprintf(b, sizeof b, "f_int_%d", c); ki[c] = mk_key(env, b); }
    ks[0] = mk_key(env, "f_str_0");
    ks[1] = mk_key(env, "f_str_1");

    uint32_t n = 1;
    if (batch && napi_get_array_length(env, argv[0], &n) != napi_ok) return NULL;

    size_t f_sz = align16((size_t)n * 16 * sizeof(double));
    size_t i_sz = align16((size_t)n * 4 * sizeof(int64_t));
    size_t s_sz = align16((size_t)n * 2 * sizeof(kiln_str_t));
    uint8_t *enc = buf_reserve(&g_enc, f_sz + i_sz + s_sz + 64);
    if (!enc) return throw_msg(env, "oom");
    double *fbuf = (double *)enc;
    int64_t *ibuf = (int64_t *)(enc + f_sz);
    kiln_str_t *sbuf = (kiln_str_t *)(enc + f_sz + i_sz);

    str_arena_t sa = {0};
    for (uint32_t r = 0; r < n; r++) {
        napi_handle_scope scope; napi_open_handle_scope(env, &scope);
        napi_value row = argv[0];
        if (batch) napi_get_element(env, argv[0], r, &row);
        int rc = 0;
        for (int c = 0; c < 16; c++) rc |= get_prop_f64(env, row, kf[c], &fbuf[(size_t)c * n + r]);
        for (int c = 0; c < 4; c++) rc |= get_prop_i64(env, row, ki[c], &ibuf[(size_t)c * n + r]);
        for (int c = 0; c < 2; c++) rc |= get_prop_str(env, row, ks[c], &sa, &sbuf[(size_t)c * n + r]);
        napi_close_handle_scope(env, scope);
        if (rc < 0) return NULL;
    }
    for (size_t k = 0; k < (size_t)n * 2; k++) fixup_str(&sbuf[k]);

    bench_table_columns_t cols;
    bench_table_columns_list_f64_t *fc[16] = {
        &cols.f_float_0, &cols.f_float_1, &cols.f_float_2, &cols.f_float_3,
        &cols.f_float_4, &cols.f_float_5, &cols.f_float_6, &cols.f_float_7,
        &cols.f_float_8, &cols.f_float_9, &cols.f_float_10, &cols.f_float_11,
        &cols.f_float_12, &cols.f_float_13, &cols.f_float_14, &cols.f_float_15
    };
    for (int c = 0; c < 16; c++) { fc[c]->items = n ? &fbuf[(size_t)c * n] : NULL; fc[c]->count = n; }
    bench_table_columns_list_i64_t *ic[4] = { &cols.f_int_0, &cols.f_int_1, &cols.f_int_2, &cols.f_int_3 };
    for (int c = 0; c < 4; c++) { ic[c]->items = n ? &ibuf[(size_t)c * n] : NULL; ic[c]->count = n; }
    cols.f_str_0.items = n ? &sbuf[0] : NULL; cols.f_str_0.count = n;
    cols.f_str_1.items = n ? &sbuf[n] : NULL; cols.f_str_1.count = n;

    uint8_t *out = buf_reserve(&g_out, 256 + (size_t)n * (16 * 8 + 4 * 8 + 2 * 4) + sa.used);
    if (!out) return throw_msg(env, "oom");
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    kiln_err_t err = kiln_asm_encode_bench_table_columns(&cols, out, g_out.cap, &opts, &res);
    if (err != KILN_OK) return throw_err(env, "encodeTable", err);
    return make_buffer_copy(env, out, (size_t)res.bytes);
}

static napi_value napi_decode_table(napi_env env, napi_callback_info info) {
    size_t argc = 2; napi_value argv[2]; const uint8_t *w; size_t wlen; bool batch = false;
    if (napi_get_cb_info(env, info, &argc, argv, NULL, NULL) != napi_ok || argc < 2 ||
        get_raw_bytes(env, argv[0], &w, &wlen) < 0 || napi_get_value_bool(env, argv[1], &batch) != napi_ok)
        return throw_msg(env, "invalid args");

    uint8_t *abuf = buf_reserve(&g_arena, wlen * 4 + 131072);
    if (!abuf) return throw_msg(env, "oom");
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    bench_table_columns_t cols;
    kiln_err_t err = kiln_asm_decode_bench_table_columns(w, wlen, &cols, &arena, &opts, &res);
    if (err != KILN_OK) return throw_err(env, "decodeTable", err);

    const bench_table_columns_list_f64_t *fc[16] = {
        &cols.f_float_0, &cols.f_float_1, &cols.f_float_2, &cols.f_float_3,
        &cols.f_float_4, &cols.f_float_5, &cols.f_float_6, &cols.f_float_7,
        &cols.f_float_8, &cols.f_float_9, &cols.f_float_10, &cols.f_float_11,
        &cols.f_float_12, &cols.f_float_13, &cols.f_float_14, &cols.f_float_15
    };
    const bench_table_columns_list_i64_t *ic[4] = { &cols.f_int_0, &cols.f_int_1, &cols.f_int_2, &cols.f_int_3 };
    uint64_t n = cols.f_float_0.count;

    napi_value kf[16], ki[4], ks[2];
    for (int c = 0; c < 16; c++) { char b[16]; snprintf(b, sizeof b, "f_float_%d", c); kf[c] = mk_key(env, b); }
    for (int c = 0; c < 4; c++) { char b[16]; snprintf(b, sizeof b, "f_int_%d", c); ki[c] = mk_key(env, b); }
    ks[0] = mk_key(env, "f_str_0");
    ks[1] = mk_key(env, "f_str_1");

    if (!batch && n == 1) {
        napi_value row, v;
        napi_create_object(env, &row);
        for (int c = 0; c < 16; c++) { napi_create_double(env, fc[c]->items[0], &v); napi_set_property(env, row, kf[c], v); }
        for (int c = 0; c < 4; c++) { napi_create_double(env, (double)ic[c]->items[0], &v); napi_set_property(env, row, ki[c], v); }
        napi_set_property(env, row, ks[0], mk_str(env, cols.f_str_0.items[0]));
        napi_set_property(env, row, ks[1], mk_str(env, cols.f_str_1.items[0]));
        return row;
    }

    napi_value out;
    napi_create_array_with_length(env, (size_t)n, &out);
    for (uint64_t r = 0; r < n; r++) {
        napi_handle_scope scope; napi_open_handle_scope(env, &scope);
        napi_value row, v;
        napi_create_object(env, &row);
        for (int c = 0; c < 16; c++) { napi_create_double(env, fc[c]->items[r], &v); napi_set_property(env, row, kf[c], v); }
        for (int c = 0; c < 4; c++) { napi_create_double(env, (double)ic[c]->items[r], &v); napi_set_property(env, row, ki[c], v); }
        napi_set_property(env, row, ks[0], mk_str(env, cols.f_str_0.items[r]));
        napi_set_property(env, row, ks[1], mk_str(env, cols.f_str_1.items[r]));
        napi_set_element(env, out, (uint32_t)r, row);
        napi_close_handle_scope(env, scope);
    }
    return out;
}

static inline size_t align64(size_t n) {
    return (n + 63u) & ~(size_t)63u;
}

static napi_value make_f64_typedarray(napi_env env, const double *src, size_t count) {
    void *data = NULL;
    napi_value ab = NULL, ta = NULL;
    size_t nbytes = count * sizeof(double);
    if (napi_create_arraybuffer(env, nbytes, &data, &ab) != napi_ok) return NULL;
    if (nbytes > 0) memcpy(data, src, nbytes);
    if (napi_create_typedarray(env, napi_float64_array, count, ab, 0, &ta) != napi_ok) return NULL;
    return ta;
}

static napi_value napi_decode_table_project(napi_env env, napi_callback_info info) {
    size_t argc = 1; napi_value argv[1]; const uint8_t *w; size_t wlen;
    if (napi_get_cb_info(env, info, &argc, argv, NULL, NULL) != napi_ok || argc < 1 ||
        get_raw_bytes(env, argv[0], &w, &wlen) < 0) return throw_msg(env, "invalid args");

    uint8_t *abuf = buf_reserve(&g_arena, wlen + 65536);
    if (!abuf) return throw_msg(env, "oom");
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, KILN_OPT_EMBEDDED };
    kiln_result_t res = {0, 0};
    bench_table_project_t proj;
    kiln_err_t err = kiln_asm_decode_bench_table_project(w, wlen, &proj, &arena, &opts, &res);
    if (err != KILN_OK) return throw_err(env, "decodeTableProject", err);
    return make_f64_typedarray(env, proj.f_float_0.items, (size_t)proj.f_float_0.count);
}

/* ==================== SIGNAL ==================== */

static napi_value napi_encode_signal(napi_env env, napi_callback_info info) {
    size_t argc = 2; napi_value argv[2]; bool batch = false;
    if (napi_get_cb_info(env, info, &argc, argv, NULL, NULL) != napi_ok || argc < 2 ||
        napi_get_value_bool(env, argv[1], &batch) != napi_ok) return throw_msg(env, "invalid args");

    napi_value k_seq = mk_key(env, "seq"), k_ts = mk_key(env, "ts"), k_pm = mk_key(env, "price_mantissa"),
               k_qty = mk_key(env, "qty"), k_fl = mk_key(env, "flags"), k_sym = mk_key(env, "symbol"),
               k_ven = mk_key(env, "venue"), k_legs = mk_key(env, "legs"),
               k_lid = mk_key(env, "leg_id"), k_lqty = mk_key(env, "leg_qty"), k_lpad = mk_key(env, "leg_pad");

    uint32_t n = 1;
    if (batch && napi_get_array_length(env, argv[0], &n) != napi_ok) return NULL;

    size_t total_legs = 0;
    for (uint32_t i = 0; i < n; i++) {
        napi_handle_scope scope; napi_open_handle_scope(env, &scope);
        napi_value row = argv[0], legs; uint32_t lc = 0;
        if (batch) napi_get_element(env, argv[0], i, &row);
        napi_get_property(env, row, k_legs, &legs);
        napi_get_array_length(env, legs, &lc);
        total_legs += lc;
        napi_close_handle_scope(env, scope);
    }

    size_t sig_sz = align16((size_t)n * sizeof(bench_signal_t));
    size_t leg_sz = align16(total_legs * sizeof(bench_signal_signal_leg_t));
    uint8_t *enc = buf_reserve(&g_enc, sig_sz + leg_sz + 64);
    if (!enc) return throw_msg(env, "oom");
    bench_signal_t *sigs = (bench_signal_t *)enc;
    bench_signal_signal_leg_t *all_legs = (bench_signal_signal_leg_t *)(enc + sig_sz);

    str_arena_t sa = {0};
    size_t pos = 0;
    for (uint32_t i = 0; i < n; i++) {
        napi_handle_scope scope; napi_open_handle_scope(env, &scope);
        napi_value row = argv[0], legs;
        if (batch) napi_get_element(env, argv[0], i, &row);
        int rc = get_prop_i64(env, row, k_seq, &sigs[i].seq) |
                 get_prop_i64(env, row, k_ts, &sigs[i].ts) |
                 get_prop_i64(env, row, k_pm, &sigs[i].price_mantissa) |
                 get_prop_i32(env, row, k_qty, &sigs[i].qty) |
                 get_prop_i32(env, row, k_fl, &sigs[i].flags) |
                 get_prop_str(env, row, k_sym, &sa, &sigs[i].symbol) |
                 get_prop_str(env, row, k_ven, &sa, &sigs[i].venue);
        napi_get_property(env, row, k_legs, &legs);
        uint32_t lc = 0; napi_get_array_length(env, legs, &lc);
        sigs[i].legs.items = lc > 0 ? &all_legs[pos] : NULL;
        sigs[i].legs.count = lc;
        for (uint32_t j = 0; j < lc && rc == 0; j++) {
            napi_value lg; napi_get_element(env, legs, j, &lg);
            bench_signal_signal_leg_t *l = &all_legs[pos++];
            rc |= get_prop_i64(env, lg, k_lid, &l->leg_id) |
                  get_prop_i32(env, lg, k_lqty, &l->leg_qty) |
                  get_prop_i32(env, lg, k_lpad, &l->leg_pad);
        }
        napi_close_handle_scope(env, scope);
        if (rc < 0) return NULL;
    }
    for (uint32_t i = 0; i < n; i++) { fixup_str(&sigs[i].symbol); fixup_str(&sigs[i].venue); }

    uint8_t *out = buf_reserve(&g_out, sa.used + (size_t)n * 64 + pos * 20 + 64);
    if (!out) return throw_msg(env, "oom");
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    kiln_err_t err = batch
        ? kiln_asm_encode_bench_signal_batch(sigs, (size_t)n, out, g_out.cap, &opts, &res)
        : kiln_asm_encode_bench_signal(sigs, out, g_out.cap, &opts, &res);
    if (err != KILN_OK) return throw_err(env, "encodeSignal", err);
    return make_buffer_copy(env, out, (size_t)res.bytes);
}

static napi_value unpack_signal_one(napi_env env, const bench_signal_t *s, napi_value *k) {
    napi_value obj, legs, v;
    napi_create_object(env, &obj);
    napi_create_double(env, (double)s->seq, &v); napi_set_property(env, obj, k[0], v);
    napi_create_double(env, (double)s->ts, &v); napi_set_property(env, obj, k[1], v);
    napi_create_double(env, (double)s->price_mantissa, &v); napi_set_property(env, obj, k[2], v);
    napi_create_int32(env, s->qty, &v); napi_set_property(env, obj, k[3], v);
    napi_create_int32(env, s->flags, &v); napi_set_property(env, obj, k[4], v);
    napi_set_property(env, obj, k[5], mk_str(env, s->symbol));
    napi_set_property(env, obj, k[6], mk_str(env, s->venue));
    napi_create_array_with_length(env, (size_t)s->legs.count, &legs);
    for (uint64_t j = 0; j < s->legs.count; j++) {
        napi_value lg;
        napi_create_object(env, &lg);
        napi_create_double(env, (double)s->legs.items[j].leg_id, &v); napi_set_property(env, lg, k[8], v);
        napi_create_int32(env, s->legs.items[j].leg_qty, &v); napi_set_property(env, lg, k[9], v);
        napi_create_int32(env, s->legs.items[j].leg_pad, &v); napi_set_property(env, lg, k[10], v);
        napi_set_element(env, legs, (uint32_t)j, lg);
    }
    napi_set_property(env, obj, k[7], legs);
    return obj;
}

static napi_value napi_decode_signal(napi_env env, napi_callback_info info) {
    size_t argc = 2; napi_value argv[2]; const uint8_t *w; size_t wlen; bool batch = false;
    if (napi_get_cb_info(env, info, &argc, argv, NULL, NULL) != napi_ok || argc < 2 ||
        get_raw_bytes(env, argv[0], &w, &wlen) < 0 || napi_get_value_bool(env, argv[1], &batch) != napi_ok)
        return throw_msg(env, "invalid args");

    uint8_t *abuf = buf_reserve(&g_arena, wlen * 4 + 131072);
    if (!abuf) return throw_msg(env, "oom");
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    napi_value k[11] = {
        mk_key(env, "seq"), mk_key(env, "ts"), mk_key(env, "price_mantissa"),
        mk_key(env, "qty"), mk_key(env, "flags"), mk_key(env, "symbol"),
        mk_key(env, "venue"), mk_key(env, "legs"),
        mk_key(env, "leg_id"), mk_key(env, "leg_qty"), mk_key(env, "leg_pad")
    };

    if (!batch) {
        bench_signal_t s;
        kiln_err_t err = kiln_asm_decode_bench_signal(w, wlen, &s, &arena, &opts, &res);
        if (err != KILN_OK) return throw_err(env, "decodeSignal", err);
        return unpack_signal_one(env, &s, k);
    }
    bench_signal_t *arr = NULL; size_t cnt = 0;
    kiln_err_t err = kiln_asm_decode_bench_signal_batch(w, wlen, &arr, &cnt, &arena, &opts, &res);
    if (err != KILN_OK) return throw_err(env, "decodeSignalBatch", err);
    napi_value out;
    napi_create_array_with_length(env, cnt, &out);
    for (size_t i = 0; i < cnt; i++) {
        napi_handle_scope scope; napi_open_handle_scope(env, &scope);
        napi_set_element(env, out, (uint32_t)i, unpack_signal_one(env, &arr[i], k));
        napi_close_handle_scope(env, scope);
    }
    return out;
}

/* ==================== ARRAY: GRID & GRID_WINDOW ==================== */

static napi_value napi_encode_grid(napi_env env, napi_callback_info info) {
    size_t argc = 3; napi_value argv[3];
    if (napi_get_cb_info(env, info, &argc, argv, NULL, NULL) != napi_ok || argc < 3)
        return throw_msg(env, "encodeGrid expects (nx, ny, f64Bytes)");
    int32_t nx = 0, ny = 0;
    const uint8_t *raw = NULL; size_t nbytes = 0;
    if (napi_get_value_int32(env, argv[0], &nx) != napi_ok ||
        napi_get_value_int32(env, argv[1], &ny) != napi_ok ||
        get_raw_bytes(env, argv[2], &raw, &nbytes) < 0)
        return throw_msg(env, "encodeGrid invalid args");

    kiln_tensor_t t;
    set_tensor_2d(&t, KILN_DTYPE_F64, (uint64_t)ny, (uint64_t)nx, raw, nbytes);
    kiln_tensor_dir_t dir = { &t, 1, 0, 2, 2 };
    size_t exact = 192u + nbytes;
    void *dst = NULL; napi_value out = NULL;
    if (napi_create_buffer(env, exact, &dst, &out) != napi_ok) return NULL;
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    kiln_err_t err = kiln_asm_encode_tensors(&dir, (uint8_t *)dst, exact, &opts, &res);
    if (err != KILN_OK) return throw_err(env, "encodeGrid", err);
    return (res.bytes == exact) ? out : make_buffer_copy(env, (const uint8_t *)dst, (size_t)res.bytes);
}

static napi_value napi_decode_grid(napi_env env, napi_callback_info info) {
    size_t argc = 1; napi_value argv[1]; const uint8_t *w; size_t wlen;
    if (napi_get_cb_info(env, info, &argc, argv, NULL, NULL) != napi_ok || argc < 1 ||
        get_raw_bytes(env, argv[0], &w, &wlen) < 0) return throw_msg(env, "invalid args");

    uint8_t *abuf = buf_reserve(&g_arena, 4096);
    if (!abuf) return throw_msg(env, "oom");
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    kiln_tensor_dir_t dir;
    kiln_err_t err = kiln_asm_decode_tensors(w, wlen, &dir, &arena, &opts, &res);
    if (err != KILN_OK || dir.count != 1 || dir.items[0].dtype != KILN_DTYPE_F64)
        return throw_err(env, "decodeGrid", err != KILN_OK ? err : KILN_ERR_TYPE);

    size_t n = (size_t)(dir.items[0].data_len / sizeof(double));
    return make_f64_typedarray(env, (const double *)dir.items[0].data, n);
}

static napi_value napi_decode_grid_window(napi_env env, napi_callback_info info) {
    size_t argc = 5; napi_value argv[5]; const uint8_t *w; size_t wlen;
    int32_t x0 = 0, y0 = 0, wx = 0, wy = 0;
    if (napi_get_cb_info(env, info, &argc, argv, NULL, NULL) != napi_ok || argc < 5 ||
        get_raw_bytes(env, argv[0], &w, &wlen) < 0 ||
        napi_get_value_int32(env, argv[1], &x0) != napi_ok ||
        napi_get_value_int32(env, argv[2], &y0) != napi_ok ||
        napi_get_value_int32(env, argv[3], &wx) != napi_ok ||
        napi_get_value_int32(env, argv[4], &wy) != napi_ok)
        return throw_msg(env, "invalid args");

    uint8_t *abuf = buf_reserve(&g_arena, 4096);
    if (!abuf) return throw_msg(env, "oom");
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    kiln_tensor_dir_t dir;
    kiln_err_t err = kiln_asm_decode_tensors(w, wlen, &dir, &arena, &opts, &res);
    if (err != KILN_OK || dir.count != 1 || dir.items[0].dtype != KILN_DTYPE_F64 || dir.items[0].rank != 2)
        return throw_err(env, "decodeGridWindow", err != KILN_OK ? err : KILN_ERR_TYPE);

    uint64_t ny = dir.items[0].shape[0], nx = dir.items[0].shape[1];
    if (x0 < 0 || y0 < 0 || wx < 0 || wy < 0 || (uint64_t)(x0 + wx) > nx || (uint64_t)(y0 + wy) > ny)
        return throw_msg(env, "grid_window out of bounds");

    const uint8_t *src = dir.items[0].data;
    size_t total = (size_t)wx * (size_t)wy;
    void *data = NULL; napi_value ab = NULL, ta = NULL;
    if (napi_create_arraybuffer(env, total * sizeof(double), &data, &ab) != napi_ok) return NULL;
    uint8_t *dst = (uint8_t *)data;
    size_t row_bytes = (size_t)wx * sizeof(double);
    for (int32_t y = 0; y < wy; y++) {
        size_t src_off = (((size_t)(y0 + y) * (size_t)nx) + (size_t)x0) * sizeof(double);
        memcpy(dst + (size_t)y * row_bytes, src + src_off, row_bytes);
    }
    if (napi_create_typedarray(env, napi_float64_array, total, ab, 0, &ta) != napi_ok) return NULL;
    return ta;
}

/* ==================== TENSOR: TENSOR, TENSOR_VIEW, PROMPT, SHARD, REQUEST ==================== */

static napi_value napi_encode_tensor(napi_env env, napi_callback_info info) {
    size_t argc = 3; napi_value argv[3];
    int32_t rows = 0, cols = 0; const uint8_t *raw = NULL; size_t nbytes = 0;
    if (napi_get_cb_info(env, info, &argc, argv, NULL, NULL) != napi_ok || argc < 3 ||
        napi_get_value_int32(env, argv[0], &rows) != napi_ok ||
        napi_get_value_int32(env, argv[1], &cols) != napi_ok ||
        get_raw_bytes(env, argv[2], &raw, &nbytes) < 0)
        return throw_msg(env, "encodeTensor invalid args");

    kiln_tensor_t t;
    set_tensor_2d(&t, KILN_DTYPE_F32, (uint64_t)rows, (uint64_t)cols, raw, nbytes);
    kiln_tensor_dir_t dir = { &t, 1, 0, 2, 2 };
    size_t exact = 192u + nbytes;
    void *dst = NULL; napi_value out = NULL;
    if (napi_create_buffer(env, exact, &dst, &out) != napi_ok) return NULL;
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    kiln_err_t err = kiln_asm_encode_tensors(&dir, (uint8_t *)dst, exact, &opts, &res);
    if (err != KILN_OK) return throw_err(env, "encodeTensor", err);
    return (res.bytes == exact) ? out : make_buffer_copy(env, (const uint8_t *)dst, (size_t)res.bytes);
}

static napi_value napi_decode_tensor(napi_env env, napi_callback_info info) {
    size_t argc = 1; napi_value argv[1]; const uint8_t *w; size_t wlen;
    if (napi_get_cb_info(env, info, &argc, argv, NULL, NULL) != napi_ok || argc < 1 ||
        get_raw_bytes(env, argv[0], &w, &wlen) < 0) return throw_msg(env, "invalid args");

    uint8_t *abuf = buf_reserve(&g_arena, 4096);
    if (!abuf) return throw_msg(env, "oom");
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    kiln_tensor_dir_t dir;
    kiln_err_t err = kiln_asm_decode_tensors(w, wlen, &dir, &arena, &opts, &res);
    if (err != KILN_OK || dir.count != 1 || dir.items[0].dtype != KILN_DTYPE_F32 || dir.items[0].rank != 2)
        return throw_err(env, "decodeTensor", err != KILN_OK ? err : KILN_ERR_TYPE);

    napi_value obj, vals, v;
    napi_create_object(env, &obj);
    napi_create_int32(env, (int32_t)dir.items[0].shape[0], &v); napi_set_named_property(env, obj, "rows", v);
    napi_create_int32(env, (int32_t)dir.items[0].shape[1], &v); napi_set_named_property(env, obj, "cols", v);
    napi_create_object(env, &vals);
    napi_set_named_property(env, vals, "f32Bytes", make_buffer_copy(env, dir.items[0].data, (size_t)dir.items[0].data_len));
    napi_create_uint32(env, (uint32_t)(dir.items[0].data_len / 4), &v); napi_set_named_property(env, vals, "length", v);
    napi_set_named_property(env, obj, "values", vals);
    return obj;
}

/* Validates KLNT v2 and returns [rows, cols, dataOffset, dataByteLength] so JS slices wire.subarray zero-copy! */
static napi_value napi_decode_tensor_view_meta(napi_env env, napi_callback_info info) {
    size_t argc = 1; napi_value argv[1]; const uint8_t *w; size_t wlen;
    if (napi_get_cb_info(env, info, &argc, argv, NULL, NULL) != napi_ok || argc < 1 ||
        get_raw_bytes(env, argv[0], &w, &wlen) < 0) return throw_msg(env, "invalid args");

    uint8_t *abuf = buf_reserve(&g_arena, 4096);
    if (!abuf) return throw_msg(env, "oom");
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    kiln_tensor_dir_t dir;
    kiln_err_t err = kiln_asm_decode_tensors(w, wlen, &dir, &arena, &opts, &res);
    if (err != KILN_OK || dir.count != 1 || dir.items[0].dtype != KILN_DTYPE_F32 || dir.items[0].rank != 2)
        return throw_err(env, "decodeTensorView", err != KILN_OK ? err : KILN_ERR_TYPE);

    napi_value out, v;
    napi_create_array_with_length(env, 4, &out);
    napi_create_int32(env, (int32_t)dir.items[0].shape[0], &v); napi_set_element(env, out, 0, v);
    napi_create_int32(env, (int32_t)dir.items[0].shape[1], &v); napi_set_element(env, out, 1, v);
    napi_create_uint32(env, (uint32_t)(dir.items[0].data - w), &v); napi_set_element(env, out, 2, v);
    napi_create_uint32(env, (uint32_t)dir.items[0].data_len, &v); napi_set_element(env, out, 3, v);
    return out;
}

static napi_value napi_encode_prompt(napi_env env, napi_callback_info info) {
    size_t argc = 5; napi_value argv[5];
    int32_t batch = 0, seq = 0;
    const uint8_t *p[3]; size_t n[3];
    if (napi_get_cb_info(env, info, &argc, argv, NULL, NULL) != napi_ok || argc < 5 ||
        napi_get_value_int32(env, argv[0], &batch) != napi_ok ||
        napi_get_value_int32(env, argv[1], &seq) != napi_ok ||
        get_raw_bytes(env, argv[2], &p[0], &n[0]) < 0 ||
        get_raw_bytes(env, argv[3], &p[1], &n[1]) < 0 ||
        get_raw_bytes(env, argv[4], &p[2], &n[2]) < 0)
        return throw_msg(env, "encodePrompt invalid args");

    kiln_tensor_t ts[3];
    for (int i = 0; i < 3; i++) set_tensor_2d(&ts[i], KILN_DTYPE_I64, (uint64_t)batch, (uint64_t)seq, p[i], n[i]);
    kiln_tensor_dir_t dir = { ts, 3, 0, 2, 2 };
    uint8_t *out = buf_reserve(&g_out, n[0] + n[1] + n[2] + 1024);
    if (!out) return throw_msg(env, "oom");
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    kiln_err_t err = kiln_asm_encode_tensors(&dir, out, g_out.cap, &opts, &res);
    if (err != KILN_OK) return throw_err(env, "encodePrompt", err);
    return make_buffer_copy(env, out, (size_t)res.bytes);
}

static napi_value unpack_i64_array(napi_env env, const uint8_t *src, size_t nbytes) {
    size_t n = nbytes / 8;
    void *data = NULL; napi_value ab = NULL, ta = NULL;
    if (napi_create_arraybuffer(env, n * sizeof(double), &data, &ab) != napi_ok) return NULL;
    double *dst = (double *)data;
    for (size_t i = 0; i < n; i++) {
        int64_t iv; memcpy(&iv, src + i * 8, 8);
        dst[i] = (double)iv;
    }
    if (napi_create_typedarray(env, napi_float64_array, n, ab, 0, &ta) != napi_ok) return NULL;
    return ta;
}

static napi_value unpack_prompt_dir(napi_env env, const kiln_tensor_dir_t *dir) {
    if (dir->count != 3 || dir->items[0].dtype != KILN_DTYPE_I64 || dir->items[0].rank != 2)
        return throw_err(env, "decodePrompt", KILN_ERR_TYPE);
    napi_value obj, v;
    napi_create_object(env, &obj);
    napi_create_int32(env, (int32_t)dir->items[0].shape[0], &v); napi_set_named_property(env, obj, "batch", v);
    napi_create_int32(env, (int32_t)dir->items[0].shape[1], &v); napi_set_named_property(env, obj, "seq", v);
    napi_set_named_property(env, obj, "input_ids", unpack_i64_array(env, dir->items[0].data, (size_t)dir->items[0].data_len));
    napi_set_named_property(env, obj, "attention_mask", unpack_i64_array(env, dir->items[1].data, (size_t)dir->items[1].data_len));
    napi_set_named_property(env, obj, "position_ids", unpack_i64_array(env, dir->items[2].data, (size_t)dir->items[2].data_len));
    return obj;
}

static napi_value napi_decode_prompt(napi_env env, napi_callback_info info) {
    size_t argc = 1; napi_value argv[1]; const uint8_t *w; size_t wlen;
    if (napi_get_cb_info(env, info, &argc, argv, NULL, NULL) != napi_ok || argc < 1 ||
        get_raw_bytes(env, argv[0], &w, &wlen) < 0) return throw_msg(env, "invalid args");

    uint8_t *abuf = buf_reserve(&g_arena, 4096);
    if (!abuf) return throw_msg(env, "oom");
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    kiln_tensor_dir_t dir;
    kiln_err_t err = kiln_asm_decode_tensors(w, wlen, &dir, &arena, &opts, &res);
    if (err != KILN_OK) return throw_err(env, "decodePrompt", err);
    return unpack_prompt_dir(env, &dir);
}

static napi_value napi_encode_shard(napi_env env, napi_callback_info info) {
    size_t argc = 7; napi_value argv[7];
    int32_t vocab = 0, hidden = 0, ffn = 0;
    const uint8_t *p[4]; size_t n[4];
    if (napi_get_cb_info(env, info, &argc, argv, NULL, NULL) != napi_ok || argc < 7 ||
        napi_get_value_int32(env, argv[0], &vocab) != napi_ok ||
        napi_get_value_int32(env, argv[1], &hidden) != napi_ok ||
        napi_get_value_int32(env, argv[2], &ffn) != napi_ok ||
        get_raw_bytes(env, argv[3], &p[0], &n[0]) < 0 ||
        get_raw_bytes(env, argv[4], &p[1], &n[1]) < 0 ||
        get_raw_bytes(env, argv[5], &p[2], &n[2]) < 0 ||
        get_raw_bytes(env, argv[6], &p[3], &n[3]) < 0)
        return throw_msg(env, "encodeShard invalid args");

    kiln_tensor_t ts[4];
    set_tensor_2d(&ts[0], KILN_DTYPE_F32, (uint64_t)vocab, (uint64_t)hidden, p[0], n[0]);
    set_tensor_2d(&ts[1], KILN_DTYPE_F32, (uint64_t)hidden, (uint64_t)hidden, p[1], n[1]);
    set_tensor_2d(&ts[2], KILN_DTYPE_F32, (uint64_t)ffn, (uint64_t)hidden, p[2], n[2]);
    set_tensor_1d(&ts[3], KILN_DTYPE_F32, (uint64_t)hidden, p[3], n[3]);
    kiln_tensor_dir_t dir = { ts, 4, 0, 2, 2 };
    size_t exact = 576u + align64(n[0]) + align64(n[1]) + align64(n[2]) + n[3];
    void *dst = NULL; napi_value out = NULL;
    if (napi_create_buffer(env, exact, &dst, &out) != napi_ok) return NULL;
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    kiln_err_t err = kiln_asm_encode_tensors(&dir, (uint8_t *)dst, exact, &opts, &res);
    if (err != KILN_OK) return throw_err(env, "encodeShard", err);
    return (res.bytes == exact) ? out : make_buffer_copy(env, (const uint8_t *)dst, (size_t)res.bytes);
}

static napi_value make_f32_view_copy(napi_env env, const uint8_t *src, size_t nbytes) {
    napi_value obj, v;
    napi_create_object(env, &obj);
    napi_set_named_property(env, obj, "f32Bytes", make_buffer_copy(env, src, nbytes));
    napi_create_uint32(env, (uint32_t)(nbytes / 4), &v);
    napi_set_named_property(env, obj, "length", v);
    return obj;
}

static napi_value napi_decode_shard(napi_env env, napi_callback_info info) {
    size_t argc = 1; napi_value argv[1]; const uint8_t *w; size_t wlen;
    if (napi_get_cb_info(env, info, &argc, argv, NULL, NULL) != napi_ok || argc < 1 ||
        get_raw_bytes(env, argv[0], &w, &wlen) < 0) return throw_msg(env, "invalid args");

    uint8_t *abuf = buf_reserve(&g_arena, 4096);
    if (!abuf) return throw_msg(env, "oom");
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    kiln_tensor_dir_t dir;
    kiln_err_t err = kiln_asm_decode_tensors(w, wlen, &dir, &arena, &opts, &res);
    if (err != KILN_OK || dir.count != 4)
        return throw_err(env, "decodeShard", err != KILN_OK ? err : KILN_ERR_TYPE);

    napi_value obj, v;
    napi_create_object(env, &obj);
    napi_create_int32(env, (int32_t)dir.items[0].shape[0], &v); napi_set_named_property(env, obj, "vocab", v);
    napi_create_int32(env, (int32_t)dir.items[0].shape[1], &v); napi_set_named_property(env, obj, "hidden", v);
    napi_create_int32(env, (int32_t)dir.items[2].shape[0], &v); napi_set_named_property(env, obj, "ffn", v);
    napi_set_named_property(env, obj, "tok_emb", make_f32_view_copy(env, dir.items[0].data, (size_t)dir.items[0].data_len));
    napi_set_named_property(env, obj, "attn", make_f32_view_copy(env, dir.items[1].data, (size_t)dir.items[1].data_len));
    napi_set_named_property(env, obj, "ffn_weight", make_f32_view_copy(env, dir.items[2].data, (size_t)dir.items[2].data_len));
    napi_set_named_property(env, obj, "norm", make_f32_view_copy(env, dir.items[3].data, (size_t)dir.items[3].data_len));
    return obj;
}

static napi_value napi_encode_request(napi_env env, napi_callback_info info) {
    size_t argc = 8; napi_value argv[8];
    int64_t req_id = 0; double temp = 0.0;
    int32_t batch = 0, seq = 0;
    const uint8_t *p[3]; size_t n[3];
    if (napi_get_cb_info(env, info, &argc, argv, NULL, NULL) != napi_ok || argc < 8 ||
        napi_get_value_int64(env, argv[0], &req_id) != napi_ok ||
        napi_get_value_double(env, argv[2], &temp) != napi_ok ||
        napi_get_value_int32(env, argv[3], &batch) != napi_ok ||
        napi_get_value_int32(env, argv[4], &seq) != napi_ok ||
        get_raw_bytes(env, argv[5], &p[0], &n[0]) < 0 ||
        get_raw_bytes(env, argv[6], &p[1], &n[1]) < 0 ||
        get_raw_bytes(env, argv[7], &p[2], &n[2]) < 0)
        return throw_msg(env, "encodeRequest invalid args");

    str_arena_t sa = {0};
    kiln_str_t model = {NULL, 0};
    if (append_js_str(env, argv[1], &sa, &model) < 0) return NULL;
    fixup_str(&model);

    kiln_tensor_t ts[3];
    for (int i = 0; i < 3; i++) set_tensor_2d(&ts[i], KILN_DTYPE_I64, (uint64_t)batch, (uint64_t)seq, p[i], n[i]);
    bench_request_t req;
    req.request_id = req_id;
    req.model = model;
    req.temperature = (float)temp;
    req.inputs.items = ts;
    req.inputs.count = 3;
    req.inputs.block_length = 0;
    req.inputs.flags = 2;
    req.inputs.version = 2;

    uint8_t *out = buf_reserve(&g_out, sa.used + n[0] + n[1] + n[2] + 1024);
    if (!out) return throw_msg(env, "oom");
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    kiln_err_t err = kiln_asm_encode_bench_request(&req, out, g_out.cap, &opts, &res);
    if (err != KILN_OK) return throw_err(env, "encodeRequest", err);
    return make_buffer_copy(env, out, (size_t)res.bytes);
}

static napi_value napi_decode_request(napi_env env, napi_callback_info info) {
    size_t argc = 1; napi_value argv[1]; const uint8_t *w; size_t wlen;
    if (napi_get_cb_info(env, info, &argc, argv, NULL, NULL) != napi_ok || argc < 1 ||
        get_raw_bytes(env, argv[0], &w, &wlen) < 0) return throw_msg(env, "invalid args");

    uint8_t *abuf = buf_reserve(&g_arena, 4096);
    if (!abuf) return throw_msg(env, "oom");
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    bench_request_t req;
    kiln_err_t err = kiln_asm_decode_bench_request(w, wlen, &req, &arena, &opts, &res);
    if (err != KILN_OK) return throw_err(env, "decodeRequest", err);

    napi_value obj, v;
    napi_create_object(env, &obj);
    napi_create_double(env, (double)req.request_id, &v); napi_set_named_property(env, obj, "request_id", v);
    napi_set_named_property(env, obj, "model", mk_str(env, req.model));
    napi_create_double(env, (double)req.temperature, &v); napi_set_named_property(env, obj, "temperature", v);
    napi_set_named_property(env, obj, "inputs", unpack_prompt_dir(env, &req.inputs));
    return obj;
}

/* ==================== COMPLIANCE (46 Kiln wire v2 vectors) ==================== */

typedef struct jbuf_t {
    char *p;
    size_t n;
    size_t cap;
} jbuf_t;

static void jb_grow(jbuf_t *jb, size_t extra) {
    if (jb->n + extra + 1 <= jb->cap) return;
    size_t next = jb->cap ? jb->cap * 2 : 1024;
    while (next < jb->n + extra + 1) next *= 2;
    jb->p = (char *)realloc(jb->p, next);
    jb->cap = next;
}

static void jb_str(jbuf_t *jb, const char *s) {
    size_t l = strlen(s);
    jb_grow(jb, l);
    memcpy(jb->p + jb->n, s, l);
    jb->n += l;
    jb->p[jb->n] = '\0';
}

static void jb_u64(jbuf_t *jb, uint64_t v) {
    char tmp[32]; snprintf(tmp, sizeof tmp, "%" PRIu64, v); jb_str(jb, tmp);
}

static void jb_i64(jbuf_t *jb, int64_t v) {
    char tmp[32]; snprintf(tmp, sizeof tmp, "%" PRId64, v); jb_str(jb, tmp);
}

static void jb_json_str(jbuf_t *jb, const uint8_t *s, size_t n) {
    jb_str(jb, "\"");
    for (size_t i = 0; i < n; i++) {
        uint8_t c = s[i];
        if (c == '"' || c == '\\') {
            char esc[3] = {'\\', (char)c, 0}; jb_str(jb, esc);
        } else if (c < 0x20) {
            char esc[8]; snprintf(esc, sizeof esc, "\\u%04x", c); jb_str(jb, esc);
        } else {
            jb_grow(jb, 1); jb->p[jb->n++] = (char)c; jb->p[jb->n] = '\0';
        }
    }
    jb_str(jb, "\"");
}

static const char *dtype_json_name(uint16_t d) {
    switch (d) {
        case 1: return "f64"; case 2: return "f32"; case 3: return "f16";
        case 4: return "bf16"; case 5: return "f8e4m3"; case 6: return "f8e5m2";
        case 7: return "bool"; case 8: return "i8"; case 9: return "u8";
        case 10: return "i16"; case 11: return "u16"; case 12: return "i32";
        case 13: return "u32"; case 14: return "i64"; case 15: return "u64";
        case 16: return "i4"; case 17: return "u4"; case 18: return "e2m1";
        case 19: return "e8m0";
        default: return NULL;
    }
}

static void jb_tensor_dir(jbuf_t *jb, const kiln_tensor_dir_t *dir) {
    static const char hex[] = "0123456789abcdef";
    jb_str(jb, "{\"version\":"); jb_u64(jb, dir->version);
    jb_str(jb, ",\"flags\":[");
    int ff = 0;
    if (dir->flags & 1u) { jb_str(jb, "\"names\""); ff = 1; }
    if (dir->flags & 2u) { if (ff) jb_str(jb, ","); jb_str(jb, "\"le\""); }
    jb_str(jb, "],\"tensors\":[");
    for (uint64_t i = 0; i < dir->count; i++) {
        const kiln_tensor_t *t = &dir->items[i];
        if (i) jb_str(jb, ",");
        jb_str(jb, "{\"name\":");
        if (t->name && t->name_len > 0) jb_json_str(jb, t->name, (size_t)t->name_len);
        else jb_str(jb, "null");
        jb_str(jb, ",\"dtype\":");
        const char *dn = dtype_json_name(t->dtype);
        if (dn) { jb_str(jb, "\""); jb_str(jb, dn); jb_str(jb, "\""); }
        else jb_u64(jb, t->dtype);
        jb_str(jb, ",\"shape\":[");
        for (uint8_t r = 0; r < t->rank; r++) { if (r) jb_str(jb, ","); jb_u64(jb, t->shape[r]); }
        jb_str(jb, "],\"quant_scheme\":"); jb_u64(jb, t->quant_scheme);
        jb_str(jb, ",\"data_hex\":\"");
        if (t->data_len > 0 && t->data) {
            jb_grow(jb, (size_t)t->data_len * 2);
            for (uint64_t b = 0; b < t->data_len; b++) {
                uint8_t v = t->data[b];
                jb->p[jb->n++] = hex[v >> 4];
                jb->p[jb->n++] = hex[v & 0xF];
            }
            jb->p[jb->n] = '\0';
        }
        jb_str(jb, "\"}");
    }
    jb_str(jb, "],\"block_length\":"); jb_u64(jb, dir->block_length); jb_str(jb, "}");
}

static napi_value napi_compliance_decode_json(napi_env env, napi_callback_info info) {
    size_t argc = 2; napi_value argv[2];
    const uint8_t *w = NULL; size_t wlen = 0; int32_t tag = 0;
    if (napi_get_cb_info(env, info, &argc, argv, NULL, NULL) != napi_ok || argc < 2 ||
        get_raw_bytes(env, argv[0], &w, &wlen) < 0 ||
        napi_get_value_int32(env, argv[1], &tag) != napi_ok)
        return throw_msg(env, "complianceDecodeJson invalid args");

    uint8_t *abuf = buf_reserve(&g_arena, 1 << 20);
    if (!abuf) return throw_msg(env, "oom");
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);

    kiln_result_t res = {0, 0};
    kiln_err_t err = KILN_ERR_FRAME;
    jbuf_t jb = {NULL, 0, 0};

    switch (tag) {
        case 0: {
            kiln_tensor_dir_t dir;
            err = kiln_asm_decode_tensors(w, wlen, &dir, &arena, NULL, &res);
            if (err == KILN_OK) jb_tensor_dir(&jb, &dir);
            break;
        }
        case 1: {
            kiln_id_tensors_t v;
            err = kiln_asm_decode_id_tensors_framed(w, wlen, &v, &arena, NULL, &res);
            if (err == KILN_OK) {
                jb_str(&jb, "{\"hash\":"); jb_u64(&jb, res.hash);
                jb_str(&jb, ",\"id\":"); jb_i64(&jb, v.id);
                jb_str(&jb, ",\"batch\":"); jb_tensor_dir(&jb, &v.batch);
                jb_str(&jb, "}");
            }
            break;
        }
        case 2: {
            kiln_id_tensors_t v;
            err = kiln_asm_decode_id_tensors(w, wlen, &v, &arena, NULL, &res);
            if (err == KILN_OK) {
                jb_str(&jb, "{\"id\":"); jb_i64(&jb, v.id);
                jb_str(&jb, ",\"batch\":"); jb_tensor_dir(&jb, &v.batch);
                jb_str(&jb, "}");
            }
            break;
        }
        case 3: {
            const uint8_t *raw = NULL; size_t cnt = 0;
            err = kiln_asm_decode_list_f32(w, wlen, &raw, &cnt, &arena, NULL, &res);
            if (err == KILN_OK) {
                jb_str(&jb, "[");
                for (size_t i = 0; i < cnt; i++) {
                    float fv; memcpy(&fv, raw + i * 4, 4);
                    if (i) jb_str(&jb, ",");
                    char tmp[64]; snprintf(tmp, sizeof tmp, "%.9g", (double)fv); jb_str(&jb, tmp);
                }
                jb_str(&jb, "]");
            }
            break;
        }
        case 4: {
            kiln_str_t *items = NULL; size_t cnt = 0;
            err = kiln_asm_decode_list_str(w, wlen, &items, &cnt, &arena, NULL, &res);
            if (err == KILN_OK) {
                jb_str(&jb, "[");
                for (size_t i = 0; i < cnt; i++) {
                    if (i) jb_str(&jb, ",");
                    jb_json_str(&jb, items[i].ptr, (size_t)items[i].len);
                }
                jb_str(&jb, "]");
            }
            break;
        }
        case 5: {
            const uint8_t *raw = NULL; size_t cnt = 0;
            err = kiln_asm_decode_list_i64_struct(w, wlen, &raw, &cnt, &arena, NULL, &res);
            if (err == KILN_OK) {
                jb_str(&jb, "[");
                for (size_t i = 0; i < cnt; i++) {
                    int64_t iv; memcpy(&iv, raw + i * 8, 8);
                    if (i) jb_str(&jb, ",");
                    jb_str(&jb, "{\"a\":"); jb_i64(&jb, iv); jb_str(&jb, "}");
                }
                jb_str(&jb, "]");
            }
            break;
        }
        default: err = KILN_ERR_SCHEMA; break;
    }

    if (err != KILN_OK) {
        free(jb.p);
        return throw_err(env, "compliance", err);
    }
    napi_value out = NULL;
    napi_create_string_utf8(env, jb.p ? jb.p : "null", jb.p ? jb.n : 4, &out);
    free(jb.p);
    return out;
}

static napi_value napi_version(napi_env env, napi_callback_info info) {
    (void)info;
    napi_value out = NULL;
    napi_create_string_utf8(env, kiln_asm_version(), NAPI_AUTO_LENGTH, &out);
    return out;
}

#define EXPORT_FN(name, fn) do { \
    napi_value f = NULL; \
    napi_create_function(env, name, NAPI_AUTO_LENGTH, fn, NULL, &f); \
    napi_set_named_property(env, exports, name, f); \
} while (0)

static napi_value init(napi_env env, napi_value exports) {
    EXPORT_FN("version", napi_version);
    EXPORT_FN("encodeMessage", napi_encode_message);
    EXPORT_FN("decodeMessage", napi_decode_message);
    EXPORT_FN("encodeDocument", napi_encode_document);
    EXPORT_FN("decodeDocument", napi_decode_document);
    EXPORT_FN("encodeTelemetry", napi_encode_telemetry);
    EXPORT_FN("decodeTelemetry", napi_decode_telemetry);
    EXPORT_FN("encodeStrings", napi_encode_strings);
    EXPORT_FN("decodeStrings", napi_decode_strings);
    EXPORT_FN("encodeEvent", napi_encode_event);
    EXPORT_FN("decodeEvent", napi_decode_event);
    EXPORT_FN("encodeTable", napi_encode_table);
    EXPORT_FN("decodeTable", napi_decode_table);
    EXPORT_FN("decodeTableProject", napi_decode_table_project);
    EXPORT_FN("encodeNestedTable", napi_encode_nested_table);
    EXPORT_FN("decodeNestedTable", napi_decode_nested_table);
    EXPORT_FN("encodeSignal", napi_encode_signal);
    EXPORT_FN("decodeSignal", napi_decode_signal);
    EXPORT_FN("encodeGrid", napi_encode_grid);
    EXPORT_FN("decodeGrid", napi_decode_grid);
    EXPORT_FN("decodeGridWindow", napi_decode_grid_window);
    EXPORT_FN("encodeTensor", napi_encode_tensor);
    EXPORT_FN("decodeTensor", napi_decode_tensor);
    EXPORT_FN("decodeTensorViewMeta", napi_decode_tensor_view_meta);
    EXPORT_FN("encodePrompt", napi_encode_prompt);
    EXPORT_FN("decodePrompt", napi_decode_prompt);
    EXPORT_FN("encodeShard", napi_encode_shard);
    EXPORT_FN("decodeShard", napi_decode_shard);
    EXPORT_FN("encodeRequest", napi_encode_request);
    EXPORT_FN("decodeRequest", napi_decode_request);
    EXPORT_FN("complianceDecodeJson", napi_compliance_decode_json);
    return exports;
}

NAPI_MODULE(NODE_GYP_MODULE_NAME, init)
