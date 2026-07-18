#include "ser_common.h"
#include "parson_pref.h"

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static JSON_Value *fx_to_val(const test_fixture_t *fx) {
    JSON_Value *root_v = json_value_init_object();
    JSON_Object *root = json_value_get_object(root_v);
    json_object_set_string(root, "type", test_data_name(fx->kind));
    switch (fx->kind) {
        case TD_MESSAGE: {
            const message_t *m = &fx->message;
            json_object_set_boolean(root, "f_bool", m->f_bool);
            json_object_set_number(root, "f_int32", m->f_int32);
            json_object_set_number(root, "f_int64", (double)m->f_int64);
            json_object_set_number(root, "f_float64", m->f_float64);
            json_object_set_string(root, "f_string", m->f_string);
            json_object_set_boolean(root, "f_bool_2", m->f_bool_2);
            json_object_set_number(root, "f_int32_2", m->f_int32_2);
            json_object_set_string(root, "f_string_2", m->f_string_2);
            break;
        }
        case TD_DOCUMENT: {
            const document_t *d = &fx->document;
            json_object_set_string(root, "id", d->id);
            json_object_set_number(root, "status", d->status);
            JSON_Value *meta_v = json_value_init_object();
            JSON_Object *meta = json_value_get_object(meta_v);
            json_object_set_string(meta, "region", d->meta.region);
            json_object_set_number(meta, "version", d->meta.version);
            json_object_set_value(root, "meta", meta_v);
            JSON_Value *items_v = json_value_init_array();
            JSON_Array *items = json_value_get_array(items_v);
            for (int i = 0; i < d->item_count; i++) {
                JSON_Value *it_v = json_value_init_object();
                JSON_Object *it = json_value_get_object(it_v);
                json_object_set_string(it, "sku", d->items[i].sku);
                json_object_set_number(it, "qty", d->items[i].qty);
                json_object_set_number(it, "price_minor", (double)d->items[i].price_minor);
                json_array_append_value(items, it_v);
            }
            json_object_set_value(root, "items", items_v);
            break;
        }
        case TD_TELEMETRY: {
            const telemetry_t *t = &fx->telemetry;
            json_object_set_string(root, "source", t->source);
            json_object_set_number(root, "ts", (double)t->ts);
            JSON_Value *tags_v = json_value_init_array();
            JSON_Array *tags = json_value_get_array(tags_v);
            for (int i = 0; i < t->tag_count; i++) json_array_append_string(tags, t->tags[i]);
            json_object_set_value(root, "tags", tags_v);
            JSON_Value *vals_v = json_value_init_array();
            JSON_Array *vals = json_value_get_array(vals_v);
            for (int i = 0; i < t->value_count; i++) json_array_append_number(vals, t->values[i]);
            json_object_set_value(root, "values", vals_v);
            break;
        }
        case TD_STRINGS: {
            JSON_Value *items_v = json_value_init_array();
            JSON_Array *items = json_value_get_array(items_v);
            for (int i = 0; i < fx->strings.count; i++) json_array_append_string(items, fx->strings.items[i]);
            json_object_set_value(root, "items", items_v);
            break;
        }
        case TD_EVENT: {
            const event_t *e = &fx->event;
            json_object_set_string(root, "event_id", e->event_id);
            json_object_set_string(root, "event_type", e->event_type);
            json_object_set_number(root, "occurred_at", (double)e->occurred_at);
            json_object_set_string(root, "producer", e->producer);
            JSON_Value *attrs_v = json_value_init_array();
            JSON_Array *attrs = json_value_get_array(attrs_v);
            for (int i = 0; i < e->attr_count; i++) {
                JSON_Value *a_v = json_value_init_object();
                JSON_Object *a = json_value_get_object(a_v);
                json_object_set_string(a, "key", e->attrs[i].key);
                json_object_set_string(a, "value", e->attrs[i].value);
                json_array_append_value(attrs, a_v);
            }
            json_object_set_value(root, "attrs", attrs_v);
            break;
        }
        default: json_value_free(root_v); return NULL;
    }
    return root_v;
}

