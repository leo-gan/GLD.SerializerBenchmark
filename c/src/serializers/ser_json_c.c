#include "ser_common.h"
#include <json-c/json.h>

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static struct json_object *fx_to_obj(const test_fixture_t *fx) {
    struct json_object *root = json_object_new_object();
    json_object_object_add(root, "type", json_object_new_string(test_data_name(fx->kind)));
    switch (fx->kind) {
        case TD_MESSAGE: {
            const message_t *m = &fx->message;
            json_object_object_add(root, "f_bool", json_object_new_boolean(m->f_bool));
            json_object_object_add(root, "f_int32", json_object_new_int(m->f_int32));
            json_object_object_add(root, "f_int64", json_object_new_int64(m->f_int64));
            json_object_object_add(root, "f_float64", json_object_new_double(m->f_float64));
            json_object_object_add(root, "f_string", json_object_new_string(m->f_string));
            json_object_object_add(root, "f_bool_2", json_object_new_boolean(m->f_bool_2));
            json_object_object_add(root, "f_int32_2", json_object_new_int(m->f_int32_2));
            json_object_object_add(root, "f_string_2", json_object_new_string(m->f_string_2));
            break;
        }
        case TD_DOCUMENT: {
            const document_t *d = &fx->document;
            json_object_object_add(root, "id", json_object_new_string(d->id));
            json_object_object_add(root, "status", json_object_new_int(d->status));
            struct json_object *meta = json_object_new_object();
            json_object_object_add(meta, "region", json_object_new_string(d->meta.region));
            json_object_object_add(meta, "version", json_object_new_int(d->meta.version));
            json_object_object_add(root, "meta", meta);
            struct json_object *items = json_object_new_array();
            for (int i = 0; i < d->item_count; i++) {
                struct json_object *it = json_object_new_object();
                json_object_object_add(it, "sku", json_object_new_string(d->items[i].sku));
                json_object_object_add(it, "qty", json_object_new_int(d->items[i].qty));
                json_object_object_add(it, "price_minor", json_object_new_int64(d->items[i].price_minor));
                json_object_array_add(items, it);
            }
            json_object_object_add(root, "items", items);
            break;
        }
        case TD_TELEMETRY: {
            const telemetry_t *t = &fx->telemetry;
            json_object_object_add(root, "source", json_object_new_string(t->source));
            json_object_object_add(root, "ts", json_object_new_int64(t->ts));
            struct json_object *tags = json_object_new_array();
            for (int i = 0; i < t->tag_count; i++) json_object_array_add(tags, json_object_new_string(t->tags[i]));
            json_object_object_add(root, "tags", tags);
            struct json_object *vals = json_object_new_array();
            for (int i = 0; i < t->value_count; i++) json_object_array_add(vals, json_object_new_double(t->values[i]));
            json_object_object_add(root, "values", vals);
            break;
        }
        case TD_STRINGS: {
            struct json_object *items = json_object_new_array();
            for (int i = 0; i < fx->strings.count; i++)
                json_object_array_add(items, json_object_new_string(fx->strings.items[i]));
            json_object_object_add(root, "items", items);
            break;
        }
        case TD_EVENT: {
            const event_t *e = &fx->event;
            json_object_object_add(root, "event_id", json_object_new_string(e->event_id));
            json_object_object_add(root, "event_type", json_object_new_string(e->event_type));
            json_object_object_add(root, "occurred_at", json_object_new_int64(e->occurred_at));
            json_object_object_add(root, "producer", json_object_new_string(e->producer));
            struct json_object *attrs = json_object_new_array();
            for (int i = 0; i < e->attr_count; i++) {
                struct json_object *a = json_object_new_object();
                json_object_object_add(a, "key", json_object_new_string(e->attrs[i].key));
                json_object_object_add(a, "value", json_object_new_string(e->attrs[i].value));
                json_object_array_add(attrs, a);
            }
            json_object_object_add(root, "attrs", attrs);
            break;
        }
        default: json_object_put(root); return NULL;
    }
    return root;
}

