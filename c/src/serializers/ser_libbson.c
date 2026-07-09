#include "ser_common.h"
#include <bson/bson.h>

/*
 * Optimal libbson usage:
 *  - bson_t on stack (BSON_INITIALIZER) + BSON_APPEND_* for fields
 *  - bson_get_data copy into caller buffer
 *  - bson_init_static + bson_iter for decode
 */

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static bool append_fx(bson_t *b, const test_fixture_t *fx) {
    BSON_APPEND_INT32(b, "kind", (int32_t)fx->kind);
    switch (fx->kind) {
        case TD_INTEGER:
            return BSON_APPEND_INT32(b, "value", fx->integer_val);
        case TD_SIMPLE:
            return BSON_APPEND_INT32(b, "Id", fx->simple.id)
                && BSON_APPEND_UTF8(b, "Name", fx->simple.name)
                && BSON_APPEND_UTF8(b, "Timestamp", fx->simple.timestamp)
                && BSON_APPEND_BOOL(b, "IsActive", fx->simple.is_active);
        case TD_PERSON: {
            const person_t *p = &fx->person;
            if (!BSON_APPEND_UTF8(b, "FirstName", p->first_name)) return false;
            if (!BSON_APPEND_UTF8(b, "LastName", p->last_name)) return false;
            if (!BSON_APPEND_INT32(b, "Age", p->age)) return false;
            if (!BSON_APPEND_INT32(b, "Gender", p->gender)) return false;
            bson_t pass;
            if (!BSON_APPEND_DOCUMENT_BEGIN(b, "Passport", &pass)) return false;
            if (!BSON_APPEND_UTF8(&pass, "Number", p->passport_number)) return false;
            if (!BSON_APPEND_UTF8(&pass, "Authority", p->passport_authority)) return false;
            if (!bson_append_document_end(b, &pass)) return false;
            bson_t arr; bson_t rec;
            if (!BSON_APPEND_ARRAY_BEGIN(b, "PoliceRecords", &arr)) return false;
            int n = p->police_count; if (n < 0) n = 0; if (n > 8) n = 8;
            for (int i = 0; i < n; i++) {
                char key[16]; snprintf(key, sizeof key, "%d", i);
                if (!BSON_APPEND_DOCUMENT_BEGIN(&arr, key, &rec)) return false;
                if (!BSON_APPEND_INT32(&rec, "Id", p->police_ids[i])) return false;
                if (!BSON_APPEND_UTF8(&rec, "CrimeCode", p->police_codes[i])) return false;
                if (!bson_append_document_end(&arr, &rec)) return false;
            }
            return bson_append_array_end(b, &arr);
        }
        case TD_TELEMETRY: {
            const telemetry_t *t = &fx->telemetry;
            if (!BSON_APPEND_UTF8(b, "Id", t->id)) return false;
            if (!BSON_APPEND_UTF8(b, "DataSource", t->data_source)) return false;
            if (!BSON_APPEND_UTF8(b, "TimeStamp", t->time_stamp)) return false;
            if (!BSON_APPEND_INT32(b, "Param1", t->param1)) return false;
            if (!BSON_APPEND_INT32(b, "Param2", t->param2)) return false;
            bson_t arr;
            if (!BSON_APPEND_ARRAY_BEGIN(b, "Measurements", &arr)) return false;
            int n = t->meas_count; if (n < 0) n = 0; if (n > 100) n = 100;
            for (int i = 0; i < n; i++) {
                char key[16]; snprintf(key, sizeof key, "%d", i);
                if (!BSON_APPEND_DOUBLE(&arr, key, t->measurements[i])) return false;
            }
            if (!bson_append_array_end(b, &arr)) return false;
            if (!BSON_APPEND_INT32(b, "AssociatedProblemID", t->problem_id)) return false;
            if (!BSON_APPEND_INT32(b, "AssociatedLogID", t->log_id)) return false;
            return BSON_APPEND_BOOL(b, "WasProcessed", t->was_processed);
        }
        case TD_STRING_ARRAY: {
            int n = fx->string_array.count; if (n < 0) n = 0; if (n > 100) n = 100;
            if (!BSON_APPEND_INT32(b, "Count", n)) return false;
            bson_t arr;
            if (!BSON_APPEND_ARRAY_BEGIN(b, "Items", &arr)) return false;
            for (int i = 0; i < n; i++) {
                char key[16]; snprintf(key, sizeof key, "%d", i);
                if (!BSON_APPEND_UTF8(&arr, key, fx->string_array.items[i])) return false;
            }
            return bson_append_array_end(b, &arr);
        }
        case TD_EDI835: {
            const edi835_t *e = &fx->edi;
            if (!BSON_APPEND_UTF8(b, "PayerName", e->payer_name)) return false;
            if (!BSON_APPEND_UTF8(b, "PayeeName", e->payee_name)) return false;
            if (!BSON_APPEND_UTF8(b, "PaymentDate", e->payment_date)) return false;
            if (!BSON_APPEND_DOUBLE(b, "TotalActual", e->total_actual)) return false;
            if (!BSON_APPEND_UTF8(b, "TCN", e->tcn)) return false;
            bson_t claims, co, lines, lo;
            if (!BSON_APPEND_ARRAY_BEGIN(b, "Claims", &claims)) return false;
            int nc = e->claim_count; if (nc < 0) nc = 0; if (nc > 6) nc = 6;
            for (int c = 0; c < nc; c++) {
                const claim_t *cl = &e->claims[c];
                char ck[16]; snprintf(ck, sizeof ck, "%d", c);
                if (!BSON_APPEND_DOCUMENT_BEGIN(&claims, ck, &co)) return false;
                if (!BSON_APPEND_UTF8(&co, "ClaimId", cl->claim_id)) return false;
                if (!BSON_APPEND_UTF8(&co, "PatientName", cl->patient_name)) return false;
                if (!BSON_APPEND_DOUBLE(&co, "TotalCharge", cl->total_charge)) return false;
                if (!BSON_APPEND_DOUBLE(&co, "Payment", cl->payment)) return false;
                if (!BSON_APPEND_ARRAY_BEGIN(&co, "Lines", &lines)) return false;
                int nl = cl->line_count; if (nl < 0) nl = 0; if (nl > 4) nl = 4;
                for (int L = 0; L < nl; L++) {
                    char lk[16]; snprintf(lk, sizeof lk, "%d", L);
                    if (!BSON_APPEND_DOCUMENT_BEGIN(&lines, lk, &lo)) return false;
                    if (!BSON_APPEND_UTF8(&lo, "ServiceCode", cl->lines[L].service_code)) return false;
                    if (!BSON_APPEND_DOUBLE(&lo, "Charge", cl->lines[L].charge)) return false;
                    if (!BSON_APPEND_DOUBLE(&lo, "Adjudicated", cl->lines[L].adjudicated)) return false;
                    if (!bson_append_document_end(&lines, &lo)) return false;
                }
                if (!bson_append_array_end(&co, &lines)) return false;
                if (!bson_append_document_end(&claims, &co)) return false;
            }
            return bson_append_array_end(b, &claims);
        }

        case TD_OBJECT_GRAPH: {
            const object_graph_t *g = &fx->graph;
            if (!BSON_APPEND_INT32(b, "root", g->root)) return false;
            bson_t nodes, no, ch;
            if (!BSON_APPEND_ARRAY_BEGIN(b, "nodes", &nodes)) return false;
            int nn = g->node_count; if (nn < 0) nn = 0; if (nn > GRAPH_MAX_NODES) nn = GRAPH_MAX_NODES;
            for (int i = 0; i < nn; i++) {
                const graph_node_t *n = &g->nodes[i];
                char ik[16]; snprintf(ik, sizeof ik, "%d", i);
                if (!BSON_APPEND_DOCUMENT_BEGIN(&nodes, ik, &no)) return false;
                if (!BSON_APPEND_UTF8(&no, "Name", n->name)) return false;
                if (!BSON_APPEND_INT32(&no, "Parent", n->parent)) return false;
                if (!BSON_APPEND_INT32(&no, "Related", n->related)) return false;
                if (!BSON_APPEND_ARRAY_BEGIN(&no, "Children", &ch)) return false;
                int nc = n->child_count; if (nc < 0) nc = 0; if (nc > GRAPH_MAX_CHILDREN) nc = GRAPH_MAX_CHILDREN;
                for (int c = 0; c < nc; c++) {
                    char ck[16]; snprintf(ck, sizeof ck, "%d", c);
                    if (!BSON_APPEND_INT32(&ch, ck, n->children[c])) return false;
                }
                if (!bson_append_array_end(&no, &ch)) return false;
                if (!bson_append_document_end(&nodes, &no)) return false;
            }
            return bson_append_array_end(b, &nodes);
        }
        default: return false;
    }
}

