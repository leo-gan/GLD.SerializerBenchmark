#include "ser_common.h"
#include "v2_codec.h"
#include "../../third_party/libcbor/src/cbor.h"

/*
 * Shared libcbor helpers used by the libcbor and libcbor-stream wrappers:
 *   - Bump-arena allocator installed via cbor_set_allocs; reset between ops.
 *     This is the documented pattern for amortizing libcbor's per-item malloc
 *     over a hot loop.
 *   - DOM-based decoder using libcbor's own map/array handles, so the libcbor
 *     benchmark rows do not depend on tinycbor.
 */

/* --- Bump arena allocator installed as libcbor's global allocator. --- */

#define LC_ARENA_SIZE (16u * 1024u * 1024u)

static uint8_t lc_arena_buf[LC_ARENA_SIZE];
static size_t lc_arena_off = 0;

static inline size_t lc_align_up(size_t n) { return (n + 15u) & ~(size_t)15u; }

/* Each allocation is prefixed with a 16-byte header carrying the payload
   size, so realloc can copy exactly the old bytes without a global registry. */
static void *lc_arena_malloc(size_t n) {
    size_t need = lc_align_up(n + 16);
    if (lc_arena_off + need > LC_ARENA_SIZE) return NULL;
    uint8_t *hdr = lc_arena_buf + lc_arena_off;
    *(size_t *)hdr = n;
    lc_arena_off += need;
    return hdr + 16;
}

static void *lc_arena_realloc(void *p, size_t n) {
    if (!p) return lc_arena_malloc(n);
    size_t old = *(size_t *)((uint8_t *)p - 16);
    void *q = lc_arena_malloc(n);
    if (!q) return NULL;
    memcpy(q, p, old < n ? old : n);
    return q;
}

static void lc_arena_free(void *p) { (void)p; /* no-op */ }

void lc_arena_reset(void) { lc_arena_off = 0; }

void lc_arena_install(void) {
    static int installed = 0;
    if (installed) return;
    installed = 1;
    cbor_set_allocs(lc_arena_malloc, lc_arena_realloc, lc_arena_free);
}

typedef struct {
    /* Stack of container items (map or array). Never owned; root owns all. */
    cbor_item_t *stack[32];
    int sp;
    /* Held during traversal; released by caller after v2_read_fixture. */
    cbor_item_t *root;
} lcr;

static cbor_item_t *rtop(lcr *c) { return c->stack[c->sp - 1]; }

static int copy_bytes(char *dst, size_t dcap, const unsigned char *src, size_t n) {
    if (n >= dcap) n = dcap - 1;
    memcpy(dst, src, n);
    dst[n] = 0;
    return 0;
}

static cbor_item_t *map_find(cbor_item_t *m, const char *key) {
    if (!cbor_isa_map(m)) return NULL;
    size_t sz = cbor_map_size(m);
    struct cbor_pair *pairs = cbor_map_handle(m);
    size_t klen = strlen(key);
    for (size_t i = 0; i < sz; i++) {
        cbor_item_t *k = pairs[i].key;
        if (!cbor_isa_string(k)) continue;
        size_t klen2 = cbor_string_length(k);
        if (klen2 != klen) continue;
        if (memcmp(cbor_string_handle(k), key, klen) == 0) return pairs[i].value;
    }
    return NULL;
}

static int as_i64(cbor_item_t *v, int64_t *out) {
    if (cbor_isa_uint(v)) {
        uint64_t u = cbor_get_int(v);
        if (u > (uint64_t)INT64_MAX) return -1;
        *out = (int64_t)u;
        return 0;
    }
    if (cbor_isa_negint(v)) {
        uint64_t u = cbor_get_int(v);
        /* CBOR negint encodes -1 - N */
        *out = (int64_t)(-1 - (int64_t)u);
        return 0;
    }
    return -1;
}

