#include "ser_common.h"
#include "tinycbor_pref.h"

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static CborError enc_fx(CborEncoder *enc, const test_fixture_t *fx) {
    CborEncoder map;
    int pairs = 1;
    switch (fx->kind) {
        case TD_INTEGER: pairs = 2; break;
        case TD_SIMPLE: pairs = 5; break;
        case TD_PERSON: pairs = 6; break;
        case TD_TELEMETRY: pairs = 4; break;
        case TD_STRING_ARRAY: pairs = 3; break;
        case TD_EDI835: pairs = 5; break;
        default: return CborErrorImproperValue;
    }
    CborError err = cbor_encoder_create_map(enc, &map, pairs);
    if (err) return err;
    err |= cbor_encode_text_stringz(&map, "kind");
    err |= cbor_encode_int(&map, (int64_t)fx->kind);
    switch (fx->kind) {
        case TD_INTEGER:
            err |= cbor_encode_text_stringz(&map, "value");
            err |= cbor_encode_int(&map, fx->integer_val);
            break;
        case TD_SIMPLE:
            err |= cbor_encode_text_stringz(&map, "Id"); err |= cbor_encode_int(&map, fx->simple.id);
            err |= cbor_encode_text_stringz(&map, "Name"); err |= cbor_encode_text_stringz(&map, fx->simple.name);
            err |= cbor_encode_text_stringz(&map, "Timestamp"); err |= cbor_encode_text_stringz(&map, fx->simple.timestamp);
            err |= cbor_encode_text_stringz(&map, "IsActive"); err |= cbor_encode_boolean(&map, fx->simple.is_active);
            break;
        case TD_PERSON:
            err |= cbor_encode_text_stringz(&map, "FirstName"); err |= cbor_encode_text_stringz(&map, fx->person.first_name);
            err |= cbor_encode_text_stringz(&map, "LastName"); err |= cbor_encode_text_stringz(&map, fx->person.last_name);
            err |= cbor_encode_text_stringz(&map, "Age"); err |= cbor_encode_int(&map, fx->person.age);
            err |= cbor_encode_text_stringz(&map, "Gender"); err |= cbor_encode_int(&map, fx->person.gender);
            err |= cbor_encode_text_stringz(&map, "PoliceCount"); err |= cbor_encode_int(&map, fx->person.police_count);
            break;
        case TD_TELEMETRY:
            err |= cbor_encode_text_stringz(&map, "Id"); err |= cbor_encode_text_stringz(&map, fx->telemetry.id);
            err |= cbor_encode_text_stringz(&map, "Param1"); err |= cbor_encode_int(&map, fx->telemetry.param1);
            err |= cbor_encode_text_stringz(&map, "MeasCount"); err |= cbor_encode_int(&map, fx->telemetry.meas_count);
            break;
        case TD_STRING_ARRAY: {
            err |= cbor_encode_text_stringz(&map, "Count"); err |= cbor_encode_int(&map, fx->string_array.count);
            err |= cbor_encode_text_stringz(&map, "Items");
            CborEncoder arr;
            err |= cbor_encoder_create_array(&map, &arr, (size_t)fx->string_array.count);
            for (int i = 0; i < fx->string_array.count && i < 100; i++)
                err |= cbor_encode_text_stringz(&arr, fx->string_array.items[i]);
            err |= cbor_encoder_close_container(&map, &arr);
            break;
        }
        case TD_EDI835:
            err |= cbor_encode_text_stringz(&map, "PayerName"); err |= cbor_encode_text_stringz(&map, fx->edi.payer_name);
            err |= cbor_encode_text_stringz(&map, "PayeeName"); err |= cbor_encode_text_stringz(&map, fx->edi.payee_name);
            err |= cbor_encode_text_stringz(&map, "ClaimCount"); err |= cbor_encode_int(&map, fx->edi.claim_count);
            err |= cbor_encode_text_stringz(&map, "TotalActual"); err |= cbor_encode_double(&map, fx->edi.total_actual);
            break;
        default: break;
    }
    err |= cbor_encoder_close_container(enc, &map);
    return err;
}

