#include "ser_common.h"
#include "qcbor/qcbor_encode.h"
#include "qcbor/qcbor_decode.h"
#include "qcbor/qcbor_spiffy_decode.h"

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static void enc_fx(QCBOREncodeContext *ctx, const test_fixture_t *fx) {
    QCBOREncode_OpenMap(ctx);
    QCBOREncode_AddInt64ToMap(ctx, "kind", (int64_t)fx->kind);
    switch (fx->kind) {
        case TD_INTEGER:
            QCBOREncode_AddInt64ToMap(ctx, "value", fx->integer_val);
            break;
        case TD_SIMPLE:
            QCBOREncode_AddInt64ToMap(ctx, "Id", fx->simple.id);
            QCBOREncode_AddSZStringToMap(ctx, "Name", fx->simple.name);
            QCBOREncode_AddSZStringToMap(ctx, "Timestamp", fx->simple.timestamp);
            QCBOREncode_AddBoolToMap(ctx, "IsActive", fx->simple.is_active);
            break;
        case TD_PERSON:
            QCBOREncode_AddSZStringToMap(ctx, "FirstName", fx->person.first_name);
            QCBOREncode_AddSZStringToMap(ctx, "LastName", fx->person.last_name);
            QCBOREncode_AddInt64ToMap(ctx, "Age", fx->person.age);
            QCBOREncode_AddInt64ToMap(ctx, "Gender", fx->person.gender);
            QCBOREncode_AddInt64ToMap(ctx, "PoliceCount", fx->person.police_count);
            break;
        case TD_TELEMETRY:
            QCBOREncode_AddSZStringToMap(ctx, "Id", fx->telemetry.id);
            QCBOREncode_AddInt64ToMap(ctx, "Param1", fx->telemetry.param1);
            QCBOREncode_AddInt64ToMap(ctx, "MeasCount", fx->telemetry.meas_count);
            break;
        case TD_STRING_ARRAY:
            QCBOREncode_AddInt64ToMap(ctx, "Count", fx->string_array.count);
            QCBOREncode_OpenArrayInMap(ctx, "Items");
            for (int i = 0; i < fx->string_array.count && i < 100; i++)
                QCBOREncode_AddSZString(ctx, fx->string_array.items[i]);
            QCBOREncode_CloseArray(ctx);
            break;
        case TD_EDI835:
            QCBOREncode_AddSZStringToMap(ctx, "PayerName", fx->edi.payer_name);
            QCBOREncode_AddSZStringToMap(ctx, "PayeeName", fx->edi.payee_name);
            QCBOREncode_AddInt64ToMap(ctx, "ClaimCount", fx->edi.claim_count);
            QCBOREncode_AddDoubleToMap(ctx, "TotalActual", fx->edi.total_actual);
            break;
        default: break;
    }
    QCBOREncode_CloseMap(ctx);
}

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    QCBOREncodeContext ctx;
    UsefulBuf ub = {buf, cap};
    QCBOREncode_Init(&ctx, ub);
    enc_fx(&ctx, fx);
    UsefulBufC enc;
    if (QCBOREncode_Finish(&ctx, &enc) != QCBOR_SUCCESS) return -1;
    *ol = enc.len;
    return 0;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    QCBORDecodeContext ctx;
    UsefulBufC ub = {buf, len};
    QCBORDecode_Init(&ctx, ub, QCBOR_DECODE_MODE_NORMAL);
    QCBORDecode_EnterMap(&ctx, NULL);
    int64_t k = -1;
    QCBORDecode_GetInt64InMapSZ(&ctx, "kind", &k);
    if (QCBORDecode_GetError(&ctx) || k != (int64_t)kind) return -1;
    memset(out, 0, sizeof *out);
    out->kind = kind;
    out->name = test_data_name(kind);
    switch (kind) {
        case TD_INTEGER: {
            int64_t v = 0;
            QCBORDecode_GetInt64InMapSZ(&ctx, "value", &v);
            out->integer_val = (int)v;
            break;
        }
        case TD_SIMPLE: {
            int64_t id = 0;
            QCBORDecode_GetInt64InMapSZ(&ctx, "Id", &id);
            out->simple.id = (int)id;
            UsefulBufC s;
            QCBORDecode_GetTextStringInMapSZ(&ctx, "Name", &s);
            if (s.ptr) snprintf(out->simple.name, sizeof out->simple.name, "%.*s", (int)s.len, (const char *)s.ptr);
            QCBORDecode_GetTextStringInMapSZ(&ctx, "Timestamp", &s);
            if (s.ptr) snprintf(out->simple.timestamp, sizeof out->simple.timestamp, "%.*s", (int)s.len, (const char *)s.ptr);
            bool b = false;
            QCBORDecode_GetBoolInMapSZ(&ctx, "IsActive", &b);
            out->simple.is_active = b;
            break;
        }
        case TD_PERSON: {
            UsefulBufC s;
            QCBORDecode_GetTextStringInMapSZ(&ctx, "FirstName", &s);
            if (s.ptr) snprintf(out->person.first_name, sizeof out->person.first_name, "%.*s", (int)s.len, (const char *)s.ptr);
            QCBORDecode_GetTextStringInMapSZ(&ctx, "LastName", &s);
            if (s.ptr) snprintf(out->person.last_name, sizeof out->person.last_name, "%.*s", (int)s.len, (const char *)s.ptr);
            int64_t v;
            QCBORDecode_GetInt64InMapSZ(&ctx, "Age", &v); out->person.age = (int)v;
            QCBORDecode_GetInt64InMapSZ(&ctx, "Gender", &v); out->person.gender = (int)v;
            QCBORDecode_GetInt64InMapSZ(&ctx, "PoliceCount", &v); out->person.police_count = (int)v;
            break;
        }
        case TD_TELEMETRY: {
            UsefulBufC s;
            QCBORDecode_GetTextStringInMapSZ(&ctx, "Id", &s);
            if (s.ptr) snprintf(out->telemetry.id, sizeof out->telemetry.id, "%.*s", (int)s.len, (const char *)s.ptr);
            int64_t v;
            QCBORDecode_GetInt64InMapSZ(&ctx, "Param1", &v); out->telemetry.param1 = (int)v;
            QCBORDecode_GetInt64InMapSZ(&ctx, "MeasCount", &v); out->telemetry.meas_count = (int)v;
            break;
        }
        case TD_STRING_ARRAY: {
            int64_t c = 0;
            QCBORDecode_GetInt64InMapSZ(&ctx, "Count", &c);
            out->string_array.count = (int)c;
            QCBORDecode_EnterArrayFromMapSZ(&ctx, "Items");
            for (int i = 0; i < out->string_array.count && i < 100; i++) {
                UsefulBufC s;
                QCBORDecode_GetTextString(&ctx, &s);
                if (s.ptr) snprintf(out->string_array.items[i], sizeof out->string_array.items[i], "%.*s", (int)s.len, (const char *)s.ptr);
            }
            QCBORDecode_ExitArray(&ctx);
            break;
        }
        case TD_EDI835: {
            UsefulBufC s;
            QCBORDecode_GetTextStringInMapSZ(&ctx, "PayerName", &s);
            if (s.ptr) snprintf(out->edi.payer_name, sizeof out->edi.payer_name, "%.*s", (int)s.len, (const char *)s.ptr);
            QCBORDecode_GetTextStringInMapSZ(&ctx, "PayeeName", &s);
            if (s.ptr) snprintf(out->edi.payee_name, sizeof out->edi.payee_name, "%.*s", (int)s.len, (const char *)s.ptr);
            int64_t v;
            QCBORDecode_GetInt64InMapSZ(&ctx, "ClaimCount", &v); out->edi.claim_count = (int)v;
            QCBORDecode_GetDoubleInMapSZ(&ctx, "TotalActual", &out->edi.total_actual);
            break;
        }
        default: return -1;
    }
    QCBORDecode_ExitMap(&ctx);
    QCBORDecode_Finish(&ctx);
    return QCBORDecode_GetError(&ctx) ? -1 : 0;
}

void bench_register_qcbor(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "qcbor", "1.5", "binary", prep, ser, de, fidelity_fx);
}
