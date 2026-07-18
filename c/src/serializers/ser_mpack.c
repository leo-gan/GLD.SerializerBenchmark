#define MPACK_HAS_CONFIG 0
#include "ser_common.h"
#include "mpack/mpack.h"

/* Native mpack fixed-buffer writer + tree reader for V2 field maps. */

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static int write_fx(mpack_writer_t *w, const test_fixture_t *fx) {
    switch (fx->kind) {
        case TD_MESSAGE: {
            const message_t *m = &fx->message;
            mpack_start_map(w, 8);
            mpack_write_cstr(w, "f_bool"); mpack_write_bool(w, m->f_bool);
            mpack_write_cstr(w, "f_int32"); mpack_write_i32(w, m->f_int32);
            mpack_write_cstr(w, "f_int64"); mpack_write_i64(w, m->f_int64);
            mpack_write_cstr(w, "f_float64"); mpack_write_double(w, m->f_float64);
            mpack_write_cstr(w, "f_string"); mpack_write_cstr(w, m->f_string);
            mpack_write_cstr(w, "f_bool_2"); mpack_write_bool(w, m->f_bool_2);
            mpack_write_cstr(w, "f_int32_2"); mpack_write_i32(w, m->f_int32_2);
            mpack_write_cstr(w, "f_string_2"); mpack_write_cstr(w, m->f_string_2);
            mpack_finish_map(w);
            break;
        }
        case TD_DOCUMENT: {
            const document_t *d = &fx->document;
            mpack_start_map(w, 4);
            mpack_write_cstr(w, "id"); mpack_write_cstr(w, d->id);
            mpack_write_cstr(w, "status"); mpack_write_i32(w, d->status);
            mpack_write_cstr(w, "meta");
            mpack_start_map(w, 2);
            mpack_write_cstr(w, "region"); mpack_write_cstr(w, d->meta.region);
            mpack_write_cstr(w, "version"); mpack_write_i32(w, d->meta.version);
            mpack_finish_map(w);
            mpack_write_cstr(w, "items");
            mpack_start_array(w, (uint32_t)d->item_count);
            for (int i = 0; i < d->item_count; i++) {
                mpack_start_map(w, 3);
                mpack_write_cstr(w, "sku"); mpack_write_cstr(w, d->items[i].sku);
                mpack_write_cstr(w, "qty"); mpack_write_i32(w, d->items[i].qty);
                mpack_write_cstr(w, "price_minor"); mpack_write_i64(w, d->items[i].price_minor);
                mpack_finish_map(w);
            }
            mpack_finish_array(w);
            mpack_finish_map(w);
            break;
        }
        case TD_TELEMETRY: {
            const telemetry_t *t = &fx->telemetry;
            mpack_start_map(w, 4);
            mpack_write_cstr(w, "source"); mpack_write_cstr(w, t->source);
            mpack_write_cstr(w, "ts"); mpack_write_i64(w, t->ts);
            mpack_write_cstr(w, "tags");
            mpack_start_array(w, (uint32_t)t->tag_count);
            for (int i = 0; i < t->tag_count; i++) mpack_write_cstr(w, t->tags[i]);
            mpack_finish_array(w);
            mpack_write_cstr(w, "values");
            mpack_start_array(w, (uint32_t)t->value_count);
            for (int i = 0; i < t->value_count; i++) mpack_write_double(w, t->values[i]);
            mpack_finish_array(w);
            mpack_finish_map(w);
            break;
        }
        case TD_STRINGS: {
            mpack_start_map(w, 1);
            mpack_write_cstr(w, "items");
            mpack_start_array(w, (uint32_t)fx->strings.count);
            for (int i = 0; i < fx->strings.count; i++) mpack_write_cstr(w, fx->strings.items[i]);
            mpack_finish_array(w);
            mpack_finish_map(w);
            break;
        }
        case TD_EVENT: {
            const event_t *e = &fx->event;
            mpack_start_map(w, 5);
            mpack_write_cstr(w, "event_id"); mpack_write_cstr(w, e->event_id);
            mpack_write_cstr(w, "event_type"); mpack_write_cstr(w, e->event_type);
            mpack_write_cstr(w, "occurred_at"); mpack_write_i64(w, e->occurred_at);
            mpack_write_cstr(w, "producer"); mpack_write_cstr(w, e->producer);
            mpack_write_cstr(w, "attrs");
            mpack_start_array(w, (uint32_t)e->attr_count);
            for (int i = 0; i < e->attr_count; i++) {
                mpack_start_map(w, 2);
                mpack_write_cstr(w, "key"); mpack_write_cstr(w, e->attrs[i].key);
                mpack_write_cstr(w, "value"); mpack_write_cstr(w, e->attrs[i].value);
                mpack_finish_map(w);
            }
            mpack_finish_array(w);
            mpack_finish_map(w);
            break;
        }
        default: return -1;
    }
    return mpack_writer_error(w) == mpack_ok ? 0 : -1;
}

