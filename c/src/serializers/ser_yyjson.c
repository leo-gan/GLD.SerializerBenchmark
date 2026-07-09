#include "ser_common.h"
#include "yyjson.h"

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static yyjson_mut_doc *fx_to_doc(const test_fixture_t *fx) {
    yyjson_mut_doc *doc = yyjson_mut_doc_new(NULL);
    if (!doc) return NULL;
    yyjson_mut_val *root = yyjson_mut_obj(doc);
    yyjson_mut_doc_set_root(doc, root);
    yyjson_mut_obj_add_int(doc, root, "kind", (int64_t)fx->kind);
    switch (fx->kind) {
        case TD_INTEGER:
            yyjson_mut_obj_add_int(doc, root, "value", fx->integer_val);
            break;
        case TD_SIMPLE:
            yyjson_mut_obj_add_int(doc, root, "Id", fx->simple.id);
            yyjson_mut_obj_add_strcpy(doc, root, "Name", fx->simple.name);
            yyjson_mut_obj_add_strcpy(doc, root, "Timestamp", fx->simple.timestamp);
            yyjson_mut_obj_add_bool(doc, root, "IsActive", fx->simple.is_active);
            break;
        case TD_PERSON: {
            yyjson_mut_obj_add_strcpy(doc, root, "FirstName", fx->person.first_name);
            yyjson_mut_obj_add_strcpy(doc, root, "LastName", fx->person.last_name);
            yyjson_mut_obj_add_int(doc, root, "Age", fx->person.age);
            yyjson_mut_obj_add_int(doc, root, "Gender", fx->person.gender);
            yyjson_mut_val *pass = yyjson_mut_obj(doc);
            yyjson_mut_obj_add_strcpy(doc, pass, "Number", fx->person.passport_number);
            yyjson_mut_obj_add_strcpy(doc, pass, "Authority", fx->person.passport_authority);
            yyjson_mut_obj_add_val(doc, root, "Passport", pass);
            yyjson_mut_val *arr = yyjson_mut_arr(doc);
            int n = fx->person.police_count; if (n < 0) n = 0; if (n > 8) n = 8;
            for (int i = 0; i < n; i++) {
                yyjson_mut_val *rec = yyjson_mut_obj(doc);
                yyjson_mut_obj_add_int(doc, rec, "Id", fx->person.police_ids[i]);
                yyjson_mut_obj_add_strcpy(doc, rec, "CrimeCode", fx->person.police_codes[i]);
                yyjson_mut_arr_add_val(arr, rec);
            }
            yyjson_mut_obj_add_val(doc, root, "PoliceRecords", arr);
            break;
        }
        case TD_TELEMETRY: {
            yyjson_mut_obj_add_strcpy(doc, root, "Id", fx->telemetry.id);
            yyjson_mut_obj_add_strcpy(doc, root, "DataSource", fx->telemetry.data_source);
            yyjson_mut_obj_add_strcpy(doc, root, "TimeStamp", fx->telemetry.time_stamp);
            yyjson_mut_obj_add_int(doc, root, "Param1", fx->telemetry.param1);
            yyjson_mut_obj_add_int(doc, root, "Param2", fx->telemetry.param2);
            yyjson_mut_val *arr = yyjson_mut_arr(doc);
            int n = fx->telemetry.meas_count; if (n < 0) n = 0; if (n > 100) n = 100;
            for (int i = 0; i < n; i++) yyjson_mut_arr_add_real(doc, arr, fx->telemetry.measurements[i]);
            yyjson_mut_obj_add_val(doc, root, "Measurements", arr);
            yyjson_mut_obj_add_int(doc, root, "AssociatedProblemID", fx->telemetry.problem_id);
            yyjson_mut_obj_add_int(doc, root, "AssociatedLogID", fx->telemetry.log_id);
            yyjson_mut_obj_add_bool(doc, root, "WasProcessed", fx->telemetry.was_processed);
            break;
        }
        case TD_STRING_ARRAY: {
            yyjson_mut_obj_add_int(doc, root, "Count", fx->string_array.count);
            yyjson_mut_val *arr = yyjson_mut_arr(doc);
            for (int i = 0; i < fx->string_array.count && i < 100; i++)
                yyjson_mut_arr_add_strcpy(doc, arr, fx->string_array.items[i]);
            yyjson_mut_obj_add_val(doc, root, "Items", arr);
            break;
        }
        case TD_EDI835: {
            yyjson_mut_obj_add_strcpy(doc, root, "PayerName", fx->edi.payer_name);
            yyjson_mut_obj_add_strcpy(doc, root, "PayeeName", fx->edi.payee_name);
            yyjson_mut_obj_add_strcpy(doc, root, "PaymentDate", fx->edi.payment_date);
            yyjson_mut_obj_add_real(doc, root, "TotalActual", fx->edi.total_actual);
            yyjson_mut_obj_add_strcpy(doc, root, "TCN", fx->edi.tcn);
            yyjson_mut_val *claims = yyjson_mut_arr(doc);
            int nc = fx->edi.claim_count; if (nc < 0) nc = 0; if (nc > 6) nc = 6;
            for (int c = 0; c < nc; c++) {
                const claim_t *cl = &fx->edi.claims[c];
                yyjson_mut_val *co = yyjson_mut_obj(doc);
                yyjson_mut_obj_add_strcpy(doc, co, "ClaimId", cl->claim_id);
                yyjson_mut_obj_add_strcpy(doc, co, "PatientName", cl->patient_name);
                yyjson_mut_obj_add_real(doc, co, "TotalCharge", cl->total_charge);
                yyjson_mut_obj_add_real(doc, co, "Payment", cl->payment);
                yyjson_mut_val *lines = yyjson_mut_arr(doc);
                int nl = cl->line_count; if (nl < 0) nl = 0; if (nl > 4) nl = 4;
                for (int L = 0; L < nl; L++) {
                    yyjson_mut_val *lo = yyjson_mut_obj(doc);
                    yyjson_mut_obj_add_strcpy(doc, lo, "ServiceCode", cl->lines[L].service_code);
                    yyjson_mut_obj_add_real(doc, lo, "Charge", cl->lines[L].charge);
                    yyjson_mut_obj_add_real(doc, lo, "Adjudicated", cl->lines[L].adjudicated);
                    yyjson_mut_arr_add_val(lines, lo);
                }
                yyjson_mut_obj_add_val(doc, co, "Lines", lines);
                yyjson_mut_arr_add_val(claims, co);
            }
            yyjson_mut_obj_add_val(doc, root, "Claims", claims);
            break;
        }

        case TD_OBJECT_GRAPH: {
            const object_graph_t *g = &fx->graph;
            yyjson_mut_obj_add_int(doc, root, "root", g->root);
            yyjson_mut_val *nodes = yyjson_mut_arr(doc);
            int nn = g->node_count; if (nn < 0) nn = 0; if (nn > GRAPH_MAX_NODES) nn = GRAPH_MAX_NODES;
            for (int i = 0; i < nn; i++) {
                const graph_node_t *n = &g->nodes[i];
                yyjson_mut_val *no = yyjson_mut_obj(doc);
                yyjson_mut_obj_add_strcpy(doc, no, "Name", n->name);
                yyjson_mut_obj_add_int(doc, no, "Parent", n->parent);
                yyjson_mut_obj_add_int(doc, no, "Related", n->related);
                yyjson_mut_val *ch = yyjson_mut_arr(doc);
                int nc = n->child_count; if (nc < 0) nc = 0; if (nc > GRAPH_MAX_CHILDREN) nc = GRAPH_MAX_CHILDREN;
                for (int c = 0; c < nc; c++) yyjson_mut_arr_add_int(doc, ch, n->children[c]);
                yyjson_mut_obj_add_val(doc, no, "Children", ch);
                yyjson_mut_arr_add_val(nodes, no);
            }
            yyjson_mut_obj_add_val(doc, root, "nodes", nodes);
            break;
        }
        default:
            yyjson_mut_doc_free(doc);
            return NULL;
    }
    return doc;
}

