#include "bench.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/*
 * Deterministic xorshift64* PRNG (within-language only; not cross-lang portable).
 * Zero-seed / avalanche constant 0x9E3779B97F4A7C15 = floor(2^64/φ) (golden ratio;
 * nothing-up-my-sleeve). Suite seed comes from BENCHMARK_SEED / master config.
 */

typedef struct { uint64_t state; } rng_t;

static void rng_init(rng_t *r, uint64_t seed) {
    /* floor(2^64/φ) when seed is 0 — standard avalanche / NUMS constant */
    r->state = seed ? seed : 0x9E3779B97F4A7C15ULL;
}
static uint64_t rng_u64(rng_t *r) {
    uint64_t x = r->state;
    x ^= x << 13;
    x ^= x >> 7;
    x ^= x << 17;
    r->state = x;
    return x;
}
static int32_t rng_int(rng_t *r, int32_t lo, int32_t hi) {
    if (hi <= lo) return lo;
    return lo + (int32_t)(rng_u64(r) % (uint64_t)(hi - lo + 1));
}
static bool rng_bool(rng_t *r) { return (rng_u64(r) & 1ULL) != 0; }
static double rng_f64(rng_t *r) {
    return (double)(rng_u64(r) >> 11) / (double)(1ULL << 53);
}
static void rng_word(rng_t *r, char *dst, size_t cap, int min_l, int max_l) {
    int n = rng_int(r, min_l, max_l);
    if (n < 0) n = 0;
    if ((size_t)n >= cap) n = (int)cap - 1;
    static const char A[] = "abcdefghijklmnopqrstuvwxyz";
    for (int i = 0; i < n; i++) dst[i] = A[rng_u64(r) % 26];
    dst[n] = 0;
}

static uint64_t mix_seed(uint64_t seed, test_data_kind_t kind, int idx) {
    uint64_t h = seed;
    h ^= (uint64_t)kind * 0x9E3779B97F4A7C15ULL;
    h ^= (uint64_t)idx * 0x100000001B3ULL;
    return h ? h : 1;
}

/* Same FNV mix as the Python/Java/Swift tensor generators. Suite cells keep mix_seed. */
static uint64_t mix_name(uint64_t seed, const char *type_id, int idx) {
    uint64_t h = seed;
    const unsigned char *p;
    for (p = (const unsigned char *)type_id; *p; p++) {
        h ^= (uint64_t)(*p);
        h *= 0x100000001B3ULL;
    }
    h ^= (uint64_t)(uint32_t)idx * 0x9E3779B97F4A7C15ULL;
    return h ? h : 1;
}

static const int64_t kBaseTsMs = 1704067200000LL;

const char *test_data_name(test_data_kind_t k) {
    switch (k) {
        case TD_MESSAGE: return "message";
        case TD_DOCUMENT: return "document";
        case TD_TELEMETRY: return "telemetry";
        case TD_STRINGS: return "strings";
        case TD_EVENT: return "event";
        case TD_GRID: return "grid";
        case TD_GRID_WINDOW: return "grid_window";
        case TD_TENSOR: return "tensor";
        case TD_TENSOR_VIEW: return "tensor_view";
        case TD_PROMPT: return "prompt";
        case TD_SHARD: return "shard";
        case TD_REQUEST: return "request";
        default: return "unknown";
    }
}

