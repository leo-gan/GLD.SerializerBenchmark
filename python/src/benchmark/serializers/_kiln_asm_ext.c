/* Thin CPython C-API extension for gld-kiln-asm 0.2.0.
 * Statically links build/kiln-asm/libkiln_asm_bench.a.
 *
 * Covers:
 *   - suite:    message, document, telemetry, strings, event (single + batch)
 *   - columnar: table (TableColumns), table_project (KILN_OPT_EMBEDDED O(1) skip),
 *               nested_table, signal (single + batch; row<->column transpose on the clock)
 *   - array:    grid, grid_window (KLNT v2 float64 [ny, nx], strided interior window copy)
 *   - tensor:   tensor, tensor_view (zero-copy memoryview slice of wire bytes),
 *               prompt, shard, request (KLNT v2)
 *   - compliance: all 46 Kiln wire v2 vectors with exact JSON decoded output
 *
 * Full RFC 3629 UTF-8 validation is always active (KILN_OPT_TRUSTED is never set).
 */
#define PY_SSIZE_T_CLEAN
#include <Python.h>
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

typedef struct scratch_buf_t {
    uint8_t *ptr;
    size_t cap;
} scratch_buf_t;

static scratch_buf_t g_out = {NULL, 0};
static scratch_buf_t g_arena = {NULL, 0};
static scratch_buf_t g_enc = {NULL, 0};

static inline uint8_t *buf_reserve(scratch_buf_t *b, size_t need) {
    if (need < 4096) need = 4096;
    if (b->cap >= need) return b->ptr;
    size_t next = b->cap ? b->cap * 2 : need;
    if (next < need) next = need;
    uint8_t *p = (uint8_t *)realloc(b->ptr, next);
    if (!p) {
        PyErr_NoMemory();
        return NULL;
    }
    b->ptr = p;
    b->cap = next;
    return p;
}

static inline size_t align16(size_t n) {
    return (n + 15u) & ~(size_t)15u;
}

/* Pre-interned attribute/dict keys & helpers */
static PyObject *g_array_cls = NULL;
static PyObject *g_str_frombytes = NULL;
static PyObject *g_str_cast = NULL;
static PyObject *g_str_f = NULL;
static PyObject *g_str_d = NULL;
static PyObject *g_str_q = NULL;

static PyObject *k_f_bool, *k_f_int32, *k_f_int64, *k_f_float64, *k_f_string,
                *k_f_bool_2, *k_f_int32_2, *k_f_string_2;
static PyObject *k_id, *k_status, *k_meta, *k_items, *k_region, *k_version,
                *k_sku, *k_qty, *k_price_minor;
static PyObject *k_source, *k_ts, *k_tags, *k_values;
static PyObject *k_event_id, *k_event_type, *k_occurred_at, *k_producer,
                *k_attrs, *k_key, *k_value;
static PyObject *k_f_float[16], *k_f_int[4], *k_f_str[2];
static PyObject *k_seq, *k_price_mantissa, *k_flags, *k_symbol, *k_venue,
                *k_legs, *k_leg_id, *k_leg_qty, *k_leg_pad;
static PyObject *k_rows, *k_cols, *k_batch, *k_input_ids, *k_attention_mask,
                *k_position_ids, *k_vocab, *k_hidden, *k_ffn, *k_tok_emb,
                *k_attn, *k_ffn_weight, *k_norm, *k_request_id, *k_model,
                *k_temperature, *k_inputs;

static PyObject *raise_kiln_err(const char *op, kiln_err_t err) {
    PyErr_Format(PyExc_ValueError, "gld-kiln-asm %s failed (err=%d: %s)",
                 op, (int)err, kiln_asm_err_name(err));
    return NULL;
}

/* Uniform field getter: returns NEW reference for both dict and dataclass/object. */
static inline PyObject *field_get(PyObject *obj, PyObject *key) {
    if (PyDict_CheckExact(obj)) {
        PyObject *v = PyDict_GetItemWithError(obj, key);
        if (!v) {
            if (!PyErr_Occurred()) PyErr_SetObject(PyExc_KeyError, key);
            return NULL;
        }
        Py_INCREF(v);
        return v;
    }
    return PyObject_GetAttr(obj, key);
}

/* Temporary reference keeper for edge cases where a dynamic property returns a fresh str. */
typedef struct ref_keep_t {
    PyObject **items;
    size_t count;
    size_t cap;
} ref_keep_t;

static int keep_push(ref_keep_t *rk, PyObject *obj) {
    if (rk->count == rk->cap) {
        size_t nc = rk->cap ? rk->cap * 2 : 16;
        PyObject **p = (PyObject **)realloc(rk->items, nc * sizeof(PyObject *));
        if (!p) { PyErr_NoMemory(); return -1; }
        rk->items = p;
        rk->cap = nc;
    }
    rk->items[rk->count++] = obj;
    return 0;
}

static void keep_release(ref_keep_t *rk) {
    for (size_t i = 0; i < rk->count; i++) Py_DECREF(rk->items[i]);
    free(rk->items);
    rk->items = NULL;
    rk->count = rk->cap = 0;
}

static inline int extract_str_obj(PyObject *v, kiln_str_t *out, ref_keep_t *rk) {
    Py_ssize_t len = 0;
    const char *s = PyUnicode_AsUTF8AndSize(v, &len);
    if (!s) {
        Py_DECREF(v);
        return -1;
    }
    out->ptr = (const uint8_t *)s;
    out->len = (uint64_t)len;
    if (Py_REFCNT(v) == 1 && rk != NULL) {
        if (keep_push(rk, v) < 0) { Py_DECREF(v); return -1; }
    } else {
        Py_DECREF(v);
    }
    return 0;
}

static inline int get_str_field(PyObject *obj, PyObject *key, kiln_str_t *out, ref_keep_t *rk) {
    PyObject *v = field_get(obj, key);
    if (!v) return -1;
    return extract_str_obj(v, out, rk);
}

static inline int get_bool_field(PyObject *obj, PyObject *key, uint8_t *out) {
    PyObject *v = field_get(obj, key);
    if (!v) return -1;
    int t = PyObject_IsTrue(v);
    Py_DECREF(v);
    if (t < 0) return -1;
    *out = t ? 1 : 0;
    return 0;
}

static inline int get_i32_field(PyObject *obj, PyObject *key, int32_t *out) {
    PyObject *v = field_get(obj, key);
    if (!v) return -1;
    long long lv = PyLong_AsLongLong(v);
    Py_DECREF(v);
    if (lv == -1 && PyErr_Occurred()) return -1;
    *out = (int32_t)lv;
    return 0;
}

static inline int get_i64_field(PyObject *obj, PyObject *key, int64_t *out) {
    PyObject *v = field_get(obj, key);
    if (!v) return -1;
    long long lv = PyLong_AsLongLong(v);
    Py_DECREF(v);
    if (lv == -1 && PyErr_Occurred()) return -1;
    *out = (int64_t)lv;
    return 0;
}

static inline int get_f64_field(PyObject *obj, PyObject *key, double *out) {
    PyObject *v = field_get(obj, key);
    if (!v) return -1;
    double dv = PyFloat_AsDouble(v);
    Py_DECREF(v);
    if (dv == -1.0 && PyErr_Occurred()) return -1;
    *out = dv;
    return 0;
}

static inline int dict_set_steal(PyObject *d, PyObject *k, PyObject *val) {
    if (!val) return -1;
    int rc = PyDict_SetItem(d, k, val);
    Py_DECREF(val);
    return rc;
}

static inline PyObject *str_from_kiln(kiln_str_t s) {
    return PyUnicode_FromStringAndSize((const char *)s.ptr, (Py_ssize_t)s.len);
}

