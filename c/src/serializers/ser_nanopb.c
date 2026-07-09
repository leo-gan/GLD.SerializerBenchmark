#include "ser_common.h"
#include "pb.h"
#include "pb_encode.h"
#include "pb_decode.h"

/*
 * Optimal nanopb usage without .proto codegen:
 *  - pb_ostream_from_buffer / pb_istream_from_buffer
 *  - pb_encode_tag + pb_encode_varint / pb_encode_string / pb_encode_fixed64
 *    (public low-level API used when hand-writing encoders)
 * Previous wrapper called a hand-rolled wire codec and only linked nanopb symbols unused.
 */

static int prep(test_data_kind_t k, const test_fixture_t *fx) { (void)k;(void)fx; return 0; }

static bool enc_varint_field(pb_ostream_t *s, uint32_t field, uint64_t v) {
    return pb_encode_tag(s, PB_WT_VARINT, field) && pb_encode_varint(s, v);
}
static bool enc_str_field(pb_ostream_t *s, uint32_t field, const char *str) {
    size_t n = strlen(str);
    return pb_encode_tag(s, PB_WT_STRING, field) && pb_encode_string(s, (const pb_byte_t *)str, n);
}
static bool enc_bytes_field(pb_ostream_t *s, uint32_t field, const void *p, size_t n) {
    return pb_encode_tag(s, PB_WT_STRING, field) && pb_encode_string(s, (const pb_byte_t *)p, n);
}
static bool enc_f64_field(pb_ostream_t *s, uint32_t field, double v) {
    return pb_encode_tag(s, PB_WT_64BIT, field) && pb_encode_fixed64(s, &v);
}

