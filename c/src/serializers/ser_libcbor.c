#include "ser_common.h"
#include "../../../third_party/libcbor/src/cbor.h"

/*
 * Optimal libcbor usage:
 *  - Build definite maps/arrays with cbor_new_* / cbor_map_add
 *  - cbor_serialize into caller buffer (not cbor_serialize_alloc)
 *  - cbor_load for decode
 */

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static cbor_item_t *str_item(const char *s) {
    return cbor_build_string(s ? s : "");
}
static cbor_item_t *int_item(int64_t v) {
    if (v >= 0) return cbor_build_uint64((uint64_t)v);
    return cbor_build_negint64((uint64_t)(-1 - v));
}
static bool map_add_str(cbor_item_t *m, const char *k, const char *v) {
    return cbor_map_add(m, (struct cbor_pair){ .key = cbor_move(str_item(k)), .value = cbor_move(str_item(v)) });
}
static bool map_add_int(cbor_item_t *m, const char *k, int64_t v) {
    return cbor_map_add(m, (struct cbor_pair){ .key = cbor_move(str_item(k)), .value = cbor_move(int_item(v)) });
}
static bool map_add_bool(cbor_item_t *m, const char *k, bool v) {
    return cbor_map_add(m, (struct cbor_pair){ .key = cbor_move(str_item(k)), .value = cbor_move(cbor_build_bool(v)) });
}
static bool map_add_f64(cbor_item_t *m, const char *k, double v) {
    return cbor_map_add(m, (struct cbor_pair){ .key = cbor_move(str_item(k)), .value = cbor_move(cbor_build_float8(v)) });
}
static bool map_add_item(cbor_item_t *m, const char *k, cbor_item_t *v) {
    return cbor_map_add(m, (struct cbor_pair){ .key = cbor_move(str_item(k)), .value = cbor_move(v) });
}

