#include "ser_common.h"
#include <bson/bson.h>

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    bson_t b = BSON_INITIALIZER;
    BSON_APPEND_INT32(&b, "kind", (int32_t)fx->kind);
    switch (fx->kind) {
        case TD_INTEGER:
            BSON_APPEND_INT32(&b, "value", fx->integer_val);
            break;
        case TD_SIMPLE:
            BSON_APPEND_INT32(&b, "Id", fx->simple.id);
            BSON_APPEND_UTF8(&b, "Name", fx->simple.name);
            BSON_APPEND_UTF8(&b, "Timestamp", fx->simple.timestamp);
            BSON_APPEND_BOOL(&b, "IsActive", fx->simple.is_active);
            break;
        case TD_PERSON:
            BSON_APPEND_UTF8(&b, "FirstName", fx->person.first_name);
            BSON_APPEND_UTF8(&b, "LastName", fx->person.last_name);
            BSON_APPEND_INT32(&b, "Age", fx->person.age);
            BSON_APPEND_INT32(&b, "Gender", fx->person.gender);
            BSON_APPEND_INT32(&b, "PoliceCount", fx->person.police_count);
            break;
        case TD_TELEMETRY:
            BSON_APPEND_UTF8(&b, "Id", fx->telemetry.id);
            BSON_APPEND_INT32(&b, "Param1", fx->telemetry.param1);
            BSON_APPEND_INT32(&b, "MeasCount", fx->telemetry.meas_count);
            break;
        case TD_STRING_ARRAY: {
            BSON_APPEND_INT32(&b, "Count", fx->string_array.count);
            bson_t arr;
            bson_append_array_begin(&b, "Items", -1, &arr);
            for (int i = 0; i < fx->string_array.count && i < 100; i++) {
                char key[16];
                snprintf(key, sizeof key, "%d", i);
                BSON_APPEND_UTF8(&arr, key, fx->string_array.items[i]);
            }
            bson_append_array_end(&b, &arr);
            break;
        }
        case TD_EDI835:
            BSON_APPEND_UTF8(&b, "PayerName", fx->edi.payer_name);
            BSON_APPEND_UTF8(&b, "PayeeName", fx->edi.payee_name);
            BSON_APPEND_INT32(&b, "ClaimCount", fx->edi.claim_count);
            BSON_APPEND_DOUBLE(&b, "TotalActual", fx->edi.total_actual);
            break;
        default:
            bson_destroy(&b);
            return -1;
    }
    if (b.len > cap) { bson_destroy(&b); return -1; }
    memcpy(buf, bson_get_data(&b), b.len);
    *ol = b.len;
    bson_destroy(&b);
    return 0;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    bson_t b;
    if (!bson_init_static(&b, buf, len)) return -1;
    bson_iter_t it;
    if (!bson_iter_init_find(&it, &b, "kind") || !BSON_ITER_HOLDS_INT32(&it) ||
        bson_iter_int32(&it) != (int32_t)kind) return -1;
    out->kind = kind;
    out->name = test_data_name(kind);
    switch (kind) {
        case TD_INTEGER:
            if (!bson_iter_init_find(&it, &b, "value")) return -1;
            out->integer_val = bson_iter_int32(&it);
            break;
        case TD_SIMPLE:
            if (bson_iter_init_find(&it, &b, "Id")) out->simple.id = bson_iter_int32(&it);
            if (bson_iter_init_find(&it, &b, "Name"))
                snprintf(out->simple.name, sizeof out->simple.name, "%s", bson_iter_utf8(&it, NULL));
            if (bson_iter_init_find(&it, &b, "Timestamp"))
                snprintf(out->simple.timestamp, sizeof out->simple.timestamp, "%s", bson_iter_utf8(&it, NULL));
            if (bson_iter_init_find(&it, &b, "IsActive")) out->simple.is_active = bson_iter_bool(&it);
            break;
        case TD_PERSON:
            if (bson_iter_init_find(&it, &b, "FirstName"))
                snprintf(out->person.first_name, sizeof out->person.first_name, "%s", bson_iter_utf8(&it, NULL));
            if (bson_iter_init_find(&it, &b, "LastName"))
                snprintf(out->person.last_name, sizeof out->person.last_name, "%s", bson_iter_utf8(&it, NULL));
            if (bson_iter_init_find(&it, &b, "Age")) out->person.age = bson_iter_int32(&it);
            if (bson_iter_init_find(&it, &b, "Gender")) out->person.gender = bson_iter_int32(&it);
            if (bson_iter_init_find(&it, &b, "PoliceCount")) out->person.police_count = bson_iter_int32(&it);
            break;
        case TD_TELEMETRY:
            if (bson_iter_init_find(&it, &b, "Id"))
                snprintf(out->telemetry.id, sizeof out->telemetry.id, "%s", bson_iter_utf8(&it, NULL));
            if (bson_iter_init_find(&it, &b, "Param1")) out->telemetry.param1 = bson_iter_int32(&it);
            if (bson_iter_init_find(&it, &b, "MeasCount")) out->telemetry.meas_count = bson_iter_int32(&it);
            break;
        case TD_STRING_ARRAY:
            if (bson_iter_init_find(&it, &b, "Count")) out->string_array.count = bson_iter_int32(&it);
            if (bson_iter_init_find(&it, &b, "Items") && BSON_ITER_HOLDS_ARRAY(&it)) {
                bson_iter_t arr;
                if (bson_iter_recurse(&it, &arr)) {
                    int i = 0;
                    while (bson_iter_next(&arr) && i < out->string_array.count && i < 100) {
                        if (BSON_ITER_HOLDS_UTF8(&arr))
                            snprintf(out->string_array.items[i], sizeof out->string_array.items[i], "%s",
                                     bson_iter_utf8(&arr, NULL));
                        i++;
                    }
                }
            }
            break;
        case TD_EDI835:
            if (bson_iter_init_find(&it, &b, "PayerName"))
                snprintf(out->edi.payer_name, sizeof out->edi.payer_name, "%s", bson_iter_utf8(&it, NULL));
            if (bson_iter_init_find(&it, &b, "PayeeName"))
                snprintf(out->edi.payee_name, sizeof out->edi.payee_name, "%s", bson_iter_utf8(&it, NULL));
            if (bson_iter_init_find(&it, &b, "ClaimCount")) out->edi.claim_count = bson_iter_int32(&it);
            if (bson_iter_init_find(&it, &b, "TotalActual")) out->edi.total_actual = bson_iter_double(&it);
            break;
        default: return -1;
    }
    return 0;
}

void bench_register_libbson(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "libbson", BSON_VERSION_S, "binary", prep, ser, de, fidelity_fx);
}