static int r_get_bool(void *ctx, const char *key, int *out) {
    lcr *c = ctx;
    cbor_item_t *v = (key && key[0]) ? map_find(rtop(c), key) : rtop(c);
    if (!v || !cbor_is_bool(v)) return 1;
    *out = cbor_get_bool(v) ? 1 : 0;
    return 0;
}
static int r_get_i64(void *ctx, const char *key, int64_t *out) {
    lcr *c = ctx;
    cbor_item_t *v = (key && key[0]) ? map_find(rtop(c), key) : rtop(c);
    if (!v || !cbor_is_int(v)) return 1;
    return as_i64(v, out);
}
static int r_get_f64(void *ctx, const char *key, double *out) {
    lcr *c = ctx;
    cbor_item_t *v = (key && key[0]) ? map_find(rtop(c), key) : rtop(c);
    if (!v) return 1;
    if (cbor_is_float(v)) { *out = cbor_float_get_float(v); return 0; }
    if (cbor_is_int(v)) { int64_t i; if (as_i64(v, &i)) return -1; *out = (double)i; return 0; }
    return 1;
}
static int r_get_str(void *ctx, const char *key, char *buf, size_t buflen) {
    lcr *c = ctx;
    cbor_item_t *v = (key && key[0]) ? map_find(rtop(c), key) : rtop(c);
    if (!v || !cbor_isa_string(v)) { if (buflen) buf[0] = 0; return 0; }
    return copy_bytes(buf, buflen, cbor_string_handle(v), cbor_string_length(v));
}
static int r_enter_object(void *ctx, const char *key) {
    lcr *c = ctx;
    cbor_item_t *v = map_find(rtop(c), key);
    if (!v || !cbor_isa_map(v)) return 1;
    if (c->sp >= 32) return -1;
    c->stack[c->sp++] = v;
    return 0;
}
static int r_leave_object(void *ctx) { lcr *c = ctx; if (c->sp <= 1) return -1; c->sp--; return 0; }
static int r_enter_array(void *ctx, const char *key, int *len_out) {
    lcr *c = ctx;
    cbor_item_t *v = map_find(rtop(c), key);
    if (!v || !cbor_isa_array(v)) return 1;
    if (c->sp >= 32) return -1;
    *len_out = (int)cbor_array_size(v);
    c->stack[c->sp++] = v;
    return 0;
}
static int r_leave_array(void *ctx) { lcr *c = ctx; if (c->sp <= 1) return -1; c->sp--; return 0; }
static int r_enter_elem(void *ctx, int index) {
    lcr *c = ctx;
    cbor_item_t *arr = rtop(c);
    if (!cbor_isa_array(arr)) return -1;
    if ((size_t)index >= cbor_array_size(arr)) return -1;
    if (c->sp >= 32) return -1;
    c->stack[c->sp++] = cbor_array_handle(arr)[index];
    return 0;
}
static int r_leave_elem(void *ctx) { lcr *c = ctx; if (c->sp <= 1) return -1; c->sp--; return 0; }

int bench_libcbor_de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    lc_arena_install();
    lc_arena_reset();
    struct cbor_load_result res = {0};
    cbor_item_t *root = cbor_load(buf, len, &res);
    if (!root || res.error.code != CBOR_ERR_NONE) {
        /* Arena: no per-item free needed; reset covers it. */
        return -1;
    }
    if (!cbor_isa_map(root)) return -1;
    lcr rc = {0};
    rc.root = root;
    rc.stack[0] = root;
    rc.sp = 1;
    v2_reader_t r = {
        .ctx = &rc, .get_bool = r_get_bool, .get_i64 = r_get_i64, .get_f64 = r_get_f64,
        .get_str = r_get_str, .enter_object = r_enter_object, .leave_object = r_leave_object,
        .enter_array = r_enter_array, .leave_array = r_leave_array,
        .enter_elem = r_enter_elem, .leave_elem = r_leave_elem,
    };
    return v2_read_fixture(kind, out, &r);
}