static cbor_item_t *fx_to_item(const test_fixture_t *fx) {
    cbor_item_t *root = NULL;
    switch (fx->kind) {
        case TD_INTEGER:
            root = cbor_new_definite_map(2);
            if (!root) return NULL;
            map_add_int(root, "kind", (int64_t)fx->kind);
            map_add_int(root, "value", fx->integer_val);
            return root;
        case TD_SIMPLE:
            root = cbor_new_definite_map(5);
            if (!root) return NULL;
            map_add_int(root, "kind", (int64_t)fx->kind);
            map_add_int(root, "Id", fx->simple.id);
            map_add_str(root, "Name", fx->simple.name);
            map_add_str(root, "Timestamp", fx->simple.timestamp);
            map_add_bool(root, "IsActive", fx->simple.is_active);
            return root;
        case TD_PERSON: {
            const person_t *p = &fx->person;
            int n = p->police_count; if (n < 0) n = 0; if (n > 8) n = 8;
            root = cbor_new_definite_map(7);
            if (!root) return NULL;
            map_add_int(root, "kind", (int64_t)fx->kind);
            map_add_str(root, "FirstName", p->first_name);
            map_add_str(root, "LastName", p->last_name);
            map_add_int(root, "Age", p->age);
            map_add_int(root, "Gender", p->gender);
            cbor_item_t *pass = cbor_new_definite_map(2);
            map_add_str(pass, "Number", p->passport_number);
            map_add_str(pass, "Authority", p->passport_authority);
            map_add_item(root, "Passport", pass);
            cbor_item_t *arr = cbor_new_definite_array((size_t)n);
            for (int i = 0; i < n; i++) {
                cbor_item_t *rec = cbor_new_definite_map(2);
                map_add_int(rec, "Id", p->police_ids[i]);
                map_add_str(rec, "CrimeCode", p->police_codes[i]);
                cbor_array_push(arr, cbor_move(rec));
            }
            map_add_item(root, "PoliceRecords", arr);
            return root;
        }
        case TD_TELEMETRY: {
            const telemetry_t *t = &fx->telemetry;
            int n = t->meas_count; if (n < 0) n = 0; if (n > 100) n = 100;
            root = cbor_new_definite_map(10);
            if (!root) return NULL;
            map_add_int(root, "kind", (int64_t)fx->kind);
            map_add_str(root, "Id", t->id);
            map_add_str(root, "DataSource", t->data_source);
            map_add_str(root, "TimeStamp", t->time_stamp);
            map_add_int(root, "Param1", t->param1);
            map_add_int(root, "Param2", t->param2);
            cbor_item_t *arr = cbor_new_definite_array((size_t)n);
            for (int i = 0; i < n; i++) cbor_array_push(arr, cbor_move(cbor_build_float8(t->measurements[i])));
            map_add_item(root, "Measurements", arr);
            map_add_int(root, "AssociatedProblemID", t->problem_id);
            map_add_int(root, "AssociatedLogID", t->log_id);
            map_add_bool(root, "WasProcessed", t->was_processed);
            return root;
        }
        case TD_STRING_ARRAY: {
            int n = fx->string_array.count; if (n < 0) n = 0; if (n > 100) n = 100;
            root = cbor_new_definite_map(3);
            if (!root) return NULL;
            map_add_int(root, "kind", (int64_t)fx->kind);
            map_add_int(root, "Count", n);
            cbor_item_t *arr = cbor_new_definite_array((size_t)n);
            for (int i = 0; i < n; i++) cbor_array_push(arr, cbor_move(str_item(fx->string_array.items[i])));
            map_add_item(root, "Items", arr);
            return root;
        }
        case TD_EDI835: {
            const edi835_t *e = &fx->edi;
            int nc = e->claim_count; if (nc < 0) nc = 0; if (nc > 6) nc = 6;
            root = cbor_new_definite_map(7);
            if (!root) return NULL;
            map_add_int(root, "kind", (int64_t)fx->kind);
            map_add_str(root, "PayerName", e->payer_name);
            map_add_str(root, "PayeeName", e->payee_name);
            map_add_str(root, "PaymentDate", e->payment_date);
            map_add_f64(root, "TotalActual", e->total_actual);
            map_add_str(root, "TCN", e->tcn);
            cbor_item_t *claims = cbor_new_definite_array((size_t)nc);
            for (int c = 0; c < nc; c++) {
                const claim_t *cl = &e->claims[c];
                int nl = cl->line_count; if (nl < 0) nl = 0; if (nl > 4) nl = 4;
                cbor_item_t *co = cbor_new_definite_map(5);
                map_add_str(co, "ClaimId", cl->claim_id);
                map_add_str(co, "PatientName", cl->patient_name);
                map_add_f64(co, "TotalCharge", cl->total_charge);
                map_add_f64(co, "Payment", cl->payment);
                cbor_item_t *lines = cbor_new_definite_array((size_t)nl);
                for (int L = 0; L < nl; L++) {
                    cbor_item_t *lo = cbor_new_definite_map(3);
                    map_add_str(lo, "ServiceCode", cl->lines[L].service_code);
                    map_add_f64(lo, "Charge", cl->lines[L].charge);
                    map_add_f64(lo, "Adjudicated", cl->lines[L].adjudicated);
                    cbor_array_push(lines, cbor_move(lo));
                }
                map_add_item(co, "Lines", lines);
                cbor_array_push(claims, cbor_move(co));
            }
            map_add_item(root, "Claims", claims);
            return root;
        }

        case TD_OBJECT_GRAPH: {
            const object_graph_t *g = &fx->graph;
            int nn = g->node_count; if (nn < 0) nn = 0; if (nn > GRAPH_MAX_NODES) nn = GRAPH_MAX_NODES;
            root = cbor_new_definite_map(3);
            if (!root) return NULL;
            map_add_int(root, "kind", (int64_t)fx->kind);
            map_add_int(root, "root", g->root);
            cbor_item_t *nodes = cbor_new_definite_array((size_t)nn);
            for (int i = 0; i < nn; i++) {
                const graph_node_t *n = &g->nodes[i];
                int nc = n->child_count; if (nc < 0) nc = 0; if (nc > GRAPH_MAX_CHILDREN) nc = GRAPH_MAX_CHILDREN;
                cbor_item_t *no = cbor_new_definite_map(4);
                map_add_str(no, "Name", n->name);
                map_add_int(no, "Parent", n->parent);
                map_add_int(no, "Related", n->related);
                cbor_item_t *ch = cbor_new_definite_array((size_t)nc);
                for (int c = 0; c < nc; c++) cbor_array_push(ch, cbor_move(int_item(n->children[c])));
                map_add_item(no, "Children", ch);
                cbor_array_push(nodes, cbor_move(no));
            }
            map_add_item(root, "nodes", nodes);
            return root;
        }
        default: return NULL;
    }
}