/* Decode helpers operating on document iterators */
static int get_i32(const bson_t *b, const char *key, int *out) {
    bson_iter_t it;
    if (!bson_iter_init_find(&it, b, key) || !BSON_ITER_HOLDS_INT32(&it)) return -1;
    *out = bson_iter_int32(&it); return 0;
}
static int get_utf8(const bson_t *b, const char *key, char *dst, size_t dstsz) {
    bson_iter_t it;
    if (!bson_iter_init_find(&it, b, key) || !BSON_ITER_HOLDS_UTF8(&it)) return -1;
    uint32_t len = 0; const char *s = bson_iter_utf8(&it, &len);
    if (!s || len >= dstsz) return -1;
    memcpy(dst, s, len); dst[len] = 0; return 0;
}
static int get_bool(const bson_t *b, const char *key, bool *out) {
    bson_iter_t it;
    if (!bson_iter_init_find(&it, b, key) || !BSON_ITER_HOLDS_BOOL(&it)) return -1;
    *out = bson_iter_bool(&it); return 0;
}
static int get_f64(const bson_t *b, const char *key, double *out) {
    bson_iter_t it;
    if (!bson_iter_init_find(&it, b, key) || !BSON_ITER_HOLDS_DOUBLE(&it)) return -1;
    *out = bson_iter_double(&it); return 0;
}

