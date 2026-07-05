#include "ser_common.h"
#include "zcbor_encode.h"
#include "zcbor_decode.h"
#include "zcbor_common.h"

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    ZCBOR_STATE_E(state, 4, buf, cap, 0);
    bool ok = zcbor_map_start_encode(state, 8);
    ok = ok && zcbor_tstr_put_lit(state, "kind") && zcbor_int32_put(state, (int32_t)fx->kind);
    switch (fx->kind) {
        case TD_INTEGER:
            ok = ok && zcbor_tstr_put_lit(state, "value") && zcbor_int32_put(state, fx->integer_val);
            break;
        case TD_SIMPLE:
            ok = ok && zcbor_tstr_put_lit(state, "Id") && zcbor_int32_put(state, fx->simple.id);
            ok = ok && zcbor_tstr_put_lit(state, "Name") && zcbor_tstr_put_term(state, fx->simple.name, 32);
            ok = ok && zcbor_tstr_put_lit(state, "Timestamp") && zcbor_tstr_put_term(state, fx->simple.timestamp, 32);
            ok = ok && zcbor_tstr_put_lit(state, "IsActive") && zcbor_bool_put(state, fx->simple.is_active);
            break;
        case TD_PERSON:
            ok = ok && zcbor_tstr_put_lit(state, "FirstName") && zcbor_tstr_put_term(state, fx->person.first_name, 32);
            ok = ok && zcbor_tstr_put_lit(state, "LastName") && zcbor_tstr_put_term(state, fx->person.last_name, 32);
            ok = ok && zcbor_tstr_put_lit(state, "Age") && zcbor_int32_put(state, fx->person.age);
            ok = ok && zcbor_tstr_put_lit(state, "Gender") && zcbor_int32_put(state, fx->person.gender);
            ok = ok && zcbor_tstr_put_lit(state, "PoliceCount") && zcbor_int32_put(state, fx->person.police_count);
            break;
        case TD_TELEMETRY:
            ok = ok && zcbor_tstr_put_lit(state, "Id") && zcbor_tstr_put_term(state, fx->telemetry.id, 24);
            ok = ok && zcbor_tstr_put_lit(state, "Param1") && zcbor_int32_put(state, fx->telemetry.param1);
            ok = ok && zcbor_tstr_put_lit(state, "MeasCount") && zcbor_int32_put(state, fx->telemetry.meas_count);
            break;
        case TD_STRING_ARRAY:
            ok = ok && zcbor_tstr_put_lit(state, "Count") && zcbor_int32_put(state, fx->string_array.count);
            ok = ok && zcbor_tstr_put_lit(state, "Items") && zcbor_list_start_encode(state, (uint32_t)fx->string_array.count);
            for (int i = 0; i < fx->string_array.count && i < 100; i++)
                ok = ok && zcbor_tstr_put_term(state, fx->string_array.items[i], 16);
            ok = ok && zcbor_list_end_encode(state, (uint32_t)fx->string_array.count);
            break;
        case TD_EDI835:
            ok = ok && zcbor_tstr_put_lit(state, "PayerName") && zcbor_tstr_put_term(state, fx->edi.payer_name, 32);
            ok = ok && zcbor_tstr_put_lit(state, "PayeeName") && zcbor_tstr_put_term(state, fx->edi.payee_name, 32);
            ok = ok && zcbor_tstr_put_lit(state, "ClaimCount") && zcbor_int32_put(state, fx->edi.claim_count);
            ok = ok && zcbor_tstr_put_lit(state, "TotalActual") && zcbor_float64_put(state, fx->edi.total_actual);
            break;
        default:
            return -1;
    }
    ok = ok && zcbor_map_end_encode(state, 8);
    if (!ok) return -1;
    *ol = (size_t)(state->payload - buf);
    return 0;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    ZCBOR_STATE_D(state, 4, buf, len, 16, 0);
    struct zcbor_string key;
    int32_t k = -1;
    memset(out, 0, sizeof *out);
    out->kind = kind;
    out->name = test_data_name(kind);
    if (!zcbor_map_start_decode(state)) return -1;
    while (!zcbor_array_at_end(state)) {
        if (!zcbor_tstr_decode(state, &key)) return -1;
        char keybuf[32];
        size_t kl = key.len < sizeof keybuf - 1 ? key.len : sizeof keybuf - 1;
        memcpy(keybuf, key.value, kl); keybuf[kl] = 0;
        if (strcmp(keybuf, "kind") == 0) {
            if (!zcbor_int32_decode(state, &k)) return -1;
        } else if (strcmp(keybuf, "value") == 0) {
            int32_t v; if (!zcbor_int32_decode(state, &v)) return -1; out->integer_val = v;
        } else if (strcmp(keybuf, "Id") == 0 && kind == TD_SIMPLE) {
            int32_t v; if (!zcbor_int32_decode(state, &v)) return -1; out->simple.id = v;
        } else if (strcmp(keybuf, "Id") == 0 && kind == TD_TELEMETRY) {
            struct zcbor_string s; if (!zcbor_tstr_decode(state, &s)) return -1;
            size_t n = s.len < sizeof out->telemetry.id - 1 ? s.len : sizeof out->telemetry.id - 1;
            memcpy(out->telemetry.id, s.value, n); out->telemetry.id[n] = 0;
        } else if (strcmp(keybuf, "Name") == 0) {
            struct zcbor_string s; if (!zcbor_tstr_decode(state, &s)) return -1;
            size_t n = s.len < sizeof out->simple.name - 1 ? s.len : sizeof out->simple.name - 1;
            memcpy(out->simple.name, s.value, n); out->simple.name[n] = 0;
        } else if (strcmp(keybuf, "Timestamp") == 0) {
            struct zcbor_string s; if (!zcbor_tstr_decode(state, &s)) return -1;
            size_t n = s.len < sizeof out->simple.timestamp - 1 ? s.len : sizeof out->simple.timestamp - 1;
            memcpy(out->simple.timestamp, s.value, n); out->simple.timestamp[n] = 0;
        } else if (strcmp(keybuf, "IsActive") == 0) {
            bool b; if (!zcbor_bool_decode(state, &b)) return -1; out->simple.is_active = b;
        } else if (strcmp(keybuf, "FirstName") == 0) {
            struct zcbor_string s; if (!zcbor_tstr_decode(state, &s)) return -1;
            size_t n = s.len < sizeof out->person.first_name - 1 ? s.len : sizeof out->person.first_name - 1;
            memcpy(out->person.first_name, s.value, n); out->person.first_name[n] = 0;
        } else if (strcmp(keybuf, "LastName") == 0) {
            struct zcbor_string s; if (!zcbor_tstr_decode(state, &s)) return -1;
            size_t n = s.len < sizeof out->person.last_name - 1 ? s.len : sizeof out->person.last_name - 1;
            memcpy(out->person.last_name, s.value, n); out->person.last_name[n] = 0;
        } else if (strcmp(keybuf, "Age") == 0) {
            int32_t v; if (!zcbor_int32_decode(state, &v)) return -1; out->person.age = v;
        } else if (strcmp(keybuf, "Gender") == 0) {
            int32_t v; if (!zcbor_int32_decode(state, &v)) return -1; out->person.gender = v;
        } else if (strcmp(keybuf, "PoliceCount") == 0) {
            int32_t v; if (!zcbor_int32_decode(state, &v)) return -1; out->person.police_count = v;
        } else if (strcmp(keybuf, "Param1") == 0) {
            int32_t v; if (!zcbor_int32_decode(state, &v)) return -1; out->telemetry.param1 = v;
        } else if (strcmp(keybuf, "MeasCount") == 0) {
            int32_t v; if (!zcbor_int32_decode(state, &v)) return -1; out->telemetry.meas_count = v;
        } else if (strcmp(keybuf, "Count") == 0) {
            int32_t v; if (!zcbor_int32_decode(state, &v)) return -1; out->string_array.count = v;
        } else if (strcmp(keybuf, "Items") == 0) {
            if (!zcbor_list_start_decode(state)) return -1;
            int i = 0;
            while (!zcbor_array_at_end(state) && i < 100) {
                struct zcbor_string s; if (!zcbor_tstr_decode(state, &s)) return -1;
                size_t n = s.len < 15 ? s.len : 15;
                memcpy(out->string_array.items[i], s.value, n); out->string_array.items[i][n] = 0;
                i++;
            }
            if (!zcbor_list_end_decode(state)) return -1;
        } else if (strcmp(keybuf, "PayerName") == 0) {
            struct zcbor_string s; if (!zcbor_tstr_decode(state, &s)) return -1;
            size_t n = s.len < sizeof out->edi.payer_name - 1 ? s.len : sizeof out->edi.payer_name - 1;
            memcpy(out->edi.payer_name, s.value, n); out->edi.payer_name[n] = 0;
        } else if (strcmp(keybuf, "PayeeName") == 0) {
            struct zcbor_string s; if (!zcbor_tstr_decode(state, &s)) return -1;
            size_t n = s.len < sizeof out->edi.payee_name - 1 ? s.len : sizeof out->edi.payee_name - 1;
            memcpy(out->edi.payee_name, s.value, n); out->edi.payee_name[n] = 0;
        } else if (strcmp(keybuf, "ClaimCount") == 0) {
            int32_t v; if (!zcbor_int32_decode(state, &v)) return -1; out->edi.claim_count = v;
        } else if (strcmp(keybuf, "TotalActual") == 0) {
            double d; if (!zcbor_float64_decode(state, &d)) return -1; out->edi.total_actual = d;
        } else {
            if (!zcbor_any_skip(state, NULL)) return -1;
        }
    }
    if (!zcbor_map_end_decode(state)) return -1;
    return k == (int32_t)kind ? 0 : -1;
}

void bench_register_zcbor(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "zcbor", "0.9", "schema", prep, ser, de, fidelity_fx);
}