static bool encode_fx(pb_ostream_t *s, const test_fixture_t *fx) {
    if (!enc_varint_field(s, 1, (uint64_t)(uint32_t)fx->kind)) return false;
    switch (fx->kind) {
        case TD_INTEGER:
            return enc_varint_field(s, 2, (uint64_t)(uint32_t)fx->integer_val);
        case TD_SIMPLE:
            return enc_varint_field(s, 10, (uint64_t)(uint32_t)fx->simple.id)
                && enc_str_field(s, 11, fx->simple.name)
                && enc_str_field(s, 12, fx->simple.timestamp)
                && enc_varint_field(s, 13, fx->simple.is_active ? 1 : 0);
        case TD_PERSON: {
            const person_t *p = &fx->person;
            if (!enc_str_field(s, 20, p->first_name)) return false;
            if (!enc_str_field(s, 21, p->last_name)) return false;
            if (!enc_varint_field(s, 22, (uint64_t)(uint32_t)p->age)) return false;
            if (!enc_varint_field(s, 23, (uint64_t)(uint32_t)p->gender)) return false;
            if (!enc_str_field(s, 25, p->passport_number)) return false;
            if (!enc_str_field(s, 26, p->passport_authority)) return false;
            int n = p->police_count; if (n < 0) n = 0; if (n > 8) n = 8;
            for (int i = 0; i < n; i++) {
                if (!enc_varint_field(s, 27, (uint64_t)(uint32_t)p->police_ids[i])) return false;
                if (!enc_str_field(s, 28, p->police_codes[i])) return false;
            }
            return true;
        }
        case TD_TELEMETRY: {
            const telemetry_t *t = &fx->telemetry;
            if (!enc_str_field(s, 30, t->id)) return false;
            if (!enc_str_field(s, 33, t->data_source)) return false;
            if (!enc_str_field(s, 34, t->time_stamp)) return false;
            if (!enc_varint_field(s, 31, (uint64_t)(uint32_t)t->param1)) return false;
            if (!enc_varint_field(s, 35, (uint64_t)(uint32_t)t->param2)) return false;
            int n = t->meas_count; if (n < 0) n = 0; if (n > 100) n = 100;
            if (!enc_bytes_field(s, 36, t->measurements, (size_t)n * 8)) return false;
            if (!enc_varint_field(s, 37, (uint64_t)(uint32_t)t->problem_id)) return false;
            if (!enc_varint_field(s, 38, (uint64_t)(uint32_t)t->log_id)) return false;
            return enc_varint_field(s, 39, t->was_processed ? 1 : 0);
        }
        case TD_STRING_ARRAY: {
            int n = fx->string_array.count; if (n < 0) n = 0; if (n > 100) n = 100;
            if (!enc_varint_field(s, 40, (uint64_t)(uint32_t)n)) return false;
            for (int i = 0; i < n; i++)
                if (!enc_str_field(s, 41, fx->string_array.items[i])) return false;
            return true;
        }
        case TD_EDI835: {
            const edi835_t *e = &fx->edi;
            if (!enc_str_field(s, 50, e->payer_name)) return false;
            if (!enc_str_field(s, 51, e->payee_name)) return false;
            if (!enc_str_field(s, 54, e->payment_date)) return false;
            if (!enc_f64_field(s, 53, e->total_actual)) return false;
            if (!enc_str_field(s, 55, e->tcn)) return false;
            int nc = e->claim_count; if (nc < 0) nc = 0; if (nc > 6) nc = 6;
            if (!enc_varint_field(s, 52, (uint64_t)(uint32_t)nc)) return false;
            for (int c = 0; c < nc; c++) {
                const claim_t *cl = &e->claims[c];
                /* Submessage as length-delimited field 60 */
                pb_ostream_t sizing = PB_OSTREAM_SIZING;
                /* encode claim into temp */
                uint8_t cbuf[512];
                pb_ostream_t cs = pb_ostream_from_buffer(cbuf, sizeof cbuf);
                if (!enc_str_field(&cs, 1, cl->claim_id)) return false;
                if (!enc_str_field(&cs, 2, cl->patient_name)) return false;
                if (!enc_f64_field(&cs, 3, cl->total_charge)) return false;
                if (!enc_f64_field(&cs, 4, cl->payment)) return false;
                int nl = cl->line_count; if (nl < 0) nl = 0; if (nl > 4) nl = 4;
                for (int L = 0; L < nl; L++) {
                    uint8_t lbuf[128];
                    pb_ostream_t ls = pb_ostream_from_buffer(lbuf, sizeof lbuf);
                    if (!enc_str_field(&ls, 1, cl->lines[L].service_code)) return false;
                    if (!enc_f64_field(&ls, 2, cl->lines[L].charge)) return false;
                    if (!enc_f64_field(&ls, 3, cl->lines[L].adjudicated)) return false;
                    if (!enc_bytes_field(&cs, 5, lbuf, ls.bytes_written)) return false;
                }
                (void)sizing;
                if (!enc_bytes_field(s, 60, cbuf, cs.bytes_written)) return false;
            }
            return true;
        }
        case TD_OBJECT_GRAPH: {
            /* Flat node table with int edges (same field ids as fixture_pb_full). */
            const object_graph_t *g = &fx->graph;
            if (!enc_varint_field(s, 70, (uint64_t)(uint32_t)(int32_t)g->root)) return false;
            int nn = g->node_count; if (nn < 0) nn = 0; if (nn > GRAPH_MAX_NODES) nn = GRAPH_MAX_NODES;
            if (!enc_varint_field(s, 71, (uint64_t)(uint32_t)nn)) return false;
            for (int i = 0; i < nn; i++) {
                const graph_node_t *n = &g->nodes[i];
                uint8_t cbuf[256];
                pb_ostream_t cs = pb_ostream_from_buffer(cbuf, sizeof cbuf);
                if (!enc_str_field(&cs, 1, n->name)) return false;
                if (!enc_varint_field(&cs, 2, (uint64_t)(uint32_t)(int32_t)n->parent)) return false;
                if (!enc_varint_field(&cs, 3, (uint64_t)(uint32_t)(int32_t)n->related)) return false;
                int nc = n->child_count; if (nc < 0) nc = 0; if (nc > GRAPH_MAX_CHILDREN) nc = GRAPH_MAX_CHILDREN;
                for (int c = 0; c < nc; c++)
                    if (!enc_varint_field(&cs, 4, (uint64_t)(uint32_t)(int32_t)n->children[c])) return false;
                if (!enc_bytes_field(s, 72, cbuf, cs.bytes_written)) return false;
            }
            return true;
        }
        default: return false;
    }
}