static int read_fx(mpack_node_t root, test_fixture_t *out, test_data_kind_t kind) {
    memset(out, 0, sizeof *out);
    out->kind = kind; out->name = test_data_name(kind); out->batch_n = 1;
    if (mpack_node_type(root) != mpack_type_map) return -1;
    switch (kind) {
        case TD_MESSAGE: {
            message_t *m = &out->message;
            m->f_bool = mpack_node_bool(mpack_node_map_cstr(root, "f_bool"));
            m->f_int32 = mpack_node_i32(mpack_node_map_cstr(root, "f_int32"));
            m->f_int64 = mpack_node_i64(mpack_node_map_cstr(root, "f_int64"));
            m->f_float64 = mpack_node_double(mpack_node_map_cstr(root, "f_float64"));
            mpack_node_copy_cstr(mpack_node_map_cstr(root, "f_string"), m->f_string, sizeof m->f_string);
            m->f_bool_2 = mpack_node_bool(mpack_node_map_cstr(root, "f_bool_2"));
            m->f_int32_2 = mpack_node_i32(mpack_node_map_cstr(root, "f_int32_2"));
            mpack_node_copy_cstr(mpack_node_map_cstr(root, "f_string_2"), m->f_string_2, sizeof m->f_string_2);
            break;
        }
        case TD_DOCUMENT: {
            document_t *d = &out->document;
            mpack_node_copy_cstr(mpack_node_map_cstr(root, "id"), d->id, sizeof d->id);
            d->status = mpack_node_i32(mpack_node_map_cstr(root, "status"));
            mpack_node_t meta = mpack_node_map_cstr(root, "meta");
            mpack_node_copy_cstr(mpack_node_map_cstr(meta, "region"), d->meta.region, sizeof d->meta.region);
            d->meta.version = mpack_node_i32(mpack_node_map_cstr(meta, "version"));
            mpack_node_t items = mpack_node_map_cstr(root, "items");
            int n = (int)mpack_node_array_length(items);
            if (n > V2_MAX_CHILDREN) n = V2_MAX_CHILDREN;
            d->item_count = n;
            for (int i = 0; i < n; i++) {
                mpack_node_t it = mpack_node_array_at(items, (size_t)i);
                mpack_node_copy_cstr(mpack_node_map_cstr(it, "sku"), d->items[i].sku, sizeof d->items[i].sku);
                d->items[i].qty = mpack_node_i32(mpack_node_map_cstr(it, "qty"));
                d->items[i].price_minor = mpack_node_i64(mpack_node_map_cstr(it, "price_minor"));
            }
            break;
        }
        case TD_TELEMETRY: {
            telemetry_t *t = &out->telemetry;
            mpack_node_copy_cstr(mpack_node_map_cstr(root, "source"), t->source, sizeof t->source);
            t->ts = mpack_node_i64(mpack_node_map_cstr(root, "ts"));
            mpack_node_t tags = mpack_node_map_cstr(root, "tags");
            int nt = (int)mpack_node_array_length(tags); if (nt > V2_MAX_TAGS) nt = V2_MAX_TAGS;
            t->tag_count = nt;
            for (int i = 0; i < nt; i++) {
                mpack_node_copy_cstr(mpack_node_array_at(tags, (size_t)i), t->tags[i], sizeof t->tags[i]);
            }
            mpack_node_t vals = mpack_node_map_cstr(root, "values");
            int nv = (int)mpack_node_array_length(vals); if (nv > V2_MAX_POINTS) nv = V2_MAX_POINTS;
            t->value_count = nv;
            for (int i = 0; i < nv; i++) t->values[i] = mpack_node_double(mpack_node_array_at(vals, (size_t)i));
            break;
        }
        case TD_STRINGS: {
            mpack_node_t items = mpack_node_map_cstr(root, "items");
            int n = (int)mpack_node_array_length(items); if (n > V2_MAX_STRINGS) n = V2_MAX_STRINGS;
            out->strings.count = n;
            for (int i = 0; i < n; i++) {
                mpack_node_copy_cstr(mpack_node_array_at(items, (size_t)i), out->strings.items[i], sizeof out->strings.items[i]);
            }
            break;
        }
        case TD_EVENT: {
            event_t *e = &out->event;
            mpack_node_copy_cstr(mpack_node_map_cstr(root, "event_id"), e->event_id, sizeof e->event_id);
            mpack_node_copy_cstr(mpack_node_map_cstr(root, "event_type"), e->event_type, sizeof e->event_type);
            e->occurred_at = mpack_node_i64(mpack_node_map_cstr(root, "occurred_at"));
            mpack_node_copy_cstr(mpack_node_map_cstr(root, "producer"), e->producer, sizeof e->producer);
            mpack_node_t attrs = mpack_node_map_cstr(root, "attrs");
            int n = (int)mpack_node_array_length(attrs); if (n > V2_MAX_ATTRS) n = V2_MAX_ATTRS;
            e->attr_count = n;
            for (int i = 0; i < n; i++) {
                mpack_node_t a = mpack_node_array_at(attrs, (size_t)i);
                mpack_node_copy_cstr(mpack_node_map_cstr(a, "key"), e->attrs[i].key, sizeof e->attrs[i].key);
                mpack_node_copy_cstr(mpack_node_map_cstr(a, "value"), e->attrs[i].value, sizeof e->attrs[i].value);
            }
            break;
        }
        default: return -1;
    }
    return mpack_node_error(root) == mpack_ok ? 0 : -1;
}

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    mpack_writer_t w;
    mpack_writer_init(&w, (char *)buf, cap);
    if (write_fx(&w, fx)) { mpack_writer_destroy(&w); return -1; }
    size_t used = mpack_writer_buffer_used(&w);
    if (mpack_writer_destroy(&w) != mpack_ok) return -1;
    *ol = used;
    return 0;
}
static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    mpack_tree_t tree;
    mpack_tree_init_data(&tree, (const char *)buf, len);
    mpack_tree_parse(&tree);
    if (mpack_tree_error(&tree) != mpack_ok) { mpack_tree_destroy(&tree); return -1; }
    int rc = read_fx(mpack_tree_root(&tree), out, kind);
    mpack_tree_destroy(&tree);
    return rc;
}
void bench_register_mpack(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "mpack", "1.1", "binary", prep, ser, de, fidelity_fx);
}
