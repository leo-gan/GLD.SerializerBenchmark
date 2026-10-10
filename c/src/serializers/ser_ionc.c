#include "ser_common.h"
#include "v2_codec.h"
#include <ionc/ion.h>
#include <stdlib.h>
#include <string.h>

/* Amazon ion-c binary datagrams. Field names are the v2 fixture names.
 * Bytes: ion_writer_open_buffer. Stream: FILE* via ion_stream_open_file_out/in
 * (the stream does not fclose the harness FILE). compact_floats stays off so
 * f64 values stay Ion float64. The reader is forward-only, so one pass builds
 * a malloc tree and the v2 visitor walks that. Empty key "" is the current
 * scalar (bare array elements). */

static int prep(test_data_kind_t k, const test_fixture_t *fx) {
    (void)k;
    (void)fx;
    return 0;
}

static void ion_opts(ION_WRITER_OPTIONS *opt) {
    memset(opt, 0, sizeof *opt);
    opt->output_as_binary = 1;
}

enum { NK_BOOL = 1, NK_I64, NK_F64, NK_STR, NK_LIST, NK_STRUCT };

typedef struct ion_node {
    int kind;
    char *key;
    int b;
    int64_t i;
    double d;
    char *s;
    struct ion_node **kids;
    int n;
    int cap;
} ion_node;

static ion_node *node_new(int kind) {
    ion_node *n = calloc(1, sizeof *n);
    if (n) n->kind = kind;
    return n;
}

static void node_free(ion_node *n) {
    if (!n) return;
    free(n->key);
    free(n->s);
    for (int i = 0; i < n->n; i++) node_free(n->kids[i]);
    free(n->kids);
    free(n);
}

static int node_add(ion_node *parent, ion_node *ch) {
    if (parent->n == parent->cap) {
        int cap = parent->cap ? parent->cap * 2 : 4;
        ion_node **p = realloc(parent->kids, (size_t)cap * sizeof *p);
        if (!p) return -1;
        parent->kids = p;
        parent->cap = cap;
    }
    parent->kids[parent->n++] = ch;
    return 0;
}

static char *dup_bytes(const BYTE *p, int n) {
    if (n < 0) n = 0;
    char *out = malloc((size_t)n + 1);
    if (!out) return NULL;
    if (n && p) memcpy(out, p, (size_t)n);
    out[n] = 0;
    return out;
}

static char *dup_ion_str(const ION_STRING *s) {
    if (!s || !s->value) return dup_bytes(NULL, 0);
    return dup_bytes(s->value, s->length);
}

