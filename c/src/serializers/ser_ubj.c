#include "ser_common.h"

/* Minimal UBJSON: map with kind (int32) + payload as strong-typed uint8 array. */

static int w_char(uint8_t **p, uint8_t *end, char t) {
    if (*p >= end) return -1; *(*p)++ = (uint8_t)t; return 0;
}
static int w_i32(uint8_t **p, uint8_t *end, int32_t v) {
    if (w_char(p, end, 'l')) return -1;
    if (*p + 4 > end) return -1;
    (*p)[0] = (uint8_t)((v >> 24) & 0xff);
    (*p)[1] = (uint8_t)((v >> 16) & 0xff);
    (*p)[2] = (uint8_t)((v >> 8) & 0xff);
    (*p)[3] = (uint8_t)(v & 0xff);
    *p += 4; return 0;
}
static int w_key(uint8_t **p, uint8_t *end, const char *k) {
    size_t n = strlen(k);
    if (w_i32(p, end, (int32_t)n)) return -1;
    if (*p + n > end) return -1;
    memcpy(*p, k, n); *p += n; return 0;
}
static int w_bytes(uint8_t **p, uint8_t *end, const uint8_t *raw, size_t n) {
    /* [$U#l <len> <bytes>] */
    if (w_char(p, end, '[')) return -1;
    if (w_char(p, end, '$')) return -1;
    if (w_char(p, end, 'U')) return -1;
    if (w_char(p, end, '#')) return -1;
    if (w_i32(p, end, (int32_t)n)) return -1;
    if (*p + n > end) return -1;
    memcpy(*p, raw, n); *p += n;
    return 0;
}

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    uint8_t raw[65536]; size_t n = 0;
    if (bin_write_fixture(fx, raw, sizeof raw, &n)) return -1;
    uint8_t *p = buf, *end = buf + cap;
    if (w_char(&p, end, '{')) return -1;
    if (w_key(&p, end, "kind") || w_i32(&p, end, (int32_t)fx->kind)) return -1;
    if (w_key(&p, end, "payload") || w_bytes(&p, end, raw, n)) return -1;
    if (w_char(&p, end, '}')) return -1;
    *ol = (size_t)(p - buf);
    return 0;
}

static int r_char(const uint8_t **p, const uint8_t *end, char *t) {
    if (*p >= end) return -1; *t = (char)*(*p)++; return 0;
}
static int r_i32(const uint8_t **p, const uint8_t *end, int32_t *v) {
    char t; if (r_char(p, end, &t) || t != 'l' || *p + 4 > end) return -1;
    *v = ((int32_t)(*p)[0] << 24) | ((int32_t)(*p)[1] << 16) | ((int32_t)(*p)[2] << 8) | (int32_t)(*p)[3];
    *p += 4; return 0;
}
static int r_key(const uint8_t **p, const uint8_t *end, char *dst, size_t dstsz) {
    int32_t n; if (r_i32(p, end, &n) || n < 0 || *p + (size_t)n > end) return -1;
    size_t cpy = (size_t)n < dstsz - 1 ? (size_t)n : dstsz - 1;
    memcpy(dst, *p, cpy); dst[cpy] = 0; *p += (size_t)n; return 0;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    const uint8_t *p = buf, *end = buf + len;
    char t;
    if (r_char(&p, end, &t) || t != '{') return -1;
    int k = -1; const uint8_t *payload = NULL; size_t plen = 0;
    while (p < end) {
        if (*p == '}') { p++; break; }
        char key[32];
        if (r_key(&p, end, key, sizeof key)) return -1;
        if (strcmp(key, "kind") == 0) {
            int32_t v; if (r_i32(&p, end, &v)) return -1; k = (int)v;
        } else if (strcmp(key, "payload") == 0) {
            if (r_char(&p, end, &t) || t != '[') return -1;
            if (r_char(&p, end, &t) || t != '$') return -1;
            if (r_char(&p, end, &t) || t != 'U') return -1;
            if (r_char(&p, end, &t) || t != '#') return -1;
            int32_t n; if (r_i32(&p, end, &n) || n < 0 || p + (size_t)n > end) return -1;
            payload = p; plen = (size_t)n; p += (size_t)n;
        } else {
            return -1;
        }
    }
    if (k != (int)kind || !payload) return -1;
    return bin_read_fixture(payload, plen, out, kind);
}

void bench_register_ubj(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "ubj", "1.0-min", "binary", prep, ser, de, fidelity_fx);
}
