#include "ser_common.h"
#include "parson_pref.h"

/* Full-field parson: serialize/deserialize by routing through a complete JSON document
 * built and parsed with parson nested objects (same field map as yyjson/cJSON/json-c/jansson). */

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

/* Build via intermediate buffer using a tiny recursive approach:
 * we produce JSON with cJSON then parse with parson for ser? That would time cJSON.
 * Instead build with parson only. */

static JSON_Value *fx_to_val(const test_fixture_t *fx) {
    JSON_Value *root_v = json_value_init_object();
    JSON_Object *root = json_value_get_object(root_v);
    json_object_set_number(root, "kind", (double)fx->kind);
    switch (fx->kind) {
        case TD_INTEGER:
            json_object_set_number(root, "value", fx->integer_val);
            break;
        case TD_SIMPLE:
            json_object_set_number(root, "Id", fx->simple.id);
            json_object_set_string(root, "Name", fx->simple.name);
            json_object_set_string(root, "Timestamp", fx->simple.timestamp);
            json_object_set_boolean(root, "IsActive", fx->simple.is_active);
            break;
        case TD_PERSON: {
            json_object_set_string(root, "FirstName", fx->person.first_name);
            json_object_set_string(root, "LastName", fx->person.last_name);
            json_object_set_number(root, "Age", fx->person.age);
            json_object_set_number(root, "Gender", fx->person.gender);
            JSON_Value *pass_v = json_value_init_object();
            JSON_Object *pass = json_value_get_object(pass_v);
            json_object_set_string(pass, "Number", fx->person.passport_number);
            json_object_set_string(pass, "Authority", fx->person.passport_authority);
            json_object_set_value(root, "Passport", pass_v);
            JSON_Value *arr_v = json_value_init_array();
            JSON_Array *arr = json_value_get_array(arr_v);
            int n = fx->person.police_count; if (n < 0) n = 0; if (n > 8) n = 8;
            for (int i = 0; i < n; i++) {
                JSON_Value *rec_v = json_value_init_object();
                JSON_Object *rec = json_value_get_object(rec_v);
                json_object_set_number(rec, "Id", fx->person.police_ids[i]);
                json_object_set_string(rec, "CrimeCode", fx->person.police_codes[i]);
                json_array_append_value(arr, rec_v);
            }
            json_object_set_value(root, "PoliceRecords", arr_v);
            break;
        }
        case TD_TELEMETRY: {
            json_object_set_string(root, "Id", fx->telemetry.id);
            json_object_set_string(root, "DataSource", fx->telemetry.data_source);
            json_object_set_string(root, "TimeStamp", fx->telemetry.time_stamp);
            json_object_set_number(root, "Param1", fx->telemetry.param1);
            json_object_set_number(root, "Param2", fx->telemetry.param2);
            JSON_Value *arr_v = json_value_init_array();
            JSON_Array *arr = json_value_get_array(arr_v);
            int n = fx->telemetry.meas_count; if (n < 0) n = 0; if (n > 100) n = 100;
            for (int i = 0; i < n; i++) json_array_append_number(arr, fx->telemetry.measurements[i]);
            json_object_set_value(root, "Measurements", arr_v);
            json_object_set_number(root, "AssociatedProblemID", fx->telemetry.problem_id);
            json_object_set_number(root, "AssociatedLogID", fx->telemetry.log_id);
            json_object_set_boolean(root, "WasProcessed", fx->telemetry.was_processed);
            break;
        }
        case TD_STRING_ARRAY: {
            json_object_set_number(root, "Count", fx->string_array.count);
            JSON_Value *arr_v = json_value_init_array();
            JSON_Array *arr = json_value_get_array(arr_v);
            for (int i = 0; i < fx->string_array.count && i < 100; i++)
                json_array_append_string(arr, fx->string_array.items[i]);
            json_object_set_value(root, "Items", arr_v);
            break;
        }
        case TD_EDI835: {
            json_object_set_string(root, "PayerName", fx->edi.payer_name);
            json_object_set_string(root, "PayeeName", fx->edi.payee_name);
            json_object_set_string(root, "PaymentDate", fx->edi.payment_date);
            json_object_set_number(root, "TotalActual", fx->edi.total_actual);
            json_object_set_string(root, "TCN", fx->edi.tcn);
            JSON_Value *claims_v = json_value_init_array();
            JSON_Array *claims = json_value_get_array(claims_v);
            int nc = fx->edi.claim_count; if (nc < 0) nc = 0; if (nc > 6) nc = 6;
            for (int c = 0; c < nc; c++) {
                const claim_t *cl = &fx->edi.claims[c];
                JSON_Value *co_v = json_value_init_object();
                JSON_Object *co = json_value_get_object(co_v);
                json_object_set_string(co, "ClaimId", cl->claim_id);
                json_object_set_string(co, "PatientName", cl->patient_name);
                json_object_set_number(co, "TotalCharge", cl->total_charge);
                json_object_set_number(co, "Payment", cl->payment);
                JSON_Value *lines_v = json_value_init_array();
                JSON_Array *lines = json_value_get_array(lines_v);
                int nl = cl->line_count; if (nl < 0) nl = 0; if (nl > 4) nl = 4;
                for (int L = 0; L < nl; L++) {
                    JSON_Value *lo_v = json_value_init_object();
                    JSON_Object *lo = json_value_get_object(lo_v);
                    json_object_set_string(lo, "ServiceCode", cl->lines[L].service_code);
                    json_object_set_number(lo, "Charge", cl->lines[L].charge);
                    json_object_set_number(lo, "Adjudicated", cl->lines[L].adjudicated);
                    json_array_append_value(lines, lo_v);
                }
                json_object_set_value(co, "Lines", lines_v);
                json_array_append_value(claims, co_v);
            }
            json_object_set_value(root, "Claims", claims_v);
            break;
        }
        default:
            json_value_free(root_v);
            return NULL;
    }
    return root_v;
}

