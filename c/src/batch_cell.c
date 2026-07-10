#define _POSIX_C_SOURCE 200809L
#include "bench.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Framed batch: u32 n LE, then n times (u32 len LE + payload bytes).
 * Single-item cells call the serializer directly (no framing). */

static void write_u32_le(uint8_t *p, uint32_t v) {
    p[0] = (uint8_t)(v);
    p[1] = (uint8_t)(v >> 8);
    p[2] = (uint8_t)(v >> 16);
    p[3] = (uint8_t)(v >> 24);
}

static uint32_t read_u32_le(const uint8_t *p) {
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) |
           ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

int bench_serialize_cell(const serializer_t *S, const test_fixture_t *fx,
                         uint8_t *buf, size_t buf_cap, size_t *out_len) {
    if (!S || !S->serialize || !fx || !buf || !out_len) return -1;
    int n = fx->batch_n > 0 ? fx->batch_n : 1;
    if (n <= 1 || !fx->batch) {
        return S->serialize(fx, buf, buf_cap, out_len);
    }
    if (buf_cap < 4) return -1;
    write_u32_le(buf, (uint32_t)n);
    size_t o = 4;
    static uint8_t tmp[2 * 1024 * 1024];
    for (int i = 0; i < n; i++) {
        size_t item_len = 0;
        if (S->serialize(&fx->batch[i], tmp, sizeof tmp, &item_len) != 0)
            return -1;
        if (o + 4 + item_len > buf_cap) return -1;
        write_u32_le(buf + o, (uint32_t)item_len);
        o += 4;
        memcpy(buf + o, tmp, item_len);
        o += item_len;
    }
    *out_len = o;
    return 0;
}

int bench_deserialize_cell(const serializer_t *S, const uint8_t *buf, size_t len,
                           test_fixture_t *out_fx, test_data_kind_t kind) {
    if (!S || !S->deserialize || !buf || !out_fx) return -1;
    int expect_n = out_fx->batch_n > 0 ? out_fx->batch_n : 1;
    if (expect_n <= 1) {
        out_fx->batch_n = 1;
        out_fx->batch = NULL;
        return S->deserialize(buf, len, out_fx, kind);
    }
    if (len < 4) return -1;
    uint32_t n = read_u32_le(buf);
    if ((int)n != expect_n) return -1;
    size_t o = 4;
    test_fixture_t *items = (test_fixture_t *)calloc(n, sizeof(test_fixture_t));
    if (!items) return -1;
    for (uint32_t i = 0; i < n; i++) {
        if (o + 4 > len) { free(items); return -1; }
        uint32_t item_len = read_u32_le(buf + o);
        o += 4;
        if (o + item_len > len) { free(items); return -1; }
        items[i].kind = kind;
        items[i].batch_n = 1;
        items[i].batch = NULL;
        if (S->deserialize(buf + o, item_len, &items[i], kind) != 0) {
            free(items);
            return -1;
        }
        o += item_len;
    }
    memset(out_fx, 0, sizeof(*out_fx));
    out_fx->kind = kind;
    out_fx->batch_n = (int)n;
    out_fx->batch = items;
    if (n > 0) {
        out_fx->simple = items[0].simple;
        out_fx->telemetry = items[0].telemetry;
        out_fx->string_array = items[0].string_array;
        out_fx->edi = items[0].edi;
        out_fx->person = items[0].person;
        out_fx->graph = items[0].graph;
        out_fx->integer_val = items[0].integer_val;
    }
    return 0;
}

bool bench_fidelity_cell(const serializer_t *S, const test_fixture_t *a,
                         const test_fixture_t *b) {
    if (!a || !b) return false;
    int na = a->batch_n > 0 ? a->batch_n : 1;
    int nb = b->batch_n > 0 ? b->batch_n : 1;
    if (na != nb) return false;
    if (!S || !S->fidelity) return true;
    if (na <= 1)
        return S->fidelity(a, b);
    if (!a->batch || !b->batch) return false;
    for (int i = 0; i < na; i++) {
        if (!S->fidelity(&a->batch[i], &b->batch[i]))
            return false;
    }
    return true;
}

/* Adapted stream (parity with Python stream_mode=adapted): write/read encoded
 * bytes through a FILE* memory stream so "stream" is not a free alias of "bytes". */
static uint8_t g_stream_mem[8 * 1024 * 1024];
static size_t g_stream_len = 0;

int bench_stream_write_all(const uint8_t *buf, size_t len)
{
    if (!buf || len > sizeof(g_stream_mem)) return -1;
    FILE *f = fmemopen(g_stream_mem, sizeof(g_stream_mem), "w+");
    if (!f) return -1;
    size_t n = fwrite(buf, 1, len, f);
    if (fflush(f) != 0) { fclose(f); return -1; }
    fclose(f);
    if (n != len) return -1;
    g_stream_len = len;
    return 0;
}

int bench_stream_read_all(uint8_t *buf, size_t cap, size_t expect_len)
{
    if (!buf || expect_len > cap || expect_len > g_stream_len) return -1;
    FILE *f = fmemopen(g_stream_mem, g_stream_len ? g_stream_len : 1, "r");
    if (!f) return -1;
    size_t n = fread(buf, 1, expect_len, f);
    fclose(f);
    return (n == expect_len) ? 0 : -1;
}
