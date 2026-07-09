#include "ser_common.h"
#include <msgpack.h>

/*
 * Optimal msgpack-c usage:
 *  - Pack into a fixed buffer via custom write callback (no sbuffer realloc+memcpy)
 *  - Native map/array field encoding (not opaque binary payload)
 *  - msgpack_unpack_next / object map walk for decode
 */

typedef struct {
    uint8_t *buf;
    size_t cap;
    size_t used;
    int overflow;
} fixed_buf_t;

static int fixed_write(void *data, const char *buf, size_t len) {
    fixed_buf_t *fb = (fixed_buf_t *)data;
    if (fb->overflow) return -1;
    if (fb->used + len > fb->cap) { fb->overflow = 1; return -1; }
    memcpy(fb->buf + fb->used, buf, len);
    fb->used += len;
    return 0;
}

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static int pack_str(msgpack_packer *pk, const char *s) {
    size_t n = strlen(s);
    if (msgpack_pack_str(pk, n) != 0) return -1;
    return msgpack_pack_str_body(pk, s, n);
}

static int pack_key(msgpack_packer *pk, const char *k) { return pack_str(pk, k); }

static int pack_fx(msgpack_packer *pk, const test_fixture_t *fx) {
    switch (fx->kind) {
        case TD_INTEGER:
            if (msgpack_pack_map(pk, 2)) return -1;
            if (pack_key(pk, "kind") || msgpack_pack_int(pk, (int)fx->kind)) return -1;
            if (pack_key(pk, "value") || msgpack_pack_int(pk, fx->integer_val)) return -1;
            return 0;
        case TD_SIMPLE:
            if (msgpack_pack_map(pk, 5)) return -1;
            if (pack_key(pk, "kind") || msgpack_pack_int(pk, (int)fx->kind)) return -1;
            if (pack_key(pk, "Id") || msgpack_pack_int(pk, fx->simple.id)) return -1;
            if (pack_key(pk, "Name") || pack_str(pk, fx->simple.name)) return -1;
            if (pack_key(pk, "Timestamp") || pack_str(pk, fx->simple.timestamp)) return -1;
            if (pack_key(pk, "IsActive") || (fx->simple.is_active ? msgpack_pack_true(pk) : msgpack_pack_false(pk))) return -1;
            return 0;
        case TD_PERSON: {
            const person_t *p = &fx->person;
            int n = p->police_count; if (n < 0) n = 0; if (n > 8) n = 8;
            if (msgpack_pack_map(pk, 7)) return -1;
            if (pack_key(pk, "kind") || msgpack_pack_int(pk, (int)fx->kind)) return -1;
            if (pack_key(pk, "FirstName") || pack_str(pk, p->first_name)) return -1;
            if (pack_key(pk, "LastName") || pack_str(pk, p->last_name)) return -1;
            if (pack_key(pk, "Age") || msgpack_pack_int(pk, p->age)) return -1;
            if (pack_key(pk, "Gender") || msgpack_pack_int(pk, p->gender)) return -1;
            if (pack_key(pk, "Passport") || msgpack_pack_map(pk, 2)) return -1;
            if (pack_key(pk, "Number") || pack_str(pk, p->passport_number)) return -1;
            if (pack_key(pk, "Authority") || pack_str(pk, p->passport_authority)) return -1;
            if (pack_key(pk, "PoliceRecords") || msgpack_pack_array(pk, (size_t)n)) return -1;
            for (int i = 0; i < n; i++) {
                if (msgpack_pack_map(pk, 2)) return -1;
                if (pack_key(pk, "Id") || msgpack_pack_int(pk, p->police_ids[i])) return -1;
                if (pack_key(pk, "CrimeCode") || pack_str(pk, p->police_codes[i])) return -1;
            }
            return 0;
        }
        case TD_TELEMETRY: {
            const telemetry_t *t = &fx->telemetry;
            int n = t->meas_count; if (n < 0) n = 0; if (n > 100) n = 100;
            if (msgpack_pack_map(pk, 10)) return -1;
            if (pack_key(pk, "kind") || msgpack_pack_int(pk, (int)fx->kind)) return -1;
            if (pack_key(pk, "Id") || pack_str(pk, t->id)) return -1;
            if (pack_key(pk, "DataSource") || pack_str(pk, t->data_source)) return -1;
            if (pack_key(pk, "TimeStamp") || pack_str(pk, t->time_stamp)) return -1;
            if (pack_key(pk, "Param1") || msgpack_pack_int(pk, t->param1)) return -1;
            if (pack_key(pk, "Param2") || msgpack_pack_int(pk, t->param2)) return -1;
            if (pack_key(pk, "Measurements") || msgpack_pack_array(pk, (size_t)n)) return -1;
            for (int i = 0; i < n; i++) if (msgpack_pack_double(pk, t->measurements[i])) return -1;
            if (pack_key(pk, "AssociatedProblemID") || msgpack_pack_int(pk, t->problem_id)) return -1;
            if (pack_key(pk, "AssociatedLogID") || msgpack_pack_int(pk, t->log_id)) return -1;
            if (pack_key(pk, "WasProcessed") || (t->was_processed ? msgpack_pack_true(pk) : msgpack_pack_false(pk))) return -1;
            return 0;
        }
        case TD_STRING_ARRAY: {
            int n = fx->string_array.count; if (n < 0) n = 0; if (n > 100) n = 100;
            if (msgpack_pack_map(pk, 3)) return -1;
            if (pack_key(pk, "kind") || msgpack_pack_int(pk, (int)fx->kind)) return -1;
            if (pack_key(pk, "Count") || msgpack_pack_int(pk, n)) return -1;
            if (pack_key(pk, "Items") || msgpack_pack_array(pk, (size_t)n)) return -1;
            for (int i = 0; i < n; i++) if (pack_str(pk, fx->string_array.items[i])) return -1;
            return 0;
        }
        case TD_EDI835: {
            const edi835_t *e = &fx->edi;
            int nc = e->claim_count; if (nc < 0) nc = 0; if (nc > 6) nc = 6;
            if (msgpack_pack_map(pk, 7)) return -1;
            if (pack_key(pk, "kind") || msgpack_pack_int(pk, (int)fx->kind)) return -1;
            if (pack_key(pk, "PayerName") || pack_str(pk, e->payer_name)) return -1;
            if (pack_key(pk, "PayeeName") || pack_str(pk, e->payee_name)) return -1;
            if (pack_key(pk, "PaymentDate") || pack_str(pk, e->payment_date)) return -1;
            if (pack_key(pk, "TotalActual") || msgpack_pack_double(pk, e->total_actual)) return -1;
            if (pack_key(pk, "TCN") || pack_str(pk, e->tcn)) return -1;
            if (pack_key(pk, "Claims") || msgpack_pack_array(pk, (size_t)nc)) return -1;
            for (int c = 0; c < nc; c++) {
                const claim_t *cl = &e->claims[c];
                int nl = cl->line_count; if (nl < 0) nl = 0; if (nl > 4) nl = 4;
                if (msgpack_pack_map(pk, 5)) return -1;
                if (pack_key(pk, "ClaimId") || pack_str(pk, cl->claim_id)) return -1;
                if (pack_key(pk, "PatientName") || pack_str(pk, cl->patient_name)) return -1;
                if (pack_key(pk, "TotalCharge") || msgpack_pack_double(pk, cl->total_charge)) return -1;
                if (pack_key(pk, "Payment") || msgpack_pack_double(pk, cl->payment)) return -1;
                if (pack_key(pk, "Lines") || msgpack_pack_array(pk, (size_t)nl)) return -1;
                for (int L = 0; L < nl; L++) {
                    if (msgpack_pack_map(pk, 3)) return -1;
                    if (pack_key(pk, "ServiceCode") || pack_str(pk, cl->lines[L].service_code)) return -1;
                    if (pack_key(pk, "Charge") || msgpack_pack_double(pk, cl->lines[L].charge)) return -1;
                    if (pack_key(pk, "Adjudicated") || msgpack_pack_double(pk, cl->lines[L].adjudicated)) return -1;
                }
            }
            return 0;
        }

        case TD_OBJECT_GRAPH: {
            const object_graph_t *g = &fx->graph;
            int nn = g->node_count; if (nn < 0) nn = 0; if (nn > GRAPH_MAX_NODES) nn = GRAPH_MAX_NODES;
            if (msgpack_pack_map(pk, 3)) return -1;
            if (pack_key(pk, "kind") || msgpack_pack_int(pk, (int)fx->kind)) return -1;
            if (pack_key(pk, "root") || msgpack_pack_int(pk, g->root)) return -1;
            if (pack_key(pk, "nodes") || msgpack_pack_array(pk, (size_t)nn)) return -1;
            for (int i = 0; i < nn; i++) {
                const graph_node_t *n = &g->nodes[i];
                int nc = n->child_count; if (nc < 0) nc = 0; if (nc > GRAPH_MAX_CHILDREN) nc = GRAPH_MAX_CHILDREN;
                if (msgpack_pack_map(pk, 4)) return -1;
                if (pack_key(pk, "Name") || pack_str(pk, n->name)) return -1;
                if (pack_key(pk, "Parent") || msgpack_pack_int(pk, n->parent)) return -1;
                if (pack_key(pk, "Related") || msgpack_pack_int(pk, n->related)) return -1;
                if (pack_key(pk, "Children") || msgpack_pack_array(pk, (size_t)nc)) return -1;
                for (int c = 0; c < nc; c++) if (msgpack_pack_int(pk, n->children[c])) return -1;
            }
            return 0;
        }
        default: return -1;
    }
}