static cbor_item_t *map_get(cbor_item_t *map, const char *key) {
    size_t n = cbor_map_size(map);
    struct cbor_pair *pairs = cbor_map_handle(map);
    size_t kl = strlen(key);
    for (size_t i = 0; i < n; i++) {
        if (!cbor_isa_string(pairs[i].key)) continue;
        if (cbor_string_length(pairs[i].key) == kl &&
            memcmp(cbor_string_handle(pairs[i].key), key, kl) == 0)
            return pairs[i].value;
    }
    return NULL;
}
static int item_int(cbor_item_t *it, int *out) {
    if (!it) return -1;
    if (cbor_isa_uint(it)) { *out = (int)cbor_get_uint64(it); return 0; }
    if (cbor_isa_negint(it)) { *out = (int)(-1 - (int64_t)cbor_get_uint64(it)); return 0; }
    return -1;
}
static int item_str(cbor_item_t *it, char *dst, size_t dstsz) {
    if (!it || !cbor_isa_string(it)) return -1;
    size_t n = cbor_string_length(it);
    if (n >= dstsz) return -1;
    memcpy(dst, cbor_string_handle(it), n); dst[n] = 0; return 0;
}
static double item_f64(cbor_item_t *it) {
    if (!it) return 0;
    if (cbor_is_float(it)) return cbor_float_get_float(it);
    return 0;
}

