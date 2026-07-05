#include "ser_common.h"
#include "flatcc/flatcc_builder.h"

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static void add_i32(flatcc_builder_t *B, int id, int32_t v) {
    void *p = flatcc_builder_table_add(B, id, 4, 4);
    if (p) memcpy(p, &v, 4);
}
static void add_u8(flatcc_builder_t *B, int id, uint8_t v) {
    void *p = flatcc_builder_table_add(B, id, 1, 1);
    if (p) memcpy(p, &v, 1);
}
static void add_f64(flatcc_builder_t *B, int id, double v) {
    void *p = flatcc_builder_table_add(B, id, 8, 8);
    if (p) memcpy(p, &v, 8);
}
static void add_off(flatcc_builder_t *B, int id, flatcc_builder_ref_t ref) {
    flatcc_builder_ref_t *r = flatcc_builder_table_add_offset(B, id);
    if (r) *r = ref;
}

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    flatcc_builder_t builder;
    flatcc_builder_init(&builder);
    flatcc_builder_start_buffer(&builder, 0, 0, 0);

    flatcc_builder_ref_t s1 = 0, s2 = 0, items_vec = 0;
    int32_t i1 = 0, i2 = 0, i3 = 0;
    uint8_t b1 = 0;
    double f1 = 0.0;

    switch (fx->kind) {
        case TD_INTEGER: i1 = fx->integer_val; break;
        case TD_SIMPLE:
            i1 = fx->simple.id;
            s1 = flatcc_builder_create_string_str(&builder, fx->simple.name);
            s2 = flatcc_builder_create_string_str(&builder, fx->simple.timestamp);
            b1 = fx->simple.is_active ? 1 : 0;
            break;
        case TD_PERSON:
            s1 = flatcc_builder_create_string_str(&builder, fx->person.first_name);
            s2 = flatcc_builder_create_string_str(&builder, fx->person.last_name);
            i1 = fx->person.age; i2 = fx->person.gender; i3 = fx->person.police_count;
            break;
        case TD_TELEMETRY:
            s1 = flatcc_builder_create_string_str(&builder, fx->telemetry.id);
            i1 = fx->telemetry.param1; i2 = fx->telemetry.meas_count;
            break;
        case TD_STRING_ARRAY: {
            i1 = fx->string_array.count;
            flatcc_builder_start_offset_vector(&builder);
            for (int i = 0; i < fx->string_array.count && i < 100; i++) {
                flatcc_builder_ref_t r = flatcc_builder_create_string_str(&builder, fx->string_array.items[i]);
                flatcc_builder_offset_vector_push(&builder, r);
            }
            items_vec = flatcc_builder_end_offset_vector(&builder);
            break;
        }
        case TD_EDI835:
            s1 = flatcc_builder_create_string_str(&builder, fx->edi.payer_name);
            s2 = flatcc_builder_create_string_str(&builder, fx->edi.payee_name);
            i1 = fx->edi.claim_count;
            f1 = fx->edi.total_actual;
            break;
        default:
            flatcc_builder_clear(&builder);
            return -1;
    }

    flatcc_builder_start_table(&builder, 10);
    add_i32(&builder, 0, (int32_t)fx->kind);
    add_i32(&builder, 1, i1);
    add_i32(&builder, 2, i2);
    add_i32(&builder, 3, i3);
    if (s1) add_off(&builder, 4, s1);
    if (s2) add_off(&builder, 5, s2);
    add_u8(&builder, 6, b1);
    add_f64(&builder, 7, f1);
    if (items_vec) add_off(&builder, 8, items_vec);
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