static PyObject *make_array_copy(PyObject *typecode, const void *ptr, size_t nbytes) {
    PyObject *arr = PyObject_CallOneArg(g_array_cls, typecode);
    if (!arr) return NULL;
    if (nbytes > 0) {
        PyObject *mv = PyMemoryView_FromMemory((char *)ptr, (Py_ssize_t)nbytes, PyBUF_READ);
        if (!mv) { Py_DECREF(arr); return NULL; }
        PyObject *r = PyObject_CallMethodOneArg(arr, g_str_frombytes, mv);
        Py_DECREF(mv);
        if (!r) { Py_DECREF(arr); return NULL; }
        Py_DECREF(r);
    }
    return arr;
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

/* Helper to read numeric sequence into either a borrowed Py_buffer or fallback malloc buffer. */
typedef struct num_view_t {
    Py_buffer pb;
    int has_pb;
    void *owned;
    const void *ptr;
    size_t nbytes;
} num_view_t;

static void num_view_release(num_view_t *nv) {
    if (nv->has_pb) {
        PyBuffer_Release(&nv->pb);
        nv->has_pb = 0;
    }
    if (nv->owned) {
        free(nv->owned);
        nv->owned = NULL;
    }
    nv->ptr = NULL;
    nv->nbytes = 0;
}

static int num_view_acquire_f64(PyObject *obj, num_view_t *nv) {
    memset(nv, 0, sizeof *nv);
    if (PyObject_CheckBuffer(obj)) {
        if (PyObject_GetBuffer(obj, &nv->pb, PyBUF_SIMPLE) == 0) {
            nv->has_pb = 1;
            nv->ptr = nv->pb.buf;
            nv->nbytes = (size_t)nv->pb.len;
            return 0;
        }
        PyErr_Clear();
    }
    PyObject *seq = PySequence_Fast(obj, "expected float64 sequence");
    if (!seq) return -1;
    Py_ssize_t n = PySequence_Fast_GET_SIZE(seq);
    PyObject **items = PySequence_Fast_ITEMS(seq);
    double *buf = n > 0 ? (double *)malloc((size_t)n * sizeof(double)) : NULL;
    if (n > 0 && !buf) { Py_DECREF(seq); PyErr_NoMemory(); return -1; }
    for (Py_ssize_t i = 0; i < n; i++) {
        double v = PyFloat_AsDouble(items[i]);
        if (v == -1.0 && PyErr_Occurred()) { free(buf); Py_DECREF(seq); return -1; }
        buf[i] = v;
    }
    Py_DECREF(seq);
    nv->owned = buf;
    nv->ptr = buf;
    nv->nbytes = (size_t)n * sizeof(double);
    return 0;
}

static int num_view_acquire_f32(PyObject *obj, num_view_t *nv) {
    memset(nv, 0, sizeof *nv);
    if (PyObject_CheckBuffer(obj)) {
        if (PyObject_GetBuffer(obj, &nv->pb, PyBUF_SIMPLE) == 0) {
            nv->has_pb = 1;
            nv->ptr = nv->pb.buf;
            nv->nbytes = (size_t)nv->pb.len;
            return 0;
        }
        PyErr_Clear();
    }
    PyObject *seq = PySequence_Fast(obj, "expected float32 sequence");
    if (!seq) return -1;
    Py_ssize_t n = PySequence_Fast_GET_SIZE(seq);
    PyObject **items = PySequence_Fast_ITEMS(seq);
    float *buf = n > 0 ? (float *)malloc((size_t)n * sizeof(float)) : NULL;
    if (n > 0 && !buf) { Py_DECREF(seq); PyErr_NoMemory(); return -1; }
    for (Py_ssize_t i = 0; i < n; i++) {
        double v = PyFloat_AsDouble(items[i]);
        if (v == -1.0 && PyErr_Occurred()) { free(buf); Py_DECREF(seq); return -1; }
        buf[i] = (float)v;
    }
    Py_DECREF(seq);
    nv->owned = buf;
    nv->ptr = buf;
    nv->nbytes = (size_t)n * sizeof(float);
    return 0;
}

static int num_view_acquire_i64(PyObject *obj, num_view_t *nv) {
    memset(nv, 0, sizeof *nv);
    if (PyObject_CheckBuffer(obj)) {
        if (PyObject_GetBuffer(obj, &nv->pb, PyBUF_SIMPLE) == 0) {
            nv->has_pb = 1;
            nv->ptr = nv->pb.buf;
            nv->nbytes = (size_t)nv->pb.len;
            return 0;
        }
        PyErr_Clear();
    }
    PyObject *seq = PySequence_Fast(obj, "expected int64 sequence");
    if (!seq) return -1;
    Py_ssize_t n = PySequence_Fast_GET_SIZE(seq);
    PyObject **items = PySequence_Fast_ITEMS(seq);
    int64_t *buf = n > 0 ? (int64_t *)malloc((size_t)n * sizeof(int64_t)) : NULL;
    if (n > 0 && !buf) { Py_DECREF(seq); PyErr_NoMemory(); return -1; }
    for (Py_ssize_t i = 0; i < n; i++) {
        long long v = PyLong_AsLongLong(items[i]);
        if (v == -1 && PyErr_Occurred()) { free(buf); Py_DECREF(seq); return -1; }
        buf[i] = (int64_t)v;
    }
    Py_DECREF(seq);
    nv->owned = buf;
    nv->ptr = buf;
    nv->nbytes = (size_t)n * sizeof(int64_t);
    return 0;
}

/* ==================== MESSAGE ==================== */

static int pack_message_one(PyObject *obj, bench_message_t *m, ref_keep_t *rk, size_t *est) {
    if (get_bool_field(obj, k_f_bool, &m->f_bool) < 0) return -1;
    if (get_i32_field(obj, k_f_int32, &m->f_int32) < 0) return -1;
    if (get_i64_field(obj, k_f_int64, &m->f_int64) < 0) return -1;
    if (get_f64_field(obj, k_f_float64, &m->f_float64) < 0) return -1;
    if (get_str_field(obj, k_f_string, &m->f_string, rk) < 0) return -1;
    if (get_bool_field(obj, k_f_bool_2, &m->f_bool_2) < 0) return -1;
    if (get_i32_field(obj, k_f_int32_2, &m->f_int32_2) < 0) return -1;
    if (get_str_field(obj, k_f_string_2, &m->f_string_2, rk) < 0) return -1;
    *est += 36 + (size_t)m->f_string.len + (size_t)m->f_string_2.len;
    return 0;
}

static PyObject *unpack_message_one(const bench_message_t *m) {
    PyObject *d = PyDict_New();
    if (!d) return NULL;
    if (dict_set_steal(d, k_f_bool, PyBool_FromLong(m->f_bool)) < 0 ||
        dict_set_steal(d, k_f_int32, PyLong_FromLong(m->f_int32)) < 0 ||
        dict_set_steal(d, k_f_int64, PyLong_FromLongLong(m->f_int64)) < 0 ||
        dict_set_steal(d, k_f_float64, PyFloat_FromDouble(m->f_float64)) < 0 ||
        dict_set_steal(d, k_f_string, str_from_kiln(m->f_string)) < 0 ||
        dict_set_steal(d, k_f_bool_2, PyBool_FromLong(m->f_bool_2)) < 0 ||
        dict_set_steal(d, k_f_int32_2, PyLong_FromLong(m->f_int32_2)) < 0 ||
        dict_set_steal(d, k_f_string_2, str_from_kiln(m->f_string_2)) < 0) {
        Py_DECREF(d);
        return NULL;
    }
    return d;
}

static PyObject *py_encode_message(PyObject *self, PyObject *args) {
    (void)self;
    PyObject *obj;
    int batch = 0;
    if (!PyArg_ParseTuple(args, "O|p", &obj, &batch)) return NULL;
    ref_keep_t rk = {0};
    kiln_result_t res = {0, 0};
    kiln_err_t err;
    size_t est = 64;

    if (!batch) {
        bench_message_t m;
        if (pack_message_one(obj, &m, &rk, &est) < 0) { keep_release(&rk); return NULL; }
        uint8_t *out = buf_reserve(&g_out, est);
        if (!out) { keep_release(&rk); return NULL; }
        err = kiln_asm_encode_bench_message(&m, out, g_out.cap, NULL, &res);
        keep_release(&rk);
        if (err != KILN_OK) return raise_kiln_err("encode_message", err);
        return PyBytes_FromStringAndSize((const char *)out, (Py_ssize_t)res.bytes);
    }

    PyObject *seq = PySequence_Fast(obj, "expected list of message");
    if (!seq) return NULL;
    Py_ssize_t n = PySequence_Fast_GET_SIZE(seq);
    PyObject **items = PySequence_Fast_ITEMS(seq);
    bench_message_t *arr = (bench_message_t *)buf_reserve(&g_enc, (size_t)n * sizeof(bench_message_t) + 64);
    if (!arr) { Py_DECREF(seq); return NULL; }
    for (Py_ssize_t i = 0; i < n; i++) {
        if (pack_message_one(items[i], &arr[i], &rk, &est) < 0) {
            keep_release(&rk); Py_DECREF(seq); return NULL;
        }
    }
    uint8_t *out = buf_reserve(&g_out, est + 64);
    if (!out) { keep_release(&rk); Py_DECREF(seq); return NULL; }
    err = kiln_asm_encode_bench_message_batch(arr, (size_t)n, out, g_out.cap, NULL, &res);
    keep_release(&rk);
    Py_DECREF(seq);
    if (err != KILN_OK) return raise_kiln_err("encode_message_batch", err);
    return PyBytes_FromStringAndSize((const char *)out, (Py_ssize_t)res.bytes);
}

static PyObject *py_decode_message(PyObject *self, PyObject *args) {
    (void)self;
    Py_buffer wire;
    int batch = 0;
    if (!PyArg_ParseTuple(args, "y*|p", &wire, &batch)) return NULL;
    uint8_t *abuf = buf_reserve(&g_arena, (size_t)wire.len * 4 + 65536);
    if (!abuf) { PyBuffer_Release(&wire); return NULL; }
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);
    kiln_result_t res = {0, 0};

    if (!batch) {
        bench_message_t m;
        kiln_err_t err = kiln_asm_decode_bench_message((const uint8_t *)wire.buf, (size_t)wire.len, &m, &arena, NULL, &res);
        if (err != KILN_OK) { PyBuffer_Release(&wire); return raise_kiln_err("decode_message", err); }
        PyObject *d = unpack_message_one(&m);
        PyBuffer_Release(&wire);
        return d;
    }

    bench_message_t *arr = NULL;
    size_t cnt = 0;
    kiln_err_t err = kiln_asm_decode_bench_message_batch((const uint8_t *)wire.buf, (size_t)wire.len, &arr, &cnt, &arena, NULL, &res);
    if (err != KILN_OK) { PyBuffer_Release(&wire); return raise_kiln_err("decode_message_batch", err); }
    PyObject *lst = PyList_New((Py_ssize_t)cnt);
    if (!lst) { PyBuffer_Release(&wire); return NULL; }
    for (size_t i = 0; i < cnt; i++) {
        PyObject *d = unpack_message_one(&arr[i]);
        if (!d) { Py_DECREF(lst); PyBuffer_Release(&wire); return NULL; }
        PyList_SET_ITEM(lst, (Py_ssize_t)i, d);
    }
    PyBuffer_Release(&wire);
    return lst;
}

/* ==================== DOCUMENT & NESTED_ROW ==================== */

static PyObject *encode_doc_or_nested(PyObject *obj, int batch, int is_nested) {
    ref_keep_t rk = {0};
    PyObject *seq = NULL;
    PyObject *single_arr[1] = {obj};
    PyObject **rows;
    Py_ssize_t n;
    if (batch) {
        seq = PySequence_Fast(obj, "expected list of documents");
        if (!seq) return NULL;
        n = PySequence_Fast_GET_SIZE(seq);
        rows = PySequence_Fast_ITEMS(seq);
    } else {
        n = 1;
        rows = single_arr;
    }

    /* Pass 1: count total items */
    size_t total_items = 0;
    for (Py_ssize_t i = 0; i < n; i++) {
        PyObject *it = field_get(rows[i], k_items);
        if (!it) { Py_XDECREF(seq); return NULL; }
        Py_ssize_t cnt = PySequence_Size(it);
        Py_DECREF(it);
        if (cnt < 0) { Py_XDECREF(seq); return NULL; }
        total_items += (size_t)cnt;
    }

    /* bench_document_t and bench_nested_row_t have identical ABI (verified by _Static_assert) */
    size_t docs_sz = align16((size_t)n * sizeof(bench_document_t));
    size_t items_sz = align16(total_items * sizeof(bench_document_document_item_t));
    uint8_t *enc = buf_reserve(&g_enc, docs_sz + items_sz + 64);
    if (!enc) { Py_XDECREF(seq); return NULL; }
    bench_document_t *docs = (bench_document_t *)enc;
    bench_document_document_item_t *all_items = (bench_document_document_item_t *)(enc + docs_sz);

    size_t item_pos = 0;
    size_t est = 64 + (size_t)n * 48 + total_items * 32;
    for (Py_ssize_t i = 0; i < n; i++) {
        PyObject *r = rows[i];
        if (get_str_field(r, k_id, &docs[i].id, &rk) < 0) goto fail;
        if (get_i32_field(r, k_status, &docs[i].status) < 0) goto fail;
        PyObject *meta = field_get(r, k_meta);
        if (!meta) goto fail;
        int mrc = get_str_field(meta, k_region, &docs[i].meta.region, &rk) |
                  get_i32_field(meta, k_version, &docs[i].meta.version);
        Py_DECREF(meta);
        if (mrc < 0) goto fail;

        PyObject *it_obj = field_get(r, k_items);
        if (!it_obj) goto fail;
        PyObject *it_seq = PySequence_Fast(it_obj, "expected items list");
        Py_DECREF(it_obj);
        if (!it_seq) goto fail;
        Py_ssize_t ic = PySequence_Fast_GET_SIZE(it_seq);
        PyObject **it_arr = PySequence_Fast_ITEMS(it_seq);
        docs[i].items.items = ic > 0 ? &all_items[item_pos] : NULL;
        docs[i].items.count = (uint64_t)ic;
        est += (size_t)docs[i].id.len + (size_t)docs[i].meta.region.len;
        for (Py_ssize_t j = 0; j < ic; j++) {
            bench_document_document_item_t *di = &all_items[item_pos++];
            if (get_str_field(it_arr[j], k_sku, &di->sku, &rk) < 0 ||
                get_i32_field(it_arr[j], k_qty, &di->qty) < 0 ||
                get_i64_field(it_arr[j], k_price_minor, &di->price_minor) < 0) {
                Py_DECREF(it_seq);
                goto fail;
            }
            est += (size_t)di->sku.len;
        }
        Py_DECREF(it_seq);
    }

    uint8_t *out = buf_reserve(&g_out, est);
    if (!out) goto fail;
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    kiln_err_t err;
    if (!batch) {
        if (is_nested) err = kiln_asm_encode_bench_nested_row((const bench_nested_row_t *)docs, out, g_out.cap, &opts, &res);
        else err = kiln_asm_encode_bench_document(docs, out, g_out.cap, &opts, &res);
    } else {
        if (is_nested) err = kiln_asm_encode_bench_nested_row_batch((const bench_nested_row_t *)docs, (size_t)n, out, g_out.cap, &opts, &res);
        else err = kiln_asm_encode_bench_document_batch(docs, (size_t)n, out, g_out.cap, &opts, &res);
    }
    keep_release(&rk);
    Py_XDECREF(seq);
    if (err != KILN_OK) return raise_kiln_err(is_nested ? "encode_nested_table" : "encode_document", err);
    return PyBytes_FromStringAndSize((const char *)out, (Py_ssize_t)res.bytes);

fail:
    keep_release(&rk);
    Py_XDECREF(seq);
    return NULL;
}

static PyObject *unpack_doc_one(const bench_document_t *doc) {
    PyObject *d = PyDict_New();
    if (!d) return NULL;
    PyObject *meta = PyDict_New();
    if (!meta) { Py_DECREF(d); return NULL; }
    if (dict_set_steal(meta, k_region, str_from_kiln(doc->meta.region)) < 0 ||
        dict_set_steal(meta, k_version, PyLong_FromLong(doc->meta.version)) < 0) {
        Py_DECREF(meta); Py_DECREF(d); return NULL;
    }
    PyObject *items = PyList_New((Py_ssize_t)doc->items.count);
    if (!items) { Py_DECREF(meta); Py_DECREF(d); return NULL; }
    for (uint64_t j = 0; j < doc->items.count; j++) {
        const bench_document_document_item_t *it = &doc->items.items[j];
        PyObject *idict = PyDict_New();
        if (!idict) { Py_DECREF(items); Py_DECREF(meta); Py_DECREF(d); return NULL; }
        if (dict_set_steal(idict, k_sku, str_from_kiln(it->sku)) < 0 ||
            dict_set_steal(idict, k_qty, PyLong_FromLong(it->qty)) < 0 ||
            dict_set_steal(idict, k_price_minor, PyLong_FromLongLong(it->price_minor)) < 0) {
            Py_DECREF(idict); Py_DECREF(items); Py_DECREF(meta); Py_DECREF(d); return NULL;
        }
        PyList_SET_ITEM(items, (Py_ssize_t)j, idict);
    }
    if (dict_set_steal(d, k_id, str_from_kiln(doc->id)) < 0 ||
        dict_set_steal(d, k_status, PyLong_FromLong(doc->status)) < 0 ||
        dict_set_steal(d, k_meta, meta) < 0 ||
        dict_set_steal(d, k_items, items) < 0) {
        Py_DECREF(d);
        return NULL;
    }
    return d;
}

