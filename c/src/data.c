#include "bench.h"
#include <string.h>
#include <stdio.h>

/* xorshift64* */
static uint64_t rng_state = 42;
static uint64_t rng_u64(void) {
    uint64_t x = rng_state;
    x ^= x << 13; x ^= x >> 7; x ^= x << 17;
    rng_state = x ? x : 1;
    return rng_state;
}
static int rng_int(int lo, int hi) {
    if (hi <= lo) return lo;
    return lo + (int)(rng_u64() % (uint64_t)(hi - lo + 1));
}
static double rng_f(void) { return (double)rng_u64() / (double)UINT64_MAX; }
static void rng_word(char *dst, size_t cap, int minl, int maxl) {
    static const char pool[] = "abcdefghijklmnopqrstuvwxyz";
    int len = rng_int(minl, maxl);
    if ((size_t)len >= cap) len = (int)cap - 1;
    for (int i = 0; i < len; i++) dst[i] = pool[rng_u64() % (sizeof(pool) - 1)];
    dst[len] = 0;
}

const char *test_data_name(test_data_kind_t k) {
    switch (k) {
        case TD_PERSON: return "Person";
        case TD_INTEGER: return "Integer";
        case TD_TELEMETRY: return "Telemetry";
        case TD_SIMPLE: return "SimpleObject";
        case TD_STRING_ARRAY: return "StringArray";
        case TD_EDI835: return "EDI_835";
        case TD_OBJECT_GRAPH: return "ObjectGraph";
        default: return "Unknown";
    }
}

static void fill_person(person_t *p) {
    memset(p, 0, sizeof(*p));
    rng_word(p->first_name, sizeof(p->first_name), 3, 10);
    rng_word(p->last_name, sizeof(p->last_name), 3, 10);
    p->age = rng_int(1, 99);
    p->gender = rng_int(0, 1);
    rng_word(p->passport_number, sizeof(p->passport_number), 8, 12);
    rng_word(p->passport_authority, sizeof(p->passport_authority), 3, 10);
    p->police_count = 5;
    for (int i = 0; i < p->police_count; i++) {
        p->police_ids[i] = i;
        rng_word(p->police_codes[i], sizeof(p->police_codes[i]), 3, 8);
    }
}

static void fill_simple(simple_object_t *s) {
    memset(s, 0, sizeof(*s));
    s->id = rng_int(0, 1000000);
    rng_word(s->name, sizeof(s->name), 3, 10);
    snprintf(s->timestamp, sizeof(s->timestamp), "2024-01-01T00:00:00Z");
    s->is_active = rng_int(0, 1);
}

static void fill_strarr(string_array_t *a) {
    memset(a, 0, sizeof(*a));
    a->count = 100;
    for (int i = 0; i < a->count; i++) rng_word(a->items[i], sizeof(a->items[i]), 3, 10);
}

static void fill_telem(telemetry_t *t) {
    memset(t, 0, sizeof(*t));
    rng_word(t->id, sizeof(t->id), 8, 12);
    rng_word(t->data_source, sizeof(t->data_source), 3, 10);
    snprintf(t->time_stamp, sizeof(t->time_stamp), "2024-01-01T00:00:00Z");
    t->param1 = rng_int(0, 1000);
    t->param2 = rng_int(0, 1000);
    t->meas_count = 100;
    for (int i = 0; i < t->meas_count; i++) t->measurements[i] = rng_f() * 100.0;
    t->problem_id = rng_int(0, 10000);
    t->log_id = rng_int(0, 10000);
    t->was_processed = rng_int(0, 1);
}

static void fill_edi(edi835_t *e) {
    memset(e, 0, sizeof(*e));
    rng_word(e->payer_name, sizeof(e->payer_name), 3, 10);
    rng_word(e->payee_name, sizeof(e->payee_name), 3, 10);
    snprintf(e->payment_date, sizeof(e->payment_date), "2024-01-01T00:00:00Z");
    e->total_actual = rng_f() * 10000.0;
    rng_word(e->tcn, sizeof(e->tcn), 8, 12);
    e->claim_count = 5;
    for (int c = 0; c < e->claim_count; c++) {
        claim_t *cl = &e->claims[c];
        snprintf(cl->claim_id, sizeof(cl->claim_id), "C%d", c);
        rng_word(cl->patient_name, sizeof(cl->patient_name), 3, 10);
        cl->total_charge = rng_f() * 5000.0;
        cl->payment = rng_f() * 5000.0;
        cl->line_count = 3;
        for (int L = 0; L < cl->line_count; L++) {
            rng_word(cl->lines[L].service_code, sizeof(cl->lines[L].service_code), 3, 6);
            cl->lines[L].charge = rng_f() * 1000.0;
            cl->lines[L].adjudicated = rng_f() * 1000.0;
        }
    }
}

/* Same topology as C# ObjectGraphDescription / Python generate_object_graph:
 * Root --children--> Child1, Child2
 * Child1.Parent = Root, Child2.Parent = Root
 * Child1.Related <-> Child2 (sibling cycle)
 */
static void fill_object_graph(object_graph_t *g) {
    memset(g, 0, sizeof(*g));
    g->node_count = 3;
    g->root = 0;

    graph_node_t *root = &g->nodes[0];
    graph_node_t *c1 = &g->nodes[1];
    graph_node_t *c2 = &g->nodes[2];

    snprintf(root->name, sizeof root->name, "Root");
    root->parent = GRAPH_NULL_IDX;
    root->related = GRAPH_NULL_IDX;
    root->child_count = 2;
    root->children[0] = 1;
    root->children[1] = 2;

    snprintf(c1->name, sizeof c1->name, "Child1");
    c1->parent = 0;
    c1->related = 2;
    c1->child_count = 0;

    snprintf(c2->name, sizeof c2->name, "Child2");
    c2->parent = 0;
    c2->related = 1;
    c2->child_count = 0;
}

void data_init_all(test_fixture_t *out, int count, uint64_t seed) {
    rng_state = seed ? seed : 42;
    for (int i = 0; i < count && i < TD_COUNT; i++) {
        memset(&out[i], 0, sizeof(out[i]));
        out[i].kind = (test_data_kind_t)i;
        out[i].name = test_data_name((test_data_kind_t)i);
        switch (i) {
            case TD_PERSON: fill_person(&out[i].person); break;
            case TD_INTEGER: out[i].integer_val = 42; break;
            case TD_TELEMETRY: fill_telem(&out[i].telemetry); break;
            case TD_SIMPLE: fill_simple(&out[i].simple); break;
            case TD_STRING_ARRAY: fill_strarr(&out[i].string_array); break;
            case TD_EDI835: fill_edi(&out[i].edi); break;
            case TD_OBJECT_GRAPH: fill_object_graph(&out[i].graph); break;
            default: break;
        }
    }
}