static void read_fb_string(const uint8_t *table, uint16_t off, char *dst, size_t dstsz) {
    if (!off) { dst[0] = 0; return; }
    int32_t rel;
    memcpy(&rel, table + off, 4);
    const uint8_t *str_obj = table + off + rel;
    uint32_t sl;
    memcpy(&sl, str_obj, 4);
    const char *s = (const char *)(str_obj + 4);
    size_t cpy = sl < dstsz - 1 ? sl : dstsz - 1;
    memcpy(dst, s, cpy);
    dst[cpy] = 0;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    if (len < 8) return -1;
    uint32_t root_off;
    memcpy(&root_off, buf, 4);
    if ((size_t)root_off + 4 > len) return -1;
    const uint8_t *table = buf + root_off;
    int32_t soff;
    memcpy(&soff, table, 4);
    const uint8_t *vtable = table - soff;
    uint16_t vsize;
    memcpy(&vsize, vtable, 2);
    uint16_t offs[9];
    memset(offs, 0, sizeof offs);
    for (int id = 0; id < 9; id++) {
        if ((uint16_t)(4 + id * 2 + 2) <= vsize)
            memcpy(&offs[id], vtable + 4 + id * 2, 2);
    }
    int32_t k = 0;
    if (offs[0]) memcpy(&k, table + offs[0], 4);
    if (k != (int32_t)kind) return -1;
    memset(out, 0, sizeof *out);
    out->kind = kind;
    out->name = test_data_name(kind);
    int32_t i1 = 0, i2 = 0, i3 = 0;
    if (offs[1]) memcpy(&i1, table + offs[1], 4);
    if (offs[2]) memcpy(&i2, table + offs[2], 4);
    if (offs[3]) memcpy(&i3, table + offs[3], 4);
    switch (kind) {
        case TD_INTEGER: out->integer_val = i1; break;
        case TD_SIMPLE:
            out->simple.id = i1;
            read_fb_string(table, offs[4], out->simple.name, sizeof out->simple.name);
            read_fb_string(table, offs[5], out->simple.timestamp, sizeof out->simple.timestamp);
            if (offs[6]) { uint8_t b; memcpy(&b, table + offs[6], 1); out->simple.is_active = b != 0; }
            break;
        case TD_PERSON:
            read_fb_string(table, offs[4], out->person.first_name, sizeof out->person.first_name);
            read_fb_string(table, offs[5], out->person.last_name, sizeof out->person.last_name);
            out->person.age = i1; out->person.gender = i2; out->person.police_count = i3;
            break;
        case TD_TELEMETRY:
            read_fb_string(table, offs[4], out->telemetry.id, sizeof out->telemetry.id);
            out->telemetry.param1 = i1; out->telemetry.meas_count = i2;
            break;
        case TD_STRING_ARRAY:
            out->string_array.count = i1;
            if (offs[8]) {
                int32_t rel; memcpy(&rel, table + offs[8], 4);
                const uint8_t *vec = table + offs[8] + rel;
                uint32_t n; memcpy(&n, vec, 4);
                if ((int)n > out->string_array.count) n = (uint32_t)out->string_array.count;
                if (n > 100) n = 100;
                for (uint32_t i = 0; i < n; i++) {
                    int32_t eref; memcpy(&eref, vec + 4 + i * 4, 4);
                    const uint8_t *str_obj = vec + 4 + i * 4 + eref;
                    uint32_t sl; memcpy(&sl, str_obj, 4);
                    const char *s = (const char *)(str_obj + 4);
                    size_t cpy = sl < 15 ? sl : 15;
                    memcpy(out->string_array.items[i], s, cpy);
                    out->string_array.items[i][cpy] = 0;
                }
            }
            break;
        case TD_EDI835:
            read_fb_string(table, offs[4], out->edi.payer_name, sizeof out->edi.payer_name);
            read_fb_string(table, offs[5], out->edi.payee_name, sizeof out->edi.payee_name);
            out->edi.claim_count = i1;
            if (offs[7]) memcpy(&out->edi.total_actual, table + offs[7], 8);
            break;
        default: return -1;
    }
    return 0;
}

void bench_register_flatcc(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "flatcc", "0.6.1", "schema", prep, ser, de, fidelity_fx);
}