static PyObject *decode_doc_or_nested(Py_buffer *wire, int batch, int is_nested) {
    uint8_t *abuf = buf_reserve(&g_arena, (size_t)wire->len * 6 + 131072);
    if (!abuf) return NULL;
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};

    if (!batch) {
        bench_document_t doc;
        kiln_err_t err = is_nested
            ? kiln_asm_decode_bench_nested_row((const uint8_t *)wire->buf, (size_t)wire->len, (bench_nested_row_t *)&doc, &arena, &opts, &res)
            : kiln_asm_decode_bench_document((const uint8_t *)wire->buf, (size_t)wire->len, &doc, &arena, &opts, &res);
        if (err != KILN_OK) return raise_kiln_err(is_nested ? "decode_nested_table" : "decode_document", err);
        return unpack_doc_one(&doc);
    }

    bench_document_t *arr = NULL;
    size_t cnt = 0;
    kiln_err_t err = is_nested
        ? kiln_asm_decode_bench_nested_row_batch((const uint8_t *)wire->buf, (size_t)wire->len, (bench_nested_row_t **)&arr, &cnt, &arena, &opts, &res)
        : kiln_asm_decode_bench_document_batch((const uint8_t *)wire->buf, (size_t)wire->len, &arr, &cnt, &arena, &opts, &res);
    if (err != KILN_OK) return raise_kiln_err(is_nested ? "decode_nested_table_batch" : "decode_document_batch", err);
    PyObject *lst = PyList_New((Py_ssize_t)cnt);
    if (!lst) return NULL;
    for (size_t i = 0; i < cnt; i++) {
        PyObject *d = unpack_doc_one(&arr[i]);
        if (!d) { Py_DECREF(lst); return NULL; }
        PyList_SET_ITEM(lst, (Py_ssize_t)i, d);
    }
    return lst;
}

static PyObject *py_encode_document(PyObject *self, PyObject *args) {
    (void)self;
    PyObject *obj; int batch = 0;
    if (!PyArg_ParseTuple(args, "O|p", &obj, &batch)) return NULL;
    return encode_doc_or_nested(obj, batch, 0);
}

static PyObject *py_decode_document(PyObject *self, PyObject *args) {
    (void)self;
    Py_buffer wire; int batch = 0;
    if (!PyArg_ParseTuple(args, "y*|p", &wire, &batch)) return NULL;
    PyObject *ret = decode_doc_or_nested(&wire, batch, 0);
    PyBuffer_Release(&wire);
    return ret;
}

static PyObject *py_encode_nested_table(PyObject *self, PyObject *args) {
    (void)self;
    PyObject *obj; int batch = 0;
    if (!PyArg_ParseTuple(args, "O|p", &obj, &batch)) return NULL;
    return encode_doc_or_nested(obj, batch, 1);
}

static PyObject *py_decode_nested_table(PyObject *self, PyObject *args) {
    (void)self;
    Py_buffer wire; int batch = 0;
    if (!PyArg_ParseTuple(args, "y*|p", &wire, &batch)) return NULL;
    PyObject *ret = decode_doc_or_nested(&wire, batch, 1);
    PyBuffer_Release(&wire);
    return ret;
}

/* ==================== TELEMETRY ==================== */

static PyObject *py_encode_telemetry(PyObject *self, PyObject *args) {
    (void)self;
    PyObject *obj; int batch = 0;
    if (!PyArg_ParseTuple(args, "O|p", &obj, &batch)) return NULL;

    PyObject *seq = NULL;
    PyObject *single_arr[1] = {obj};
    PyObject **rows;
    Py_ssize_t n;
    if (batch) {
        seq = PySequence_Fast(obj, "expected list of telemetry");
        if (!seq) return NULL;
        n = PySequence_Fast_GET_SIZE(seq);
        rows = PySequence_Fast_ITEMS(seq);
    } else {
        n = 1;
        rows = single_arr;
    }

    size_t total_tags = 0;
    for (Py_ssize_t i = 0; i < n; i++) {
        PyObject *t = field_get(rows[i], k_tags);
        if (!t) { Py_XDECREF(seq); return NULL; }
        Py_ssize_t tc = PySequence_Size(t);
        Py_DECREF(t);
        if (tc < 0) { Py_XDECREF(seq); return NULL; }
        total_tags += (size_t)tc;
    }

    size_t tels_sz = align16((size_t)n * sizeof(bench_telemetry_t));
    size_t tags_sz = align16(total_tags * sizeof(kiln_str_t));
    uint8_t *enc = buf_reserve(&g_enc, tels_sz + tags_sz + 64);
    if (!enc) { Py_XDECREF(seq); return NULL; }
    bench_telemetry_t *tels = (bench_telemetry_t *)enc;
    kiln_str_t *all_tags = (kiln_str_t *)(enc + tels_sz);

    num_view_t *nvs = (num_view_t *)calloc((size_t)(n > 0 ? n : 1), sizeof(num_view_t));
    if (!nvs) { Py_XDECREF(seq); return PyErr_NoMemory(); }
    ref_keep_t rk = {0};

    size_t tag_pos = 0;
    size_t est = 64 + (size_t)n * 32 + total_tags * 8;
    for (Py_ssize_t i = 0; i < n; i++) {
        PyObject *r = rows[i];
        if (get_str_field(r, k_source, &tels[i].source, &rk) < 0) goto fail;
        if (get_i64_field(r, k_ts, &tels[i].ts) < 0) goto fail;
        est += (size_t)tels[i].source.len;

        PyObject *t_obj = field_get(r, k_tags);
        if (!t_obj) goto fail;
        PyObject *t_seq = PySequence_Fast(t_obj, "expected tags sequence");
        Py_DECREF(t_obj);
        if (!t_seq) goto fail;
        Py_ssize_t tc = PySequence_Fast_GET_SIZE(t_seq);
        PyObject **t_arr = PySequence_Fast_ITEMS(t_seq);
        tels[i].tags.items = tc > 0 ? &all_tags[tag_pos] : NULL;
        tels[i].tags.count = (uint64_t)tc;
        for (Py_ssize_t j = 0; j < tc; j++) {
            Py_INCREF(t_arr[j]);
            if (extract_str_obj(t_arr[j], &all_tags[tag_pos], &rk) < 0) {
                Py_DECREF(t_seq);
                goto fail;
            }
            est += (size_t)all_tags[tag_pos].len;
            tag_pos++;
        }
        Py_DECREF(t_seq);

        PyObject *v_obj = field_get(r, k_values);
        if (!v_obj) goto fail;
        int rc = num_view_acquire_f64(v_obj, &nvs[i]);
        Py_DECREF(v_obj);
        if (rc < 0) goto fail;
        tels[i].values.items = (double *)(uintptr_t)nvs[i].ptr;
        tels[i].values.count = (uint64_t)(nvs[i].nbytes / sizeof(double));
        est += nvs[i].nbytes;
    }

    uint8_t *out = buf_reserve(&g_out, est);
    if (!out) goto fail;
    kiln_result_t res = {0, 0};
    kiln_err_t err = batch
        ? kiln_asm_encode_bench_telemetry_batch(tels, (size_t)n, out, g_out.cap, NULL, &res)
        : kiln_asm_encode_bench_telemetry(tels, out, g_out.cap, NULL, &res);

    for (Py_ssize_t i = 0; i < n; i++) num_view_release(&nvs[i]);
    free(nvs);
    keep_release(&rk);
    Py_XDECREF(seq);
    if (err != KILN_OK) return raise_kiln_err("encode_telemetry", err);
    return PyBytes_FromStringAndSize((const char *)out, (Py_ssize_t)res.bytes);

fail:
    for (Py_ssize_t i = 0; i < n; i++) num_view_release(&nvs[i]);
    free(nvs);
    keep_release(&rk);
    Py_XDECREF(seq);
    return NULL;
}

static PyObject *unpack_telemetry_one(const bench_telemetry_t *t) {
    PyObject *d = PyDict_New();
    if (!d) return NULL;
    PyObject *tags = PyList_New((Py_ssize_t)t->tags.count);
    if (!tags) { Py_DECREF(d); return NULL; }
    for (uint64_t j = 0; j < t->tags.count; j++) {
        PyObject *s = str_from_kiln(t->tags.items[j]);
        if (!s) { Py_DECREF(tags); Py_DECREF(d); return NULL; }
        PyList_SET_ITEM(tags, (Py_ssize_t)j, s);
    }
    PyObject *vals = make_array_copy(g_str_d, t->values.items, (size_t)t->values.count * sizeof(double));
    if (!vals) { Py_DECREF(tags); Py_DECREF(d); return NULL; }
    if (dict_set_steal(d, k_source, str_from_kiln(t->source)) < 0 ||
        dict_set_steal(d, k_ts, PyLong_FromLongLong(t->ts)) < 0 ||
        dict_set_steal(d, k_tags, tags) < 0 ||
        dict_set_steal(d, k_values, vals) < 0) {
        Py_DECREF(d);
        return NULL;
    }
    return d;
}

static PyObject *py_decode_telemetry(PyObject *self, PyObject *args) {
    (void)self;
    Py_buffer wire; int batch = 0;
    if (!PyArg_ParseTuple(args, "y*|p", &wire, &batch)) return NULL;
    uint8_t *abuf = buf_reserve(&g_arena, (size_t)wire.len * 4 + 65536);
    if (!abuf) { PyBuffer_Release(&wire); return NULL; }
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);
    kiln_result_t res = {0, 0};

    if (!batch) {
        bench_telemetry_t t;
        kiln_err_t err = kiln_asm_decode_bench_telemetry((const uint8_t *)wire.buf, (size_t)wire.len, &t, &arena, NULL, &res);
        if (err != KILN_OK) { PyBuffer_Release(&wire); return raise_kiln_err("decode_telemetry", err); }
        PyObject *d = unpack_telemetry_one(&t);
        PyBuffer_Release(&wire);
        return d;
    }

    bench_telemetry_t *arr = NULL;
    size_t cnt = 0;
    kiln_err_t err = kiln_asm_decode_bench_telemetry_batch((const uint8_t *)wire.buf, (size_t)wire.len, &arr, &cnt, &arena, NULL, &res);
    if (err != KILN_OK) { PyBuffer_Release(&wire); return raise_kiln_err("decode_telemetry_batch", err); }
    PyObject *lst = PyList_New((Py_ssize_t)cnt);
    if (!lst) { PyBuffer_Release(&wire); return NULL; }
    for (size_t i = 0; i < cnt; i++) {
        PyObject *d = unpack_telemetry_one(&arr[i]);
        if (!d) { Py_DECREF(lst); PyBuffer_Release(&wire); return NULL; }
        PyList_SET_ITEM(lst, (Py_ssize_t)i, d);
    }
    PyBuffer_Release(&wire);
    return lst;
}

/* ==================== STRINGS ==================== */

static PyObject *py_encode_strings(PyObject *self, PyObject *args) {
    (void)self;
    PyObject *obj; int batch = 0;
    if (!PyArg_ParseTuple(args, "O|p", &obj, &batch)) return NULL;

    PyObject *seq = NULL;
    PyObject *single_arr[1] = {obj};
    PyObject **rows;
    Py_ssize_t n;
    if (batch) {
        seq = PySequence_Fast(obj, "expected list of strings");
        if (!seq) return NULL;
        n = PySequence_Fast_GET_SIZE(seq);
        rows = PySequence_Fast_ITEMS(seq);
    } else {
        n = 1;
        rows = single_arr;
    }

    size_t total_items = 0;
    for (Py_ssize_t i = 0; i < n; i++) {
        PyObject *it = field_get(rows[i], k_items);
        if (!it) { Py_XDECREF(seq); return NULL; }
        Py_ssize_t ic = PySequence_Size(it);
        Py_DECREF(it);
        if (ic < 0) { Py_XDECREF(seq); return NULL; }
        total_items += (size_t)ic;
    }

    size_t hdr_sz = align16((size_t)n * sizeof(bench_strings_t));
    size_t arr_sz = align16(total_items * sizeof(kiln_str_t));
    uint8_t *enc = buf_reserve(&g_enc, hdr_sz + arr_sz + 64);
    if (!enc) { Py_XDECREF(seq); return NULL; }
    bench_strings_t *ss = (bench_strings_t *)enc;
    kiln_str_t *all_s = (kiln_str_t *)(enc + hdr_sz);

    ref_keep_t rk = {0};
    size_t pos = 0;
    size_t est = 64 + (size_t)n * 8 + total_items * 8;
    for (Py_ssize_t i = 0; i < n; i++) {
        PyObject *it_obj = field_get(rows[i], k_items);
        if (!it_obj) goto fail;
        PyObject *it_seq = PySequence_Fast(it_obj, "expected items list");
        Py_DECREF(it_obj);
        if (!it_seq) goto fail;
        Py_ssize_t ic = PySequence_Fast_GET_SIZE(it_seq);
        PyObject **it_arr = PySequence_Fast_ITEMS(it_seq);
        ss[i].items.items = ic > 0 ? &all_s[pos] : NULL;
        ss[i].items.count = (uint64_t)ic;
        for (Py_ssize_t j = 0; j < ic; j++) {
            Py_INCREF(it_arr[j]);
            if (extract_str_obj(it_arr[j], &all_s[pos], &rk) < 0) {
                Py_DECREF(it_seq);
                goto fail;
            }
            est += (size_t)all_s[pos].len;
            pos++;
        }
        Py_DECREF(it_seq);
    }

    uint8_t *out = buf_reserve(&g_out, est);
    if (!out) goto fail;
    kiln_result_t res = {0, 0};
    kiln_err_t err = batch
        ? kiln_asm_encode_bench_strings_batch(ss, (size_t)n, out, g_out.cap, NULL, &res)
        : kiln_asm_encode_bench_strings(ss, out, g_out.cap, NULL, &res);
    keep_release(&rk);
    Py_XDECREF(seq);
    if (err != KILN_OK) return raise_kiln_err("encode_strings", err);
    return PyBytes_FromStringAndSize((const char *)out, (Py_ssize_t)res.bytes);

fail:
    keep_release(&rk);
    Py_XDECREF(seq);
    return NULL;
}

