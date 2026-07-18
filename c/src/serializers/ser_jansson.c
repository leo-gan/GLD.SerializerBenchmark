#include "ser_common.h"
#include <jansson.h>

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static json_t *fx_to_json(const test_fixture_t *fx) {
    json_t *root = json_object();
    if (!root) return NULL;
    json_object_set_new(root, "type", json_string(test_data_name(fx->kind)));
    switch (fx->kind) {
        case TD_MESSAGE: {
            const message_t *m = &fx->message;
            json_object_set_new(root, "f_bool", json_boolean(m->f_bool));
            json_object_set_new(root, "f_int32", json_integer(m->f_int32));
            json_object_set_new(root, "f_int64", json_integer(m->f_int64));
            json_object_set_new(root, "f_float64", json_real(m->f_float64));
            json_object_set_new(root, "f_string", json_string(m->f_string));
            json_object_set_new(root, "f_bool_2", json_boolean(m->f_bool_2));
            json_object_set_new(root, "f_int32_2", json_integer(m->f_int32_2));
            json_object_set_new(root, "f_string_2", json_string(m->f_string_2));
            break;
        }
        case TD_DOCUMENT: {
            const document_t *d = &fx->document;
            json_object_set_new(root, "id", json_string(d->id));
            json_object_set_new(root, "status", json_integer(d->status));
            json_t *meta = json_object();
            json_object_set_new(meta, "region", json_string(d->meta.region));
            json_object_set_new(meta, "version", json_integer(d->meta.version));
            json_object_set_new(root, "meta", meta);
            json_t *items = json_array();
            for (int i = 0; i < d->item_count; i++) {
                json_t *it = json_object();
                json_object_set_new(it, "sku", json_string(d->items[i].sku));
                json_object_set_new(it, "qty", json_integer(d->items[i].qty));
                json_object_set_new(it, "price_minor", json_integer(d->items[i].price_minor));
                json_array_append_new(items, it);
            }
            json_object_set_new(root, "items", items);
            break;
        }
        case TD_TELEMETRY: {
            const telemetry_t *t = &fx->telemetry;
            json_object_set_new(root, "source", json_string(t->source));
            json_object_set_new(root, "ts", json_integer(t->ts));
            json_t *tags = json_array();
            for (int i = 0; i < t->tag_count; i++) json_array_append_new(tags, json_string(t->tags[i]));
            json_object_set_new(root, "tags", tags);
            json_t *vals = json_array();
            for (int i = 0; i < t->value_count; i++) json_array_append_new(vals, json_real(t->values[i]));
            json_object_set_new(root, "values", vals);
            break;
        }
        case TD_STRINGS: {
            json_t *items = json_array();
            for (int i = 0; i < fx->strings.count; i++)
                json_array_append_new(items, json_string(fx->strings.items[i]));
            json_object_set_new(root, "items", items);
            break;
        }
        case TD_EVENT: {
            const event_t *e = &fx->event;
            json_object_set_new(root, "event_id", json_string(e->event_id));
            json_object_set_new(root, "event_type", json_string(e->event_type));
            json_object_set_new(root, "occurred_at", json_integer(e->occurred_at));
            json_object_set_new(root, "producer", json_string(e->producer));
            json_t *attrs = json_array();
            for (int i = 0; i < e->attr_count; i++) {
                json_t *a = json_object();
                json_object_set_new(a, "key", json_string(e->attrs[i].key));
                json_object_set_new(a, "value", json_string(e->attrs[i].value));
                json_array_append_new(attrs, a);
            }
            json_object_set_new(root, "attrs", attrs);
            break;
        }
        default: json_decref(root); return NULL;
    }
    return root;
}

