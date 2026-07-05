#include "ser_common.h"
#include <json-c/json.h>

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

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
        case TD_PERSON:
            json_object_object_add(root, "FirstName", json_object_new_string(fx->person.first_name));
            json_object_object_add(root, "LastName", json_object_new_string(fx->person.last_name));
            json_object_object_add(root, "Age", json_object_new_int(fx->person.age));
            json_object_object_add(root, "Gender", json_object_new_int(fx->person.gender));
            json_object_object_add(root, "PoliceCount", json_object_new_int(fx->person.police_count));
            break;
        case TD_TELEMETRY:
            json_object_object_add(root, "Id", json_object_new_string(fx->telemetry.id));
            json_object_object_add(root, "Param1", json_object_new_int(fx->telemetry.param1));
            json_object_object_add(root, "MeasCount", json_object_new_int(fx->telemetry.meas_count));
            break;
        case TD_STRING_ARRAY: {
            json_object_object_add(root, "Count", json_object_new_int(fx->string_array.count));
            struct json_object *arr = json_object_new_array();
            for (int i = 0; i < fx->string_array.count && i < 100; i++)
                json_object_array_add(arr, json_object_new_string(fx->string_array.items[i]));
            json_object_object_add(root, "Items", arr);
            break;
        }
        case TD_EDI835:
            json_object_object_add(root, "PayerName", json_object_new_string(fx->edi.payer_name));
            json_object_object_add(root, "PayeeName", json_object_new_string(fx->edi.payee_name));
            json_object_object_add(root, "ClaimCount", json_object_new_int(fx->edi.claim_count));
            json_object_object_add(root, "TotalActual", json_object_new_double(fx->edi.total_actual));
            break;
        default:
            json_object_put(root);
            return NULL;
    }
    return root;
}

static int obj_to_fx(struct json_object *root, test_fixture_t *out, test_data_kind_t kind) {
    struct json_object *kv = NULL;
    if (!json_object_object_get_ex(root, "kind", &kv) || json_object_get_int(kv) != (int)kind) return -1;
    out->kind = kind;
    out->name = test_data_name(kind);
    struct json_object *v;
    switch (kind) {
        case TD_INTEGER:
            json_object_object_get_ex(root, "value", &v);
            out->integer_val = json_object_get_int(v);
            break;
        case TD_SIMPLE:
            json_object_object_get_ex(root, "Id", &v); out->simple.id = json_object_get_int(v);
            json_object_object_get_ex(root, "Name", &v);
            if (!v) return -1;
            snprintf(out->simple.name, sizeof out->simple.name, "%s", json_object_get_string(v));
            if (json_object_object_get_ex(root, "Timestamp", &v))
                snprintf(out->simple.timestamp, sizeof out->simple.timestamp, "%s", json_object_get_string(v));
            json_object_object_get_ex(root, "IsActive", &v);
            out->simple.is_active = json_object_get_boolean(v);
            break;
        case TD_PERSON:
            json_object_object_get_ex(root, "FirstName", &v);
            if (!v) return -1;
            snprintf(out->person.first_name, sizeof out->person.first_name, "%s", json_object_get_string(v));
            json_object_object_get_ex(root, "LastName", &v);
            snprintf(out->person.last_name, sizeof out->person.last_name, "%s", json_object_get_string(v));
            json_object_object_get_ex(root, "Age", &v); out->person.age = json_object_get_int(v);
            json_object_object_get_ex(root, "Gender", &v); out->person.gender = json_object_get_int(v);
            json_object_object_get_ex(root, "PoliceCount", &v); out->person.police_count = json_object_get_int(v);
            break;
        case TD_TELEMETRY:
            json_object_object_get_ex(root, "Id", &v);
            if (!v) return -1;
            snprintf(out->telemetry.id, sizeof out->telemetry.id, "%s", json_object_get_string(v));
            json_object_object_get_ex(root, "Param1", &v); out->telemetry.param1 = json_object_get_int(v);
            json_object_object_get_ex(root, "MeasCount", &v); out->telemetry.meas_count = json_object_get_int(v);
            break;
        case TD_STRING_ARRAY:
            json_object_object_get_ex(root, "Count", &v);
            out->string_array.count = json_object_get_int(v);
            if (out->string_array.count < 0 || out->string_array.count > 100) return -1;
            if (json_object_object_get_ex(root, "Items", &v) && json_object_is_type(v, json_type_array)) {
                int n = json_object_array_length(v);
                if (n > out->string_array.count) n = out->string_array.count;
                for (int i = 0; i < n; i++) {
                    struct json_object *it = json_object_array_get_idx(v, i);
                    snprintf(out->string_array.items[i], sizeof out->string_array.items[i], "%s",
                             json_object_get_string(it));
                }
            }
            break;
        case TD_EDI835:
            json_object_object_get_ex(root, "PayerName", &v);
            if (!v) return -1;
            snprintf(out->edi.payer_name, sizeof out->edi.payer_name, "%s", json_object_get_string(v));
            if (json_object_object_get_ex(root, "PayeeName", &v))
                snprintf(out->edi.payee_name, sizeof out->edi.payee_name, "%s", json_object_get_string(v));
            json_object_object_get_ex(root, "ClaimCount", &v); out->edi.claim_count = json_object_get_int(v);
            json_object_object_get_ex(root, "TotalActual", &v); out->edi.total_actual = json_object_get_double(v);
            break;
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
