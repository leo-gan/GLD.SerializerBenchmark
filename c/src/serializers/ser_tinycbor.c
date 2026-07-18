#include "ser_common.h"
#include "tinycbor_pref.h"

/* Native tinycbor CborEncoder / CborParser for V2 maps. */

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static CborError enc_str(CborEncoder *e, const char *s) {
    return cbor_encode_text_stringz(e, s);
}

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    CborEncoder enc, map;
    cbor_encoder_init(&enc, buf, cap, 0);
    switch (fx->kind) {
        case TD_MESSAGE: {
            const message_t *m = &fx->message;
            if (cbor_encoder_create_map(&enc, &map, 8) != CborNoError) return -1;
            if (enc_str(&map, "f_bool") || cbor_encode_boolean(&map, m->f_bool)) return -1;
            if (enc_str(&map, "f_int32") || cbor_encode_int(&map, m->f_int32)) return -1;
            if (enc_str(&map, "f_int64") || cbor_encode_int(&map, m->f_int64)) return -1;
            if (enc_str(&map, "f_float64") || cbor_encode_double(&map, m->f_float64)) return -1;
            if (enc_str(&map, "f_string") || enc_str(&map, m->f_string)) return -1;
            if (enc_str(&map, "f_bool_2") || cbor_encode_boolean(&map, m->f_bool_2)) return -1;
            if (enc_str(&map, "f_int32_2") || cbor_encode_int(&map, m->f_int32_2)) return -1;
            if (enc_str(&map, "f_string_2") || enc_str(&map, m->f_string_2)) return -1;
            if (cbor_encoder_close_container(&enc, &map) != CborNoError) return -1;
            break;
        }
        case TD_DOCUMENT: {
            const document_t *d = &fx->document;
            CborEncoder meta, items, it;
            if (cbor_encoder_create_map(&enc, &map, 4) != CborNoError) return -1;
            if (enc_str(&map, "id") || enc_str(&map, d->id)) return -1;
            if (enc_str(&map, "status") || cbor_encode_int(&map, d->status)) return -1;
            if (enc_str(&map, "meta") || cbor_encoder_create_map(&map, &meta, 2) != CborNoError) return -1;
            if (enc_str(&meta, "region") || enc_str(&meta, d->meta.region)) return -1;
            if (enc_str(&meta, "version") || cbor_encode_int(&meta, d->meta.version)) return -1;
            if (cbor_encoder_close_container(&map, &meta) != CborNoError) return -1;
            if (enc_str(&map, "items") || cbor_encoder_create_array(&map, &items, (size_t)d->item_count) != CborNoError) return -1;
            for (int i = 0; i < d->item_count; i++) {
                if (cbor_encoder_create_map(&items, &it, 3) != CborNoError) return -1;
                if (enc_str(&it, "sku") || enc_str(&it, d->items[i].sku)) return -1;
                if (enc_str(&it, "qty") || cbor_encode_int(&it, d->items[i].qty)) return -1;
                if (enc_str(&it, "price_minor") || cbor_encode_int(&it, d->items[i].price_minor)) return -1;
                if (cbor_encoder_close_container(&items, &it) != CborNoError) return -1;
            }
            if (cbor_encoder_close_container(&map, &items) != CborNoError) return -1;
            if (cbor_encoder_close_container(&enc, &map) != CborNoError) return -1;
            break;
        }
        case TD_TELEMETRY: {
            const telemetry_t *t = &fx->telemetry;
            CborEncoder tags, vals;
            if (cbor_encoder_create_map(&enc, &map, 4) != CborNoError) return -1;
            if (enc_str(&map, "source") || enc_str(&map, t->source)) return -1;
            if (enc_str(&map, "ts") || cbor_encode_int(&map, t->ts)) return -1;
            if (enc_str(&map, "tags") || cbor_encoder_create_array(&map, &tags, (size_t)t->tag_count) != CborNoError) return -1;
            for (int i = 0; i < t->tag_count; i++) if (enc_str(&tags, t->tags[i])) return -1;
            if (cbor_encoder_close_container(&map, &tags) != CborNoError) return -1;
            if (enc_str(&map, "values") || cbor_encoder_create_array(&map, &vals, (size_t)t->value_count) != CborNoError) return -1;
            for (int i = 0; i < t->value_count; i++) if (cbor_encode_double(&vals, t->values[i])) return -1;
            if (cbor_encoder_close_container(&map, &vals) != CborNoError) return -1;
            if (cbor_encoder_close_container(&enc, &map) != CborNoError) return -1;
            break;
        }
        case TD_STRINGS: {
            CborEncoder items;
            if (cbor_encoder_create_map(&enc, &map, 1) != CborNoError) return -1;
            if (enc_str(&map, "items") || cbor_encoder_create_array(&map, &items, (size_t)fx->strings.count) != CborNoError) return -1;
            for (int i = 0; i < fx->strings.count; i++) if (enc_str(&items, fx->strings.items[i])) return -1;
            if (cbor_encoder_close_container(&map, &items) != CborNoError) return -1;
            if (cbor_encoder_close_container(&enc, &map) != CborNoError) return -1;
            break;
        }
        case TD_EVENT: {
            const event_t *e = &fx->event;
            CborEncoder attrs, a;
            if (cbor_encoder_create_map(&enc, &map, 5) != CborNoError) return -1;
            if (enc_str(&map, "event_id") || enc_str(&map, e->event_id)) return -1;
            if (enc_str(&map, "event_type") || enc_str(&map, e->event_type)) return -1;
            if (enc_str(&map, "occurred_at") || cbor_encode_int(&map, e->occurred_at)) return -1;
            if (enc_str(&map, "producer") || enc_str(&map, e->producer)) return -1;
            if (enc_str(&map, "attrs") || cbor_encoder_create_array(&map, &attrs, (size_t)e->attr_count) != CborNoError) return -1;
            for (int i = 0; i < e->attr_count; i++) {
                if (cbor_encoder_create_map(&attrs, &a, 2) != CborNoError) return -1;
                if (enc_str(&a, "key") || enc_str(&a, e->attrs[i].key)) return -1;
                if (enc_str(&a, "value") || enc_str(&a, e->attrs[i].value)) return -1;
                if (cbor_encoder_close_container(&attrs, &a) != CborNoError) return -1;
            }
            if (cbor_encoder_close_container(&map, &attrs) != CborNoError) return -1;
            if (cbor_encoder_close_container(&enc, &map) != CborNoError) return -1;
            break;
        }
        default: return -1;
    }
    *ol = cbor_encoder_get_buffer_size(&enc, buf);
    return 0;
}