void data_make_one(test_fixture_t *out, test_data_kind_t kind, uint64_t seed, int instance_index,
                   int children, int points, int str_count, int attr_count) {
    memset(out, 0, sizeof(*out));
    out->kind = kind;
    out->name = test_data_name(kind);
    out->batch_n = 1;
    out->batch = NULL;
    rng_t r;
    rng_init(&r, mix_seed(seed, kind, instance_index));

    if (children < 0) children = 0;
    if (children > V2_MAX_CHILDREN) children = V2_MAX_CHILDREN;
    if (points < 0) points = 0;
    if (points > V2_MAX_POINTS) points = V2_MAX_POINTS;
    if (str_count < 0) str_count = 0;
    if (str_count > V2_MAX_STRINGS) str_count = V2_MAX_STRINGS;
    if (attr_count < 0) attr_count = 0;
    if (attr_count > V2_MAX_ATTRS) attr_count = V2_MAX_ATTRS;

    switch (kind) {
        case TD_MESSAGE: {
            message_t *m = &out->message;
            m->f_bool = rng_bool(&r);
            m->f_int32 = rng_int(&r, 0, 1000000);
            m->f_int64 = rng_int(&r, 0, 1000000);
            m->f_float64 = rng_f64(&r) * 1000.0;
            rng_word(&r, m->f_string, sizeof m->f_string, 3, 16);
            m->f_bool_2 = rng_bool(&r);
            m->f_int32_2 = rng_int(&r, 0, 1000000);
            rng_word(&r, m->f_string_2, sizeof m->f_string_2, 3, 16);
            break;
        }
        case TD_DOCUMENT: {
            document_t *d = &out->document;
            rng_word(&r, d->id, sizeof d->id, 8, 12);
            d->status = rng_int(&r, 0, 5);
            rng_word(&r, d->meta.region, sizeof d->meta.region, 2, 4);
            d->meta.version = rng_int(&r, 1, 10);
            d->item_count = children;
            for (int i = 0; i < children; i++) {
                rng_word(&r, d->items[i].sku, sizeof d->items[i].sku, 3, 12);
                d->items[i].qty = rng_int(&r, 1, 100);
                d->items[i].price_minor = rng_int(&r, 0, 100000);
            }
            break;
        }
        case TD_TELEMETRY: {
            telemetry_t *t = &out->telemetry;
            rng_word(&r, t->source, sizeof t->source, 3, 10);
            t->ts = kBaseTsMs + rng_int(&r, 0, 86400000);
            t->tag_count = 2;
            if (t->tag_count > V2_MAX_TAGS) t->tag_count = V2_MAX_TAGS;
            for (int i = 0; i < t->tag_count; i++)
                rng_word(&r, t->tags[i], sizeof t->tags[i], 3, 10);
            t->value_count = points;
            for (int i = 0; i < points; i++) t->values[i] = rng_f64(&r) * 100.0;
            break;
        }
        case TD_STRINGS: {
            strings_t *s = &out->strings;
            s->count = str_count;
            for (int i = 0; i < str_count; i++)
                rng_word(&r, s->items[i], sizeof s->items[i], 3, 16);
            break;
        }
        case TD_EVENT: {
            event_t *e = &out->event;
            rng_word(&r, e->event_id, sizeof e->event_id, 8, 12);
            rng_word(&r, e->event_type, sizeof e->event_type, 3, 12);
            e->occurred_at = kBaseTsMs + rng_int(&r, 0, 86400000);
            rng_word(&r, e->producer, sizeof e->producer, 3, 12);
            e->attr_count = attr_count;
            for (int i = 0; i < attr_count; i++) {
                rng_word(&r, e->attrs[i].key, sizeof e->attrs[i].key, 3, 12);
                rng_word(&r, e->attrs[i].value, sizeof e->attrs[i].value, 3, 12);
            }
            break;
        }
        case TD_GRID:
            data_fill_grid(out, kind, seed, instance_index, 512, 512, 0, 0, 0, 0);
            break;
        case TD_GRID_WINDOW:
            data_fill_grid(out, kind, seed, instance_index, 512, 512, 128, 64, 256, 128);
            break;
        case TD_TENSOR:
        case TD_TENSOR_VIEW:
            /* Small shape so suite round-trip tests stay under the 4 MiB buffer. */
            data_fill_tensor(out, kind, seed, instance_index, 2, 2, 4, 256, 32000, 256, 512, 3, 16);
            break;
        case TD_PROMPT:
            data_fill_tensor(out, kind, seed, instance_index, 1024, 1024, 2, 4, 32, 256, 512, 3, 16);
            break;
        case TD_SHARD:
            data_fill_tensor(out, kind, seed, instance_index, 1024, 1024, 4, 256, 4, 3, 5, 3, 16);
            break;
        case TD_REQUEST:
            data_fill_tensor(out, kind, seed, instance_index, 1024, 1024, 2, 4, 32, 256, 512, 3, 16);
            break;
        default:
            break;
    }
}

