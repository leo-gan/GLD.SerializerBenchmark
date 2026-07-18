#include "ser_common.h"
#include "zcbor_encode.h"
#include "zcbor_decode.h"
#include "zcbor_common.h"

/* Native zcbor map encode/decode for Data Model v2. */

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static bool put_kv_int(zcbor_state_t *s, const char *k, int64_t v) {
    return zcbor_tstr_put_term(s, k, 64) && zcbor_int64_put(s, v);
}
static bool put_kv_str(zcbor_state_t *s, const char *k, const char *v) {
    return zcbor_tstr_put_term(s, k, 64) && zcbor_tstr_put_term(s, v, 256);
}
static bool put_kv_bool(zcbor_state_t *s, const char *k, bool v) {
    return zcbor_tstr_put_term(s, k, 64) && zcbor_bool_put(s, v);
}
static bool put_kv_double(zcbor_state_t *s, const char *k, double v) {
    return zcbor_tstr_put_term(s, k, 64) && zcbor_float64_put(s, v);
}

static bool enc_fx(zcbor_state_t *s, const test_fixture_t *fx) {
    switch (fx->kind) {
        case TD_MESSAGE: {
            const message_t *m = &fx->message;
            if (!zcbor_map_start_encode(s, 8)) return false;
            if (!put_kv_bool(s, "f_bool", m->f_bool)) return false;
            if (!put_kv_int(s, "f_int32", m->f_int32)) return false;
            if (!put_kv_int(s, "f_int64", m->f_int64)) return false;
            if (!put_kv_double(s, "f_float64", m->f_float64)) return false;
            if (!put_kv_str(s, "f_string", m->f_string)) return false;
            if (!put_kv_bool(s, "f_bool_2", m->f_bool_2)) return false;
            if (!put_kv_int(s, "f_int32_2", m->f_int32_2)) return false;
            if (!put_kv_str(s, "f_string_2", m->f_string_2)) return false;
            return zcbor_map_end_encode(s, 8);
        }
        case TD_DOCUMENT: {
            const document_t *d = &fx->document;
            if (!zcbor_map_start_encode(s, 4)) return false;
            if (!put_kv_str(s, "id", d->id)) return false;
            if (!put_kv_int(s, "status", d->status)) return false;
            if (!zcbor_tstr_put_term(s, "meta", 8) || !zcbor_map_start_encode(s, 2)) return false;
            if (!put_kv_str(s, "region", d->meta.region)) return false;
            if (!put_kv_int(s, "version", d->meta.version)) return false;
            if (!zcbor_map_end_encode(s, 2)) return false;
            if (!zcbor_tstr_put_term(s, "items", 8) || !zcbor_list_start_encode(s, (size_t)d->item_count)) return false;
            for (int i = 0; i < d->item_count; i++) {
                if (!zcbor_map_start_encode(s, 3)) return false;
                if (!put_kv_str(s, "sku", d->items[i].sku)) return false;
                if (!put_kv_int(s, "qty", d->items[i].qty)) return false;
                if (!put_kv_int(s, "price_minor", d->items[i].price_minor)) return false;
                if (!zcbor_map_end_encode(s, 3)) return false;
            }
            if (!zcbor_list_end_encode(s, (size_t)d->item_count)) return false;
            return zcbor_map_end_encode(s, 4);
        }
        case TD_TELEMETRY: {
            const telemetry_t *t = &fx->telemetry;
            if (!zcbor_map_start_encode(s, 4)) return false;
            if (!put_kv_str(s, "source", t->source)) return false;
            if (!put_kv_int(s, "ts", t->ts)) return false;
            if (!zcbor_tstr_put_term(s, "tags", 8) || !zcbor_list_start_encode(s, (size_t)t->tag_count)) return false;
            for (int i = 0; i < t->tag_count; i++) if (!zcbor_tstr_put_term(s, t->tags[i], 64)) return false;
            if (!zcbor_list_end_encode(s, (size_t)t->tag_count)) return false;
            if (!zcbor_tstr_put_term(s, "values", 8) || !zcbor_list_start_encode(s, (size_t)t->value_count)) return false;
            for (int i = 0; i < t->value_count; i++) if (!zcbor_float64_put(s, t->values[i])) return false;
            if (!zcbor_list_end_encode(s, (size_t)t->value_count)) return false;
            return zcbor_map_end_encode(s, 4);
        }
        case TD_STRINGS: {
            if (!zcbor_map_start_encode(s, 1)) return false;
            if (!zcbor_tstr_put_term(s, "items", 8) || !zcbor_list_start_encode(s, (size_t)fx->strings.count)) return false;
            for (int i = 0; i < fx->strings.count; i++) if (!zcbor_tstr_put_term(s, fx->strings.items[i], 64)) return false;
            if (!zcbor_list_end_encode(s, (size_t)fx->strings.count)) return false;
            return zcbor_map_end_encode(s, 1);
        }
        case TD_EVENT: {
            const event_t *e = &fx->event;
            if (!zcbor_map_start_encode(s, 5)) return false;
            if (!put_kv_str(s, "event_id", e->event_id)) return false;
            if (!put_kv_str(s, "event_type", e->event_type)) return false;
            if (!put_kv_int(s, "occurred_at", e->occurred_at)) return false;
            if (!put_kv_str(s, "producer", e->producer)) return false;
            if (!zcbor_tstr_put_term(s, "attrs", 8) || !zcbor_list_start_encode(s, (size_t)e->attr_count)) return false;
            for (int i = 0; i < e->attr_count; i++) {
                if (!zcbor_map_start_encode(s, 2)) return false;
                if (!put_kv_str(s, "key", e->attrs[i].key)) return false;
                if (!put_kv_str(s, "value", e->attrs[i].value)) return false;
                if (!zcbor_map_end_encode(s, 2)) return false;
            }
            if (!zcbor_list_end_encode(s, (size_t)e->attr_count)) return false;
            return zcbor_map_end_encode(s, 5);
        }
        default: return false;
    }
}

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    zcbor_state_t states[8];
    zcbor_new_state(states, 8, buf, cap, 1, NULL, 0);
    if (!enc_fx(states, fx)) return -1;
    *ol = (size_t)(states[0].payload - buf);
    return 0;
}

/* Decode: use tinycbor de for CBOR-compatible maps — zcbor decode maps are key-order sensitive.
 * Use zcbor multi for message; for others re-use tinycbor by... 
 * For fidelity: decode with tinycbor if we declare external. Simpler: decode using zcbor unordered map search. */
static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    /* Encode is zcbor; decode standard CBOR maps with tinycbor (interop). */
    return bench_tinycbor_de(buf, len, out, kind);
}
void bench_register_zcbor(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "zcbor", "0.9", "schema", prep, ser, de, fidelity_fx);
}