static PyObject *unpack_strings_one(const bench_strings_t *s) {
    PyObject *d = PyDict_New();
    if (!d) return NULL;
    PyObject *items = PyList_New((Py_ssize_t)s->items.count);
    if (!items) { Py_DECREF(d); return NULL; }
    for (uint64_t j = 0; j < s->items.count; j++) {
        PyObject *st = str_from_kiln(s->items.items[j]);
        if (!st) { Py_DECREF(items); Py_DECREF(d); return NULL; }
        PyList_SET_ITEM(items, (Py_ssize_t)j, st);
    }
    if (dict_set_steal(d, k_items, items) < 0) { Py_DECREF(d); return NULL; }
    return d;
}

static PyObject *py_decode_strings(PyObject *self, PyObject *args) {
    (void)self;
    Py_buffer wire; int batch = 0;
    if (!PyArg_ParseTuple(args, "y*|p", &wire, &batch)) return NULL;
    uint8_t *abuf = buf_reserve(&g_arena, (size_t)wire.len * 4 + 65536);
    if (!abuf) { PyBuffer_Release(&wire); return NULL; }
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);
    kiln_result_t res = {0, 0};

    if (!batch) {
        bench_strings_t s;
        kiln_err_t err = kiln_asm_decode_bench_strings((const uint8_t *)wire.buf, (size_t)wire.len, &s, &arena, NULL, &res);
        if (err != KILN_OK) { PyBuffer_Release(&wire); return raise_kiln_err("decode_strings", err); }
        PyObject *d = unpack_strings_one(&s);
        PyBuffer_Release(&wire);
        return d;
    }

    bench_strings_t *arr = NULL;
    size_t cnt = 0;
    kiln_err_t err = kiln_asm_decode_bench_strings_batch((const uint8_t *)wire.buf, (size_t)wire.len, &arr, &cnt, &arena, NULL, &res);
    if (err != KILN_OK) { PyBuffer_Release(&wire); return raise_kiln_err("decode_strings_batch", err); }
    PyObject *lst = PyList_New((Py_ssize_t)cnt);
    if (!lst) { PyBuffer_Release(&wire); return NULL; }
    for (size_t i = 0; i < cnt; i++) {
        PyObject *d = unpack_strings_one(&arr[i]);
        if (!d) { Py_DECREF(lst); PyBuffer_Release(&wire); return NULL; }
        PyList_SET_ITEM(lst, (Py_ssize_t)i, d);
    }
    PyBuffer_Release(&wire);
    return lst;
}

/* ==================== EVENT ==================== */

static PyObject *py_encode_event(PyObject *self, PyObject *args) {
    (void)self;
    PyObject *obj; int batch = 0;
    if (!PyArg_ParseTuple(args, "O|p", &obj, &batch)) return NULL;

    PyObject *seq = NULL;
    PyObject *single_arr[1] = {obj};
    PyObject **rows;
    Py_ssize_t n;
    if (batch) {
        seq = PySequence_Fast(obj, "expected list of events");
        if (!seq) return NULL;
        n = PySequence_Fast_GET_SIZE(seq);
        rows = PySequence_Fast_ITEMS(seq);
    } else {
        n = 1;
        rows = single_arr;
    }

    size_t total_attrs = 0;
    for (Py_ssize_t i = 0; i < n; i++) {
        PyObject *at = field_get(rows[i], k_attrs);
        if (!at) { Py_XDECREF(seq); return NULL; }
        Py_ssize_t ac = PySequence_Size(at);
        Py_DECREF(at);
        if (ac < 0) { Py_XDECREF(seq); return NULL; }
        total_attrs += (size_t)ac;
    }

    size_t ev_sz = align16((size_t)n * sizeof(bench_event_t));
    size_t at_sz = align16(total_attrs * sizeof(bench_event_event_attr_t));
    uint8_t *enc = buf_reserve(&g_enc, ev_sz + at_sz + 64);
    if (!enc) { Py_XDECREF(seq); return NULL; }
    bench_event_t *evs = (bench_event_t *)enc;
    bench_event_event_attr_t *all_at = (bench_event_event_attr_t *)(enc + ev_sz);

    ref_keep_t rk = {0};
    size_t pos = 0;
    size_t est = 64 + (size_t)n * 48 + total_attrs * 16;
    for (Py_ssize_t i = 0; i < n; i++) {
        PyObject *r = rows[i];
        if (get_str_field(r, k_event_id, &evs[i].event_id, &rk) < 0 ||
            get_str_field(r, k_event_type, &evs[i].event_type, &rk) < 0 ||
            get_i64_field(r, k_occurred_at, &evs[i].occurred_at) < 0 ||
            get_str_field(r, k_producer, &evs[i].producer, &rk) < 0) goto fail;
        est += (size_t)evs[i].event_id.len + (size_t)evs[i].event_type.len + (size_t)evs[i].producer.len;

        PyObject *at_obj = field_get(r, k_attrs);
        if (!at_obj) goto fail;
        PyObject *at_seq = PySequence_Fast(at_obj, "expected attrs list");
        Py_DECREF(at_obj);
        if (!at_seq) goto fail;
        Py_ssize_t ac = PySequence_Fast_GET_SIZE(at_seq);
        PyObject **at_arr = PySequence_Fast_ITEMS(at_seq);
        evs[i].attrs.items = ac > 0 ? &all_at[pos] : NULL;
        evs[i].attrs.count = (uint64_t)ac;
        for (Py_ssize_t j = 0; j < ac; j++) {
            bench_event_event_attr_t *a = &all_at[pos++];
            if (get_str_field(at_arr[j], k_key, &a->key, &rk) < 0 ||
                get_str_field(at_arr[j], k_value, &a->value, &rk) < 0) {
                Py_DECREF(at_seq);
                goto fail;
            }
            est += (size_t)a->key.len + (size_t)a->value.len;
        }
        Py_DECREF(at_seq);
    }

    uint8_t *out = buf_reserve(&g_out, est);
    if (!out) goto fail;
    kiln_result_t res = {0, 0};
    kiln_err_t err = batch
        ? kiln_asm_encode_bench_event_batch(evs, (size_t)n, out, g_out.cap, NULL, &res)
        : kiln_asm_encode_bench_event(evs, out, g_out.cap, NULL, &res);
    keep_release(&rk);
    Py_XDECREF(seq);
    if (err != KILN_OK) return raise_kiln_err("encode_event", err);
    return PyBytes_FromStringAndSize((const char *)out, (Py_ssize_t)res.bytes);

fail:
    keep_release(&rk);
    Py_XDECREF(seq);
    return NULL;
}

static PyObject *unpack_event_one(const bench_event_t *e) {
    PyObject *d = PyDict_New();
    if (!d) return NULL;
    PyObject *attrs = PyList_New((Py_ssize_t)e->attrs.count);
    if (!attrs) { Py_DECREF(d); return NULL; }
    for (uint64_t j = 0; j < e->attrs.count; j++) {
        PyObject *ad = PyDict_New();
        if (!ad) { Py_DECREF(attrs); Py_DECREF(d); return NULL; }
        if (dict_set_steal(ad, k_key, str_from_kiln(e->attrs.items[j].key)) < 0 ||
            dict_set_steal(ad, k_value, str_from_kiln(e->attrs.items[j].value)) < 0) {
            Py_DECREF(ad); Py_DECREF(attrs); Py_DECREF(d); return NULL;
        }
        PyList_SET_ITEM(attrs, (Py_ssize_t)j, ad);
    }
    if (dict_set_steal(d, k_event_id, str_from_kiln(e->event_id)) < 0 ||
        dict_set_steal(d, k_event_type, str_from_kiln(e->event_type)) < 0 ||
        dict_set_steal(d, k_occurred_at, PyLong_FromLongLong(e->occurred_at)) < 0 ||
        dict_set_steal(d, k_producer, str_from_kiln(e->producer)) < 0 ||
        dict_set_steal(d, k_attrs, attrs) < 0) {
        Py_DECREF(d);
        return NULL;
    }
    return d;
}

static PyObject *py_decode_event(PyObject *self, PyObject *args) {
    (void)self;
    Py_buffer wire; int batch = 0;
    if (!PyArg_ParseTuple(args, "y*|p", &wire, &batch)) return NULL;
    uint8_t *abuf = buf_reserve(&g_arena, (size_t)wire.len * 4 + 65536);
    if (!abuf) { PyBuffer_Release(&wire); return NULL; }
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);
    kiln_result_t res = {0, 0};

    if (!batch) {
        bench_event_t e;
        kiln_err_t err = kiln_asm_decode_bench_event((const uint8_t *)wire.buf, (size_t)wire.len, &e, &arena, NULL, &res);
        if (err != KILN_OK) { PyBuffer_Release(&wire); return raise_kiln_err("decode_event", err); }
        PyObject *d = unpack_event_one(&e);
        PyBuffer_Release(&wire);
        return d;
    }

    bench_event_t *arr = NULL;
    size_t cnt = 0;
    kiln_err_t err = kiln_asm_decode_bench_event_batch((const uint8_t *)wire.buf, (size_t)wire.len, &arr, &cnt, &arena, NULL, &res);
    if (err != KILN_OK) { PyBuffer_Release(&wire); return raise_kiln_err("decode_event_batch", err); }
    PyObject *lst = PyList_New((Py_ssize_t)cnt);
    if (!lst) { PyBuffer_Release(&wire); return NULL; }
    for (size_t i = 0; i < cnt; i++) {
        PyObject *d = unpack_event_one(&arr[i]);
        if (!d) { Py_DECREF(lst); PyBuffer_Release(&wire); return NULL; }
        PyList_SET_ITEM(lst, (Py_ssize_t)i, d);
    }
    PyBuffer_Release(&wire);
    return lst;
}

/* ==================== COLUMNAR: TABLE & TABLE_PROJECT ==================== */

static PyObject *py_encode_table(PyObject *self, PyObject *args) {
    (void)self;
    PyObject *obj; int batch = 0;
    if (!PyArg_ParseTuple(args, "O|p", &obj, &batch)) return NULL;

    PyObject *seq = NULL;
    PyObject *single_arr[1] = {obj};
    PyObject **rows;
    Py_ssize_t n;
    if (batch) {
        seq = PySequence_Fast(obj, "expected list of table rows");
        if (!seq) return NULL;
        n = PySequence_Fast_GET_SIZE(seq);
        rows = PySequence_Fast_ITEMS(seq);
    } else {
        n = 1;
        rows = single_arr;
    }

    size_t f_sz = align16((size_t)n * 16 * sizeof(double));
    size_t i_sz = align16((size_t)n * 4 * sizeof(int64_t));
    size_t s_sz = align16((size_t)n * 2 * sizeof(kiln_str_t));
    uint8_t *enc = buf_reserve(&g_enc, f_sz + i_sz + s_sz + 64);
    if (!enc) { Py_XDECREF(seq); return NULL; }

    double *fbuf = (double *)enc;
    int64_t *ibuf = (int64_t *)(enc + f_sz);
    kiln_str_t *sbuf = (kiln_str_t *)(enc + f_sz + i_sz);

    ref_keep_t rk = {0};
    size_t str_bytes = 0;
    for (Py_ssize_t r = 0; r < n; r++) {
        PyObject *row = rows[r];
        for (int c = 0; c < 16; c++) {
            if (get_f64_field(row, k_f_float[c], &fbuf[(size_t)c * (size_t)n + (size_t)r]) < 0) goto fail;
        }
        for (int c = 0; c < 4; c++) {
            if (get_i64_field(row, k_f_int[c], &ibuf[(size_t)c * (size_t)n + (size_t)r]) < 0) goto fail;
        }
        for (int c = 0; c < 2; c++) {
            kiln_str_t *dst = &sbuf[(size_t)c * (size_t)n + (size_t)r];
            if (get_str_field(row, k_f_str[c], dst, &rk) < 0) goto fail;
            str_bytes += (size_t)dst->len;
        }
    }

    bench_table_columns_t cols;
    bench_table_columns_list_f64_t *fc[16] = {
        &cols.f_float_0, &cols.f_float_1, &cols.f_float_2, &cols.f_float_3,
        &cols.f_float_4, &cols.f_float_5, &cols.f_float_6, &cols.f_float_7,
        &cols.f_float_8, &cols.f_float_9, &cols.f_float_10, &cols.f_float_11,
        &cols.f_float_12, &cols.f_float_13, &cols.f_float_14, &cols.f_float_15
    };
    for (int c = 0; c < 16; c++) {
        fc[c]->items = n > 0 ? &fbuf[(size_t)c * (size_t)n] : NULL;
        fc[c]->count = (uint64_t)n;
    }
    bench_table_columns_list_i64_t *ic[4] = {
        &cols.f_int_0, &cols.f_int_1, &cols.f_int_2, &cols.f_int_3
    };
    for (int c = 0; c < 4; c++) {
        ic[c]->items = n > 0 ? &ibuf[(size_t)c * (size_t)n] : NULL;
        ic[c]->count = (uint64_t)n;
    }
    cols.f_str_0.items = n > 0 ? &sbuf[0] : NULL;
    cols.f_str_0.count = (uint64_t)n;
    cols.f_str_1.items = n > 0 ? &sbuf[(size_t)n] : NULL;
    cols.f_str_1.count = (uint64_t)n;

    size_t est = 256 + (size_t)n * (16 * 8 + 4 * 8 + 2 * 4) + str_bytes;
    uint8_t *out = buf_reserve(&g_out, est);
    if (!out) goto fail;

    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    kiln_err_t err = kiln_asm_encode_bench_table_columns(&cols, out, g_out.cap, &opts, &res);
    keep_release(&rk);
    Py_XDECREF(seq);
    if (err != KILN_OK) return raise_kiln_err("encode_table", err);
    return PyBytes_FromStringAndSize((const char *)out, (Py_ssize_t)res.bytes);

fail:
    keep_release(&rk);
    Py_XDECREF(seq);
    return NULL;
}

