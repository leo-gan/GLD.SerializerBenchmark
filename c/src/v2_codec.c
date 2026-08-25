#include "v2_codec.h"
#include <string.h>

#define W(call) do { if ((call) != 0) return -1; } while (0)

static int w_kv_bool(const v2_writer_t *w, const char *k, int v) {
    W(w->key(w->ctx, k));
    return w->put_bool(w->ctx, v);
}
static int w_kv_i64(const v2_writer_t *w, const char *k, int64_t v) {
    W(w->key(w->ctx, k));
    return w->put_i64(w->ctx, v);
}
static int w_kv_f64(const v2_writer_t *w, const char *k, double v) {
    W(w->key(w->ctx, k));
    return w->put_f64(w->ctx, v);
}
static int w_kv_str(const v2_writer_t *w, const char *k, const char *s) {
    W(w->key(w->ctx, k));
    return w->put_str(w->ctx, s);
}

/* Monomorphic writers (issue #59): timed path uses an indirect call via jump
 * table so kind dispatch is O(1), not a multi-way switch chain. Kind is fixed
 * per cell for the whole timed loop. */

static int v2_write_message(const test_fixture_t *fx, const v2_writer_t *w) {
    const message_t *m = &fx->message;
    W(w->begin_map(w->ctx, 8));
    W(w_kv_bool(w, "f_bool", m->f_bool));
    W(w_kv_i64(w, "f_int32", m->f_int32));
    W(w_kv_i64(w, "f_int64", m->f_int64));
    W(w_kv_f64(w, "f_float64", m->f_float64));
    W(w_kv_str(w, "f_string", m->f_string));
    W(w_kv_bool(w, "f_bool_2", m->f_bool_2));
    W(w_kv_i64(w, "f_int32_2", m->f_int32_2));
    W(w_kv_str(w, "f_string_2", m->f_string_2));
    return w->end_map(w->ctx);
}
static int v2_write_document(const test_fixture_t *fx, const v2_writer_t *w) {
    const document_t *d = &fx->document;
    W(w->begin_map(w->ctx, 4));
    W(w_kv_str(w, "id", d->id));
    W(w_kv_i64(w, "status", d->status));
    W(w->key(w->ctx, "meta"));
    W(w->begin_map(w->ctx, 2));
    W(w_kv_str(w, "region", d->meta.region));
    W(w_kv_i64(w, "version", d->meta.version));
    W(w->end_map(w->ctx));
    W(w->key(w->ctx, "items"));
    W(w->begin_array(w->ctx, d->item_count));
    for (int i = 0; i < d->item_count; i++) {
        W(w->begin_map(w->ctx, 3));
        W(w_kv_str(w, "sku", d->items[i].sku));
        W(w_kv_i64(w, "qty", d->items[i].qty));
        W(w_kv_i64(w, "price_minor", d->items[i].price_minor));
        W(w->end_map(w->ctx));
    }
    W(w->end_array(w->ctx));
    return w->end_map(w->ctx);
}
static int v2_write_telemetry(const test_fixture_t *fx, const v2_writer_t *w) {
    const telemetry_t *t = &fx->telemetry;
    W(w->begin_map(w->ctx, 4));
    W(w_kv_str(w, "source", t->source));
    W(w_kv_i64(w, "ts", t->ts));
    W(w->key(w->ctx, "tags"));
    W(w->begin_array(w->ctx, t->tag_count));
    for (int i = 0; i < t->tag_count; i++) W(w->put_str(w->ctx, t->tags[i]));
    W(w->end_array(w->ctx));
    W(w->key(w->ctx, "values"));
    W(w->begin_array(w->ctx, t->value_count));
    for (int i = 0; i < t->value_count; i++) W(w->put_f64(w->ctx, t->values[i]));
    W(w->end_array(w->ctx));
    return w->end_map(w->ctx);
}
static int v2_write_strings(const test_fixture_t *fx, const v2_writer_t *w) {
    W(w->begin_map(w->ctx, 1));
    W(w->key(w->ctx, "items"));
    W(w->begin_array(w->ctx, fx->strings.count));
    for (int i = 0; i < fx->strings.count; i++) W(w->put_str(w->ctx, fx->strings.items[i]));
    W(w->end_array(w->ctx));
    return w->end_map(w->ctx);
}
static int v2_write_event(const test_fixture_t *fx, const v2_writer_t *w) {
    const event_t *e = &fx->event;
    W(w->begin_map(w->ctx, 5));
    W(w_kv_str(w, "event_id", e->event_id));
    W(w_kv_str(w, "event_type", e->event_type));
    W(w_kv_i64(w, "occurred_at", e->occurred_at));
    W(w_kv_str(w, "producer", e->producer));
    W(w->key(w->ctx, "attrs"));
    W(w->begin_array(w->ctx, e->attr_count));
    for (int i = 0; i < e->attr_count; i++) {
        W(w->begin_map(w->ctx, 2));
        W(w_kv_str(w, "key", e->attrs[i].key));
        W(w_kv_str(w, "value", e->attrs[i].value));
        W(w->end_map(w->ctx));
    }
    W(w->end_array(w->ctx));
    return w->end_map(w->ctx);
}

