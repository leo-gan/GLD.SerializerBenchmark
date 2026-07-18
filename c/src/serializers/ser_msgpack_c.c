#include "ser_common.h"
#include "v2_codec.h"
#include <msgpack.h>

/* Wrapper: only msgpack-c ops. Domain shape is v2_write/read_fixture. */

typedef struct { uint8_t *buf; size_t cap; size_t used; int overflow; } fixed_buf_t;
static int fixed_write(void *data, const char *buf, size_t len) {
    fixed_buf_t *fb = (fixed_buf_t *)data;
    if (fb->overflow || fb->used + len > fb->cap) { fb->overflow = 1; return -1; }
    memcpy(fb->buf + fb->used, buf, len); fb->used += len; return 0;
}
static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

typedef struct { msgpack_packer *pk; int err; } mw;
static int pstr(msgpack_packer *pk, const char *s) {
    size_t n = strlen(s ? s : "");
    return msgpack_pack_str(pk, n) || msgpack_pack_str_body(pk, s ? s : "", n);
}
static int w_begin_map(void *ctx, int n) {
    mw *c = ctx;
    if (msgpack_pack_map(c->pk, n >= 0 ? (size_t)n : 0)) c->err = 1;
    return c->err ? -1 : 0;
}
static int w_end_map(void *ctx) { (void)ctx; return 0; }
static int w_begin_array(void *ctx, int n) {
    mw *c = ctx;
    if (msgpack_pack_array(c->pk, n >= 0 ? (size_t)n : 0)) c->err = 1;
    return c->err ? -1 : 0;
}
static int w_end_array(void *ctx) { (void)ctx; return 0; }
static int w_key(void *ctx, const char *k) {
    mw *c = ctx; if (pstr(c->pk, k)) c->err = 1; return c->err ? -1 : 0;
}
static int w_bool(void *ctx, int v) {
    mw *c = ctx;
    if (v ? msgpack_pack_true(c->pk) : msgpack_pack_false(c->pk)) c->err = 1;
    return c->err ? -1 : 0;
}
static int w_i64(void *ctx, int64_t v) {
    mw *c = ctx; if (msgpack_pack_int64(c->pk, v)) c->err = 1; return c->err ? -1 : 0;
}
static int w_f64(void *ctx, double v) {
    mw *c = ctx; if (msgpack_pack_double(c->pk, v)) c->err = 1; return c->err ? -1 : 0;
}
static int w_str(void *ctx, const char *s) {
    mw *c = ctx; if (pstr(c->pk, s)) c->err = 1; return c->err ? -1 : 0;
}

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    fixed_buf_t fb = { .buf = buf, .cap = cap };
    msgpack_packer pk;
    msgpack_packer_init(&pk, &fb, fixed_write);
    mw ctx = { .pk = &pk };
    v2_writer_t w = {
        .ctx = &ctx, .begin_map = w_begin_map, .end_map = w_end_map,
        .begin_array = w_begin_array, .end_array = w_end_array,
        .key = w_key, .put_bool = w_bool, .put_i64 = w_i64, .put_f64 = w_f64, .put_str = w_str,
    };
    if (v2_write_fixture(fx, &w) != 0 || fb.overflow || ctx.err) return -1;
    *ol = fb.used;
    return 0;
}

