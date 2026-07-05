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
        case TD_SIMPLE: {
            cJSON_AddNumberToObject(root, "Id", fx->simple.id);
            cJSON_AddStringToObject(root, "Name", fx->simple.name);
            cJSON_AddStringToObject(root, "Timestamp", fx->simple.timestamp);
            cJSON_AddBoolToObject(root, "IsActive", fx->simple.is_active);
            break;
        }
        case TD_PERSON: {
            cJSON_AddStringToObject(root, "FirstName", fx->person.first_name);
            cJSON_AddStringToObject(root, "LastName", fx->person.last_name);
            cJSON_AddNumberToObject(root, "Age", fx->person.age);
            cJSON_AddNumberToObject(root, "Gender", fx->person.gender);
            cJSON_AddStringToObject(root, "PassportNumber", fx->person.passport_number);
            cJSON_AddStringToObject(root, "PassportAuthority", fx->person.passport_authority);
            cJSON_AddNumberToObject(root, "PoliceCount", fx->person.police_count);
            break;
        }
        case TD_TELEMETRY: {
            cJSON_AddStringToObject(root, "Id", fx->telemetry.id);
            cJSON_AddStringToObject(root, "DataSource", fx->telemetry.data_source);
            cJSON_AddNumberToObject(root, "Param1", fx->telemetry.param1);
            cJSON_AddNumberToObject(root, "Param2", fx->telemetry.param2);
            cJSON_AddNumberToObject(root, "MeasCount", fx->telemetry.meas_count);
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
            cJSON_AddNumberToObject(root, "ClaimCount", fx->edi.claim_count);
            cJSON_AddNumberToObject(root, "TotalActual", fx->edi.total_actual);
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
            cJSON *age = cJSON_GetObjectItemCaseSensitive(root, "Age");
            cJSON *g = cJSON_GetObjectItemCaseSensitive(root, "Gender");
            cJSON *pc = cJSON_GetObjectItemCaseSensitive(root, "PoliceCount");
            if (!cJSON_IsString(fn) || !cJSON_IsString(ln) || !cJSON_IsNumber(age)) return -1;
            snprintf(out->person.first_name, sizeof out->person.first_name, "%s", fn->valuestring);
            snprintf(out->person.last_name, sizeof out->person.last_name, "%s", ln->valuestring);
            out->person.age = (int)age->valuedouble;
            out->person.gender = cJSON_IsNumber(g) ? (int)g->valuedouble : 0;
            out->person.police_count = cJSON_IsNumber(pc) ? (int)pc->valuedouble : 0;
            break;
        }
        case TD_TELEMETRY: {
            cJSON *id = cJSON_GetObjectItemCaseSensitive(root, "Id");
            cJSON *p1 = cJSON_GetObjectItemCaseSensitive(root, "Param1");
            cJSON *mc = cJSON_GetObjectItemCaseSensitive(root, "MeasCount");
            if (!cJSON_IsString(id)) return -1;
            snprintf(out->telemetry.id, sizeof out->telemetry.id, "%s", id->valuestring);
            out->telemetry.param1 = cJSON_IsNumber(p1) ? (int)p1->valuedouble : 0;
            out->telemetry.meas_count = cJSON_IsNumber(mc) ? (int)mc->valuedouble : 0;
            break;
        }
        case TD_STRING_ARRAY: {
            cJSON *c = cJSON_GetObjectItemCaseSensitive(root, "Count");
            cJSON *items = cJSON_GetObjectItemCaseSensitive(root, "Items");
            if (!cJSON_IsNumber(c)) return -1;
            out->string_array.count = (int)c->valuedouble;
            if (out->string_array.count < 0 || out->string_array.count > 100) return -1;
            if (cJSON_IsArray(items)) {
                int n = cJSON_GetArraySize(items);
                if (n > out->string_array.count) n = out->string_array.count;
                for (int i = 0; i < n; i++) {
                    cJSON *it = cJSON_GetArrayItem(items, i);
                    if (cJSON_IsString(it))
                        snprintf(out->string_array.items[i], sizeof out->string_array.items[i], "%s", it->valuestring);
                }
            }
            break;
        }
        case TD_EDI835: {
            cJSON *p = cJSON_GetObjectItemCaseSensitive(root, "PayerName");
            cJSON *q = cJSON_GetObjectItemCaseSensitive(root, "PayeeName");
            cJSON *cc = cJSON_GetObjectItemCaseSensitive(root, "ClaimCount");
            cJSON *ta = cJSON_GetObjectItemCaseSensitive(root, "TotalActual");
            if (!cJSON_IsString(p)) return -1;
            snprintf(out->edi.payer_name, sizeof out->edi.payer_name, "%s", p->valuestring);
            if (cJSON_IsString(q)) snprintf(out->edi.payee_name, sizeof out->edi.payee_name, "%s", q->valuestring);
            out->edi.claim_count = cJSON_IsNumber(cc) ? (int)cc->valuedouble : 0;
            out->edi.total_actual = cJSON_IsNumber(ta) ? ta->valuedouble : 0;
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
    buf[n] = 0;
    *ol = n;
    free(s);
    return 0;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    char *tmp = (char *)malloc(len + 1);
    if (!tmp) return -1;
    memcpy(tmp, buf, len);
    tmp[len] = 0;
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
