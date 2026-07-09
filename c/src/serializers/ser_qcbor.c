#include "ser_common.h"
#include "qcbor/qcbor_encode.h"
#include "qcbor/qcbor_decode.h"
#include "qcbor/qcbor_spiffy_decode.h"

/*
 * Optimal QCBOR usage (laurencelundblade/QCBOR):
 *  - Encode into caller UsefulBuf; structured OpenMap/Add*ToMap
 *  - Decode with spiffy Get*InMapSZ + EnterArrayFromMapSZ
 */

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
        case TD_PERSON: {
            const person_t *p = &fx->person;
            QCBOREncode_AddSZStringToMap(ctx, "FirstName", p->first_name);
            QCBOREncode_AddSZStringToMap(ctx, "LastName", p->last_name);
            QCBOREncode_AddInt64ToMap(ctx, "Age", p->age);
            QCBOREncode_AddInt64ToMap(ctx, "Gender", p->gender);
            QCBOREncode_OpenMapInMap(ctx, "Passport");
            QCBOREncode_AddSZStringToMap(ctx, "Number", p->passport_number);
            QCBOREncode_AddSZStringToMap(ctx, "Authority", p->passport_authority);
            QCBOREncode_CloseMap(ctx);
            int n = p->police_count; if (n < 0) n = 0; if (n > 8) n = 8;
            QCBOREncode_OpenArrayInMap(ctx, "PoliceRecords");
            for (int i = 0; i < n; i++) {
                QCBOREncode_OpenMap(ctx);
                QCBOREncode_AddInt64ToMap(ctx, "Id", p->police_ids[i]);
                QCBOREncode_AddSZStringToMap(ctx, "CrimeCode", p->police_codes[i]);
                QCBOREncode_CloseMap(ctx);
            }
            QCBOREncode_CloseArray(ctx);
            break;
        }
        case TD_TELEMETRY: {
            const telemetry_t *t = &fx->telemetry;
            QCBOREncode_AddSZStringToMap(ctx, "Id", t->id);
            QCBOREncode_AddSZStringToMap(ctx, "DataSource", t->data_source);
            QCBOREncode_AddSZStringToMap(ctx, "TimeStamp", t->time_stamp);
            QCBOREncode_AddInt64ToMap(ctx, "Param1", t->param1);
            QCBOREncode_AddInt64ToMap(ctx, "Param2", t->param2);
            int n = t->meas_count; if (n < 0) n = 0; if (n > 100) n = 100;
            QCBOREncode_OpenArrayInMap(ctx, "Measurements");
            for (int i = 0; i < n; i++) QCBOREncode_AddDouble(ctx, t->measurements[i]);
            QCBOREncode_CloseArray(ctx);
            QCBOREncode_AddInt64ToMap(ctx, "AssociatedProblemID", t->problem_id);
            QCBOREncode_AddInt64ToMap(ctx, "AssociatedLogID", t->log_id);
            QCBOREncode_AddBoolToMap(ctx, "WasProcessed", t->was_processed);
            break;
        }
        case TD_STRING_ARRAY: {
            int n = fx->string_array.count; if (n < 0) n = 0; if (n > 100) n = 100;
            QCBOREncode_AddInt64ToMap(ctx, "Count", n);
            QCBOREncode_OpenArrayInMap(ctx, "Items");
            for (int i = 0; i < n; i++) QCBOREncode_AddSZString(ctx, fx->string_array.items[i]);
            QCBOREncode_CloseArray(ctx);
            break;
        }
        case TD_EDI835: {
            const edi835_t *e = &fx->edi;
            QCBOREncode_AddSZStringToMap(ctx, "PayerName", e->payer_name);
            QCBOREncode_AddSZStringToMap(ctx, "PayeeName", e->payee_name);
            QCBOREncode_AddSZStringToMap(ctx, "PaymentDate", e->payment_date);
            QCBOREncode_AddDoubleToMap(ctx, "TotalActual", e->total_actual);
            QCBOREncode_AddSZStringToMap(ctx, "TCN", e->tcn);
            int nc = e->claim_count; if (nc < 0) nc = 0; if (nc > 6) nc = 6;
            QCBOREncode_OpenArrayInMap(ctx, "Claims");
            for (int c = 0; c < nc; c++) {
                const claim_t *cl = &e->claims[c];
                QCBOREncode_OpenMap(ctx);
                QCBOREncode_AddSZStringToMap(ctx, "ClaimId", cl->claim_id);
                QCBOREncode_AddSZStringToMap(ctx, "PatientName", cl->patient_name);
                QCBOREncode_AddDoubleToMap(ctx, "TotalCharge", cl->total_charge);
                QCBOREncode_AddDoubleToMap(ctx, "Payment", cl->payment);
                int nl = cl->line_count; if (nl < 0) nl = 0; if (nl > 4) nl = 4;
                QCBOREncode_OpenArrayInMap(ctx, "Lines");
                for (int L = 0; L < nl; L++) {
                    QCBOREncode_OpenMap(ctx);
                    QCBOREncode_AddSZStringToMap(ctx, "ServiceCode", cl->lines[L].service_code);
                    QCBOREncode_AddDoubleToMap(ctx, "Charge", cl->lines[L].charge);
                    QCBOREncode_AddDoubleToMap(ctx, "Adjudicated", cl->lines[L].adjudicated);
                    QCBOREncode_CloseMap(ctx);
                }
                QCBOREncode_CloseArray(ctx);
                QCBOREncode_CloseMap(ctx);
            }
            QCBOREncode_CloseArray(ctx);
            break;
        }

        case TD_OBJECT_GRAPH: {
            const object_graph_t *g = &fx->graph;
            QCBOREncode_AddInt64ToMap(ctx, "root", g->root);
            int nn = g->node_count; if (nn < 0) nn = 0; if (nn > GRAPH_MAX_NODES) nn = GRAPH_MAX_NODES;
            QCBOREncode_OpenArrayInMap(ctx, "nodes");
            for (int i = 0; i < nn; i++) {
                const graph_node_t *n = &g->nodes[i];
                int nc = n->child_count; if (nc < 0) nc = 0; if (nc > GRAPH_MAX_CHILDREN) nc = GRAPH_MAX_CHILDREN;
                QCBOREncode_OpenMap(ctx);
                QCBOREncode_AddSZStringToMap(ctx, "Name", n->name);
                QCBOREncode_AddInt64ToMap(ctx, "Parent", n->parent);
                QCBOREncode_AddInt64ToMap(ctx, "Related", n->related);
                QCBOREncode_OpenArrayInMap(ctx, "Children");
                for (int c = 0; c < nc; c++) QCBOREncode_AddInt64(ctx, n->children[c]);
                QCBOREncode_CloseArray(ctx);
                QCBOREncode_CloseMap(ctx);
            }
            QCBOREncode_CloseArray(ctx);
            break;
        }
        default: break;
    }
    QCBOREncode_CloseMap(ctx);
}

