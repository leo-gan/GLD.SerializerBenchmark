#include "ser_common.h"
#include "flatcc/flatcc_builder.h"

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

/* FlatBuffer table: field0=kind(int32), field1=full payload (ubyte vector of bin_write_fixture). */
static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    uint8_t payload[65536];
    size_t plen = 0;
    if (bin_write_fixture(fx, payload, sizeof payload, &plen)) return -1;

    flatcc_builder_t builder;
    flatcc_builder_init(&builder);
    flatcc_builder_start_buffer(&builder, 0, 0, 0);

    /* create ubyte vector of full fixture binary payload */
    flatcc_builder_ref_t blob = flatcc_builder_create_vector(
        &builder, payload, plen, 1, 1, (size_t)-1);
    if (!blob) { flatcc_builder_clear(&builder); return -1; }

    flatcc_builder_start_table(&builder, 2);
    void *kp = flatcc_builder_table_add(&builder, 0, 4, 4);
    if (kp) { int32_t k = (int32_t)fx->kind; memcpy(kp, &k, 4); }
    flatcc_builder_ref_t *rp = flatcc_builder_table_add_offset(&builder, 1);
    if (rp) *rp = blob;
    flatcc_builder_ref_t root = flatcc_builder_end_table(&builder);
    flatcc_builder_end_buffer(&builder, root);

    size_t size = 0;
    void *ptr = flatcc_builder_finalize_buffer(&builder, &size);
    if (!ptr || size > cap) {
        if (ptr) flatcc_builder_free(ptr);
        flatcc_builder_clear(&builder);
        return -1;
    }
    memcpy(buf, ptr, size);
    *ol = size;
    flatcc_builder_free(ptr);
    flatcc_builder_clear(&builder);
    return 0;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    if (len < 8) return -1;
    uint32_t root_off;
    memcpy(&root_off, buf, 4);
    if ((size_t)root_off + 4 > len) return -1;
    const uint8_t *table = buf + root_off;
    int32_t soff; memcpy(&soff, table, 4);
    const uint8_t *vtable = table - soff;
    uint16_t vsize; memcpy(&vsize, vtable, 2);
    uint16_t off0 = 0, off1 = 0;
    if (vsize >= 6) memcpy(&off0, vtable + 4, 2);
    if (vsize >= 8) memcpy(&off1, vtable + 6, 2);
    int32_t k = 0;
    if (off0) memcpy(&k, table + off0, 4);
    if (k != (int32_t)kind) return -1;
    if (!off1) return -1;
    int32_t rel; memcpy(&rel, table + off1, 4);
    const uint8_t *vec = table + off1 + rel;
    uint32_t n; memcpy(&n, vec, 4);
    if ((size_t)(vec - buf) + 4 + n > len) return -1;
    return bin_read_fixture(vec + 4, n, out, kind);
}

void bench_register_flatcc(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "flatcc", "0.6.1", "schema", prep, ser, de, fidelity_fx);
}
