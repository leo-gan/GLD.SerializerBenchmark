#include "ser_common.h"
#include <json-c/json.h>

/* Full-field json-c: for complex nests build via json_tokener on a string produced by
 * our full protobuf wire base64? No - use json_object graph. */

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

/* Serialize by converting fixture through yyjson-compatible full object built with json-c. */
static struct json_object *fx_to_obj(const test_fixture_t *fx);

/* To reduce code size: ser uses json_object_to_json_string after building with a recursive helper
 * that for PERSON/TELEMETRY/EDI builds nested objects. */

static struct json_object *fx_to_obj(const test_fixture_t *fx) {
    struct json_object *root = json_object_new_object();
    json_object_object_add(root, "kind", json_object_new_int(fx->kind));
    switch (fx->kind) {
        case TD_INTEGER:
            json_object_object_add(root, "value", json_object_new_int(fx->integer_val));
            break;
        case TD_SIMPLE:
            json_object_object_add(root, "Id", json_object_new_int(fx->simple.id));
            json_object_object_add(root, "Name", json_object_new_string(fx->simple.name));
            json_object_object_add(root, "Timestamp", json_object_new_string(fx->simple.timestamp));
            json_object_object_add(root, "IsActive", json_object_new_boolean(fx->simple.is_active));
            break;
        case TD_PERSON: {
            json_object_object_add(root, "FirstName", json_object_new_string(fx->person.first_name));
            json_object_object_add(root, "LastName", json_object_new_string(fx->person.last_name));
            json_object_object_add(root, "Age", json_object_new_int(fx->person.age));
            json_object_object_add(root, "Gender", json_object_new_int(fx->person.gender));
            struct json_object *pass = json_object_new_object();
            json_object_object_add(pass, "Number", json_object_new_string(fx->person.passport_number));
            json_object_object_add(pass, "Authority", json_object_new_string(fx->person.passport_authority));
            json_object_object_add(root, "Passport", pass);
            struct json_object *arr = json_object_new_array();
            int n = fx->person.police_count; if (n < 0) n = 0; if (n > 8) n = 8;
            for (int i = 0; i < n; i++) {
                struct json_object *rec = json_object_new_object();
                json_object_object_add(rec, "Id", json_object_new_int(fx->person.police_ids[i]));
                json_object_object_add(rec, "CrimeCode", json_object_new_string(fx->person.police_codes[i]));
                json_object_array_add(arr, rec);
            }
            json_object_object_add(root, "PoliceRecords", arr);
            break;
        }
        case TD_TELEMETRY: {
            json_object_object_add(root, "Id", json_object_new_string(fx->telemetry.id));
            json_object_object_add(root, "DataSource", json_object_new_string(fx->telemetry.data_source));
            json_object_object_add(root, "TimeStamp", json_object_new_string(fx->telemetry.time_stamp));
            json_object_object_add(root, "Param1", json_object_new_int(fx->telemetry.param1));
            json_object_object_add(root, "Param2", json_object_new_int(fx->telemetry.param2));
            struct json_object *arr = json_object_new_array();
            int n = fx->telemetry.meas_count; if (n < 0) n = 0; if (n > 100) n = 100;
            for (int i = 0; i < n; i++) json_object_array_add(arr, json_object_new_double(fx->telemetry.measurements[i]));
            json_object_object_add(root, "Measurements", arr);
            json_object_object_add(root, "AssociatedProblemID", json_object_new_int(fx->telemetry.problem_id));
            json_object_object_add(root, "AssociatedLogID", json_object_new_int(fx->telemetry.log_id));
            json_object_object_add(root, "WasProcessed", json_object_new_boolean(fx->telemetry.was_processed));
            break;
        }
        case TD_STRING_ARRAY: {
            json_object_object_add(root, "Count", json_object_new_int(fx->string_array.count));
            struct json_object *arr = json_object_new_array();
            for (int i = 0; i < fx->string_array.count && i < 100; i++)
                json_object_array_add(arr, json_object_new_string(fx->string_array.items[i]));
            json_object_object_add(root, "Items", arr);
            break;
        }
        case TD_EDI835: {
            json_object_object_add(root, "PayerName", json_object_new_string(fx->edi.payer_name));
            json_object_object_add(root, "PayeeName", json_object_new_string(fx->edi.payee_name));
            json_object_object_add(root, "PaymentDate", json_object_new_string(fx->edi.payment_date));
            json_object_object_add(root, "TotalActual", json_object_new_double(fx->edi.total_actual));
            json_object_object_add(root, "TCN", json_object_new_string(fx->edi.tcn));
            struct json_object *claims = json_object_new_array();
            int nc = fx->edi.claim_count; if (nc < 0) nc = 0; if (nc > 6) nc = 6;
            for (int c = 0; c < nc; c++) {
                const claim_t *cl = &fx->edi.claims[c];
                struct json_object *co = json_object_new_object();
                json_object_object_add(co, "ClaimId", json_object_new_string(cl->claim_id));
                json_object_object_add(co, "PatientName", json_object_new_string(cl->patient_name));
                json_object_object_add(co, "TotalCharge", json_object_new_double(cl->total_charge));
                json_object_object_add(co, "Payment", json_object_new_double(cl->payment));
                struct json_object *lines = json_object_new_array();
                int nl = cl->line_count; if (nl < 0) nl = 0; if (nl > 4) nl = 4;
                for (int L = 0; L < nl; L++) {
                    struct json_object *lo = json_object_new_object();
                    json_object_object_add(lo, "ServiceCode", json_object_new_string(cl->lines[L].service_code));
                    json_object_object_add(lo, "Charge", json_object_new_double(cl->lines[L].charge));
                    json_object_object_add(lo, "Adjudicated", json_object_new_double(cl->lines[L].adjudicated));
                    json_object_array_add(lines, lo);
                }
                json_object_object_add(co, "Lines", lines);
                json_object_array_add(claims, co);
            }
            json_object_object_add(root, "Claims", claims);
            break;
        }
        default:
            json_object_put(root);
            return NULL;
    }
    return root;
}

