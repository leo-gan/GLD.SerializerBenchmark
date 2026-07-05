#include "ser_common.h"
#include <avro.h>

static avro_schema_t g_schema;
static int g_ready;

static const char *SCHEMA_JSON =
    "{\"type\":\"record\",\"name\":\"Fixture\",\"fields\":["
    "{\"name\":\"kind\",\"type\":\"int\"},"
    "{\"name\":\"integer_val\",\"type\":\"int\",\"default\":0},"
    "{\"name\":\"first_name\",\"type\":\"string\",\"default\":\"\"},"
    "{\"name\":\"last_name\",\"type\":\"string\",\"default\":\"\"},"
    "{\"name\":\"age\",\"type\":\"int\",\"default\":0},"
    "{\"name\":\"gender\",\"type\":\"int\",\"default\":0},"
    "{\"name\":\"police_count\",\"type\":\"int\",\"default\":0},"
    "{\"name\":\"simple_id\",\"type\":\"int\",\"default\":0},"
    "{\"name\":\"simple_name\",\"type\":\"string\",\"default\":\"\"},"
    "{\"name\":\"simple_ts\",\"type\":\"string\",\"default\":\"\"},"
    "{\"name\":\"simple_active\",\"type\":\"boolean\",\"default\":false},"
    "{\"name\":\"telem_id\",\"type\":\"string\",\"default\":\"\"},"
    "{\"name\":\"param1\",\"type\":\"int\",\"default\":0},"
    "{\"name\":\"meas_count\",\"type\":\"int\",\"default\":0},"
    "{\"name\":\"str_count\",\"type\":\"int\",\"default\":0},"
    "{\"name\":\"items\",\"type\":{\"type\":\"array\",\"items\":\"string\"},\"default\":[]},"
    "{\"name\":\"payer\",\"type\":\"string\",\"default\":\"\"},"
    "{\"name\":\"payee\",\"type\":\"string\",\"default\":\"\"},"
    "{\"name\":\"claim_count\",\"type\":\"int\",\"default\":0},"
    "{\"name\":\"total_actual\",\"type\":\"double\",\"default\":0}"
    "]}";

