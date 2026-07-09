#define MPACK_HAS_CONFIG 0
#include "ser_common.h"
#include "mpack/mpack.h"

/*
 * Optimal mpack usage (ludocode/mpack):
 *  - Fixed-buffer mpack_writer_init into the caller buffer (no growable alloc)
 *  - mpack_build_map / mpack_write_* for structured fields (not opaque blobs)
 *  - mpack_tree_init_data + map_cstr for decode (DOM is the recommended random-access path)
 */

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static int write_fx(mpack_writer_t *w, const test_fixture_t *fx) {
    mpack_build_map(w);
    mpack_write_cstr(w, "kind"); mpack_write_int(w, (int64_t)fx->kind);
    switch (fx->kind) {
        case TD_INTEGER:
            mpack_write_cstr(w, "value"); mpack_write_int(w, fx->integer_val);
            break;
        case TD_SIMPLE:
            mpack_write_cstr(w, "Id"); mpack_write_int(w, fx->simple.id);
            mpack_write_cstr(w, "Name"); mpack_write_cstr(w, fx->simple.name);
            mpack_write_cstr(w, "Timestamp"); mpack_write_cstr(w, fx->simple.timestamp);
            mpack_write_cstr(w, "IsActive"); mpack_write_bool(w, fx->simple.is_active);
            break;
        case TD_PERSON: {
            const person_t *p = &fx->person;
            mpack_write_cstr(w, "FirstName"); mpack_write_cstr(w, p->first_name);
            mpack_write_cstr(w, "LastName"); mpack_write_cstr(w, p->last_name);
            mpack_write_cstr(w, "Age"); mpack_write_int(w, p->age);
            mpack_write_cstr(w, "Gender"); mpack_write_int(w, p->gender);
            mpack_write_cstr(w, "Passport");
            mpack_build_map(w);
            mpack_write_cstr(w, "Number"); mpack_write_cstr(w, p->passport_number);
            mpack_write_cstr(w, "Authority"); mpack_write_cstr(w, p->passport_authority);
            mpack_complete_map(w);
            int n = p->police_count; if (n < 0) n = 0; if (n > 8) n = 8;
            mpack_write_cstr(w, "PoliceRecords");
            mpack_start_array(w, (uint32_t)n);
            for (int i = 0; i < n; i++) {
                mpack_build_map(w);
                mpack_write_cstr(w, "Id"); mpack_write_int(w, p->police_ids[i]);
                mpack_write_cstr(w, "CrimeCode"); mpack_write_cstr(w, p->police_codes[i]);
                mpack_complete_map(w);
            }
            mpack_finish_array(w);
            break;
        }
        case TD_TELEMETRY: {
            const telemetry_t *t = &fx->telemetry;
            mpack_write_cstr(w, "Id"); mpack_write_cstr(w, t->id);
            mpack_write_cstr(w, "DataSource"); mpack_write_cstr(w, t->data_source);
            mpack_write_cstr(w, "TimeStamp"); mpack_write_cstr(w, t->time_stamp);
            mpack_write_cstr(w, "Param1"); mpack_write_int(w, t->param1);
            mpack_write_cstr(w, "Param2"); mpack_write_int(w, t->param2);
            int n = t->meas_count; if (n < 0) n = 0; if (n > 100) n = 100;
            mpack_write_cstr(w, "Measurements");
            mpack_start_array(w, (uint32_t)n);
            for (int i = 0; i < n; i++) mpack_write_double(w, t->measurements[i]);
            mpack_finish_array(w);
            mpack_write_cstr(w, "AssociatedProblemID"); mpack_write_int(w, t->problem_id);
            mpack_write_cstr(w, "AssociatedLogID"); mpack_write_int(w, t->log_id);
            mpack_write_cstr(w, "WasProcessed"); mpack_write_bool(w, t->was_processed);
            break;
        }
        case TD_STRING_ARRAY: {
            int n = fx->string_array.count; if (n < 0) n = 0; if (n > 100) n = 100;
            mpack_write_cstr(w, "Count"); mpack_write_int(w, n);
            mpack_write_cstr(w, "Items");
            mpack_start_array(w, (uint32_t)n);
            for (int i = 0; i < n; i++) mpack_write_cstr(w, fx->string_array.items[i]);
            mpack_finish_array(w);
            break;
        }
        case TD_EDI835: {
            const edi835_t *e = &fx->edi;
            mpack_write_cstr(w, "PayerName"); mpack_write_cstr(w, e->payer_name);
            mpack_write_cstr(w, "PayeeName"); mpack_write_cstr(w, e->payee_name);
            mpack_write_cstr(w, "PaymentDate"); mpack_write_cstr(w, e->payment_date);
            mpack_write_cstr(w, "TotalActual"); mpack_write_double(w, e->total_actual);
            mpack_write_cstr(w, "TCN"); mpack_write_cstr(w, e->tcn);
            int nc = e->claim_count; if (nc < 0) nc = 0; if (nc > 6) nc = 6;
            mpack_write_cstr(w, "Claims");
            mpack_start_array(w, (uint32_t)nc);
            for (int c = 0; c < nc; c++) {
                const claim_t *cl = &e->claims[c];
                mpack_build_map(w);
                mpack_write_cstr(w, "ClaimId"); mpack_write_cstr(w, cl->claim_id);
                mpack_write_cstr(w, "PatientName"); mpack_write_cstr(w, cl->patient_name);
                mpack_write_cstr(w, "TotalCharge"); mpack_write_double(w, cl->total_charge);
                mpack_write_cstr(w, "Payment"); mpack_write_double(w, cl->payment);
                int nl = cl->line_count; if (nl < 0) nl = 0; if (nl > 4) nl = 4;
                mpack_write_cstr(w, "Lines");
                mpack_start_array(w, (uint32_t)nl);
                for (int L = 0; L < nl; L++) {
                    mpack_build_map(w);
                    mpack_write_cstr(w, "ServiceCode"); mpack_write_cstr(w, cl->lines[L].service_code);
                    mpack_write_cstr(w, "Charge"); mpack_write_double(w, cl->lines[L].charge);
                    mpack_write_cstr(w, "Adjudicated"); mpack_write_double(w, cl->lines[L].adjudicated);
                    mpack_complete_map(w);
                }
                mpack_finish_array(w);
                mpack_complete_map(w);
            }
            mpack_finish_array(w);
            break;
        }

        case TD_OBJECT_GRAPH: {
            const object_graph_t *g = &fx->graph;
            mpack_write_cstr(w, "root"); mpack_write_int(w, g->root);
            int nn = g->node_count; if (nn < 0) nn = 0; if (nn > GRAPH_MAX_NODES) nn = GRAPH_MAX_NODES;
            mpack_write_cstr(w, "nodes");
            mpack_start_array(w, (uint32_t)nn);
            for (int i = 0; i < nn; i++) {
                const graph_node_t *n = &g->nodes[i];
                int nc = n->child_count; if (nc < 0) nc = 0; if (nc > GRAPH_MAX_CHILDREN) nc = GRAPH_MAX_CHILDREN;
                mpack_build_map(w);
                mpack_write_cstr(w, "Name"); mpack_write_cstr(w, n->name);
                mpack_write_cstr(w, "Parent"); mpack_write_int(w, n->parent);
                mpack_write_cstr(w, "Related"); mpack_write_int(w, n->related);
                mpack_write_cstr(w, "Children");
                mpack_start_array(w, (uint32_t)nc);
                for (int c = 0; c < nc; c++) mpack_write_int(w, n->children[c]);
                mpack_finish_array(w);
                mpack_complete_map(w);
            }
            mpack_finish_array(w);
            break;
        }
        default:
            return -1;
    }
    mpack_complete_map(w);
    return 0;
}

