#include "ser_common.h"
#include <jansson.h>

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static json_t *fx_to_json(const test_fixture_t *fx) {
    json_t *root = json_object();
    json_object_set_new(root, "kind", json_integer(fx->kind));
    switch (fx->kind) {
        case TD_INTEGER:
            json_object_set_new(root, "value", json_integer(fx->integer_val));
            break;
        case TD_SIMPLE:
            json_object_set_new(root, "Id", json_integer(fx->simple.id));
            json_object_set_new(root, "Name", json_string(fx->simple.name));
            json_object_set_new(root, "Timestamp", json_string(fx->simple.timestamp));
            json_object_set_new(root, "IsActive", json_boolean(fx->simple.is_active));
            break;
        case TD_PERSON: {
            json_object_set_new(root, "FirstName", json_string(fx->person.first_name));
            json_object_set_new(root, "LastName", json_string(fx->person.last_name));
            json_object_set_new(root, "Age", json_integer(fx->person.age));
            json_object_set_new(root, "Gender", json_integer(fx->person.gender));
            json_t *pass = json_object();
            json_object_set_new(pass, "Number", json_string(fx->person.passport_number));
            json_object_set_new(pass, "Authority", json_string(fx->person.passport_authority));
            json_object_set_new(root, "Passport", pass);
            json_t *arr = json_array();
            int n = fx->person.police_count; if (n < 0) n = 0; if (n > 8) n = 8;
            for (int i = 0; i < n; i++) {
                json_t *rec = json_object();
                json_object_set_new(rec, "Id", json_integer(fx->person.police_ids[i]));
                json_object_set_new(rec, "CrimeCode", json_string(fx->person.police_codes[i]));
                json_array_append_new(arr, rec);
            }
            json_object_set_new(root, "PoliceRecords", arr);
            break;
        }
        case TD_TELEMETRY: {
            json_object_set_new(root, "Id", json_string(fx->telemetry.id));
            json_object_set_new(root, "DataSource", json_string(fx->telemetry.data_source));
            json_object_set_new(root, "TimeStamp", json_string(fx->telemetry.time_stamp));
            json_object_set_new(root, "Param1", json_integer(fx->telemetry.param1));
            json_object_set_new(root, "Param2", json_integer(fx->telemetry.param2));
            json_t *arr = json_array();
            int n = fx->telemetry.meas_count; if (n < 0) n = 0; if (n > 100) n = 100;
            for (int i = 0; i < n; i++) json_array_append_new(arr, json_real(fx->telemetry.measurements[i]));
            json_object_set_new(root, "Measurements", arr);
            json_object_set_new(root, "AssociatedProblemID", json_integer(fx->telemetry.problem_id));
            json_object_set_new(root, "AssociatedLogID", json_integer(fx->telemetry.log_id));
            json_object_set_new(root, "WasProcessed", json_boolean(fx->telemetry.was_processed));
            break;
        }
        case TD_STRING_ARRAY: {
            json_object_set_new(root, "Count", json_integer(fx->string_array.count));
            json_t *arr = json_array();
            for (int i = 0; i < fx->string_array.count && i < 100; i++)
                json_array_append_new(arr, json_string(fx->string_array.items[i]));
            json_object_set_new(root, "Items", arr);
            break;
        }
        case TD_EDI835: {
            json_object_set_new(root, "PayerName", json_string(fx->edi.payer_name));
            json_object_set_new(root, "PayeeName", json_string(fx->edi.payee_name));
            json_object_set_new(root, "PaymentDate", json_string(fx->edi.payment_date));
            json_object_set_new(root, "TotalActual", json_real(fx->edi.total_actual));
            json_object_set_new(root, "TCN", json_string(fx->edi.tcn));
            json_t *claims = json_array();
            int nc = fx->edi.claim_count; if (nc < 0) nc = 0; if (nc > 6) nc = 6;
            for (int c = 0; c < nc; c++) {
                const claim_t *cl = &fx->edi.claims[c];
                json_t *co = json_object();
                json_object_set_new(co, "ClaimId", json_string(cl->claim_id));
                json_object_set_new(co, "PatientName", json_string(cl->patient_name));
                json_object_set_new(co, "TotalCharge", json_real(cl->total_charge));
                json_object_set_new(co, "Payment", json_real(cl->payment));
                json_t *lines = json_array();
                int nl = cl->line_count; if (nl < 0) nl = 0; if (nl > 4) nl = 4;
                for (int L = 0; L < nl; L++) {
                    json_t *lo = json_object();
                    json_object_set_new(lo, "ServiceCode", json_string(cl->lines[L].service_code));
                    json_object_set_new(lo, "Charge", json_real(cl->lines[L].charge));
                    json_object_set_new(lo, "Adjudicated", json_real(cl->lines[L].adjudicated));
                    json_array_append_new(lines, lo);
                }
                json_object_set_new(co, "Lines", lines);
                json_array_append_new(claims, co);
            }
            json_object_set_new(root, "Claims", claims);
            break;
        }
        default:
            json_decref(root);
            return NULL;
    }
    return root;
}

