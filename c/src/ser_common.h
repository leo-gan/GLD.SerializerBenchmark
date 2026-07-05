#ifndef SER_COMMON_H
#define SER_COMMON_H
#include "bench.h"
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

static inline bool supports_all(test_data_kind_t k) { (void)k; return true; }

static inline bool f64_close(double a, double b) {
    double d = a - b; if (d < 0) d = -d;
    double s = a >= 0 ? a : -a; if (b > s) s = b >= 0 ? b : -b;
    return d <= 1e-9 || d <= 1e-6 * (s + 1.0);
}

static inline bool fidelity_person(const person_t *a, const person_t *b) {
    if (a->age != b->age || a->gender != b->gender || a->police_count != b->police_count)
        return false;
    if (strcmp(a->first_name, b->first_name) || strcmp(a->last_name, b->last_name))
        return false;
    if (strcmp(a->passport_number, b->passport_number) ||
        strcmp(a->passport_authority, b->passport_authority))
        return false;
    for (int i = 0; i < a->police_count && i < 8; i++) {
        if (a->police_ids[i] != b->police_ids[i]) return false;
        if (strcmp(a->police_codes[i], b->police_codes[i])) return false;
    }
    return true;
}

static inline bool fidelity_simple(const simple_object_t *a, const simple_object_t *b) {
    return a->id == b->id && a->is_active == b->is_active &&
           strcmp(a->name, b->name) == 0 && strcmp(a->timestamp, b->timestamp) == 0;
}

static inline bool fidelity_telem(const telemetry_t *a, const telemetry_t *b) {
    if (a->param1 != b->param1 || a->param2 != b->param2 || a->meas_count != b->meas_count)
        return false;
    if (a->problem_id != b->problem_id || a->log_id != b->log_id ||
        a->was_processed != b->was_processed)
        return false;
    if (strcmp(a->id, b->id) || strcmp(a->data_source, b->data_source))
        return false;
    for (int i = 0; i < a->meas_count && i < 100; i++)
        if (!f64_close(a->measurements[i], b->measurements[i])) return false;
    return true;
}

static inline bool fidelity_strarr(const string_array_t *a, const string_array_t *b) {
    if (a->count != b->count) return false;
    for (int i = 0; i < a->count; i++)
        if (strcmp(a->items[i], b->items[i]) != 0) return false;
    return true;
}

static inline bool fidelity_edi(const edi835_t *a, const edi835_t *b) {
    if (a->claim_count != b->claim_count) return false;
    if (strcmp(a->payer_name, b->payer_name) || strcmp(a->payee_name, b->payee_name))
        return false;
    if (!f64_close(a->total_actual, b->total_actual)) return false;
    for (int c = 0; c < a->claim_count && c < 6; c++) {
        if (strcmp(a->claims[c].claim_id, b->claims[c].claim_id)) return false;
        if (a->claims[c].line_count != b->claims[c].line_count) return false;
    }
    return true;
}

static inline bool fidelity_fx(const test_fixture_t *a, const test_fixture_t *b) {
    if (a->kind != b->kind) return false;
    switch (a->kind) {
        case TD_PERSON: return fidelity_person(&a->person, &b->person);
        case TD_INTEGER: return a->integer_val == b->integer_val;
        case TD_TELEMETRY: return fidelity_telem(&a->telemetry, &b->telemetry);
        case TD_SIMPLE: return fidelity_simple(&a->simple, &b->simple);
        case TD_STRING_ARRAY: return fidelity_strarr(&a->string_array, &b->string_array);
        case TD_EDI835: return fidelity_edi(&a->edi, &b->edi);
        default: return false;
    }
}

