#include "ser_common.h"
#include "yyjson.h"

/* Native yyjson mut write / immutable read for Data Model v2. */

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static yyjson_mut_doc *fx_to_doc(const test_fixture_t *fx) {
    yyjson_mut_doc *doc = yyjson_mut_doc_new(NULL);
    if (!doc) return NULL;
    yyjson_mut_val *root = yyjson_mut_obj(doc);
    yyjson_mut_doc_set_root(doc, root);
    yyjson_mut_obj_add_str(doc, root, "type", test_data_name(fx->kind));
    switch (fx->kind) {
        case TD_MESSAGE: {
            const message_t *m = &fx->message;
            yyjson_mut_obj_add_bool(doc, root, "f_bool", m->f_bool);
            yyjson_mut_obj_add_int(doc, root, "f_int32", m->f_int32);
            yyjson_mut_obj_add_sint(doc, root, "f_int64", m->f_int64);
            yyjson_mut_obj_add_real(doc, root, "f_float64", m->f_float64);
            yyjson_mut_obj_add_strcpy(doc, root, "f_string", m->f_string);
            yyjson_mut_obj_add_bool(doc, root, "f_bool_2", m->f_bool_2);
            yyjson_mut_obj_add_int(doc, root, "f_int32_2", m->f_int32_2);
            yyjson_mut_obj_add_strcpy(doc, root, "f_string_2", m->f_string_2);
            break;
        }
        case TD_DOCUMENT: {
            const document_t *d = &fx->document;
            yyjson_mut_obj_add_strcpy(doc, root, "id", d->id);
            yyjson_mut_obj_add_int(doc, root, "status", d->status);
            yyjson_mut_val *meta = yyjson_mut_obj(doc);
            yyjson_mut_obj_add_strcpy(doc, meta, "region", d->meta.region);
            yyjson_mut_obj_add_int(doc, meta, "version", d->meta.version);
            yyjson_mut_obj_add_val(doc, root, "meta", meta);
            yyjson_mut_val *items = yyjson_mut_arr(doc);
            for (int i = 0; i < d->item_count; i++) {
                yyjson_mut_val *it = yyjson_mut_obj(doc);
                yyjson_mut_obj_add_strcpy(doc, it, "sku", d->items[i].sku);
                yyjson_mut_obj_add_int(doc, it, "qty", d->items[i].qty);
                yyjson_mut_obj_add_sint(doc, it, "price_minor", d->items[i].price_minor);
                yyjson_mut_arr_add_val(items, it);
            }
            yyjson_mut_obj_add_val(doc, root, "items", items);
            break;
        }
        case TD_TELEMETRY: {
            const telemetry_t *t = &fx->telemetry;
            yyjson_mut_obj_add_strcpy(doc, root, "source", t->source);
            yyjson_mut_obj_add_sint(doc, root, "ts", t->ts);
            yyjson_mut_val *tags = yyjson_mut_arr(doc);
            for (int i = 0; i < t->tag_count; i++) yyjson_mut_arr_add_strcpy(doc, tags, t->tags[i]);
            yyjson_mut_obj_add_val(doc, root, "tags", tags);
            yyjson_mut_val *vals = yyjson_mut_arr(doc);
            for (int i = 0; i < t->value_count; i++) yyjson_mut_arr_add_real(doc, vals, t->values[i]);
            yyjson_mut_obj_add_val(doc, root, "values", vals);
            break;
        }
        case TD_STRINGS: {
            yyjson_mut_val *items = yyjson_mut_arr(doc);
            for (int i = 0; i < fx->strings.count; i++)
                yyjson_mut_arr_add_strcpy(doc, items, fx->strings.items[i]);
            yyjson_mut_obj_add_val(doc, root, "items", items);
            break;
        }
        case TD_EVENT: {
            const event_t *e = &fx->event;
            yyjson_mut_obj_add_strcpy(doc, root, "event_id", e->event_id);
            yyjson_mut_obj_add_strcpy(doc, root, "event_type", e->event_type);
            yyjson_mut_obj_add_sint(doc, root, "occurred_at", e->occurred_at);
            yyjson_mut_obj_add_strcpy(doc, root, "producer", e->producer);
            yyjson_mut_val *attrs = yyjson_mut_arr(doc);
            for (int i = 0; i < e->attr_count; i++) {
                yyjson_mut_val *a = yyjson_mut_obj(doc);
                yyjson_mut_obj_add_strcpy(doc, a, "key", e->attrs[i].key);
                yyjson_mut_obj_add_strcpy(doc, a, "value", e->attrs[i].value);
                yyjson_mut_arr_add_val(attrs, a);
            }
            yyjson_mut_obj_add_val(doc, root, "attrs", attrs);
            break;
        }
        default:
            yyjson_mut_doc_free(doc);
            return NULL;
    }
    return doc;
}

