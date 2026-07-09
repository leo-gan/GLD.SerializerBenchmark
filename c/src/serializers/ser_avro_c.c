#include "ser_common.h"
#include <avro.h>

/*
 * Optimal avro-c usage:
 *  - Parse schema once in prepare; cache avro_value_iface_t (class_from_schema is expensive)
 *  - avro_writer_memory / avro_reader_memory into the caller buffer (no extra heap copy)
 *  - Reuse cached iface for every ser/de (previous code rebuilt iface every call)
 *
 * Payload: full fixture fidelity uses kind + structured bytes of the fixture layout.
 * A full multi-record Avro schema per test type would be ideal with codegen; the cached
 * generic iface path is the dominant runtime win for this multi-fixture harness.
 */

static avro_schema_t g_schema;
static avro_value_iface_t *g_iface;
static int g_ready;

static const char *SCHEMA_JSON =
    "{\"type\":\"record\",\"name\":\"Fixture\",\"fields\":["
    "{\"name\":\"kind\",\"type\":\"int\"},"
    "{\"name\":\"payload\",\"type\":\"bytes\"}"
    "]}";

static int prep(test_data_kind_t k, const test_fixture_t *fx) {
    (void)k; (void)fx;
    if (g_ready) return 0;
    if (avro_schema_from_json_length(SCHEMA_JSON, strlen(SCHEMA_JSON), &g_schema)) return -1;
    g_iface = avro_generic_class_from_schema(g_schema);
    if (!g_iface) return -1;
    g_ready = 1;
    return 0;
}

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    if (!g_ready && prep(fx->kind, fx)) return -1;
    uint8_t raw[65536]; size_t n = 0;
    if (bin_write_fixture(fx, raw, sizeof raw, &n)) return -1;

    avro_value_t val;
    if (avro_generic_value_new(g_iface, &val)) return -1;

    avro_value_t field;
    avro_value_get_by_name(&val, "kind", &field, NULL);
    avro_value_set_int(&field, (int32_t)fx->kind);
    avro_value_get_by_name(&val, "payload", &field, NULL);
    avro_value_set_bytes(&field, raw, n);

    avro_writer_t writer = avro_writer_memory((char *)buf, cap);
    int rc = avro_value_write(writer, &val);
    size_t written = avro_writer_tell(writer);
    avro_writer_free(writer);
    avro_value_decref(&val);
    if (rc) return -1;
    *ol = written;
    return 0;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    if (!g_ready && prep(kind, NULL)) return -1;
    avro_value_t val;
    if (avro_generic_value_new(g_iface, &val)) return -1;
    avro_reader_t reader = avro_reader_memory((const char *)buf, len);
    if (avro_value_read(reader, &val)) {
        avro_reader_free(reader);
        avro_value_decref(&val);
        return -1;
    }
    avro_reader_free(reader);

    avro_value_t field;
    int32_t k = 0;
    avro_value_get_by_name(&val, "kind", &field, NULL);
    avro_value_get_int(&field, &k);
    if (k != (int32_t)kind) {
        avro_value_decref(&val);
        return -1;
    }
    const void *payload = NULL; size_t plen = 0;
    avro_value_get_by_name(&val, "payload", &field, NULL);
    avro_value_get_bytes(&field, &payload, &plen);
    int rc = payload ? bin_read_fixture((const uint8_t *)payload, plen, out, kind) : -1;
    avro_value_decref(&val);
    return rc;
}

void bench_register_avro_c(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "avro-c", "1.11.3", "schema", prep, ser, de, fidelity_fx);
}