static int val_to_fx(JSON_Value *root_v, test_fixture_t *out, test_data_kind_t kind) {
    JSON_Object *root = json_value_get_object(root_v);
    if (!root || (int)json_object_get_number(root, "kind") != (int)kind) return -1;
    memset(out, 0, sizeof *out);
    out->kind = kind;
    out->name = test_data_name(kind);
    switch (kind) {
        case TD_INTEGER:
            out->integer_val = (int)json_object_get_number(root, "value");
            break;
        case TD_SIMPLE: {
            out->simple.id = (int)json_object_get_number(root, "Id");
            const char *n = json_object_get_string(root, "Name");
            const char *t = json_object_get_string(root, "Timestamp");
            if (!n) return -1;
            snprintf(out->simple.name, sizeof out->simple.name, "%s", n);
            if (t) snprintf(out->simple.timestamp, sizeof out->simple.timestamp, "%s", t);
            out->simple.is_active = json_object_get_boolean(root, "IsActive") == 1;
            break;
        }
        case TD_PERSON: {
            const char *fn = json_object_get_string(root, "FirstName");
            const char *ln = json_object_get_string(root, "LastName");
            if (!fn || !ln) return -1;
            snprintf(out->person.first_name, sizeof out->person.first_name, "%s", fn);
            snprintf(out->person.last_name, sizeof out->person.last_name, "%s", ln);
            out->person.age = (int)json_object_get_number(root, "Age");
            out->person.gender = (int)json_object_get_number(root, "Gender");
            JSON_Object *pass = json_object_get_object(root, "Passport");
            if (pass) {
                const char *pn = json_object_get_string(pass, "Number");
                const char *pa = json_object_get_string(pass, "Authority");
                if (pn) snprintf(out->person.passport_number, sizeof out->person.passport_number, "%s", pn);
                if (pa) snprintf(out->person.passport_authority, sizeof out->person.passport_authority, "%s", pa);
            }
            JSON_Array *arr = json_object_get_array(root, "PoliceRecords");
            if (arr) {
                size_t n = json_array_get_count(arr); if (n > 8) n = 8;
                out->person.police_count = (int)n;
                for (size_t i = 0; i < n; i++) {
                    JSON_Object *rec = json_array_get_object(arr, i);
                    out->person.police_ids[i] = (int)json_object_get_number(rec, "Id");
                    const char *cc = json_object_get_string(rec, "CrimeCode");
                    if (cc) snprintf(out->person.police_codes[i], sizeof out->person.police_codes[i], "%s", cc);
                }
            }
            break;
        }
        case TD_TELEMETRY: {
            const char *id = json_object_get_string(root, "Id");
            if (!id) return -1;
            snprintf(out->telemetry.id, sizeof out->telemetry.id, "%s", id);
            const char *ds = json_object_get_string(root, "DataSource");
            if (ds) snprintf(out->telemetry.data_source, sizeof out->telemetry.data_source, "%s", ds);
            const char *ts = json_object_get_string(root, "TimeStamp");
            if (ts) snprintf(out->telemetry.time_stamp, sizeof out->telemetry.time_stamp, "%s", ts);
            out->telemetry.param1 = (int)json_object_get_number(root, "Param1");
            out->telemetry.param2 = (int)json_object_get_number(root, "Param2");
            out->telemetry.problem_id = (int)json_object_get_number(root, "AssociatedProblemID");
            out->telemetry.log_id = (int)json_object_get_number(root, "AssociatedLogID");
            out->telemetry.was_processed = json_object_get_boolean(root, "WasProcessed") == 1;
            JSON_Array *arr = json_object_get_array(root, "Measurements");
            if (arr) {
                size_t n = json_array_get_count(arr); if (n > 100) n = 100;
                out->telemetry.meas_count = (int)n;
                for (size_t i = 0; i < n; i++) out->telemetry.measurements[i] = json_array_get_number(arr, i);
            }
            break;
        }
        case TD_STRING_ARRAY: {
            JSON_Array *arr = json_object_get_array(root, "Items");
            if (arr) {
                size_t n = json_array_get_count(arr); if (n > 100) n = 100;
                out->string_array.count = (int)n;
                for (size_t i = 0; i < n; i++) {
                    const char *s = json_array_get_string(arr, i);
                    if (s) snprintf(out->string_array.items[i], sizeof out->string_array.items[i], "%s", s);
                }
            }
            break;
        }
        case TD_EDI835: {
            const char *p = json_object_get_string(root, "PayerName");
            if (!p) return -1;
            snprintf(out->edi.payer_name, sizeof out->edi.payer_name, "%s", p);
            const char *q = json_object_get_string(root, "PayeeName");
            if (q) snprintf(out->edi.payee_name, sizeof out->edi.payee_name, "%s", q);
            const char *pd = json_object_get_string(root, "PaymentDate");
            if (pd) snprintf(out->edi.payment_date, sizeof out->edi.payment_date, "%s", pd);
            const char *tcn = json_object_get_string(root, "TCN");
            if (tcn) snprintf(out->edi.tcn, sizeof out->edi.tcn, "%s", tcn);
            out->edi.total_actual = json_object_get_number(root, "TotalActual");
            JSON_Array *claims = json_object_get_array(root, "Claims");
            if (claims) {
                size_t nc = json_array_get_count(claims); if (nc > 6) nc = 6;
                out->edi.claim_count = (int)nc;
                for (size_t c = 0; c < nc; c++) {
                    JSON_Object *co = json_array_get_object(claims, c);
                    claim_t *cl = &out->edi.claims[c];
                    const char *cid = json_object_get_string(co, "ClaimId");
                    const char *pn = json_object_get_string(co, "PatientName");
                    if (cid) snprintf(cl->claim_id, sizeof cl->claim_id, "%s", cid);
                    if (pn) snprintf(cl->patient_name, sizeof cl->patient_name, "%s", pn);
                    cl->total_charge = json_object_get_number(co, "TotalCharge");
                    cl->payment = json_object_get_number(co, "Payment");
                    JSON_Array *lines = json_object_get_array(co, "Lines");
                    size_t nl = lines ? json_array_get_count(lines) : 0; if (nl > 4) nl = 4;
                    cl->line_count = (int)nl;
                    for (size_t L = 0; L < nl; L++) {
                        JSON_Object *lo = json_array_get_object(lines, L);
                        const char *sc = json_object_get_string(lo, "ServiceCode");
                        if (sc) snprintf(cl->lines[L].service_code, sizeof cl->lines[L].service_code, "%s", sc);
                        cl->lines[L].charge = json_object_get_number(lo, "Charge");
                        cl->lines[L].adjudicated = json_object_get_number(lo, "Adjudicated");
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
    JSON_Value *v = fx_to_val(fx);
    if (!v) return -1;
    char *s = json_serialize_to_string(v);
    json_value_free(v);
    if (!s) return -1;
    size_t n = strlen(s);
    if (n >= cap) { json_free_serialized_string(s); return -1; }
    memcpy(buf, s, n);
    *ol = n;
    json_free_serialized_string(s);
    return 0;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    char *tmp = (char *)malloc(len + 1);
    if (!tmp) return -1;
    memcpy(tmp, buf, len); tmp[len] = 0;
    JSON_Value *v = json_parse_string(tmp);
    free(tmp);
    if (!v) return -1;
    int rc = val_to_fx(v, out, kind);
    json_value_free(v);
    return rc;
}

void bench_register_parson(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "parson", "1.5.3", "json", prep, ser, de, fidelity_fx);
}
