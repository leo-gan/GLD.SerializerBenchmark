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
        case TD_PERSON:
            json_object_set_new(root, "FirstName", json_string(fx->person.first_name));
            json_object_set_new(root, "LastName", json_string(fx->person.last_name));
            json_object_set_new(root, "Age", json_integer(fx->person.age));
            json_object_set_new(root, "Gender", json_integer(fx->person.gender));
            json_object_set_new(root, "PoliceCount", json_integer(fx->person.police_count));
            break;
        case TD_TELEMETRY:
            json_object_set_new(root, "Id", json_string(fx->telemetry.id));
            json_object_set_new(root, "Param1", json_integer(fx->telemetry.param1));
            json_object_set_new(root, "MeasCount", json_integer(fx->telemetry.meas_count));
            break;
        case TD_STRING_ARRAY: {
            json_object_set_new(root, "Count", json_integer(fx->string_array.count));
            json_t *arr = json_array();
            for (int i = 0; i < fx->string_array.count && i < 100; i++)
                json_array_append_new(arr, json_string(fx->string_array.items[i]));
            json_object_set_new(root, "Items", arr);
            break;
        }
        case TD_EDI835:
            json_object_set_new(root, "PayerName", json_string(fx->edi.payer_name));
            json_object_set_new(root, "PayeeName", json_string(fx->edi.payee_name));
            json_object_set_new(root, "ClaimCount", json_integer(fx->edi.claim_count));
            json_object_set_new(root, "TotalActual", json_real(fx->edi.total_actual));
            break;
        default:
            json_decref(root);
            return NULL;
    }
    return root;
}

static int json_to_fx(json_t *root, test_fixture_t *out, test_data_kind_t kind) {
    json_t *kv = json_object_get(root, "kind");
    if (!json_is_integer(kv) || (int)json_integer_value(kv) != (int)kind) return -1;
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
            out->person.police_count = (int)json_integer_value(json_object_get(root, "PoliceCount"));
            break;
        }
        case TD_TELEMETRY: {
            const char *id = json_string_value(json_object_get(root, "Id"));
            if (!id) return -1;
            snprintf(out->telemetry.id, sizeof out->telemetry.id, "%s", id);
            out->telemetry.param1 = (int)json_integer_value(json_object_get(root, "Param1"));
            out->telemetry.meas_count = (int)json_integer_value(json_object_get(root, "MeasCount"));
            break;
        }
        case TD_STRING_ARRAY: {
            out->string_array.count = (int)json_integer_value(json_object_get(root, "Count"));
            if (out->string_array.count < 0 || out->string_array.count > 100) return -1;
            json_t *items = json_object_get(root, "Items");
            if (json_is_array(items)) {
                size_t n = json_array_size(items);
                if ((int)n > out->string_array.count) n = (size_t)out->string_array.count;
                for (size_t i = 0; i < n; i++) {
                    const char *s = json_string_value(json_array_get(items, i));
                    if (s) snprintf(out->string_array.items[i], sizeof out->string_array.items[i], "%s", s);
                }
            }
            break;
        }
        case TD_EDI835: {
            const char *p = json_string_value(json_object_get(root, "PayerName"));
            const char *q = json_string_value(json_object_get(root, "PayeeName"));
            if (!p) return -1;
            snprintf(out->edi.payer_name, sizeof out->edi.payer_name, "%s", p);
            if (q) snprintf(out->edi.payee_name, sizeof out->edi.payee_name, "%s", q);
            out->edi.claim_count = (int)json_integer_value(json_object_get(root, "ClaimCount"));
            out->edi.total_actual = json_real_value(json_object_get(root, "TotalActual"));
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