static int obj_to_fx(struct json_object *root, test_fixture_t *out, test_data_kind_t kind) {
    memset(out, 0, sizeof *out);
    out->kind = kind; out->name = test_data_name(kind); out->batch_n = 1;
    struct json_object *j;
    switch (kind) {
        case TD_MESSAGE: {
            message_t *m = &out->message;
            if (json_object_object_get_ex(root, "f_bool", &j)) m->f_bool = json_object_get_boolean(j);
            if (json_object_object_get_ex(root, "f_int32", &j)) m->f_int32 = json_object_get_int(j);
            if (json_object_object_get_ex(root, "f_int64", &j)) m->f_int64 = json_object_get_int64(j);
            if (json_object_object_get_ex(root, "f_float64", &j)) m->f_float64 = json_object_get_double(j);
            if (json_object_object_get_ex(root, "f_string", &j)) snprintf(m->f_string, sizeof m->f_string, "%s", json_object_get_string(j));
            if (json_object_object_get_ex(root, "f_bool_2", &j)) m->f_bool_2 = json_object_get_boolean(j);
            if (json_object_object_get_ex(root, "f_int32_2", &j)) m->f_int32_2 = json_object_get_int(j);
            if (json_object_object_get_ex(root, "f_string_2", &j)) snprintf(m->f_string_2, sizeof m->f_string_2, "%s", json_object_get_string(j));
            break;
        }
        case TD_DOCUMENT: {
            document_t *d = &out->document;
            if (json_object_object_get_ex(root, "id", &j)) snprintf(d->id, sizeof d->id, "%s", json_object_get_string(j));
            if (json_object_object_get_ex(root, "status", &j)) d->status = json_object_get_int(j);
            if (json_object_object_get_ex(root, "meta", &j)) {
                struct json_object *r;
                if (json_object_object_get_ex(j, "region", &r)) snprintf(d->meta.region, sizeof d->meta.region, "%s", json_object_get_string(r));
                if (json_object_object_get_ex(j, "version", &r)) d->meta.version = json_object_get_int(r);
            }
            if (json_object_object_get_ex(root, "items", &j) && json_object_is_type(j, json_type_array)) {
                int n = json_object_array_length(j); if (n > V2_MAX_CHILDREN) n = V2_MAX_CHILDREN;
                d->item_count = n;
                for (int i = 0; i < n; i++) {
                    struct json_object *it = json_object_array_get_idx(j, i), *f;
                    if (json_object_object_get_ex(it, "sku", &f)) snprintf(d->items[i].sku, sizeof d->items[i].sku, "%s", json_object_get_string(f));
                    if (json_object_object_get_ex(it, "qty", &f)) d->items[i].qty = json_object_get_int(f);
                    if (json_object_object_get_ex(it, "price_minor", &f)) d->items[i].price_minor = json_object_get_int64(f);
                }
            }
            break;
        }
        case TD_TELEMETRY: {
            telemetry_t *t = &out->telemetry;
            if (json_object_object_get_ex(root, "source", &j)) snprintf(t->source, sizeof t->source, "%s", json_object_get_string(j));
            if (json_object_object_get_ex(root, "ts", &j)) t->ts = json_object_get_int64(j);
            if (json_object_object_get_ex(root, "tags", &j) && json_object_is_type(j, json_type_array)) {
                int n = json_object_array_length(j); if (n > V2_MAX_TAGS) n = V2_MAX_TAGS;
                t->tag_count = n;
                for (int i = 0; i < n; i++) {
                    struct json_object *s = json_object_array_get_idx(j, i);
                    snprintf(t->tags[i], sizeof t->tags[i], "%s", json_object_get_string(s));
                }
            }
            if (json_object_object_get_ex(root, "values", &j) && json_object_is_type(j, json_type_array)) {
                int n = json_object_array_length(j); if (n > V2_MAX_POINTS) n = V2_MAX_POINTS;
                t->value_count = n;
                for (int i = 0; i < n; i++) t->values[i] = json_object_get_double(json_object_array_get_idx(j, i));
            }
            break;
        }
        case TD_STRINGS: {
            if (json_object_object_get_ex(root, "items", &j) && json_object_is_type(j, json_type_array)) {
                int n = json_object_array_length(j); if (n > V2_MAX_STRINGS) n = V2_MAX_STRINGS;
                out->strings.count = n;
                for (int i = 0; i < n; i++)
                    snprintf(out->strings.items[i], sizeof out->strings.items[i], "%s",
                             json_object_get_string(json_object_array_get_idx(j, i)));
            }
            break;
        }
        case TD_EVENT: {
            event_t *e = &out->event;
            if (json_object_object_get_ex(root, "event_id", &j)) snprintf(e->event_id, sizeof e->event_id, "%s", json_object_get_string(j));
            if (json_object_object_get_ex(root, "event_type", &j)) snprintf(e->event_type, sizeof e->event_type, "%s", json_object_get_string(j));
            if (json_object_object_get_ex(root, "occurred_at", &j)) e->occurred_at = json_object_get_int64(j);
            if (json_object_object_get_ex(root, "producer", &j)) snprintf(e->producer, sizeof e->producer, "%s", json_object_get_string(j));
            if (json_object_object_get_ex(root, "attrs", &j) && json_object_is_type(j, json_type_array)) {
                int n = json_object_array_length(j); if (n > V2_MAX_ATTRS) n = V2_MAX_ATTRS;
                e->attr_count = n;
                for (int i = 0; i < n; i++) {
                    struct json_object *a = json_object_array_get_idx(j, i), *f;
                    if (json_object_object_get_ex(a, "key", &f)) snprintf(e->attrs[i].key, sizeof e->attrs[i].key, "%s", json_object_get_string(f));
                    if (json_object_object_get_ex(a, "value", &f)) snprintf(e->attrs[i].value, sizeof e->attrs[i].value, "%s", json_object_get_string(f));
                }
            }
            break;
        }
        default: return -1;
    }
    return 0;
}

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    struct json_object *root = fx_to_obj(fx);
    if (!root) return -1;
    size_t len = 0;
    const char *s = json_object_to_json_string_length(root, JSON_C_TO_STRING_PLAIN, &len);
    if (!s || len + 1 > cap) { json_object_put(root); return -1; }
    memcpy(buf, s, len); *ol = len;
    json_object_put(root);
    return 0;
}
static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    struct json_tokener *tok = json_tokener_new();
    struct json_object *root = json_tokener_parse_ex(tok, (const char *)buf, (int)len);
    json_tokener_free(tok);
    if (!root) return -1;
    int rc = obj_to_fx(root, out, kind);
    json_object_put(root);
    return rc;
}
void bench_register_json_c(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "json-c", "0.16", "json", prep, ser, de, fidelity_fx);
}