static int copy_sz(UsefulBufC s, char *dst, size_t dstsz) {
    if (!s.ptr || s.len >= dstsz) return -1;
    memcpy(dst, s.ptr, s.len);
    dst[s.len] = 0;
    return 0;
}

/* Consume array elements until ExitArray; returns count filled. */
static int dec_police(QCBORDecodeContext *ctx, person_t *p) {
    QCBORDecode_EnterArrayFromMapSZ(ctx, "PoliceRecords");
    int i = 0;
    for (;;) {
        QCBORItem item;
        QCBORError e = QCBORDecode_PeekNext(ctx, &item);
        if (e == QCBOR_ERR_NO_MORE_ITEMS) break;
        if (e != QCBOR_SUCCESS) { QCBORDecode_ExitArray(ctx); return -1; }
        if (i >= 8) { QCBORDecode_GetNext(ctx, &item); continue; }
        QCBORDecode_EnterMap(ctx, NULL);
        int64_t id = 0; UsefulBufC s;
        QCBORDecode_GetInt64InMapSZ(ctx, "Id", &id);
        QCBORDecode_GetTextStringInMapSZ(ctx, "CrimeCode", &s);
        p->police_ids[i] = (int)id;
        copy_sz(s, p->police_codes[i], sizeof p->police_codes[i]);
        QCBORDecode_ExitMap(ctx);
        i++;
    }
    p->police_count = i;
    QCBORDecode_ExitArray(ctx);
    return 0;
}