static int find_key(CborValue *map, const char *key, CborValue *out) {
    CborValue it = *map;
    while (!cbor_value_at_end(&it)) {
        char buf[64];
        size_t n = sizeof buf;
        if (!cbor_value_is_text_string(&it)) return -1;
        if (cbor_value_copy_text_string(&it, buf, &n, &it) != CborNoError) return -1;
        if (strcmp(buf, key) == 0) { *out = it; return 0; }
        if (cbor_value_advance(&it) != CborNoError) return -1;
    }
    return -1;
}

static int get_int_key(CborValue *map, const char *key, int *v) {
    CborValue val;
    if (find_key(map, key, &val)) return -1;
    int64_t x;
    if (cbor_value_get_int64(&val, &x) != CborNoError) return -1;
    *v = (int)x;
    return 0;
}

static int get_str_key(CborValue *map, const char *key, char *dst, size_t dstsz) {
    CborValue val;
    if (find_key(map, key, &val)) return -1;
    size_t n = dstsz;
    if (cbor_value_copy_text_string(&val, dst, &n, NULL) != CborNoError) return -1;
    return 0;
}

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    CborEncoder enc;
    cbor_encoder_init(&enc, buf, cap, 0);
    if (enc_fx(&enc, fx) != CborNoError) return -1;
    *ol = cbor_encoder_get_buffer_size(&enc, buf);
    return 0;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    CborParser parser;
    CborValue root, map;
    if (cbor_parser_init(buf, len, 0, &parser, &root) != CborNoError) return -1;
    if (!cbor_value_is_map(&root)) return -1;
    if (cbor_value_enter_container(&root, &map) != CborNoError) return -1;
    int k = -1;
    if (get_int_key(&map, "kind", &k) || k != (int)kind) return -1;
    out->kind = kind;
    out->name = test_data_name(kind);
    switch (kind) {
        case TD_INTEGER:
            return get_int_key(&map, "value", &out->integer_val);
        case TD_SIMPLE:
            if (get_int_key(&map, "Id", &out->simple.id)) return -1;
            if (get_str_key(&map, "Name", out->simple.name, sizeof out->simple.name)) return -1;
            get_str_key(&map, "Timestamp", out->simple.timestamp, sizeof out->simple.timestamp);
            {
                CborValue v; bool b = false;
                if (!find_key(&map, "IsActive", &v)) cbor_value_get_boolean(&v, &b);
                out->simple.is_active = b;
            }
            return 0;
        case TD_PERSON:
            if (get_str_key(&map, "FirstName", out->person.first_name, sizeof out->person.first_name)) return -1;
            if (get_str_key(&map, "LastName", out->person.last_name, sizeof out->person.last_name)) return -1;
            get_int_key(&map, "Age", &out->person.age);
            get_int_key(&map, "Gender", &out->person.gender);
            get_int_key(&map, "PoliceCount", &out->person.police_count);
            return 0;
        case TD_TELEMETRY:
            if (get_str_key(&map, "Id", out->telemetry.id, sizeof out->telemetry.id)) return -1;
            get_int_key(&map, "Param1", &out->telemetry.param1);
            get_int_key(&map, "MeasCount", &out->telemetry.meas_count);
            return 0;
        case TD_STRING_ARRAY: {
            get_int_key(&map, "Count", &out->string_array.count);
            CborValue items, it;
            if (find_key(&map, "Items", &items)) return 0;
            if (!cbor_value_is_array(&items)) return -1;
            if (cbor_value_enter_container(&items, &it) != CborNoError) return -1;
            int i = 0;
            while (!cbor_value_at_end(&it) && i < out->string_array.count && i < 100) {
                size_t n = sizeof out->string_array.items[i];
                if (cbor_value_copy_text_string(&it, out->string_array.items[i], &n, &it) != CborNoError) return -1;
                i++;
            }
            return 0;
        }
        case TD_EDI835: {
            if (get_str_key(&map, "PayerName", out->edi.payer_name, sizeof out->edi.payer_name)) return -1;
            get_str_key(&map, "PayeeName", out->edi.payee_name, sizeof out->edi.payee_name);
            get_int_key(&map, "ClaimCount", &out->edi.claim_count);
            CborValue v;
            if (!find_key(&map, "TotalActual", &v)) cbor_value_get_double(&v, &out->edi.total_actual);
            return 0;
        }
        default: return -1;
    }
}

void bench_register_tinycbor(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "tinycbor", "0.6.0", "binary", prep, ser, de, fidelity_fx);
}