static int copy_str(char *dst, size_t dstsz, mpack_node_t n) {
    if (mpack_node_type(n) != mpack_type_str) return -1;
    const char *s = mpack_node_str(n);
    size_t len = mpack_node_strlen(n);
    if (!s || len >= dstsz) return -1;
    memcpy(dst, s, len);
    dst[len] = 0;
    return 0;
}

static int read_fx(mpack_node_t root, test_fixture_t *out, test_data_kind_t kind) {
    if (mpack_node_int(mpack_node_map_cstr(root, "kind")) != (int)kind) return -1;
    memset(out, 0, sizeof *out);
    out->kind = kind;
    out->name = test_data_name(kind);
    switch (kind) {
        case TD_INTEGER:
            out->integer_val = (int)mpack_node_int(mpack_node_map_cstr(root, "value"));
            break;
        case TD_SIMPLE:
            out->simple.id = (int)mpack_node_int(mpack_node_map_cstr(root, "Id"));
            if (copy_str(out->simple.name, sizeof out->simple.name, mpack_node_map_cstr(root, "Name"))) return -1;
            if (copy_str(out->simple.timestamp, sizeof out->simple.timestamp, mpack_node_map_cstr(root, "Timestamp"))) return -1;
            out->simple.is_active = mpack_node_bool(mpack_node_map_cstr(root, "IsActive"));
            break;
        case TD_PERSON: {
            if (copy_str(out->person.first_name, sizeof out->person.first_name, mpack_node_map_cstr(root, "FirstName"))) return -1;
            if (copy_str(out->person.last_name, sizeof out->person.last_name, mpack_node_map_cstr(root, "LastName"))) return -1;
            out->person.age = (int)mpack_node_int(mpack_node_map_cstr(root, "Age"));
            out->person.gender = (int)mpack_node_int(mpack_node_map_cstr(root, "Gender"));
            mpack_node_t pass = mpack_node_map_cstr(root, "Passport");
            if (mpack_node_type(pass) == mpack_type_map) {
                copy_str(out->person.passport_number, sizeof out->person.passport_number, mpack_node_map_cstr(pass, "Number"));
                copy_str(out->person.passport_authority, sizeof out->person.passport_authority, mpack_node_map_cstr(pass, "Authority"));
            }
            mpack_node_t arr = mpack_node_map_cstr(root, "PoliceRecords");
            size_t n = mpack_node_array_length(arr); if (n > 8) n = 8;
            out->person.police_count = (int)n;
            for (size_t i = 0; i < n; i++) {
                mpack_node_t rec = mpack_node_array_at(arr, i);
                out->person.police_ids[i] = (int)mpack_node_int(mpack_node_map_cstr(rec, "Id"));
                copy_str(out->person.police_codes[i], sizeof out->person.police_codes[i], mpack_node_map_cstr(rec, "CrimeCode"));
            }
            break;
        }
        case TD_TELEMETRY: {
            if (copy_str(out->telemetry.id, sizeof out->telemetry.id, mpack_node_map_cstr(root, "Id"))) return -1;
            copy_str(out->telemetry.data_source, sizeof out->telemetry.data_source, mpack_node_map_cstr(root, "DataSource"));
            copy_str(out->telemetry.time_stamp, sizeof out->telemetry.time_stamp, mpack_node_map_cstr(root, "TimeStamp"));
            out->telemetry.param1 = (int)mpack_node_int(mpack_node_map_cstr(root, "Param1"));
            out->telemetry.param2 = (int)mpack_node_int(mpack_node_map_cstr(root, "Param2"));
            out->telemetry.problem_id = (int)mpack_node_int(mpack_node_map_cstr(root, "AssociatedProblemID"));
            out->telemetry.log_id = (int)mpack_node_int(mpack_node_map_cstr(root, "AssociatedLogID"));
            out->telemetry.was_processed = mpack_node_bool(mpack_node_map_cstr(root, "WasProcessed"));
            mpack_node_t arr = mpack_node_map_cstr(root, "Measurements");
            size_t n = mpack_node_array_length(arr); if (n > 100) n = 100;
            out->telemetry.meas_count = (int)n;
            for (size_t i = 0; i < n; i++) out->telemetry.measurements[i] = mpack_node_double(mpack_node_array_at(arr, i));
            break;
        }
        case TD_STRING_ARRAY: {
            mpack_node_t arr = mpack_node_map_cstr(root, "Items");
            size_t n = mpack_node_array_length(arr); if (n > 100) n = 100;
            out->string_array.count = (int)n;
            for (size_t i = 0; i < n; i++)
                if (copy_str(out->string_array.items[i], sizeof out->string_array.items[i], mpack_node_array_at(arr, i))) return -1;
            break;
        }
        case TD_EDI835: {
            if (copy_str(out->edi.payer_name, sizeof out->edi.payer_name, mpack_node_map_cstr(root, "PayerName"))) return -1;
            copy_str(out->edi.payee_name, sizeof out->edi.payee_name, mpack_node_map_cstr(root, "PayeeName"));
            copy_str(out->edi.payment_date, sizeof out->edi.payment_date, mpack_node_map_cstr(root, "PaymentDate"));
            copy_str(out->edi.tcn, sizeof out->edi.tcn, mpack_node_map_cstr(root, "TCN"));
            out->edi.total_actual = mpack_node_double(mpack_node_map_cstr(root, "TotalActual"));
            mpack_node_t claims = mpack_node_map_cstr(root, "Claims");
            size_t nc = mpack_node_array_length(claims); if (nc > 6) nc = 6;
            out->edi.claim_count = (int)nc;
            for (size_t c = 0; c < nc; c++) {
                mpack_node_t co = mpack_node_array_at(claims, c);
                claim_t *cl = &out->edi.claims[c];
                copy_str(cl->claim_id, sizeof cl->claim_id, mpack_node_map_cstr(co, "ClaimId"));
                copy_str(cl->patient_name, sizeof cl->patient_name, mpack_node_map_cstr(co, "PatientName"));
                cl->total_charge = mpack_node_double(mpack_node_map_cstr(co, "TotalCharge"));
                cl->payment = mpack_node_double(mpack_node_map_cstr(co, "Payment"));
                mpack_node_t lines = mpack_node_map_cstr(co, "Lines");
                size_t nl = mpack_node_array_length(lines); if (nl > 4) nl = 4;
                cl->line_count = (int)nl;
                for (size_t L = 0; L < nl; L++) {
                    mpack_node_t lo = mpack_node_array_at(lines, L);
                    copy_str(cl->lines[L].service_code, sizeof cl->lines[L].service_code, mpack_node_map_cstr(lo, "ServiceCode"));
                    cl->lines[L].charge = mpack_node_double(mpack_node_map_cstr(lo, "Charge"));
                    cl->lines[L].adjudicated = mpack_node_double(mpack_node_map_cstr(lo, "Adjudicated"));
                }
            }
            break;
        }

        case TD_OBJECT_GRAPH: {
            out->graph.root = (int)mpack_node_int(mpack_node_map_cstr(root, "root"));
            mpack_node_t nodes = mpack_node_map_cstr(root, "nodes");
            size_t nn = mpack_node_array_length(nodes); if (nn > GRAPH_MAX_NODES) nn = GRAPH_MAX_NODES;
            out->graph.node_count = (int)nn;
            for (size_t i = 0; i < nn; i++) {
                mpack_node_t no = mpack_node_array_at(nodes, i);
                graph_node_t *n = &out->graph.nodes[i];
                if (copy_str(n->name, sizeof n->name, mpack_node_map_cstr(no, "Name"))) return -1;
                n->parent = (int)mpack_node_int(mpack_node_map_cstr(no, "Parent"));
                n->related = (int)mpack_node_int(mpack_node_map_cstr(no, "Related"));
                mpack_node_t ch = mpack_node_map_cstr(no, "Children");
                size_t nc = mpack_node_array_length(ch); if (nc > GRAPH_MAX_CHILDREN) nc = GRAPH_MAX_CHILDREN;
                n->child_count = (int)nc;
                for (size_t c = 0; c < nc; c++) n->children[c] = (int)mpack_node_int(mpack_node_array_at(ch, c));
            }
            break;
        }
        default: return -1;
    }
    return mpack_node_error(root) == mpack_ok ? 0 : -1;
}

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    mpack_writer_t w;
    mpack_writer_init(&w, (char *)buf, cap);
    if (write_fx(&w, fx)) { mpack_writer_destroy(&w); return -1; }
    if (mpack_writer_error(&w) != mpack_ok) { mpack_writer_destroy(&w); return -1; }
    *ol = mpack_writer_buffer_used(&w);
    mpack_writer_destroy(&w);
    return 0;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    mpack_tree_t tree;
    mpack_tree_init_data(&tree, (const char *)buf, len);
    mpack_tree_parse(&tree);
    if (mpack_tree_error(&tree) != mpack_ok) { mpack_tree_destroy(&tree); return -1; }
    int r = read_fx(mpack_tree_root(&tree), out, kind);
    if (mpack_tree_error(&tree) != mpack_ok) r = -1;
    mpack_tree_destroy(&tree);
    return r;
}

void bench_register_mpack(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "mpack", "1.1", "binary", prep, ser, de, fidelity_fx);
}
