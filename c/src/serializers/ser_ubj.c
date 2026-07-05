#include "ser_common.h"

static int ubj_write_char(uint8_t **p, uint8_t *end, char t) {
    if (*p >= end) return -1; *(*p)++ = (uint8_t)t; return 0;
}
static int ubj_write_int32(uint8_t **p, uint8_t *end, int32_t v) {
    if (ubj_write_char(p, end, 'l')) return -1;
    if (*p + 4 > end) return -1;
    (*p)[0] = (uint8_t)((v >> 24) & 0xff);
    (*p)[1] = (uint8_t)((v >> 16) & 0xff);
    (*p)[2] = (uint8_t)((v >> 8) & 0xff);
    (*p)[3] = (uint8_t)(v & 0xff);
    *p += 4; return 0;
}
static int ubj_write_str(uint8_t **p, uint8_t *end, const char *s) {
    size_t n = strlen(s);
    if (ubj_write_char(p, end, 'S')) return -1;
    if (ubj_write_int32(p, end, (int32_t)n)) return -1;
    if (*p + n > end) return -1;
    memcpy(*p, s, n); *p += n; return 0;
}
static int ubj_write_bool(uint8_t **p, uint8_t *end, bool v) {
    return ubj_write_char(p, end, v ? 'T' : 'F');
}
static int ubj_write_f64(uint8_t **p, uint8_t *end, double v) {
    if (ubj_write_char(p, end, 'D')) return -1;
    if (*p + 8 > end) return -1;
    uint64_t u; memcpy(&u, &v, 8);
    for (int i = 7; i >= 0; i--) *(*p)++ = (uint8_t)((u >> (i * 8)) & 0xff);
    return 0;
}
static int ubj_write_key(uint8_t **p, uint8_t *end, const char *k) {
    size_t n = strlen(k);
    if (ubj_write_int32(p, end, (int32_t)n)) return -1;
    if (*p + n > end) return -1;
    memcpy(*p, k, n); *p += n; return 0;
}

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    uint8_t *p = buf, *end = buf + cap;
    if (ubj_write_char(&p, end, '{')) return -1;
    if (ubj_write_key(&p, end, "kind") || ubj_write_int32(&p, end, (int32_t)fx->kind)) return -1;
    switch (fx->kind) {
        case TD_INTEGER:
            if (ubj_write_key(&p, end, "value") || ubj_write_int32(&p, end, fx->integer_val)) return -1;
            break;
        case TD_SIMPLE:
            if (ubj_write_key(&p, end, "Id") || ubj_write_int32(&p, end, fx->simple.id)) return -1;
            if (ubj_write_key(&p, end, "Name") || ubj_write_str(&p, end, fx->simple.name)) return -1;
            if (ubj_write_key(&p, end, "Timestamp") || ubj_write_str(&p, end, fx->simple.timestamp)) return -1;
            if (ubj_write_key(&p, end, "IsActive") || ubj_write_bool(&p, end, fx->simple.is_active)) return -1;
            break;
        case TD_PERSON:
            if (ubj_write_key(&p, end, "FirstName") || ubj_write_str(&p, end, fx->person.first_name)) return -1;
            if (ubj_write_key(&p, end, "LastName") || ubj_write_str(&p, end, fx->person.last_name)) return -1;
            if (ubj_write_key(&p, end, "Age") || ubj_write_int32(&p, end, fx->person.age)) return -1;
            if (ubj_write_key(&p, end, "Gender") || ubj_write_int32(&p, end, fx->person.gender)) return -1;
            if (ubj_write_key(&p, end, "PoliceCount") || ubj_write_int32(&p, end, fx->person.police_count)) return -1;
            break;
        case TD_TELEMETRY:
            if (ubj_write_key(&p, end, "Id") || ubj_write_str(&p, end, fx->telemetry.id)) return -1;
            if (ubj_write_key(&p, end, "Param1") || ubj_write_int32(&p, end, fx->telemetry.param1)) return -1;
            if (ubj_write_key(&p, end, "MeasCount") || ubj_write_int32(&p, end, fx->telemetry.meas_count)) return -1;
            break;
        case TD_STRING_ARRAY:
            if (ubj_write_key(&p, end, "Count") || ubj_write_int32(&p, end, fx->string_array.count)) return -1;
            if (ubj_write_key(&p, end, "Items") || ubj_write_char(&p, end, '[')) return -1;
            for (int i = 0; i < fx->string_array.count && i < 100; i++)
                if (ubj_write_str(&p, end, fx->string_array.items[i])) return -1;
            if (ubj_write_char(&p, end, ']')) return -1;
            break;
        case TD_EDI835:
            if (ubj_write_key(&p, end, "PayerName") || ubj_write_str(&p, end, fx->edi.payer_name)) return -1;
            if (ubj_write_key(&p, end, "PayeeName") || ubj_write_str(&p, end, fx->edi.payee_name)) return -1;
            if (ubj_write_key(&p, end, "ClaimCount") || ubj_write_int32(&p, end, fx->edi.claim_count)) return -1;
            if (ubj_write_key(&p, end, "TotalActual") || ubj_write_f64(&p, end, fx->edi.total_actual)) return -1;
            break;
        default: return -1;
    }
    if (ubj_write_char(&p, end, '}')) return -1;
    *ol = (size_t)(p - buf);
    return 0;
}

