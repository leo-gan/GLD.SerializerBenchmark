#include "ser_common.h"
#include "v2_codec.h"
#include "parson_pref.h"

/* Wrapper: only parson ops. Domain shape is v2_write/read_fixture. */

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

typedef enum { PS_OBJ, PS_ARR } ps_kind;
typedef struct {
    JSON_Value *vals[32];
    ps_kind kinds[32];
    int sp;
    JSON_Value *root;
    char pending_key[64];
    int has_key;
} pw;

static int w_begin_map(void *ctx, int n) {
    (void)n;
    pw *c = ctx;
    JSON_Value *v = json_value_init_object();
    if (!v) return -1;
    if (c->sp == 0) {
        c->root = v;
    } else if (c->has_key && c->kinds[c->sp - 1] == PS_OBJ) {
        json_object_set_value(json_value_get_object(c->vals[c->sp - 1]), c->pending_key, v);
        c->has_key = 0;
    } else if (c->kinds[c->sp - 1] == PS_ARR) {
        json_array_append_value(json_value_get_array(c->vals[c->sp - 1]), v);
    } else { json_value_free(v); return -1; }
    c->vals[c->sp] = v;
    c->kinds[c->sp] = PS_OBJ;
    c->sp++;
    return 0;
}
static int w_end_map(void *ctx) { pw *c = ctx; if (c->sp <= 0) return -1; c->sp--; return 0; }
static int w_begin_array(void *ctx, int n) {
    (void)n;
    pw *c = ctx;
    JSON_Value *v = json_value_init_array();
    if (!v) return -1;
    if (c->has_key && c->kinds[c->sp - 1] == PS_OBJ) {
        json_object_set_value(json_value_get_object(c->vals[c->sp - 1]), c->pending_key, v);
        c->has_key = 0;
    } else { json_value_free(v); return -1; }
    c->vals[c->sp] = v;
    c->kinds[c->sp] = PS_ARR;
    c->sp++;
    return 0;
}
static int w_end_array(void *ctx) { pw *c = ctx; if (c->sp <= 0) return -1; c->sp--; return 0; }
static int w_key(void *ctx, const char *k) {
    pw *c = ctx; snprintf(c->pending_key, sizeof c->pending_key, "%s", k); c->has_key = 1; return 0;
}
static int w_attach_val(pw *c, JSON_Value *v) {
    if (!v) return -1;
    if (c->has_key && c->kinds[c->sp - 1] == PS_OBJ) {
        json_object_set_value(json_value_get_object(c->vals[c->sp - 1]), c->pending_key, v);
        c->has_key = 0;
    } else if (c->kinds[c->sp - 1] == PS_ARR) {
        json_array_append_value(json_value_get_array(c->vals[c->sp - 1]), v);
    } else { json_value_free(v); return -1; }
    return 0;
}
static int w_bool(void *ctx, int v) { return w_attach_val(ctx, json_value_init_boolean(v)); }
static int w_i64(void *ctx, int64_t v) { return w_attach_val(ctx, json_value_init_number((double)v)); }
static int w_f64(void *ctx, double v) { return w_attach_val(ctx, json_value_init_number(v)); }
static int w_str(void *ctx, const char *s) { return w_attach_val(ctx, json_value_init_string(s ? s : "")); }

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    pw c = {0};
    v2_writer_t w = {
        .ctx = &c, .begin_map = w_begin_map, .end_map = w_end_map,
        .begin_array = w_begin_array, .end_array = w_end_array,
        .key = w_key, .put_bool = w_bool, .put_i64 = w_i64, .put_f64 = w_f64, .put_str = w_str,
    };
    if (v2_write_fixture(fx, &w) != 0 || !c.root) {
        if (c.root) json_value_free(c.root);
        return -1;
    }
    char *s = json_serialize_to_string(c.root);
    json_value_free(c.root);
    if (!s) return -1;
    size_t n = strlen(s);
    if (n + 1 > cap) { json_free_serialized_string(s); return -1; }
    memcpy(buf, s, n); *ol = n;
    json_free_serialized_string(s);
    return 0;
}

typedef struct {
    JSON_Value *stack[32]; /* for objects: value; for arrays after enter: array value */
    JSON_Array *arr_stack[32];
    int is_arr[32];
    int sp;
} pr;