static void free_prompt(prompt_t *p) {
    if (!p) return;
    free(p->input_ids);
    free(p->attention_mask);
    free(p->position_ids);
    p->input_ids = NULL;
    p->attention_mask = NULL;
    p->position_ids = NULL;
    p->n = 0;
}

static void free_shard(shard_t *s) {
    if (!s) return;
    free(s->tok_emb);
    free(s->attn);
    free(s->ffn_weight);
    free(s->norm);
    s->tok_emb = NULL;
    s->attn = NULL;
    s->ffn_weight = NULL;
    s->norm = NULL;
}

void data_free_grid(test_fixture_t *fx) {
    if (!fx) return;
    free(fx->grid.values);
    fx->grid.values = NULL;
    fx->grid.nvalues = 0;
    if (fx->tensor.values_owned) free(fx->tensor.values);
    fx->tensor.values = NULL;
    fx->tensor.values_owned = 0;
    fx->tensor.nvalues = 0;
    free_prompt(&fx->prompt);
    free_shard(&fx->shard);
    free_prompt(&fx->request.inputs);
}

static void *alloc_bytes(size_t n) {
    void *p;
    if (n == 0) return NULL;
    p = malloc(n);
    if (!p) {
        fprintf(stderr, "[ERROR] fixture OOM %zu bytes\n", n);
        exit(1);
    }
    return p;
}

static int shape_n(int a, int b, int *out) {
    long long n;
    if (a < 1 || b < 1) return -1;
    n = (long long)a * (long long)b;
    if (n > 0x7fffffffLL) return -1;
    *out = (int)n;
    return 0;
}

static void f32_set_bits(float *p, uint32_t bits) {
    memcpy(p, &bits, 4);
}

/* Draw every element, then pin index 0 and 1 when requested. */
static void fill_f32(rng_t *r, float *dst, int n, int pin) {
    int i;
    for (i = 0; i < n; i++) dst[i] = (float)rng_f64(r);
    if (pin && n >= 2) {
        f32_set_bits(&dst[0], 0x80000000u);
        f32_set_bits(&dst[1], 0x7fc00000u);
    }
}

static float *make_f32(rng_t *r, int n, int pin) {
    float *dst = (float *)alloc_bytes((size_t)n * sizeof(float));
    fill_f32(r, dst, n, pin);
    return dst;
}

static void fill_prompt(rng_t *r, prompt_t *p, int batch, int seq, int vocab) {
    int n = 0;
    int row;
    int64_t *ids;
    int64_t *mask;
    int64_t *pos;
    if (shape_n(batch, seq, &n) || vocab < 2) return;
    ids = (int64_t *)alloc_bytes((size_t)n * sizeof(int64_t));
    mask = (int64_t *)alloc_bytes((size_t)n * sizeof(int64_t));
    pos = (int64_t *)alloc_bytes((size_t)n * sizeof(int64_t));
    for (row = 0; row < batch; row++) {
        int lo = seq / 2;
        int content;
        int col;
        if (lo < 1) lo = 1;
        content = rng_int(r, lo, seq);
        for (col = 0; col < seq; col++) {
            int i = row * seq + col;
            if (col < content) {
                ids[i] = rng_int(r, 1, vocab - 1);
                mask[i] = 1;
            } else {
                ids[i] = 0;
                mask[i] = 0;
            }
            pos[i] = col;
        }
    }
    p->batch = batch;
    p->seq = seq;
    p->n = n;
    p->input_ids = ids;
    p->attention_mask = mask;
    p->position_ids = pos;
}

