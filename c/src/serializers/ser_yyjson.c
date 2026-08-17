#include "ser_common.h"
#include "v2_codec.h"
#include "yyjson.h"

/* Wrapper: only yyjson ops. Domain shape is v2_write/read_fixture. */

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

typedef struct {
    yyjson_mut_doc *doc;
    yyjson_mut_val *stack[32];
    int sp;
    char pending_key[64];
    int has_key;
} yyw;

static int add_kv(yyw *c, yyjson_mut_val *v) {
    if (!v || !c->has_key) return -1;
    /* Keys must outlive the doc; copy into the mut doc (pending_key is reused). */
    yyjson_mut_val *k = yyjson_mut_strcpy(c->doc, c->pending_key);
    if (!k) return -1;
    if (!yyjson_mut_obj_add(c->stack[c->sp - 1], k, v)) return -1;
    c->has_key = 0;
    return 0;
}
static int w_begin_map(void *ctx, int n) {
    (void)n;
    yyw *c = ctx;
    yyjson_mut_val *o = yyjson_mut_obj(c->doc);
    if (!o) return -1;
    if (c->sp == 0) {
        yyjson_mut_doc_set_root(c->doc, o);
    } else if (c->has_key) {
        if (add_kv(c, o) != 0) return -1;
    } else if (yyjson_mut_is_arr(c->stack[c->sp - 1])) {
        yyjson_mut_arr_add_val(c->stack[c->sp - 1], o);
    } else return -1;
    c->stack[c->sp++] = o;
    return 0;
}
static int w_end_map(void *ctx) {
    yyw *c = ctx;
    if (c->sp <= 0) return -1;
    c->sp--;
    return 0;
}
static int w_begin_array(void *ctx, int n) {
    (void)n;
    yyw *c = ctx;
    yyjson_mut_val *a = yyjson_mut_arr(c->doc);
    if (!a) return -1;
    if (c->has_key) {
        if (add_kv(c, a) != 0) return -1;
    } else return -1;
    c->stack[c->sp++] = a;
    return 0;
}
static int w_end_array(void *ctx) {
    yyw *c = ctx;
    if (c->sp <= 0) return -1;
    c->sp--;
    return 0;
}
static int w_key(void *ctx, const char *k) {
    yyw *c = ctx;
    snprintf(c->pending_key, sizeof c->pending_key, "%s", k);
    c->has_key = 1;
    return 0;
}
static int w_attach(yyw *c, yyjson_mut_val *v) {
    if (!v) return -1;
    if (c->has_key) return add_kv(c, v);
    if (yyjson_mut_is_arr(c->stack[c->sp - 1])) {
        yyjson_mut_arr_add_val(c->stack[c->sp - 1], v);
        return 0;
    }
    return -1;
}
static int w_bool(void *ctx, int v) { return w_attach(ctx, yyjson_mut_bool(((yyw *)ctx)->doc, v)); }
static int w_i64(void *ctx, int64_t v) { return w_attach(ctx, yyjson_mut_sint(((yyw *)ctx)->doc, v)); }
static int w_f64(void *ctx, double v) { return w_attach(ctx, yyjson_mut_real(((yyw *)ctx)->doc, v)); }
static int w_str(void *ctx, const char *s) {
    yyw *c = ctx;
    return w_attach(c, yyjson_mut_strcpy(c->doc, s ? s : ""));
}

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    yyw c = {0};
    c.doc = yyjson_mut_doc_new(NULL);
    if (!c.doc) return -1;
    v2_writer_t w = {
        .ctx = &c, .begin_map = w_begin_map, .end_map = w_end_map,
        .begin_array = w_begin_array, .end_array = w_end_array,
        .key = w_key, .put_bool = w_bool, .put_i64 = w_i64, .put_f64 = w_f64, .put_str = w_str,
    };
    if (v2_write_fixture(fx, &w) != 0) { yyjson_mut_doc_free(c.doc); return -1; }
    size_t len = 0;
    char *json = yyjson_mut_write(c.doc, 0, &len);
    yyjson_mut_doc_free(c.doc);
    if (!json || len + 1 > cap) { free(json); return -1; }
    memcpy(buf, json, len); buf[len] = 0; *ol = len;
    free(json);
    return 0;
}

typedef struct {
    yyjson_val *stack[32];
    int sp;
} yyr;

