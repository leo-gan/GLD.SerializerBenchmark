#define MPACK_HAS_CONFIG 0
#include "ser_common.h"
#include "v2_codec.h"
#include "mpack/mpack.h"

/* Only mpack ops — domain shape in v2_write/read_fixture. */

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

typedef struct { mpack_writer_t *w; } mw;

static int w_begin_map(void *ctx, int n) {
    mpack_start_map(((mw *)ctx)->w, n >= 0 ? (uint32_t)n : 0);
    return mpack_writer_error(((mw *)ctx)->w) == mpack_ok ? 0 : -1;
}
static int w_end_map(void *ctx) {
    mpack_finish_map(((mw *)ctx)->w);
    return mpack_writer_error(((mw *)ctx)->w) == mpack_ok ? 0 : -1;
}
static int w_begin_array(void *ctx, int n) {
    mpack_start_array(((mw *)ctx)->w, n >= 0 ? (uint32_t)n : 0);
    return mpack_writer_error(((mw *)ctx)->w) == mpack_ok ? 0 : -1;
}
static int w_end_array(void *ctx) {
    mpack_finish_array(((mw *)ctx)->w);
    return mpack_writer_error(((mw *)ctx)->w) == mpack_ok ? 0 : -1;
}
static int w_key(void *ctx, const char *k) {
    mpack_write_cstr(((mw *)ctx)->w, k);
    return mpack_writer_error(((mw *)ctx)->w) == mpack_ok ? 0 : -1;
}
static int w_bool(void *ctx, int v) {
    mpack_write_bool(((mw *)ctx)->w, v);
    return mpack_writer_error(((mw *)ctx)->w) == mpack_ok ? 0 : -1;
}
static int w_i64(void *ctx, int64_t v) {
    mpack_write_i64(((mw *)ctx)->w, v);
    return mpack_writer_error(((mw *)ctx)->w) == mpack_ok ? 0 : -1;
}
static int w_f64(void *ctx, double v) {
    mpack_write_double(((mw *)ctx)->w, v);
    return mpack_writer_error(((mw *)ctx)->w) == mpack_ok ? 0 : -1;
}
static int w_str(void *ctx, const char *s) {
    mpack_write_cstr(((mw *)ctx)->w, s ? s : "");
    return mpack_writer_error(((mw *)ctx)->w) == mpack_ok ? 0 : -1;
}

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    mpack_writer_t writer;
    mpack_writer_init(&writer, (char *)buf, cap);
    mw ctx = { .w = &writer };
    v2_writer_t w = {
        .ctx = &ctx, .begin_map = w_begin_map, .end_map = w_end_map,
        .begin_array = w_begin_array, .end_array = w_end_array,
        .key = w_key, .put_bool = w_bool, .put_i64 = w_i64, .put_f64 = w_f64, .put_str = w_str,
    };
    if (v2_write_fixture(fx, &w) != 0) { mpack_writer_destroy(&writer); return -1; }
    size_t used = mpack_writer_buffer_used(&writer);
    if (mpack_writer_destroy(&writer) != mpack_ok) return -1;
    *ol = used;
    return 0;
}

/* Reader: stack of mpack_node_t */
typedef struct {
    mpack_node_t stack[32];
    int sp;
} mr;

static mpack_node_t rtop(mr *c) { return c->stack[c->sp - 1]; }

static int r_get_bool(void *ctx, const char *key, int *out) {
    mr *c = ctx;
    mpack_node_t n = (key && key[0]) ? mpack_node_map_cstr_optional(rtop(c), key) : rtop(c);
    if (mpack_node_is_nil(n)) return 1;
    *out = mpack_node_bool(n);
    return mpack_node_error(n) == mpack_ok ? 0 : -1;
}
static int r_get_i64(void *ctx, const char *key, int64_t *out) {
    mr *c = ctx;
    mpack_node_t n = (key && key[0]) ? mpack_node_map_cstr_optional(rtop(c), key) : rtop(c);
    if (mpack_node_is_nil(n)) return 1;
    *out = mpack_node_i64(n);
    return mpack_node_error(n) == mpack_ok ? 0 : -1;
}
static int r_get_f64(void *ctx, const char *key, double *out) {
    mr *c = ctx;
    mpack_node_t n = (key && key[0]) ? mpack_node_map_cstr_optional(rtop(c), key) : rtop(c);
    if (mpack_node_is_nil(n)) return 1;
    *out = mpack_node_double(n);
    return mpack_node_error(n) == mpack_ok ? 0 : -1;
}
static int r_get_str(void *ctx, const char *key, char *buf, size_t buflen) {
    mr *c = ctx;
    mpack_node_t n = (key && key[0]) ? mpack_node_map_cstr_optional(rtop(c), key) : rtop(c);
    if (mpack_node_is_nil(n)) { if (buflen) buf[0] = 0; return 0; }
    mpack_node_copy_cstr(n, buf, buflen);
    return mpack_node_error(n) == mpack_ok ? 0 : -1;
}
static int r_enter_object(void *ctx, const char *key) {
    mr *c = ctx;
    mpack_node_t n = mpack_node_map_cstr_optional(rtop(c), key);
    if (mpack_node_is_nil(n) || mpack_node_type(n) != mpack_type_map) return 1;
    c->stack[c->sp++] = n;
    return 0;
}
static int r_leave_object(void *ctx) {
    mr *c = ctx; if (c->sp <= 1) return -1; c->sp--; return 0;
}
static int r_enter_array(void *ctx, const char *key, int *len_out) {
    mr *c = ctx;
    mpack_node_t n = mpack_node_map_cstr_optional(rtop(c), key);
    if (mpack_node_is_nil(n) || mpack_node_type(n) != mpack_type_array) return 1;
    *len_out = (int)mpack_node_array_length(n);
    c->stack[c->sp++] = n;
    return 0;
}
static int r_leave_array(void *ctx) {
    mr *c = ctx; if (c->sp <= 1) return -1; c->sp--; return 0;
}
static int r_enter_elem(void *ctx, int index) {
    mr *c = ctx;
    mpack_node_t n = mpack_node_array_at(rtop(c), (size_t)index);
    c->stack[c->sp++] = n;
    return mpack_node_error(n) == mpack_ok ? 0 : -1;
}
static int r_leave_elem(void *ctx) {
    mr *c = ctx; if (c->sp <= 1) return -1; c->sp--; return 0;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    mpack_tree_t tree;
    mpack_tree_init_data(&tree, (const char *)buf, len);
    mpack_tree_parse(&tree);
    if (mpack_tree_error(&tree) != mpack_ok) { mpack_tree_destroy(&tree); return -1; }
    mr rc = {0};
    rc.stack[0] = mpack_tree_root(&tree);
    rc.sp = 1;
    v2_reader_t r = {
        .ctx = &rc, .get_bool = r_get_bool, .get_i64 = r_get_i64, .get_f64 = r_get_f64,
        .get_str = r_get_str, .enter_object = r_enter_object, .leave_object = r_leave_object,
        .enter_array = r_enter_array, .leave_array = r_leave_array,
        .enter_elem = r_enter_elem, .leave_elem = r_leave_elem,
    };
    int err = v2_read_fixture(kind, out, &r);
    mpack_tree_destroy(&tree);
    return err;
}

void bench_register_mpack(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "mpack", "1.1", "binary", prep, ser, de, fidelity_fx);
}
