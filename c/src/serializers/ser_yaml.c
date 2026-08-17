#include "ser_common.h"
#include "v2_codec.h"
#ifndef YAML_DECLARE_STATIC
#define YAML_DECLARE_STATIC
#endif
#include <yaml.h>
#include <stdlib.h>
#include <string.h>

/* libyaml — official C YAML 1.1 library. https://github.com/yaml/libyaml */

static int prep(test_data_kind_t k, const test_fixture_t *fx) {
    (void)k;
    (void)fx;
    return 0;
}

typedef struct {
    yaml_emitter_t emitter;
    int ok;
} yem;

static int emit(yem *c, yaml_event_t *ev) {
    if (!c->ok) {
        yaml_event_delete(ev);
        return -1;
    }
    if (!yaml_emitter_emit(&c->emitter, ev)) {
        c->ok = 0;
        return -1;
    }
    return 0;
}

static int e_scalar(yem *c, const char *s, yaml_scalar_style_t style) {
    yaml_event_t ev;
    const char *p = s ? s : "";
    if (!yaml_scalar_event_initialize(&ev, NULL, NULL, (yaml_char_t *)p, (int)strlen(p), 1, 1, style))
        return -1;
    return emit(c, &ev);
}

static int w_begin_map(void *ctx, int n) {
    (void)n;
    yaml_event_t ev;
    if (!yaml_mapping_start_event_initialize(&ev, NULL, NULL, 1, YAML_BLOCK_MAPPING_STYLE))
        return -1;
    return emit(ctx, &ev);
}
static int w_end_map(void *ctx) {
    yaml_event_t ev;
    if (!yaml_mapping_end_event_initialize(&ev)) return -1;
    return emit(ctx, &ev);
}
static int w_begin_array(void *ctx, int n) {
    (void)n;
    yaml_event_t ev;
    if (!yaml_sequence_start_event_initialize(&ev, NULL, NULL, 1, YAML_BLOCK_SEQUENCE_STYLE))
        return -1;
    return emit(ctx, &ev);
}
static int w_end_array(void *ctx) {
    yaml_event_t ev;
    if (!yaml_sequence_end_event_initialize(&ev)) return -1;
    return emit(ctx, &ev);
}
static int w_key(void *ctx, const char *k) { return e_scalar(ctx, k, YAML_PLAIN_SCALAR_STYLE); }
static int w_bool(void *ctx, int v) { return e_scalar(ctx, v ? "true" : "false", YAML_PLAIN_SCALAR_STYLE); }
static int w_i64(void *ctx, int64_t v) {
    char b[32];
    snprintf(b, sizeof b, "%lld", (long long)v);
    return e_scalar(ctx, b, YAML_PLAIN_SCALAR_STYLE);
}
static int w_f64(void *ctx, double v) {
    char b[64];
    snprintf(b, sizeof b, "%.17g", v);
    return e_scalar(ctx, b, YAML_PLAIN_SCALAR_STYLE);
}
static int w_str(void *ctx, const char *s) { return e_scalar(ctx, s, YAML_DOUBLE_QUOTED_SCALAR_STYLE); }

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    yem c;
    memset(&c, 0, sizeof c);
    c.ok = 1;
    if (!yaml_emitter_initialize(&c.emitter)) return -1;
    size_t written = 0;
    yaml_emitter_set_output_string(&c.emitter, buf, cap, &written);
    yaml_event_t ev;
    if (!yaml_stream_start_event_initialize(&ev, YAML_UTF8_ENCODING) || emit(&c, &ev) != 0) {
        yaml_emitter_delete(&c.emitter);
        return -1;
    }
    if (!yaml_document_start_event_initialize(&ev, NULL, NULL, NULL, 1) || emit(&c, &ev) != 0) {
        yaml_emitter_delete(&c.emitter);
        return -1;
    }
    v2_writer_t w = {
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
    int rc = v2_write_fixture(fx, &w);
    if (rc == 0) {
        if (!yaml_document_end_event_initialize(&ev, 1) || emit(&c, &ev) != 0) rc = -1;
    }
    if (rc == 0) {
        if (!yaml_stream_end_event_initialize(&ev) || emit(&c, &ev) != 0) rc = -1;
    }
    if (rc == 0 && !yaml_emitter_flush(&c.emitter)) rc = -1;
    yaml_emitter_delete(&c.emitter);
    if (rc != 0 || !c.ok) return -1;
    *ol = written;
    return 0;
}