static ion_node *parse_value(hREADER rd, ION_TYPE t) {
    BOOL is_null = 0;
    if (ion_reader_is_null(rd, &is_null) != IERR_OK) return NULL;
    if (t == tid_STRUCT || t == tid_LIST || t == tid_SEXP) {
        ion_node *n = node_new(t == tid_STRUCT ? NK_STRUCT : NK_LIST);
        if (!n) return NULL;
        if (!is_null) {
            if (ion_reader_step_in(rd) != IERR_OK) {
                node_free(n);
                return NULL;
            }
            for (;;) {
                ION_TYPE ct;
                iERR e = ion_reader_next(rd, &ct);
                if (e != IERR_OK) {
                    node_free(n);
                    return NULL;
                }
                if (ct == tid_EOF) break;
                char *key = NULL;
                if (t == tid_STRUCT) {
                    ION_STRING name;
                    ION_STRING_INIT(&name);
                    if (ion_reader_get_field_name(rd, &name) != IERR_OK) {
                        node_free(n);
                        return NULL;
                    }
                    key = dup_ion_str(&name);
                    if (!key) {
                        node_free(n);
                        return NULL;
                    }
                }
                ion_node *ch = parse_value(rd, ct);
                if (!ch) {
                    free(key);
                    node_free(n);
                    return NULL;
                }
                ch->key = key;
                if (node_add(n, ch) != 0) {
                    node_free(ch);
                    node_free(n);
                    return NULL;
                }
            }
            if (ion_reader_step_out(rd) != IERR_OK) {
                node_free(n);
                return NULL;
            }
        }
        return n;
    }
    if (t == tid_BOOL) {
        BOOL v = 0;
        if (!is_null && ion_reader_read_bool(rd, &v) != IERR_OK) return NULL;
        ion_node *n = node_new(NK_BOOL);
        if (n) n->b = v ? 1 : 0;
        return n;
    }
    if (t == tid_INT) {
        int64_t v = 0;
        if (!is_null && ion_reader_read_int64(rd, &v) != IERR_OK) return NULL;
        ion_node *n = node_new(NK_I64);
        if (n) n->i = v;
        return n;
    }
    if (t == tid_FLOAT) {
        double v = 0;
        if (!is_null && ion_reader_read_double(rd, &v) != IERR_OK) return NULL;
        ion_node *n = node_new(NK_F64);
        if (n) n->d = v;
        return n;
    }
    if (t == tid_STRING || t == tid_SYMBOL) {
        ION_STRING s;
        ION_STRING_INIT(&s);
        if (!is_null && ion_reader_read_string(rd, &s) != IERR_OK) return NULL;
        ion_node *n = node_new(NK_STR);
        if (!n) return NULL;
        n->s = is_null ? dup_bytes(NULL, 0) : dup_ion_str(&s);
        if (!n->s) {
            node_free(n);
            return NULL;
        }
        return n;
    }
    return NULL;
}

static int slurp(hREADER rd, ion_node **out) {
    ION_TYPE t;
    iERR e = ion_reader_next(rd, &t);
    if (e != IERR_OK || t == tid_EOF) return -1;
    ion_node *root = parse_value(rd, t);
    if (!root) return -1;
    ION_TYPE t2;
    e = ion_reader_next(rd, &t2);
    if (e != IERR_OK || t2 != tid_EOF) {
        node_free(root);
        return -1;
    }
    *out = root;
    return 0;
}

typedef struct {
    hWRITER w;
} iw;

static int w_begin_map(void *ctx, int n_pairs) {
    (void)n_pairs;
    return ion_writer_start_container(((iw *)ctx)->w, tid_STRUCT) == IERR_OK ? 0 : -1;
}
static int w_end_map(void *ctx) {
    return ion_writer_finish_container(((iw *)ctx)->w) == IERR_OK ? 0 : -1;
}
static int w_begin_array(void *ctx, int n) {
    (void)n;
    return ion_writer_start_container(((iw *)ctx)->w, tid_LIST) == IERR_OK ? 0 : -1;
}
static int w_end_array(void *ctx) {
    return ion_writer_finish_container(((iw *)ctx)->w) == IERR_OK ? 0 : -1;
}
static int w_key(void *ctx, const char *k) {
    ION_STRING s;
    const char *t = k ? k : "";
    ion_string_assign_cstr(&s, (char *)t, (SIZE)strlen(t));
    return ion_writer_write_field_name(((iw *)ctx)->w, &s) == IERR_OK ? 0 : -1;
}
static int w_bool(void *ctx, int v) {
    return ion_writer_write_bool(((iw *)ctx)->w, v ? 1 : 0) == IERR_OK ? 0 : -1;
}
static int w_i64(void *ctx, int64_t v) {
    return ion_writer_write_int64(((iw *)ctx)->w, v) == IERR_OK ? 0 : -1;
}
static int w_f64(void *ctx, double v) {
    return ion_writer_write_double(((iw *)ctx)->w, v) == IERR_OK ? 0 : -1;
}
static int w_str(void *ctx, const char *s) {
    ION_STRING ion;
    const char *t = s ? s : "";
    ion_string_assign_cstr(&ion, (char *)t, (SIZE)strlen(t));
    return ion_writer_write_string(((iw *)ctx)->w, &ion) == IERR_OK ? 0 : -1;
}