static int val_to_fx(JSON_Value *root_v, test_fixture_t *out, test_data_kind_t kind) {
    memset(out, 0, sizeof *out);
    out->kind = kind; out->name = test_data_name(kind); out->batch_n = 1;
    JSON_Object *root = json_value_get_object(root_v);
    if (!root) return -1;
    switch (kind) {
        case TD_MESSAGE: {
            message_t *m = &out->message;
            m->f_bool = json_object_get_boolean(root, "f_bool") == 1;
            m->f_int32 = (int32_t)json_object_get_number(root, "f_int32");
            m->f_int64 = (int64_t)json_object_get_number(root, "f_int64");
            m->f_float64 = json_object_get_number(root, "f_float64");
            { const char *s = json_object_get_string(root, "f_string"); if (s) snprintf(m->f_string, sizeof m->f_string, "%s", s); }
            m->f_bool_2 = json_object_get_boolean(root, "f_bool_2") == 1;
            m->f_int32_2 = (int32_t)json_object_get_number(root, "f_int32_2");
            { const char *s = json_object_get_string(root, "f_string_2"); if (s) snprintf(m->f_string_2, sizeof m->f_string_2, "%s", s); }
            break;
        }
        case TD_DOCUMENT: {
            document_t *d = &out->document;
            { const char *s = json_object_get_string(root, "id"); if (s) snprintf(d->id, sizeof d->id, "%s", s); }
            d->status = (int32_t)json_object_get_number(root, "status");
            JSON_Object *meta = json_object_get_object(root, "meta");
            if (meta) {
                const char *r = json_object_get_string(meta, "region");
                if (r) snprintf(d->meta.region, sizeof d->meta.region, "%s", r);
                d->meta.version = (int32_t)json_object_get_number(meta, "version");
            }
            JSON_Array *items = json_object_get_array(root, "items");
            if (items) {
                size_t n = json_array_get_count(items); if (n > V2_MAX_CHILDREN) n = V2_MAX_CHILDREN;
                d->item_count = (int)n;
                for (size_t i = 0; i < n; i++) {
                    JSON_Object *it = json_array_get_object(items, i);
                    const char *sku = json_object_get_string(it, "sku");
                    if (sku) snprintf(d->items[i].sku, sizeof d->items[i].sku, "%s", sku);
                    d->items[i].qty = (int32_t)json_object_get_number(it, "qty");
                    d->items[i].price_minor = (int64_t)json_object_get_number(it, "price_minor");
                }
            }
            break;
        }
        case TD_TELEMETRY: {
            telemetry_t *t = &out->telemetry;
            { const char *s = json_object_get_string(root, "source"); if (s) snprintf(t->source, sizeof t->source, "%s", s); }
            t->ts = (int64_t)json_object_get_number(root, "ts");
            JSON_Array *tags = json_object_get_array(root, "tags");
            if (tags) {
                size_t n = json_array_get_count(tags); if (n > V2_MAX_TAGS) n = V2_MAX_TAGS;
                t->tag_count = (int)n;
                for (size_t i = 0; i < n; i++) {
                    const char *s = json_array_get_string(tags, i);
                    if (s) snprintf(t->tags[i], sizeof t->tags[i], "%s", s);
                }
            }
            JSON_Array *vals = json_object_get_array(root, "values");
            if (vals) {
                size_t n = json_array_get_count(vals); if (n > V2_MAX_POINTS) n = V2_MAX_POINTS;
                t->value_count = (int)n;
                for (size_t i = 0; i < n; i++) t->values[i] = json_array_get_number(vals, i);
            }
            break;
        }
        case TD_STRINGS: {
            JSON_Array *items = json_object_get_array(root, "items");
            if (items) {
                size_t n = json_array_get_count(items); if (n > V2_MAX_STRINGS) n = V2_MAX_STRINGS;
                out->strings.count = (int)n;
                for (size_t i = 0; i < n; i++) {
                    const char *s = json_array_get_string(items, i);
                    if (s) snprintf(out->strings.items[i], sizeof out->strings.items[i], "%s", s);
                }
            }
            break;
        }
        case TD_EVENT: {
            event_t *e = &out->event;
            { const char *s = json_object_get_string(root, "event_id"); if (s) snprintf(e->event_id, sizeof e->event_id, "%s", s); }
            { const char *s = json_object_get_string(root, "event_type"); if (s) snprintf(e->event_type, sizeof e->event_type, "%s", s); }
            e->occurred_at = (int64_t)json_object_get_number(root, "occurred_at");
            { const char *s = json_object_get_string(root, "producer"); if (s) snprintf(e->producer, sizeof e->producer, "%s", s); }
            JSON_Array *attrs = json_object_get_array(root, "attrs");
            if (attrs) {
                size_t n = json_array_get_count(attrs); if (n > V2_MAX_ATTRS) n = V2_MAX_ATTRS;
                e->attr_count = (int)n;
                for (size_t i = 0; i < n; i++) {
                    JSON_Object *a = json_array_get_object(attrs, i);
                    const char *k = json_object_get_string(a, "key");
                    const char *v = json_object_get_string(a, "value");
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
    JSON_Value *v = fx_to_val(fx);
    if (!v) return -1;
    char *s = json_serialize_to_string(v);
    json_value_free(v);
    if (!s) return -1;
    size_t n = strlen(s);
    if (n + 1 > cap) { json_free_serialized_string(s); return -1; }
    memcpy(buf, s, n); *ol = n;
    json_free_serialized_string(s);
    return 0;
}
static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    /* parson needs NUL-terminated; copy if needed */
    char *tmp = (char *)malloc(len + 1);
    if (!tmp) return -1;
    memcpy(tmp, buf, len); tmp[len] = 0;
    JSON_Value *v = json_parse_string(tmp);
    free(tmp);
    if (!v) return -1;
    int rc = val_to_fx(v, out, kind);
    json_value_free(v);
    return rc;
}
void bench_register_parson(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "parson", "1.5.3", "json", prep, ser, de, fidelity_fx);
}