static int r_char(const uint8_t **p, const uint8_t *end, char *t) {
    if (*p >= end) return -1; *t = (char)*(*p)++; return 0;
}
static int r_i32(const uint8_t **p, const uint8_t *end, int32_t *v) {
    char t; if (r_char(p, end, &t) || t != 'l' || *p + 4 > end) return -1;
    *v = ((int32_t)(*p)[0] << 24) | ((int32_t)(*p)[1] << 16) | ((int32_t)(*p)[2] << 8) | (int32_t)(*p)[3];
    *p += 4; return 0;
}
static int r_key(const uint8_t **p, const uint8_t *end, char *dst, size_t dstsz) {
    int32_t n; if (r_i32(p, end, &n) || n < 0 || *p + (size_t)n > end) return -1;
    size_t cpy = (size_t)n < dstsz - 1 ? (size_t)n : dstsz - 1;
    memcpy(dst, *p, cpy); dst[cpy] = 0; *p += (size_t)n; return 0;
}
static int r_str(const uint8_t **p, const uint8_t *end, char *dst, size_t dstsz) {
    char t; if (r_char(p, end, &t) || t != 'S') return -1;
    int32_t n; if (r_i32(p, end, &n) || n < 0 || *p + (size_t)n > end) return -1;
    size_t cpy = (size_t)n < dstsz - 1 ? (size_t)n : dstsz - 1;
    memcpy(dst, *p, cpy); dst[cpy] = 0; *p += (size_t)n; return 0;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    const uint8_t *p = buf, *end = buf + len;
    char t;
    if (r_char(&p, end, &t) || t != '{') return -1;
    memset(out, 0, sizeof *out);
    out->kind = kind;
    out->name = test_data_name(kind);
    while (p < end) {
        if (*p == '}') { p++; break; }
        char key[64];
        if (r_key(&p, end, key, sizeof key)) return -1;
        if (strcmp(key, "kind") == 0) {
            int32_t v; if (r_i32(&p, end, &v) || v != (int32_t)kind) return -1;
        } else if (strcmp(key, "value") == 0) {
            int32_t v; if (r_i32(&p, end, &v)) return -1; out->integer_val = v;
        } else if (strcmp(key, "Id") == 0 && kind == TD_SIMPLE) {
            int32_t v; if (r_i32(&p, end, &v)) return -1; out->simple.id = v;
        } else if (strcmp(key, "Id") == 0 && kind == TD_TELEMETRY) {
            if (r_str(&p, end, out->telemetry.id, sizeof out->telemetry.id)) return -1;
        } else if (strcmp(key, "Name") == 0) {
            if (r_str(&p, end, out->simple.name, sizeof out->simple.name)) return -1;
        } else if (strcmp(key, "Timestamp") == 0) {
            if (r_str(&p, end, out->simple.timestamp, sizeof out->simple.timestamp)) return -1;
        } else if (strcmp(key, "IsActive") == 0) {
            if (r_char(&p, end, &t)) return -1; out->simple.is_active = (t == 'T');
        } else if (strcmp(key, "FirstName") == 0) {
            if (r_str(&p, end, out->person.first_name, sizeof out->person.first_name)) return -1;
        } else if (strcmp(key, "LastName") == 0) {
            if (r_str(&p, end, out->person.last_name, sizeof out->person.last_name)) return -1;
        } else if (strcmp(key, "Age") == 0) {
            int32_t v; if (r_i32(&p, end, &v)) return -1; out->person.age = v;
        } else if (strcmp(key, "Gender") == 0) {
            int32_t v; if (r_i32(&p, end, &v)) return -1; out->person.gender = v;
        } else if (strcmp(key, "PoliceCount") == 0) {
            int32_t v; if (r_i32(&p, end, &v)) return -1; out->person.police_count = v;
        } else if (strcmp(key, "Param1") == 0) {
            int32_t v; if (r_i32(&p, end, &v)) return -1; out->telemetry.param1 = v;
        } else if (strcmp(key, "MeasCount") == 0) {
            int32_t v; if (r_i32(&p, end, &v)) return -1; out->telemetry.meas_count = v;
        } else if (strcmp(key, "Count") == 0) {
            int32_t v; if (r_i32(&p, end, &v)) return -1; out->string_array.count = v;
        } else if (strcmp(key, "Items") == 0) {
            if (r_char(&p, end, &t) || t != '[') return -1;
            int i = 0;
            while (p < end && *p != ']') {
                if (i >= 100) return -1;
                if (r_str(&p, end, out->string_array.items[i], sizeof out->string_array.items[i])) return -1;
                i++;
            }
            if (r_char(&p, end, &t) || t != ']') return -1;
        } else if (strcmp(key, "PayerName") == 0) {
            if (r_str(&p, end, out->edi.payer_name, sizeof out->edi.payer_name)) return -1;
        } else if (strcmp(key, "PayeeName") == 0) {
            if (r_str(&p, end, out->edi.payee_name, sizeof out->edi.payee_name)) return -1;
        } else if (strcmp(key, "ClaimCount") == 0) {
            int32_t v; if (r_i32(&p, end, &v)) return -1; out->edi.claim_count = v;
        } else if (strcmp(key, "TotalActual") == 0) {
            if (r_char(&p, end, &t) || t != 'D' || p + 8 > end) return -1;
            uint64_t u = 0;
            for (int i = 0; i < 8; i++) u = (u << 8) | p[i];
            p += 8; memcpy(&out->edi.total_actual, &u, 8);
        } else {
            return -1;
        }
    }
    return 0;
}

void bench_register_ubj(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "ubj", "1.0-min", "binary", prep, ser, de, fidelity_fx);
}