static int item_to_fx(cbor_item_t *root, test_fixture_t *out, test_data_kind_t kind) {
    if (!root || !cbor_isa_map(root)) return -1;
    int k = -1;
    if (item_int(map_get(root, "kind"), &k) || k != (int)kind) return -1;
    memset(out, 0, sizeof *out);
    out->kind = kind;
    out->name = test_data_name(kind);
    switch (kind) {
        case TD_INTEGER:
            return item_int(map_get(root, "value"), &out->integer_val);
        case TD_SIMPLE:
            if (item_int(map_get(root, "Id"), &out->simple.id)) return -1;
            if (item_str(map_get(root, "Name"), out->simple.name, sizeof out->simple.name)) return -1;
            item_str(map_get(root, "Timestamp"), out->simple.timestamp, sizeof out->simple.timestamp);
            {
                cbor_item_t *b = map_get(root, "IsActive");
                out->simple.is_active = b && cbor_isa_float_ctrl(b) && cbor_get_bool(b);
            }
            return 0;
        case TD_PERSON: {
            if (item_str(map_get(root, "FirstName"), out->person.first_name, sizeof out->person.first_name)) return -1;
            if (item_str(map_get(root, "LastName"), out->person.last_name, sizeof out->person.last_name)) return -1;
            item_int(map_get(root, "Age"), &out->person.age);
            item_int(map_get(root, "Gender"), &out->person.gender);
            cbor_item_t *pass = map_get(root, "Passport");
            if (pass && cbor_isa_map(pass)) {
                item_str(map_get(pass, "Number"), out->person.passport_number, sizeof out->person.passport_number);
                item_str(map_get(pass, "Authority"), out->person.passport_authority, sizeof out->person.passport_authority);
            }
            cbor_item_t *arr = map_get(root, "PoliceRecords");
            if (arr && cbor_isa_array(arr)) {
                size_t n = cbor_array_size(arr); if (n > 8) n = 8;
                out->person.police_count = (int)n;
                for (size_t i = 0; i < n; i++) {
                    cbor_item_t *rec = cbor_array_get(arr, i);
                    if (!rec || !cbor_isa_map(rec)) continue;
                    item_int(map_get(rec, "Id"), &out->person.police_ids[i]);
                    item_str(map_get(rec, "CrimeCode"), out->person.police_codes[i], sizeof out->person.police_codes[i]);
                }
            }
            return 0;
        }
        case TD_TELEMETRY: {
            if (item_str(map_get(root, "Id"), out->telemetry.id, sizeof out->telemetry.id)) return -1;
            item_str(map_get(root, "DataSource"), out->telemetry.data_source, sizeof out->telemetry.data_source);
            item_str(map_get(root, "TimeStamp"), out->telemetry.time_stamp, sizeof out->telemetry.time_stamp);
            item_int(map_get(root, "Param1"), &out->telemetry.param1);
            item_int(map_get(root, "Param2"), &out->telemetry.param2);
            item_int(map_get(root, "AssociatedProblemID"), &out->telemetry.problem_id);
            item_int(map_get(root, "AssociatedLogID"), &out->telemetry.log_id);
            {
                cbor_item_t *b = map_get(root, "WasProcessed");
                out->telemetry.was_processed = b && cbor_isa_float_ctrl(b) && cbor_get_bool(b);
            }
            cbor_item_t *arr = map_get(root, "Measurements");
            if (arr && cbor_isa_array(arr)) {
                size_t n = cbor_array_size(arr); if (n > 100) n = 100;
                out->telemetry.meas_count = (int)n;
                for (size_t i = 0; i < n; i++) out->telemetry.measurements[i] = item_f64(cbor_array_get(arr, i));
            }
            return 0;
        }
        case TD_STRING_ARRAY: {
            cbor_item_t *arr = map_get(root, "Items");
            if (!arr || !cbor_isa_array(arr)) return -1;
            size_t n = cbor_array_size(arr); if (n > 100) n = 100;
            out->string_array.count = (int)n;
            for (size_t i = 0; i < n; i++)
                if (item_str(cbor_array_get(arr, i), out->string_array.items[i], sizeof out->string_array.items[i])) return -1;
            return 0;
        }
        case TD_EDI835: {
            if (item_str(map_get(root, "PayerName"), out->edi.payer_name, sizeof out->edi.payer_name)) return -1;
            item_str(map_get(root, "PayeeName"), out->edi.payee_name, sizeof out->edi.payee_name);
            item_str(map_get(root, "PaymentDate"), out->edi.payment_date, sizeof out->edi.payment_date);
            item_str(map_get(root, "TCN"), out->edi.tcn, sizeof out->edi.tcn);
            out->edi.total_actual = item_f64(map_get(root, "TotalActual"));
            cbor_item_t *claims = map_get(root, "Claims");
            if (claims && cbor_isa_array(claims)) {
                size_t nc = cbor_array_size(claims); if (nc > 6) nc = 6;
                out->edi.claim_count = (int)nc;
                for (size_t c = 0; c < nc; c++) {
                    cbor_item_t *co = cbor_array_get(claims, c);
                    if (!co || !cbor_isa_map(co)) continue;
                    claim_t *cl = &out->edi.claims[c];
                    item_str(map_get(co, "ClaimId"), cl->claim_id, sizeof cl->claim_id);
                    item_str(map_get(co, "PatientName"), cl->patient_name, sizeof cl->patient_name);
                    cl->total_charge = item_f64(map_get(co, "TotalCharge"));
                    cl->payment = item_f64(map_get(co, "Payment"));
                    cbor_item_t *lines = map_get(co, "Lines");
                    if (lines && cbor_isa_array(lines)) {
                        size_t nl = cbor_array_size(lines); if (nl > 4) nl = 4;
                        cl->line_count = (int)nl;
                        for (size_t L = 0; L < nl; L++) {
                            cbor_item_t *lo = cbor_array_get(lines, L);
                            if (!lo || !cbor_isa_map(lo)) continue;
                            item_str(map_get(lo, "ServiceCode"), cl->lines[L].service_code, sizeof cl->lines[L].service_code);
                            cl->lines[L].charge = item_f64(map_get(lo, "Charge"));
                            cl->lines[L].adjudicated = item_f64(map_get(lo, "Adjudicated"));
                        }
                    }
                }
            }
            return 0;
        }

        case TD_OBJECT_GRAPH: {
            item_int(map_get(root, "root"), &out->graph.root);
            cbor_item_t *nodes = map_get(root, "nodes");
            if (!nodes || !cbor_isa_array(nodes)) return -1;
            size_t nn = cbor_array_size(nodes); if (nn > GRAPH_MAX_NODES) nn = GRAPH_MAX_NODES;
            out->graph.node_count = (int)nn;
            for (size_t i = 0; i < nn; i++) {
                cbor_item_t *no = cbor_array_get(nodes, i);
                if (!no || !cbor_isa_map(no)) continue;
                graph_node_t *n = &out->graph.nodes[i];
                item_str(map_get(no, "Name"), n->name, sizeof n->name);
                item_int(map_get(no, "Parent"), &n->parent);
                item_int(map_get(no, "Related"), &n->related);
                cbor_item_t *ch = map_get(no, "Children");
                if (ch && cbor_isa_array(ch)) {
                    size_t nc = cbor_array_size(ch); if (nc > GRAPH_MAX_CHILDREN) nc = GRAPH_MAX_CHILDREN;
                    n->child_count = (int)nc;
                    for (size_t c = 0; c < nc; c++) item_int(cbor_array_get(ch, c), &n->children[c]);
                }
            }
            return 0;
        }
        default: return -1;
    }
}

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    cbor_item_t *item = fx_to_item(fx);
    if (!item) return -1;
    size_t len = cbor_serialize(item, buf, cap);
    cbor_decref(&item);
    if (len == 0) return -1;
    *ol = len;
    return 0;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    struct cbor_load_result res;
    cbor_item_t *item = cbor_load(buf, len, &res);
    if (!item) return -1;
    int rc = item_to_fx(item, out, kind);
    cbor_decref(&item);
    return rc;
}

void bench_register_libcbor(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "cbor-encode", "0.11.0", "binary", prep, ser, de, fidelity_fx);
}