/* Decode: cbor_value_map_find_value requires a map CborValue (not entered iterator). */
int bench_tinycbor_de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    CborParser parser;
    CborValue root, v;
    if (cbor_parser_init(buf, len, 0, &parser, &root) != CborNoError) return -1;
    if (!cbor_value_is_map(&root)) return -1;
    memset(out, 0, sizeof *out);
    out->kind = kind;
    out->name = test_data_name(kind);
    out->batch_n = 1;

    if (kind == TD_MESSAGE) {
        message_t *m = &out->message;
        bool b; int64_t i; double d; size_t n;
        if (cbor_value_map_find_value(&root, "f_bool", &v) == CborNoError && cbor_value_is_boolean(&v))
            { cbor_value_get_boolean(&v, &b); m->f_bool = b; }
        if (cbor_value_map_find_value(&root, "f_int32", &v) == CborNoError && cbor_value_is_integer(&v))
            { cbor_value_get_int64(&v, &i); m->f_int32 = (int32_t)i; }
        if (cbor_value_map_find_value(&root, "f_int64", &v) == CborNoError && cbor_value_is_integer(&v))
            { cbor_value_get_int64(&v, &i); m->f_int64 = i; }
        if (cbor_value_map_find_value(&root, "f_float64", &v) == CborNoError && cbor_value_is_double(&v))
            { cbor_value_get_double(&v, &d); m->f_float64 = d; }
        if (cbor_value_map_find_value(&root, "f_string", &v) == CborNoError && cbor_value_is_text_string(&v)) {
            n = sizeof m->f_string;
            if (cbor_value_copy_text_string(&v, m->f_string, &n, NULL) == CborNoError) {
                if (n >= sizeof m->f_string) n = sizeof m->f_string - 1;
                m->f_string[n] = 0;
            }
        }
        if (cbor_value_map_find_value(&root, "f_bool_2", &v) == CborNoError && cbor_value_is_boolean(&v))
            { cbor_value_get_boolean(&v, &b); m->f_bool_2 = b; }
        if (cbor_value_map_find_value(&root, "f_int32_2", &v) == CborNoError && cbor_value_is_integer(&v))
            { cbor_value_get_int64(&v, &i); m->f_int32_2 = (int32_t)i; }
        if (cbor_value_map_find_value(&root, "f_string_2", &v) == CborNoError && cbor_value_is_text_string(&v)) {
            n = sizeof m->f_string_2;
            if (cbor_value_copy_text_string(&v, m->f_string_2, &n, NULL) == CborNoError) {
                if (n >= sizeof m->f_string_2) n = sizeof m->f_string_2 - 1;
                m->f_string_2[n] = 0;
            }
        }
        return 0;
    }
    if (kind == TD_STRINGS) {
        CborValue arr, el;
        if (cbor_value_map_find_value(&root, "items", &arr) != CborNoError || !cbor_value_is_array(&arr)) return -1;
        if (cbor_value_enter_container(&arr, &el) != CborNoError) return -1;
        int i = 0;
        while (!cbor_value_at_end(&el) && i < V2_MAX_STRINGS) {
            if (cbor_value_is_text_string(&el)) {
                size_t n = sizeof out->strings.items[i];
                cbor_value_copy_text_string(&el, out->strings.items[i], &n, &el);
                if (n >= sizeof out->strings.items[i]) n = sizeof out->strings.items[i] - 1;
                out->strings.items[i][n] = 0;
            } else {
                cbor_value_advance(&el);
            }
            i++;
        }
        out->strings.count = i;
        return 0;
    }
    if (kind == TD_DOCUMENT) {
        document_t *d = &out->document;
        size_t n; int64_t i64;
        if (cbor_value_map_find_value(&root, "id", &v) == CborNoError && cbor_value_is_text_string(&v)) {
            n = sizeof d->id; cbor_value_copy_text_string(&v, d->id, &n, NULL);
            if (n >= sizeof d->id) n = sizeof d->id - 1; d->id[n] = 0;
        }
        if (cbor_value_map_find_value(&root, "status", &v) == CborNoError && cbor_value_is_integer(&v))
            { cbor_value_get_int64(&v, &i64); d->status = (int32_t)i64; }
        CborValue meta, items, el;
        if (cbor_value_map_find_value(&root, "meta", &meta) == CborNoError && cbor_value_is_map(&meta)) {
            CborValue mv;
            if (cbor_value_map_find_value(&meta, "region", &mv) == CborNoError && cbor_value_is_text_string(&mv)) {
                n = sizeof d->meta.region; cbor_value_copy_text_string(&mv, d->meta.region, &n, NULL);
                if (n >= sizeof d->meta.region) n = sizeof d->meta.region - 1; d->meta.region[n] = 0;
            }
            if (cbor_value_map_find_value(&meta, "version", &mv) == CborNoError && cbor_value_is_integer(&mv))
                { cbor_value_get_int64(&mv, &i64); d->meta.version = (int32_t)i64; }
        }
        if (cbor_value_map_find_value(&root, "items", &items) == CborNoError && cbor_value_is_array(&items)) {
            if (cbor_value_enter_container(&items, &el) != CborNoError) return -1;
            int i = 0;
            while (!cbor_value_at_end(&el) && i < V2_MAX_CHILDREN) {
                if (cbor_value_is_map(&el)) {
                    CborValue f;
                    if (cbor_value_map_find_value(&el, "sku", &f) == CborNoError && cbor_value_is_text_string(&f)) {
                        n = sizeof d->items[i].sku; cbor_value_copy_text_string(&f, d->items[i].sku, &n, NULL);
                        if (n >= sizeof d->items[i].sku) n = sizeof d->items[i].sku - 1; d->items[i].sku[n] = 0;
                    }
                    if (cbor_value_map_find_value(&el, "qty", &f) == CborNoError && cbor_value_is_integer(&f))
                        { cbor_value_get_int64(&f, &i64); d->items[i].qty = (int32_t)i64; }
                    if (cbor_value_map_find_value(&el, "price_minor", &f) == CborNoError && cbor_value_is_integer(&f))
                        { cbor_value_get_int64(&f, &i64); d->items[i].price_minor = i64; }
                }
                cbor_value_advance(&el);
                i++;
            }
            d->item_count = i;
        }
        return 0;
    }
    if (kind == TD_TELEMETRY) {
        telemetry_t *t = &out->telemetry;
        size_t n; int64_t i64; double d;
        if (cbor_value_map_find_value(&root, "source", &v) == CborNoError && cbor_value_is_text_string(&v)) {
            n = sizeof t->source; cbor_value_copy_text_string(&v, t->source, &n, NULL);
            if (n >= sizeof t->source) n = sizeof t->source - 1; t->source[n] = 0;
        }
        if (cbor_value_map_find_value(&root, "ts", &v) == CborNoError && cbor_value_is_integer(&v))
            { cbor_value_get_int64(&v, &i64); t->ts = i64; }
        CborValue arr, el;
        if (cbor_value_map_find_value(&root, "tags", &arr) == CborNoError && cbor_value_is_array(&arr)) {
            if (cbor_value_enter_container(&arr, &el) != CborNoError) return -1;
            int i = 0;
            while (!cbor_value_at_end(&el) && i < V2_MAX_TAGS) {
                if (cbor_value_is_text_string(&el)) {
                    n = sizeof t->tags[i]; cbor_value_copy_text_string(&el, t->tags[i], &n, &el);
                    if (n >= sizeof t->tags[i]) n = sizeof t->tags[i] - 1; t->tags[i][n] = 0;
                } else cbor_value_advance(&el);
                i++;
            }
            t->tag_count = i;
        }
        if (cbor_value_map_find_value(&root, "values", &arr) == CborNoError && cbor_value_is_array(&arr)) {
            if (cbor_value_enter_container(&arr, &el) != CborNoError) return -1;
            int i = 0;
            while (!cbor_value_at_end(&el) && i < V2_MAX_POINTS) {
                if (cbor_value_is_double(&el)) { cbor_value_get_double(&el, &d); t->values[i++] = d; cbor_value_advance(&el); }
                else cbor_value_advance(&el);
            }
            t->value_count = i;
        }
        return 0;
    }
    if (kind == TD_EVENT) {
        event_t *e = &out->event;
        size_t n; int64_t i64;
        if (cbor_value_map_find_value(&root, "event_id", &v) == CborNoError && cbor_value_is_text_string(&v)) {
            n = sizeof e->event_id; cbor_value_copy_text_string(&v, e->event_id, &n, NULL);
            if (n >= sizeof e->event_id) n = sizeof e->event_id - 1; e->event_id[n] = 0;
        }
        if (cbor_value_map_find_value(&root, "event_type", &v) == CborNoError && cbor_value_is_text_string(&v)) {
            n = sizeof e->event_type; cbor_value_copy_text_string(&v, e->event_type, &n, NULL);
            if (n >= sizeof e->event_type) n = sizeof e->event_type - 1; e->event_type[n] = 0;
        }
        if (cbor_value_map_find_value(&root, "occurred_at", &v) == CborNoError && cbor_value_is_integer(&v))
            { cbor_value_get_int64(&v, &i64); e->occurred_at = i64; }
        if (cbor_value_map_find_value(&root, "producer", &v) == CborNoError && cbor_value_is_text_string(&v)) {
            n = sizeof e->producer; cbor_value_copy_text_string(&v, e->producer, &n, NULL);
            if (n >= sizeof e->producer) n = sizeof e->producer - 1; e->producer[n] = 0;
        }
        CborValue attrs, el;
        if (cbor_value_map_find_value(&root, "attrs", &attrs) == CborNoError && cbor_value_is_array(&attrs)) {
            if (cbor_value_enter_container(&attrs, &el) != CborNoError) return -1;
            int i = 0;
            while (!cbor_value_at_end(&el) && i < V2_MAX_ATTRS) {
                if (cbor_value_is_map(&el)) {
                    CborValue f;
                    if (cbor_value_map_find_value(&el, "key", &f) == CborNoError && cbor_value_is_text_string(&f)) {
                        n = sizeof e->attrs[i].key; cbor_value_copy_text_string(&f, e->attrs[i].key, &n, NULL);
                        if (n >= sizeof e->attrs[i].key) n = sizeof e->attrs[i].key - 1; e->attrs[i].key[n] = 0;
                    }
                    if (cbor_value_map_find_value(&el, "value", &f) == CborNoError && cbor_value_is_text_string(&f)) {
                        n = sizeof e->attrs[i].value; cbor_value_copy_text_string(&f, e->attrs[i].value, &n, NULL);
                        if (n >= sizeof e->attrs[i].value) n = sizeof e->attrs[i].value - 1; e->attrs[i].value[n] = 0;
                    }
                }
                cbor_value_advance(&el);
                i++;
            }
            e->attr_count = i;
        }
        return 0;
    }
    return -1;
}
void bench_register_tinycbor(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "tinycbor", "0.6.0", "binary", prep, ser, bench_tinycbor_de, fidelity_fx);
}