static int read_fx(const bson_t *b, test_fixture_t *out, test_data_kind_t kind) {
    int k = -1;
    if (get_i32(b, "kind", &k) || k != (int)kind) return -1;
    memset(out, 0, sizeof *out);
    out->kind = kind;
    out->name = test_data_name(kind);
    switch (kind) {
        case TD_INTEGER: return get_i32(b, "value", &out->integer_val);
        case TD_SIMPLE: {
            if (get_i32(b, "Id", &out->simple.id)) return -1;
            if (get_utf8(b, "Name", out->simple.name, sizeof out->simple.name)) return -1;
            get_utf8(b, "Timestamp", out->simple.timestamp, sizeof out->simple.timestamp);
            bool act = false; get_bool(b, "IsActive", &act); out->simple.is_active = act;
            return 0;
        }
        case TD_PERSON: {
            if (get_utf8(b, "FirstName", out->person.first_name, sizeof out->person.first_name)) return -1;
            if (get_utf8(b, "LastName", out->person.last_name, sizeof out->person.last_name)) return -1;
            get_i32(b, "Age", &out->person.age);
            get_i32(b, "Gender", &out->person.gender);
            bson_iter_t it, pass;
            if (bson_iter_init_find(&it, b, "Passport") && BSON_ITER_HOLDS_DOCUMENT(&it) && bson_iter_recurse(&it, &pass)) {
                bson_t pdoc;
                const uint8_t *data = NULL; uint32_t len = 0;
                bson_iter_document(&it, &len, &data);
                if (data && bson_init_static(&pdoc, data, len)) {
                    get_utf8(&pdoc, "Number", out->person.passport_number, sizeof out->person.passport_number);
                    get_utf8(&pdoc, "Authority", out->person.passport_authority, sizeof out->person.passport_authority);
                }
            }
            if (bson_iter_init_find(&it, b, "PoliceRecords") && BSON_ITER_HOLDS_ARRAY(&it)) {
                bson_iter_t arr;
                if (bson_iter_recurse(&it, &arr)) {
                    int i = 0;
                    while (bson_iter_next(&arr) && i < 8) {
                        if (!BSON_ITER_HOLDS_DOCUMENT(&arr)) continue;
                        const uint8_t *data = NULL; uint32_t len = 0;
                        bson_iter_document(&arr, &len, &data);
                        bson_t rec;
                        if (!data || !bson_init_static(&rec, data, len)) continue;
                        get_i32(&rec, "Id", &out->person.police_ids[i]);
                        get_utf8(&rec, "CrimeCode", out->person.police_codes[i], sizeof out->person.police_codes[i]);
                        i++;
                    }
                    out->person.police_count = i;
                }
            }
            return 0;
        }
        case TD_TELEMETRY: {
            if (get_utf8(b, "Id", out->telemetry.id, sizeof out->telemetry.id)) return -1;
            get_utf8(b, "DataSource", out->telemetry.data_source, sizeof out->telemetry.data_source);
            get_utf8(b, "TimeStamp", out->telemetry.time_stamp, sizeof out->telemetry.time_stamp);
            get_i32(b, "Param1", &out->telemetry.param1);
            get_i32(b, "Param2", &out->telemetry.param2);
            get_i32(b, "AssociatedProblemID", &out->telemetry.problem_id);
            get_i32(b, "AssociatedLogID", &out->telemetry.log_id);
            bool wp = false; get_bool(b, "WasProcessed", &wp); out->telemetry.was_processed = wp;
            bson_iter_t it;
            if (bson_iter_init_find(&it, b, "Measurements") && BSON_ITER_HOLDS_ARRAY(&it)) {
                bson_iter_t arr;
                if (bson_iter_recurse(&it, &arr)) {
                    int i = 0;
                    while (bson_iter_next(&arr) && i < 100) {
                        if (BSON_ITER_HOLDS_DOUBLE(&arr)) out->telemetry.measurements[i++] = bson_iter_double(&arr);
                    }
                    out->telemetry.meas_count = i;
                }
            }
            return 0;
        }
        case TD_STRING_ARRAY: {
            bson_iter_t it;
            if (!bson_iter_init_find(&it, b, "Items") || !BSON_ITER_HOLDS_ARRAY(&it)) return -1;
            bson_iter_t arr;
            if (!bson_iter_recurse(&it, &arr)) return -1;
            int i = 0;
            while (bson_iter_next(&arr) && i < 100) {
                if (!BSON_ITER_HOLDS_UTF8(&arr)) continue;
                uint32_t len = 0; const char *s = bson_iter_utf8(&arr, &len);
                if (s && len < sizeof out->string_array.items[i]) {
                    memcpy(out->string_array.items[i], s, len); out->string_array.items[i][len] = 0;
                }
                i++;
            }
            out->string_array.count = i;
            return 0;
        }
        case TD_EDI835: {
            if (get_utf8(b, "PayerName", out->edi.payer_name, sizeof out->edi.payer_name)) return -1;
            get_utf8(b, "PayeeName", out->edi.payee_name, sizeof out->edi.payee_name);
            get_utf8(b, "PaymentDate", out->edi.payment_date, sizeof out->edi.payment_date);
            get_utf8(b, "TCN", out->edi.tcn, sizeof out->edi.tcn);
            get_f64(b, "TotalActual", &out->edi.total_actual);
            bson_iter_t it;
            if (bson_iter_init_find(&it, b, "Claims") && BSON_ITER_HOLDS_ARRAY(&it)) {
                bson_iter_t claims;
                if (bson_iter_recurse(&it, &claims)) {
                    int c = 0;
                    while (bson_iter_next(&claims) && c < 6) {
                        if (!BSON_ITER_HOLDS_DOCUMENT(&claims)) continue;
                        const uint8_t *data = NULL; uint32_t len = 0;
                        bson_iter_document(&claims, &len, &data);
                        bson_t co;
                        if (!data || !bson_init_static(&co, data, len)) continue;
                        claim_t *cl = &out->edi.claims[c];
                        get_utf8(&co, "ClaimId", cl->claim_id, sizeof cl->claim_id);
                        get_utf8(&co, "PatientName", cl->patient_name, sizeof cl->patient_name);
                        get_f64(&co, "TotalCharge", &cl->total_charge);
                        get_f64(&co, "Payment", &cl->payment);
                        bson_iter_t li;
                        if (bson_iter_init_find(&li, &co, "Lines") && BSON_ITER_HOLDS_ARRAY(&li)) {
                            bson_iter_t lines;
                            if (bson_iter_recurse(&li, &lines)) {
                                int L = 0;
                                while (bson_iter_next(&lines) && L < 4) {
                                    if (!BSON_ITER_HOLDS_DOCUMENT(&lines)) continue;
                                    const uint8_t *ld = NULL; uint32_t ll = 0;
                                    bson_iter_document(&lines, &ll, &ld);
                                    bson_t lo;
                                    if (!ld || !bson_init_static(&lo, ld, ll)) continue;
                                    get_utf8(&lo, "ServiceCode", cl->lines[L].service_code, sizeof cl->lines[L].service_code);
                                    get_f64(&lo, "Charge", &cl->lines[L].charge);
                                    get_f64(&lo, "Adjudicated", &cl->lines[L].adjudicated);
                                    L++;
                                }
                                cl->line_count = L;
                            }
                        }
                        c++;
                    }
                    out->edi.claim_count = c;
                }
            }
            return 0;
        }

        case TD_OBJECT_GRAPH: {
            get_i32(b, "root", &out->graph.root);
            bson_iter_t it;
            if (!bson_iter_init_find(&it, b, "nodes") || !BSON_ITER_HOLDS_ARRAY(&it)) return -1;
            bson_iter_t arr;
            if (!bson_iter_recurse(&it, &arr)) return -1;
            int i = 0;
            while (bson_iter_next(&arr) && i < GRAPH_MAX_NODES) {
                if (!BSON_ITER_HOLDS_DOCUMENT(&arr)) continue;
                const uint8_t *data = NULL; uint32_t len = 0;
                bson_iter_document(&arr, &len, &data);
                bson_t no;
                if (!data || !bson_init_static(&no, data, len)) continue;
                graph_node_t *n = &out->graph.nodes[i];
                get_utf8(&no, "Name", n->name, sizeof n->name);
                get_i32(&no, "Parent", &n->parent);
                get_i32(&no, "Related", &n->related);
                bson_iter_t li;
                if (bson_iter_init_find(&li, &no, "Children") && BSON_ITER_HOLDS_ARRAY(&li)) {
                    bson_iter_t ch;
                    if (bson_iter_recurse(&li, &ch)) {
                        int c = 0;
                        while (bson_iter_next(&ch) && c < GRAPH_MAX_CHILDREN) {
                            if (BSON_ITER_HOLDS_INT32(&ch)) n->children[c++] = bson_iter_int32(&ch);
                        }
                        n->child_count = c;
                    }
                }
                i++;
            }
            out->graph.node_count = i;
            return 0;
        }
        default: return -1;
    }
}

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    bson_t b = BSON_INITIALIZER;
    if (!append_fx(&b, fx)) { bson_destroy(&b); return -1; }
    if (b.len > cap) { bson_destroy(&b); return -1; }
    memcpy(buf, bson_get_data(&b), b.len);
    *ol = b.len;
    bson_destroy(&b);
    return 0;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    bson_t b;
    if (!bson_init_static(&b, buf, len)) return -1;
    return read_fx(&b, out, kind);
}

void bench_register_libbson(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "libbson", BSON_VERSION_S, "binary", prep, ser, de, fidelity_fx);
}
