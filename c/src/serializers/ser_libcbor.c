#include "ser_common.h"
/* Disambiguate from tinycbor's cbor.h (earlier on include path). */
#include "../../third_party/libcbor/src/cbor.h"

/* Native libcbor encode (cbor_item_t tree + cbor_serialize). Decode via tinycbor
 * map walker (standard CBOR maps are interoperable). */

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static cbor_item_t *str(const char *s) { return cbor_build_string(s); }
static cbor_item_t *sint(int64_t v) {
    if (v >= 0) return cbor_build_uint64((uint64_t)v);
    return cbor_build_negint64((uint64_t)(-1 - v));
}
static cbor_item_t *f64(double v) { return cbor_build_float8(v); }
static cbor_item_t *boolean(bool v) { return cbor_build_bool(v); }

static void map_add(cbor_item_t *m, const char *k, cbor_item_t *v) {
    cbor_map_add(m, (struct cbor_pair){ .key = cbor_move(str(k)), .value = cbor_move(v) });
}

static cbor_item_t *fx_to_item(const test_fixture_t *fx) {
    cbor_item_t *m = cbor_new_definite_map(16);
    if (!m) return NULL;
    switch (fx->kind) {
        case TD_MESSAGE: {
            const message_t *x = &fx->message;
            map_add(m, "f_bool", boolean(x->f_bool));
            map_add(m, "f_int32", sint(x->f_int32));
            map_add(m, "f_int64", sint(x->f_int64));
            map_add(m, "f_float64", f64(x->f_float64));
            map_add(m, "f_string", str(x->f_string));
            map_add(m, "f_bool_2", boolean(x->f_bool_2));
            map_add(m, "f_int32_2", sint(x->f_int32_2));
            map_add(m, "f_string_2", str(x->f_string_2));
            break;
        }
        case TD_DOCUMENT: {
            const document_t *d = &fx->document;
            map_add(m, "id", str(d->id));
            map_add(m, "status", sint(d->status));
            cbor_item_t *meta = cbor_new_definite_map(2);
            map_add(meta, "region", str(d->meta.region));
            map_add(meta, "version", sint(d->meta.version));
            map_add(m, "meta", meta);
            cbor_item_t *items = cbor_new_definite_array((size_t)d->item_count);
            for (int i = 0; i < d->item_count; i++) {
                cbor_item_t *it = cbor_new_definite_map(3);
                map_add(it, "sku", str(d->items[i].sku));
                map_add(it, "qty", sint(d->items[i].qty));
                map_add(it, "price_minor", sint(d->items[i].price_minor));
                cbor_array_push(items, cbor_move(it));
            }
            map_add(m, "items", items);
            break;
        }
        case TD_TELEMETRY: {
            const telemetry_t *t = &fx->telemetry;
            map_add(m, "source", str(t->source));
            map_add(m, "ts", sint(t->ts));
            cbor_item_t *tags = cbor_new_definite_array((size_t)t->tag_count);
            for (int i = 0; i < t->tag_count; i++) cbor_array_push(tags, cbor_move(str(t->tags[i])));
            map_add(m, "tags", tags);
            cbor_item_t *vals = cbor_new_definite_array((size_t)t->value_count);
            for (int i = 0; i < t->value_count; i++) cbor_array_push(vals, cbor_move(f64(t->values[i])));
            map_add(m, "values", vals);
            break;
        }
        case TD_STRINGS: {
            cbor_item_t *items = cbor_new_definite_array((size_t)fx->strings.count);
            for (int i = 0; i < fx->strings.count; i++) cbor_array_push(items, cbor_move(str(fx->strings.items[i])));
            map_add(m, "items", items);
            break;
        }
        case TD_EVENT: {
            const event_t *e = &fx->event;
            map_add(m, "event_id", str(e->event_id));
            map_add(m, "event_type", str(e->event_type));
            map_add(m, "occurred_at", sint(e->occurred_at));
            map_add(m, "producer", str(e->producer));
            cbor_item_t *attrs = cbor_new_definite_array((size_t)e->attr_count);
            for (int i = 0; i < e->attr_count; i++) {
                cbor_item_t *a = cbor_new_definite_map(2);
                map_add(a, "key", str(e->attrs[i].key));
                map_add(a, "value", str(e->attrs[i].value));
                cbor_array_push(attrs, cbor_move(a));
            }
            map_add(m, "attrs", attrs);
            break;
        }
        default: cbor_decref(&m); return NULL;
    }
    return m;
}

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    cbor_item_t *item = fx_to_item(fx);
    if (!item) return -1;
    size_t len = cbor_serialize(item, buf, cap);
    cbor_decref(&item);
    if (len == 0 || len > cap) return -1;
    *ol = len;
    return 0;
}
static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    return bench_tinycbor_de(buf, len, out, kind);
}
void bench_register_libcbor(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "cbor-encode", "0.11.0", "binary", prep, ser, de, fidelity_fx);
}
