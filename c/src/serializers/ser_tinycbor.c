#include "ser_common.h"
#include "tinycbor_pref.h"

/*
 * Optimal tinycbor usage (Intel tinycbor):
 *  - cbor_encoder_init into caller buffer
 *  - cbor_encode_* structured maps/arrays (not opaque byte payload of custom-binary)
 *  - cbor_parser_init + value enter/iterate for decode
 */

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static CborError enc_text(CborEncoder *e, const char *s) {
    return cbor_encode_text_stringz(e, s);
}
static CborError enc_kv_text(CborEncoder *map, const char *k, const char *v) {
    CborError err = enc_text(map, k); if (err) return err;
    return enc_text(map, v);
}
static CborError enc_kv_int(CborEncoder *map, const char *k, int64_t v) {
    CborError err = enc_text(map, k); if (err) return err;
    return cbor_encode_int(map, v);
}
static CborError enc_kv_bool(CborEncoder *map, const char *k, bool v) {
    CborError err = enc_text(map, k); if (err) return err;
    return cbor_encode_boolean(map, v);
}
static CborError enc_kv_double(CborEncoder *map, const char *k, double v) {
    CborError err = enc_text(map, k); if (err) return err;
    return cbor_encode_double(map, v);
}

static CborError write_fx(CborEncoder *enc, const test_fixture_t *fx) {
    CborEncoder map;
    CborError err;
    switch (fx->kind) {
        case TD_INTEGER:
            err = cbor_encoder_create_map(enc, &map, 2); if (err) return err;
            err = enc_kv_int(&map, "kind", (int64_t)fx->kind); if (err) return err;
            err = enc_kv_int(&map, "value", fx->integer_val); if (err) return err;
            return cbor_encoder_close_container(enc, &map);
        case TD_SIMPLE:
            err = cbor_encoder_create_map(enc, &map, 5); if (err) return err;
            err = enc_kv_int(&map, "kind", (int64_t)fx->kind); if (err) return err;
            err = enc_kv_int(&map, "Id", fx->simple.id); if (err) return err;
            err = enc_kv_text(&map, "Name", fx->simple.name); if (err) return err;
            err = enc_kv_text(&map, "Timestamp", fx->simple.timestamp); if (err) return err;
            err = enc_kv_bool(&map, "IsActive", fx->simple.is_active); if (err) return err;
            return cbor_encoder_close_container(enc, &map);
        case TD_PERSON: {
            const person_t *p = &fx->person;
            int n = p->police_count; if (n < 0) n = 0; if (n > 8) n = 8;
            err = cbor_encoder_create_map(enc, &map, 7); if (err) return err;
            err = enc_kv_int(&map, "kind", (int64_t)fx->kind); if (err) return err;
            err = enc_kv_text(&map, "FirstName", p->first_name); if (err) return err;
            err = enc_kv_text(&map, "LastName", p->last_name); if (err) return err;
            err = enc_kv_int(&map, "Age", p->age); if (err) return err;
            err = enc_kv_int(&map, "Gender", p->gender); if (err) return err;
            err = enc_text(&map, "Passport"); if (err) return err;
            {
                CborEncoder pass;
                err = cbor_encoder_create_map(&map, &pass, 2); if (err) return err;
                err = enc_kv_text(&pass, "Number", p->passport_number); if (err) return err;
                err = enc_kv_text(&pass, "Authority", p->passport_authority); if (err) return err;
                err = cbor_encoder_close_container(&map, &pass); if (err) return err;
            }
            err = enc_text(&map, "PoliceRecords"); if (err) return err;
            {
                CborEncoder arr;
                err = cbor_encoder_create_array(&map, &arr, (size_t)n); if (err) return err;
                for (int i = 0; i < n; i++) {
                    CborEncoder rec;
                    err = cbor_encoder_create_map(&arr, &rec, 2); if (err) return err;
                    err = enc_kv_int(&rec, "Id", p->police_ids[i]); if (err) return err;
                    err = enc_kv_text(&rec, "CrimeCode", p->police_codes[i]); if (err) return err;
                    err = cbor_encoder_close_container(&arr, &rec); if (err) return err;
                }
                err = cbor_encoder_close_container(&map, &arr); if (err) return err;
            }
            return cbor_encoder_close_container(enc, &map);
        }
        case TD_TELEMETRY: {
            const telemetry_t *t = &fx->telemetry;
            int n = t->meas_count; if (n < 0) n = 0; if (n > 100) n = 100;
            err = cbor_encoder_create_map(enc, &map, 10); if (err) return err;
            err = enc_kv_int(&map, "kind", (int64_t)fx->kind); if (err) return err;
            err = enc_kv_text(&map, "Id", t->id); if (err) return err;
            err = enc_kv_text(&map, "DataSource", t->data_source); if (err) return err;
            err = enc_kv_text(&map, "TimeStamp", t->time_stamp); if (err) return err;
            err = enc_kv_int(&map, "Param1", t->param1); if (err) return err;
            err = enc_kv_int(&map, "Param2", t->param2); if (err) return err;
            err = enc_text(&map, "Measurements"); if (err) return err;
            {
                CborEncoder arr;
                err = cbor_encoder_create_array(&map, &arr, (size_t)n); if (err) return err;
                for (int i = 0; i < n; i++) {
                    err = cbor_encode_double(&arr, t->measurements[i]); if (err) return err;
                }
                err = cbor_encoder_close_container(&map, &arr); if (err) return err;
            }
            err = enc_kv_int(&map, "AssociatedProblemID", t->problem_id); if (err) return err;
            err = enc_kv_int(&map, "AssociatedLogID", t->log_id); if (err) return err;
            err = enc_kv_bool(&map, "WasProcessed", t->was_processed); if (err) return err;
            return cbor_encoder_close_container(enc, &map);
        }
        case TD_STRING_ARRAY: {
            int n = fx->string_array.count; if (n < 0) n = 0; if (n > 100) n = 100;
            err = cbor_encoder_create_map(enc, &map, 3); if (err) return err;
            err = enc_kv_int(&map, "kind", (int64_t)fx->kind); if (err) return err;
            err = enc_kv_int(&map, "Count", n); if (err) return err;
            err = enc_text(&map, "Items"); if (err) return err;
            {
                CborEncoder arr;
                err = cbor_encoder_create_array(&map, &arr, (size_t)n); if (err) return err;
                for (int i = 0; i < n; i++) {
                    err = enc_text(&arr, fx->string_array.items[i]); if (err) return err;
                }
                err = cbor_encoder_close_container(&map, &arr); if (err) return err;
            }
            return cbor_encoder_close_container(enc, &map);
        }
        case TD_EDI835: {
            const edi835_t *e = &fx->edi;
            int nc = e->claim_count; if (nc < 0) nc = 0; if (nc > 6) nc = 6;
            err = cbor_encoder_create_map(enc, &map, 7); if (err) return err;
            err = enc_kv_int(&map, "kind", (int64_t)fx->kind); if (err) return err;
            err = enc_kv_text(&map, "PayerName", e->payer_name); if (err) return err;
            err = enc_kv_text(&map, "PayeeName", e->payee_name); if (err) return err;
            err = enc_kv_text(&map, "PaymentDate", e->payment_date); if (err) return err;
            err = enc_kv_double(&map, "TotalActual", e->total_actual); if (err) return err;
            err = enc_kv_text(&map, "TCN", e->tcn); if (err) return err;
            err = enc_text(&map, "Claims"); if (err) return err;
            {
                CborEncoder claims;
                err = cbor_encoder_create_array(&map, &claims, (size_t)nc); if (err) return err;
                for (int c = 0; c < nc; c++) {
                    const claim_t *cl = &e->claims[c];
                    int nl = cl->line_count; if (nl < 0) nl = 0; if (nl > 4) nl = 4;
                    CborEncoder co;
                    err = cbor_encoder_create_map(&claims, &co, 5); if (err) return err;
                    err = enc_kv_text(&co, "ClaimId", cl->claim_id); if (err) return err;
                    err = enc_kv_text(&co, "PatientName", cl->patient_name); if (err) return err;
                    err = enc_kv_double(&co, "TotalCharge", cl->total_charge); if (err) return err;
                    err = enc_kv_double(&co, "Payment", cl->payment); if (err) return err;
                    err = enc_text(&co, "Lines"); if (err) return err;
                    {
                        CborEncoder lines;
                        err = cbor_encoder_create_array(&co, &lines, (size_t)nl); if (err) return err;
                        for (int L = 0; L < nl; L++) {
                            CborEncoder lo;
                            err = cbor_encoder_create_map(&lines, &lo, 3); if (err) return err;
                            err = enc_kv_text(&lo, "ServiceCode", cl->lines[L].service_code); if (err) return err;
                            err = enc_kv_double(&lo, "Charge", cl->lines[L].charge); if (err) return err;
                            err = enc_kv_double(&lo, "Adjudicated", cl->lines[L].adjudicated); if (err) return err;
                            err = cbor_encoder_close_container(&lines, &lo); if (err) return err;
                        }
                        err = cbor_encoder_close_container(&co, &lines); if (err) return err;
                    }
                    err = cbor_encoder_close_container(&claims, &co); if (err) return err;
                }
                err = cbor_encoder_close_container(&map, &claims); if (err) return err;
            }
            return cbor_encoder_close_container(enc, &map);
        }

        case TD_OBJECT_GRAPH: {
            const object_graph_t *g = &fx->graph;
            int nn = g->node_count; if (nn < 0) nn = 0; if (nn > GRAPH_MAX_NODES) nn = GRAPH_MAX_NODES;
            err = cbor_encoder_create_map(enc, &map, 3); if (err) return err;
            err = enc_kv_int(&map, "kind", (int64_t)fx->kind); if (err) return err;
            err = enc_kv_int(&map, "root", g->root); if (err) return err;
            err = enc_text(&map, "nodes"); if (err) return err;
            {
                CborEncoder arr;
                err = cbor_encoder_create_array(&map, &arr, (size_t)nn); if (err) return err;
                for (int i = 0; i < nn; i++) {
                    const graph_node_t *n = &g->nodes[i];
                    int nc = n->child_count; if (nc < 0) nc = 0; if (nc > GRAPH_MAX_CHILDREN) nc = GRAPH_MAX_CHILDREN;
                    CborEncoder no;
                    err = cbor_encoder_create_map(&arr, &no, 4); if (err) return err;
                    err = enc_kv_text(&no, "Name", n->name); if (err) return err;
                    err = enc_kv_int(&no, "Parent", n->parent); if (err) return err;
                    err = enc_kv_int(&no, "Related", n->related); if (err) return err;
                    err = enc_text(&no, "Children"); if (err) return err;
                    {
                        CborEncoder ch;
                        err = cbor_encoder_create_array(&no, &ch, (size_t)nc); if (err) return err;
                        for (int c = 0; c < nc; c++) {
                            err = cbor_encode_int(&ch, n->children[c]); if (err) return err;
                        }
                        err = cbor_encoder_close_container(&no, &ch); if (err) return err;
                    }
                    err = cbor_encoder_close_container(&arr, &no); if (err) return err;
                }
                err = cbor_encoder_close_container(&map, &arr); if (err) return err;
            }
            return cbor_encoder_close_container(enc, &map);
        }
        default: return CborErrorImproperValue;
    }
}

