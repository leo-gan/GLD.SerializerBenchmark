#include "ser_common.h"
#include "qcbor/qcbor_encode.h"
#include "qcbor/qcbor_decode.h"
#include "qcbor/qcbor_spiffy_decode.h"

/* Native QCBOR encode of V2 field maps; decode via standard CBOR map walker (tinycbor). */

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    UsefulBuf ub = { buf, cap };
    QCBOREncodeContext ctx;
    QCBOREncode_Init(&ctx, ub);
    switch (fx->kind) {
        case TD_MESSAGE: {
            const message_t *m = &fx->message;
            QCBOREncode_OpenMap(&ctx);
            QCBOREncode_AddBoolToMapSZ(&ctx, "f_bool", m->f_bool);
            QCBOREncode_AddInt64ToMapSZ(&ctx, "f_int32", m->f_int32);
            QCBOREncode_AddInt64ToMapSZ(&ctx, "f_int64", m->f_int64);
            QCBOREncode_AddDoubleToMapSZ(&ctx, "f_float64", m->f_float64);
            QCBOREncode_AddSZStringToMapSZ(&ctx, "f_string", m->f_string);
            QCBOREncode_AddBoolToMapSZ(&ctx, "f_bool_2", m->f_bool_2);
            QCBOREncode_AddInt64ToMapSZ(&ctx, "f_int32_2", m->f_int32_2);
            QCBOREncode_AddSZStringToMapSZ(&ctx, "f_string_2", m->f_string_2);
            QCBOREncode_CloseMap(&ctx);
            break;
        }
        case TD_DOCUMENT: {
            const document_t *d = &fx->document;
            QCBOREncode_OpenMap(&ctx);
            QCBOREncode_AddSZStringToMapSZ(&ctx, "id", d->id);
            QCBOREncode_AddInt64ToMapSZ(&ctx, "status", d->status);
            QCBOREncode_OpenMapInMapSZ(&ctx, "meta");
            QCBOREncode_AddSZStringToMapSZ(&ctx, "region", d->meta.region);
            QCBOREncode_AddInt64ToMapSZ(&ctx, "version", d->meta.version);
            QCBOREncode_CloseMap(&ctx);
            QCBOREncode_OpenArrayInMapSZ(&ctx, "items");
            for (int i = 0; i < d->item_count; i++) {
                QCBOREncode_OpenMap(&ctx);
                QCBOREncode_AddSZStringToMapSZ(&ctx, "sku", d->items[i].sku);
                QCBOREncode_AddInt64ToMapSZ(&ctx, "qty", d->items[i].qty);
                QCBOREncode_AddInt64ToMapSZ(&ctx, "price_minor", d->items[i].price_minor);
                QCBOREncode_CloseMap(&ctx);
            }
            QCBOREncode_CloseArray(&ctx);
            QCBOREncode_CloseMap(&ctx);
            break;
        }
        case TD_TELEMETRY: {
            const telemetry_t *t = &fx->telemetry;
            QCBOREncode_OpenMap(&ctx);
            QCBOREncode_AddSZStringToMapSZ(&ctx, "source", t->source);
            QCBOREncode_AddInt64ToMapSZ(&ctx, "ts", t->ts);
            QCBOREncode_OpenArrayInMapSZ(&ctx, "tags");
            for (int i = 0; i < t->tag_count; i++) QCBOREncode_AddSZString(&ctx, t->tags[i]);
            QCBOREncode_CloseArray(&ctx);
            QCBOREncode_OpenArrayInMapSZ(&ctx, "values");
            for (int i = 0; i < t->value_count; i++) QCBOREncode_AddDouble(&ctx, t->values[i]);
            QCBOREncode_CloseArray(&ctx);
            QCBOREncode_CloseMap(&ctx);
            break;
        }
        case TD_STRINGS: {
            QCBOREncode_OpenMap(&ctx);
            QCBOREncode_OpenArrayInMapSZ(&ctx, "items");
            for (int i = 0; i < fx->strings.count; i++) QCBOREncode_AddSZString(&ctx, fx->strings.items[i]);
            QCBOREncode_CloseArray(&ctx);
            QCBOREncode_CloseMap(&ctx);
            break;
        }
        case TD_EVENT: {
            const event_t *e = &fx->event;
            QCBOREncode_OpenMap(&ctx);
            QCBOREncode_AddSZStringToMapSZ(&ctx, "event_id", e->event_id);
            QCBOREncode_AddSZStringToMapSZ(&ctx, "event_type", e->event_type);
            QCBOREncode_AddInt64ToMapSZ(&ctx, "occurred_at", e->occurred_at);
            QCBOREncode_AddSZStringToMapSZ(&ctx, "producer", e->producer);
            QCBOREncode_OpenArrayInMapSZ(&ctx, "attrs");
            for (int i = 0; i < e->attr_count; i++) {
                QCBOREncode_OpenMap(&ctx);
                QCBOREncode_AddSZStringToMapSZ(&ctx, "key", e->attrs[i].key);
                QCBOREncode_AddSZStringToMapSZ(&ctx, "value", e->attrs[i].value);
                QCBOREncode_CloseMap(&ctx);
            }
            QCBOREncode_CloseArray(&ctx);
            QCBOREncode_CloseMap(&ctx);
            break;
        }
        default: return -1;
    }
    UsefulBufC enc;
    if (QCBOREncode_Finish(&ctx, &enc) != QCBOR_SUCCESS) return -1;
    *ol = enc.len;
    return 0;
}
static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    return bench_tinycbor_de(buf, len, out, kind);
}
void bench_register_qcbor(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "qcbor", "1.5.1", "binary", prep, ser, de, fidelity_fx);
}
