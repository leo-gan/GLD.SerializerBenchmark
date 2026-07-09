#ifndef FIXTURE_PB_FULL_H
#define FIXTURE_PB_FULL_H
/*
 * Full-fixture protobuf-style wire (field tags shared by nanopb / protobuf-c / upb entries).
 * Encodes complete C structs: police arrays, measurements[], EDI claims/lines, etc.
 */
#include "ser_common.h"
#include <string.h>

static inline size_t pb_wr_varint(uint8_t *buf, uint64_t v) {
    size_t n = 0;
    while (v >= 0x80) { buf[n++] = (uint8_t)((v & 0x7f) | 0x80); v >>= 7; }
    buf[n++] = (uint8_t)v;
    return n;
}
static inline size_t pb_wr_tag(uint8_t *buf, uint32_t field, uint32_t wt) {
    return pb_wr_varint(buf, ((uint64_t)field << 3) | wt);
}
static inline int pb_append_varint(uint8_t *buf, size_t cap, size_t *o, uint32_t field, uint64_t v) {
    uint8_t tmp[20]; size_t n = pb_wr_tag(tmp, field, 0); n += pb_wr_varint(tmp + n, v);
    if (*o + n > cap) return -1; memcpy(buf + *o, tmp, n); *o += n; return 0;
}
static inline int pb_append_bytes(uint8_t *buf, size_t cap, size_t *o, uint32_t field, const void *p, size_t len) {
    uint8_t tmp[20]; size_t n = pb_wr_tag(tmp, field, 2); n += pb_wr_varint(tmp + n, len);
    if (*o + n + len > cap) return -1; memcpy(buf + *o, tmp, n); *o += n; memcpy(buf + *o, p, len); *o += len; return 0;
}
static inline int pb_append_str(uint8_t *buf, size_t cap, size_t *o, uint32_t field, const char *s) {
    return pb_append_bytes(buf, cap, o, field, s, strlen(s));
}
static inline int pb_append_f64(uint8_t *buf, size_t cap, size_t *o, uint32_t field, double v) {
    uint8_t tmp[12]; size_t n = pb_wr_tag(tmp, field, 1);
    if (*o + n + 8 > cap) return -1; memcpy(buf + *o, tmp, n); *o += n;
    memcpy(buf + *o, &v, 8); *o += 8; return 0;
}

/* Field map (kind-discriminated; all under one message envelope with field 1 = kind) */
/* 1 kind
 * INTEGER: 2 value
 * SIMPLE: 10 id, 11 name, 12 ts, 13 active
 * PERSON: 20 fn, 21 ln, 22 age, 23 gender, 25 pass_num, 26 pass_auth,
 *         27 police_id (repeated), 28 police_code (repeated, parallel)
 * TELEMETRY: 30 id, 33 data_source, 34 time_stamp, 31 param1, 35 param2,
 *            36 measurements packed as length-delimited doubles, 37 problem, 38 log, 39 was_proc
 * STRING_ARRAY: 40 count, 41 item string repeated
 * EDI: 50 payer, 51 payee, 54 payment_date, 52 claim_count, 53 total,
 *      55 tcn, 60 claim blob repeated (sub-encoded)
 */

