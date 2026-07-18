#include "ser_common.h"
#include <bson/bson.h>

/* Native libbson document builder/reader for V2 field maps. */

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    bson_t b = BSON_INITIALIZER;
    switch (fx->kind) {
        case TD_MESSAGE: {
            const message_t *m = &fx->message;
            BSON_APPEND_BOOL(&b, "f_bool", m->f_bool);
            BSON_APPEND_INT32(&b, "f_int32", m->f_int32);
            BSON_APPEND_INT64(&b, "f_int64", m->f_int64);
            BSON_APPEND_DOUBLE(&b, "f_float64", m->f_float64);
            BSON_APPEND_UTF8(&b, "f_string", m->f_string);
            BSON_APPEND_BOOL(&b, "f_bool_2", m->f_bool_2);
            BSON_APPEND_INT32(&b, "f_int32_2", m->f_int32_2);
            BSON_APPEND_UTF8(&b, "f_string_2", m->f_string_2);
            break;
        }
        case TD_DOCUMENT: {
            const document_t *d = &fx->document;
            BSON_APPEND_UTF8(&b, "id", d->id);
            BSON_APPEND_INT32(&b, "status", d->status);
            bson_t meta;
            BSON_APPEND_DOCUMENT_BEGIN(&b, "meta", &meta);
            BSON_APPEND_UTF8(&meta, "region", d->meta.region);
            BSON_APPEND_INT32(&meta, "version", d->meta.version);
            bson_append_document_end(&b, &meta);
            bson_t items, it;
            BSON_APPEND_ARRAY_BEGIN(&b, "items", &items);
            for (int i = 0; i < d->item_count; i++) {
                char key[16]; snprintf(key, sizeof key, "%d", i);
                BSON_APPEND_DOCUMENT_BEGIN(&items, key, &it);
                BSON_APPEND_UTF8(&it, "sku", d->items[i].sku);
                BSON_APPEND_INT32(&it, "qty", d->items[i].qty);
                BSON_APPEND_INT64(&it, "price_minor", d->items[i].price_minor);
                bson_append_document_end(&items, &it);
            }
            bson_append_array_end(&b, &items);
            break;
        }
        case TD_TELEMETRY: {
            const telemetry_t *t = &fx->telemetry;
            BSON_APPEND_UTF8(&b, "source", t->source);
            BSON_APPEND_INT64(&b, "ts", t->ts);
            bson_t tags; BSON_APPEND_ARRAY_BEGIN(&b, "tags", &tags);
            for (int i = 0; i < t->tag_count; i++) {
                char key[16]; snprintf(key, sizeof key, "%d", i);
                BSON_APPEND_UTF8(&tags, key, t->tags[i]);
            }
            bson_append_array_end(&b, &tags);
            bson_t vals; BSON_APPEND_ARRAY_BEGIN(&b, "values", &vals);
            for (int i = 0; i < t->value_count; i++) {
                char key[16]; snprintf(key, sizeof key, "%d", i);
                BSON_APPEND_DOUBLE(&vals, key, t->values[i]);
            }
            bson_append_array_end(&b, &vals);
            break;
        }
        case TD_STRINGS: {
            bson_t items; BSON_APPEND_ARRAY_BEGIN(&b, "items", &items);
            for (int i = 0; i < fx->strings.count; i++) {
                char key[16]; snprintf(key, sizeof key, "%d", i);
                BSON_APPEND_UTF8(&items, key, fx->strings.items[i]);
            }
            bson_append_array_end(&b, &items);
            break;
        }
        case TD_EVENT: {
            const event_t *e = &fx->event;
            BSON_APPEND_UTF8(&b, "event_id", e->event_id);
            BSON_APPEND_UTF8(&b, "event_type", e->event_type);
            BSON_APPEND_INT64(&b, "occurred_at", e->occurred_at);
            BSON_APPEND_UTF8(&b, "producer", e->producer);
            bson_t attrs, a;
            BSON_APPEND_ARRAY_BEGIN(&b, "attrs", &attrs);
            for (int i = 0; i < e->attr_count; i++) {
                char key[16]; snprintf(key, sizeof key, "%d", i);
                BSON_APPEND_DOCUMENT_BEGIN(&attrs, key, &a);
                BSON_APPEND_UTF8(&a, "key", e->attrs[i].key);
                BSON_APPEND_UTF8(&a, "value", e->attrs[i].value);
                bson_append_document_end(&attrs, &a);
            }
            bson_append_array_end(&b, &attrs);
            break;
        }
        default: bson_destroy(&b); return -1;
    }
    if (b.len > cap) { bson_destroy(&b); return -1; }
    memcpy(buf, bson_get_data(&b), b.len);
    *ol = b.len;
    bson_destroy(&b);
    return 0;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    bson_t b;
    if (!bson_init_static(&b, buf, len)) return -1;
    memset(out, 0, sizeof *out);
    out->kind = kind; out->name = test_data_name(kind); out->batch_n = 1;
    bson_iter_t it;
    switch (kind) {
        case TD_MESSAGE: {
            message_t *m = &out->message;
            if (bson_iter_init_find(&it, &b, "f_bool")) m->f_bool = bson_iter_bool(&it);
            if (bson_iter_init_find(&it, &b, "f_int32")) m->f_int32 = bson_iter_int32(&it);
            if (bson_iter_init_find(&it, &b, "f_int64")) m->f_int64 = bson_iter_int64(&it);
            if (bson_iter_init_find(&it, &b, "f_float64")) m->f_float64 = bson_iter_double(&it);
            if (bson_iter_init_find(&it, &b, "f_string")) {
                const char *s = bson_iter_utf8(&it, NULL); if (s) snprintf(m->f_string, sizeof m->f_string, "%s", s);
            }
            if (bson_iter_init_find(&it, &b, "f_bool_2")) m->f_bool_2 = bson_iter_bool(&it);
            if (bson_iter_init_find(&it, &b, "f_int32_2")) m->f_int32_2 = bson_iter_int32(&it);
            if (bson_iter_init_find(&it, &b, "f_string_2")) {
                const char *s = bson_iter_utf8(&it, NULL); if (s) snprintf(m->f_string_2, sizeof m->f_string_2, "%s", s);
            }
            break;
        }
        case TD_DOCUMENT: {
            document_t *d = &out->document;
            if (bson_iter_init_find(&it, &b, "id")) { const char *s = bson_iter_utf8(&it, NULL); if (s) snprintf(d->id, sizeof d->id, "%s", s); }
            if (bson_iter_init_find(&it, &b, "status")) d->status = bson_iter_int32(&it);
            if (bson_iter_init_find(&it, &b, "meta") && BSON_ITER_HOLDS_DOCUMENT(&it)) {
                bson_iter_t meta; bson_iter_recurse(&it, &meta);
                while (bson_iter_next(&meta)) {
                    if (strcmp(bson_iter_key(&meta), "region") == 0) {
                        const char *s = bson_iter_utf8(&meta, NULL); if (s) snprintf(d->meta.region, sizeof d->meta.region, "%s", s);
                    } else if (strcmp(bson_iter_key(&meta), "version") == 0) d->meta.version = bson_iter_int32(&meta);
                }
            }
            if (bson_iter_init_find(&it, &b, "items") && BSON_ITER_HOLDS_ARRAY(&it)) {
                bson_iter_t arr, el; bson_iter_recurse(&it, &arr);
                int i = 0;
                while (bson_iter_next(&arr) && i < V2_MAX_CHILDREN) {
                    if (BSON_ITER_HOLDS_DOCUMENT(&arr)) {
                        bson_iter_recurse(&arr, &el);
                        while (bson_iter_next(&el)) {
                            if (strcmp(bson_iter_key(&el), "sku") == 0) {
                                const char *s = bson_iter_utf8(&el, NULL); if (s) snprintf(d->items[i].sku, sizeof d->items[i].sku, "%s", s);
                            } else if (strcmp(bson_iter_key(&el), "qty") == 0) d->items[i].qty = bson_iter_int32(&el);
                            else if (strcmp(bson_iter_key(&el), "price_minor") == 0) d->items[i].price_minor = bson_iter_int64(&el);
                        }
                        i++;
                    }
                }
                d->item_count = i;
            }
            break;
        }
        case TD_TELEMETRY: {
            telemetry_t *t = &out->telemetry;
            if (bson_iter_init_find(&it, &b, "source")) { const char *s = bson_iter_utf8(&it, NULL); if (s) snprintf(t->source, sizeof t->source, "%s", s); }
            if (bson_iter_init_find(&it, &b, "ts")) t->ts = bson_iter_int64(&it);
            if (bson_iter_init_find(&it, &b, "tags") && BSON_ITER_HOLDS_ARRAY(&it)) {
                bson_iter_t arr; bson_iter_recurse(&it, &arr);
                int i = 0;
                while (bson_iter_next(&arr) && i < V2_MAX_TAGS) {
                    if (BSON_ITER_HOLDS_UTF8(&arr)) {
                        const char *s = bson_iter_utf8(&arr, NULL); if (s) snprintf(t->tags[i], sizeof t->tags[i], "%s", s);
                        i++;
                    }
                }
                t->tag_count = i;
            }
            if (bson_iter_init_find(&it, &b, "values") && BSON_ITER_HOLDS_ARRAY(&it)) {
                bson_iter_t arr; bson_iter_recurse(&it, &arr);
                int i = 0;
                while (bson_iter_next(&arr) && i < V2_MAX_POINTS) {
                    if (BSON_ITER_HOLDS_DOUBLE(&arr)) t->values[i++] = bson_iter_double(&arr);
                }
                t->value_count = i;
            }
            break;
        }
        case TD_STRINGS: {
            if (bson_iter_init_find(&it, &b, "items") && BSON_ITER_HOLDS_ARRAY(&it)) {
                bson_iter_t arr; bson_iter_recurse(&it, &arr);
                int i = 0;
                while (bson_iter_next(&arr) && i < V2_MAX_STRINGS) {
                    if (BSON_ITER_HOLDS_UTF8(&arr)) {
                        const char *s = bson_iter_utf8(&arr, NULL); if (s) snprintf(out->strings.items[i], sizeof out->strings.items[i], "%s", s);
                        i++;
                    }
                }
                out->strings.count = i;
            }
            break;
        }
        case TD_EVENT: {
            event_t *e = &out->event;
            if (bson_iter_init_find(&it, &b, "event_id")) { const char *s = bson_iter_utf8(&it, NULL); if (s) snprintf(e->event_id, sizeof e->event_id, "%s", s); }
            if (bson_iter_init_find(&it, &b, "event_type")) { const char *s = bson_iter_utf8(&it, NULL); if (s) snprintf(e->event_type, sizeof e->event_type, "%s", s); }
            if (bson_iter_init_find(&it, &b, "occurred_at")) e->occurred_at = bson_iter_int64(&it);
            if (bson_iter_init_find(&it, &b, "producer")) { const char *s = bson_iter_utf8(&it, NULL); if (s) snprintf(e->producer, sizeof e->producer, "%s", s); }
            if (bson_iter_init_find(&it, &b, "attrs") && BSON_ITER_HOLDS_ARRAY(&it)) {
                bson_iter_t arr, el; bson_iter_recurse(&it, &arr);
                int i = 0;
                while (bson_iter_next(&arr) && i < V2_MAX_ATTRS) {
                    if (BSON_ITER_HOLDS_DOCUMENT(&arr)) {
                        bson_iter_recurse(&arr, &el);
                        while (bson_iter_next(&el)) {
                            if (strcmp(bson_iter_key(&el), "key") == 0) {
                                const char *s = bson_iter_utf8(&el, NULL); if (s) snprintf(e->attrs[i].key, sizeof e->attrs[i].key, "%s", s);
                            } else if (strcmp(bson_iter_key(&el), "value") == 0) {
                                const char *s = bson_iter_utf8(&el, NULL); if (s) snprintf(e->attrs[i].value, sizeof e->attrs[i].value, "%s", s);
                            }
                        }
                        i++;
                    }
                }
                e->attr_count = i;
            }
            break;
        }
        default: return -1;
    }
    return 0;
}
void bench_register_libbson(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "libbson", "1.27.5", "binary", prep, ser, de, fidelity_fx);
}