/* Parse to a yaml_document and walk nodes for v2_reader. */
typedef struct {
    yaml_document_t *doc;
    yaml_node_t *stack[32];
    int sp;
} yrd;

static yaml_node_t *ytop(yrd *c) { return c->stack[c->sp - 1]; }

static yaml_node_t *yget(yrd *c, const char *key) {
    if (!key || !key[0]) return ytop(c);
    yaml_node_t *n = ytop(c);
    if (!n || n->type != YAML_MAPPING_NODE) return NULL;
    yaml_node_pair_t *p;
    for (p = n->data.mapping.pairs.start; p < n->data.mapping.pairs.top; p++) {
        yaml_node_t *k = yaml_document_get_node(c->doc, p->key);
        if (k && k->type == YAML_SCALAR_NODE && strcmp((char *)k->data.scalar.value, key) == 0)
            return yaml_document_get_node(c->doc, p->value);
    }
    return NULL;
}

static int r_get_bool(void *ctx, const char *key, int *out) {
    yaml_node_t *n = yget(ctx, key);
    if (!n || n->type != YAML_SCALAR_NODE) return 1;
    *out = strcmp((char *)n->data.scalar.value, "true") == 0;
    return 0;
}
static int r_get_i64(void *ctx, const char *key, int64_t *out) {
    yaml_node_t *n = yget(ctx, key);
    if (!n || n->type != YAML_SCALAR_NODE) return 1;
    *out = strtoll((char *)n->data.scalar.value, NULL, 10);
    return 0;
}
static int r_get_f64(void *ctx, const char *key, double *out) {
    yaml_node_t *n = yget(ctx, key);
    if (!n || n->type != YAML_SCALAR_NODE) return 1;
    *out = strtod((char *)n->data.scalar.value, NULL);
    return 0;
}
static int r_get_str(void *ctx, const char *key, char *buf, size_t buflen) {
    yaml_node_t *n = yget(ctx, key);
    if (!n || n->type != YAML_SCALAR_NODE) {
        if (buflen) buf[0] = 0;
        return 0;
    }
    snprintf(buf, buflen, "%s", (char *)n->data.scalar.value);
    return 0;
}
static int r_enter_object(void *ctx, const char *key) {
    yrd *c = ctx;
    yaml_node_t *n = yget(c, key);
    if (!n || n->type != YAML_MAPPING_NODE) return 1;
    c->stack[c->sp++] = n;
    return 0;
}
static int r_leave_object(void *ctx) {
    yrd *c = ctx;
    if (c->sp <= 1) return -1;
    c->sp--;
    return 0;
}
static int r_enter_array(void *ctx, const char *key, int *len_out) {
    yrd *c = ctx;
    yaml_node_t *n = yget(c, key);
    if (!n || n->type != YAML_SEQUENCE_NODE) return 1;
    *len_out = (int)(n->data.sequence.items.top - n->data.sequence.items.start);
    c->stack[c->sp++] = n;
    return 0;
}
static int r_leave_array(void *ctx) { return r_leave_object(ctx); }
static int r_enter_elem(void *ctx, int index) {
    yrd *c = ctx;
    yaml_node_t *n = ytop(c);
    if (!n || n->type != YAML_SEQUENCE_NODE) return -1;
    int len = (int)(n->data.sequence.items.top - n->data.sequence.items.start);
    if (index < 0 || index >= len) return -1;
    yaml_node_item_t item = n->data.sequence.items.start[index];
    c->stack[c->sp++] = yaml_document_get_node(c->doc, item);
    return 0;
}
static int r_leave_elem(void *ctx) { return r_leave_object(ctx); }

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    yaml_parser_t parser;
    yaml_document_t doc;
    if (!yaml_parser_initialize(&parser)) return -1;
    yaml_parser_set_input_string(&parser, buf, len);
    if (!yaml_parser_load(&parser, &doc)) {
        yaml_parser_delete(&parser);
        return -1;
    }
    yaml_parser_delete(&parser);
    yaml_node_t *root = yaml_document_get_root_node(&doc);
    if (!root) {
        yaml_document_delete(&doc);
        return -1;
    }
    yrd c = {.doc = &doc, .sp = 1};
    c.stack[0] = root;
    v2_reader_t r = {
        .ctx = &c,
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
    int err = v2_read_fixture(kind, out, &r);
    yaml_document_delete(&doc);
    return err;
}

void bench_register_yaml(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "libyaml", "0.2.5", "human", prep, ser, de, fidelity_fx);
}