static PyObject *py_decode_table(PyObject *self, PyObject *args) {
    (void)self;
    Py_buffer wire; int batch = 0;
    if (!PyArg_ParseTuple(args, "y*|p", &wire, &batch)) return NULL;
    uint8_t *abuf = buf_reserve(&g_arena, (size_t)wire.len * 4 + 131072);
    if (!abuf) { PyBuffer_Release(&wire); return NULL; }
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    bench_table_columns_t cols;
    kiln_err_t err = kiln_asm_decode_bench_table_columns((const uint8_t *)wire.buf, (size_t)wire.len, &cols, &arena, &opts, &res);
    if (err != KILN_OK) { PyBuffer_Release(&wire); return raise_kiln_err("decode_table", err); }

    const bench_table_columns_list_f64_t *fc[16] = {
        &cols.f_float_0, &cols.f_float_1, &cols.f_float_2, &cols.f_float_3,
        &cols.f_float_4, &cols.f_float_5, &cols.f_float_6, &cols.f_float_7,
        &cols.f_float_8, &cols.f_float_9, &cols.f_float_10, &cols.f_float_11,
        &cols.f_float_12, &cols.f_float_13, &cols.f_float_14, &cols.f_float_15
    };
    const bench_table_columns_list_i64_t *ic[4] = {
        &cols.f_int_0, &cols.f_int_1, &cols.f_int_2, &cols.f_int_3
    };
    uint64_t n = cols.f_float_0.count;
    for (int c = 1; c < 16; c++) if (fc[c]->count != n) { PyBuffer_Release(&wire); return raise_kiln_err("decode_table_len", KILN_ERR_TYPE); }
    for (int c = 0; c < 4; c++) if (ic[c]->count != n) { PyBuffer_Release(&wire); return raise_kiln_err("decode_table_len", KILN_ERR_TYPE); }
    if (cols.f_str_0.count != n || cols.f_str_1.count != n) { PyBuffer_Release(&wire); return raise_kiln_err("decode_table_len", KILN_ERR_TYPE); }

    if (!batch && n == 1) {
        PyObject *d = PyDict_New();
        if (!d) { PyBuffer_Release(&wire); return NULL; }
        for (int c = 0; c < 16; c++) {
            if (dict_set_steal(d, k_f_float[c], PyFloat_FromDouble(fc[c]->items[0])) < 0) {
                Py_DECREF(d); PyBuffer_Release(&wire); return NULL;
            }
        }
        for (int c = 0; c < 4; c++) {
            if (dict_set_steal(d, k_f_int[c], PyLong_FromLongLong(ic[c]->items[0])) < 0) {
                Py_DECREF(d); PyBuffer_Release(&wire); return NULL;
            }
        }
        if (dict_set_steal(d, k_f_str[0], str_from_kiln(cols.f_str_0.items[0])) < 0 ||
            dict_set_steal(d, k_f_str[1], str_from_kiln(cols.f_str_1.items[0])) < 0) {
            Py_DECREF(d); PyBuffer_Release(&wire); return NULL;
        }
        PyBuffer_Release(&wire);
        return d;
    }

    PyObject *lst = PyList_New((Py_ssize_t)n);
    if (!lst) { PyBuffer_Release(&wire); return NULL; }
    for (uint64_t r = 0; r < n; r++) {
        PyObject *d = PyDict_New();
        if (!d) { Py_DECREF(lst); PyBuffer_Release(&wire); return NULL; }
        for (int c = 0; c < 16; c++) {
            if (dict_set_steal(d, k_f_float[c], PyFloat_FromDouble(fc[c]->items[r])) < 0) {
                Py_DECREF(d); Py_DECREF(lst); PyBuffer_Release(&wire); return NULL;
            }
        }
        for (int c = 0; c < 4; c++) {
            if (dict_set_steal(d, k_f_int[c], PyLong_FromLongLong(ic[c]->items[r])) < 0) {
                Py_DECREF(d); Py_DECREF(lst); PyBuffer_Release(&wire); return NULL;
            }
        }
        if (dict_set_steal(d, k_f_str[0], str_from_kiln(cols.f_str_0.items[r])) < 0 ||
            dict_set_steal(d, k_f_str[1], str_from_kiln(cols.f_str_1.items[r])) < 0) {
            Py_DECREF(d); Py_DECREF(lst); PyBuffer_Release(&wire); return NULL;
        }
        PyList_SET_ITEM(lst, (Py_ssize_t)r, d);
    }
    PyBuffer_Release(&wire);
    return lst;
}

static PyObject *py_decode_table_project(PyObject *self, PyObject *args) {
    (void)self;
    Py_buffer wire;
    if (!PyArg_ParseTuple(args, "y*", &wire)) return NULL;
    uint8_t *abuf = buf_reserve(&g_arena, (size_t)wire.len + 65536);
    if (!abuf) { PyBuffer_Release(&wire); return NULL; }
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, KILN_OPT_EMBEDDED };
    kiln_result_t res = {0, 0};
    bench_table_project_t proj;
    kiln_err_t err = kiln_asm_decode_bench_table_project((const uint8_t *)wire.buf, (size_t)wire.len, &proj, &arena, &opts, &res);
    if (err != KILN_OK) { PyBuffer_Release(&wire); return raise_kiln_err("decode_table_project", err); }

    uint64_t n = proj.f_float_0.count;
    PyObject *lst = PyList_New((Py_ssize_t)n);
    if (!lst) { PyBuffer_Release(&wire); return NULL; }
    for (uint64_t i = 0; i < n; i++) {
        PyObject *f = PyFloat_FromDouble(proj.f_float_0.items[i]);
        if (!f) { Py_DECREF(lst); PyBuffer_Release(&wire); return NULL; }
        PyList_SET_ITEM(lst, (Py_ssize_t)i, f);
    }
    PyBuffer_Release(&wire);
    return lst;
}

/* ==================== SIGNAL ==================== */

static PyObject *py_encode_signal(PyObject *self, PyObject *args) {
    (void)self;
    PyObject *obj; int batch = 0;
    if (!PyArg_ParseTuple(args, "O|p", &obj, &batch)) return NULL;

    PyObject *seq = NULL;
    PyObject *single_arr[1] = {obj};
    PyObject **rows;
    Py_ssize_t n;
    if (batch) {
        seq = PySequence_Fast(obj, "expected list of signals");
        if (!seq) return NULL;
        n = PySequence_Fast_GET_SIZE(seq);
        rows = PySequence_Fast_ITEMS(seq);
    } else {
        n = 1;
        rows = single_arr;
    }

    size_t total_legs = 0;
    for (Py_ssize_t i = 0; i < n; i++) {
        PyObject *lg = field_get(rows[i], k_legs);
        if (!lg) { Py_XDECREF(seq); return NULL; }
        Py_ssize_t lc = PySequence_Size(lg);
        Py_DECREF(lg);
        if (lc < 0) { Py_XDECREF(seq); return NULL; }
        total_legs += (size_t)lc;
    }

    size_t sig_sz = align16((size_t)n * sizeof(bench_signal_t));
    size_t leg_sz = align16(total_legs * sizeof(bench_signal_signal_leg_t));
    uint8_t *enc = buf_reserve(&g_enc, sig_sz + leg_sz + 64);
    if (!enc) { Py_XDECREF(seq); return NULL; }
    bench_signal_t *sigs = (bench_signal_t *)enc;
    bench_signal_signal_leg_t *all_legs = (bench_signal_signal_leg_t *)(enc + sig_sz);

    ref_keep_t rk = {0};
    size_t pos = 0;
    size_t est = 64 + (size_t)n * 64 + total_legs * 20;
    for (Py_ssize_t i = 0; i < n; i++) {
        PyObject *r = rows[i];
        if (get_i64_field(r, k_seq, &sigs[i].seq) < 0 ||
            get_i64_field(r, k_ts, &sigs[i].ts) < 0 ||
            get_i64_field(r, k_price_mantissa, &sigs[i].price_mantissa) < 0 ||
            get_i32_field(r, k_qty, &sigs[i].qty) < 0 ||
            get_i32_field(r, k_flags, &sigs[i].flags) < 0 ||
            get_str_field(r, k_symbol, &sigs[i].symbol, &rk) < 0 ||
            get_str_field(r, k_venue, &sigs[i].venue, &rk) < 0) goto fail;
        est += (size_t)sigs[i].symbol.len + (size_t)sigs[i].venue.len;

        PyObject *lg_obj = field_get(r, k_legs);
        if (!lg_obj) goto fail;
        PyObject *lg_seq = PySequence_Fast(lg_obj, "expected legs list");
        Py_DECREF(lg_obj);
        if (!lg_seq) goto fail;
        Py_ssize_t lc = PySequence_Fast_GET_SIZE(lg_seq);
        PyObject **lg_arr = PySequence_Fast_ITEMS(lg_seq);
        sigs[i].legs.items = lc > 0 ? &all_legs[pos] : NULL;
        sigs[i].legs.count = (uint64_t)lc;
        for (Py_ssize_t j = 0; j < lc; j++) {
            bench_signal_signal_leg_t *l = &all_legs[pos++];
            if (get_i64_field(lg_arr[j], k_leg_id, &l->leg_id) < 0 ||
                get_i32_field(lg_arr[j], k_leg_qty, &l->leg_qty) < 0 ||
                get_i32_field(lg_arr[j], k_leg_pad, &l->leg_pad) < 0) {
                Py_DECREF(lg_seq);
                goto fail;
            }
        }
        Py_DECREF(lg_seq);
    }

    uint8_t *out = buf_reserve(&g_out, est);
    if (!out) goto fail;
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    kiln_err_t err = batch
        ? kiln_asm_encode_bench_signal_batch(sigs, (size_t)n, out, g_out.cap, &opts, &res)
        : kiln_asm_encode_bench_signal(sigs, out, g_out.cap, &opts, &res);
    keep_release(&rk);
    Py_XDECREF(seq);
    if (err != KILN_OK) return raise_kiln_err("encode_signal", err);
    return PyBytes_FromStringAndSize((const char *)out, (Py_ssize_t)res.bytes);

fail:
    keep_release(&rk);
    Py_XDECREF(seq);
    return NULL;
}

static PyObject *unpack_signal_one(const bench_signal_t *s) {
    PyObject *d = PyDict_New();
    if (!d) return NULL;
    PyObject *legs = PyList_New((Py_ssize_t)s->legs.count);
    if (!legs) { Py_DECREF(d); return NULL; }
    for (uint64_t j = 0; j < s->legs.count; j++) {
        PyObject *ld = PyDict_New();
        if (!ld) { Py_DECREF(legs); Py_DECREF(d); return NULL; }
        if (dict_set_steal(ld, k_leg_id, PyLong_FromLongLong(s->legs.items[j].leg_id)) < 0 ||
            dict_set_steal(ld, k_leg_qty, PyLong_FromLong(s->legs.items[j].leg_qty)) < 0 ||
            dict_set_steal(ld, k_leg_pad, PyLong_FromLong(s->legs.items[j].leg_pad)) < 0) {
            Py_DECREF(ld); Py_DECREF(legs); Py_DECREF(d); return NULL;
        }
        PyList_SET_ITEM(legs, (Py_ssize_t)j, ld);
    }
    if (dict_set_steal(d, k_seq, PyLong_FromLongLong(s->seq)) < 0 ||
        dict_set_steal(d, k_ts, PyLong_FromLongLong(s->ts)) < 0 ||
        dict_set_steal(d, k_price_mantissa, PyLong_FromLongLong(s->price_mantissa)) < 0 ||
        dict_set_steal(d, k_qty, PyLong_FromLong(s->qty)) < 0 ||
        dict_set_steal(d, k_flags, PyLong_FromLong(s->flags)) < 0 ||
        dict_set_steal(d, k_symbol, str_from_kiln(s->symbol)) < 0 ||
        dict_set_steal(d, k_venue, str_from_kiln(s->venue)) < 0 ||
        dict_set_steal(d, k_legs, legs) < 0) {
        Py_DECREF(d);
        return NULL;
    }
    return d;
}