static int write_fx(hWRITER w, const test_fixture_t *fx) {
    iw c = {.w = w};
    v2_writer_t wr = {
        .ctx = &c,
        .begin_map = w_begin_map,
        .end_map = w_end_map,
        .begin_array = w_begin_array,
        .end_array = w_end_array,
        .key = w_key,
        .put_bool = w_bool,
        .put_i64 = w_i64,
        .put_f64 = w_f64,
        .put_str = w_str,
    };
    return v2_write_fixture(fx, &wr);
}

static int finish_writer(hWRITER w, int rc, size_t *ol) {
    SIZE flushed = 0;
    if (rc == 0 && ion_writer_finish(w, &flushed) != IERR_OK) rc = -1;
    ion_writer_close(w);
    if (rc == 0) {
        if (flushed <= 0) rc = -1;
        else if (ol) *ol = (size_t)flushed;
    }
    return rc;
}

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    if (!buf || cap == 0 || cap > 0x7fffffff) return -1;
    ION_WRITER_OPTIONS opt;
    ion_opts(&opt);
    hWRITER w = NULL;
    if (ion_writer_open_buffer(&w, buf, (SIZE)cap, &opt) != IERR_OK) return -1;
    return finish_writer(w, write_fx(w, fx), ol);
}

static int ser_fp(const test_fixture_t *fx, FILE *f, size_t *ol) {
    ION_WRITER_OPTIONS opt;
    ion_opts(&opt);
    ION_STREAM *st = NULL;
    if (ion_stream_open_file_out(f, &st) != IERR_OK) return -1;
    hWRITER w = NULL;
    if (ion_writer_open(&w, st, &opt) != IERR_OK) {
        ion_stream_close(st);
        return -1;
    }
    /* ion_writer_open does not own the stream. close frees the stream object
     * and flushes; it does not fclose the harness FILE. */
    int rc = finish_writer(w, write_fx(w, fx), ol);
    ion_stream_close(st);
    return rc;
}

typedef struct {
    ion_node *stack[32];
    int sp;
} ir;

static ion_node *rtop(ir *c) { return c->stack[c->sp - 1]; }

static ion_node *lookup(ion_node *n, const char *key) {
    if (!n) return NULL;
    if (!key || !key[0]) {
        if (n->kind != NK_STRUCT && n->kind != NK_LIST) return n;
    }
    if (n->kind != NK_STRUCT) return NULL;
    const char *k = key ? key : "";
    for (int i = 0; i < n->n; i++) {
        if (n->kids[i]->key && strcmp(n->kids[i]->key, k) == 0) return n->kids[i];
    }
    return NULL;
}