static int doc_to_fx(yyjson_val *root, test_fixture_t *out, test_data_kind_t kind) {
    memset(out, 0, sizeof *out);
    out->kind = kind;
    out->name = test_data_name(kind);
    out->batch_n = 1;
    switch (kind) {
        case TD_MESSAGE: {
            message_t *m = &out->message;
            m->f_bool = yyjson_get_bool(yyjson_obj_get(root, "f_bool"));
            m->f_int32 = (int32_t)yyjson_get_int(yyjson_obj_get(root, "f_int32"));
            m->f_int64 = yyjson_get_sint(yyjson_obj_get(root, "f_int64"));
            m->f_float64 = yyjson_get_real(yyjson_obj_get(root, "f_float64"));
            { const char *s = yyjson_get_str(yyjson_obj_get(root, "f_string")); if (s) snprintf(m->f_string, sizeof m->f_string, "%s", s); }
            m->f_bool_2 = yyjson_get_bool(yyjson_obj_get(root, "f_bool_2"));
            m->f_int32_2 = (int32_t)yyjson_get_int(yyjson_obj_get(root, "f_int32_2"));
            { const char *s = yyjson_get_str(yyjson_obj_get(root, "f_string_2")); if (s) snprintf(m->f_string_2, sizeof m->f_string_2, "%s", s); }
            break;
        }
        case TD_DOCUMENT: {
            document_t *d = &out->document;
            { const char *s = yyjson_get_str(yyjson_obj_get(root, "id")); if (s) snprintf(d->id, sizeof d->id, "%s", s); }
            d->status = (int32_t)yyjson_get_int(yyjson_obj_get(root, "status"));
            yyjson_val *meta = yyjson_obj_get(root, "meta");
            if (meta) {
                const char *r = yyjson_get_str(yyjson_obj_get(meta, "region"));
                if (r) snprintf(d->meta.region, sizeof d->meta.region, "%s", r);
                d->meta.version = (int32_t)yyjson_get_int(yyjson_obj_get(meta, "version"));
            }
            yyjson_val *items = yyjson_obj_get(root, "items");
            if (items && yyjson_is_arr(items)) {
                size_t max = yyjson_arr_size(items);
                if (max > V2_MAX_CHILDREN) max = V2_MAX_CHILDREN;
                d->item_count = (int)max;
                for (size_t idx = 0; idx < max; idx++) {
                    yyjson_val *it = yyjson_arr_get(items, idx);
                    const char *sku = yyjson_get_str(yyjson_obj_get(it, "sku"));
                    if (sku) snprintf(d->items[idx].sku, sizeof d->items[idx].sku, "%s", sku);
                    d->items[idx].qty = (int32_t)yyjson_get_int(yyjson_obj_get(it, "qty"));
                    d->items[idx].price_minor = yyjson_get_sint(yyjson_obj_get(it, "price_minor"));
                }
            }
            break;
        }
        case TD_TELEMETRY: {
            telemetry_t *t = &out->telemetry;
            { const char *s = yyjson_get_str(yyjson_obj_get(root, "source")); if (s) snprintf(t->source, sizeof t->source, "%s", s); }
            t->ts = yyjson_get_sint(yyjson_obj_get(root, "ts"));
            yyjson_val *tags = yyjson_obj_get(root, "tags");
            if (tags && yyjson_is_arr(tags)) {
                size_t idx, max = yyjson_arr_size(tags);
                if (max > V2_MAX_TAGS) max = V2_MAX_TAGS;
                t->tag_count = (int)max;
                for (size_t i = 0; i < max; i++) {
                    const char *s = yyjson_get_str(yyjson_arr_get(tags, i));
                    if (s) snprintf(t->tags[i], sizeof t->tags[i], "%s", s);
                }
            }
            yyjson_val *vals = yyjson_obj_get(root, "values");
            if (vals && yyjson_is_arr(vals)) {
                size_t max = yyjson_arr_size(vals);
                if (max > V2_MAX_POINTS) max = V2_MAX_POINTS;
                t->value_count = (int)max;
                for (size_t i = 0; i < max; i++) t->values[i] = yyjson_get_real(yyjson_arr_get(vals, i));
            }
            break;
        }
        case TD_STRINGS: {
            yyjson_val *items = yyjson_obj_get(root, "items");
            if (items && yyjson_is_arr(items)) {
                size_t max = yyjson_arr_size(items);
                if (max > V2_MAX_STRINGS) max = V2_MAX_STRINGS;
                out->strings.count = (int)max;
                for (size_t i = 0; i < max; i++) {
                    const char *s = yyjson_get_str(yyjson_arr_get(items, i));
                    if (s) snprintf(out->strings.items[i], sizeof out->strings.items[i], "%s", s);
                }
            }
            break;
        }
        case TD_EVENT: {
            event_t *e = &out->event;
            { const char *s = yyjson_get_str(yyjson_obj_get(root, "event_id")); if (s) snprintf(e->event_id, sizeof e->event_id, "%s", s); }
            { const char *s = yyjson_get_str(yyjson_obj_get(root, "event_type")); if (s) snprintf(e->event_type, sizeof e->event_type, "%s", s); }
            e->occurred_at = yyjson_get_sint(yyjson_obj_get(root, "occurred_at"));
            { const char *s = yyjson_get_str(yyjson_obj_get(root, "producer")); if (s) snprintf(e->producer, sizeof e->producer, "%s", s); }
            yyjson_val *attrs = yyjson_obj_get(root, "attrs");
            if (attrs && yyjson_is_arr(attrs)) {
                size_t max = yyjson_arr_size(attrs);
                if (max > V2_MAX_ATTRS) max = V2_MAX_ATTRS;
                e->attr_count = (int)max;
                for (size_t i = 0; i < max; i++) {
                    yyjson_val *a = yyjson_arr_get(attrs, i);
                    const char *k = yyjson_get_str(yyjson_obj_get(a, "key"));
                    const char *v = yyjson_get_str(yyjson_obj_get(a, "value"));
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
    yyjson_mut_doc *doc = fx_to_doc(fx);
    if (!doc) return -1;
    size_t len = 0;
    char *json = yyjson_mut_write(doc, 0, &len);
    yyjson_mut_doc_free(doc);
    if (!json || len + 1 > cap) { free(json); return -1; }
    memcpy(buf, json, len); buf[len] = 0; *ol = len;
    free(json);
    return 0;
}
static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    yyjson_doc *doc = yyjson_read((const char *)buf, len, 0);
    if (!doc) return -1;
    int rc = doc_to_fx(yyjson_doc_get_root(doc), out, kind);
    yyjson_doc_free(doc);
    return rc;
}
void bench_register_yyjson(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "yyjson", "0.10.0", "json", prep, ser, de, fidelity_fx);
}