static inline int pb_full_encode(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *out_len) {
    size_t o = 0;
    if (pb_append_varint(buf, cap, &o, 1, (uint64_t)(uint32_t)fx->kind)) return -1;
    switch (fx->kind) {
        case TD_INTEGER:
            if (pb_append_varint(buf, cap, &o, 2, (uint64_t)(uint32_t)fx->integer_val)) return -1;
            break;
        case TD_SIMPLE:
            if (pb_append_varint(buf, cap, &o, 10, (uint64_t)(uint32_t)fx->simple.id)) return -1;
            if (pb_append_str(buf, cap, &o, 11, fx->simple.name)) return -1;
            if (pb_append_str(buf, cap, &o, 12, fx->simple.timestamp)) return -1;
            if (pb_append_varint(buf, cap, &o, 13, fx->simple.is_active ? 1 : 0)) return -1;
            break;
        case TD_PERSON: {
            const person_t *p = &fx->person;
            if (pb_append_str(buf, cap, &o, 20, p->first_name)) return -1;
            if (pb_append_str(buf, cap, &o, 21, p->last_name)) return -1;
            if (pb_append_varint(buf, cap, &o, 22, (uint64_t)(uint32_t)p->age)) return -1;
            if (pb_append_varint(buf, cap, &o, 23, (uint64_t)(uint32_t)p->gender)) return -1;
            if (pb_append_str(buf, cap, &o, 25, p->passport_number)) return -1;
            if (pb_append_str(buf, cap, &o, 26, p->passport_authority)) return -1;
            int n = p->police_count; if (n < 0) n = 0; if (n > 8) n = 8;
            for (int i = 0; i < n; i++) {
                if (pb_append_varint(buf, cap, &o, 27, (uint64_t)(uint32_t)p->police_ids[i])) return -1;
                if (pb_append_str(buf, cap, &o, 28, p->police_codes[i])) return -1;
            }
            break;
        }
        case TD_TELEMETRY: {
            const telemetry_t *t = &fx->telemetry;
            if (pb_append_str(buf, cap, &o, 30, t->id)) return -1;
            if (pb_append_str(buf, cap, &o, 33, t->data_source)) return -1;
            if (pb_append_str(buf, cap, &o, 34, t->time_stamp)) return -1;
            if (pb_append_varint(buf, cap, &o, 31, (uint64_t)(uint32_t)t->param1)) return -1;
            if (pb_append_varint(buf, cap, &o, 35, (uint64_t)(uint32_t)t->param2)) return -1;
            int n = t->meas_count; if (n < 0) n = 0; if (n > 100) n = 100;
            if (pb_append_bytes(buf, cap, &o, 36, t->measurements, (size_t)n * 8)) return -1;
            if (pb_append_varint(buf, cap, &o, 37, (uint64_t)(uint32_t)t->problem_id)) return -1;
            if (pb_append_varint(buf, cap, &o, 38, (uint64_t)(uint32_t)t->log_id)) return -1;
            if (pb_append_varint(buf, cap, &o, 39, t->was_processed ? 1 : 0)) return -1;
            break;
        }
        case TD_STRING_ARRAY: {
            const string_array_t *a = &fx->string_array;
            int n = a->count; if (n < 0) n = 0; if (n > 100) n = 100;
            if (pb_append_varint(buf, cap, &o, 40, (uint64_t)(uint32_t)n)) return -1;
            for (int i = 0; i < n; i++)
                if (pb_append_str(buf, cap, &o, 41, a->items[i])) return -1;
            break;
        }
        case TD_EDI835: {
            const edi835_t *e = &fx->edi;
            if (pb_append_str(buf, cap, &o, 50, e->payer_name)) return -1;
            if (pb_append_str(buf, cap, &o, 51, e->payee_name)) return -1;
            if (pb_append_str(buf, cap, &o, 54, e->payment_date)) return -1;
            if (pb_append_f64(buf, cap, &o, 53, e->total_actual)) return -1;
            if (pb_append_str(buf, cap, &o, 55, e->tcn)) return -1;
            int nc = e->claim_count; if (nc < 0) nc = 0; if (nc > 6) nc = 6;
            if (pb_append_varint(buf, cap, &o, 52, (uint64_t)(uint32_t)nc)) return -1;
            for (int c = 0; c < nc; c++) {
                const claim_t *cl = &e->claims[c];
                /* submessage field 60: length-delimited claim */
                uint8_t sub[512]; size_t so = 0;
                if (pb_append_str(sub, sizeof sub, &so, 1, cl->claim_id)) return -1;
                if (pb_append_str(sub, sizeof sub, &so, 2, cl->patient_name)) return -1;
                if (pb_append_f64(sub, sizeof sub, &so, 3, cl->total_charge)) return -1;
                if (pb_append_f64(sub, sizeof sub, &so, 4, cl->payment)) return -1;
                int nl = cl->line_count; if (nl < 0) nl = 0; if (nl > 4) nl = 4;
                if (pb_append_varint(sub, sizeof sub, &so, 5, (uint64_t)(uint32_t)nl)) return -1;
                for (int L = 0; L < nl; L++) {
                    uint8_t line[128]; size_t lo = 0;
                    if (pb_append_str(line, sizeof line, &lo, 1, cl->lines[L].service_code)) return -1;
                    if (pb_append_f64(line, sizeof line, &lo, 2, cl->lines[L].charge)) return -1;
                    if (pb_append_f64(line, sizeof line, &lo, 3, cl->lines[L].adjudicated)) return -1;
                    if (pb_append_bytes(sub, sizeof sub, &so, 6, line, lo)) return -1;
                }
                if (pb_append_bytes(buf, cap, &o, 60, sub, so)) return -1;
            }
            break;
        }

        case TD_OBJECT_GRAPH: {
            const object_graph_t *g = &fx->graph;
            if (pb_append_varint(buf, cap, &o, 70, (uint64_t)(uint32_t)(int32_t)g->root)) return -1;
            int nn = g->node_count; if (nn < 0) nn = 0; if (nn > GRAPH_MAX_NODES) nn = GRAPH_MAX_NODES;
            if (pb_append_varint(buf, cap, &o, 71, (uint64_t)(uint32_t)nn)) return -1;
            for (int i = 0; i < nn; i++) {
                const graph_node_t *n = &g->nodes[i];
                uint8_t sub[256]; size_t so = 0;
                if (pb_append_str(sub, sizeof sub, &so, 1, n->name)) return -1;
                /* parent/related as signed zig? use int32 varint as uint cast */
                if (pb_append_varint(sub, sizeof sub, &so, 2, (uint64_t)(uint32_t)(int32_t)n->parent)) return -1;
                if (pb_append_varint(sub, sizeof sub, &so, 3, (uint64_t)(uint32_t)(int32_t)n->related)) return -1;
                int nc = n->child_count; if (nc < 0) nc = 0; if (nc > GRAPH_MAX_CHILDREN) nc = GRAPH_MAX_CHILDREN;
                for (int c = 0; c < nc; c++)
                    if (pb_append_varint(sub, sizeof sub, &so, 4, (uint64_t)(uint32_t)(int32_t)n->children[c])) return -1;
                if (pb_append_bytes(buf, cap, &o, 72, sub, so)) return -1;
            }
            break;
        }
        default: return -1;
    }
    *out_len = o;
    return 0;
}