static int r_get_bool(void *ctx, const char *key, int *out) {
    ion_node *n = lookup(rtop(ctx), key);
    if (!n || n->kind != NK_BOOL) return 1;
    *out = n->b;
    return 0;
}
static int r_get_i64(void *ctx, const char *key, int64_t *out) {
    ion_node *n = lookup(rtop(ctx), key);
    if (!n || n->kind != NK_I64) return 1;
    *out = n->i;
    return 0;
}
static int r_get_f64(void *ctx, const char *key, double *out) {
    ion_node *n = lookup(rtop(ctx), key);
    if (!n || n->kind != NK_F64) return 1;
    *out = n->d;
    return 0;
}
static int r_get_str(void *ctx, const char *key, char *buf, size_t buflen) {
    ion_node *n = lookup(rtop(ctx), key);
    if (!n) {
        if (buflen) buf[0] = 0;
        return 0;
    }
    if (n->kind != NK_STR || !n->s || buflen == 0) return -1;
    size_t nlen = strlen(n->s);
    if (nlen >= buflen) return -1;
    memcpy(buf, n->s, nlen + 1);
    return 0;
}
static int r_enter_object(void *ctx, const char *key) {
    ir *c = ctx;
    ion_node *n = lookup(rtop(c), key);
    if (!n || n->kind != NK_STRUCT) return 1;
    if (c->sp >= (int)(sizeof c->stack / sizeof c->stack[0])) return -1;
    c->stack[c->sp++] = n;
    return 0;
}
static int r_leave_object(void *ctx) {
    ir *c = ctx;
    if (c->sp <= 1) return -1;
    c->sp--;
    return 0;
}
static int r_enter_array(void *ctx, const char *key, int *len_out) {
    ir *c = ctx;
    ion_node *n = lookup(rtop(c), key);
    if (!n || n->kind != NK_LIST) return 1;
    if (c->sp >= (int)(sizeof c->stack / sizeof c->stack[0])) return -1;
    *len_out = n->n;
    c->stack[c->sp++] = n;
    return 0;
}
static int r_leave_array(void *ctx) {
    ir *c = ctx;
    if (c->sp <= 1) return -1;
    c->sp--;
    return 0;
}
static int r_enter_elem(void *ctx, int index) {
    ir *c = ctx;
    ion_node *n = rtop(c);
    if (!n || n->kind != NK_LIST || index < 0 || index >= n->n) return -1;
    if (c->sp >= (int)(sizeof c->stack / sizeof c->stack[0])) return -1;
    c->stack[c->sp++] = n->kids[index];
    return 0;
}
static int r_leave_elem(void *ctx) {
    ir *c = ctx;
    if (c->sp <= 1) return -1;
    c->sp--;
    return 0;
}

static int read_tree(ion_node *root, test_fixture_t *out, test_data_kind_t kind) {
    ir rc = {0};
    rc.stack[0] = root;
    rc.sp = 1;
    v2_reader_t r = {
        .ctx = &rc,
        .get_bool = r_get_bool,
        .get_i64 = r_get_i64,
        .get_f64 = r_get_f64,
        .get_str = r_get_str,
        .enter_object = r_enter_object,
        .leave_object = r_leave_object,
        .enter_array = r_enter_array,
        .leave_array = r_leave_array,
        .enter_elem = r_enter_elem,
        .leave_elem = r_leave_elem,
    };
    return v2_read_fixture(kind, out, &r);
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    if (!buf || len == 0 || len > 0x7fffffff) return -1;
    hREADER rd = NULL;
    if (ion_reader_open_buffer(&rd, (BYTE *)buf, (SIZE)len, NULL) != IERR_OK) return -1;
    ion_node *root = NULL;
    int rc = slurp(rd, &root);
    ion_reader_close(rd);
    if (rc != 0) return -1;
    rc = read_tree(root, out, kind);
    node_free(root);
    return rc;
}

static int de_fp(FILE *f, test_fixture_t *out, test_data_kind_t kind) {
    ION_STREAM *st = NULL;
    if (ion_stream_open_file_in(f, &st) != IERR_OK) return -1;
    hREADER rd = NULL;
    if (ion_reader_open(&rd, st, NULL) != IERR_OK) {
        ion_stream_close(st);
        return -1;
    }
    ion_node *root = NULL;
    int rc = slurp(rd, &root);
    ion_reader_close(rd);
    ion_stream_close(st);
    if (rc != 0) return -1;
    rc = read_tree(root, out, kind);
    node_free(root);
    return rc;
}

void bench_register_ionc(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "ion-c", "1.1.6", "binary", prep, ser, de, fidelity_fx);
    o[*c - 1].serialize_fp = ser_fp;
    o[*c - 1].deserialize_fp = de_fp;
}

/* gld-ffi-export */
int bench_ionc_prep(test_data_kind_t kind, const test_fixture_t *fx) {
    return prep(kind, fx);
}
int bench_ionc_ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    return ser(fx, buf, cap, ol);
}
int bench_ionc_de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    return de(buf, len, out, kind);
}
