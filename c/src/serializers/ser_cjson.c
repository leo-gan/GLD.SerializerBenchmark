#include "ser_common.h"
#include "cJSON.h"
#include <stdlib.h>

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static cJSON *fx_to_json(const test_fixture_t *fx) {
    cJSON *root = cJSON_CreateObject();
    if (!root) return NULL;
    cJSON_AddStringToObject(root, "type", test_data_name(fx->kind));
    switch (fx->kind) {
        case TD_MESSAGE: {
            const message_t *m = &fx->message;
            cJSON_AddBoolToObject(root, "f_bool", m->f_bool);
            cJSON_AddNumberToObject(root, "f_int32", m->f_int32);
            cJSON_AddNumberToObject(root, "f_int64", (double)m->f_int64);
            cJSON_AddNumberToObject(root, "f_float64", m->f_float64);
            cJSON_AddStringToObject(root, "f_string", m->f_string);
            cJSON_AddBoolToObject(root, "f_bool_2", m->f_bool_2);
            cJSON_AddNumberToObject(root, "f_int32_2", m->f_int32_2);
            cJSON_AddStringToObject(root, "f_string_2", m->f_string_2);
            break;
        }
        case TD_DOCUMENT: {
            const document_t *d = &fx->document;
            cJSON_AddStringToObject(root, "id", d->id);
            cJSON_AddNumberToObject(root, "status", d->status);
            cJSON *meta = cJSON_CreateObject();
            cJSON_AddStringToObject(meta, "region", d->meta.region);
            cJSON_AddNumberToObject(meta, "version", d->meta.version);
            cJSON_AddItemToObject(root, "meta", meta);
            cJSON *items = cJSON_CreateArray();
            for (int i = 0; i < d->item_count; i++) {
                cJSON *it = cJSON_CreateObject();
                cJSON_AddStringToObject(it, "sku", d->items[i].sku);
                cJSON_AddNumberToObject(it, "qty", d->items[i].qty);
                cJSON_AddNumberToObject(it, "price_minor", (double)d->items[i].price_minor);
                cJSON_AddItemToArray(items, it);
            }
            cJSON_AddItemToObject(root, "items", items);
            break;
        }
        case TD_TELEMETRY: {
            const telemetry_t *t = &fx->telemetry;
            cJSON_AddStringToObject(root, "source", t->source);
            cJSON_AddNumberToObject(root, "ts", (double)t->ts);
            cJSON *tags = cJSON_CreateArray();
            for (int i = 0; i < t->tag_count; i++) cJSON_AddItemToArray(tags, cJSON_CreateString(t->tags[i]));
            cJSON_AddItemToObject(root, "tags", tags);
            cJSON *vals = cJSON_CreateArray();
            for (int i = 0; i < t->value_count; i++) cJSON_AddItemToArray(vals, cJSON_CreateNumber(t->values[i]));
            cJSON_AddItemToObject(root, "values", vals);
            break;
        }
        case TD_STRINGS: {
            cJSON *items = cJSON_CreateArray();
            for (int i = 0; i < fx->strings.count; i++)
                cJSON_AddItemToArray(items, cJSON_CreateString(fx->strings.items[i]));
            cJSON_AddItemToObject(root, "items", items);
            break;
        }
        case TD_EVENT: {
            const event_t *e = &fx->event;
            cJSON_AddStringToObject(root, "event_id", e->event_id);
            cJSON_AddStringToObject(root, "event_type", e->event_type);
            cJSON_AddNumberToObject(root, "occurred_at", (double)e->occurred_at);
            cJSON_AddStringToObject(root, "producer", e->producer);
            cJSON *attrs = cJSON_CreateArray();
            for (int i = 0; i < e->attr_count; i++) {
                cJSON *a = cJSON_CreateObject();
                cJSON_AddStringToObject(a, "key", e->attrs[i].key);
                cJSON_AddStringToObject(a, "value", e->attrs[i].value);
                cJSON_AddItemToArray(attrs, a);
            }
            cJSON_AddItemToObject(root, "attrs", attrs);
            break;
        }
        default: break;
    }
    return root;
}