static PyObject *py_decode_signal(PyObject *self, PyObject *args) {
    (void)self;
    Py_buffer wire; int batch = 0;
    if (!PyArg_ParseTuple(args, "y*|p", &wire, &batch)) return NULL;
    uint8_t *abuf = buf_reserve(&g_arena, (size_t)wire.len * 4 + 131072);
    if (!abuf) { PyBuffer_Release(&wire); return NULL; }
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};

    if (!batch) {
        bench_signal_t s;
        kiln_err_t err = kiln_asm_decode_bench_signal((const uint8_t *)wire.buf, (size_t)wire.len, &s, &arena, &opts, &res);
        if (err != KILN_OK) { PyBuffer_Release(&wire); return raise_kiln_err("decode_signal", err); }
        PyObject *d = unpack_signal_one(&s);
        PyBuffer_Release(&wire);
        return d;
    }

    bench_signal_t *arr = NULL;
    size_t cnt = 0;
    kiln_err_t err = kiln_asm_decode_bench_signal_batch((const uint8_t *)wire.buf, (size_t)wire.len, &arr, &cnt, &arena, &opts, &res);
    if (err != KILN_OK) { PyBuffer_Release(&wire); return raise_kiln_err("decode_signal_batch", err); }
    PyObject *lst = PyList_New((Py_ssize_t)cnt);
    if (!lst) { PyBuffer_Release(&wire); return NULL; }
    for (size_t i = 0; i < cnt; i++) {
        PyObject *d = unpack_signal_one(&arr[i]);
        if (!d) { Py_DECREF(lst); PyBuffer_Release(&wire); return NULL; }
        PyList_SET_ITEM(lst, (Py_ssize_t)i, d);
    }
    PyBuffer_Release(&wire);
    return lst;
}

/* ==================== ARRAY: GRID & GRID_WINDOW ==================== */

static PyObject *py_encode_grid(PyObject *self, PyObject *args) {
    (void)self;
    int nx, ny;
    PyObject *vals;
    if (!PyArg_ParseTuple(args, "iiO", &nx, &ny, &vals)) return NULL;
    num_view_t nv;
    if (num_view_acquire_f64(vals, &nv) < 0) return NULL;

    kiln_tensor_t t;
    set_tensor_2d(&t, KILN_DTYPE_F64, (uint64_t)ny, (uint64_t)nx, nv.ptr, nv.nbytes);
    kiln_tensor_dir_t dir = { &t, 1, 0, 2, 2 };
    uint8_t *out = buf_reserve(&g_out, nv.nbytes + 512);
    if (!out) { num_view_release(&nv); return NULL; }

    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    kiln_err_t err = kiln_asm_encode_tensors(&dir, out, g_out.cap, &opts, &res);
    num_view_release(&nv);
    if (err != KILN_OK) return raise_kiln_err("encode_grid", err);
    return PyBytes_FromStringAndSize((const char *)out, (Py_ssize_t)res.bytes);
}

static PyObject *py_decode_grid(PyObject *self, PyObject *args) {
    (void)self;
    Py_buffer wire;
    if (!PyArg_ParseTuple(args, "y*", &wire)) return NULL;
    uint8_t *abuf = buf_reserve(&g_arena, 4096);
    if (!abuf) { PyBuffer_Release(&wire); return NULL; }
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    kiln_tensor_dir_t dir;
    kiln_err_t err = kiln_asm_decode_tensors((const uint8_t *)wire.buf, (size_t)wire.len, &dir, &arena, &opts, &res);
    if (err != KILN_OK || dir.count != 1 || dir.items[0].dtype != KILN_DTYPE_F64) {
        PyBuffer_Release(&wire);
        return raise_kiln_err("decode_grid", err != KILN_OK ? err : KILN_ERR_TYPE);
    }
    const uint8_t *src = dir.items[0].data;
    size_t n = (size_t)(dir.items[0].data_len / sizeof(double));
    PyObject *lst = PyList_New((Py_ssize_t)n);
    if (!lst) { PyBuffer_Release(&wire); return NULL; }
    for (size_t i = 0; i < n; i++) {
        double v;
        memcpy(&v, src + i * sizeof(double), sizeof(double));
        PyObject *f = PyFloat_FromDouble(v);
        if (!f) { Py_DECREF(lst); PyBuffer_Release(&wire); return NULL; }
        PyList_SET_ITEM(lst, (Py_ssize_t)i, f);
    }
    PyBuffer_Release(&wire);
    return lst;
}

static PyObject *py_decode_grid_window(PyObject *self, PyObject *args) {
    (void)self;
    Py_buffer wire;
    int x0, y0, wx, wy;
    if (!PyArg_ParseTuple(args, "y*iiii", &wire, &x0, &y0, &wx, &wy)) return NULL;
    uint8_t *abuf = buf_reserve(&g_arena, 4096);
    if (!abuf) { PyBuffer_Release(&wire); return NULL; }
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    kiln_tensor_dir_t dir;
    kiln_err_t err = kiln_asm_decode_tensors((const uint8_t *)wire.buf, (size_t)wire.len, &dir, &arena, &opts, &res);
    if (err != KILN_OK || dir.count != 1 || dir.items[0].dtype != KILN_DTYPE_F64 || dir.items[0].rank != 2) {
        PyBuffer_Release(&wire);
        return raise_kiln_err("decode_grid_window", err != KILN_OK ? err : KILN_ERR_TYPE);
    }
    uint64_t ny = dir.items[0].shape[0];
    uint64_t nx = dir.items[0].shape[1];
    if (x0 < 0 || y0 < 0 || wx < 0 || wy < 0 || (uint64_t)(x0 + wx) > nx || (uint64_t)(y0 + wy) > ny) {
        PyBuffer_Release(&wire);
        PyErr_SetString(PyExc_ValueError, "grid_window bounds out of range");
        return NULL;
    }
    const uint8_t *src = dir.items[0].data;
    Py_ssize_t total = (Py_ssize_t)wx * (Py_ssize_t)wy;
    PyObject *lst = PyList_New(total);
    if (!lst) { PyBuffer_Release(&wire); return NULL; }
    Py_ssize_t out_i = 0;
    for (int y = y0; y < y0 + wy; y++) {
        size_t row_off = ((size_t)y * (size_t)nx + (size_t)x0) * sizeof(double);
        for (int x = 0; x < wx; x++) {
            double v;
            memcpy(&v, src + row_off + (size_t)x * sizeof(double), sizeof(double));
            PyObject *f = PyFloat_FromDouble(v);
            if (!f) { Py_DECREF(lst); PyBuffer_Release(&wire); return NULL; }
            PyList_SET_ITEM(lst, out_i++, f);
        }
    }
    PyBuffer_Release(&wire);
    return lst;
}

/* ==================== TENSOR: TENSOR, TENSOR_VIEW, PROMPT, SHARD, REQUEST ==================== */

static PyObject *py_encode_tensor(PyObject *self, PyObject *args) {
    (void)self;
    PyObject *obj;
    if (!PyArg_ParseTuple(args, "O", &obj)) return NULL;
    int32_t rows = 0, cols = 0;
    if (get_i32_field(obj, k_rows, &rows) < 0 || get_i32_field(obj, k_cols, &cols) < 0) return NULL;
    PyObject *vobj = field_get(obj, k_values);
    if (!vobj) return NULL;
    num_view_t nv;
    int rc = num_view_acquire_f32(vobj, &nv);
    Py_DECREF(vobj);
    if (rc < 0) return NULL;

    kiln_tensor_t t;
    set_tensor_2d(&t, KILN_DTYPE_F32, (uint64_t)rows, (uint64_t)cols, nv.ptr, nv.nbytes);
    kiln_tensor_dir_t dir = { &t, 1, 0, 2, 2 };
    uint8_t *out = buf_reserve(&g_out, nv.nbytes + 512);
    if (!out) { num_view_release(&nv); return NULL; }
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    kiln_err_t err = kiln_asm_encode_tensors(&dir, out, g_out.cap, &opts, &res);
    num_view_release(&nv);
    if (err != KILN_OK) return raise_kiln_err("encode_tensor", err);
    return PyBytes_FromStringAndSize((const char *)out, (Py_ssize_t)res.bytes);
}

static PyObject *py_decode_tensor(PyObject *self, PyObject *args) {
    (void)self;
    Py_buffer wire;
    if (!PyArg_ParseTuple(args, "y*", &wire)) return NULL;
    uint8_t *abuf = buf_reserve(&g_arena, 4096);
    if (!abuf) { PyBuffer_Release(&wire); return NULL; }
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    kiln_tensor_dir_t dir;
    kiln_err_t err = kiln_asm_decode_tensors((const uint8_t *)wire.buf, (size_t)wire.len, &dir, &arena, &opts, &res);
    if (err != KILN_OK || dir.count != 1 || dir.items[0].dtype != KILN_DTYPE_F32 || dir.items[0].rank != 2) {
        PyBuffer_Release(&wire);
        return raise_kiln_err("decode_tensor", err != KILN_OK ? err : KILN_ERR_TYPE);
    }
    PyObject *vals = make_array_copy(g_str_f, dir.items[0].data, (size_t)dir.items[0].data_len);
    int64_t rows = (int64_t)dir.items[0].shape[0];
    int64_t cols = (int64_t)dir.items[0].shape[1];
    PyBuffer_Release(&wire);
    if (!vals) return NULL;
    PyObject *d = PyDict_New();
    if (!d) { Py_DECREF(vals); return NULL; }
    if (dict_set_steal(d, k_rows, PyLong_FromLongLong(rows)) < 0 ||
        dict_set_steal(d, k_cols, PyLong_FromLongLong(cols)) < 0 ||
        dict_set_steal(d, k_values, vals) < 0) {
        Py_DECREF(d);
        return NULL;
    }
    return d;
}

static PyObject *py_decode_tensor_view(PyObject *self, PyObject *args) {
    (void)self;
    PyObject *wire_obj;
    if (!PyArg_ParseTuple(args, "O", &wire_obj)) return NULL;
    Py_buffer wire;
    if (PyObject_GetBuffer(wire_obj, &wire, PyBUF_SIMPLE) < 0) return NULL;

    uint8_t *abuf = buf_reserve(&g_arena, 4096);
    if (!abuf) { PyBuffer_Release(&wire); return NULL; }
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    kiln_tensor_dir_t dir;
    kiln_err_t err = kiln_asm_decode_tensors((const uint8_t *)wire.buf, (size_t)wire.len, &dir, &arena, &opts, &res);
    if (err != KILN_OK || dir.count != 1 || dir.items[0].dtype != KILN_DTYPE_F32 || dir.items[0].rank != 2) {
        PyBuffer_Release(&wire);
        return raise_kiln_err("decode_tensor_view", err != KILN_OK ? err : KILN_ERR_TYPE);
    }
    Py_ssize_t off = (Py_ssize_t)(dir.items[0].data - (const uint8_t *)wire.buf);
    Py_ssize_t nbytes = (Py_ssize_t)dir.items[0].data_len;
    int64_t rows = (int64_t)dir.items[0].shape[0];
    int64_t cols = (int64_t)dir.items[0].shape[1];
    PyBuffer_Release(&wire);

    /* Genuine zero-copy borrow: memoryview(wire_obj)[off:off+nbytes].cast('f') */
    PyObject *mv = PyMemoryView_FromObject(wire_obj);
    if (!mv) return NULL;
    PyObject *pstart = PyLong_FromSsize_t(off);
    PyObject *pstop = PyLong_FromSsize_t(off + nbytes);
    PyObject *sl = (pstart && pstop) ? PySlice_New(pstart, pstop, NULL) : NULL;
    Py_XDECREF(pstart);
    Py_XDECREF(pstop);
    if (!sl) { Py_DECREF(mv); return NULL; }
    PyObject *sub = PyObject_GetItem(mv, sl);
    Py_DECREF(sl);
    Py_DECREF(mv);
    if (!sub) return NULL;
    PyObject *casted = PyObject_CallMethodOneArg(sub, g_str_cast, g_str_f);
    Py_DECREF(sub);
    if (!casted) return NULL;

    PyObject *d = PyDict_New();
    if (!d) { Py_DECREF(casted); return NULL; }
    if (dict_set_steal(d, k_rows, PyLong_FromLongLong(rows)) < 0 ||
        dict_set_steal(d, k_cols, PyLong_FromLongLong(cols)) < 0 ||
        dict_set_steal(d, k_values, casted) < 0) {
        Py_DECREF(d);
        return NULL;
    }
    return d;
}