static int doc_to_fx(yyjson_val *root, test_fixture_t *out, test_data_kind_t kind) {
    yyjson_val *kv = yyjson_obj_get(root, "kind");
    if (!yyjson_is_int(kv) || (int)yyjson_get_int(kv) != (int)kind) return -1;
    memset(out, 0, sizeof *out);
    out->kind = kind;
    out->name = test_data_name(kind);
    switch (kind) {
        case TD_INTEGER:
            out->integer_val = (int)yyjson_get_int(yyjson_obj_get(root, "value"));
            break;
        case TD_SIMPLE: {
            out->simple.id = (int)yyjson_get_int(yyjson_obj_get(root, "Id"));
            const char *n = yyjson_get_str(yyjson_obj_get(root, "Name"));
            const char *t = yyjson_get_str(yyjson_obj_get(root, "Timestamp"));
            if (!n) return -1;
            snprintf(out->simple.name, sizeof out->simple.name, "%s", n);
            if (t) snprintf(out->simple.timestamp, sizeof out->simple.timestamp, "%s", t);
            out->simple.is_active = yyjson_get_bool(yyjson_obj_get(root, "IsActive"));
            break;
        }
        case TD_PERSON: {
            const char *fn = yyjson_get_str(yyjson_obj_get(root, "FirstName"));
            const char *ln = yyjson_get_str(yyjson_obj_get(root, "LastName"));
            if (!fn || !ln) return -1;
            snprintf(out->person.first_name, sizeof out->person.first_name, "%s", fn);
            snprintf(out->person.last_name, sizeof out->person.last_name, "%s", ln);
            out->person.age = (int)yyjson_get_int(yyjson_obj_get(root, "Age"));
            out->person.gender = (int)yyjson_get_int(yyjson_obj_get(root, "Gender"));
            yyjson_val *pass = yyjson_obj_get(root, "Passport");
            if (pass) {
                const char *pn = yyjson_get_str(yyjson_obj_get(pass, "Number"));
                const char *pa = yyjson_get_str(yyjson_obj_get(pass, "Authority"));
                if (pn) snprintf(out->person.passport_number, sizeof out->person.passport_number, "%s", pn);
                if (pa) snprintf(out->person.passport_authority, sizeof out->person.passport_authority, "%s", pa);
            }
            yyjson_val *arr = yyjson_obj_get(root, "PoliceRecords");
            if (yyjson_is_arr(arr)) {
                size_t idx, max; yyjson_val *it;
                int i = 0;
                yyjson_arr_foreach(arr, idx, max, it) {
                    if (i >= 8) break;
                    out->person.police_ids[i] = (int)yyjson_get_int(yyjson_obj_get(it, "Id"));
                    const char *cc = yyjson_get_str(yyjson_obj_get(it, "CrimeCode"));
                    if (cc) snprintf(out->person.police_codes[i], sizeof out->person.police_codes[i], "%s", cc);
                    i++;
                }
                out->person.police_count = i;
            }
            break;
        }
        case TD_TELEMETRY: {
            const char *id = yyjson_get_str(yyjson_obj_get(root, "Id"));
            if (!id) return -1;
            snprintf(out->telemetry.id, sizeof out->telemetry.id, "%s", id);
            const char *ds = yyjson_get_str(yyjson_obj_get(root, "DataSource"));
            if (ds) snprintf(out->telemetry.data_source, sizeof out->telemetry.data_source, "%s", ds);
            const char *ts = yyjson_get_str(yyjson_obj_get(root, "TimeStamp"));
            if (ts) snprintf(out->telemetry.time_stamp, sizeof out->telemetry.time_stamp, "%s", ts);
            out->telemetry.param1 = (int)yyjson_get_int(yyjson_obj_get(root, "Param1"));
            out->telemetry.param2 = (int)yyjson_get_int(yyjson_obj_get(root, "Param2"));
            out->telemetry.problem_id = (int)yyjson_get_int(yyjson_obj_get(root, "AssociatedProblemID"));
            out->telemetry.log_id = (int)yyjson_get_int(yyjson_obj_get(root, "AssociatedLogID"));
            out->telemetry.was_processed = yyjson_get_bool(yyjson_obj_get(root, "WasProcessed"));
            yyjson_val *arr = yyjson_obj_get(root, "Measurements");
            if (yyjson_is_arr(arr)) {
                size_t idx, max; yyjson_val *it; int i = 0;
                yyjson_arr_foreach(arr, idx, max, it) {
                    if (i >= 100) break;
                    out->telemetry.measurements[i++] = yyjson_get_real(it);
                }
                out->telemetry.meas_count = i;
            }
            break;
        }
        case TD_STRING_ARRAY: {
            yyjson_val *arr = yyjson_obj_get(root, "Items");
            if (yyjson_is_arr(arr)) {
                size_t idx, max; yyjson_val *it; int i = 0;
                yyjson_arr_foreach(arr, idx, max, it) {
                    if (i >= 100) break;
                    const char *s = yyjson_get_str(it);
                    if (s) snprintf(out->string_array.items[i], sizeof out->string_array.items[i], "%s", s);
                    i++;
                }
                out->string_array.count = i;
            } else {
                out->string_array.count = (int)yyjson_get_int(yyjson_obj_get(root, "Count"));
            }
            break;
        }
        case TD_EDI835: {
            const char *p = yyjson_get_str(yyjson_obj_get(root, "PayerName"));
            const char *q = yyjson_get_str(yyjson_obj_get(root, "PayeeName"));
            if (!p) return -1;
            snprintf(out->edi.payer_name, sizeof out->edi.payer_name, "%s", p);
            if (q) snprintf(out->edi.payee_name, sizeof out->edi.payee_name, "%s", q);
            const char *pd = yyjson_get_str(yyjson_obj_get(root, "PaymentDate"));
            if (pd) snprintf(out->edi.payment_date, sizeof out->edi.payment_date, "%s", pd);
            const char *tcn = yyjson_get_str(yyjson_obj_get(root, "TCN"));
            if (tcn) snprintf(out->edi.tcn, sizeof out->edi.tcn, "%s", tcn);
            out->edi.total_actual = yyjson_get_real(yyjson_obj_get(root, "TotalActual"));
            yyjson_val *claims = yyjson_obj_get(root, "Claims");
            if (yyjson_is_arr(claims)) {
                size_t idx, max; yyjson_val *co; int c = 0;
                yyjson_arr_foreach(claims, idx, max, co) {
                    if (c >= 6) break;
                    claim_t *cl = &out->edi.claims[c];
                    const char *cid = yyjson_get_str(yyjson_obj_get(co, "ClaimId"));
                    const char *pn = yyjson_get_str(yyjson_obj_get(co, "PatientName"));
                    if (cid) snprintf(cl->claim_id, sizeof cl->claim_id, "%s", cid);
                    if (pn) snprintf(cl->patient_name, sizeof cl->patient_name, "%s", pn);
                    cl->total_charge = yyjson_get_real(yyjson_obj_get(co, "TotalCharge"));
                    cl->payment = yyjson_get_real(yyjson_obj_get(co, "Payment"));
                    yyjson_val *lines = yyjson_obj_get(co, "Lines");
                    int L = 0;
                    if (yyjson_is_arr(lines)) {
                        size_t i2, m2; yyjson_val *lo;
                        yyjson_arr_foreach(lines, i2, m2, lo) {
                            if (L >= 4) break;
                            const char *sc = yyjson_get_str(yyjson_obj_get(lo, "ServiceCode"));
                            if (sc) snprintf(cl->lines[L].service_code, sizeof cl->lines[L].service_code, "%s", sc);
                            cl->lines[L].charge = yyjson_get_real(yyjson_obj_get(lo, "Charge"));
                            cl->lines[L].adjudicated = yyjson_get_real(yyjson_obj_get(lo, "Adjudicated"));
                            L++;
                        }
                    }
                    cl->line_count = L;
                    c++;
                }
                out->edi.claim_count = c;
            }
            break;
        }

        case TD_OBJECT_GRAPH: {
            out->graph.root = (int)yyjson_get_int(yyjson_obj_get(root, "root"));
            yyjson_val *nodes = yyjson_obj_get(root, "nodes");
            if (!yyjson_is_arr(nodes)) return -1;
            size_t idx, max; yyjson_val *no; int i = 0;
            yyjson_arr_foreach(nodes, idx, max, no) {
                if (i >= GRAPH_MAX_NODES) break;
                graph_node_t *n = &out->graph.nodes[i];
                const char *nm = yyjson_get_str(yyjson_obj_get(no, "Name"));
                if (nm) snprintf(n->name, sizeof n->name, "%s", nm);
                n->parent = (int)yyjson_get_int(yyjson_obj_get(no, "Parent"));
                n->related = (int)yyjson_get_int(yyjson_obj_get(no, "Related"));
                yyjson_val *ch = yyjson_obj_get(no, "Children");
                int c = 0;
                if (yyjson_is_arr(ch)) {
                    size_t i2, m2; yyjson_val *ci;
                    yyjson_arr_foreach(ch, i2, m2, ci) {
                        if (c >= GRAPH_MAX_CHILDREN) break;
                        n->children[c++] = (int)yyjson_get_int(ci);
                    }
                }
                n->child_count = c;
                i++;
            }
            out->graph.node_count = i;
            break;
        }
        default: return -1;
    }
    return 0;
}

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    /* Optimal path: build mut doc, write minified JSON (flag 0 = YYJSON_WRITE_NOFLAG).
     * yyjson has no write-into-external-buffer API; mut_write is the recommended export. */
    yyjson_mut_doc *doc = fx_to_doc(fx);
    if (!doc) return -1;
    size_t len = 0;
    char *s = yyjson_mut_write(doc, YYJSON_WRITE_NOFLAG, &len);
    yyjson_mut_doc_free(doc);
    if (!s) return -1;
    if (len > cap) { free(s); return -1; }
    memcpy(buf, s, len);
    *ol = len;
    free(s);
    return 0;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    /* Optimal: yyjson_read on the raw buffer (no copy); INSITU would mutate input. */
    yyjson_doc *doc = yyjson_read((const char *)buf, len, YYJSON_READ_NOFLAG);
    if (!doc) return -1;
    int rc = doc_to_fx(yyjson_doc_get_root(doc), out, kind);
    yyjson_doc_free(doc);
    return rc;
}

void bench_register_yyjson(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "yyjson", YYJSON_VERSION_STRING, "json", prep, ser, de, fidelity_fx);
}
