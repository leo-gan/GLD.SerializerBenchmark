#include "ser_common.h"
#include <msgpack.h>

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    msgpack_sbuffer sbuf;
    msgpack_sbuffer_init(&sbuf);
    msgpack_packer pk;
    msgpack_packer_init(&pk, &sbuf, msgpack_sbuffer_write);

    /* count pairs */
    int pairs = 1; /* kind */
    switch (fx->kind) {
        case TD_INTEGER: pairs += 1; break;
        case TD_SIMPLE: pairs += 4; break;
        case TD_PERSON: pairs += 5; break;
        case TD_TELEMETRY: pairs += 3; break;
        case TD_STRING_ARRAY: pairs += 2; break;
        case TD_EDI835: pairs += 4; break;
        default: msgpack_sbuffer_destroy(&sbuf); return -1;
    }
    msgpack_pack_map(&pk, (size_t)pairs);
    msgpack_pack_str(&pk, 4); msgpack_pack_str_body(&pk, "kind", 4);
    msgpack_pack_int(&pk, (int)fx->kind);

    #define PACK_STR_KV(k, v) do { \
        msgpack_pack_str(&pk, strlen(k)); msgpack_pack_str_body(&pk, k, strlen(k)); \
        msgpack_pack_str(&pk, strlen(v)); msgpack_pack_str_body(&pk, v, strlen(v)); \
    } while (0)
    #define PACK_INT_KV(k, v) do { \
        msgpack_pack_str(&pk, strlen(k)); msgpack_pack_str_body(&pk, k, strlen(k)); \
        msgpack_pack_int(&pk, (int)(v)); \
    } while (0)

    switch (fx->kind) {
        case TD_INTEGER:
            PACK_INT_KV("value", fx->integer_val);
            break;
        case TD_SIMPLE:
            PACK_INT_KV("Id", fx->simple.id);
            PACK_STR_KV("Name", fx->simple.name);
            PACK_STR_KV("Timestamp", fx->simple.timestamp);
            msgpack_pack_str(&pk, 8); msgpack_pack_str_body(&pk, "IsActive", 8);
            if (fx->simple.is_active) msgpack_pack_true(&pk); else msgpack_pack_false(&pk);
            break;
        case TD_PERSON:
            PACK_STR_KV("FirstName", fx->person.first_name);
            PACK_STR_KV("LastName", fx->person.last_name);
            PACK_INT_KV("Age", fx->person.age);
            PACK_INT_KV("Gender", fx->person.gender);
            PACK_INT_KV("PoliceCount", fx->person.police_count);
            break;
        case TD_TELEMETRY:
            PACK_STR_KV("Id", fx->telemetry.id);
            PACK_INT_KV("Param1", fx->telemetry.param1);
            PACK_INT_KV("MeasCount", fx->telemetry.meas_count);
            break;
        case TD_STRING_ARRAY:
            PACK_INT_KV("Count", fx->string_array.count);
            msgpack_pack_str(&pk, 5); msgpack_pack_str_body(&pk, "Items", 5);
            msgpack_pack_array(&pk, (size_t)fx->string_array.count);
            for (int i = 0; i < fx->string_array.count && i < 100; i++) {
                size_t n = strlen(fx->string_array.items[i]);
                msgpack_pack_str(&pk, n); msgpack_pack_str_body(&pk, fx->string_array.items[i], n);
            }
            break;
        case TD_EDI835:
            PACK_STR_KV("PayerName", fx->edi.payer_name);
            PACK_STR_KV("PayeeName", fx->edi.payee_name);
            PACK_INT_KV("ClaimCount", fx->edi.claim_count);
            msgpack_pack_str(&pk, 11); msgpack_pack_str_body(&pk, "TotalActual", 11);
            msgpack_pack_double(&pk, fx->edi.total_actual);
            break;
        default: break;
    }

    if (sbuf.size > cap) { msgpack_sbuffer_destroy(&sbuf); return -1; }
    memcpy(buf, sbuf.data, sbuf.size);
    *ol = sbuf.size;
    msgpack_sbuffer_destroy(&sbuf);
    return 0;
}

static int map_get_str(msgpack_object map, const char *key, char *dst, size_t dstsz) {
    if (map.type != MSGPACK_OBJECT_MAP) return -1;
    for (uint32_t i = 0; i < map.via.map.size; i++) {
        msgpack_object k = map.via.map.ptr[i].key;
        if (k.type == MSGPACK_OBJECT_STR && k.via.str.size == strlen(key) &&
            memcmp(k.via.str.ptr, key, k.via.str.size) == 0) {
            msgpack_object v = map.via.map.ptr[i].val;
            if (v.type != MSGPACK_OBJECT_STR) return -1;
            size_t n = v.via.str.size < dstsz - 1 ? v.via.str.size : dstsz - 1;
            memcpy(dst, v.via.str.ptr, n); dst[n] = 0;
            return 0;
        }
    }
    return -1;
}