/* Decode via re-serialize is hard; walk map keys into a temp structure using recursive value advance.
 * For robustness we convert CBOR->walk with a simple key copy approach using cbor_value_map_find_value where available.
 * tinycbor has cbor_value_map_find_value in recent versions. */
static int copy_text(CborValue *v, char *dst, size_t dstsz) {
    if (!cbor_value_is_text_string(v)) return -1;
    size_t n = dstsz;
    if (cbor_value_copy_text_string(v, dst, &n, v) != CborNoError) return -1;
    return 0;
}
static int get_int(CborValue *v, int *out) {
    int64_t x;
    if (cbor_value_get_int64(v, &x) != CborNoError) return -1;
    *out = (int)x;
    if (cbor_value_advance_fixed(v) != CborNoError) return -1;
    return 0;
}
static int find_enter(CborValue *map, const char *key, CborValue *out) {
    return cbor_value_map_find_value(map, key, out) == CborNoError && cbor_value_is_valid(out) ? 0 : -1;
}

static int read_fx(CborValue *root, test_fixture_t *out, test_data_kind_t kind) {
    if (!cbor_value_is_map(root)) return -1;
    CborValue map;
    if (cbor_value_enter_container(root, &map) != CborNoError) return -1;
    /* We need random access: re-enter from root each find. */
    CborValue rmap = *root;
    CborValue it;
    int k = -1;
    if (find_enter(&rmap, "kind", &it) || get_int(&it, &k) || k != (int)kind) return -1;
    memset(out, 0, sizeof *out);
    out->kind = kind;
    out->name = test_data_name(kind);
    switch (kind) {
        case TD_INTEGER:
            if (find_enter(&rmap, "value", &it) || get_int(&it, &out->integer_val)) return -1;
            break;
        case TD_SIMPLE:
            if (find_enter(&rmap, "Id", &it) || get_int(&it, &out->simple.id)) return -1;
            if (find_enter(&rmap, "Name", &it) || copy_text(&it, out->simple.name, sizeof out->simple.name)) return -1;
            if (find_enter(&rmap, "Timestamp", &it) == 0) copy_text(&it, out->simple.timestamp, sizeof out->simple.timestamp);
            if (find_enter(&rmap, "IsActive", &it) == 0) {
                bool b = false; cbor_value_get_boolean(&it, &b); out->simple.is_active = b;
            }
            break;
        case TD_PERSON: {
            if (find_enter(&rmap, "FirstName", &it) || copy_text(&it, out->person.first_name, sizeof out->person.first_name)) return -1;
            if (find_enter(&rmap, "LastName", &it) || copy_text(&it, out->person.last_name, sizeof out->person.last_name)) return -1;
            if (find_enter(&rmap, "Age", &it) == 0) get_int(&it, &out->person.age);
            if (find_enter(&rmap, "Gender", &it) == 0) get_int(&it, &out->person.gender);
            if (find_enter(&rmap, "Passport", &it) == 0 && cbor_value_is_map(&it)) {
                CborValue pass = it, f;
                if (find_enter(&pass, "Number", &f) == 0) copy_text(&f, out->person.passport_number, sizeof out->person.passport_number);
                if (find_enter(&pass, "Authority", &f) == 0) copy_text(&f, out->person.passport_authority, sizeof out->person.passport_authority);
            }
            if (find_enter(&rmap, "PoliceRecords", &it) == 0 && cbor_value_is_array(&it)) {
                CborValue arr;
                if (cbor_value_enter_container(&it, &arr) != CborNoError) return -1;
                int i = 0;
                while (!cbor_value_at_end(&arr) && i < 8) {
                    if (!cbor_value_is_map(&arr)) return -1;
                    CborValue rec = arr, f;
                    if (find_enter(&rec, "Id", &f) == 0) get_int(&f, &out->person.police_ids[i]);
                    if (find_enter(&rec, "CrimeCode", &f) == 0) copy_text(&f, out->person.police_codes[i], sizeof out->person.police_codes[i]);
                    if (cbor_value_advance(&arr) != CborNoError) return -1;
                    i++;
                }
                out->person.police_count = i;
            }
            break;
        }
        case TD_TELEMETRY: {
            if (find_enter(&rmap, "Id", &it) || copy_text(&it, out->telemetry.id, sizeof out->telemetry.id)) return -1;
            if (find_enter(&rmap, "DataSource", &it) == 0) copy_text(&it, out->telemetry.data_source, sizeof out->telemetry.data_source);
            if (find_enter(&rmap, "TimeStamp", &it) == 0) copy_text(&it, out->telemetry.time_stamp, sizeof out->telemetry.time_stamp);
            if (find_enter(&rmap, "Param1", &it) == 0) get_int(&it, &out->telemetry.param1);
            if (find_enter(&rmap, "Param2", &it) == 0) get_int(&it, &out->telemetry.param2);
            if (find_enter(&rmap, "AssociatedProblemID", &it) == 0) get_int(&it, &out->telemetry.problem_id);
            if (find_enter(&rmap, "AssociatedLogID", &it) == 0) get_int(&it, &out->telemetry.log_id);
            if (find_enter(&rmap, "WasProcessed", &it) == 0) {
                bool b = false; cbor_value_get_boolean(&it, &b); out->telemetry.was_processed = b;
            }
            if (find_enter(&rmap, "Measurements", &it) == 0 && cbor_value_is_array(&it)) {
                CborValue arr;
                if (cbor_value_enter_container(&it, &arr) != CborNoError) return -1;
                int i = 0;
                while (!cbor_value_at_end(&arr) && i < 100) {
                    double d = 0;
                    if (cbor_value_get_double(&arr, &d) != CborNoError) return -1;
                    out->telemetry.measurements[i++] = d;
                    if (cbor_value_advance_fixed(&arr) != CborNoError) return -1;
                }
                out->telemetry.meas_count = i;
            }
            break;
        }
        case TD_STRING_ARRAY: {
            if (find_enter(&rmap, "Items", &it) || !cbor_value_is_array(&it)) return -1;
            CborValue arr;
            if (cbor_value_enter_container(&it, &arr) != CborNoError) return -1;
            int i = 0;
            while (!cbor_value_at_end(&arr) && i < 100) {
                if (copy_text(&arr, out->string_array.items[i], sizeof out->string_array.items[i])) return -1;
                i++;
            }
            out->string_array.count = i;
            break;
        }
        case TD_EDI835: {
            if (find_enter(&rmap, "PayerName", &it) || copy_text(&it, out->edi.payer_name, sizeof out->edi.payer_name)) return -1;
            if (find_enter(&rmap, "PayeeName", &it) == 0) copy_text(&it, out->edi.payee_name, sizeof out->edi.payee_name);
            if (find_enter(&rmap, "PaymentDate", &it) == 0) copy_text(&it, out->edi.payment_date, sizeof out->edi.payment_date);
            if (find_enter(&rmap, "TCN", &it) == 0) copy_text(&it, out->edi.tcn, sizeof out->edi.tcn);
            if (find_enter(&rmap, "TotalActual", &it) == 0) {
                double d = 0; cbor_value_get_double(&it, &d); out->edi.total_actual = d;
            }
            if (find_enter(&rmap, "Claims", &it) == 0 && cbor_value_is_array(&it)) {
                CborValue claims;
                if (cbor_value_enter_container(&it, &claims) != CborNoError) return -1;
                int c = 0;
                while (!cbor_value_at_end(&claims) && c < 6) {
                    if (!cbor_value_is_map(&claims)) return -1;
                    claim_t *cl = &out->edi.claims[c];
                    CborValue co = claims, f;
                    if (find_enter(&co, "ClaimId", &f) == 0) copy_text(&f, cl->claim_id, sizeof cl->claim_id);
                    if (find_enter(&co, "PatientName", &f) == 0) copy_text(&f, cl->patient_name, sizeof cl->patient_name);
                    if (find_enter(&co, "TotalCharge", &f) == 0) { double d=0; cbor_value_get_double(&f,&d); cl->total_charge=d; }
                    if (find_enter(&co, "Payment", &f) == 0) { double d=0; cbor_value_get_double(&f,&d); cl->payment=d; }
                    if (find_enter(&co, "Lines", &f) == 0 && cbor_value_is_array(&f)) {
                        CborValue lines;
                        if (cbor_value_enter_container(&f, &lines) != CborNoError) return -1;
                        int L = 0;
                        while (!cbor_value_at_end(&lines) && L < 4) {
                            CborValue lo = lines, g;
                            if (find_enter(&lo, "ServiceCode", &g) == 0) copy_text(&g, cl->lines[L].service_code, sizeof cl->lines[L].service_code);
                            if (find_enter(&lo, "Charge", &g) == 0) { double d=0; cbor_value_get_double(&g,&d); cl->lines[L].charge=d; }
                            if (find_enter(&lo, "Adjudicated", &g) == 0) { double d=0; cbor_value_get_double(&g,&d); cl->lines[L].adjudicated=d; }
                            if (cbor_value_advance(&lines) != CborNoError) return -1;
                            L++;
                        }
                        cl->line_count = L;
                    }
                    if (cbor_value_advance(&claims) != CborNoError) return -1;
                    c++;
                }
                out->edi.claim_count = c;
            }
            break;
        }

        case TD_OBJECT_GRAPH: {
            if (find_enter(&rmap, "root", &it) == 0) get_int(&it, &out->graph.root);
            if (find_enter(&rmap, "nodes", &it) || !cbor_value_is_array(&it)) return -1;
            CborValue arr;
            if (cbor_value_enter_container(&it, &arr) != CborNoError) return -1;
            int i = 0;
            while (!cbor_value_at_end(&arr) && i < GRAPH_MAX_NODES) {
                if (!cbor_value_is_map(&arr)) return -1;
                graph_node_t *n = &out->graph.nodes[i];
                CborValue no = arr, f;
                if (find_enter(&no, "Name", &f) == 0) copy_text(&f, n->name, sizeof n->name);
                if (find_enter(&no, "Parent", &f) == 0) get_int(&f, &n->parent);
                if (find_enter(&no, "Related", &f) == 0) get_int(&f, &n->related);
                if (find_enter(&no, "Children", &f) == 0 && cbor_value_is_array(&f)) {
                    CborValue ch;
                    if (cbor_value_enter_container(&f, &ch) != CborNoError) return -1;
                    int c = 0;
                    while (!cbor_value_at_end(&ch) && c < GRAPH_MAX_CHILDREN) {
                        if (get_int(&ch, &n->children[c])) return -1;
                        c++;
                    }
                    n->child_count = c;
                }
                if (cbor_value_advance(&arr) != CborNoError) return -1;
                i++;
            }
            out->graph.node_count = i;
            break;
        }
        default: return -1;
    }
    (void)map;
    return 0;
}

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    CborEncoder enc;
    cbor_encoder_init(&enc, buf, cap, 0);
    if (write_fx(&enc, fx) != CborNoError) return -1;
    *ol = cbor_encoder_get_buffer_size(&enc, buf);
    return 0;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    CborParser parser; CborValue root;
    if (cbor_parser_init(buf, len, 0, &parser, &root) != CborNoError) return -1;
    return read_fx(&root, out, kind);
}

void bench_register_tinycbor(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "tinycbor", "0.6.0", "binary", prep, ser, de, fidelity_fx);
}
