#include "ser_common.h"
#include "v2_codec.h"
#include <jansson.h>

/* Wrapper: only jansson ops. Domain shape is v2_write/read_fixture. */

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

typedef struct {
    json_t *stack[32];
    int sp;
    json_t *root;
    char pending_key[64];
    int has_key;
} jw;

static int w_begin_map(void *ctx, int n) {
    (void)n;
    jw *c = ctx;
    json_t *o = json_object();
    if (!o) return -1;
    if (c->sp == 0) {
        c->root = o;
    } else if (c->has_key) {
        json_object_set_new(c->stack[c->sp - 1], c->pending_key, o);
        c->has_key = 0;
    } else if (json_is_array(c->stack[c->sp - 1])) {
        json_array_append_new(c->stack[c->sp - 1], o);
    } else { json_decref(o); return -1; }
    c->stack[c->sp++] = o;
    return 0;
}
static int w_end_map(void *ctx) {
    jw *c = ctx; if (c->sp <= 0) return -1; c->sp--; return 0;
}
static int w_begin_array(void *ctx, int n) {
    (void)n;
    jw *c = ctx;
    json_t *a = json_array();
    if (!a) return -1;
    if (c->has_key) {
        json_object_set_new(c->stack[c->sp - 1], c->pending_key, a);
        c->has_key = 0;
    } else { json_decref(a); return -1; }
    c->stack[c->sp++] = a;
    return 0;
}
static int w_end_array(void *ctx) {
    jw *c = ctx; if (c->sp <= 0) return -1; c->sp--; return 0;
}
static int w_key(void *ctx, const char *k) {
    jw *c = ctx;
    snprintf(c->pending_key, sizeof c->pending_key, "%s", k);
    c->has_key = 1;
    return 0;
}
static int w_attach(jw *c, json_t *v) {
    if (!v) return -1;
    if (c->has_key) {
        json_object_set_new(c->stack[c->sp - 1], c->pending_key, v);
        c->has_key = 0;
    } else if (json_is_array(c->stack[c->sp - 1])) {
        json_array_append_new(c->stack[c->sp - 1], v);
    } else { json_decref(v); return -1; }
    return 0;
}
static int w_bool(void *ctx, int v) { return w_attach(ctx, json_boolean(v)); }
static int w_i64(void *ctx, int64_t v) { return w_attach(ctx, json_integer(v)); }
static int w_f64(void *ctx, double v) { return w_attach(ctx, json_real(v)); }
static int w_str(void *ctx, const char *s) { return w_attach(ctx, json_string(s ? s : "")); }

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    jw c = {0};
    v2_writer_t w = {
        .ctx = &c, .begin_map = w_begin_map, .end_map = w_end_map,
        .begin_array = w_begin_array, .end_array = w_end_array,
        .key = w_key, .put_bool = w_bool, .put_i64 = w_i64, .put_f64 = w_f64, .put_str = w_str,
    };
    if (v2_write_fixture(fx, &w) != 0 || !c.root) {
        if (c.root) json_decref(c.root);
        return -1;
    }
    size_t n = json_dumpb(c.root, (char *)buf, cap, JSON_COMPACT);
    json_decref(c.root);
    if (n == 0 || n > cap) return -1;
    *ol = n;
    return 0;
}

typedef struct { json_t *stack[32]; int sp; } jr;
static json_t *rtop(jr *c) { return c->stack[c->sp - 1]; }
static json_t *rget(jr *c, const char *key) {
    if (key && key[0]) return json_object_get(rtop(c), key);
    return rtop(c);
}
static int r_get_bool(void *ctx, const char *key, int *out) {
    json_t *j = rget(ctx, key); if (!j) return 1; *out = json_is_true(j); return 0;
}
static int r_get_i64(void *ctx, const char *key, int64_t *out) {
    json_t *j = rget(ctx, key); if (!j) return 1; *out = (int64_t)json_integer_value(j); return 0;
}
static int r_get_f64(void *ctx, const char *key, double *out) {
    json_t *j = rget(ctx, key); if (!j) return 1; *out = json_number_value(j); return 0;
}
static int r_get_str(void *ctx, const char *key, char *buf, size_t buflen) {
    json_t *j = rget(ctx, key);
    if (!j) { if (buflen) buf[0] = 0; return 0; }
    const char *s = json_string_value(j);
    if (!s) return -1;
    snprintf(buf, buflen, "%s", s);
    return 0;
}
static int r_enter_object(void *ctx, const char *key) {
    jr *c = ctx; json_t *j = json_object_get(rtop(c), key);
    if (!j || !json_is_object(j)) return 1; c->stack[c->sp++] = j; return 0;
}
static int r_leave_object(void *ctx) { jr *c = ctx; if (c->sp <= 1) return -1; c->sp--; return 0; }
static int r_enter_array(void *ctx, const char *key, int *len_out) {
    jr *c = ctx; json_t *j = json_object_get(rtop(c), key);
    if (!j || !json_is_array(j)) return 1;
    *len_out = (int)json_array_size(j); c->stack[c->sp++] = j; return 0;
}
static int r_leave_array(void *ctx) { jr *c = ctx; if (c->sp <= 1) return -1; c->sp--; return 0; }
static int r_enter_elem(void *ctx, int index) {
    jr *c = ctx; json_t *j = json_array_get(rtop(c), (size_t)index);
    if (!j) return -1; c->stack[c->sp++] = j; return 0;
}
static int r_leave_elem(void *ctx) { jr *c = ctx; if (c->sp <= 1) return -1; c->sp--; return 0; }

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    json_error_t err;
    json_t *root = json_loadb((const char *)buf, len, 0, &err);
    if (!root) return -1;
    jr rc = {0}; rc.stack[0] = root; rc.sp = 1;
    v2_reader_t r = {
        .ctx = &rc, .get_bool = r_get_bool, .get_i64 = r_get_i64, .get_f64 = r_get_f64,
        .get_str = r_get_str, .enter_object = r_enter_object, .leave_object = r_leave_object,
        .enter_array = r_enter_array, .leave_array = r_leave_array,
        .enter_elem = r_enter_elem, .leave_elem = r_leave_elem,
    };
    int e = v2_read_fixture(kind, out, &r);
    json_decref(root);
    return e;
}

void bench_register_jansson(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "jansson", JANSSON_VERSION, "json", prep, ser, de, fidelity_fx);
}