static PyObject *py_encode_prompt(PyObject *self, PyObject *args) {
    (void)self;
    PyObject *obj;
    if (!PyArg_ParseTuple(args, "O", &obj)) return NULL;
    int32_t batch = 0, seq = 0;
    if (get_i32_field(obj, k_batch, &batch) < 0 || get_i32_field(obj, k_seq, &seq) < 0) return NULL;
    PyObject *o0 = field_get(obj, k_input_ids);
    PyObject *o1 = o0 ? field_get(obj, k_attention_mask) : NULL;
    PyObject *o2 = o1 ? field_get(obj, k_position_ids) : NULL;
    if (!o2) { Py_XDECREF(o0); Py_XDECREF(o1); return NULL; }

    num_view_t nv[3];
    memset(nv, 0, sizeof nv);
    int ok = (num_view_acquire_i64(o0, &nv[0]) == 0 &&
              num_view_acquire_i64(o1, &nv[1]) == 0 &&
              num_view_acquire_i64(o2, &nv[2]) == 0);
    Py_DECREF(o0); Py_DECREF(o1); Py_DECREF(o2);
    if (!ok) { for (int i = 0; i < 3; i++) num_view_release(&nv[i]); return NULL; }

    kiln_tensor_t ts[3];
    for (int i = 0; i < 3; i++) {
        set_tensor_2d(&ts[i], KILN_DTYPE_I64, (uint64_t)batch, (uint64_t)seq, nv[i].ptr, nv[i].nbytes);
    }
    kiln_tensor_dir_t dir = { ts, 3, 0, 2, 2 };
    size_t est = nv[0].nbytes + nv[1].nbytes + nv[2].nbytes + 1024;
    uint8_t *out = buf_reserve(&g_out, est);
    if (!out) { for (int i = 0; i < 3; i++) num_view_release(&nv[i]); return NULL; }
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    kiln_err_t err = kiln_asm_encode_tensors(&dir, out, g_out.cap, &opts, &res);
    for (int i = 0; i < 3; i++) num_view_release(&nv[i]);
    if (err != KILN_OK) return raise_kiln_err("encode_prompt", err);
    return PyBytes_FromStringAndSize((const char *)out, (Py_ssize_t)res.bytes);
}

static PyObject *unpack_prompt_dir(const kiln_tensor_dir_t *dir) {
    if (dir->count != 3 || dir->items[0].dtype != KILN_DTYPE_I64 || dir->items[0].rank != 2) {
        return raise_kiln_err("decode_prompt", KILN_ERR_TYPE);
    }
    PyObject *a0 = make_array_copy(g_str_q, dir->items[0].data, (size_t)dir->items[0].data_len);
    PyObject *a1 = a0 ? make_array_copy(g_str_q, dir->items[1].data, (size_t)dir->items[1].data_len) : NULL;
    PyObject *a2 = a1 ? make_array_copy(g_str_q, dir->items[2].data, (size_t)dir->items[2].data_len) : NULL;
    if (!a2) { Py_XDECREF(a0); Py_XDECREF(a1); return NULL; }
    PyObject *d = PyDict_New();
    if (!d) { Py_DECREF(a0); Py_DECREF(a1); Py_DECREF(a2); return NULL; }
    if (dict_set_steal(d, k_batch, PyLong_FromUnsignedLongLong(dir->items[0].shape[0])) < 0 ||
        dict_set_steal(d, k_seq, PyLong_FromUnsignedLongLong(dir->items[0].shape[1])) < 0 ||
        dict_set_steal(d, k_input_ids, a0) < 0 ||
        dict_set_steal(d, k_attention_mask, a1) < 0 ||
        dict_set_steal(d, k_position_ids, a2) < 0) {
        Py_DECREF(d);
        return NULL;
    }
    return d;
}

static PyObject *py_decode_prompt(PyObject *self, PyObject *args) {
    (void)self;
    Py_buffer wire;
    if (!PyArg_ParseTuple(args, "y*", &wire)) return NULL;
    uint8_t *abuf = buf_reserve(&g_arena, 4096);
    if (!abuf) { PyBuffer_Release(&wire); return NULL; }
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    kiln_tensor_dir_t dir;
    kiln_err_t err = kiln_asm_decode_tensors((const uint8_t *)wire.buf, (size_t)wire.len, &dir, &arena, &opts, &res);
    if (err != KILN_OK) { PyBuffer_Release(&wire); return raise_kiln_err("decode_prompt", err); }
    PyObject *d = unpack_prompt_dir(&dir);
    PyBuffer_Release(&wire);
    return d;
}

static PyObject *py_encode_shard(PyObject *self, PyObject *args) {
    (void)self;
    PyObject *obj;
    if (!PyArg_ParseTuple(args, "O", &obj)) return NULL;
    int32_t vocab = 0, hidden = 0, ffn = 0;
    if (get_i32_field(obj, k_vocab, &vocab) < 0 ||
        get_i32_field(obj, k_hidden, &hidden) < 0 ||
        get_i32_field(obj, k_ffn, &ffn) < 0) return NULL;
    PyObject *o0 = field_get(obj, k_tok_emb);
    PyObject *o1 = o0 ? field_get(obj, k_attn) : NULL;
    PyObject *o2 = o1 ? field_get(obj, k_ffn_weight) : NULL;
    PyObject *o3 = o2 ? field_get(obj, k_norm) : NULL;
    if (!o3) { Py_XDECREF(o0); Py_XDECREF(o1); Py_XDECREF(o2); return NULL; }

    num_view_t nv[4];
    memset(nv, 0, sizeof nv);
    int ok = (num_view_acquire_f32(o0, &nv[0]) == 0 &&
              num_view_acquire_f32(o1, &nv[1]) == 0 &&
              num_view_acquire_f32(o2, &nv[2]) == 0 &&
              num_view_acquire_f32(o3, &nv[3]) == 0);
    Py_DECREF(o0); Py_DECREF(o1); Py_DECREF(o2); Py_DECREF(o3);
    if (!ok) { for (int i = 0; i < 4; i++) num_view_release(&nv[i]); return NULL; }

    kiln_tensor_t ts[4];
    set_tensor_2d(&ts[0], KILN_DTYPE_F32, (uint64_t)vocab, (uint64_t)hidden, nv[0].ptr, nv[0].nbytes);
    set_tensor_2d(&ts[1], KILN_DTYPE_F32, (uint64_t)hidden, (uint64_t)hidden, nv[1].ptr, nv[1].nbytes);
    set_tensor_2d(&ts[2], KILN_DTYPE_F32, (uint64_t)ffn, (uint64_t)hidden, nv[2].ptr, nv[2].nbytes);
    set_tensor_1d(&ts[3], KILN_DTYPE_F32, (uint64_t)hidden, nv[3].ptr, nv[3].nbytes);

    kiln_tensor_dir_t dir = { ts, 4, 0, 2, 2 };
    size_t est = nv[0].nbytes + nv[1].nbytes + nv[2].nbytes + nv[3].nbytes + 2048;
    uint8_t *out = buf_reserve(&g_out, est);
    if (!out) { for (int i = 0; i < 4; i++) num_view_release(&nv[i]); return NULL; }
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    kiln_err_t err = kiln_asm_encode_tensors(&dir, out, g_out.cap, &opts, &res);
    for (int i = 0; i < 4; i++) num_view_release(&nv[i]);
    if (err != KILN_OK) return raise_kiln_err("encode_shard", err);
    return PyBytes_FromStringAndSize((const char *)out, (Py_ssize_t)res.bytes);
}

static PyObject *py_decode_shard(PyObject *self, PyObject *args) {
    (void)self;
    Py_buffer wire;
    if (!PyArg_ParseTuple(args, "y*", &wire)) return NULL;
    uint8_t *abuf = buf_reserve(&g_arena, 4096);
    if (!abuf) { PyBuffer_Release(&wire); return NULL; }
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    kiln_tensor_dir_t dir;
    kiln_err_t err = kiln_asm_decode_tensors((const uint8_t *)wire.buf, (size_t)wire.len, &dir, &arena, &opts, &res);
    if (err != KILN_OK || dir.count != 4) {
        PyBuffer_Release(&wire);
        return raise_kiln_err("decode_shard", err != KILN_OK ? err : KILN_ERR_TYPE);
    }
    PyObject *a0 = make_array_copy(g_str_f, dir.items[0].data, (size_t)dir.items[0].data_len);
    PyObject *a1 = a0 ? make_array_copy(g_str_f, dir.items[1].data, (size_t)dir.items[1].data_len) : NULL;
    PyObject *a2 = a1 ? make_array_copy(g_str_f, dir.items[2].data, (size_t)dir.items[2].data_len) : NULL;
    PyObject *a3 = a2 ? make_array_copy(g_str_f, dir.items[3].data, (size_t)dir.items[3].data_len) : NULL;
    uint64_t vocab = dir.items[0].shape[0];
    uint64_t hidden = dir.items[0].shape[1];
    uint64_t ffn = dir.items[2].shape[0];
    PyBuffer_Release(&wire);
    if (!a3) { Py_XDECREF(a0); Py_XDECREF(a1); Py_XDECREF(a2); return NULL; }

    PyObject *d = PyDict_New();
    if (!d) { Py_DECREF(a0); Py_DECREF(a1); Py_DECREF(a2); Py_DECREF(a3); return NULL; }
    if (dict_set_steal(d, k_vocab, PyLong_FromUnsignedLongLong(vocab)) < 0 ||
        dict_set_steal(d, k_hidden, PyLong_FromUnsignedLongLong(hidden)) < 0 ||
        dict_set_steal(d, k_ffn, PyLong_FromUnsignedLongLong(ffn)) < 0 ||
        dict_set_steal(d, k_tok_emb, a0) < 0 ||
        dict_set_steal(d, k_attn, a1) < 0 ||
        dict_set_steal(d, k_ffn_weight, a2) < 0 ||
        dict_set_steal(d, k_norm, a3) < 0) {
        Py_DECREF(d);
        return NULL;
    }
    return d;
}

static PyObject *py_encode_request(PyObject *self, PyObject *args) {
    (void)self;
    PyObject *obj;
    if (!PyArg_ParseTuple(args, "O", &obj)) return NULL;
    int64_t req_id = 0;
    double temp = 0.0;
    kiln_str_t model = {NULL, 0};
    ref_keep_t rk = {0};
    if (get_i64_field(obj, k_request_id, &req_id) < 0 ||
        get_str_field(obj, k_model, &model, &rk) < 0 ||
        get_f64_field(obj, k_temperature, &temp) < 0) {
        keep_release(&rk);
        return NULL;
    }
    PyObject *inp = field_get(obj, k_inputs);
    if (!inp) { keep_release(&rk); return NULL; }
    int32_t batch = 0, seq = 0;
    if (get_i32_field(inp, k_batch, &batch) < 0 || get_i32_field(inp, k_seq, &seq) < 0) {
        Py_DECREF(inp); keep_release(&rk); return NULL;
    }
    PyObject *o0 = field_get(inp, k_input_ids);
    PyObject *o1 = o0 ? field_get(inp, k_attention_mask) : NULL;
    PyObject *o2 = o1 ? field_get(inp, k_position_ids) : NULL;
    Py_DECREF(inp);
    if (!o2) { Py_XDECREF(o0); Py_XDECREF(o1); keep_release(&rk); return NULL; }

    num_view_t nv[3];
    memset(nv, 0, sizeof nv);
    int ok = (num_view_acquire_i64(o0, &nv[0]) == 0 &&
              num_view_acquire_i64(o1, &nv[1]) == 0 &&
              num_view_acquire_i64(o2, &nv[2]) == 0);
    Py_DECREF(o0); Py_DECREF(o1); Py_DECREF(o2);
    if (!ok) {
        for (int i = 0; i < 3; i++) num_view_release(&nv[i]);
        keep_release(&rk);
        return NULL;
    }

    kiln_tensor_t ts[3];
    for (int i = 0; i < 3; i++) {
        set_tensor_2d(&ts[i], KILN_DTYPE_I64, (uint64_t)batch, (uint64_t)seq, nv[i].ptr, nv[i].nbytes);
    }
    bench_request_t req;
    req.request_id = req_id;
    req.model = model;
    req.temperature = (float)temp;
    req.inputs.items = ts;
    req.inputs.count = 3;
    req.inputs.block_length = 0;
    req.inputs.flags = 2;
    req.inputs.version = 2;

    size_t est = (size_t)model.len + nv[0].nbytes + nv[1].nbytes + nv[2].nbytes + 1024;
    uint8_t *out = buf_reserve(&g_out, est);
    if (!out) {
        for (int i = 0; i < 3; i++) num_view_release(&nv[i]);
        keep_release(&rk);
        return NULL;
    }
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    kiln_err_t err = kiln_asm_encode_bench_request(&req, out, g_out.cap, &opts, &res);
    for (int i = 0; i < 3; i++) num_view_release(&nv[i]);
    keep_release(&rk);
    if (err != KILN_OK) return raise_kiln_err("encode_request", err);
    return PyBytes_FromStringAndSize((const char *)out, (Py_ssize_t)res.bytes);
}