static int map_get_int(msgpack_object map, const char *key, int *out) {
    if (map.type != MSGPACK_OBJECT_MAP) return -1;
    for (uint32_t i = 0; i < map.via.map.size; i++) {
        msgpack_object k = map.via.map.ptr[i].key;
        if (k.type == MSGPACK_OBJECT_STR && k.via.str.size == strlen(key) &&
            memcmp(k.via.str.ptr, key, k.via.str.size) == 0) {
            msgpack_object v = map.via.map.ptr[i].val;
            if (v.type == MSGPACK_OBJECT_POSITIVE_INTEGER) { *out = (int)v.via.u64; return 0; }
            if (v.type == MSGPACK_OBJECT_NEGATIVE_INTEGER) { *out = (int)v.via.i64; return 0; }
            return -1;
        }
    }
    return -1;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    msgpack_unpacked result;
    msgpack_unpacked_init(&result);
    if (msgpack_unpack_next(&result, (const char *)buf, len, NULL) != MSGPACK_UNPACK_SUCCESS) {
        msgpack_unpacked_destroy(&result);
        return -1;
    }
    msgpack_object root = result.data;
    int k = -1;
    if (map_get_int(root, "kind", &k) || k != (int)kind) {
        msgpack_unpacked_destroy(&result);
        return -1;
    }
    out->kind = kind;
    out->name = test_data_name(kind);
    int rc = 0;
    switch (kind) {
        case TD_INTEGER:
            rc = map_get_int(root, "value", &out->integer_val);
            break;
        case TD_SIMPLE:
            rc |= map_get_int(root, "Id", &out->simple.id);
            rc |= map_get_str(root, "Name", out->simple.name, sizeof out->simple.name);
            map_get_str(root, "Timestamp", out->simple.timestamp, sizeof out->simple.timestamp);
            for (uint32_t i = 0; i < root.via.map.size; i++) {
                msgpack_object key = root.via.map.ptr[i].key;
                if (key.type == MSGPACK_OBJECT_STR && key.via.str.size == 8 &&
                    memcmp(key.via.str.ptr, "IsActive", 8) == 0)
                    out->simple.is_active = root.via.map.ptr[i].val.type == MSGPACK_OBJECT_BOOLEAN &&
                                            root.via.map.ptr[i].val.via.boolean;
            }
            break;
        case TD_PERSON:
            rc |= map_get_str(root, "FirstName", out->person.first_name, sizeof out->person.first_name);
            rc |= map_get_str(root, "LastName", out->person.last_name, sizeof out->person.last_name);
            rc |= map_get_int(root, "Age", &out->person.age);
            map_get_int(root, "Gender", &out->person.gender);
            map_get_int(root, "PoliceCount", &out->person.police_count);
            break;
        case TD_TELEMETRY:
            rc |= map_get_str(root, "Id", out->telemetry.id, sizeof out->telemetry.id);
            map_get_int(root, "Param1", &out->telemetry.param1);
            map_get_int(root, "MeasCount", &out->telemetry.meas_count);
            break;
        case TD_STRING_ARRAY: {
            map_get_int(root, "Count", &out->string_array.count);
            for (uint32_t i = 0; i < root.via.map.size; i++) {
                msgpack_object key = root.via.map.ptr[i].key;
                if (key.type == MSGPACK_OBJECT_STR && key.via.str.size == 5 &&
                    memcmp(key.via.str.ptr, "Items", 5) == 0 &&
                    root.via.map.ptr[i].val.type == MSGPACK_OBJECT_ARRAY) {
                    msgpack_object arr = root.via.map.ptr[i].val;
                    uint32_t n = arr.via.array.size;
                    if ((int)n > out->string_array.count) n = (uint32_t)out->string_array.count;
                    if (n > 100) n = 100;
                    for (uint32_t j = 0; j < n; j++) {
                        msgpack_object it = arr.via.array.ptr[j];
                        if (it.type == MSGPACK_OBJECT_STR) {
                            size_t nn = it.via.str.size < 15 ? it.via.str.size : 15;
                            memcpy(out->string_array.items[j], it.via.str.ptr, nn);
                            out->string_array.items[j][nn] = 0;
                        }
                    }
                }
            }
            break;
        }
        case TD_EDI835:
            rc |= map_get_str(root, "PayerName", out->edi.payer_name, sizeof out->edi.payer_name);
            map_get_str(root, "PayeeName", out->edi.payee_name, sizeof out->edi.payee_name);
            map_get_int(root, "ClaimCount", &out->edi.claim_count);
            for (uint32_t i = 0; i < root.via.map.size; i++) {
                msgpack_object key = root.via.map.ptr[i].key;
                if (key.type == MSGPACK_OBJECT_STR && key.via.str.size == 11 &&
                    memcmp(key.via.str.ptr, "TotalActual", 11) == 0 &&
                    root.via.map.ptr[i].val.type == MSGPACK_OBJECT_FLOAT64)
                    out->edi.total_actual = root.via.map.ptr[i].val.via.f64;
            }
            break;
        default: rc = -1;
    }
    msgpack_unpacked_destroy(&result);
    return rc;
}

void bench_register_msgpack_c(serializer_t *o, int *c) {
    char ver[32];
    snprintf(ver, sizeof ver, "%d.%d.%d", MSGPACK_VERSION_MAJOR, MSGPACK_VERSION_MINOR, MSGPACK_VERSION_REVISION);
    /* version string must outlive - use static */
    static char ver_s[32];
    snprintf(ver_s, sizeof ver_s, "%s", ver);
    BENCH_ADD(o, c, "msgpack-c", ver_s, "binary", prep, ser, de, fidelity_fx);
}
