#include "ser_common.h"
#include "cJSON.h"
#include <stdlib.h>

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static cJSON *fx_to_json(const test_fixture_t *fx) {
    cJSON *root = cJSON_CreateObject();
    if (!root) return NULL;
    cJSON_AddNumberToObject(root, "kind", (double)fx->kind);
    switch (fx->kind) {
        case TD_INTEGER:
            cJSON_AddNumberToObject(root, "value", fx->integer_val);
            break;
        case TD_SIMPLE:
            cJSON_AddNumberToObject(root, "Id", fx->simple.id);
            cJSON_AddStringToObject(root, "Name", fx->simple.name);
            cJSON_AddStringToObject(root, "Timestamp", fx->simple.timestamp);
            cJSON_AddBoolToObject(root, "IsActive", fx->simple.is_active);
            break;
        case TD_PERSON: {
            cJSON_AddStringToObject(root, "FirstName", fx->person.first_name);
            cJSON_AddStringToObject(root, "LastName", fx->person.last_name);
            cJSON_AddNumberToObject(root, "Age", fx->person.age);
            cJSON_AddNumberToObject(root, "Gender", fx->person.gender);
            cJSON *pass = cJSON_CreateObject();
            cJSON_AddStringToObject(pass, "Number", fx->person.passport_number);
            cJSON_AddStringToObject(pass, "Authority", fx->person.passport_authority);
            cJSON_AddItemToObject(root, "Passport", pass);
            cJSON *arr = cJSON_CreateArray();
            int n = fx->person.police_count; if (n < 0) n = 0; if (n > 8) n = 8;
            for (int i = 0; i < n; i++) {
                cJSON *rec = cJSON_CreateObject();
                cJSON_AddNumberToObject(rec, "Id", fx->person.police_ids[i]);
                cJSON_AddStringToObject(rec, "CrimeCode", fx->person.police_codes[i]);
                cJSON_AddItemToArray(arr, rec);
            }
            cJSON_AddItemToObject(root, "PoliceRecords", arr);
            break;
        }
        case TD_TELEMETRY: {
            cJSON_AddStringToObject(root, "Id", fx->telemetry.id);
            cJSON_AddStringToObject(root, "DataSource", fx->telemetry.data_source);
            cJSON_AddStringToObject(root, "TimeStamp", fx->telemetry.time_stamp);
            cJSON_AddNumberToObject(root, "Param1", fx->telemetry.param1);
            cJSON_AddNumberToObject(root, "Param2", fx->telemetry.param2);
            cJSON *arr = cJSON_CreateArray();
            int n = fx->telemetry.meas_count; if (n < 0) n = 0; if (n > 100) n = 100;
            for (int i = 0; i < n; i++) cJSON_AddItemToArray(arr, cJSON_CreateNumber(fx->telemetry.measurements[i]));
            cJSON_AddItemToObject(root, "Measurements", arr);
            cJSON_AddNumberToObject(root, "AssociatedProblemID", fx->telemetry.problem_id);
            cJSON_AddNumberToObject(root, "AssociatedLogID", fx->telemetry.log_id);
            cJSON_AddBoolToObject(root, "WasProcessed", fx->telemetry.was_processed);
            break;
        }
        case TD_STRING_ARRAY: {
            cJSON_AddNumberToObject(root, "Count", fx->string_array.count);
            cJSON *arr = cJSON_CreateArray();
            for (int i = 0; i < fx->string_array.count && i < 100; i++)
                cJSON_AddItemToArray(arr, cJSON_CreateString(fx->string_array.items[i]));
            cJSON_AddItemToObject(root, "Items", arr);
            break;
        }
        case TD_EDI835: {
            cJSON_AddStringToObject(root, "PayerName", fx->edi.payer_name);
            cJSON_AddStringToObject(root, "PayeeName", fx->edi.payee_name);
            cJSON_AddStringToObject(root, "PaymentDate", fx->edi.payment_date);
            cJSON_AddNumberToObject(root, "TotalActual", fx->edi.total_actual);
            cJSON_AddStringToObject(root, "TCN", fx->edi.tcn);
            cJSON *claims = cJSON_CreateArray();
            int nc = fx->edi.claim_count; if (nc < 0) nc = 0; if (nc > 6) nc = 6;
            for (int c = 0; c < nc; c++) {
                const claim_t *cl = &fx->edi.claims[c];
                cJSON *co = cJSON_CreateObject();
                cJSON_AddStringToObject(co, "ClaimId", cl->claim_id);
                cJSON_AddStringToObject(co, "PatientName", cl->patient_name);
                cJSON_AddNumberToObject(co, "TotalCharge", cl->total_charge);
                cJSON_AddNumberToObject(co, "Payment", cl->payment);
                cJSON *lines = cJSON_CreateArray();
                int nl = cl->line_count; if (nl < 0) nl = 0; if (nl > 4) nl = 4;
                for (int L = 0; L < nl; L++) {
                    cJSON *lo = cJSON_CreateObject();
                    cJSON_AddStringToObject(lo, "ServiceCode", cl->lines[L].service_code);
                    cJSON_AddNumberToObject(lo, "Charge", cl->lines[L].charge);
                    cJSON_AddNumberToObject(lo, "Adjudicated", cl->lines[L].adjudicated);
                    cJSON_AddItemToArray(lines, lo);
                }
                cJSON_AddItemToObject(co, "Lines", lines);
                cJSON_AddItemToArray(claims, co);
            }
            cJSON_AddItemToObject(root, "Claims", claims);
            break;
        }
        default:
            cJSON_Delete(root);
            return NULL;
    }
    return root;
}