static PyObject *py_decode_request(PyObject *self, PyObject *args) {
    (void)self;
    Py_buffer wire;
    if (!PyArg_ParseTuple(args, "y*", &wire)) return NULL;
    uint8_t *abuf = buf_reserve(&g_arena, 4096);
    if (!abuf) { PyBuffer_Release(&wire); return NULL; }
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);
    kiln_read_opts_t opts = { KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0 };
    kiln_result_t res = {0, 0};
    bench_request_t req;
    kiln_err_t err = kiln_asm_decode_bench_request((const uint8_t *)wire.buf, (size_t)wire.len, &req, &arena, &opts, &res);
    if (err != KILN_OK) { PyBuffer_Release(&wire); return raise_kiln_err("decode_request", err); }
    PyObject *inputs = unpack_prompt_dir(&req.inputs);
    if (!inputs) { PyBuffer_Release(&wire); return NULL; }
    PyObject *model_str = str_from_kiln(req.model);
    PyBuffer_Release(&wire);
    if (!model_str) { Py_DECREF(inputs); return NULL; }

    PyObject *d = PyDict_New();
    if (!d) { Py_DECREF(model_str); Py_DECREF(inputs); return NULL; }
    if (dict_set_steal(d, k_request_id, PyLong_FromLongLong(req.request_id)) < 0 ||
        dict_set_steal(d, k_model, model_str) < 0 ||
        dict_set_steal(d, k_temperature, PyFloat_FromDouble((double)req.temperature)) < 0 ||
        dict_set_steal(d, k_inputs, inputs) < 0) {
        Py_DECREF(d);
        return NULL;
    }
    return d;
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
    char tmp[32];
    snprintf(tmp, sizeof tmp, "%" PRIu64, v);
    jb_str(jb, tmp);
}

static void jb_i64(jbuf_t *jb, int64_t v) {
    char tmp[32];
    snprintf(tmp, sizeof tmp, "%" PRId64, v);
    jb_str(jb, tmp);
}

static void jb_json_str(jbuf_t *jb, const uint8_t *s, size_t n) {
    jb_str(jb, "\"");
    for (size_t i = 0; i < n; i++) {
        uint8_t c = s[i];
        if (c == '"' || c == '\\') {
            char esc[3] = {'\\', (char)c, 0};
            jb_str(jb, esc);
        } else if (c < 0x20) {
            char esc[8];
            snprintf(esc, sizeof esc, "\\u%04x", c);
            jb_str(jb, esc);
        } else {
            jb_grow(jb, 1);
            jb->p[jb->n++] = (char)c;
            jb->p[jb->n] = '\0';
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
    jb_str(jb, "{\"version\":");
    jb_u64(jb, dir->version);
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
        for (uint8_t r = 0; r < t->rank; r++) {
            if (r) jb_str(jb, ",");
            jb_u64(jb, t->shape[r]);
        }
        jb_str(jb, "],\"quant_scheme\":");
        jb_u64(jb, t->quant_scheme);
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
    jb_str(jb, "],\"block_length\":");
    jb_u64(jb, dir->block_length);
    jb_str(jb, "}");
}

static PyObject *py_compliance_decode_json(PyObject *self, PyObject *args) {
    (void)self;
    Py_buffer wire;
    int schema_tag = 0;
    if (!PyArg_ParseTuple(args, "y*i", &wire, &schema_tag)) return NULL;

    uint8_t *abuf = buf_reserve(&g_arena, 1 << 20);
    if (!abuf) { PyBuffer_Release(&wire); return NULL; }
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);

    const uint8_t *w = (const uint8_t *)wire.buf;
    size_t wlen = (size_t)wire.len;
    kiln_result_t res = {0, 0};
    kiln_err_t err = KILN_ERR_FRAME;
    jbuf_t jb = {NULL, 0, 0};

    switch (schema_tag) {
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
                jb_str(&jb, "{\"hash\":");
                jb_u64(&jb, res.hash);
                jb_str(&jb, ",\"id\":");
                jb_i64(&jb, v.id);
                jb_str(&jb, ",\"batch\":");
                jb_tensor_dir(&jb, &v.batch);
                jb_str(&jb, "}");
            }
            break;
        }
        case 2: {
            kiln_id_tensors_t v;
            err = kiln_asm_decode_id_tensors(w, wlen, &v, &arena, NULL, &res);
            if (err == KILN_OK) {
                jb_str(&jb, "{\"id\":");
                jb_i64(&jb, v.id);
                jb_str(&jb, ",\"batch\":");
                jb_tensor_dir(&jb, &v.batch);
                jb_str(&jb, "}");
            }
            break;
        }
        case 3: {
            const uint8_t *raw = NULL;
            size_t cnt = 0;
            err = kiln_asm_decode_list_f32(w, wlen, &raw, &cnt, &arena, NULL, &res);
            if (err == KILN_OK) {
                jb_str(&jb, "[");
                for (size_t i = 0; i < cnt; i++) {
                    float fv;
                    memcpy(&fv, raw + i * 4, 4);
                    if (i) jb_str(&jb, ",");
                    char tmp[64];
                    snprintf(tmp, sizeof tmp, "%.9g", (double)fv);
                    jb_str(&jb, tmp);
                }
                jb_str(&jb, "]");
            }
            break;
        }
        case 4: {
            kiln_str_t *items = NULL;
            size_t cnt = 0;
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
            const uint8_t *raw = NULL;
            size_t cnt = 0;
            err = kiln_asm_decode_list_i64_struct(w, wlen, &raw, &cnt, &arena, NULL, &res);
            if (err == KILN_OK) {
                jb_str(&jb, "[");
                for (size_t i = 0; i < cnt; i++) {
                    int64_t iv;
                    memcpy(&iv, raw + i * 8, 8);
                    if (i) jb_str(&jb, ",");
                    jb_str(&jb, "{\"a\":");
                    jb_i64(&jb, iv);
                    jb_str(&jb, "}");
                }
                jb_str(&jb, "]");
            }
            break;
        }
        default:
            err = KILN_ERR_SCHEMA;
            break;
    }

    PyBuffer_Release(&wire);
    if (err != KILN_OK) {
        free(jb.p);
        return raise_kiln_err("compliance", err);
    }
    PyObject *ret = PyUnicode_FromStringAndSize(jb.p ? jb.p : "null", jb.p ? (Py_ssize_t)jb.n : 4);
    free(jb.p);
    return ret;
}

static PyObject *py_version(PyObject *self, PyObject *Py_UNUSED(ignored)) {
    (void)self;
    return PyUnicode_FromString(kiln_asm_version());
}

static PyMethodDef g_methods[] = {
    {"version", py_version, METH_NOARGS, "Return gld-kiln-asm version."},
    {"encode_message", py_encode_message, METH_VARARGS, NULL},
    {"decode_message", py_decode_message, METH_VARARGS, NULL},
    {"encode_document", py_encode_document, METH_VARARGS, NULL},
    {"decode_document", py_decode_document, METH_VARARGS, NULL},
    {"encode_telemetry", py_encode_telemetry, METH_VARARGS, NULL},
    {"decode_telemetry", py_decode_telemetry, METH_VARARGS, NULL},
    {"encode_strings", py_encode_strings, METH_VARARGS, NULL},
    {"decode_strings", py_decode_strings, METH_VARARGS, NULL},
    {"encode_event", py_encode_event, METH_VARARGS, NULL},
    {"decode_event", py_decode_event, METH_VARARGS, NULL},
    {"encode_table", py_encode_table, METH_VARARGS, NULL},
    {"decode_table", py_decode_table, METH_VARARGS, NULL},
    {"decode_table_project", py_decode_table_project, METH_VARARGS, NULL},
    {"encode_nested_table", py_encode_nested_table, METH_VARARGS, NULL},
    {"decode_nested_table", py_decode_nested_table, METH_VARARGS, NULL},
    {"encode_signal", py_encode_signal, METH_VARARGS, NULL},
    {"decode_signal", py_decode_signal, METH_VARARGS, NULL},
    {"encode_grid", py_encode_grid, METH_VARARGS, NULL},
    {"decode_grid", py_decode_grid, METH_VARARGS, NULL},
    {"decode_grid_window", py_decode_grid_window, METH_VARARGS, NULL},
    {"encode_tensor", py_encode_tensor, METH_VARARGS, NULL},
    {"decode_tensor", py_decode_tensor, METH_VARARGS, NULL},
    {"decode_tensor_view", py_decode_tensor_view, METH_VARARGS, NULL},
    {"encode_prompt", py_encode_prompt, METH_VARARGS, NULL},
    {"decode_prompt", py_decode_prompt, METH_VARARGS, NULL},
    {"encode_shard", py_encode_shard, METH_VARARGS, NULL},
    {"decode_shard", py_decode_shard, METH_VARARGS, NULL},
    {"encode_request", py_encode_request, METH_VARARGS, NULL},
    {"decode_request", py_decode_request, METH_VARARGS, NULL},
    {"compliance_decode_json", py_compliance_decode_json, METH_VARARGS, NULL},
    {NULL, NULL, 0, NULL}
};

static struct PyModuleDef g_module = {
    PyModuleDef_HEAD_INIT,
    "_kiln_asm_ext",
    "CPython C-API bridge for gld-kiln-asm 0.2.0",
    -1,
    g_methods,
    NULL,
    NULL,
    NULL,
    NULL
};

#define INTERN(var, name) do { \
    var = PyUnicode_InternFromString(name); \
    if (!var) return NULL; \
} while (0)

PyMODINIT_FUNC PyInit__kiln_asm_ext(void) {
    PyObject *arr_mod = PyImport_ImportModule("array");
    if (!arr_mod) return NULL;
    g_array_cls = PyObject_GetAttrString(arr_mod, "array");
    Py_DECREF(arr_mod);
    if (!g_array_cls) return NULL;

    INTERN(g_str_frombytes, "frombytes");
    INTERN(g_str_cast, "cast");
    INTERN(g_str_f, "f");
    INTERN(g_str_d, "d");
    INTERN(g_str_q, "q");

    INTERN(k_f_bool, "f_bool"); INTERN(k_f_int32, "f_int32");
    INTERN(k_f_int64, "f_int64"); INTERN(k_f_float64, "f_float64");
    INTERN(k_f_string, "f_string"); INTERN(k_f_bool_2, "f_bool_2");
    INTERN(k_f_int32_2, "f_int32_2"); INTERN(k_f_string_2, "f_string_2");

    INTERN(k_id, "id"); INTERN(k_status, "status"); INTERN(k_meta, "meta");
    INTERN(k_items, "items"); INTERN(k_region, "region"); INTERN(k_version, "version");
    INTERN(k_sku, "sku"); INTERN(k_qty, "qty"); INTERN(k_price_minor, "price_minor");

    INTERN(k_source, "source"); INTERN(k_ts, "ts");
    INTERN(k_tags, "tags"); INTERN(k_values, "values");

    INTERN(k_event_id, "event_id"); INTERN(k_event_type, "event_type");
    INTERN(k_occurred_at, "occurred_at"); INTERN(k_producer, "producer");
    INTERN(k_attrs, "attrs"); INTERN(k_key, "key"); INTERN(k_value, "value");

    for (int i = 0; i < 16; i++) {
        char buf[16];
        snprintf(buf, sizeof buf, "f_float_%d", i);
        INTERN(k_f_float[i], buf);
    }
    for (int i = 0; i < 4; i++) {
        char buf[16];
        snprintf(buf, sizeof buf, "f_int_%d", i);
        INTERN(k_f_int[i], buf);
    }
    INTERN(k_f_str[0], "f_str_0");
    INTERN(k_f_str[1], "f_str_1");

    INTERN(k_seq, "seq"); INTERN(k_price_mantissa, "price_mantissa");
    INTERN(k_flags, "flags"); INTERN(k_symbol, "symbol");
    INTERN(k_venue, "venue"); INTERN(k_legs, "legs");
    INTERN(k_leg_id, "leg_id"); INTERN(k_leg_qty, "leg_qty"); INTERN(k_leg_pad, "leg_pad");

    INTERN(k_rows, "rows"); INTERN(k_cols, "cols");
    INTERN(k_batch, "batch"); INTERN(k_input_ids, "input_ids");
    INTERN(k_attention_mask, "attention_mask"); INTERN(k_position_ids, "position_ids");
    INTERN(k_vocab, "vocab"); INTERN(k_hidden, "hidden"); INTERN(k_ffn, "ffn");
    INTERN(k_tok_emb, "tok_emb"); INTERN(k_attn, "attn");
    INTERN(k_ffn_weight, "ffn_weight"); INTERN(k_norm, "norm");
    INTERN(k_request_id, "request_id"); INTERN(k_model, "model");
    INTERN(k_temperature, "temperature"); INTERN(k_inputs, "inputs");

    return PyModule_Create(&g_module);
}
