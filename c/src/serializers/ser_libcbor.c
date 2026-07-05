#include "ser_common.h"
#include "../../../third_party/libcbor/src/cbor.h"

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static void map_put_string(cbor_item_t *map, const char *k, const char *v) {
    cbor_item_t *key = cbor_build_string(k);
    cbor_item_t *val = cbor_build_string(v ? v : "");
    cbor_map_add(map, (struct cbor_pair){ .key = key, .value = val });
}
static void map_put_uint(cbor_item_t *map, const char *k, uint64_t v) {
    cbor_item_t *key = cbor_build_string(k);
    cbor_item_t *val = cbor_build_uint64(v);
    cbor_map_add(map, (struct cbor_pair){ .key = key, .value = val });
}
static void map_put_float(cbor_item_t *map, const char *k, double v) {
    cbor_item_t *key = cbor_build_string(k);
    cbor_item_t *val = cbor_build_float8(v);
    cbor_map_add(map, (struct cbor_pair){ .key = key, .value = val });
}

static cbor_item_t *fx_to_item(const test_fixture_t *fx) {
    cbor_item_t *map = cbor_new_indefinite_map();
    if (!map) return NULL;
    map_put_uint(map, "kind", (uint64_t)fx->kind);
    switch (fx->kind) {
        case TD_INTEGER:
            map_put_uint(map, "value", (uint64_t)(uint32_t)fx->integer_val);
            break;
        case TD_SIMPLE:
            map_put_uint(map, "Id", (uint64_t)(uint32_t)fx->simple.id);
            map_put_string(map, "Name", fx->simple.name);
            map_put_string(map, "Timestamp", fx->simple.timestamp);
            map_put_uint(map, "IsActive", fx->simple.is_active ? 1 : 0);
            break;
        case TD_PERSON:
            map_put_string(map, "FirstName", fx->person.first_name);
            map_put_string(map, "LastName", fx->person.last_name);
            map_put_uint(map, "Age", (uint64_t)(uint32_t)fx->person.age);
            map_put_uint(map, "Gender", (uint64_t)(uint32_t)fx->person.gender);
            map_put_uint(map, "PoliceCount", (uint64_t)(uint32_t)fx->person.police_count);
            break;
        case TD_TELEMETRY:
            map_put_string(map, "Id", fx->telemetry.id);
            map_put_uint(map, "Param1", (uint64_t)(uint32_t)fx->telemetry.param1);
            map_put_uint(map, "MeasCount", (uint64_t)(uint32_t)fx->telemetry.meas_count);
            break;
        case TD_STRING_ARRAY: {
            map_put_uint(map, "Count", (uint64_t)(uint32_t)fx->string_array.count);
            cbor_item_t *arr = cbor_new_definite_array((size_t)fx->string_array.count);
            for (int i = 0; i < fx->string_array.count && i < 100; i++)
                cbor_array_push(arr, cbor_move(cbor_build_string(fx->string_array.items[i])));
            cbor_item_t *key = cbor_build_string("Items");
            cbor_map_add(map, (struct cbor_pair){ .key = key, .value = arr });
            break;
        }
        case TD_EDI835:
            map_put_string(map, "PayerName", fx->edi.payer_name);
            map_put_string(map, "PayeeName", fx->edi.payee_name);
            map_put_uint(map, "ClaimCount", (uint64_t)(uint32_t)fx->edi.claim_count);
            map_put_float(map, "TotalActual", fx->edi.total_actual);
            break;
        default:
            cbor_decref(&map);
            return NULL;
    }
    return map;
}

static int map_int(cbor_item_t *map, const char *key, int *out) {
    size_t n = cbor_map_size(map);
    struct cbor_pair *pairs = cbor_map_handle(map);
    for (size_t i = 0; i < n; i++) {
        if (!cbor_isa_string(pairs[i].key)) continue;
        size_t len = cbor_string_length(pairs[i].key);
        if (len != strlen(key) || memcmp(cbor_string_handle(pairs[i].key), key, len) != 0) continue;
        if (cbor_isa_uint(pairs[i].value)) {
            *out = (int)cbor_get_uint64(pairs[i].value);
            return 0;
        }
    }
    return -1;
}

