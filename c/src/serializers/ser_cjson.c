#include "ser_common.h"
#include "v2_codec.h"
#include "cJSON.h"
#include <stdlib.h>

/* Wrapper: only cJSON ops. Domain shape is v2_write/read_fixture. */

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

typedef struct {
    cJSON *stack[32];
    int sp;
    cJSON *root;
    char pending_key[64];
    int has_key;
} cj_full;

static int w_begin_map(void *ctx, int n) {
    (void)n;
    cj_full *c = ctx;
    cJSON *o = cJSON_CreateObject();
    if (!o) return -1;
    if (c->sp == 0) {
        c->root = o;
    } else if (c->has_key) {
        cJSON_AddItemToObject(c->stack[c->sp - 1], c->pending_key, o);
        c->has_key = 0;
    } else if (cJSON_IsArray(c->stack[c->sp - 1])) {
        cJSON_AddItemToArray(c->stack[c->sp - 1], o);
    } else { cJSON_Delete(o); return -1; }
    c->stack[c->sp++] = o;
    return 0;
}
static int w_end_map(void *ctx) {
    cj_full *c = ctx; if (c->sp <= 0) return -1; c->sp--; return 0;
}
static int w_begin_array(void *ctx, int n) {
    (void)n;
    cj_full *c = ctx;
    cJSON *a = cJSON_CreateArray();
    if (!a) return -1;
    if (c->has_key) {
        cJSON_AddItemToObject(c->stack[c->sp - 1], c->pending_key, a);
        c->has_key = 0;
    } else { cJSON_Delete(a); return -1; }
    c->stack[c->sp++] = a;
    return 0;
}
static int w_end_array(void *ctx) {
    cj_full *c = ctx; if (c->sp <= 0) return -1; c->sp--; return 0;
}
static int w_key(void *ctx, const char *k) {
    cj_full *c = ctx;
    snprintf(c->pending_key, sizeof c->pending_key, "%s", k);
    c->has_key = 1;
    return 0;
}
static int w_attach(cj_full *c, cJSON *v) {
    if (!v) return -1;
    if (c->has_key) {
        cJSON_AddItemToObject(c->stack[c->sp - 1], c->pending_key, v);
        c->has_key = 0;
    } else if (cJSON_IsArray(c->stack[c->sp - 1])) {
        cJSON_AddItemToArray(c->stack[c->sp - 1], v);
    } else { cJSON_Delete(v); return -1; }
    return 0;
}
static int w_bool(void *ctx, int v) { return w_attach(ctx, cJSON_CreateBool(v)); }
static int w_i64(void *ctx, int64_t v) { return w_attach(ctx, cJSON_CreateNumber((double)v)); }
static int w_f64(void *ctx, double v) { return w_attach(ctx, cJSON_CreateNumber(v)); }
static int w_str(void *ctx, const char *s) { return w_attach(ctx, cJSON_CreateString(s ? s : "")); }

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    cj_full c = {0};
    v2_writer_t w = {
        .ctx = &c, .begin_map = w_begin_map, .end_map = w_end_map,
        .begin_array = w_begin_array, .end_array = w_end_array,
        .key = w_key, .put_bool = w_bool, .put_i64 = w_i64, .put_f64 = w_f64, .put_str = w_str,
    };
    if (v2_write_fixture(fx, &w) != 0 || !c.root) {
        if (c.root) cJSON_Delete(c.root);
        return -1;
    }
    if (!cJSON_PrintPreallocated(c.root, (char *)buf, (int)cap, 0)) {
        cJSON_Delete(c.root);
        return -1;
    }
    *ol = strlen((char *)buf);
    cJSON_Delete(c.root);
    return 0;
}

typedef struct { cJSON *stack[32]; int sp; } cj_r;
static cJSON *rtop(cj_r *c) { return c->stack[c->sp - 1]; }

static int r_get_bool(void *ctx, const char *key, int *out) {
    cj_r *c = ctx;
    cJSON *j = (key && key[0]) ? cJSON_GetObjectItem(rtop(c), key) : rtop(c);
    if (!j) return 1; *out = cJSON_IsTrue(j); return 0;
}
static int r_get_i64(void *ctx, const char *key, int64_t *out) {
    cj_r *c = ctx;
    cJSON *j = (key && key[0]) ? cJSON_GetObjectItem(rtop(c), key) : rtop(c);
    if (!j || !cJSON_IsNumber(j)) return 1; *out = (int64_t)j->valuedouble; return 0;
}
static int r_get_f64(void *ctx, const char *key, double *out) {
    cj_r *c = ctx;
    cJSON *j = (key && key[0]) ? cJSON_GetObjectItem(rtop(c), key) : rtop(c);
    if (!j || !cJSON_IsNumber(j)) return 1; *out = j->valuedouble; return 0;
}
static int r_get_str(void *ctx, const char *key, char *buf, size_t buflen) {
    cj_r *c = ctx;
    cJSON *j = (key && key[0]) ? cJSON_GetObjectItem(rtop(c), key) : rtop(c);
    if (!j) { if (buflen) buf[0] = 0; return 0; }
    if (!cJSON_IsString(j)) return -1;
    snprintf(buf, buflen, "%s", j->valuestring ? j->valuestring : "");
    return 0;
}
static int r_enter_object(void *ctx, const char *key) {
    cj_r *c = ctx; cJSON *j = cJSON_GetObjectItem(rtop(c), key);
    if (!j || !cJSON_IsObject(j)) return 1; c->stack[c->sp++] = j; return 0;
}
static int r_leave_object(void *ctx) { cj_r *c = ctx; if (c->sp <= 1) return -1; c->sp--; return 0; }
static int r_enter_array(void *ctx, const char *key, int *len_out) {
    cj_r *c = ctx; cJSON *j = cJSON_GetObjectItem(rtop(c), key);
    if (!j || !cJSON_IsArray(j)) return 1;
    *len_out = cJSON_GetArraySize(j); c->stack[c->sp++] = j; return 0;
}
static int r_leave_array(void *ctx) { cj_r *c = ctx; if (c->sp <= 1) return -1; c->sp--; return 0; }
static int r_enter_elem(void *ctx, int index) {
    cj_r *c = ctx; cJSON *j = cJSON_GetArrayItem(rtop(c), index);
    if (!j) return -1; c->stack[c->sp++] = j; return 0;
}
static int r_leave_elem(void *ctx) { cj_r *c = ctx; if (c->sp <= 1) return -1; c->sp--; return 0; }

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    cJSON *root = cJSON_ParseWithLength((const char *)buf, len);
    if (!root) return -1;
    cj_r rc = {0}; rc.stack[0] = root; rc.sp = 1;
    v2_reader_t r = {
        .ctx = &rc, .get_bool = r_get_bool, .get_i64 = r_get_i64, .get_f64 = r_get_f64,
        .get_str = r_get_str, .enter_object = r_enter_object, .leave_object = r_leave_object,
        .enter_array = r_enter_array, .leave_array = r_leave_array,
        .enter_elem = r_enter_elem, .leave_elem = r_leave_elem,
    };
    int err = v2_read_fixture(kind, out, &r);
    cJSON_Delete(root);
    return err;
}

void bench_register_cjson(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "cJSON", "1.7.18", "json", prep, ser, de, fidelity_fx);
}
