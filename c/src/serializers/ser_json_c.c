#include "ser_common.h"
#include "v2_codec.h"
#include <json-c/json.h>

/* Wrapper: only json-c ops. Domain shape is v2_write/read_fixture. */

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

typedef struct {
    struct json_object *stack[32];
    int sp;
    struct json_object *root;
    char pending_key[64];
    int has_key;
} jcw;

static int w_begin_map(void *ctx, int n) {
    (void)n;
    jcw *c = ctx;
    struct json_object *o = json_object_new_object();
    if (!o) return -1;
    if (c->sp == 0) {
        c->root = o;
    } else if (c->has_key) {
        json_object_object_add(c->stack[c->sp - 1], c->pending_key, o);
        c->has_key = 0;
    } else if (json_object_is_type(c->stack[c->sp - 1], json_type_array)) {
        json_object_array_add(c->stack[c->sp - 1], o);
    } else { json_object_put(o); return -1; }
    c->stack[c->sp++] = o;
    return 0;
}
static int w_end_map(void *ctx) { jcw *c = ctx; if (c->sp <= 0) return -1; c->sp--; return 0; }
static int w_begin_array(void *ctx, int n) {
    (void)n;
    jcw *c = ctx;
    struct json_object *a = json_object_new_array();
    if (!a) return -1;
    if (c->has_key) {
        json_object_object_add(c->stack[c->sp - 1], c->pending_key, a);
        c->has_key = 0;
    } else { json_object_put(a); return -1; }
    c->stack[c->sp++] = a;
    return 0;
}
static int w_end_array(void *ctx) { jcw *c = ctx; if (c->sp <= 0) return -1; c->sp--; return 0; }
static int w_key(void *ctx, const char *k) {
    jcw *c = ctx; snprintf(c->pending_key, sizeof c->pending_key, "%s", k); c->has_key = 1; return 0;
}
static int w_attach(jcw *c, struct json_object *v) {
    if (!v) return -1;
    if (c->has_key) {
        json_object_object_add(c->stack[c->sp - 1], c->pending_key, v);
        c->has_key = 0;
    } else if (json_object_is_type(c->stack[c->sp - 1], json_type_array)) {
        json_object_array_add(c->stack[c->sp - 1], v);
    } else { json_object_put(v); return -1; }
    return 0;
}
static int w_bool(void *ctx, int v) { return w_attach(ctx, json_object_new_boolean(v)); }
static int w_i64(void *ctx, int64_t v) { return w_attach(ctx, json_object_new_int64(v)); }
static int w_f64(void *ctx, double v) { return w_attach(ctx, json_object_new_double(v)); }
static int w_str(void *ctx, const char *s) { return w_attach(ctx, json_object_new_string(s ? s : "")); }

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    jcw c = {0};
    v2_writer_t w = {
        .ctx = &c, .begin_map = w_begin_map, .end_map = w_end_map,
        .begin_array = w_begin_array, .end_array = w_end_array,
        .key = w_key, .put_bool = w_bool, .put_i64 = w_i64, .put_f64 = w_f64, .put_str = w_str,
    };
    if (v2_write_fixture(fx, &w) != 0 || !c.root) {
        if (c.root) json_object_put(c.root);
        return -1;
    }
    size_t len = 0;
    const char *s = json_object_to_json_string_length(c.root, JSON_C_TO_STRING_PLAIN, &len);
    if (!s || len + 1 > cap) { json_object_put(c.root); return -1; }
    memcpy(buf, s, len); *ol = len;
    json_object_put(c.root);
    return 0;
}

typedef struct { struct json_object *stack[32]; int sp; } jcr;
static struct json_object *rtop(jcr *c) { return c->stack[c->sp - 1]; }

static int r_get_bool(void *ctx, const char *key, int *out) {
    jcr *c = ctx; struct json_object *j = NULL;
    if (key && key[0]) {
        if (!json_object_object_get_ex(rtop(c), key, &j)) return 1;
    } else j = rtop(c);
    if (!j) return 1; *out = json_object_get_boolean(j); return 0;
}
static int r_get_i64(void *ctx, const char *key, int64_t *out) {
    jcr *c = ctx; struct json_object *j = NULL;
    if (key && key[0]) {
        if (!json_object_object_get_ex(rtop(c), key, &j)) return 1;
    } else j = rtop(c);
    if (!j) return 1; *out = json_object_get_int64(j); return 0;
}
static int r_get_f64(void *ctx, const char *key, double *out) {
    jcr *c = ctx; struct json_object *j = NULL;
    if (key && key[0]) {
        if (!json_object_object_get_ex(rtop(c), key, &j)) return 1;
    } else j = rtop(c);
    if (!j) return 1; *out = json_object_get_double(j); return 0;
}
static int r_get_str(void *ctx, const char *key, char *buf, size_t buflen) {
    jcr *c = ctx; struct json_object *j = NULL;
    if (key && key[0]) {
        if (!json_object_object_get_ex(rtop(c), key, &j)) { if (buflen) buf[0] = 0; return 0; }
    } else j = rtop(c);
    if (!j) { if (buflen) buf[0] = 0; return 0; }
    const char *s = json_object_get_string(j);
    if (!s) return -1;
    snprintf(buf, buflen, "%s", s);
    return 0;
}
static int r_enter_object(void *ctx, const char *key) {
    jcr *c = ctx; struct json_object *j = NULL;
    if (!json_object_object_get_ex(rtop(c), key, &j) || !json_object_is_type(j, json_type_object)) return 1;
    c->stack[c->sp++] = j; return 0;
}
static int r_leave_object(void *ctx) { jcr *c = ctx; if (c->sp <= 1) return -1; c->sp--; return 0; }
static int r_enter_array(void *ctx, const char *key, int *len_out) {
    jcr *c = ctx; struct json_object *j = NULL;
    if (!json_object_object_get_ex(rtop(c), key, &j) || !json_object_is_type(j, json_type_array)) return 1;
    *len_out = (int)json_object_array_length(j); c->stack[c->sp++] = j; return 0;
}
static int r_leave_array(void *ctx) { jcr *c = ctx; if (c->sp <= 1) return -1; c->sp--; return 0; }
static int r_enter_elem(void *ctx, int index) {
    jcr *c = ctx; struct json_object *j = json_object_array_get_idx(rtop(c), index);
    if (!j) return -1; c->stack[c->sp++] = j; return 0;
}
static int r_leave_elem(void *ctx) { jcr *c = ctx; if (c->sp <= 1) return -1; c->sp--; return 0; }

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    struct json_tokener *tok = json_tokener_new();
    struct json_object *root = json_tokener_parse_ex(tok, (const char *)buf, (int)len);
    json_tokener_free(tok);
    if (!root) return -1;
    jcr rc = {0}; rc.stack[0] = root; rc.sp = 1;
    v2_reader_t r = {
        .ctx = &rc, .get_bool = r_get_bool, .get_i64 = r_get_i64, .get_f64 = r_get_f64,
        .get_str = r_get_str, .enter_object = r_enter_object, .leave_object = r_leave_object,
        .enter_array = r_enter_array, .leave_array = r_leave_array,
        .enter_elem = r_enter_elem, .leave_elem = r_leave_elem,
    };
    int e = v2_read_fixture(kind, out, &r);
    json_object_put(root);
    return e;
}

void bench_register_json_c(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "json-c", "0.16", "json", prep, ser, de, fidelity_fx);
}