static int json_to_fx(cJSON *root, test_fixture_t *out, test_data_kind_t kind) {
    memset(out, 0, sizeof(*out));
    out->kind = kind;
    out->name = test_data_name(kind);
    out->batch_n = 1;
    switch (kind) {
        case TD_MESSAGE: {
            message_t *m = &out->message;
            cJSON *j;
            if ((j = cJSON_GetObjectItem(root, "f_bool"))) m->f_bool = cJSON_IsTrue(j);
            if ((j = cJSON_GetObjectItem(root, "f_int32"))) m->f_int32 = (int32_t)j->valuedouble;
            if ((j = cJSON_GetObjectItem(root, "f_int64"))) m->f_int64 = (int64_t)j->valuedouble;
            if ((j = cJSON_GetObjectItem(root, "f_float64"))) m->f_float64 = j->valuedouble;
            if ((j = cJSON_GetObjectItem(root, "f_string")) && cJSON_IsString(j))
                snprintf(m->f_string, sizeof m->f_string, "%s", j->valuestring);
            if ((j = cJSON_GetObjectItem(root, "f_bool_2"))) m->f_bool_2 = cJSON_IsTrue(j);
            if ((j = cJSON_GetObjectItem(root, "f_int32_2"))) m->f_int32_2 = (int32_t)j->valuedouble;
            if ((j = cJSON_GetObjectItem(root, "f_string_2")) && cJSON_IsString(j))
                snprintf(m->f_string_2, sizeof m->f_string_2, "%s", j->valuestring);
            break;
        }
        case TD_DOCUMENT: {
            document_t *d = &out->document;
            cJSON *j;
            if ((j = cJSON_GetObjectItem(root, "id")) && cJSON_IsString(j))
                snprintf(d->id, sizeof d->id, "%s", j->valuestring);
            if ((j = cJSON_GetObjectItem(root, "status"))) d->status = (int32_t)j->valuedouble;
            cJSON *meta = cJSON_GetObjectItem(root, "meta");
            if (meta) {
                if ((j = cJSON_GetObjectItem(meta, "region")) && cJSON_IsString(j))
                    snprintf(d->meta.region, sizeof d->meta.region, "%s", j->valuestring);
                if ((j = cJSON_GetObjectItem(meta, "version"))) d->meta.version = (int32_t)j->valuedouble;
            }
            cJSON *items = cJSON_GetObjectItem(root, "items");
            if (items && cJSON_IsArray(items)) {
                int n = cJSON_GetArraySize(items);
                if (n > V2_MAX_CHILDREN) n = V2_MAX_CHILDREN;
                d->item_count = n;
                for (int i = 0; i < n; i++) {
                    cJSON *it = cJSON_GetArrayItem(items, i);
                    if ((j = cJSON_GetObjectItem(it, "sku")) && cJSON_IsString(j))
                        snprintf(d->items[i].sku, sizeof d->items[i].sku, "%s", j->valuestring);
                    if ((j = cJSON_GetObjectItem(it, "qty"))) d->items[i].qty = (int32_t)j->valuedouble;
                    if ((j = cJSON_GetObjectItem(it, "price_minor"))) d->items[i].price_minor = (int64_t)j->valuedouble;
                }
            }
            break;
        }
        case TD_TELEMETRY: {
            telemetry_t *t = &out->telemetry;
            cJSON *j;
            if ((j = cJSON_GetObjectItem(root, "source")) && cJSON_IsString(j))
                snprintf(t->source, sizeof t->source, "%s", j->valuestring);
            if ((j = cJSON_GetObjectItem(root, "ts"))) t->ts = (int64_t)j->valuedouble;
            cJSON *tags = cJSON_GetObjectItem(root, "tags");
            if (tags && cJSON_IsArray(tags)) {
                int n = cJSON_GetArraySize(tags); if (n > V2_MAX_TAGS) n = V2_MAX_TAGS;
                t->tag_count = n;
                for (int i = 0; i < n; i++) {
                    cJSON *s = cJSON_GetArrayItem(tags, i);
                    if (cJSON_IsString(s)) snprintf(t->tags[i], sizeof t->tags[i], "%s", s->valuestring);
                }
            }
            cJSON *vals = cJSON_GetObjectItem(root, "values");
            if (vals && cJSON_IsArray(vals)) {
                int n = cJSON_GetArraySize(vals); if (n > V2_MAX_POINTS) n = V2_MAX_POINTS;
                t->value_count = n;
                for (int i = 0; i < n; i++) t->values[i] = cJSON_GetArrayItem(vals, i)->valuedouble;
            }
            break;
        }
        case TD_STRINGS: {
            cJSON *items = cJSON_GetObjectItem(root, "items");
            if (items && cJSON_IsArray(items)) {
                int n = cJSON_GetArraySize(items); if (n > V2_MAX_STRINGS) n = V2_MAX_STRINGS;
                out->strings.count = n;
                for (int i = 0; i < n; i++) {
                    cJSON *s = cJSON_GetArrayItem(items, i);
                    if (cJSON_IsString(s)) snprintf(out->strings.items[i], sizeof out->strings.items[i], "%s", s->valuestring);
                }
            }
            break;
        }
        case TD_EVENT: {
            event_t *e = &out->event;
            cJSON *j;
            if ((j = cJSON_GetObjectItem(root, "event_id")) && cJSON_IsString(j))
                snprintf(e->event_id, sizeof e->event_id, "%s", j->valuestring);
            if ((j = cJSON_GetObjectItem(root, "event_type")) && cJSON_IsString(j))
                snprintf(e->event_type, sizeof e->event_type, "%s", j->valuestring);
            if ((j = cJSON_GetObjectItem(root, "occurred_at"))) e->occurred_at = (int64_t)j->valuedouble;
            if ((j = cJSON_GetObjectItem(root, "producer")) && cJSON_IsString(j))
                snprintf(e->producer, sizeof e->producer, "%s", j->valuestring);
            cJSON *attrs = cJSON_GetObjectItem(root, "attrs");
            if (attrs && cJSON_IsArray(attrs)) {
                int n = cJSON_GetArraySize(attrs); if (n > V2_MAX_ATTRS) n = V2_MAX_ATTRS;
                e->attr_count = n;
                for (int i = 0; i < n; i++) {
                    cJSON *a = cJSON_GetArrayItem(attrs, i);
                    if ((j = cJSON_GetObjectItem(a, "key")) && cJSON_IsString(j))
                        snprintf(e->attrs[i].key, sizeof e->attrs[i].key, "%s", j->valuestring);
                    if ((j = cJSON_GetObjectItem(a, "value")) && cJSON_IsString(j))
                        snprintf(e->attrs[i].value, sizeof e->attrs[i].value, "%s", j->valuestring);
                }
            }
            break;
        }
        default: return -1;
    }
    return 0;
}

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    cJSON *root = fx_to_json(fx);
    if (!root) return -1;
    if (!cJSON_PrintPreallocated(root, (char *)buf, (int)cap, 0)) { cJSON_Delete(root); return -1; }
    *ol = strlen((char *)buf);
    cJSON_Delete(root);
    return 0;
}
static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    cJSON *root = cJSON_ParseWithLength((const char *)buf, len);
    if (!root) return -1;
    int rc = json_to_fx(root, out, kind);
    cJSON_Delete(root);
    return rc;
}
void bench_register_cjson(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "cJSON", "1.7.18", "json", prep, ser, de, fidelity_fx);
}
