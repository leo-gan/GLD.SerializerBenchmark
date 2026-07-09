#include "ser_common.h"
#include "zcbor_encode.h"
#include "zcbor_decode.h"
#include "zcbor_common.h"

/*
 * Optimal zcbor usage (Nordic):
 *  - zcbor_map_start_encode / tstr_put / typed puts for structured data
 *  - zcbor_map_start_decode + key match for decode
 */

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static bool put_kv_int(zcbor_state_t *s, const char *k, int32_t v) {
    return zcbor_tstr_put_term(s, k, 64) && zcbor_int32_put(s, v);
}
static bool put_kv_str(zcbor_state_t *s, const char *k, const char *v) {
    return zcbor_tstr_put_term(s, k, 64) && zcbor_tstr_put_term(s, v, 256);
}
static bool put_kv_bool(zcbor_state_t *s, const char *k, bool v) {
    return zcbor_tstr_put_term(s, k, 64) && zcbor_bool_put(s, v);
}
static bool put_kv_double(zcbor_state_t *s, const char *k, double v) {
    return zcbor_tstr_put_term(s, k, 64) && zcbor_float64_put(s, v);
}

static bool enc_fx(zcbor_state_t *s, const test_fixture_t *fx) {
    size_t nkeys = 2;
    switch (fx->kind) {
        case TD_INTEGER: nkeys = 2; break;
        case TD_SIMPLE: nkeys = 5; break;
        case TD_PERSON: nkeys = 7; break;
        case TD_TELEMETRY: nkeys = 10; break;
        case TD_STRING_ARRAY: nkeys = 3; break;
        case TD_EDI835: nkeys = 7; break;
        case TD_OBJECT_GRAPH: nkeys = 3; break;
        default: return false;
    }
    if (!zcbor_map_start_encode(s, nkeys)) return false;
    if (!put_kv_int(s, "kind", (int32_t)fx->kind)) return false;
    switch (fx->kind) {
        case TD_INTEGER:
            if (!put_kv_int(s, "value", fx->integer_val)) return false;
            break;
        case TD_SIMPLE:
            if (!put_kv_int(s, "Id", fx->simple.id)) return false;
            if (!put_kv_str(s, "Name", fx->simple.name)) return false;
            if (!put_kv_str(s, "Timestamp", fx->simple.timestamp)) return false;
            if (!put_kv_bool(s, "IsActive", fx->simple.is_active)) return false;
            break;
        case TD_PERSON: {
            const person_t *p = &fx->person;
            if (!put_kv_str(s, "FirstName", p->first_name)) return false;
            if (!put_kv_str(s, "LastName", p->last_name)) return false;
            if (!put_kv_int(s, "Age", p->age)) return false;
            if (!put_kv_int(s, "Gender", p->gender)) return false;
            if (!zcbor_tstr_put_term(s, "Passport", 64)) return false;
            if (!zcbor_map_start_encode(s, 2)) return false;
            if (!put_kv_str(s, "Number", p->passport_number)) return false;
            if (!put_kv_str(s, "Authority", p->passport_authority)) return false;
            if (!zcbor_map_end_encode(s, 2)) return false;
            int n = p->police_count; if (n < 0) n = 0; if (n > 8) n = 8;
            if (!zcbor_tstr_put_term(s, "PoliceRecords", 64)) return false;
            if (!zcbor_list_start_encode(s, (size_t)n)) return false;
            for (int i = 0; i < n; i++) {
                if (!zcbor_map_start_encode(s, 2)) return false;
                if (!put_kv_int(s, "Id", p->police_ids[i])) return false;
                if (!put_kv_str(s, "CrimeCode", p->police_codes[i])) return false;
                if (!zcbor_map_end_encode(s, 2)) return false;
            }
            if (!zcbor_list_end_encode(s, (size_t)n)) return false;
            break;
        }
        case TD_TELEMETRY: {
            const telemetry_t *t = &fx->telemetry;
            if (!put_kv_str(s, "Id", t->id)) return false;
            if (!put_kv_str(s, "DataSource", t->data_source)) return false;
            if (!put_kv_str(s, "TimeStamp", t->time_stamp)) return false;
            if (!put_kv_int(s, "Param1", t->param1)) return false;
            if (!put_kv_int(s, "Param2", t->param2)) return false;
            int n = t->meas_count; if (n < 0) n = 0; if (n > 100) n = 100;
            if (!zcbor_tstr_put_term(s, "Measurements", 64)) return false;
            if (!zcbor_list_start_encode(s, (size_t)n)) return false;
            for (int i = 0; i < n; i++) if (!zcbor_float64_put(s, t->measurements[i])) return false;
            if (!zcbor_list_end_encode(s, (size_t)n)) return false;
            if (!put_kv_int(s, "AssociatedProblemID", t->problem_id)) return false;
            if (!put_kv_int(s, "AssociatedLogID", t->log_id)) return false;
            if (!put_kv_bool(s, "WasProcessed", t->was_processed)) return false;
            break;
        }
        case TD_STRING_ARRAY: {
            int n = fx->string_array.count; if (n < 0) n = 0; if (n > 100) n = 100;
            if (!put_kv_int(s, "Count", n)) return false;
            if (!zcbor_tstr_put_term(s, "Items", 64)) return false;
            if (!zcbor_list_start_encode(s, (size_t)n)) return false;
            for (int i = 0; i < n; i++) if (!zcbor_tstr_put_term(s, fx->string_array.items[i], 16)) return false;
            if (!zcbor_list_end_encode(s, (size_t)n)) return false;
            break;
        }
        case TD_EDI835: {
            const edi835_t *e = &fx->edi;
            if (!put_kv_str(s, "PayerName", e->payer_name)) return false;
            if (!put_kv_str(s, "PayeeName", e->payee_name)) return false;
            if (!put_kv_str(s, "PaymentDate", e->payment_date)) return false;
            if (!put_kv_double(s, "TotalActual", e->total_actual)) return false;
            if (!put_kv_str(s, "TCN", e->tcn)) return false;
            int nc = e->claim_count; if (nc < 0) nc = 0; if (nc > 6) nc = 6;
            if (!zcbor_tstr_put_term(s, "Claims", 64)) return false;
            if (!zcbor_list_start_encode(s, (size_t)nc)) return false;
            for (int c = 0; c < nc; c++) {
                const claim_t *cl = &e->claims[c];
                int nl = cl->line_count; if (nl < 0) nl = 0; if (nl > 4) nl = 4;
                if (!zcbor_map_start_encode(s, 5)) return false;
                if (!put_kv_str(s, "ClaimId", cl->claim_id)) return false;
                if (!put_kv_str(s, "PatientName", cl->patient_name)) return false;
                if (!put_kv_double(s, "TotalCharge", cl->total_charge)) return false;
                if (!put_kv_double(s, "Payment", cl->payment)) return false;
                if (!zcbor_tstr_put_term(s, "Lines", 64)) return false;
                if (!zcbor_list_start_encode(s, (size_t)nl)) return false;
                for (int L = 0; L < nl; L++) {
                    if (!zcbor_map_start_encode(s, 3)) return false;
                    if (!put_kv_str(s, "ServiceCode", cl->lines[L].service_code)) return false;
                    if (!put_kv_double(s, "Charge", cl->lines[L].charge)) return false;
                    if (!put_kv_double(s, "Adjudicated", cl->lines[L].adjudicated)) return false;
                    if (!zcbor_map_end_encode(s, 3)) return false;
                }
                if (!zcbor_list_end_encode(s, (size_t)nl)) return false;
                if (!zcbor_map_end_encode(s, 5)) return false;
            }
            if (!zcbor_list_end_encode(s, (size_t)nc)) return false;
            break;
        }

        case TD_OBJECT_GRAPH: {
            const object_graph_t *g = &fx->graph;
            if (!put_kv_int(s, "root", g->root)) return false;
            int nn = g->node_count; if (nn < 0) nn = 0; if (nn > GRAPH_MAX_NODES) nn = GRAPH_MAX_NODES;
            if (!zcbor_tstr_put_term(s, "nodes", 64)) return false;
            if (!zcbor_list_start_encode(s, (size_t)nn)) return false;
            for (int i = 0; i < nn; i++) {
                const graph_node_t *n = &g->nodes[i];
                int nc = n->child_count; if (nc < 0) nc = 0; if (nc > GRAPH_MAX_CHILDREN) nc = GRAPH_MAX_CHILDREN;
                if (!zcbor_map_start_encode(s, 4)) return false;
                if (!put_kv_str(s, "Name", n->name)) return false;
                if (!put_kv_int(s, "Parent", n->parent)) return false;
                if (!put_kv_int(s, "Related", n->related)) return false;
                if (!zcbor_tstr_put_term(s, "Children", 64)) return false;
                if (!zcbor_list_start_encode(s, (size_t)nc)) return false;
                for (int c = 0; c < nc; c++) if (!zcbor_int32_put(s, n->children[c])) return false;
                if (!zcbor_list_end_encode(s, (size_t)nc)) return false;
                if (!zcbor_map_end_encode(s, 4)) return false;
            }
            if (!zcbor_list_end_encode(s, (size_t)nn)) return false;
            break;
        }
        default: return false;
    }
    return zcbor_map_end_encode(s, nkeys);
}