static int json_to_fx(json_t *root, test_fixture_t *out, test_data_kind_t kind) {
    memset(out, 0, sizeof *out);
    out->kind = kind; out->name = test_data_name(kind); out->batch_n = 1;
    switch (kind) {
        case TD_MESSAGE: {
            message_t *m = &out->message;
            m->f_bool = json_is_true(json_object_get(root, "f_bool"));
            m->f_int32 = (int32_t)json_integer_value(json_object_get(root, "f_int32"));
            m->f_int64 = (int64_t)json_integer_value(json_object_get(root, "f_int64"));
            m->f_float64 = json_real_value(json_object_get(root, "f_float64"));
            { const char *s = json_string_value(json_object_get(root, "f_string")); if (s) snprintf(m->f_string, sizeof m->f_string, "%s", s); }
            m->f_bool_2 = json_is_true(json_object_get(root, "f_bool_2"));
            m->f_int32_2 = (int32_t)json_integer_value(json_object_get(root, "f_int32_2"));
            { const char *s = json_string_value(json_object_get(root, "f_string_2")); if (s) snprintf(m->f_string_2, sizeof m->f_string_2, "%s", s); }
            break;
        }
        case TD_DOCUMENT: {
            document_t *d = &out->document;
            { const char *s = json_string_value(json_object_get(root, "id")); if (s) snprintf(d->id, sizeof d->id, "%s", s); }
            d->status = (int32_t)json_integer_value(json_object_get(root, "status"));
            json_t *meta = json_object_get(root, "meta");
            if (meta) {
                const char *r = json_string_value(json_object_get(meta, "region"));
                if (r) snprintf(d->meta.region, sizeof d->meta.region, "%s", r);
                d->meta.version = (int32_t)json_integer_value(json_object_get(meta, "version"));
            }
            json_t *items = json_object_get(root, "items");
            if (json_is_array(items)) {
                size_t n = json_array_size(items); if (n > V2_MAX_CHILDREN) n = V2_MAX_CHILDREN;
                d->item_count = (int)n;
                for (size_t i = 0; i < n; i++) {
                    json_t *it = json_array_get(items, i);
                    const char *sku = json_string_value(json_object_get(it, "sku"));
                    if (sku) snprintf(d->items[i].sku, sizeof d->items[i].sku, "%s", sku);
                    d->items[i].qty = (int32_t)json_integer_value(json_object_get(it, "qty"));
                    d->items[i].price_minor = (int64_t)json_integer_value(json_object_get(it, "price_minor"));
                }
            }
            break;
        }
        case TD_TELEMETRY: {
            telemetry_t *t = &out->telemetry;
            { const char *s = json_string_value(json_object_get(root, "source")); if (s) snprintf(t->source, sizeof t->source, "%s", s); }
            t->ts = (int64_t)json_integer_value(json_object_get(root, "ts"));
            json_t *tags = json_object_get(root, "tags");
            if (json_is_array(tags)) {
                size_t n = json_array_size(tags); if (n > V2_MAX_TAGS) n = V2_MAX_TAGS;
                t->tag_count = (int)n;
                for (size_t i = 0; i < n; i++) {
                    const char *s = json_string_value(json_array_get(tags, i));
                    if (s) snprintf(t->tags[i], sizeof t->tags[i], "%s", s);
                }
            }
            json_t *vals = json_object_get(root, "values");
            if (json_is_array(vals)) {
                size_t n = json_array_size(vals); if (n > V2_MAX_POINTS) n = V2_MAX_POINTS;
                t->value_count = (int)n;
                for (size_t i = 0; i < n; i++) t->values[i] = json_number_value(json_array_get(vals, i));
            }
            break;
        }
        case TD_STRINGS: {
            json_t *items = json_object_get(root, "items");
            if (json_is_array(items)) {
                size_t n = json_array_size(items); if (n > V2_MAX_STRINGS) n = V2_MAX_STRINGS;
                out->strings.count = (int)n;
                for (size_t i = 0; i < n; i++) {
                    const char *s = json_string_value(json_array_get(items, i));
                    if (s) snprintf(out->strings.items[i], sizeof out->strings.items[i], "%s", s);
                }
            }
            break;
        }
        case TD_EVENT: {
            event_t *e = &out->event;
            { const char *s = json_string_value(json_object_get(root, "event_id")); if (s) snprintf(e->event_id, sizeof e->event_id, "%s", s); }
            { const char *s = json_string_value(json_object_get(root, "event_type")); if (s) snprintf(e->event_type, sizeof e->event_type, "%s", s); }
            e->occurred_at = (int64_t)json_integer_value(json_object_get(root, "occurred_at"));
            { const char *s = json_string_value(json_object_get(root, "producer")); if (s) snprintf(e->producer, sizeof e->producer, "%s", s); }
            json_t *attrs = json_object_get(root, "attrs");
            if (json_is_array(attrs)) {
                size_t n = json_array_size(attrs); if (n > V2_MAX_ATTRS) n = V2_MAX_ATTRS;
                e->attr_count = (int)n;
                for (size_t i = 0; i < n; i++) {
                    json_t *a = json_array_get(attrs, i);
                    const char *k = json_string_value(json_object_get(a, "key"));
                    const char *v = json_string_value(json_object_get(a, "value"));
                    if (k) snprintf(e->attrs[i].key, sizeof e->attrs[i].key, "%s", k);
                    if (v) snprintf(e->attrs[i].value, sizeof e->attrs[i].value, "%s", v);
                }
            }
            break;
        }
        default: return -1;
    }
    return 0;
}

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    json_t *root = fx_to_json(fx);
    if (!root) return -1;
    size_t n = json_dumpb(root, (char *)buf, cap, JSON_COMPACT);
    json_decref(root);
    if (n == 0 || n > cap) return -1;
    *ol = n;
    return 0;
}
static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    json_error_t err;
    json_t *root = json_loadb((const char *)buf, len, 0, &err);
    if (!root) return -1;
    int rc = json_to_fx(root, out, kind);
    json_decref(root);
    return rc;
}
void bench_register_jansson(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "jansson", "2.14", "json", prep, ser, de, fidelity_fx);
}
