#include "ser_common.h"
#include "v2_codec.h"
/* Disambiguate from tinycbor's cbor.h (earlier on include path). */
#include "../../third_party/libcbor/src/cbor.h"

/*
 * Wrapper: libcbor's streaming/low-level encoder (src/cbor/encoding.h).
 * No cbor_item_t allocations; bytes are written directly into the caller's
 * buffer. Interoperable CBOR output. Decode uses the shared libcbor-native
 * DOM decoder from ser_libcbor_common.c (bench_libcbor_de) — encode is the
 * streaming half of this row; decode is not yet allocation-free.
 *
 * v2_write_fixture only ever supplies definite-length container sizes, so
 * end_map / end_array are no-ops (definite-length containers auto-close
 * once N elements are written). An indefinite count (n < 0) is not
 * supported and will fail-fast rather than silently emit garbage.
 */

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

typedef struct {
    uint8_t *buf;
    size_t cap;
    size_t off;
    int err;
} lcs;

static inline int lcs_write(lcs *c, size_t n) {
    if (n == 0) { c->err = 1; return -1; }
    c->off += n;
    return 0;
}

/* v2_write_fixture only ever passes definite-length sizes, so end_* are no-ops
   (definite containers auto-close after their promised N elements). An
   indefinite (n < 0) count is not supported and would silently produce
   garbage via a wrap to (size_t)-1, so fail-fast on it. */
static int w_begin_map(void *ctx, int n) {
    lcs *c = ctx;
    if (n < 0) { c->err = 1; return -1; }
    return lcs_write(c, cbor_encode_map_start((size_t)n, c->buf + c->off, c->cap - c->off));
}
static int w_end_map(void *ctx) { (void)ctx; return 0; }
static int w_begin_array(void *ctx, int n) {
    lcs *c = ctx;
    if (n < 0) { c->err = 1; return -1; }
    return lcs_write(c, cbor_encode_array_start((size_t)n, c->buf + c->off, c->cap - c->off));
}
static int w_end_array(void *ctx) { (void)ctx; return 0; }

static int emit_text(lcs *c, const char *s) {
    if (!s) s = "";
    size_t len = strlen(s);
    size_t w = cbor_encode_string_start(len, c->buf + c->off, c->cap - c->off);
    if (w == 0) { c->err = 1; return -1; }
    c->off += w;
    if (len > c->cap - c->off) { c->err = 1; return -1; }
    memcpy(c->buf + c->off, s, len);
    c->off += len;
    return 0;
}

static int w_key(void *ctx, const char *k) { return emit_text(ctx, k); }
static int w_str(void *ctx, const char *s) { return emit_text(ctx, s); }

static int w_bool(void *ctx, int v) {
    lcs *c = ctx;
    return lcs_write(c, cbor_encode_bool(v != 0, c->buf + c->off, c->cap - c->off));
}
static int w_i64(void *ctx, int64_t v) {
    lcs *c = ctx;
    size_t w = v >= 0
        ? cbor_encode_uint((uint64_t)v, c->buf + c->off, c->cap - c->off)
        : cbor_encode_negint((uint64_t)(-1 - v), c->buf + c->off, c->cap - c->off);
    return lcs_write(c, w);
}
static int w_f64(void *ctx, double v) {
    lcs *c = ctx;
    return lcs_write(c, cbor_encode_double(v, c->buf + c->off, c->cap - c->off));
}

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    lcs c = { .buf = buf, .cap = cap, .off = 0, .err = 0 };
    v2_writer_t w = {
        .ctx = &c, .begin_map = w_begin_map, .end_map = w_end_map,
        .begin_array = w_begin_array, .end_array = w_end_array,
        .key = w_key, .put_bool = w_bool, .put_i64 = w_i64, .put_f64 = w_f64, .put_str = w_str,
    };
    if (v2_write_fixture(fx, &w) != 0 || c.err) return -1;
    *ol = c.off;
    return 0;
}

int bench_libcbor_de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind);
static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    return bench_libcbor_de(buf, len, out, kind);
}

void bench_register_libcbor_stream(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "libcbor-stream", "0.11.0", "binary", prep, ser, de, fidelity_fx);
}