static inline int pb_rd_varint(const uint8_t **p, const uint8_t *end, uint64_t *v) {
    uint64_t r = 0; int s = 0;
    while (*p < end) {
        uint8_t b = *(*p)++;
        r |= (uint64_t)(b & 0x7f) << s;
        if (!(b & 0x80)) { *v = r; return 0; }
        s += 7; if (s > 63) return -1;
    }
    return -1;
}
static inline int pb_rd_bytes(const uint8_t **p, const uint8_t *end, const uint8_t **out, size_t *len) {
    uint64_t n; if (pb_rd_varint(p, end, &n) || *p + n > end) return -1;
    *out = *p; *len = (size_t)n; *p += n; return 0;
}
static inline int pb_rd_str(const uint8_t **p, const uint8_t *end, char *dst, size_t dstsz) {
    const uint8_t *b; size_t n;
    if (pb_rd_bytes(p, end, &b, &n)) return -1;
    size_t c = n < dstsz - 1 ? n : dstsz - 1;
    memcpy(dst, b, c); dst[c] = 0; return 0;
}

static inline int pb_full_decode(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    const uint8_t *p = buf, *end = buf + len;
    memset(out, 0, sizeof *out);
    out->kind = kind;
    out->name = test_data_name(kind);
    int got_kind = -1;
    int police_n = 0, items_n = 0, claims_n = 0;
    while (p < end) {
        uint64_t tag; if (pb_rd_varint(&p, end, &tag)) return -1;
        uint32_t field = (uint32_t)(tag >> 3), wt = (uint32_t)(tag & 7);
        if (field == 1 && wt == 0) {
            uint64_t v; if (pb_rd_varint(&p, end, &v)) return -1; got_kind = (int)v;
        } else if (field == 2 && wt == 0) {
            uint64_t v; if (pb_rd_varint(&p, end, &v)) return -1; out->integer_val = (int)v;
        } else if (field == 10 && wt == 0) {
            uint64_t v; if (pb_rd_varint(&p, end, &v)) return -1; out->simple.id = (int)v;
        } else if (field == 11 && wt == 2) {
            if (pb_rd_str(&p, end, out->simple.name, sizeof out->simple.name)) return -1;
        } else if (field == 12 && wt == 2) {
            if (pb_rd_str(&p, end, out->simple.timestamp, sizeof out->simple.timestamp)) return -1;
        } else if (field == 13 && wt == 0) {
            uint64_t v; if (pb_rd_varint(&p, end, &v)) return -1; out->simple.is_active = v != 0;
        } else if (field == 20 && wt == 2) {
            if (pb_rd_str(&p, end, out->person.first_name, sizeof out->person.first_name)) return -1;
        } else if (field == 21 && wt == 2) {
            if (pb_rd_str(&p, end, out->person.last_name, sizeof out->person.last_name)) return -1;
        } else if (field == 22 && wt == 0) {
            uint64_t v; if (pb_rd_varint(&p, end, &v)) return -1; out->person.age = (int)v;
        } else if (field == 23 && wt == 0) {
            uint64_t v; if (pb_rd_varint(&p, end, &v)) return -1; out->person.gender = (int)v;
        } else if (field == 25 && wt == 2) {
            if (pb_rd_str(&p, end, out->person.passport_number, sizeof out->person.passport_number)) return -1;
        } else if (field == 26 && wt == 2) {
            if (pb_rd_str(&p, end, out->person.passport_authority, sizeof out->person.passport_authority)) return -1;
        } else if (field == 27 && wt == 0) {
            uint64_t v; if (pb_rd_varint(&p, end, &v)) return -1;
            if (police_n < 8) out->person.police_ids[police_n] = (int)v;
            /* codes filled by interleaved 28 or we pair by index */
            if (police_n < 8) police_n++;
            out->person.police_count = police_n;
        } else if (field == 28 && wt == 2) {
            /* attach code to last police id slot - if parallel, use police_n-1 */
            int idx = police_n > 0 ? police_n - 1 : 0;
            if (idx < 8 && pb_rd_str(&p, end, out->person.police_codes[idx], sizeof out->person.police_codes[idx])) return -1;
        } else if (field == 30 && wt == 2) {
            if (pb_rd_str(&p, end, out->telemetry.id, sizeof out->telemetry.id)) return -1;
        } else if (field == 33 && wt == 2) {
            if (pb_rd_str(&p, end, out->telemetry.data_source, sizeof out->telemetry.data_source)) return -1;
        } else if (field == 34 && wt == 2) {
            if (pb_rd_str(&p, end, out->telemetry.time_stamp, sizeof out->telemetry.time_stamp)) return -1;
        } else if (field == 31 && wt == 0) {
            uint64_t v; if (pb_rd_varint(&p, end, &v)) return -1; out->telemetry.param1 = (int)v;
        } else if (field == 35 && wt == 0) {
            uint64_t v; if (pb_rd_varint(&p, end, &v)) return -1; out->telemetry.param2 = (int)v;
        } else if (field == 36 && wt == 2) {
            const uint8_t *b; size_t n;
            if (pb_rd_bytes(&p, end, &b, &n)) return -1;
            int cnt = (int)(n / 8); if (cnt > 100) cnt = 100;
            out->telemetry.meas_count = cnt;
            memcpy(out->telemetry.measurements, b, (size_t)cnt * 8);
        } else if (field == 37 && wt == 0) {
            uint64_t v; if (pb_rd_varint(&p, end, &v)) return -1; out->telemetry.problem_id = (int)v;
        } else if (field == 38 && wt == 0) {
            uint64_t v; if (pb_rd_varint(&p, end, &v)) return -1; out->telemetry.log_id = (int)v;
        } else if (field == 39 && wt == 0) {
            uint64_t v; if (pb_rd_varint(&p, end, &v)) return -1; out->telemetry.was_processed = v != 0;
        } else if (field == 40 && wt == 0) {
            uint64_t v; if (pb_rd_varint(&p, end, &v)) return -1; out->string_array.count = (int)v;
        } else if (field == 41 && wt == 2) {
            if (items_n < 100) {
                if (pb_rd_str(&p, end, out->string_array.items[items_n], sizeof out->string_array.items[items_n])) return -1;
                items_n++;
                if (out->string_array.count < items_n) out->string_array.count = items_n;
            } else {
                const uint8_t *b; size_t n; if (pb_rd_bytes(&p, end, &b, &n)) return -1;
            }
        } else if (field == 50 && wt == 2) {
            if (pb_rd_str(&p, end, out->edi.payer_name, sizeof out->edi.payer_name)) return -1;
        } else if (field == 51 && wt == 2) {
            if (pb_rd_str(&p, end, out->edi.payee_name, sizeof out->edi.payee_name)) return -1;
        } else if (field == 54 && wt == 2) {
            if (pb_rd_str(&p, end, out->edi.payment_date, sizeof out->edi.payment_date)) return -1;
        } else if (field == 55 && wt == 2) {
            if (pb_rd_str(&p, end, out->edi.tcn, sizeof out->edi.tcn)) return -1;
        } else if (field == 52 && wt == 0) {
            uint64_t v; if (pb_rd_varint(&p, end, &v)) return -1; out->edi.claim_count = (int)v;
        } else if (field == 53 && wt == 1) {
            if (p + 8 > end) return -1; memcpy(&out->edi.total_actual, p, 8); p += 8;
        } else if (field == 60 && wt == 2) {
            const uint8_t *sub; size_t slen;
            if (pb_rd_bytes(&p, end, &sub, &slen)) return -1;
            if (claims_n >= 6) continue;
            claim_t *cl = &out->edi.claims[claims_n++];
            const uint8_t *sp = sub, *send = sub + slen;
            int lines_n = 0;
            while (sp < send) {
                uint64_t t2; if (pb_rd_varint(&sp, send, &t2)) return -1;
                uint32_t f2 = (uint32_t)(t2 >> 3), w2 = (uint32_t)(t2 & 7);
                if (f2 == 1 && w2 == 2) { if (pb_rd_str(&sp, send, cl->claim_id, sizeof cl->claim_id)) return -1; }
                else if (f2 == 2 && w2 == 2) { if (pb_rd_str(&sp, send, cl->patient_name, sizeof cl->patient_name)) return -1; }
                else if (f2 == 3 && w2 == 1) { if (sp+8>send) return -1; memcpy(&cl->total_charge, sp, 8); sp+=8; }
                else if (f2 == 4 && w2 == 1) { if (sp+8>send) return -1; memcpy(&cl->payment, sp, 8); sp+=8; }
                else if (f2 == 5 && w2 == 0) { uint64_t v; if (pb_rd_varint(&sp, send, &v)) return -1; cl->line_count = (int)v; }
                else if (f2 == 6 && w2 == 2) {
                    const uint8_t *lb; size_t ln;
                    if (pb_rd_bytes(&sp, send, &lb, &ln)) return -1;
                    if (lines_n < 4) {
                        service_line_t *L = &cl->lines[lines_n++];
                        const uint8_t *lp = lb, *lend = lb + ln;
                        while (lp < lend) {
                            uint64_t t3; if (pb_rd_varint(&lp, lend, &t3)) return -1;
                            uint32_t f3 = (uint32_t)(t3 >> 3), w3 = (uint32_t)(t3 & 7);
                            if (f3 == 1 && w3 == 2) { if (pb_rd_str(&lp, lend, L->service_code, sizeof L->service_code)) return -1; }
                            else if (f3 == 2 && w3 == 1) { if (lp+8>lend) return -1; memcpy(&L->charge, lp, 8); lp+=8; }
                            else if (f3 == 3 && w3 == 1) { if (lp+8>lend) return -1; memcpy(&L->adjudicated, lp, 8); lp+=8; }
                            else if (w3 == 0) { uint64_t v; if (pb_rd_varint(&lp, lend, &v)) return -1; }
                            else if (w3 == 1) { if (lp+8>lend) return -1; lp+=8; }
                            else if (w3 == 2) { const uint8_t *x; size_t xn; if (pb_rd_bytes(&lp, lend, &x, &xn)) return -1; }
                            else if (w3 == 5) { if (lp+4>lend) return -1; lp+=4; }
                            else return -1;
                        }
                    }
                    if (cl->line_count < lines_n) cl->line_count = lines_n;
                } else if (w2 == 0) { uint64_t v; if (pb_rd_varint(&sp, send, &v)) return -1; }
                else if (w2 == 1) { if (sp+8>send) return -1; sp+=8; }
                else if (w2 == 2) { const uint8_t *x; size_t xn; if (pb_rd_bytes(&sp, send, &x, &xn)) return -1; }
                else if (w2 == 5) { if (sp+4>send) return -1; sp+=4; }
                else return -1;
            }
            if (out->edi.claim_count < claims_n) out->edi.claim_count = claims_n;

        } else if (field == 70 && wt == 0) {
            uint64_t v; if (pb_rd_varint(&p, end, &v)) return -1;
            out->graph.root = (int)(int32_t)(uint32_t)v;
        } else if (field == 71 && wt == 0) {
            uint64_t v; if (pb_rd_varint(&p, end, &v)) return -1;
            /* advisory count */
            (void)v;
        } else if (field == 72 && wt == 2) {
            const uint8_t *sub; size_t slen;
            if (pb_rd_bytes(&p, end, &sub, &slen)) return -1;
            if (out->graph.node_count >= GRAPH_MAX_NODES) continue;
            graph_node_t *n = &out->graph.nodes[out->graph.node_count++];
            const uint8_t *sp = sub, *send = sub + slen;
            int kids = 0;
            while (sp < send) {
                uint64_t t2; if (pb_rd_varint(&sp, send, &t2)) return -1;
                uint32_t f2 = (uint32_t)(t2 >> 3), w2 = (uint32_t)(t2 & 7);
                if (f2 == 1 && w2 == 2) {
                    if (pb_rd_str(&sp, send, n->name, sizeof n->name)) return -1;
                } else if (f2 == 2 && w2 == 0) {
                    uint64_t v; if (pb_rd_varint(&sp, send, &v)) return -1;
                    n->parent = (int)(int32_t)(uint32_t)v;
                } else if (f2 == 3 && w2 == 0) {
                    uint64_t v; if (pb_rd_varint(&sp, send, &v)) return -1;
                    n->related = (int)(int32_t)(uint32_t)v;
                } else if (f2 == 4 && w2 == 0) {
                    uint64_t v; if (pb_rd_varint(&sp, send, &v)) return -1;
                    if (kids < GRAPH_MAX_CHILDREN) n->children[kids++] = (int)(int32_t)(uint32_t)v;
                } else if (w2 == 0) { uint64_t v; if (pb_rd_varint(&sp, send, &v)) return -1; }
                else if (w2 == 1) { if (sp+8>send) return -1; sp+=8; }
                else if (w2 == 2) { const uint8_t *x; size_t xn; if (pb_rd_bytes(&sp, send, &x, &xn)) return -1; }
                else if (w2 == 5) { if (sp+4>send) return -1; sp+=4; }
                else return -1;
            }
            n->child_count = kids;

        } else if (wt == 0) {
            uint64_t v; if (pb_rd_varint(&p, end, &v)) return -1;
        } else if (wt == 1) {
            if (p + 8 > end) return -1; p += 8;
        } else if (wt == 2) {
            const uint8_t *b; size_t n; if (pb_rd_bytes(&p, end, &b, &n)) return -1;
        } else if (wt == 5) {
            if (p + 4 > end) return -1; p += 4;
        } else return -1;
    }
    return got_kind == (int)kind ? 0 : -1;
}

#endif