static int map_str(cbor_item_t *map, const char *key, char *dst, size_t dstsz) {
    size_t n = cbor_map_size(map);
    struct cbor_pair *pairs = cbor_map_handle(map);
    for (size_t i = 0; i < n; i++) {
        if (!cbor_isa_string(pairs[i].key)) continue;
        size_t len = cbor_string_length(pairs[i].key);
        if (len != strlen(key) || memcmp(cbor_string_handle(pairs[i].key), key, len) != 0) continue;
        if (cbor_isa_string(pairs[i].value)) {
            size_t sl = cbor_string_length(pairs[i].value);
            if (sl >= dstsz) sl = dstsz - 1;
            memcpy(dst, cbor_string_handle(pairs[i].value), sl);
            dst[sl] = 0;
            return 0;
        }
    }
    return -1;
}

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    cbor_item_t *item = fx_to_item(fx);
    if (!item) return -1;
    unsigned char *out = NULL;
    size_t len = cbor_serialize_alloc(item, &out, NULL);
    cbor_decref(&item);
    if (!out || len == 0 || len > cap) { free(out); return -1; }
    memcpy(buf, out, len);
    *ol = len;
    free(out);
    return 0;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    struct cbor_load_result res;
    cbor_item_t *item = cbor_load(buf, len, &res);
    if (!item || !cbor_isa_map(item)) { if (item) cbor_decref(&item); return -1; }
    int k = -1;
    if (map_int(item, "kind", &k) || k != (int)kind) { cbor_decref(&item); return -1; }
    memset(out, 0, sizeof *out);
    out->kind = kind;
    out->name = test_data_name(kind);
    int rc = 0;
    switch (kind) {
        case TD_INTEGER:
            rc = map_int(item, "value", &out->integer_val);
            break;
        case TD_SIMPLE: {
            int act = 0;
            if (map_int(item, "Id", &out->simple.id)) rc = -1;
            if (map_str(item, "Name", out->simple.name, sizeof out->simple.name)) rc = -1;
            map_str(item, "Timestamp", out->simple.timestamp, sizeof out->simple.timestamp);
            if (!map_int(item, "IsActive", &act)) out->simple.is_active = act != 0;
            break;
        }
        case TD_PERSON:
            if (map_str(item, "FirstName", out->person.first_name, sizeof out->person.first_name)) rc = -1;
            if (map_str(item, "LastName", out->person.last_name, sizeof out->person.last_name)) rc = -1;
            map_int(item, "Age", &out->person.age);
            map_int(item, "Gender", &out->person.gender);
            map_int(item, "PoliceCount", &out->person.police_count);
            break;
        case TD_TELEMETRY:
            if (map_str(item, "Id", out->telemetry.id, sizeof out->telemetry.id)) rc = -1;
            map_int(item, "Param1", &out->telemetry.param1);
            map_int(item, "MeasCount", &out->telemetry.meas_count);
            break;
        case TD_STRING_ARRAY: {
            map_int(item, "Count", &out->string_array.count);
            size_t nmap = cbor_map_size(item);
            struct cbor_pair *pairs = cbor_map_handle(item);
            for (size_t i = 0; i < nmap; i++) {
                if (cbor_isa_string(pairs[i].key) && cbor_string_length(pairs[i].key) == 5 &&
                    memcmp(cbor_string_handle(pairs[i].key), "Items", 5) == 0 && cbor_isa_array(pairs[i].value)) {
                    size_t an = cbor_array_size(pairs[i].value);
                    if ((int)an > out->string_array.count) an = (size_t)out->string_array.count;
                    if (an > 100) an = 100;
                    for (size_t j = 0; j < an; j++) {
                        cbor_item_t *it = cbor_array_get(pairs[i].value, j);
                        if (it && cbor_isa_string(it)) {
                            size_t sl = cbor_string_length(it);
                            if (sl > 15) sl = 15;
                            memcpy(out->string_array.items[j], cbor_string_handle(it), sl);
                            out->string_array.items[j][sl] = 0;
                        }
                    }
                }
            }
            break;
        }
        case TD_EDI835:
            if (map_str(item, "PayerName", out->edi.payer_name, sizeof out->edi.payer_name)) rc = -1;
            map_str(item, "PayeeName", out->edi.payee_name, sizeof out->edi.payee_name);
            map_int(item, "ClaimCount", &out->edi.claim_count);
            {
                size_t nmap = cbor_map_size(item);
                struct cbor_pair *pairs = cbor_map_handle(item);
                for (size_t i = 0; i < nmap; i++) {
                    if (cbor_isa_string(pairs[i].key) && cbor_string_length(pairs[i].key) == 11 &&
                        memcmp(cbor_string_handle(pairs[i].key), "TotalActual", 11) == 0 && cbor_is_float(pairs[i].value))
                        out->edi.total_actual = cbor_float_get_float8(pairs[i].value);
                }
            }
            break;
        default: rc = -1;
    }
    cbor_decref(&item);
    return rc;
}

void bench_register_libcbor(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "cbor-encode", "0.11.0", "binary", prep, ser, de, fidelity_fx);
}