static int key_eq(msgpack_object k, const char *s) {
    size_t n = strlen(s);
    return k.type == MSGPACK_OBJECT_STR && k.via.str.size == n && memcmp(k.via.str.ptr, s, n) == 0;
}
static int obj_int(msgpack_object o, int *out) {
    if (o.type == MSGPACK_OBJECT_POSITIVE_INTEGER) { *out = (int)o.via.u64; return 0; }
    if (o.type == MSGPACK_OBJECT_NEGATIVE_INTEGER) { *out = (int)o.via.i64; return 0; }
    return -1;
}
static int obj_str(msgpack_object o, char *dst, size_t dstsz) {
    if (o.type != MSGPACK_OBJECT_STR || o.via.str.size >= dstsz) return -1;
    memcpy(dst, o.via.str.ptr, o.via.str.size); dst[o.via.str.size] = 0; return 0;
}
static msgpack_object *map_get(msgpack_object map, const char *key) {
    if (map.type != MSGPACK_OBJECT_MAP) return NULL;
    for (uint32_t i = 0; i < map.via.map.size; i++)
        if (key_eq(map.via.map.ptr[i].key, key)) return &map.via.map.ptr[i].val;
    return NULL;
}

static int read_fx(msgpack_object root, test_fixture_t *out, test_data_kind_t kind) {
    msgpack_object *kv = map_get(root, "kind");
    int k = -1;
    if (!kv || obj_int(*kv, &k) || k != (int)kind) return -1;
    memset(out, 0, sizeof *out);
    out->kind = kind;
    out->name = test_data_name(kind);
    switch (kind) {
        case TD_INTEGER: {
            msgpack_object *v = map_get(root, "value");
            return v ? obj_int(*v, &out->integer_val) : -1;
        }
        case TD_SIMPLE: {
            msgpack_object *v;
            if (!(v = map_get(root, "Id")) || obj_int(*v, &out->simple.id)) return -1;
            if (!(v = map_get(root, "Name")) || obj_str(*v, out->simple.name, sizeof out->simple.name)) return -1;
            if ((v = map_get(root, "Timestamp"))) obj_str(*v, out->simple.timestamp, sizeof out->simple.timestamp);
            if ((v = map_get(root, "IsActive"))) out->simple.is_active = (v->type == MSGPACK_OBJECT_BOOLEAN && v->via.boolean);
            return 0;
        }
        case TD_PERSON: {
            msgpack_object *v;
            if (!(v = map_get(root, "FirstName")) || obj_str(*v, out->person.first_name, sizeof out->person.first_name)) return -1;
            if (!(v = map_get(root, "LastName")) || obj_str(*v, out->person.last_name, sizeof out->person.last_name)) return -1;
            if ((v = map_get(root, "Age"))) obj_int(*v, &out->person.age);
            if ((v = map_get(root, "Gender"))) obj_int(*v, &out->person.gender);
            if ((v = map_get(root, "Passport")) && v->type == MSGPACK_OBJECT_MAP) {
                msgpack_object *p;
                if ((p = map_get(*v, "Number"))) obj_str(*p, out->person.passport_number, sizeof out->person.passport_number);
                if ((p = map_get(*v, "Authority"))) obj_str(*p, out->person.passport_authority, sizeof out->person.passport_authority);
            }
            if ((v = map_get(root, "PoliceRecords")) && v->type == MSGPACK_OBJECT_ARRAY) {
                uint32_t n = v->via.array.size; if (n > 8) n = 8;
                out->person.police_count = (int)n;
                for (uint32_t i = 0; i < n; i++) {
                    msgpack_object rec = v->via.array.ptr[i];
                    msgpack_object *f;
                    if ((f = map_get(rec, "Id"))) obj_int(*f, &out->person.police_ids[i]);
                    if ((f = map_get(rec, "CrimeCode"))) obj_str(*f, out->person.police_codes[i], sizeof out->person.police_codes[i]);
                }
            }
            return 0;
        }
        case TD_TELEMETRY: {
            msgpack_object *v;
            if (!(v = map_get(root, "Id")) || obj_str(*v, out->telemetry.id, sizeof out->telemetry.id)) return -1;
            if ((v = map_get(root, "DataSource"))) obj_str(*v, out->telemetry.data_source, sizeof out->telemetry.data_source);
            if ((v = map_get(root, "TimeStamp"))) obj_str(*v, out->telemetry.time_stamp, sizeof out->telemetry.time_stamp);
            if ((v = map_get(root, "Param1"))) obj_int(*v, &out->telemetry.param1);
            if ((v = map_get(root, "Param2"))) obj_int(*v, &out->telemetry.param2);
            if ((v = map_get(root, "AssociatedProblemID"))) obj_int(*v, &out->telemetry.problem_id);
            if ((v = map_get(root, "AssociatedLogID"))) obj_int(*v, &out->telemetry.log_id);
            if ((v = map_get(root, "WasProcessed"))) out->telemetry.was_processed = (v->type == MSGPACK_OBJECT_BOOLEAN && v->via.boolean);
            if ((v = map_get(root, "Measurements")) && v->type == MSGPACK_OBJECT_ARRAY) {
                uint32_t n = v->via.array.size; if (n > 100) n = 100;
                out->telemetry.meas_count = (int)n;
                for (uint32_t i = 0; i < n; i++) {
                    msgpack_object m = v->via.array.ptr[i];
                    if (m.type == MSGPACK_OBJECT_FLOAT64) out->telemetry.measurements[i] = m.via.f64;
                    else if (m.type == MSGPACK_OBJECT_FLOAT32) out->telemetry.measurements[i] = m.via.f64;
                }
            }
            return 0;
        }
        case TD_STRING_ARRAY: {
            msgpack_object *v = map_get(root, "Items");
            if (!v || v->type != MSGPACK_OBJECT_ARRAY) return -1;
            uint32_t n = v->via.array.size; if (n > 100) n = 100;
            out->string_array.count = (int)n;
            for (uint32_t i = 0; i < n; i++)
                if (obj_str(v->via.array.ptr[i], out->string_array.items[i], sizeof out->string_array.items[i])) return -1;
            return 0;
        }
        case TD_EDI835: {
            msgpack_object *v;
            if (!(v = map_get(root, "PayerName")) || obj_str(*v, out->edi.payer_name, sizeof out->edi.payer_name)) return -1;
            if ((v = map_get(root, "PayeeName"))) obj_str(*v, out->edi.payee_name, sizeof out->edi.payee_name);
            if ((v = map_get(root, "PaymentDate"))) obj_str(*v, out->edi.payment_date, sizeof out->edi.payment_date);
            if ((v = map_get(root, "TCN"))) obj_str(*v, out->edi.tcn, sizeof out->edi.tcn);
            if ((v = map_get(root, "TotalActual")) && (v->type == MSGPACK_OBJECT_FLOAT64 || v->type == MSGPACK_OBJECT_FLOAT32))
                out->edi.total_actual = v->via.f64;
            if ((v = map_get(root, "Claims")) && v->type == MSGPACK_OBJECT_ARRAY) {
                uint32_t nc = v->via.array.size; if (nc > 6) nc = 6;
                out->edi.claim_count = (int)nc;
                for (uint32_t c = 0; c < nc; c++) {
                    msgpack_object co = v->via.array.ptr[c];
                    claim_t *cl = &out->edi.claims[c];
                    msgpack_object *f;
                    if ((f = map_get(co, "ClaimId"))) obj_str(*f, cl->claim_id, sizeof cl->claim_id);
                    if ((f = map_get(co, "PatientName"))) obj_str(*f, cl->patient_name, sizeof cl->patient_name);
                    if ((f = map_get(co, "TotalCharge")) && (f->type == MSGPACK_OBJECT_FLOAT64 || f->type == MSGPACK_OBJECT_FLOAT32))
                        cl->total_charge = f->via.f64;
                    if ((f = map_get(co, "Payment")) && (f->type == MSGPACK_OBJECT_FLOAT64 || f->type == MSGPACK_OBJECT_FLOAT32))
                        cl->payment = f->via.f64;
                    if ((f = map_get(co, "Lines")) && f->type == MSGPACK_OBJECT_ARRAY) {
                        uint32_t nl = f->via.array.size; if (nl > 4) nl = 4;
                        cl->line_count = (int)nl;
                        for (uint32_t L = 0; L < nl; L++) {
                            msgpack_object lo = f->via.array.ptr[L];
                            msgpack_object *g;
                            if ((g = map_get(lo, "ServiceCode"))) obj_str(*g, cl->lines[L].service_code, sizeof cl->lines[L].service_code);
                            if ((g = map_get(lo, "Charge")) && (g->type == MSGPACK_OBJECT_FLOAT64 || g->type == MSGPACK_OBJECT_FLOAT32))
                                cl->lines[L].charge = g->via.f64;
                            if ((g = map_get(lo, "Adjudicated")) && (g->type == MSGPACK_OBJECT_FLOAT64 || g->type == MSGPACK_OBJECT_FLOAT32))
                                cl->lines[L].adjudicated = g->via.f64;
                        }
                    }
                }
            }
            return 0;
        }

        case TD_OBJECT_GRAPH: {
            msgpack_object *v;
            if ((v = map_get(root, "root"))) obj_int(*v, &out->graph.root);
            if (!(v = map_get(root, "nodes")) || v->type != MSGPACK_OBJECT_ARRAY) return -1;
            uint32_t nn = v->via.array.size; if (nn > GRAPH_MAX_NODES) nn = GRAPH_MAX_NODES;
            out->graph.node_count = (int)nn;
            for (uint32_t i = 0; i < nn; i++) {
                msgpack_object no = v->via.array.ptr[i];
                graph_node_t *n = &out->graph.nodes[i];
                msgpack_object *f;
                if ((f = map_get(no, "Name"))) obj_str(*f, n->name, sizeof n->name);
                if ((f = map_get(no, "Parent"))) obj_int(*f, &n->parent);
                if ((f = map_get(no, "Related"))) obj_int(*f, &n->related);
                if ((f = map_get(no, "Children")) && f->type == MSGPACK_OBJECT_ARRAY) {
                    uint32_t nc = f->via.array.size; if (nc > GRAPH_MAX_CHILDREN) nc = GRAPH_MAX_CHILDREN;
                    n->child_count = (int)nc;
                    for (uint32_t c = 0; c < nc; c++) obj_int(f->via.array.ptr[c], &n->children[c]);
                }
            }
            return 0;
        }
        default: return -1;
    }
}

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    fixed_buf_t fb = { .buf = buf, .cap = cap, .used = 0, .overflow = 0 };
    msgpack_packer pk;
    msgpack_packer_init(&pk, &fb, fixed_write);
    if (pack_fx(&pk, fx) || fb.overflow) return -1;
    *ol = fb.used;
    return 0;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    msgpack_unpacked result;
    msgpack_unpacked_init(&result);
    if (msgpack_unpack_next(&result, (const char *)buf, len, NULL) != MSGPACK_UNPACK_SUCCESS) {
        msgpack_unpacked_destroy(&result); return -1;
    }
    int rc = read_fx(result.data, out, kind);
    msgpack_unpacked_destroy(&result);
    return rc;
}

void bench_register_msgpack_c(serializer_t *o, int *c) {
    static char ver_s[32];
    snprintf(ver_s, sizeof ver_s, "%d.%d.%d", MSGPACK_VERSION_MAJOR, MSGPACK_VERSION_MINOR, MSGPACK_VERSION_REVISION);
    BENCH_ADD(o, c, "msgpack-c", ver_s, "binary", prep, ser, de, fidelity_fx);
}