void data_fill_tensor(test_fixture_t *out, test_data_kind_t kind, uint64_t seed, int instance_index,
                      int rows, int cols, int batch, int seq, int vocab,
                      int hidden, int ffn, int string_min, int string_max) {
    rng_t r;
    test_data_kind_t seed_kind = kind;
    data_free_grid(out);
    memset(out, 0, sizeof(*out));
    out->kind = kind;
    out->name = test_data_name(kind);
    out->batch_n = 1;
    /* tensor_view mixes the name "tensor", not "tensor_view". */
    if (kind == TD_TENSOR_VIEW) seed_kind = TD_TENSOR;
    if (rows <= 0) rows = 1024;
    if (cols <= 0) cols = 1024;
    if (batch <= 0) batch = 4;
    if (seq <= 0) seq = 256;
    if (vocab <= 1) vocab = 32000;
    if (hidden <= 0) hidden = 256;
    if (ffn <= 0) ffn = 512;
    if (string_min <= 0) string_min = 3;
    if (string_max < string_min) string_max = string_min;
    rng_init(&r, mix_name(seed, test_data_name(seed_kind), instance_index));
    if (kind == TD_TENSOR || kind == TD_TENSOR_VIEW) {
        int n = 0;
        if (shape_n(rows, cols, &n) || n < 2) return;
        out->tensor.rows = rows;
        out->tensor.cols = cols;
        out->tensor.nvalues = n;
        out->tensor.values = make_f32(&r, n, 1);
        out->tensor.values_owned = 1;
        return;
    }
    if (kind == TD_PROMPT) {
        fill_prompt(&r, &out->prompt, batch, seq, vocab);
        return;
    }
    if (kind == TD_SHARD) {
        int n_tok = 0, n_attn = 0, n_ffn = 0;
        if (shape_n(vocab, hidden, &n_tok) || shape_n(hidden, hidden, &n_attn) ||
            shape_n(ffn, hidden, &n_ffn))
            return;
        out->shard.vocab = vocab;
        out->shard.hidden = hidden;
        out->shard.ffn = ffn;
        out->shard.n_tok = n_tok;
        out->shard.n_attn = n_attn;
        out->shard.n_ffn = n_ffn;
        out->shard.n_norm = hidden;
        out->shard.tok_emb = make_f32(&r, n_tok, 0);
        out->shard.attn = make_f32(&r, n_attn, 0);
        out->shard.ffn_weight = make_f32(&r, n_ffn, 0);
        out->shard.norm = make_f32(&r, hidden, 0);
        return;
    }
    if (kind == TD_REQUEST) {
        out->request.request_id = rng_int(&r, 1, 1000000000);
        rng_word(&r, out->request.model, sizeof out->request.model, string_min, string_max);
        out->request.temperature = (float)(rng_f64(&r) * 2.0);
        fill_prompt(&r, &out->request.inputs, batch, seq, vocab);
    }
}

void data_fill_grid(test_fixture_t *out, test_data_kind_t kind, uint64_t seed, int instance_index,
                    int nx, int ny, int x0, int y0, int wx, int wy) {
    data_free_grid(out);
    memset(out, 0, sizeof(*out));
    out->kind = kind;
    out->name = test_data_name(kind);
    out->batch_n = 1;
    if (nx <= 0) nx = 512;
    if (ny <= 0) ny = 512;
    if (kind != TD_GRID_WINDOW) {
        x0 = y0 = wx = wy = 0;
    } else if (wx <= 0 || wy <= 0) {
        x0 = 128;
        y0 = 64;
        wx = 256;
        wy = 128;
    }
    size_t n = (size_t)nx * (size_t)ny;
    double *values = (double *)malloc(n * sizeof(double));
    if (!values) return;
    rng_t r;
    rng_init(&r, mix_seed(seed, kind, instance_index));
    for (size_t i = 0; i < n; i++) values[i] = rng_f64(&r);
    out->grid.nx = nx;
    out->grid.ny = ny;
    out->grid.x0 = x0;
    out->grid.y0 = y0;
    out->grid.wx = wx;
    out->grid.wy = wy;
    out->grid.nvalues = (int)n;
    out->grid.values = values;
}

void data_init_all(test_fixture_t *out, int count, uint64_t seed) {
    if (count > TD_COUNT) count = TD_COUNT;
    for (int i = 0; i < count; i++) {
        data_make_one(&out[i], (test_data_kind_t)i, seed, 0,
                      /*children*/8, /*points*/32, /*str_count*/32, /*attr_count*/4);
    }
}
