#include "bench.h"
#include <string.h>
#include <stdio.h>

/* xorshift64* — matches C++ / other harness RNGs */

typedef struct { uint64_t state; } rng_t;

static void rng_init(rng_t *r, uint64_t seed) {
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

static const int64_t kBaseTsMs = 1704067200000LL;

const char *test_data_name(test_data_kind_t k) {
    switch (k) {
        case TD_MESSAGE: return "message";
        case TD_DOCUMENT: return "document";
        case TD_TELEMETRY: return "telemetry";
        case TD_STRINGS: return "strings";
        case TD_EVENT: return "event";
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
        default:
            break;
    }
}

void data_init_all(test_fixture_t *out, int count, uint64_t seed) {
    if (count > TD_COUNT) count = TD_COUNT;
    for (int i = 0; i < count; i++) {
        data_make_one(&out[i], (test_data_kind_t)i, seed, 0,
                      /*children*/8, /*points*/32, /*str_count*/32, /*attr_count*/4);
    }
}