static JSON_Object *robj(pr *c) {
    return json_value_get_object(c->stack[c->sp - 1]);
}

static int r_get_bool(void *ctx, const char *key, int *out) {
    pr *c = ctx;
    if (key && key[0]) {
        JSON_Value *v = json_object_get_value(robj(c), key);
        if (!v) return 1;
        *out = json_value_get_boolean(v);
        return 0;
    }
    *out = json_value_get_boolean(c->stack[c->sp - 1]);
    return 0;
}
static int r_get_i64(void *ctx, const char *key, int64_t *out) {
    pr *c = ctx;
    if (key && key[0]) {
        JSON_Value *v = json_object_get_value(robj(c), key);
        if (!v) return 1;
        *out = (int64_t)json_value_get_number(v);
        return 0;
    }
    *out = (int64_t)json_value_get_number(c->stack[c->sp - 1]);
    return 0;
}
static int r_get_f64(void *ctx, const char *key, double *out) {
    pr *c = ctx;
    if (key && key[0]) {
        JSON_Value *v = json_object_get_value(robj(c), key);
        if (!v) return 1;
        *out = json_value_get_number(v);
        return 0;
    }
    *out = json_value_get_number(c->stack[c->sp - 1]);
    return 0;
}
static int r_get_str(void *ctx, const char *key, char *buf, size_t buflen) {
    pr *c = ctx;
    const char *s = NULL;
    if (key && key[0]) {
        s = json_object_get_string(robj(c), key);
        if (!s) { if (buflen) buf[0] = 0; return 0; }
    } else {
        s = json_value_get_string(c->stack[c->sp - 1]);
        if (!s) return -1;
    }
    snprintf(buf, buflen, "%s", s);
    return 0;
}
static int r_enter_object(void *ctx, const char *key) {
    pr *c = ctx;
    JSON_Value *v = json_object_get_value(robj(c), key);
    if (!v || json_value_get_type(v) != JSONObject) return 1;
    c->stack[c->sp] = v; c->is_arr[c->sp] = 0; c->sp++;
    return 0;
}
static int r_leave_object(void *ctx) { pr *c = ctx; if (c->sp <= 1) return -1; c->sp--; return 0; }
static int r_enter_array(void *ctx, const char *key, int *len_out) {
    pr *c = ctx;
    JSON_Array *a = json_object_get_array(robj(c), key);
    if (!a) return 1;
    *len_out = (int)json_array_get_count(a);
    c->stack[c->sp] = json_object_get_value(robj(c), key);
    c->arr_stack[c->sp] = a;
    c->is_arr[c->sp] = 1;
    c->sp++;
    return 0;
}
static int r_leave_array(void *ctx) { pr *c = ctx; if (c->sp <= 1) return -1; c->sp--; return 0; }
static int r_enter_elem(void *ctx, int index) {
    pr *c = ctx;
    JSON_Array *a = c->arr_stack[c->sp - 1];
    JSON_Value *v = json_array_get_value(a, (size_t)index);
    if (!v) return -1;
    c->stack[c->sp] = v; c->is_arr[c->sp] = 0; c->sp++;
    return 0;
}
static int r_leave_elem(void *ctx) { pr *c = ctx; if (c->sp <= 1) return -1; c->sp--; return 0; }

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    /* parson needs NUL-terminated; copy if needed */
    char *tmp = malloc(len + 1);
    if (!tmp) return -1;
    memcpy(tmp, buf, len); tmp[len] = 0;
    JSON_Value *root = json_parse_string(tmp);
    free(tmp);
    if (!root) return -1;
    pr rc = {0}; rc.stack[0] = root; rc.sp = 1;
    v2_reader_t r = {
        .ctx = &rc, .get_bool = r_get_bool, .get_i64 = r_get_i64, .get_f64 = r_get_f64,
        .get_str = r_get_str, .enter_object = r_enter_object, .leave_object = r_leave_object,
        .enter_array = r_enter_array, .leave_array = r_leave_array,
        .enter_elem = r_enter_elem, .leave_elem = r_leave_elem,
    };
    int e = v2_read_fixture(kind, out, &r);
    json_value_free(root);
    return e;
}

void bench_register_parson(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "parson", "1.5.3", "json", prep, ser, de, fidelity_fx);
}