static int read_fx(QCBORDecodeContext *ctx, test_fixture_t *out, test_data_kind_t kind) {
    QCBORDecode_EnterMap(ctx, NULL);
    int64_t k = -1;
    QCBORDecode_GetInt64InMapSZ(ctx, "kind", &k);
    if (k != (int64_t)kind) return -1;
    memset(out, 0, sizeof *out);
    out->kind = kind;
    out->name = test_data_name(kind);

    switch (kind) {
        case TD_INTEGER: {
            int64_t v = 0;
            QCBORDecode_GetInt64InMapSZ(ctx, "value", &v);
            out->integer_val = (int)v;
            break;
        }
        case TD_SIMPLE: {
            int64_t v = 0; UsefulBufC s; bool b = false;
            QCBORDecode_GetInt64InMapSZ(ctx, "Id", &v); out->simple.id = (int)v;
            QCBORDecode_GetTextStringInMapSZ(ctx, "Name", &s);
            if (copy_sz(s, out->simple.name, sizeof out->simple.name)) return -1;
            QCBORDecode_GetTextStringInMapSZ(ctx, "Timestamp", &s);
            copy_sz(s, out->simple.timestamp, sizeof out->simple.timestamp);
            QCBORDecode_GetBoolInMapSZ(ctx, "IsActive", &b);
            out->simple.is_active = b;
            break;
        }
        case TD_PERSON: {
            UsefulBufC s; int64_t v = 0;
            QCBORDecode_GetTextStringInMapSZ(ctx, "FirstName", &s);
            if (copy_sz(s, out->person.first_name, sizeof out->person.first_name)) return -1;
            QCBORDecode_GetTextStringInMapSZ(ctx, "LastName", &s);
            if (copy_sz(s, out->person.last_name, sizeof out->person.last_name)) return -1;
            QCBORDecode_GetInt64InMapSZ(ctx, "Age", &v); out->person.age = (int)v;
            QCBORDecode_GetInt64InMapSZ(ctx, "Gender", &v); out->person.gender = (int)v;
            QCBORDecode_EnterMapFromMapSZ(ctx, "Passport");
            QCBORDecode_GetTextStringInMapSZ(ctx, "Number", &s);
            copy_sz(s, out->person.passport_number, sizeof out->person.passport_number);
            QCBORDecode_GetTextStringInMapSZ(ctx, "Authority", &s);
            copy_sz(s, out->person.passport_authority, sizeof out->person.passport_authority);
            QCBORDecode_ExitMap(ctx);
            if (dec_police(ctx, &out->person)) return -1;
            break;
        }
        case TD_TELEMETRY: {
            UsefulBufC s; int64_t v = 0; bool b = false;
            QCBORDecode_GetTextStringInMapSZ(ctx, "Id", &s);
            if (copy_sz(s, out->telemetry.id, sizeof out->telemetry.id)) return -1;
            QCBORDecode_GetTextStringInMapSZ(ctx, "DataSource", &s);
            copy_sz(s, out->telemetry.data_source, sizeof out->telemetry.data_source);
            QCBORDecode_GetTextStringInMapSZ(ctx, "TimeStamp", &s);
            copy_sz(s, out->telemetry.time_stamp, sizeof out->telemetry.time_stamp);
            QCBORDecode_GetInt64InMapSZ(ctx, "Param1", &v); out->telemetry.param1 = (int)v;
            QCBORDecode_GetInt64InMapSZ(ctx, "Param2", &v); out->telemetry.param2 = (int)v;
            QCBORDecode_GetInt64InMapSZ(ctx, "AssociatedProblemID", &v); out->telemetry.problem_id = (int)v;
            QCBORDecode_GetInt64InMapSZ(ctx, "AssociatedLogID", &v); out->telemetry.log_id = (int)v;
            QCBORDecode_GetBoolInMapSZ(ctx, "WasProcessed", &b); out->telemetry.was_processed = b;
            QCBORDecode_EnterArrayFromMapSZ(ctx, "Measurements");
            int i = 0;
            for (;;) {
                double d = 0;
                QCBORDecode_GetDouble(ctx, &d);
                QCBORError e = QCBORDecode_GetAndResetError(ctx);
                if (e == QCBOR_ERR_NO_MORE_ITEMS) break;
                if (e != QCBOR_SUCCESS) { QCBORDecode_ExitArray(ctx); return -1; }
                if (i < 100) out->telemetry.measurements[i++] = d;
            }
            out->telemetry.meas_count = i;
            QCBORDecode_ExitArray(ctx);
            break;
        }
        case TD_STRING_ARRAY: {
            QCBORDecode_EnterArrayFromMapSZ(ctx, "Items");
            int i = 0;
            for (;;) {
                UsefulBufC s;
                QCBORDecode_GetTextString(ctx, &s);
                QCBORError e = QCBORDecode_GetAndResetError(ctx);
                if (e == QCBOR_ERR_NO_MORE_ITEMS) break;
                if (e != QCBOR_SUCCESS) { QCBORDecode_ExitArray(ctx); return -1; }
                if (i < 100) { copy_sz(s, out->string_array.items[i], sizeof out->string_array.items[i]); i++; }
            }
            out->string_array.count = i;
            QCBORDecode_ExitArray(ctx);
            break;
        }
        case TD_EDI835: {
            UsefulBufC s; double d = 0;
            QCBORDecode_GetTextStringInMapSZ(ctx, "PayerName", &s);
            if (copy_sz(s, out->edi.payer_name, sizeof out->edi.payer_name)) return -1;
            QCBORDecode_GetTextStringInMapSZ(ctx, "PayeeName", &s);
            copy_sz(s, out->edi.payee_name, sizeof out->edi.payee_name);
            QCBORDecode_GetTextStringInMapSZ(ctx, "PaymentDate", &s);
            copy_sz(s, out->edi.payment_date, sizeof out->edi.payment_date);
            QCBORDecode_GetTextStringInMapSZ(ctx, "TCN", &s);
            copy_sz(s, out->edi.tcn, sizeof out->edi.tcn);
            QCBORDecode_GetDoubleInMapSZ(ctx, "TotalActual", &d);
            out->edi.total_actual = d;
            QCBORDecode_EnterArrayFromMapSZ(ctx, "Claims");
            int c = 0;
            for (;;) {
                QCBORItem item;
                QCBORError e = QCBORDecode_PeekNext(ctx, &item);
                if (e == QCBOR_ERR_NO_MORE_ITEMS) break;
                if (e != QCBOR_SUCCESS) { QCBORDecode_ExitArray(ctx); return -1; }
                if (c >= 6) { QCBORDecode_GetNext(ctx, &item); continue; }
                QCBORDecode_EnterMap(ctx, NULL);
                claim_t *cl = &out->edi.claims[c];
                QCBORDecode_GetTextStringInMapSZ(ctx, "ClaimId", &s);
                copy_sz(s, cl->claim_id, sizeof cl->claim_id);
                QCBORDecode_GetTextStringInMapSZ(ctx, "PatientName", &s);
                copy_sz(s, cl->patient_name, sizeof cl->patient_name);
                QCBORDecode_GetDoubleInMapSZ(ctx, "TotalCharge", &d); cl->total_charge = d;
                QCBORDecode_GetDoubleInMapSZ(ctx, "Payment", &d); cl->payment = d;
                QCBORDecode_EnterArrayFromMapSZ(ctx, "Lines");
                int L = 0;
                for (;;) {
                    QCBORError e2 = QCBORDecode_PeekNext(ctx, &item);
                    if (e2 == QCBOR_ERR_NO_MORE_ITEMS) break;
                    if (e2 != QCBOR_SUCCESS) { QCBORDecode_ExitArray(ctx); return -1; }
                    if (L >= 4) { QCBORDecode_GetNext(ctx, &item); continue; }
                    QCBORDecode_EnterMap(ctx, NULL);
                    QCBORDecode_GetTextStringInMapSZ(ctx, "ServiceCode", &s);
                    copy_sz(s, cl->lines[L].service_code, sizeof cl->lines[L].service_code);
                    QCBORDecode_GetDoubleInMapSZ(ctx, "Charge", &d); cl->lines[L].charge = d;
                    QCBORDecode_GetDoubleInMapSZ(ctx, "Adjudicated", &d); cl->lines[L].adjudicated = d;
                    QCBORDecode_ExitMap(ctx);
                    L++;
                }
                cl->line_count = L;
                QCBORDecode_ExitArray(ctx);
                QCBORDecode_ExitMap(ctx);
                c++;
            }
            out->edi.claim_count = c;
            QCBORDecode_ExitArray(ctx);
            break;
        }

        case TD_OBJECT_GRAPH: {
            int64_t v = 0;
            QCBORDecode_GetInt64InMapSZ(ctx, "root", &v); out->graph.root = (int)v;
            QCBORDecode_EnterArrayFromMapSZ(ctx, "nodes");
            int i = 0;
            for (;;) {
                QCBORItem item;
                QCBORError e = QCBORDecode_PeekNext(ctx, &item);
                if (e == QCBOR_ERR_NO_MORE_ITEMS) break;
                if (e != QCBOR_SUCCESS) { QCBORDecode_ExitArray(ctx); return -1; }
                if (i >= GRAPH_MAX_NODES) { QCBORDecode_GetNext(ctx, &item); continue; }
                QCBORDecode_EnterMap(ctx, NULL);
                graph_node_t *n = &out->graph.nodes[i];
                UsefulBufC s;
                QCBORDecode_GetTextStringInMapSZ(ctx, "Name", &s); copy_sz(s, n->name, sizeof n->name);
                QCBORDecode_GetInt64InMapSZ(ctx, "Parent", &v); n->parent = (int)v;
                QCBORDecode_GetInt64InMapSZ(ctx, "Related", &v); n->related = (int)v;
                QCBORDecode_EnterArrayFromMapSZ(ctx, "Children");
                int c = 0;
                for (;;) {
                    QCBORDecode_GetInt64(ctx, &v);
                    QCBORError e2 = QCBORDecode_GetAndResetError(ctx);
                    if (e2 == QCBOR_ERR_NO_MORE_ITEMS) break;
                    if (e2 != QCBOR_SUCCESS) { QCBORDecode_ExitArray(ctx); return -1; }
                    if (c < GRAPH_MAX_CHILDREN) n->children[c++] = (int)v;
                }
                n->child_count = c;
                QCBORDecode_ExitArray(ctx);
                QCBORDecode_ExitMap(ctx);
                i++;
            }
            out->graph.node_count = i;
            QCBORDecode_ExitArray(ctx);
            break;
        }
        default:
            return -1;
    }
    QCBORDecode_ExitMap(ctx);
    return QCBORDecode_Finish(ctx) == QCBOR_SUCCESS ? 0 : -1;
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
    UsefulBufC ub = {(void *)(uintptr_t)buf, len};
    QCBORDecode_Init(&ctx, ub, QCBOR_DECODE_MODE_NORMAL);
    return read_fx(&ctx, out, kind);
}

void bench_register_qcbor(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "qcbor", "1.5", "binary", prep, ser, de, fidelity_fx);
}