/* Decode: use json-c tokener then re-use field extraction by re-serializing and loading with a minimal approach:
 * parse then walk like jansson. */
static int obj_to_fx(struct json_object *root, test_fixture_t *out, test_data_kind_t kind);

/* Implement by converting to string and using jansson-compatible walk via json-c API */
static const char *jo_str(struct json_object *o, const char *k) {
    struct json_object *v;
    if (!json_object_object_get_ex(o, k, &v) || !json_object_is_type(v, json_type_string)) return NULL;
    return json_object_get_string(v);
}
static int jo_int(struct json_object *o, const char *k, int def) {
    struct json_object *v;
    if (!json_object_object_get_ex(o, k, &v)) return def;
    return json_object_get_int(v);
}
static double jo_dbl(struct json_object *o, const char *k) {
    struct json_object *v;
    if (!json_object_object_get_ex(o, k, &v)) return 0;
    return json_object_get_double(v);
}
static int jo_bool(struct json_object *o, const char *k) {
    struct json_object *v;
    if (!json_object_object_get_ex(o, k, &v)) return 0;
    return json_object_get_boolean(v);
}

static int obj_to_fx(struct json_object *root, test_fixture_t *out, test_data_kind_t kind) {
    if (jo_int(root, "kind", -1) != (int)kind) return -1;
    memset(out, 0, sizeof *out);
    out->kind = kind;
    out->name = test_data_name(kind);
    switch (kind) {
        case TD_INTEGER:
            out->integer_val = jo_int(root, "value", 0);
            break;
        case TD_SIMPLE: {
            out->simple.id = jo_int(root, "Id", 0);
            const char *n = jo_str(root, "Name"); if (!n) return -1;
            snprintf(out->simple.name, sizeof out->simple.name, "%s", n);
            const char *t = jo_str(root, "Timestamp");
            if (t) snprintf(out->simple.timestamp, sizeof out->simple.timestamp, "%s", t);
            out->simple.is_active = jo_bool(root, "IsActive");
            break;
        }
        case TD_PERSON: {
            const char *fn = jo_str(root, "FirstName"), *ln = jo_str(root, "LastName");
            if (!fn || !ln) return -1;
            snprintf(out->person.first_name, sizeof out->person.first_name, "%s", fn);
            snprintf(out->person.last_name, sizeof out->person.last_name, "%s", ln);
            out->person.age = jo_int(root, "Age", 0);
            out->person.gender = jo_int(root, "Gender", 0);
            struct json_object *pass;
            if (json_object_object_get_ex(root, "Passport", &pass) && json_object_is_type(pass, json_type_object)) {
                const char *pn = jo_str(pass, "Number"), *pa = jo_str(pass, "Authority");
                if (pn) snprintf(out->person.passport_number, sizeof out->person.passport_number, "%s", pn);
                if (pa) snprintf(out->person.passport_authority, sizeof out->person.passport_authority, "%s", pa);
            }
            struct json_object *arr;
            if (json_object_object_get_ex(root, "PoliceRecords", &arr) && json_object_is_type(arr, json_type_array)) {
                int n = json_object_array_length(arr); if (n > 8) n = 8;
                out->person.police_count = n;
                for (int i = 0; i < n; i++) {
                    struct json_object *rec = json_object_array_get_idx(arr, i);
                    out->person.police_ids[i] = jo_int(rec, "Id", 0);
                    const char *cc = jo_str(rec, "CrimeCode");
                    if (cc) snprintf(out->person.police_codes[i], sizeof out->person.police_codes[i], "%s", cc);
                }
            }
            break;
        }
        case TD_TELEMETRY: {
            const char *id = jo_str(root, "Id"); if (!id) return -1;
            snprintf(out->telemetry.id, sizeof out->telemetry.id, "%s", id);
            const char *ds = jo_str(root, "DataSource");
            if (ds) snprintf(out->telemetry.data_source, sizeof out->telemetry.data_source, "%s", ds);
            const char *ts = jo_str(root, "TimeStamp");
            if (ts) snprintf(out->telemetry.time_stamp, sizeof out->telemetry.time_stamp, "%s", ts);
            out->telemetry.param1 = jo_int(root, "Param1", 0);
            out->telemetry.param2 = jo_int(root, "Param2", 0);
            out->telemetry.problem_id = jo_int(root, "AssociatedProblemID", 0);
            out->telemetry.log_id = jo_int(root, "AssociatedLogID", 0);
            out->telemetry.was_processed = jo_bool(root, "WasProcessed");
            struct json_object *arr;
            if (json_object_object_get_ex(root, "Measurements", &arr) && json_object_is_type(arr, json_type_array)) {
                int n = json_object_array_length(arr); if (n > 100) n = 100;
                out->telemetry.meas_count = n;
                for (int i = 0; i < n; i++) out->telemetry.measurements[i] = json_object_get_double(json_object_array_get_idx(arr, i));
            }
            break;
        }
        case TD_STRING_ARRAY: {
            struct json_object *arr;
            if (json_object_object_get_ex(root, "Items", &arr) && json_object_is_type(arr, json_type_array)) {
                int n = json_object_array_length(arr); if (n > 100) n = 100;
                out->string_array.count = n;
                for (int i = 0; i < n; i++) {
                    const char *s = json_object_get_string(json_object_array_get_idx(arr, i));
                    if (s) snprintf(out->string_array.items[i], sizeof out->string_array.items[i], "%s", s);
                }
            }
            break;
        }
        case TD_EDI835: {
            const char *p = jo_str(root, "PayerName"); if (!p) return -1;
            snprintf(out->edi.payer_name, sizeof out->edi.payer_name, "%s", p);
            const char *q = jo_str(root, "PayeeName");
            if (q) snprintf(out->edi.payee_name, sizeof out->edi.payee_name, "%s", q);
            const char *pd = jo_str(root, "PaymentDate");
            if (pd) snprintf(out->edi.payment_date, sizeof out->edi.payment_date, "%s", pd);
            const char *tcn = jo_str(root, "TCN");
            if (tcn) snprintf(out->edi.tcn, sizeof out->edi.tcn, "%s", tcn);
            out->edi.total_actual = jo_dbl(root, "TotalActual");
            struct json_object *claims;
            if (json_object_object_get_ex(root, "Claims", &claims) && json_object_is_type(claims, json_type_array)) {
                int nc = json_object_array_length(claims); if (nc > 6) nc = 6;
                out->edi.claim_count = nc;
                for (int c = 0; c < nc; c++) {
                    struct json_object *co = json_object_array_get_idx(claims, c);
                    claim_t *cl = &out->edi.claims[c];
                    const char *cid = jo_str(co, "ClaimId"), *pn = jo_str(co, "PatientName");
                    if (cid) snprintf(cl->claim_id, sizeof cl->claim_id, "%s", cid);
                    if (pn) snprintf(cl->patient_name, sizeof cl->patient_name, "%s", pn);
                    cl->total_charge = jo_dbl(co, "TotalCharge");
                    cl->payment = jo_dbl(co, "Payment");
                    struct json_object *lines;
                    int nl = 0;
                    if (json_object_object_get_ex(co, "Lines", &lines) && json_object_is_type(lines, json_type_array)) {
                        nl = json_object_array_length(lines); if (nl > 4) nl = 4;
                        for (int L = 0; L < nl; L++) {
                            struct json_object *lo = json_object_array_get_idx(lines, L);
                            const char *sc = jo_str(lo, "ServiceCode");
                            if (sc) snprintf(cl->lines[L].service_code, sizeof cl->lines[L].service_code, "%s", sc);
                            cl->lines[L].charge = jo_dbl(lo, "Charge");
                            cl->lines[L].adjudicated = jo_dbl(lo, "Adjudicated");
                        }
                    }
                    cl->line_count = nl;
                }
            }
            break;
        }
        default: return -1;
    }
    return 0;
}

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    struct json_object *root = fx_to_obj(fx);
    if (!root) return -1;
    const char *s = json_object_to_json_string_ext(root, JSON_C_TO_STRING_PLAIN);
    if (!s) { json_object_put(root); return -1; }
    size_t n = strlen(s);
    if (n >= cap) { json_object_put(root); return -1; }
    memcpy(buf, s, n);
    *ol = n;
    json_object_put(root);
    return 0;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    struct json_tokener *tok = json_tokener_new();
    struct json_object *root = json_tokener_parse_ex(tok, (const char *)buf, (int)len);
    enum json_tokener_error e = json_tokener_get_error(tok);
    json_tokener_free(tok);
    if (e != json_tokener_success || !root) {
        if (root) json_object_put(root);
        return -1;
    }
    int rc = obj_to_fx(root, out, kind);
    json_object_put(root);
    return rc;
}

void bench_register_json_c(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "json-c", json_c_version(), "json", prep, ser, de, fidelity_fx);
}
