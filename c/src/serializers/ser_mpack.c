#define MPACK_HAS_CONFIG 0
#include "ser_common.h"
#include "mpack/mpack.h"

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    uint8_t raw[65536]; size_t n = 0;
    if (bin_write_fixture(fx, raw, sizeof raw, &n)) return -1;
    mpack_writer_t w;
    mpack_writer_init(&w, (char *)buf, cap);
    mpack_build_map(&w);
    mpack_write_cstr(&w, "kind"); mpack_write_int(&w, (int64_t)fx->kind);
    mpack_write_cstr(&w, "payload"); mpack_write_bin(&w, (const char *)raw, n);
    mpack_complete_map(&w);
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
    mpack_node_t root = mpack_tree_root(&tree);
    if (mpack_node_int(mpack_node_map_cstr(root, "kind")) != (int)kind) {
        mpack_tree_destroy(&tree); return -1;
    }
    mpack_node_t pl = mpack_node_map_cstr(root, "payload");
    const char *p = mpack_node_bin_data(pl);
    size_t n = mpack_node_bin_size(pl);
    int r = bin_read_fixture((const uint8_t *)p, n, out, kind);
    if (mpack_tree_error(&tree) != mpack_ok) r = -1;
    mpack_tree_destroy(&tree);
    return r;
}

void bench_register_mpack(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "mpack", "1.1", "binary", prep, ser, de, fidelity_fx);
}