/* Decode via re-parse with jansson then field extract - use json_loads of dumps from same shape.
 * Full decode mirrors yyjson logic. */
static int json_to_fx(json_t *root, test_fixture_t *out, test_data_kind_t kind) {
    json_t *kv = json_object_get(root, "kind");
    if (!json_is_integer(kv) || (int)json_integer_value(kv) != (int)kind) return -1;
    memset(out, 0, sizeof *out);
    out->kind = kind;
    out->name = test_data_name(kind);
    switch (kind) {
        case TD_INTEGER:
            out->integer_val = (int)json_integer_value(json_object_get(root, "value"));
            break;
        case TD_SIMPLE: {
            out->simple.id = (int)json_integer_value(json_object_get(root, "Id"));
            const char *n = json_string_value(json_object_get(root, "Name"));
            const char *t = json_string_value(json_object_get(root, "Timestamp"));
            if (!n) return -1;
            snprintf(out->simple.name, sizeof out->simple.name, "%s", n);
            if (t) snprintf(out->simple.timestamp, sizeof out->simple.timestamp, "%s", t);
            out->simple.is_active = json_is_true(json_object_get(root, "IsActive"));
            break;
        }
        case TD_PERSON: {
            const char *fn = json_string_value(json_object_get(root, "FirstName"));
            const char *ln = json_string_value(json_object_get(root, "LastName"));
            if (!fn || !ln) return -1;
            snprintf(out->person.first_name, sizeof out->person.first_name, "%s", fn);
            snprintf(out->person.last_name, sizeof out->person.last_name, "%s", ln);
            out->person.age = (int)json_integer_value(json_object_get(root, "Age"));
            out->person.gender = (int)json_integer_value(json_object_get(root, "Gender"));
            json_t *pass = json_object_get(root, "Passport");
            if (json_is_object(pass)) {
                const char *pn = json_string_value(json_object_get(pass, "Number"));
                const char *pa = json_string_value(json_object_get(pass, "Authority"));
                if (pn) snprintf(out->person.passport_number, sizeof out->person.passport_number, "%s", pn);
                if (pa) snprintf(out->person.passport_authority, sizeof out->person.passport_authority, "%s", pa);
            }
            json_t *arr = json_object_get(root, "PoliceRecords");
            if (json_is_array(arr)) {
                size_t n = json_array_size(arr); if (n > 8) n = 8;
                out->person.police_count = (int)n;
                for (size_t i = 0; i < n; i++) {
                    json_t *rec = json_array_get(arr, i);
                    out->person.police_ids[i] = (int)json_integer_value(json_object_get(rec, "Id"));
                    const char *cc = json_string_value(json_object_get(rec, "CrimeCode"));
                    if (cc) snprintf(out->person.police_codes[i], sizeof out->person.police_codes[i], "%s", cc);
                }
            }
            break;
        }
        case TD_TELEMETRY: {
            const char *id = json_string_value(json_object_get(root, "Id"));
            if (!id) return -1;
            snprintf(out->telemetry.id, sizeof out->telemetry.id, "%s", id);
            const char *ds = json_string_value(json_object_get(root, "DataSource"));
            if (ds) snprintf(out->telemetry.data_source, sizeof out->telemetry.data_source, "%s", ds);
            const char *ts = json_string_value(json_object_get(root, "TimeStamp"));
            if (ts) snprintf(out->telemetry.time_stamp, sizeof out->telemetry.time_stamp, "%s", ts);
            out->telemetry.param1 = (int)json_integer_value(json_object_get(root, "Param1"));
            out->telemetry.param2 = (int)json_integer_value(json_object_get(root, "Param2"));
            out->telemetry.problem_id = (int)json_integer_value(json_object_get(root, "AssociatedProblemID"));
            out->telemetry.log_id = (int)json_integer_value(json_object_get(root, "AssociatedLogID"));
            out->telemetry.was_processed = json_is_true(json_object_get(root, "WasProcessed"));
            json_t *arr = json_object_get(root, "Measurements");
            if (json_is_array(arr)) {
                size_t n = json_array_size(arr); if (n > 100) n = 100;
                out->telemetry.meas_count = (int)n;
                for (size_t i = 0; i < n; i++) out->telemetry.measurements[i] = json_real_value(json_array_get(arr, i));
            }
            break;
        }
        case TD_STRING_ARRAY: {
            json_t *arr = json_object_get(root, "Items");
            if (json_is_array(arr)) {
                size_t n = json_array_size(arr); if (n > 100) n = 100;
                out->string_array.count = (int)n;
                for (size_t i = 0; i < n; i++) {
                    const char *s = json_string_value(json_array_get(arr, i));
                    if (s) snprintf(out->string_array.items[i], sizeof out->string_array.items[i], "%s", s);
                }
            }
            break;
        }
        case TD_EDI835: {
            const char *p = json_string_value(json_object_get(root, "PayerName"));
            if (!p) return -1;
            snprintf(out->edi.payer_name, sizeof out->edi.payer_name, "%s", p);
            const char *q = json_string_value(json_object_get(root, "PayeeName"));
            if (q) snprintf(out->edi.payee_name, sizeof out->edi.payee_name, "%s", q);
            const char *pd = json_string_value(json_object_get(root, "PaymentDate"));
            if (pd) snprintf(out->edi.payment_date, sizeof out->edi.payment_date, "%s", pd);
            const char *tcn = json_string_value(json_object_get(root, "TCN"));
            if (tcn) snprintf(out->edi.tcn, sizeof out->edi.tcn, "%s", tcn);
            out->edi.total_actual = json_real_value(json_object_get(root, "TotalActual"));
            json_t *claims = json_object_get(root, "Claims");
            if (json_is_array(claims)) {
                size_t nc = json_array_size(claims); if (nc > 6) nc = 6;
                out->edi.claim_count = (int)nc;
                for (size_t c = 0; c < nc; c++) {
                    json_t *co = json_array_get(claims, c);
                    claim_t *cl = &out->edi.claims[c];
                    const char *cid = json_string_value(json_object_get(co, "ClaimId"));
                    const char *pn = json_string_value(json_object_get(co, "PatientName"));
                    if (cid) snprintf(cl->claim_id, sizeof cl->claim_id, "%s", cid);
                    if (pn) snprintf(cl->patient_name, sizeof cl->patient_name, "%s", pn);
                    cl->total_charge = json_real_value(json_object_get(co, "TotalCharge"));
                    cl->payment = json_real_value(json_object_get(co, "Payment"));
                    json_t *lines = json_object_get(co, "Lines");
                    size_t nl = json_is_array(lines) ? json_array_size(lines) : 0; if (nl > 4) nl = 4;
                    cl->line_count = (int)nl;
                    for (size_t L = 0; L < nl; L++) {
                        json_t *lo = json_array_get(lines, L);
                        const char *sc = json_string_value(json_object_get(lo, "ServiceCode"));
                        if (sc) snprintf(cl->lines[L].service_code, sizeof cl->lines[L].service_code, "%s", sc);
                        cl->lines[L].charge = json_real_value(json_object_get(lo, "Charge"));
                        cl->lines[L].adjudicated = json_real_value(json_object_get(lo, "Adjudicated"));
                    }
                }
            }
            break;
        }
        default: return -1;
    }
    return 0;
}

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    json_t *root = fx_to_json(fx);
    if (!root) return -1;
    char *s = json_dumps(root, JSON_COMPACT);
    json_decref(root);
    if (!s) return -1;
    size_t n = strlen(s);
    if (n >= cap) { free(s); return -1; }
    memcpy(buf, s, n);
    *ol = n;
    free(s);
    return 0;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    json_error_t err;
    json_t *root = json_loadb((const char *)buf, len, 0, &err);
    if (!root) return -1;
    int rc = json_to_fx(root, out, kind);
    json_decref(root);
    return rc;
}

void bench_register_jansson(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "jansson", JANSSON_VERSION, "json", prep, ser, de, fidelity_fx);
}