typedef int (*v2_write_fn)(const test_fixture_t *, const v2_writer_t *);

static v2_write_fn v2_writer_table[TD_COUNT] = {
    v2_write_message,
    v2_write_document,
    v2_write_telemetry,
    v2_write_strings,
    v2_write_event,
};

int v2_write_fixture(const test_fixture_t *fx, const v2_writer_t *w) {
    if (!fx || !w) return -1;
    if ((unsigned)fx->kind >= (unsigned)TD_COUNT) return -1;
    return v2_writer_table[fx->kind](fx, w);
}

#define R(call) do { if ((call) != 0) return -1; } while (0)

int v2_read_fixture(test_data_kind_t kind, test_fixture_t *out, const v2_reader_t *r) {
    if (!out || !r) return -1;
    memset(out, 0, sizeof(*out));
    out->kind = kind;
    out->name = test_data_name(kind);
    out->batch_n = 1;

    switch (kind) {
        case TD_MESSAGE: {
            message_t *m = &out->message;
            int b = 0;
            int64_t i = 0;
            double d = 0;
            if (r->get_bool(r->ctx, "f_bool", &b) == 0) m->f_bool = b;
            if (r->get_i64(r->ctx, "f_int32", &i) == 0) m->f_int32 = (int32_t)i;
            if (r->get_i64(r->ctx, "f_int64", &i) == 0) m->f_int64 = i;
            if (r->get_f64(r->ctx, "f_float64", &d) == 0) m->f_float64 = d;
            R(r->get_str(r->ctx, "f_string", m->f_string, sizeof m->f_string));
            if (r->get_bool(r->ctx, "f_bool_2", &b) == 0) m->f_bool_2 = b;
            if (r->get_i64(r->ctx, "f_int32_2", &i) == 0) m->f_int32_2 = (int32_t)i;
            R(r->get_str(r->ctx, "f_string_2", m->f_string_2, sizeof m->f_string_2));
            return 0;
        }
        case TD_DOCUMENT: {
            document_t *d = &out->document;
            int64_t i = 0;
            R(r->get_str(r->ctx, "id", d->id, sizeof d->id));
            if (r->get_i64(r->ctx, "status", &i) == 0) d->status = (int32_t)i;
            if (r->enter_object(r->ctx, "meta") == 0) {
                R(r->get_str(r->ctx, "region", d->meta.region, sizeof d->meta.region));
                if (r->get_i64(r->ctx, "version", &i) == 0) d->meta.version = (int32_t)i;
                R(r->leave_object(r->ctx));
            }
            int n = 0;
            if (r->enter_array(r->ctx, "items", &n) == 0) {
                if (n > V2_MAX_CHILDREN) n = V2_MAX_CHILDREN;
                d->item_count = n;
                for (int j = 0; j < n; j++) {
                    R(r->enter_elem(r->ctx, j));
                    R(r->get_str(r->ctx, "sku", d->items[j].sku, sizeof d->items[j].sku));
                    if (r->get_i64(r->ctx, "qty", &i) == 0) d->items[j].qty = (int32_t)i;
                    if (r->get_i64(r->ctx, "price_minor", &i) == 0) d->items[j].price_minor = i;
                    R(r->leave_elem(r->ctx));
                }
                R(r->leave_array(r->ctx));
            }
            return 0;
        }
        case TD_TELEMETRY: {
            telemetry_t *t = &out->telemetry;
            int64_t i = 0;
            double d = 0;
            R(r->get_str(r->ctx, "source", t->source, sizeof t->source));
            if (r->get_i64(r->ctx, "ts", &i) == 0) t->ts = i;
            int n = 0;
            if (r->enter_array(r->ctx, "tags", &n) == 0) {
                if (n > V2_MAX_TAGS) n = V2_MAX_TAGS;
                t->tag_count = n;
                for (int j = 0; j < n; j++) {
                    R(r->enter_elem(r->ctx, j));
                    /* element is a bare string: use get_str with empty key convention? */
                    /* Readers must support get_str(ctx, "", buf) for bare array string elems */
                    R(r->get_str(r->ctx, "", t->tags[j], sizeof t->tags[j]));
                    R(r->leave_elem(r->ctx));
                }
                R(r->leave_array(r->ctx));
            }
            if (r->enter_array(r->ctx, "values", &n) == 0) {
                if (n > V2_MAX_POINTS) n = V2_MAX_POINTS;
                t->value_count = n;
                for (int j = 0; j < n; j++) {
                    R(r->enter_elem(r->ctx, j));
                    if (r->get_f64(r->ctx, "", &d) == 0) t->values[j] = d;
                    R(r->leave_elem(r->ctx));
                }
                R(r->leave_array(r->ctx));
            }
            return 0;
        }
        case TD_STRINGS: {
            int n = 0;
            if (r->enter_array(r->ctx, "items", &n) == 0) {
                if (n > V2_MAX_STRINGS) n = V2_MAX_STRINGS;
                out->strings.count = n;
                for (int j = 0; j < n; j++) {
                    R(r->enter_elem(r->ctx, j));
                    R(r->get_str(r->ctx, "", out->strings.items[j], sizeof out->strings.items[j]));
                    R(r->leave_elem(r->ctx));
                }
                R(r->leave_array(r->ctx));
            }
            return 0;
        }
        case TD_EVENT: {
            event_t *e = &out->event;
            int64_t i = 0;
            R(r->get_str(r->ctx, "event_id", e->event_id, sizeof e->event_id));
            R(r->get_str(r->ctx, "event_type", e->event_type, sizeof e->event_type));
            if (r->get_i64(r->ctx, "occurred_at", &i) == 0) e->occurred_at = i;
            R(r->get_str(r->ctx, "producer", e->producer, sizeof e->producer));
            int n = 0;
            if (r->enter_array(r->ctx, "attrs", &n) == 0) {
                if (n > V2_MAX_ATTRS) n = V2_MAX_ATTRS;
                e->attr_count = n;
                for (int j = 0; j < n; j++) {
                    R(r->enter_elem(r->ctx, j));
                    R(r->get_str(r->ctx, "key", e->attrs[j].key, sizeof e->attrs[j].key));
                    R(r->get_str(r->ctx, "value", e->attrs[j].value, sizeof e->attrs[j].value));
                    R(r->leave_elem(r->ctx));
                }
                R(r->leave_array(r->ctx));
            }
            return 0;
        }
        default:
            return -1;
    }
}
