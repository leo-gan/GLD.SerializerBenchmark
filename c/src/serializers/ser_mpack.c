#define MPACK_HAS_CONFIG 0
#include "ser_common.h"
#include "mpack/mpack.h"

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static void write_fx(mpack_writer_t *w, const test_fixture_t *fx) {
    mpack_build_map(w);
    mpack_write_cstr(w, "kind"); mpack_write_int(w, (int64_t)fx->kind);
    switch (fx->kind) {
        case TD_INTEGER:
            mpack_write_cstr(w, "value"); mpack_write_int(w, fx->integer_val);
            break;
        case TD_SIMPLE:
            mpack_write_cstr(w, "Id"); mpack_write_int(w, fx->simple.id);
            mpack_write_cstr(w, "Name"); mpack_write_cstr(w, fx->simple.name);
            mpack_write_cstr(w, "Timestamp"); mpack_write_cstr(w, fx->simple.timestamp);
            mpack_write_cstr(w, "IsActive"); mpack_write_bool(w, fx->simple.is_active);
            break;
        case TD_PERSON:
            mpack_write_cstr(w, "FirstName"); mpack_write_cstr(w, fx->person.first_name);
            mpack_write_cstr(w, "LastName"); mpack_write_cstr(w, fx->person.last_name);
            mpack_write_cstr(w, "Age"); mpack_write_int(w, fx->person.age);
            mpack_write_cstr(w, "Gender"); mpack_write_int(w, fx->person.gender);
            mpack_write_cstr(w, "PoliceCount"); mpack_write_int(w, fx->person.police_count);
            break;
        case TD_TELEMETRY:
            mpack_write_cstr(w, "Id"); mpack_write_cstr(w, fx->telemetry.id);
            mpack_write_cstr(w, "Param1"); mpack_write_int(w, fx->telemetry.param1);
            mpack_write_cstr(w, "MeasCount"); mpack_write_int(w, fx->telemetry.meas_count);
            break;
        case TD_STRING_ARRAY:
            mpack_write_cstr(w, "Count"); mpack_write_int(w, fx->string_array.count);
            mpack_write_cstr(w, "Items");
            mpack_start_array(w, (uint32_t)fx->string_array.count);
            for (int i = 0; i < fx->string_array.count && i < 100; i++)
                mpack_write_cstr(w, fx->string_array.items[i]);
            mpack_finish_array(w);
            break;
        case TD_EDI835:
            mpack_write_cstr(w, "PayerName"); mpack_write_cstr(w, fx->edi.payer_name);
            mpack_write_cstr(w, "PayeeName"); mpack_write_cstr(w, fx->edi.payee_name);
            mpack_write_cstr(w, "ClaimCount"); mpack_write_int(w, fx->edi.claim_count);
            mpack_write_cstr(w, "TotalActual"); mpack_write_double(w, fx->edi.total_actual);
            break;
        default: break;
    }
    mpack_complete_map(w);
}

static void mpack_copy_str(mpack_node_t node, char *dst, size_t dstsz) {
    const char *s = mpack_node_str(node);
    size_t n = mpack_node_strlen(node);
    if (!s) { dst[0] = 0; return; }
    if (n >= dstsz) n = dstsz - 1;
    memcpy(dst, s, n);
    dst[n] = 0;
}

static int read_fx(mpack_node_t root, test_fixture_t *out, test_data_kind_t kind) {
    if (mpack_node_int(mpack_node_map_cstr(root, "kind")) != (int)kind) return -1;
    out->kind = kind;
    out->name = test_data_name(kind);
    switch (kind) {
        case TD_INTEGER:
            out->integer_val = (int)mpack_node_int(mpack_node_map_cstr(root, "value"));
            break;
        case TD_SIMPLE:
            out->simple.id = (int)mpack_node_int(mpack_node_map_cstr(root, "Id"));
            mpack_copy_str(mpack_node_map_cstr(root, "Name"), out->simple.name, sizeof out->simple.name);
            mpack_copy_str(mpack_node_map_cstr(root, "Timestamp"), out->simple.timestamp, sizeof out->simple.timestamp);
            out->simple.is_active = mpack_node_bool(mpack_node_map_cstr(root, "IsActive"));
            break;
        case TD_PERSON:
            mpack_copy_str(mpack_node_map_cstr(root, "FirstName"), out->person.first_name, sizeof out->person.first_name);
            mpack_copy_str(mpack_node_map_cstr(root, "LastName"), out->person.last_name, sizeof out->person.last_name);
            out->person.age = (int)mpack_node_int(mpack_node_map_cstr(root, "Age"));
            out->person.gender = (int)mpack_node_int(mpack_node_map_cstr(root, "Gender"));
            out->person.police_count = (int)mpack_node_int(mpack_node_map_cstr(root, "PoliceCount"));
            break;
        case TD_TELEMETRY:
            mpack_copy_str(mpack_node_map_cstr(root, "Id"), out->telemetry.id, sizeof out->telemetry.id);
            out->telemetry.param1 = (int)mpack_node_int(mpack_node_map_cstr(root, "Param1"));
            out->telemetry.meas_count = (int)mpack_node_int(mpack_node_map_cstr(root, "MeasCount"));
            break;
        case TD_STRING_ARRAY: {
            out->string_array.count = (int)mpack_node_int(mpack_node_map_cstr(root, "Count"));
            mpack_node_t items = mpack_node_map_cstr(root, "Items");
            int n = (int)mpack_node_array_length(items);
            if (n > out->string_array.count) n = out->string_array.count;
            if (n > 100) n = 100;
            for (int i = 0; i < n; i++)
                mpack_copy_str(mpack_node_array_at(items, (size_t)i), out->string_array.items[i], sizeof out->string_array.items[i]);
            break;
        }
        case TD_EDI835:
            mpack_copy_str(mpack_node_map_cstr(root, "PayerName"), out->edi.payer_name, sizeof out->edi.payer_name);
            mpack_copy_str(mpack_node_map_cstr(root, "PayeeName"), out->edi.payee_name, sizeof out->edi.payee_name);
            out->edi.claim_count = (int)mpack_node_int(mpack_node_map_cstr(root, "ClaimCount"));
            out->edi.total_actual = mpack_node_double(mpack_node_map_cstr(root, "TotalActual"));
            break;
        default: return -1;
    }
    return 0;
}

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    mpack_writer_t w;
    mpack_writer_init(&w, (char *)buf, cap);
    write_fx(&w, fx);
    if (mpack_writer_error(&w) != mpack_ok) return -1;
    *ol = mpack_writer_buffer_used(&w);
    mpack_writer_destroy(&w);
    return 0;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    mpack_tree_t tree;
    mpack_tree_init_data(&tree, (const char *)buf, len);
    mpack_tree_parse(&tree);
    if (mpack_tree_error(&tree) != mpack_ok) { mpack_tree_destroy(&tree); return -1; }
    int rc = read_fx(mpack_tree_root(&tree), out, kind);
    if (mpack_tree_error(&tree) != mpack_ok) rc = -1;
    mpack_tree_destroy(&tree);
    return rc;
}

void bench_register_mpack(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "mpack", "1.1", "binary", prep, ser, de, fidelity_fx);
}