static yyjson_val *rtop(yyr *c) { return c->stack[c->sp - 1]; }
static yyjson_val *rget(yyr *c, const char *key) {
    if (key && key[0]) return yyjson_obj_get(rtop(c), key);
    return rtop(c);
}
static int r_get_bool(void *ctx, const char *key, int *out) {
    yyjson_val *j = rget(ctx, key);
    if (!j) return 1;
    *out = yyjson_get_bool(j);
    return 0;
}
static int r_get_i64(void *ctx, const char *key, int64_t *out) {
    yyjson_val *j = rget(ctx, key);
    if (!j) return 1;
    *out = yyjson_get_sint(j);
    return 0;
}
static int r_get_f64(void *ctx, const char *key, double *out) {
    yyjson_val *j = rget(ctx, key);
    if (!j) return 1;
    *out = yyjson_get_real(j);
    return 0;
}
static int r_get_str(void *ctx, const char *key, char *buf, size_t buflen) {
    yyjson_val *j = rget(ctx, key);
    if (!j) { if (buflen) buf[0] = 0; return 0; }
    const char *s = yyjson_get_str(j);
    if (!s) return -1;
    snprintf(buf, buflen, "%s", s);
    return 0;
}
static int r_enter_object(void *ctx, const char *key) {
    yyr *c = ctx;
    yyjson_val *j = yyjson_obj_get(rtop(c), key);
    if (!j || !yyjson_is_obj(j)) return 1;
    c->stack[c->sp++] = j;
    return 0;
}
static int r_leave_object(void *ctx) {
    yyr *c = ctx; if (c->sp <= 1) return -1; c->sp--; return 0;
}
static int r_enter_array(void *ctx, const char *key, int *len_out) {
    yyr *c = ctx;
    yyjson_val *j = yyjson_obj_get(rtop(c), key);
    if (!j || !yyjson_is_arr(j)) return 1;
    *len_out = (int)yyjson_arr_size(j);
    c->stack[c->sp++] = j;
    return 0;
}
static int r_leave_array(void *ctx) {
    yyr *c = ctx; if (c->sp <= 1) return -1; c->sp--; return 0;
}
static int r_enter_elem(void *ctx, int index) {
    yyr *c = ctx;
    yyjson_val *j = yyjson_arr_get(rtop(c), (size_t)index);
    if (!j) return -1;
    c->stack[c->sp++] = j;
    return 0;
}
static int r_leave_elem(void *ctx) {
    yyr *c = ctx; if (c->sp <= 1) return -1; c->sp--; return 0;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    yyjson_doc *doc = yyjson_read((const char *)buf, len, 0);
    if (!doc) return -1;
    yyr rc = {0};
    rc.stack[0] = yyjson_doc_get_root(doc);
    rc.sp = 1;
    v2_reader_t r = {
        .ctx = &rc, .get_bool = r_get_bool, .get_i64 = r_get_i64, .get_f64 = r_get_f64,
        .get_str = r_get_str, .enter_object = r_enter_object, .leave_object = r_leave_object,
        .enter_array = r_enter_array, .leave_array = r_leave_array,
        .enter_elem = r_enter_elem, .leave_elem = r_leave_elem,
    };
    int err = v2_read_fixture(kind, out, &r);
    yyjson_doc_free(doc);
    return err;
}

static int ser_fp(const test_fixture_t *fx, FILE *f, size_t *ol) {
    yyw c = {0};
    c.doc = yyjson_mut_doc_new(NULL);
    if (!c.doc) return -1;
    v2_writer_t w = {
        .ctx = &c, .begin_map = w_begin_map, .end_map = w_end_map,
        .begin_array = w_begin_array, .end_array = w_end_array,
        .key = w_key, .put_bool = w_bool, .put_i64 = w_i64, .put_f64 = w_f64, .put_str = w_str,
    };
    if (v2_write_fixture(fx, &w) != 0) { yyjson_mut_doc_free(c.doc); return -1; }
    size_t len = 0;
    if (!yyjson_mut_write_fp(f, c.doc, 0, NULL, NULL)) {
        yyjson_mut_doc_free(c.doc);
        return -1;
    }
    yyjson_mut_doc_free(c.doc);
    long pos = ftell(f);
    if (ol) *ol = pos > 0 ? (size_t)pos : 0;
    return 0;
}

static int de_fp(FILE *f, test_fixture_t *out, test_data_kind_t kind) {
    yyjson_read_err err;
    yyjson_doc *doc = yyjson_read_fp(f, 0, NULL, &err);
    if (!doc) return -1;
    yyr rc = {0};
    rc.stack[0] = yyjson_doc_get_root(doc);
    rc.sp = 1;
    v2_reader_t r = {
        .ctx = &rc, .get_bool = r_get_bool, .get_i64 = r_get_i64, .get_f64 = r_get_f64,
        .get_str = r_get_str, .enter_object = r_enter_object, .leave_object = r_leave_object,
        .enter_array = r_enter_array, .leave_array = r_leave_array,
        .enter_elem = r_enter_elem, .leave_elem = r_leave_elem,
    };
    int rc2 = v2_read_fixture(kind, out, &r);
    yyjson_doc_free(doc);
    return rc2;
}

void bench_register_yyjson(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "yyjson", "0.10.0", "json", prep, ser, de, fidelity_fx);
    o[*c - 1].serialize_fp = ser_fp;
    o[*c - 1].deserialize_fp = de_fp;
}