static int prep(test_data_kind_t k, const test_fixture_t *fx) {
    (void)k; (void)fx;
    if (g_ready) return 0;
    if (avro_schema_from_json_length(SCHEMA_JSON, strlen(SCHEMA_JSON), &g_schema)) return -1;
    g_ready = 1;
    return 0;
}

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    if (!g_ready && prep(fx->kind, fx)) return -1;
    avro_value_iface_t *iface = avro_generic_class_from_schema(g_schema);
    avro_value_t val;
    avro_generic_value_new(iface, &val);

    avro_value_t field;
    avro_value_get_by_name(&val, "kind", &field, NULL);
    avro_value_set_int(&field, (int32_t)fx->kind);

    #define SET_INT(name, v) do { avro_value_get_by_name(&val, name, &field, NULL); avro_value_set_int(&field, (int32_t)(v)); } while (0)
    #define SET_STR(name, v) do { avro_value_get_by_name(&val, name, &field, NULL); avro_value_set_string(&field, (v)); } while (0)
    #define SET_BOOL(name, v) do { avro_value_get_by_name(&val, name, &field, NULL); avro_value_set_boolean(&field, (v)); } while (0)
    #define SET_DBL(name, v) do { avro_value_get_by_name(&val, name, &field, NULL); avro_value_set_double(&field, (v)); } while (0)

    switch (fx->kind) {
        case TD_INTEGER: SET_INT("integer_val", fx->integer_val); break;
        case TD_SIMPLE:
            SET_INT("simple_id", fx->simple.id);
            SET_STR("simple_name", fx->simple.name);
            SET_STR("simple_ts", fx->simple.timestamp);
            SET_BOOL("simple_active", fx->simple.is_active);
            break;
        case TD_PERSON:
            SET_STR("first_name", fx->person.first_name);
            SET_STR("last_name", fx->person.last_name);
            SET_INT("age", fx->person.age);
            SET_INT("gender", fx->person.gender);
            SET_INT("police_count", fx->person.police_count);
            break;
        case TD_TELEMETRY:
            SET_STR("telem_id", fx->telemetry.id);
            SET_INT("param1", fx->telemetry.param1);
            SET_INT("meas_count", fx->telemetry.meas_count);
            break;
        case TD_STRING_ARRAY: {
            SET_INT("str_count", fx->string_array.count);
            avro_value_get_by_name(&val, "items", &field, NULL);
            for (int i = 0; i < fx->string_array.count && i < 100; i++) {
                avro_value_t elem;
                size_t idx;
                avro_value_append(&field, &elem, &idx);
                avro_value_set_string(&elem, fx->string_array.items[i]);
            }
            break;
        }
        case TD_EDI835:
            SET_STR("payer", fx->edi.payer_name);
            SET_STR("payee", fx->edi.payee_name);
            SET_INT("claim_count", fx->edi.claim_count);
            SET_DBL("total_actual", fx->edi.total_actual);
            break;
        default:
            avro_value_decref(&val);
            avro_value_iface_decref(iface);
            return -1;
    }

    avro_writer_t writer = avro_writer_memory((char *)buf, cap);
    int rc = avro_value_write(writer, &val);
    size_t written = avro_writer_tell(writer);
    avro_writer_free(writer);
    avro_value_decref(&val);
    avro_value_iface_decref(iface);
    if (rc) return -1;
    *ol = written;
    return 0;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    if (!g_ready && prep(kind, NULL)) return -1;
    avro_value_iface_t *iface = avro_generic_class_from_schema(g_schema);
    avro_value_t val;
    avro_generic_value_new(iface, &val);
    avro_reader_t reader = avro_reader_memory((const char *)buf, len);
    if (avro_value_read(reader, &val)) {
        avro_reader_free(reader);
        avro_value_decref(&val);
        avro_value_iface_decref(iface);
        return -1;
    }
    avro_reader_free(reader);

    avro_value_t field;
    int32_t k = 0;
    avro_value_get_by_name(&val, "kind", &field, NULL);
    avro_value_get_int(&field, &k);
    if (k != (int32_t)kind) {
        avro_value_decref(&val);
        avro_value_iface_decref(iface);
        return -1;
    }
    memset(out, 0, sizeof *out);
    out->kind = kind;
    out->name = test_data_name(kind);

    const char *s = NULL;
    int32_t i = 0;
    int b = 0;
    double d = 0;

    switch (kind) {
        case TD_INTEGER:
            avro_value_get_by_name(&val, "integer_val", &field, NULL);
            avro_value_get_int(&field, &i); out->integer_val = i;
            break;
        case TD_SIMPLE:
            avro_value_get_by_name(&val, "simple_id", &field, NULL);
            avro_value_get_int(&field, &i); out->simple.id = i;
            avro_value_get_by_name(&val, "simple_name", &field, NULL);
            avro_value_get_string(&field, &s, NULL);
            if (s) snprintf(out->simple.name, sizeof out->simple.name, "%s", s);
            avro_value_get_by_name(&val, "simple_ts", &field, NULL);
            avro_value_get_string(&field, &s, NULL);
            if (s) snprintf(out->simple.timestamp, sizeof out->simple.timestamp, "%s", s);
            avro_value_get_by_name(&val, "simple_active", &field, NULL);
            avro_value_get_boolean(&field, &b); out->simple.is_active = b != 0;
            break;
        case TD_PERSON:
            avro_value_get_by_name(&val, "first_name", &field, NULL);
            avro_value_get_string(&field, &s, NULL);
            if (s) snprintf(out->person.first_name, sizeof out->person.first_name, "%s", s);
            avro_value_get_by_name(&val, "last_name", &field, NULL);
            avro_value_get_string(&field, &s, NULL);
            if (s) snprintf(out->person.last_name, sizeof out->person.last_name, "%s", s);
            avro_value_get_by_name(&val, "age", &field, NULL);
            avro_value_get_int(&field, &i); out->person.age = i;
            avro_value_get_by_name(&val, "gender", &field, NULL);
            avro_value_get_int(&field, &i); out->person.gender = i;
            avro_value_get_by_name(&val, "police_count", &field, NULL);
            avro_value_get_int(&field, &i); out->person.police_count = i;
            break;
        case TD_TELEMETRY:
            avro_value_get_by_name(&val, "telem_id", &field, NULL);
            avro_value_get_string(&field, &s, NULL);
            if (s) snprintf(out->telemetry.id, sizeof out->telemetry.id, "%s", s);
            avro_value_get_by_name(&val, "param1", &field, NULL);
            avro_value_get_int(&field, &i); out->telemetry.param1 = i;
            avro_value_get_by_name(&val, "meas_count", &field, NULL);
            avro_value_get_int(&field, &i); out->telemetry.meas_count = i;
            break;
        case TD_STRING_ARRAY: {
            avro_value_get_by_name(&val, "str_count", &field, NULL);
            avro_value_get_int(&field, &i); out->string_array.count = i;
            avro_value_get_by_name(&val, "items", &field, NULL);
            size_t n = 0; avro_value_get_size(&field, &n);
            if ((int)n > out->string_array.count) n = (size_t)out->string_array.count;
            if (n > 100) n = 100;
            for (size_t j = 0; j < n; j++) {
                avro_value_t elem;
                avro_value_get_by_index(&field, j, &elem, NULL);
                avro_value_get_string(&elem, &s, NULL);
                if (s) snprintf(out->string_array.items[j], sizeof out->string_array.items[j], "%s", s);
            }
            break;
        }
        case TD_EDI835:
            avro_value_get_by_name(&val, "payer", &field, NULL);
            avro_value_get_string(&field, &s, NULL);
            if (s) snprintf(out->edi.payer_name, sizeof out->edi.payer_name, "%s", s);
            avro_value_get_by_name(&val, "payee", &field, NULL);
            avro_value_get_string(&field, &s, NULL);
            if (s) snprintf(out->edi.payee_name, sizeof out->edi.payee_name, "%s", s);
            avro_value_get_by_name(&val, "claim_count", &field, NULL);
            avro_value_get_int(&field, &i); out->edi.claim_count = i;
            avro_value_get_by_name(&val, "total_actual", &field, NULL);
            avro_value_get_double(&field, &d); out->edi.total_actual = d;
            break;
        default:
            avro_value_decref(&val);
            avro_value_iface_decref(iface);
            return -1;
    }
    avro_value_decref(&val);
    avro_value_iface_decref(iface);
    return 0;
}

void bench_register_avro_c(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "avro-c", "1.11.3", "schema", prep, ser, de, fidelity_fx);
}