typedef struct { const msgpack_object *stack[32]; int sp; } mr;
static const msgpack_object *rtop(mr *c) { return c->stack[c->sp - 1]; }
static const msgpack_object *map_get(const msgpack_object *m, const char *key) {
    if (!m || m->type != MSGPACK_OBJECT_MAP) return NULL;
    size_t kn = strlen(key);
    for (uint32_t i = 0; i < m->via.map.size; i++) {
        const msgpack_object *k = &m->via.map.ptr[i].key;
        if (k->type == MSGPACK_OBJECT_STR && k->via.str.size == kn && memcmp(k->via.str.ptr, key, kn) == 0)
            return &m->via.map.ptr[i].val;
    }
    return NULL;
}
static const msgpack_object *rget(mr *c, const char *key) {
    if (key && key[0]) return map_get(rtop(c), key);
    return rtop(c);
}
static int64_t as_i64(const msgpack_object *o) {
    if (!o) return 0;
    if (o->type == MSGPACK_OBJECT_POSITIVE_INTEGER) return (int64_t)o->via.u64;
    if (o->type == MSGPACK_OBJECT_NEGATIVE_INTEGER) return o->via.i64;
    if (o->type == MSGPACK_OBJECT_FLOAT64 || o->type == MSGPACK_OBJECT_FLOAT32) return (int64_t)o->via.f64;
    return 0;
}
static int r_get_bool(void *ctx, const char *key, int *out) {
    const msgpack_object *o = rget(ctx, key);
    if (!o) return 1;
    if (o->type == MSGPACK_OBJECT_BOOLEAN) { *out = o->via.boolean; return 0; }
    return 1;
}
static int r_get_i64(void *ctx, const char *key, int64_t *out) {
    const msgpack_object *o = rget(ctx, key);
    if (!o) return 1;
    *out = as_i64(o);
    return 0;
}
static int r_get_f64(void *ctx, const char *key, double *out) {
    const msgpack_object *o = rget(ctx, key);
    if (!o) return 1;
    if (o->type == MSGPACK_OBJECT_FLOAT64 || o->type == MSGPACK_OBJECT_FLOAT32) { *out = o->via.f64; return 0; }
    *out = (double)as_i64(o);
    return 0;
}
static int r_get_str(void *ctx, const char *key, char *buf, size_t buflen) {
    const msgpack_object *o = rget(ctx, key);
    if (!o) { if (buflen) buf[0] = 0; return 0; }
    if (o->type != MSGPACK_OBJECT_STR || o->via.str.size >= buflen) return -1;
    memcpy(buf, o->via.str.ptr, o->via.str.size); buf[o->via.str.size] = 0;
    return 0;
}
static int r_enter_object(void *ctx, const char *key) {
    mr *c = ctx; const msgpack_object *o = map_get(rtop(c), key);
    if (!o || o->type != MSGPACK_OBJECT_MAP) return 1;
    c->stack[c->sp++] = o; return 0;
}
static int r_leave_object(void *ctx) { mr *c = ctx; if (c->sp <= 1) return -1; c->sp--; return 0; }
static int r_enter_array(void *ctx, const char *key, int *len_out) {
    mr *c = ctx; const msgpack_object *o = map_get(rtop(c), key);
    if (!o || o->type != MSGPACK_OBJECT_ARRAY) return 1;
    *len_out = (int)o->via.array.size; c->stack[c->sp++] = o; return 0;
}
static int r_leave_array(void *ctx) { mr *c = ctx; if (c->sp <= 1) return -1; c->sp--; return 0; }
static int r_enter_elem(void *ctx, int index) {
    mr *c = ctx; const msgpack_object *a = rtop(c);
    if (a->type != MSGPACK_OBJECT_ARRAY || (uint32_t)index >= a->via.array.size) return -1;
    c->stack[c->sp++] = &a->via.array.ptr[index]; return 0;
}
static int r_leave_elem(void *ctx) { mr *c = ctx; if (c->sp <= 1) return -1; c->sp--; return 0; }

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    msgpack_unpacked result;
    msgpack_unpacked_init(&result);
    if (msgpack_unpack_next(&result, (const char *)buf, len, NULL) != MSGPACK_UNPACK_SUCCESS) {
        msgpack_unpacked_destroy(&result);
        return -1;
    }
    mr rc = {0}; rc.stack[0] = &result.data; rc.sp = 1;
    v2_reader_t r = {
        .ctx = &rc, .get_bool = r_get_bool, .get_i64 = r_get_i64, .get_f64 = r_get_f64,
        .get_str = r_get_str, .enter_object = r_enter_object, .leave_object = r_leave_object,
        .enter_array = r_enter_array, .leave_array = r_leave_array,
        .enter_elem = r_enter_elem, .leave_elem = r_leave_elem,
    };
    int e = v2_read_fixture(kind, out, &r);
    msgpack_unpacked_destroy(&result);
    return e;
}

void bench_register_msgpack_c(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "msgpack-c", "6.0.1", "binary", prep, ser, de, fidelity_fx);
}