/* custom-binary: hand-packed structs (baseline, not a third-party library) */
#define BIN_PERSON_FIXED_BYTES   124
#define BIN_PERSON_POLICE_BYTES  20
#define BIN_SIMPLE_BYTES         69
#define BIN_TELEMETRY_PRE_BYTES  92
#define BIN_TELEMETRY_TAIL_BYTES 9
#define BIN_TELEMETRY_FIXED_BYTES (BIN_TELEMETRY_PRE_BYTES + BIN_TELEMETRY_TAIL_BYTES)
/* EDI header: payer(32)+payee(32)+payment_date(32)+total(8)+tcn(24)+claim_count(4) */
#define BIN_EDI_HDR_BYTES        132
/* service line: code(16)+charge(8)+adjudicated(8) */
#define BIN_EDI_LINE_BYTES       32
/* claim fixed: id(16)+patient(32)+total_charge(8)+payment(8)+line_count(4) */
#define BIN_EDI_CLAIM_FIXED      68

static inline int bin_write_fixture(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *out_len) {
    if (cap < 1) return -1;
    size_t o = 0;
    buf[o++] = (uint8_t)fx->kind;
    switch (fx->kind) {
        case TD_INTEGER: {
            if (o + 4 > cap) return -1;
            int32_t v = fx->integer_val;
            memcpy(buf + o, &v, 4); o += 4;
            break;
        }
        case TD_SIMPLE: {
            const simple_object_t *s = &fx->simple;
            if (o + BIN_SIMPLE_BYTES > cap) return -1;
            memcpy(buf + o, &s->id, 4); o += 4;
            memcpy(buf + o, s->name, 32); o += 32;
            memcpy(buf + o, s->timestamp, 32); o += 32;
            buf[o++] = s->is_active ? 1 : 0;
            break;
        }
        case TD_PERSON: {
            const person_t *p = &fx->person;
            int n_police = p->police_count;
            if (n_police < 0) n_police = 0;
            if (n_police > 8) n_police = 8;
            size_t need = (size_t)BIN_PERSON_FIXED_BYTES + (size_t)n_police * BIN_PERSON_POLICE_BYTES;
            if (o + need > cap) return -1;
            memcpy(buf + o, p->first_name, 32); o += 32;
            memcpy(buf + o, p->last_name, 32); o += 32;
            memcpy(buf + o, &p->age, 4); o += 4;
            memcpy(buf + o, &p->gender, 4); o += 4;
            memcpy(buf + o, p->passport_number, 24); o += 24;
            memcpy(buf + o, p->passport_authority, 24); o += 24;
            int32_t police_wire = (int32_t)n_police;
            memcpy(buf + o, &police_wire, 4); o += 4;
            for (int i = 0; i < n_police; i++) {
                memcpy(buf + o, &p->police_ids[i], 4); o += 4;
                memcpy(buf + o, p->police_codes[i], 16); o += 16;
            }
            break;
        }
        case TD_STRING_ARRAY: {
            const string_array_t *a = &fx->string_array;
            int n = a->count;
            if (n < 0) n = 0;
            if (n > 100) n = 100;
            if (o + 4 + (size_t)n * 16 > cap) return -1;
            int32_t count_wire = (int32_t)n;
            memcpy(buf + o, &count_wire, 4); o += 4;
            for (int i = 0; i < n; i++) { memcpy(buf + o, a->items[i], 16); o += 16; }
            break;
        }
        case TD_TELEMETRY: {
            const telemetry_t *t = &fx->telemetry;
            int n_meas = t->meas_count;
            if (n_meas < 0) n_meas = 0;
            if (n_meas > 100) n_meas = 100;
            size_t need = (size_t)BIN_TELEMETRY_FIXED_BYTES + (size_t)n_meas * 8;
            if (o + need > cap) return -1;
            memcpy(buf + o, t->id, 24); o += 24;
            memcpy(buf + o, t->data_source, 24); o += 24;
            memcpy(buf + o, t->time_stamp, 32); o += 32;
            memcpy(buf + o, &t->param1, 4); o += 4;
            memcpy(buf + o, &t->param2, 4); o += 4;
            int32_t meas_wire = (int32_t)n_meas;
            memcpy(buf + o, &meas_wire, 4); o += 4;
            for (int i = 0; i < n_meas; i++) { memcpy(buf + o, &t->measurements[i], 8); o += 8; }
            memcpy(buf + o, &t->problem_id, 4); o += 4;
            memcpy(buf + o, &t->log_id, 4); o += 4;
            buf[o++] = t->was_processed ? 1 : 0;
            break;
        }
        case TD_EDI835: {
            const edi835_t *e = &fx->edi;
            int nc = e->claim_count;
            if (nc < 0) nc = 0;
            if (nc > 6) nc = 6;
            size_t need = (size_t)BIN_EDI_HDR_BYTES;
            for (int c = 0; c < nc; c++) {
                int nl = e->claims[c].line_count;
                if (nl < 0) nl = 0;
                if (nl > 4) nl = 4;
                need += (size_t)BIN_EDI_CLAIM_FIXED + (size_t)nl * BIN_EDI_LINE_BYTES;
            }
            if (o + need > cap) return -1;
            memcpy(buf + o, e->payer_name, 32); o += 32;
            memcpy(buf + o, e->payee_name, 32); o += 32;
            memcpy(buf + o, e->payment_date, 32); o += 32;
            memcpy(buf + o, &e->total_actual, 8); o += 8;
            memcpy(buf + o, e->tcn, 24); o += 24;
            int32_t nc_wire = (int32_t)nc;
            memcpy(buf + o, &nc_wire, 4); o += 4;
            for (int c = 0; c < nc; c++) {
                const claim_t *cl = &e->claims[c];
                int nl = cl->line_count;
                if (nl < 0) nl = 0;
                if (nl > 4) nl = 4;
                memcpy(buf + o, cl->claim_id, 16); o += 16;
                memcpy(buf + o, cl->patient_name, 32); o += 32;
                memcpy(buf + o, &cl->total_charge, 8); o += 8;
                memcpy(buf + o, &cl->payment, 8); o += 8;
                int32_t nl_wire = (int32_t)nl;
                memcpy(buf + o, &nl_wire, 4); o += 4;
                for (int L = 0; L < nl; L++) {
                    memcpy(buf + o, cl->lines[L].service_code, 16); o += 16;
                    memcpy(buf + o, &cl->lines[L].charge, 8); o += 8;
                    memcpy(buf + o, &cl->lines[L].adjudicated, 8); o += 8;
                }
            }
            break;
        }
        default: return -1;
    }
    *out_len = o;
    return 0;
}

