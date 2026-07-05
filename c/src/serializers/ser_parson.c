#include "ser_common.h"
#include "parson_pref.h"

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

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
        case TD_PERSON:
            json_object_set_string(root, "FirstName", fx->person.first_name);
            json_object_set_string(root, "LastName", fx->person.last_name);
            json_object_set_number(root, "Age", fx->person.age);
            json_object_set_number(root, "Gender", fx->person.gender);
            json_object_set_number(root, "PoliceCount", fx->person.police_count);
            break;
        case TD_TELEMETRY:
            json_object_set_string(root, "Id", fx->telemetry.id);
            json_object_set_number(root, "Param1", fx->telemetry.param1);
            json_object_set_number(root, "MeasCount", fx->telemetry.meas_count);
            break;
        case TD_STRING_ARRAY: {
            json_object_set_number(root, "Count", fx->string_array.count);
            JSON_Value *arr_v = json_value_init_array();
            JSON_Array *arr = json_value_get_array(arr_v);
            for (int i = 0; i < fx->string_array.count && i < 100; i++)
                json_array_append_string(arr, fx->string_array.items[i]);
            json_object_set_value(root, "Items", arr_v);
            break;
        }
        case TD_EDI835:
            json_object_set_string(root, "PayerName", fx->edi.payer_name);
            json_object_set_string(root, "PayeeName", fx->edi.payee_name);
            json_object_set_number(root, "ClaimCount", fx->edi.claim_count);
            json_object_set_number(root, "TotalActual", fx->edi.total_actual);
            break;
        default:
            json_value_free(root_v);
            return NULL;
    }
    return root_v;
}

static int val_to_fx(JSON_Value *root_v, test_fixture_t *out, test_data_kind_t kind) {
    JSON_Object *root = json_value_get_object(root_v);
    if (!root) return -1;
    if ((int)json_object_get_number(root, "kind") != (int)kind) return -1;
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
            out->person.police_count = (int)json_object_get_number(root, "PoliceCount");
            break;
        }
        case TD_TELEMETRY: {
            const char *id = json_object_get_string(root, "Id");
            if (!id) return -1;
            snprintf(out->telemetry.id, sizeof out->telemetry.id, "%s", id);
            out->telemetry.param1 = (int)json_object_get_number(root, "Param1");
            out->telemetry.meas_count = (int)json_object_get_number(root, "MeasCount");
            break;
        }
        case TD_STRING_ARRAY: {
            out->string_array.count = (int)json_object_get_number(root, "Count");
            if (out->string_array.count < 0 || out->string_array.count > 100) return -1;
            JSON_Array *items = json_object_get_array(root, "Items");
            if (items) {
                size_t n = json_array_get_count(items);
                if ((int)n > out->string_array.count) n = (size_t)out->string_array.count;
                for (size_t i = 0; i < n; i++) {
                    const char *s = json_array_get_string(items, i);
                    if (s) snprintf(out->string_array.items[i], sizeof out->string_array.items[i], "%s", s);
                }
            }
            break;
        }
        case TD_EDI835: {
            const char *p = json_object_get_string(root, "PayerName");
            const char *q = json_object_get_string(root, "PayeeName");
            if (!p) return -1;
            snprintf(out->edi.payer_name, sizeof out->edi.payer_name, "%s", p);
            if (q) snprintf(out->edi.payee_name, sizeof out->edi.payee_name, "%s", q);
            out->edi.claim_count = (int)json_object_get_number(root, "ClaimCount");
            out->edi.total_actual = json_object_get_number(root, "TotalActual");
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
    memcpy(tmp, buf, len);
    tmp[len] = 0;
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