/* Decode: use pb_decode_tag loop (nanopb stream decode API) */
static bool dec_varint(pb_istream_t *s, uint64_t *v) { return pb_decode_varint(s, v); }

static int decode_fx(pb_istream_t *stream, test_fixture_t *out, test_data_kind_t kind) {
    memset(out, 0, sizeof *out);
    out->kind = kind;
    out->name = test_data_name(kind);
    int got_kind = -1;
    while (stream->bytes_left) {
        uint32_t tag;
        pb_wire_type_t wt;
        {
            bool eof = false;
            if (!pb_decode_tag(stream, &wt, &tag, &eof)) {
                if (eof || stream->bytes_left == 0) break;
                return -1;
            }
        }
        if (tag == 1 && wt == PB_WT_VARINT) {
            uint64_t v; if (!dec_varint(stream, &v)) return -1; got_kind = (int)v;
            continue;
        }
        switch (kind) {
            case TD_INTEGER:
                if (tag == 2 && wt == PB_WT_VARINT) { uint64_t v; if (!dec_varint(stream, &v)) return -1; out->integer_val = (int)v; }
                else if (!pb_skip_field(stream, wt)) return -1;
                break;
            case TD_SIMPLE:
                if (tag == 10 && wt == PB_WT_VARINT) { uint64_t v; if (!dec_varint(stream, &v)) return -1; out->simple.id = (int)v; }
                else if (tag == 11 && wt == PB_WT_STRING) {
                    pb_istream_t sub; if (!pb_make_string_substream(stream, &sub)) return -1;
                    size_t n = sub.bytes_left; if (n >= sizeof out->simple.name) n = sizeof out->simple.name - 1;
                    if (!pb_read(&sub, (pb_byte_t *)out->simple.name, n)) return -1;
                    out->simple.name[n] = 0;
                    if (!pb_close_string_substream(stream, &sub)) return -1;
                } else if (tag == 12 && wt == PB_WT_STRING) {
                    pb_istream_t sub; if (!pb_make_string_substream(stream, &sub)) return -1;
                    size_t n = sub.bytes_left; if (n >= sizeof out->simple.timestamp) n = sizeof out->simple.timestamp - 1;
                    if (!pb_read(&sub, (pb_byte_t *)out->simple.timestamp, n)) return -1;
                    out->simple.timestamp[n] = 0;
                    if (!pb_close_string_substream(stream, &sub)) return -1;
                } else if (tag == 13 && wt == PB_WT_VARINT) {
                    uint64_t v; if (!dec_varint(stream, &v)) return -1; out->simple.is_active = v != 0;
                } else if (!pb_skip_field(stream, wt)) return -1;
                break;
            case TD_PERSON:
                if (tag == 20 && wt == PB_WT_STRING) {
                    pb_istream_t sub; if (!pb_make_string_substream(stream, &sub)) return -1;
                    size_t n = sub.bytes_left; if (n >= sizeof out->person.first_name) n = sizeof out->person.first_name - 1;
                    if (!pb_read(&sub, (pb_byte_t *)out->person.first_name, n)) return -1;
                    out->person.first_name[n] = 0;
                    if (!pb_close_string_substream(stream, &sub)) return -1;
                } else if (tag == 21 && wt == PB_WT_STRING) {
                    pb_istream_t sub; if (!pb_make_string_substream(stream, &sub)) return -1;
                    size_t n = sub.bytes_left; if (n >= sizeof out->person.last_name) n = sizeof out->person.last_name - 1;
                    if (!pb_read(&sub, (pb_byte_t *)out->person.last_name, n)) return -1;
                    out->person.last_name[n] = 0;
                    if (!pb_close_string_substream(stream, &sub)) return -1;
                } else if (tag == 22 && wt == PB_WT_VARINT) { uint64_t v; if (!dec_varint(stream, &v)) return -1; out->person.age = (int)v; }
                else if (tag == 23 && wt == PB_WT_VARINT) { uint64_t v; if (!dec_varint(stream, &v)) return -1; out->person.gender = (int)v; }
                else if (tag == 25 && wt == PB_WT_STRING) {
                    pb_istream_t sub; if (!pb_make_string_substream(stream, &sub)) return -1;
                    size_t n = sub.bytes_left; if (n >= sizeof out->person.passport_number) n = sizeof out->person.passport_number - 1;
                    if (!pb_read(&sub, (pb_byte_t *)out->person.passport_number, n)) return -1;
                    out->person.passport_number[n] = 0;
                    if (!pb_close_string_substream(stream, &sub)) return -1;
                } else if (tag == 26 && wt == PB_WT_STRING) {
                    pb_istream_t sub; if (!pb_make_string_substream(stream, &sub)) return -1;
                    size_t n = sub.bytes_left; if (n >= sizeof out->person.passport_authority) n = sizeof out->person.passport_authority - 1;
                    if (!pb_read(&sub, (pb_byte_t *)out->person.passport_authority, n)) return -1;
                    out->person.passport_authority[n] = 0;
                    if (!pb_close_string_substream(stream, &sub)) return -1;
                } else if (tag == 27 && wt == PB_WT_VARINT) {
                    if (out->person.police_count >= 8) { if (!pb_skip_field(stream, wt)) return -1; }
                    else { uint64_t v; if (!dec_varint(stream, &v)) return -1; out->person.police_ids[out->person.police_count++] = (int)v; }
                } else if (tag == 28 && wt == PB_WT_STRING) {
                    int i = out->person.police_count > 0 ? out->person.police_count - 1 : 0;
                    pb_istream_t sub; if (!pb_make_string_substream(stream, &sub)) return -1;
                    size_t n = sub.bytes_left; if (n >= sizeof out->person.police_codes[i]) n = sizeof out->person.police_codes[i] - 1;
                    if (!pb_read(&sub, (pb_byte_t *)out->person.police_codes[i], n)) return -1;
                    out->person.police_codes[i][n] = 0;
                    if (!pb_close_string_substream(stream, &sub)) return -1;
                } else if (!pb_skip_field(stream, wt)) return -1;
                break;
            case TD_TELEMETRY:
                if (tag == 30 && wt == PB_WT_STRING) {
                    pb_istream_t sub; if (!pb_make_string_substream(stream, &sub)) return -1;
                    size_t n = sub.bytes_left; if (n >= sizeof out->telemetry.id) n = sizeof out->telemetry.id - 1;
                    if (!pb_read(&sub, (pb_byte_t *)out->telemetry.id, n)) return -1;
                    out->telemetry.id[n] = 0;
                    if (!pb_close_string_substream(stream, &sub)) return -1;
                } else if (tag == 33 && wt == PB_WT_STRING) {
                    pb_istream_t sub; if (!pb_make_string_substream(stream, &sub)) return -1;
                    size_t n = sub.bytes_left; if (n >= sizeof out->telemetry.data_source) n = sizeof out->telemetry.data_source - 1;
                    if (!pb_read(&sub, (pb_byte_t *)out->telemetry.data_source, n)) return -1;
                    out->telemetry.data_source[n] = 0;
                    if (!pb_close_string_substream(stream, &sub)) return -1;
                } else if (tag == 34 && wt == PB_WT_STRING) {
                    pb_istream_t sub; if (!pb_make_string_substream(stream, &sub)) return -1;
                    size_t n = sub.bytes_left; if (n >= sizeof out->telemetry.time_stamp) n = sizeof out->telemetry.time_stamp - 1;
                    if (!pb_read(&sub, (pb_byte_t *)out->telemetry.time_stamp, n)) return -1;
                    out->telemetry.time_stamp[n] = 0;
                    if (!pb_close_string_substream(stream, &sub)) return -1;
                } else if (tag == 31 && wt == PB_WT_VARINT) { uint64_t v; if (!dec_varint(stream, &v)) return -1; out->telemetry.param1 = (int)v; }
                else if (tag == 35 && wt == PB_WT_VARINT) { uint64_t v; if (!dec_varint(stream, &v)) return -1; out->telemetry.param2 = (int)v; }
                else if (tag == 36 && wt == PB_WT_STRING) {
                    pb_istream_t sub; if (!pb_make_string_substream(stream, &sub)) return -1;
                    size_t n = sub.bytes_left / 8; if (n > 100) n = 100;
                    out->telemetry.meas_count = (int)n;
                    if (!pb_read(&sub, (pb_byte_t *)out->telemetry.measurements, n * 8)) return -1;
                    if (!pb_close_string_substream(stream, &sub)) return -1;
                } else if (tag == 37 && wt == PB_WT_VARINT) { uint64_t v; if (!dec_varint(stream, &v)) return -1; out->telemetry.problem_id = (int)v; }
                else if (tag == 38 && wt == PB_WT_VARINT) { uint64_t v; if (!dec_varint(stream, &v)) return -1; out->telemetry.log_id = (int)v; }
                else if (tag == 39 && wt == PB_WT_VARINT) { uint64_t v; if (!dec_varint(stream, &v)) return -1; out->telemetry.was_processed = v != 0; }
                else if (!pb_skip_field(stream, wt)) return -1;
                break;
            case TD_STRING_ARRAY:
                if (tag == 40 && wt == PB_WT_VARINT) { uint64_t v; if (!dec_varint(stream, &v)) return -1; /* count advisory */ (void)v; }
                else if (tag == 41 && wt == PB_WT_STRING) {
                    if (out->string_array.count >= 100) { if (!pb_skip_field(stream, wt)) return -1; break; }
                    int i = out->string_array.count++;
                    pb_istream_t sub; if (!pb_make_string_substream(stream, &sub)) return -1;
                    size_t n = sub.bytes_left; if (n >= sizeof out->string_array.items[i]) n = sizeof out->string_array.items[i] - 1;
                    if (!pb_read(&sub, (pb_byte_t *)out->string_array.items[i], n)) return -1;
                    out->string_array.items[i][n] = 0;
                    if (!pb_close_string_substream(stream, &sub)) return -1;
                } else if (!pb_skip_field(stream, wt)) return -1;
                break;
            case TD_EDI835:
                if (tag == 50 && wt == PB_WT_STRING) {
                    pb_istream_t sub; if (!pb_make_string_substream(stream, &sub)) return -1;
                    size_t n = sub.bytes_left; if (n >= sizeof out->edi.payer_name) n = sizeof out->edi.payer_name - 1;
                    if (!pb_read(&sub, (pb_byte_t *)out->edi.payer_name, n)) return -1;
                    out->edi.payer_name[n] = 0;
                    if (!pb_close_string_substream(stream, &sub)) return -1;
                } else if (tag == 51 && wt == PB_WT_STRING) {
                    pb_istream_t sub; if (!pb_make_string_substream(stream, &sub)) return -1;
                    size_t n = sub.bytes_left; if (n >= sizeof out->edi.payee_name) n = sizeof out->edi.payee_name - 1;
                    if (!pb_read(&sub, (pb_byte_t *)out->edi.payee_name, n)) return -1;
                    out->edi.payee_name[n] = 0;
                    if (!pb_close_string_substream(stream, &sub)) return -1;
                } else if (tag == 54 && wt == PB_WT_STRING) {
                    pb_istream_t sub; if (!pb_make_string_substream(stream, &sub)) return -1;
                    size_t n = sub.bytes_left; if (n >= sizeof out->edi.payment_date) n = sizeof out->edi.payment_date - 1;
                    if (!pb_read(&sub, (pb_byte_t *)out->edi.payment_date, n)) return -1;
                    out->edi.payment_date[n] = 0;
                    if (!pb_close_string_substream(stream, &sub)) return -1;
                } else if (tag == 55 && wt == PB_WT_STRING) {
                    pb_istream_t sub; if (!pb_make_string_substream(stream, &sub)) return -1;
                    size_t n = sub.bytes_left; if (n >= sizeof out->edi.tcn) n = sizeof out->edi.tcn - 1;
                    if (!pb_read(&sub, (pb_byte_t *)out->edi.tcn, n)) return -1;
                    out->edi.tcn[n] = 0;
                    if (!pb_close_string_substream(stream, &sub)) return -1;
                } else if (tag == 53 && wt == PB_WT_64BIT) {
                    if (!pb_decode_fixed64(stream, &out->edi.total_actual)) return -1;
                } else if (tag == 52 && wt == PB_WT_VARINT) {
                    uint64_t v; if (!dec_varint(stream, &v)) return -1; /* advisory */ (void)v;
                } else if (tag == 60 && wt == PB_WT_STRING) {
                    if (out->edi.claim_count >= 6) { if (!pb_skip_field(stream, wt)) return -1; break; }
                    claim_t *cl = &out->edi.claims[out->edi.claim_count++];
                    pb_istream_t sub; if (!pb_make_string_substream(stream, &sub)) return -1;
                    while (sub.bytes_left) {
                        uint32_t t2; pb_wire_type_t w2;
                        { bool eof2 = false; if (!pb_decode_tag(&sub, &w2, &t2, &eof2)) break; }
                        if (t2 == 1 && w2 == PB_WT_STRING) {
                            pb_istream_t ss; if (!pb_make_string_substream(&sub, &ss)) return -1;
                            size_t n = ss.bytes_left; if (n >= sizeof cl->claim_id) n = sizeof cl->claim_id - 1;
                            if (!pb_read(&ss, (pb_byte_t *)cl->claim_id, n)) return -1; cl->claim_id[n]=0;
                            if (!pb_close_string_substream(&sub, &ss)) return -1;
                        } else if (t2 == 2 && w2 == PB_WT_STRING) {
                            pb_istream_t ss; if (!pb_make_string_substream(&sub, &ss)) return -1;
                            size_t n = ss.bytes_left; if (n >= sizeof cl->patient_name) n = sizeof cl->patient_name - 1;
                            if (!pb_read(&ss, (pb_byte_t *)cl->patient_name, n)) return -1; cl->patient_name[n]=0;
                            if (!pb_close_string_substream(&sub, &ss)) return -1;
                        } else if (t2 == 3 && w2 == PB_WT_64BIT) {
                            if (!pb_decode_fixed64(&sub, &cl->total_charge)) return -1;
                        } else if (t2 == 4 && w2 == PB_WT_64BIT) {
                            if (!pb_decode_fixed64(&sub, &cl->payment)) return -1;
                        } else if (t2 == 5 && w2 == PB_WT_STRING) {
                            if (cl->line_count >= 4) { if (!pb_skip_field(&sub, w2)) return -1; continue; }
                            service_line_t *ln = &cl->lines[cl->line_count++];
                            pb_istream_t ls; if (!pb_make_string_substream(&sub, &ls)) return -1;
                            while (ls.bytes_left) {
                                uint32_t t3; pb_wire_type_t w3;
                                { bool eof3 = false; if (!pb_decode_tag(&ls, &w3, &t3, &eof3)) break; }
                                if (t3 == 1 && w3 == PB_WT_STRING) {
                                    pb_istream_t ss; if (!pb_make_string_substream(&ls, &ss)) return -1;
                                    size_t n = ss.bytes_left; if (n >= sizeof ln->service_code) n = sizeof ln->service_code - 1;
                                    if (!pb_read(&ss, (pb_byte_t *)ln->service_code, n)) return -1; ln->service_code[n]=0;
                                    if (!pb_close_string_substream(&ls, &ss)) return -1;
                                } else if (t3 == 2 && w3 == PB_WT_64BIT) {
                                    if (!pb_decode_fixed64(&ls, &ln->charge)) return -1;
                                } else if (t3 == 3 && w3 == PB_WT_64BIT) {
                                    if (!pb_decode_fixed64(&ls, &ln->adjudicated)) return -1;
                                } else if (!pb_skip_field(&ls, w3)) return -1;
                            }
                            if (!pb_close_string_substream(&sub, &ls)) return -1;
                        } else if (!pb_skip_field(&sub, w2)) return -1;
                    }
                    if (!pb_close_string_substream(stream, &sub)) return -1;
                } else if (!pb_skip_field(stream, wt)) return -1;
                break;
            case TD_OBJECT_GRAPH:
                if (tag == 70 && wt == PB_WT_VARINT) {
                    uint64_t v; if (!dec_varint(stream, &v)) return -1;
                    out->graph.root = (int)(int32_t)(uint32_t)v;
                } else if (tag == 71 && wt == PB_WT_VARINT) {
                    uint64_t v; if (!dec_varint(stream, &v)) return -1; (void)v;
                } else if (tag == 72 && wt == PB_WT_STRING) {
                    if (out->graph.node_count >= GRAPH_MAX_NODES) {
                        if (!pb_skip_field(stream, wt)) return -1;
                        break;
                    }
                    graph_node_t *n = &out->graph.nodes[out->graph.node_count++];
                    pb_istream_t sub;
                    if (!pb_make_string_substream(stream, &sub)) return -1;
                    int kids = 0;
                    while (sub.bytes_left) {
                        uint32_t t2; pb_wire_type_t w2; bool eof2 = false;
                        if (!pb_decode_tag(&sub, &w2, &t2, &eof2)) break;
                        if (t2 == 1 && w2 == PB_WT_STRING) {
                            pb_istream_t ss;
                            if (!pb_make_string_substream(&sub, &ss)) return -1;
                            size_t nlen = ss.bytes_left;
                            if (nlen >= sizeof n->name) nlen = sizeof n->name - 1;
                            if (!pb_read(&ss, (pb_byte_t *)n->name, nlen)) return -1;
                            n->name[nlen] = 0;
                            if (!pb_close_string_substream(&sub, &ss)) return -1;
                        } else if (t2 == 2 && w2 == PB_WT_VARINT) {
                            uint64_t v; if (!dec_varint(&sub, &v)) return -1;
                            n->parent = (int)(int32_t)(uint32_t)v;
                        } else if (t2 == 3 && w2 == PB_WT_VARINT) {
                            uint64_t v; if (!dec_varint(&sub, &v)) return -1;
                            n->related = (int)(int32_t)(uint32_t)v;
                        } else if (t2 == 4 && w2 == PB_WT_VARINT) {
                            uint64_t v; if (!dec_varint(&sub, &v)) return -1;
                            if (kids < GRAPH_MAX_CHILDREN)
                                n->children[kids++] = (int)(int32_t)(uint32_t)v;
                        } else if (!pb_skip_field(&sub, w2)) {
                            return -1;
                        }
                    }
                    n->child_count = kids;
                    if (!pb_close_string_substream(stream, &sub)) return -1;
                } else if (!pb_skip_field(stream, wt)) {
                    return -1;
                }
                break;
            default:
                if (!pb_skip_field(stream, wt)) return -1;
                break;
        }
    }
    return got_kind == (int)kind ? 0 : -1;
}

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    pb_ostream_t stream = pb_ostream_from_buffer(buf, cap);
    if (!encode_fx(&stream, fx)) return -1;
    *ol = stream.bytes_written;
    return 0;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    pb_istream_t stream = pb_istream_from_buffer(buf, len);
    return decode_fx(&stream, out, kind);
}

void bench_register_nanopb(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "nanopb", "0.4.9", "schema", prep, ser, de, fidelity_fx);
}