static int key_eq(const struct zcbor_string *k, const char *lit) {
    size_t n = strlen(lit);
    return k->len == n && memcmp(k->value, lit, n) == 0;
}
static int copy_zstr(const struct zcbor_string *s, char *dst, size_t dstsz) {
    if (!s->value || s->len >= dstsz) return -1;
    memcpy(dst, s->value, s->len); dst[s->len] = 0; return 0;
}

static int read_fx(zcbor_state_t *s, test_fixture_t *out, test_data_kind_t kind) {
    if (!zcbor_map_start_decode(s)) return -1;
    int kfound = -1;
    memset(out, 0, sizeof *out);
    out->kind = kind;
    out->name = test_data_name(kind);
    while (!zcbor_array_at_end(s)) {
        struct zcbor_string key;
        if (!zcbor_tstr_decode(s, &key)) return -1;
        if (key_eq(&key, "kind")) {
            int32_t v; if (!zcbor_int32_decode(s, &v)) return -1; kfound = (int)v;
        } else if (key_eq(&key, "value") && kind == TD_INTEGER) {
            int32_t v; if (!zcbor_int32_decode(s, &v)) return -1; out->integer_val = (int)v;
        } else if (key_eq(&key, "Id") && kind == TD_SIMPLE) {
            int32_t v; if (!zcbor_int32_decode(s, &v)) return -1; out->simple.id = (int)v;
        } else if (key_eq(&key, "Name") && kind == TD_SIMPLE) {
            struct zcbor_string v; if (!zcbor_tstr_decode(s, &v) || copy_zstr(&v, out->simple.name, sizeof out->simple.name)) return -1;
        } else if (key_eq(&key, "Timestamp") && kind == TD_SIMPLE) {
            struct zcbor_string v; if (!zcbor_tstr_decode(s, &v) || copy_zstr(&v, out->simple.timestamp, sizeof out->simple.timestamp)) return -1;
        } else if (key_eq(&key, "IsActive") && kind == TD_SIMPLE) {
            bool v; if (!zcbor_bool_decode(s, &v)) return -1; out->simple.is_active = v;
        } else if (key_eq(&key, "FirstName") && kind == TD_PERSON) {
            struct zcbor_string v; if (!zcbor_tstr_decode(s, &v) || copy_zstr(&v, out->person.first_name, sizeof out->person.first_name)) return -1;
        } else if (key_eq(&key, "LastName") && kind == TD_PERSON) {
            struct zcbor_string v; if (!zcbor_tstr_decode(s, &v) || copy_zstr(&v, out->person.last_name, sizeof out->person.last_name)) return -1;
        } else if (key_eq(&key, "Age") && kind == TD_PERSON) {
            int32_t v; if (!zcbor_int32_decode(s, &v)) return -1; out->person.age = (int)v;
        } else if (key_eq(&key, "Gender") && kind == TD_PERSON) {
            int32_t v; if (!zcbor_int32_decode(s, &v)) return -1; out->person.gender = (int)v;
        } else if (key_eq(&key, "Passport") && kind == TD_PERSON) {
            if (!zcbor_map_start_decode(s)) return -1;
            while (!zcbor_array_at_end(s)) {
                struct zcbor_string pk, pv;
                if (!zcbor_tstr_decode(s, &pk)) return -1;
                if (key_eq(&pk, "Number")) {
                    if (!zcbor_tstr_decode(s, &pv) || copy_zstr(&pv, out->person.passport_number, sizeof out->person.passport_number)) return -1;
                } else if (key_eq(&pk, "Authority")) {
                    if (!zcbor_tstr_decode(s, &pv) || copy_zstr(&pv, out->person.passport_authority, sizeof out->person.passport_authority)) return -1;
                } else if (!zcbor_any_skip(s, NULL)) return -1;
            }
            if (!zcbor_map_end_decode(s)) return -1;
        } else if (key_eq(&key, "PoliceRecords") && kind == TD_PERSON) {
            if (!zcbor_list_start_decode(s)) return -1;
            int i = 0;
            while (!zcbor_array_at_end(s) && i < 8) {
                if (!zcbor_map_start_decode(s)) return -1;
                while (!zcbor_array_at_end(s)) {
                    struct zcbor_string pk;
                    if (!zcbor_tstr_decode(s, &pk)) return -1;
                    if (key_eq(&pk, "Id")) {
                        int32_t v; if (!zcbor_int32_decode(s, &v)) return -1; out->person.police_ids[i] = (int)v;
                    } else if (key_eq(&pk, "CrimeCode")) {
                        struct zcbor_string v; if (!zcbor_tstr_decode(s, &v) || copy_zstr(&v, out->person.police_codes[i], sizeof out->person.police_codes[i])) return -1;
                    } else if (!zcbor_any_skip(s, NULL)) return -1;
                }
                if (!zcbor_map_end_decode(s)) return -1;
                i++;
            }
            out->person.police_count = i;
            if (!zcbor_list_end_decode(s)) return -1;
        } else if (key_eq(&key, "Id") && kind == TD_TELEMETRY) {
            struct zcbor_string v; if (!zcbor_tstr_decode(s, &v) || copy_zstr(&v, out->telemetry.id, sizeof out->telemetry.id)) return -1;
        } else if (key_eq(&key, "DataSource") && kind == TD_TELEMETRY) {
            struct zcbor_string v; if (!zcbor_tstr_decode(s, &v) || copy_zstr(&v, out->telemetry.data_source, sizeof out->telemetry.data_source)) return -1;
        } else if (key_eq(&key, "TimeStamp") && kind == TD_TELEMETRY) {
            struct zcbor_string v; if (!zcbor_tstr_decode(s, &v) || copy_zstr(&v, out->telemetry.time_stamp, sizeof out->telemetry.time_stamp)) return -1;
        } else if (key_eq(&key, "Param1") && kind == TD_TELEMETRY) {
            int32_t v; if (!zcbor_int32_decode(s, &v)) return -1; out->telemetry.param1 = (int)v;
        } else if (key_eq(&key, "Param2") && kind == TD_TELEMETRY) {
            int32_t v; if (!zcbor_int32_decode(s, &v)) return -1; out->telemetry.param2 = (int)v;
        } else if (key_eq(&key, "AssociatedProblemID") && kind == TD_TELEMETRY) {
            int32_t v; if (!zcbor_int32_decode(s, &v)) return -1; out->telemetry.problem_id = (int)v;
        } else if (key_eq(&key, "AssociatedLogID") && kind == TD_TELEMETRY) {
            int32_t v; if (!zcbor_int32_decode(s, &v)) return -1; out->telemetry.log_id = (int)v;
        } else if (key_eq(&key, "WasProcessed") && kind == TD_TELEMETRY) {
            bool v; if (!zcbor_bool_decode(s, &v)) return -1; out->telemetry.was_processed = v;
        } else if (key_eq(&key, "Measurements") && kind == TD_TELEMETRY) {
            if (!zcbor_list_start_decode(s)) return -1;
            int i = 0;
            while (!zcbor_array_at_end(s) && i < 100) {
                double d; if (!zcbor_float64_decode(s, &d)) return -1;
                out->telemetry.measurements[i++] = d;
            }
            out->telemetry.meas_count = i;
            if (!zcbor_list_end_decode(s)) return -1;
        } else if (key_eq(&key, "Items") && kind == TD_STRING_ARRAY) {
            if (!zcbor_list_start_decode(s)) return -1;
            int i = 0;
            while (!zcbor_array_at_end(s) && i < 100) {
                struct zcbor_string v; if (!zcbor_tstr_decode(s, &v) || copy_zstr(&v, out->string_array.items[i], sizeof out->string_array.items[i])) return -1;
                i++;
            }
            out->string_array.count = i;
            if (!zcbor_list_end_decode(s)) return -1;
        } else if (key_eq(&key, "PayerName") && kind == TD_EDI835) {
            struct zcbor_string v; if (!zcbor_tstr_decode(s, &v) || copy_zstr(&v, out->edi.payer_name, sizeof out->edi.payer_name)) return -1;
        } else if (key_eq(&key, "PayeeName") && kind == TD_EDI835) {
            struct zcbor_string v; if (!zcbor_tstr_decode(s, &v) || copy_zstr(&v, out->edi.payee_name, sizeof out->edi.payee_name)) return -1;
        } else if (key_eq(&key, "PaymentDate") && kind == TD_EDI835) {
            struct zcbor_string v; if (!zcbor_tstr_decode(s, &v) || copy_zstr(&v, out->edi.payment_date, sizeof out->edi.payment_date)) return -1;
        } else if (key_eq(&key, "TCN") && kind == TD_EDI835) {
            struct zcbor_string v; if (!zcbor_tstr_decode(s, &v) || copy_zstr(&v, out->edi.tcn, sizeof out->edi.tcn)) return -1;
        } else if (key_eq(&key, "TotalActual") && kind == TD_EDI835) {
            double d; if (!zcbor_float64_decode(s, &d)) return -1; out->edi.total_actual = d;
        } else if (key_eq(&key, "Claims") && kind == TD_EDI835) {
            if (!zcbor_list_start_decode(s)) return -1;
            int c = 0;
            while (!zcbor_array_at_end(s) && c < 6) {
                claim_t *cl = &out->edi.claims[c];
                if (!zcbor_map_start_decode(s)) return -1;
                while (!zcbor_array_at_end(s)) {
                    struct zcbor_string ck;
                    if (!zcbor_tstr_decode(s, &ck)) return -1;
                    if (key_eq(&ck, "ClaimId")) {
                        struct zcbor_string v; if (!zcbor_tstr_decode(s, &v) || copy_zstr(&v, cl->claim_id, sizeof cl->claim_id)) return -1;
                    } else if (key_eq(&ck, "PatientName")) {
                        struct zcbor_string v; if (!zcbor_tstr_decode(s, &v) || copy_zstr(&v, cl->patient_name, sizeof cl->patient_name)) return -1;
                    } else if (key_eq(&ck, "TotalCharge")) {
                        double d; if (!zcbor_float64_decode(s, &d)) return -1; cl->total_charge = d;
                    } else if (key_eq(&ck, "Payment")) {
                        double d; if (!zcbor_float64_decode(s, &d)) return -1; cl->payment = d;
                    } else if (key_eq(&ck, "Lines")) {
                        if (!zcbor_list_start_decode(s)) return -1;
                        int L = 0;
                        while (!zcbor_array_at_end(s) && L < 4) {
                            if (!zcbor_map_start_decode(s)) return -1;
                            while (!zcbor_array_at_end(s)) {
                                struct zcbor_string lk;
                                if (!zcbor_tstr_decode(s, &lk)) return -1;
                                if (key_eq(&lk, "ServiceCode")) {
                                    struct zcbor_string v; if (!zcbor_tstr_decode(s, &v) || copy_zstr(&v, cl->lines[L].service_code, sizeof cl->lines[L].service_code)) return -1;
                                } else if (key_eq(&lk, "Charge")) {
                                    double d; if (!zcbor_float64_decode(s, &d)) return -1; cl->lines[L].charge = d;
                                } else if (key_eq(&lk, "Adjudicated")) {
                                    double d; if (!zcbor_float64_decode(s, &d)) return -1; cl->lines[L].adjudicated = d;
                                } else if (!zcbor_any_skip(s, NULL)) return -1;
                            }
                            if (!zcbor_map_end_decode(s)) return -1;
                            L++;
                        }
                        cl->line_count = L;
                        if (!zcbor_list_end_decode(s)) return -1;
                    } else if (!zcbor_any_skip(s, NULL)) return -1;
                }
                if (!zcbor_map_end_decode(s)) return -1;
                c++;
            }
            out->edi.claim_count = c;
            if (!zcbor_list_end_decode(s)) return -1;

        } else if (key_eq(&key, "root") && kind == TD_OBJECT_GRAPH) {
            int32_t v; if (!zcbor_int32_decode(s, &v)) return -1; out->graph.root = (int)v;
        } else if (key_eq(&key, "nodes") && kind == TD_OBJECT_GRAPH) {
            if (!zcbor_list_start_decode(s)) return -1;
            int i = 0;
            while (!zcbor_array_at_end(s) && i < GRAPH_MAX_NODES) {
                graph_node_t *n = &out->graph.nodes[i];
                if (!zcbor_map_start_decode(s)) return -1;
                while (!zcbor_array_at_end(s)) {
                    struct zcbor_string nk;
                    if (!zcbor_tstr_decode(s, &nk)) return -1;
                    if (key_eq(&nk, "Name")) {
                        struct zcbor_string v; if (!zcbor_tstr_decode(s, &v) || copy_zstr(&v, n->name, sizeof n->name)) return -1;
                    } else if (key_eq(&nk, "Parent")) {
                        int32_t v; if (!zcbor_int32_decode(s, &v)) return -1; n->parent = (int)v;
                    } else if (key_eq(&nk, "Related")) {
                        int32_t v; if (!zcbor_int32_decode(s, &v)) return -1; n->related = (int)v;
                    } else if (key_eq(&nk, "Children")) {
                        if (!zcbor_list_start_decode(s)) return -1;
                        int c = 0;
                        while (!zcbor_array_at_end(s) && c < GRAPH_MAX_CHILDREN) {
                            int32_t v; if (!zcbor_int32_decode(s, &v)) return -1;
                            n->children[c++] = (int)v;
                        }
                        n->child_count = c;
                        if (!zcbor_list_end_decode(s)) return -1;
                    } else if (!zcbor_any_skip(s, NULL)) return -1;
                }
                if (!zcbor_map_end_decode(s)) return -1;
                i++;
            }
            out->graph.node_count = i;
            if (!zcbor_list_end_decode(s)) return -1;

        } else if (!zcbor_any_skip(s, NULL)) {
            return -1;
        }
    }
    if (!zcbor_map_end_decode(s)) return -1;
    return kfound == (int)kind ? 0 : -1;
}

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    ZCBOR_STATE_E(state, 8, buf, cap, 0);
    if (!enc_fx(state, fx)) return -1;
    *ol = (size_t)(state->payload - buf);
    return 0;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    ZCBOR_STATE_D(state, 8, buf, len, 32, 0);
    return read_fx(state, out, kind);
}

void bench_register_zcbor(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "zcbor", "0.9", "schema", prep, ser, de, fidelity_fx);
}
