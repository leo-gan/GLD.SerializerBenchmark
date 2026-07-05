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
        case TD_PERSON:
            yyjson_mut_obj_add_strcpy(doc, root, "FirstName", fx->person.first_name);
            yyjson_mut_obj_add_strcpy(doc, root, "LastName", fx->person.last_name);
            yyjson_mut_obj_add_int(doc, root, "Age", fx->person.age);
            yyjson_mut_obj_add_int(doc, root, "Gender", fx->person.gender);
            yyjson_mut_obj_add_int(doc, root, "PoliceCount", fx->person.police_count);
            break;
        case TD_TELEMETRY:
            yyjson_mut_obj_add_strcpy(doc, root, "Id", fx->telemetry.id);
            yyjson_mut_obj_add_int(doc, root, "Param1", fx->telemetry.param1);
            yyjson_mut_obj_add_int(doc, root, "MeasCount", fx->telemetry.meas_count);
            break;
        case TD_STRING_ARRAY: {
            yyjson_mut_obj_add_int(doc, root, "Count", fx->string_array.count);
            yyjson_mut_val *arr = yyjson_mut_arr(doc);
            for (int i = 0; i < fx->string_array.count && i < 100; i++)
                yyjson_mut_arr_add_strcpy(doc, arr, fx->string_array.items[i]);
            yyjson_mut_obj_add_val(doc, root, "Items", arr);
            break;
        }
        case TD_EDI835:
            yyjson_mut_obj_add_strcpy(doc, root, "PayerName", fx->edi.payer_name);
            yyjson_mut_obj_add_strcpy(doc, root, "PayeeName", fx->edi.payee_name);
            yyjson_mut_obj_add_int(doc, root, "ClaimCount", fx->edi.claim_count);
            yyjson_mut_obj_add_real(doc, root, "TotalActual", fx->edi.total_actual);
            break;
        default:
            yyjson_mut_doc_free(doc);
            return NULL;
    }
    return doc;
}

static int doc_to_fx(yyjson_val *root, test_fixture_t *out, test_data_kind_t kind) {
    yyjson_val *kv = yyjson_obj_get(root, "kind");
    if (!yyjson_is_int(kv) || (int)yyjson_get_int(kv) != (int)kind) return -1;
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
            out->person.police_count = (int)yyjson_get_int(yyjson_obj_get(root, "PoliceCount"));
            break;
        }
        case TD_TELEMETRY: {
            const char *id = yyjson_get_str(yyjson_obj_get(root, "Id"));
            if (!id) return -1;
            snprintf(out->telemetry.id, sizeof out->telemetry.id, "%s", id);
            out->telemetry.param1 = (int)yyjson_get_int(yyjson_obj_get(root, "Param1"));
            out->telemetry.meas_count = (int)yyjson_get_int(yyjson_obj_get(root, "MeasCount"));
            break;
        }
        case TD_STRING_ARRAY: {
            out->string_array.count = (int)yyjson_get_int(yyjson_obj_get(root, "Count"));
            if (out->string_array.count < 0 || out->string_array.count > 100) return -1;
            yyjson_val *items = yyjson_obj_get(root, "Items");
            if (yyjson_is_arr(items)) {
                size_t idx, max;
                yyjson_val *it;
                yyjson_arr_foreach(items, idx, max, it) {
                    if ((int)idx >= out->string_array.count) break;
                    const char *s = yyjson_get_str(it);
                    if (s) snprintf(out->string_array.items[idx], sizeof out->string_array.items[idx], "%s", s);
                }
            }
            break;
        }
        case TD_EDI835: {
            const char *p = yyjson_get_str(yyjson_obj_get(root, "PayerName"));
            const char *q = yyjson_get_str(yyjson_obj_get(root, "PayeeName"));
            if (!p) return -1;
            snprintf(out->edi.payer_name, sizeof out->edi.payer_name, "%s", p);
            if (q) snprintf(out->edi.payee_name, sizeof out->edi.payee_name, "%s", q);
            out->edi.claim_count = (int)yyjson_get_int(yyjson_obj_get(root, "ClaimCount"));
            out->edi.total_actual = yyjson_get_real(yyjson_obj_get(root, "TotalActual"));
            break;
        }
        default: return -1;
    }
    return 0;
}

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    yyjson_mut_doc *doc = fx_to_doc(fx);
    if (!doc) return -1;
    size_t len = 0;
    char *s = yyjson_mut_write(doc, 0, &len);
    yyjson_mut_doc_free(doc);
    if (!s) return -1;
    if (len >= cap) { free(s); return -1; }
    memcpy(buf, s, len);
    *ol = len;
    free(s);
    return 0;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    yyjson_doc *doc = yyjson_read((const char *)buf, len, 0);
    if (!doc) return -1;
    int rc = doc_to_fx(yyjson_doc_get_root(doc), out, kind);
    yyjson_doc_free(doc);
    return rc;
}

void bench_register_yyjson(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "yyjson", YYJSON_VERSION_STRING, "json", prep, ser, de, fidelity_fx);
}