static inline int bin_read_fixture(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    if (len < 1) return -1;
    size_t o = 0;
    test_data_kind_t k = (test_data_kind_t)buf[o++];
    if (k != kind) return -1;
    out->kind = k;
    out->name = test_data_name(k);
    switch (k) {
        case TD_INTEGER:
            if (o + 4 > len) return -1;
            memcpy(&out->integer_val, buf + o, 4);
            break;
        case TD_SIMPLE: {
            simple_object_t *s = &out->simple;
            if (o + BIN_SIMPLE_BYTES > len) return -1;
            memcpy(&s->id, buf + o, 4); o += 4;
            memcpy(s->name, buf + o, 32); o += 32;
            memcpy(s->timestamp, buf + o, 32); o += 32;
            s->is_active = buf[o++] != 0;
            break;
        }
        case TD_PERSON: {
            person_t *p = &out->person;
            if (o + BIN_PERSON_FIXED_BYTES > len) return -1;
            memcpy(p->first_name, buf + o, 32); o += 32;
            memcpy(p->last_name, buf + o, 32); o += 32;
            memcpy(&p->age, buf + o, 4); o += 4;
            memcpy(&p->gender, buf + o, 4); o += 4;
            memcpy(p->passport_number, buf + o, 24); o += 24;
            memcpy(p->passport_authority, buf + o, 24); o += 24;
            memcpy(&p->police_count, buf + o, 4); o += 4;
            if (p->police_count < 0 || p->police_count > 8) return -1;
            for (int i = 0; i < p->police_count; i++) {
                if (o + BIN_PERSON_POLICE_BYTES > len) return -1;
                memcpy(&p->police_ids[i], buf + o, 4); o += 4;
                memcpy(p->police_codes[i], buf + o, 16); o += 16;
            }
            break;
        }
        case TD_STRING_ARRAY: {
            string_array_t *a = &out->string_array;
            if (o + 4 > len) return -1;
            memcpy(&a->count, buf + o, 4); o += 4;
            if (a->count < 0 || a->count > 100) return -1;
            if (o + (size_t)a->count * 16 > len) return -1;
            for (int i = 0; i < a->count; i++) {
                memcpy(a->items[i], buf + o, 16); o += 16;
            }
            break;
        }
        case TD_TELEMETRY: {
            telemetry_t *t = &out->telemetry;
            if (o + BIN_TELEMETRY_PRE_BYTES > len) return -1;
            memcpy(t->id, buf + o, 24); o += 24;
            memcpy(t->data_source, buf + o, 24); o += 24;
            memcpy(t->time_stamp, buf + o, 32); o += 32;
            memcpy(&t->param1, buf + o, 4); o += 4;
            memcpy(&t->param2, buf + o, 4); o += 4;
            memcpy(&t->meas_count, buf + o, 4); o += 4;
            if (t->meas_count < 0 || t->meas_count > 100) return -1;
            if (o + (size_t)t->meas_count * 8 + BIN_TELEMETRY_TAIL_BYTES > len) return -1;
            for (int i = 0; i < t->meas_count; i++) {
                memcpy(&t->measurements[i], buf + o, 8); o += 8;
            }
            memcpy(&t->problem_id, buf + o, 4); o += 4;
            memcpy(&t->log_id, buf + o, 4); o += 4;
            t->was_processed = buf[o++] != 0;
            break;
        }
        case TD_EDI835: {
            edi835_t *e = &out->edi;
            memset(e, 0, sizeof *e);
            if (o + BIN_EDI_HDR_BYTES > len) return -1;
            memcpy(e->payer_name, buf + o, 32); o += 32;
            memcpy(e->payee_name, buf + o, 32); o += 32;
            memcpy(e->payment_date, buf + o, 32); o += 32;
            memcpy(&e->total_actual, buf + o, 8); o += 8;
            memcpy(e->tcn, buf + o, 24); o += 24;
            memcpy(&e->claim_count, buf + o, 4); o += 4;
            if (e->claim_count < 0 || e->claim_count > 6) return -1;
            for (int c = 0; c < e->claim_count; c++) {
                if (o + BIN_EDI_CLAIM_FIXED > len) return -1;
                claim_t *cl = &e->claims[c];
                memcpy(cl->claim_id, buf + o, 16); o += 16;
                memcpy(cl->patient_name, buf + o, 32); o += 32;
                memcpy(&cl->total_charge, buf + o, 8); o += 8;
                memcpy(&cl->payment, buf + o, 8); o += 8;
                memcpy(&cl->line_count, buf + o, 4); o += 4;
                if (cl->line_count < 0 || cl->line_count > 4) return -1;
                for (int L = 0; L < cl->line_count; L++) {
                    if (o + BIN_EDI_LINE_BYTES > len) return -1;
                    memcpy(cl->lines[L].service_code, buf + o, 16); o += 16;
                    memcpy(&cl->lines[L].charge, buf + o, 8); o += 8;
                    memcpy(&cl->lines[L].adjudicated, buf + o, 8); o += 8;
                }
            }
            break;
        }
        default: return -1;
    }
    return 0;
}

#define BENCH_ADD(out, count, nm, ver, cat, prep, ser, de, fid) do { \
    (out)[*(count)].name = (nm); \
    (out)[*(count)].version = (ver); \
    (out)[*(count)].category = (cat); \
    (out)[*(count)].supports = supports_all; \
    (out)[*(count)].prepare = (prep); \
    (out)[*(count)].serialize = (ser); \
    (out)[*(count)].deserialize = (de); \
    (out)[*(count)].fidelity = (fid); \
    (*(count))++; \
} while (0)

#endif