static int json_to_fx(cJSON *root, test_fixture_t *out, test_data_kind_t kind) {
    cJSON *k = cJSON_GetObjectItemCaseSensitive(root, "kind");
    if (!cJSON_IsNumber(k) || (int)k->valuedouble != (int)kind) return -1;
    memset(out, 0, sizeof *out);
    out->kind = kind;
    out->name = test_data_name(kind);
    switch (kind) {
        case TD_INTEGER: {
            cJSON *v = cJSON_GetObjectItemCaseSensitive(root, "value");
            if (!cJSON_IsNumber(v)) return -1;
            out->integer_val = (int)v->valuedouble;
            break;
        }
        case TD_SIMPLE: {
            cJSON *id = cJSON_GetObjectItemCaseSensitive(root, "Id");
            cJSON *name = cJSON_GetObjectItemCaseSensitive(root, "Name");
            cJSON *ts = cJSON_GetObjectItemCaseSensitive(root, "Timestamp");
            cJSON *act = cJSON_GetObjectItemCaseSensitive(root, "IsActive");
            if (!cJSON_IsNumber(id) || !cJSON_IsString(name)) return -1;
            out->simple.id = (int)id->valuedouble;
            snprintf(out->simple.name, sizeof out->simple.name, "%s", name->valuestring);
            if (cJSON_IsString(ts)) snprintf(out->simple.timestamp, sizeof out->simple.timestamp, "%s", ts->valuestring);
            out->simple.is_active = cJSON_IsTrue(act);
            break;
        }
        case TD_PERSON: {
            cJSON *fn = cJSON_GetObjectItemCaseSensitive(root, "FirstName");
            cJSON *ln = cJSON_GetObjectItemCaseSensitive(root, "LastName");
            if (!cJSON_IsString(fn) || !cJSON_IsString(ln)) return -1;
            snprintf(out->person.first_name, sizeof out->person.first_name, "%s", fn->valuestring);
            snprintf(out->person.last_name, sizeof out->person.last_name, "%s", ln->valuestring);
            out->person.age = (int)cJSON_GetObjectItemCaseSensitive(root, "Age")->valuedouble;
            out->person.gender = (int)cJSON_GetObjectItemCaseSensitive(root, "Gender")->valuedouble;
            cJSON *pass = cJSON_GetObjectItemCaseSensitive(root, "Passport");
            if (cJSON_IsObject(pass)) {
                cJSON *pn = cJSON_GetObjectItemCaseSensitive(pass, "Number");
                cJSON *pa = cJSON_GetObjectItemCaseSensitive(pass, "Authority");
                if (cJSON_IsString(pn)) snprintf(out->person.passport_number, sizeof out->person.passport_number, "%s", pn->valuestring);
                if (cJSON_IsString(pa)) snprintf(out->person.passport_authority, sizeof out->person.passport_authority, "%s", pa->valuestring);
            }
            cJSON *arr = cJSON_GetObjectItemCaseSensitive(root, "PoliceRecords");
            if (cJSON_IsArray(arr)) {
                int n = cJSON_GetArraySize(arr); if (n > 8) n = 8;
                out->person.police_count = n;
                for (int i = 0; i < n; i++) {
                    cJSON *rec = cJSON_GetArrayItem(arr, i);
                    out->person.police_ids[i] = (int)cJSON_GetObjectItemCaseSensitive(rec, "Id")->valuedouble;
                    cJSON *cc = cJSON_GetObjectItemCaseSensitive(rec, "CrimeCode");
                    if (cJSON_IsString(cc)) snprintf(out->person.police_codes[i], sizeof out->person.police_codes[i], "%s", cc->valuestring);
                }
            }
            break;
        }
        case TD_TELEMETRY: {
            cJSON *id = cJSON_GetObjectItemCaseSensitive(root, "Id");
            if (!cJSON_IsString(id)) return -1;
            snprintf(out->telemetry.id, sizeof out->telemetry.id, "%s", id->valuestring);
            cJSON *ds = cJSON_GetObjectItemCaseSensitive(root, "DataSource");
            if (cJSON_IsString(ds)) snprintf(out->telemetry.data_source, sizeof out->telemetry.data_source, "%s", ds->valuestring);
            cJSON *ts = cJSON_GetObjectItemCaseSensitive(root, "TimeStamp");
            if (cJSON_IsString(ts)) snprintf(out->telemetry.time_stamp, sizeof out->telemetry.time_stamp, "%s", ts->valuestring);
            out->telemetry.param1 = (int)cJSON_GetObjectItemCaseSensitive(root, "Param1")->valuedouble;
            out->telemetry.param2 = (int)cJSON_GetObjectItemCaseSensitive(root, "Param2")->valuedouble;
            out->telemetry.problem_id = (int)cJSON_GetObjectItemCaseSensitive(root, "AssociatedProblemID")->valuedouble;
            out->telemetry.log_id = (int)cJSON_GetObjectItemCaseSensitive(root, "AssociatedLogID")->valuedouble;
            out->telemetry.was_processed = cJSON_IsTrue(cJSON_GetObjectItemCaseSensitive(root, "WasProcessed"));
            cJSON *arr = cJSON_GetObjectItemCaseSensitive(root, "Measurements");
            if (cJSON_IsArray(arr)) {
                int n = cJSON_GetArraySize(arr); if (n > 100) n = 100;
                out->telemetry.meas_count = n;
                for (int i = 0; i < n; i++) out->telemetry.measurements[i] = cJSON_GetArrayItem(arr, i)->valuedouble;
            }
            break;
        }
        case TD_STRING_ARRAY: {
            cJSON *arr = cJSON_GetObjectItemCaseSensitive(root, "Items");
            if (cJSON_IsArray(arr)) {
                int n = cJSON_GetArraySize(arr); if (n > 100) n = 100;
                out->string_array.count = n;
                for (int i = 0; i < n; i++) {
                    cJSON *it = cJSON_GetArrayItem(arr, i);
                    if (cJSON_IsString(it)) snprintf(out->string_array.items[i], sizeof out->string_array.items[i], "%s", it->valuestring);
                }
            }
            break;
        }
        case TD_EDI835: {
            cJSON *p = cJSON_GetObjectItemCaseSensitive(root, "PayerName");
            if (!cJSON_IsString(p)) return -1;
            snprintf(out->edi.payer_name, sizeof out->edi.payer_name, "%s", p->valuestring);
            cJSON *q = cJSON_GetObjectItemCaseSensitive(root, "PayeeName");
            if (cJSON_IsString(q)) snprintf(out->edi.payee_name, sizeof out->edi.payee_name, "%s", q->valuestring);
            cJSON *pd = cJSON_GetObjectItemCaseSensitive(root, "PaymentDate");
            if (cJSON_IsString(pd)) snprintf(out->edi.payment_date, sizeof out->edi.payment_date, "%s", pd->valuestring);
            cJSON *tcn = cJSON_GetObjectItemCaseSensitive(root, "TCN");
            if (cJSON_IsString(tcn)) snprintf(out->edi.tcn, sizeof out->edi.tcn, "%s", tcn->valuestring);
            out->edi.total_actual = cJSON_GetObjectItemCaseSensitive(root, "TotalActual")->valuedouble;
            cJSON *claims = cJSON_GetObjectItemCaseSensitive(root, "Claims");
            if (cJSON_IsArray(claims)) {
                int nc = cJSON_GetArraySize(claims); if (nc > 6) nc = 6;
                out->edi.claim_count = nc;
                for (int c = 0; c < nc; c++) {
                    cJSON *co = cJSON_GetArrayItem(claims, c);
                    claim_t *cl = &out->edi.claims[c];
                    cJSON *cid = cJSON_GetObjectItemCaseSensitive(co, "ClaimId");
                    cJSON *pn = cJSON_GetObjectItemCaseSensitive(co, "PatientName");
                    if (cJSON_IsString(cid)) snprintf(cl->claim_id, sizeof cl->claim_id, "%s", cid->valuestring);
                    if (cJSON_IsString(pn)) snprintf(cl->patient_name, sizeof cl->patient_name, "%s", pn->valuestring);
                    cl->total_charge = cJSON_GetObjectItemCaseSensitive(co, "TotalCharge")->valuedouble;
                    cl->payment = cJSON_GetObjectItemCaseSensitive(co, "Payment")->valuedouble;
                    cJSON *lines = cJSON_GetObjectItemCaseSensitive(co, "Lines");
                    int nl = cJSON_IsArray(lines) ? cJSON_GetArraySize(lines) : 0; if (nl > 4) nl = 4;
                    cl->line_count = nl;
                    for (int L = 0; L < nl; L++) {
                        cJSON *lo = cJSON_GetArrayItem(lines, L);
                        cJSON *sc = cJSON_GetObjectItemCaseSensitive(lo, "ServiceCode");
                        if (cJSON_IsString(sc)) snprintf(cl->lines[L].service_code, sizeof cl->lines[L].service_code, "%s", sc->valuestring);
                        cl->lines[L].charge = cJSON_GetObjectItemCaseSensitive(lo, "Charge")->valuedouble;
                        cl->lines[L].adjudicated = cJSON_GetObjectItemCaseSensitive(lo, "Adjudicated")->valuedouble;
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
    cJSON *root = fx_to_json(fx);
    if (!root) return -1;
    char *s = cJSON_PrintUnformatted(root);
    cJSON_Delete(root);
    if (!s) return -1;
    size_t n = strlen(s);
    if (n >= cap) { free(s); return -1; }
    memcpy(buf, s, n);
    *ol = n;
    free(s);
    return 0;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    char *tmp = (char *)malloc(len + 1);
    if (!tmp) return -1;
    memcpy(tmp, buf, len); tmp[len] = 0;
    cJSON *root = cJSON_Parse(tmp);
    free(tmp);
    if (!root) return -1;
    int rc = json_to_fx(root, out, kind);
    cJSON_Delete(root);
    return rc;
}

void bench_register_cjson(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "cJSON", cJSON_Version(), "json", prep, ser, de, fidelity_fx);
}
