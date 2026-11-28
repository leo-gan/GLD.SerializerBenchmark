#ifndef GO_KILN_ASM_C_H
#define GO_KILN_ASM_C_H

#include <stddef.h>
#include <stdint.h>

typedef struct go_kiln_ctx_t go_kiln_ctx_t;

go_kiln_ctx_t *go_kiln_ctx_new(void);
void go_kiln_ctx_free(go_kiln_ctx_t *ctx);
const uint8_t *go_kiln_ctx_out_ptr(const go_kiln_ctx_t *ctx);
const char *go_kiln_version(void);

/* Message */
int go_kiln_encode_message(
    go_kiln_ctx_t *ctx,
    uint8_t b1, int32_t i1, int64_t l1, double d1,
    const uint8_t *s1, size_t n1,
    uint8_t b2, int32_t i2,
    const uint8_t *s2, size_t n2,
    size_t *out_len);

int go_kiln_encode_message_batch(
    go_kiln_ctx_t *ctx, size_t count,
    const uint8_t *bools, const int32_t *ints, const int64_t *longs, const double *doubles,
    const uint8_t *str_buf, const uint32_t *str_lens,
    size_t *out_len);

int go_kiln_decode_message(
    go_kiln_ctx_t *ctx, int batch,
    const uint8_t *wire, size_t wlen,
    uint8_t *out_bools, int32_t *out_ints, int64_t *out_longs, double *out_doubles,
    size_t cap_items, size_t *out_count);

/* Document & NestedRow (identical ABI) */
int go_kiln_encode_document(
    go_kiln_ctx_t *ctx, int is_nested, int batch, size_t n_docs,
    const int32_t *doc_ints, const uint32_t *item_counts,
    const int32_t *item_qtys, const int64_t *item_prices,
    const uint8_t *str_buf, const uint32_t *str_lens,
    size_t *out_len);

int go_kiln_decode_document(
    go_kiln_ctx_t *ctx, int is_nested, int batch,
    const uint8_t *wire, size_t wlen,
    int32_t *doc_ints, uint32_t *item_counts, uint32_t *doc_str_spans,
    size_t cap_docs,
    int32_t *item_qtys, int64_t *item_prices, uint32_t *item_str_spans,
    size_t cap_items,
    size_t *out_docs, size_t *out_items);

/* Telemetry */
int go_kiln_encode_telemetry(
    go_kiln_ctx_t *ctx, int batch, size_t n_rows,
    const int64_t *ts, const uint32_t *tag_counts, const uint32_t *val_counts,
    const double *all_vals,
    const uint8_t *str_buf, const uint32_t *str_lens,
    size_t *out_len);

int go_kiln_decode_telemetry(
    go_kiln_ctx_t *ctx, int batch,
    const uint8_t *wire, size_t wlen,
    int64_t *ts, uint32_t *tag_counts, uint32_t *val_counts, uint32_t *src_spans,
    size_t cap_rows,
    uint32_t *tag_spans, size_t cap_tags,
    double *all_vals, size_t cap_vals,
    size_t *out_rows, size_t *out_tags, size_t *out_vals);

/* Strings */
int go_kiln_encode_strings(
    go_kiln_ctx_t *ctx, int batch, size_t n_rows,
    const uint32_t *item_counts,
    const uint8_t *str_buf, const uint32_t *str_lens,
    size_t *out_len);

int go_kiln_decode_strings(
    go_kiln_ctx_t *ctx, int batch,
    const uint8_t *wire, size_t wlen,
    uint32_t *item_counts, size_t cap_rows,
    uint32_t *str_spans, size_t cap_strs,
    size_t *out_rows, size_t *out_strs);

/* Event */
int go_kiln_encode_event(
    go_kiln_ctx_t *ctx, int batch, size_t n_rows,
    const int64_t *occ, const uint32_t *attr_counts,
    const uint8_t *str_buf, const uint32_t *str_lens,
    size_t *out_len);

int go_kiln_decode_event(
    go_kiln_ctx_t *ctx, int batch,
    const uint8_t *wire, size_t wlen,
    int64_t *occ, uint32_t *attr_counts, uint32_t *ev_str_spans,
    size_t cap_rows,
    uint32_t *attr_str_spans, size_t cap_attrs,
    size_t *out_rows, size_t *out_attrs);

/* TableColumns & TableProject */
int go_kiln_encode_table(
    go_kiln_ctx_t *ctx, size_t n_rows,
    const double *floats_col_major, const int64_t *ints_col_major,
    const uint8_t *str_buf, const uint32_t *str_lens,
    size_t *out_len);

int go_kiln_decode_table(
    go_kiln_ctx_t *ctx,
    const uint8_t *wire, size_t wlen,
    double *floats_col_major, int64_t *ints_col_major, uint32_t *str_spans,
    size_t cap_rows, size_t *out_rows);

int go_kiln_decode_table_project(
    go_kiln_ctx_t *ctx,
    const uint8_t *wire, size_t wlen,
    double *out_f0, size_t cap_rows, size_t *out_rows);

/* Signal */
int go_kiln_encode_signal(
    go_kiln_ctx_t *ctx, int batch, size_t n_rows,
    const int64_t *sig_i64, const int32_t *sig_i32, const uint32_t *leg_counts,
    const int64_t *leg_ids, const int32_t *leg_i32,
    const uint8_t *str_buf, const uint32_t *str_lens,
    size_t *out_len);

int go_kiln_decode_signal(
    go_kiln_ctx_t *ctx, int batch,
    const uint8_t *wire, size_t wlen,
    int64_t *sig_i64, int32_t *sig_i32, uint32_t *leg_counts, uint32_t *sig_str_spans,
    size_t cap_rows,
    int64_t *leg_ids, int32_t *leg_i32, size_t cap_legs,
    size_t *out_rows, size_t *out_legs);

/* Tensor, TensorView, Prompt, Shard, Request (KLNT v2) */
int go_kiln_encode_tensor(
    go_kiln_ctx_t *ctx, int32_t rows, int32_t cols,
    const float *vals, size_t n_vals, size_t *out_len);

int go_kiln_decode_tensor_meta(
    go_kiln_ctx_t *ctx, const uint8_t *wire, size_t wlen,
    int32_t *out_rows, int32_t *out_cols, size_t *out_off, size_t *out_nbytes);

int go_kiln_encode_prompt(
    go_kiln_ctx_t *ctx, int32_t batch, int32_t seq,
    const int64_t *a0, const int64_t *a1, const int64_t *a2, size_t n_elems,
    size_t *out_len);

int go_kiln_decode_prompt_meta(
    go_kiln_ctx_t *ctx, const uint8_t *wire, size_t wlen,
    int32_t *out_batch, int32_t *out_seq, size_t out_offs[3], size_t *out_nbytes);

int go_kiln_encode_shard(
    go_kiln_ctx_t *ctx, int32_t vocab, int32_t hidden, int32_t ffn,
    const float *t0, size_t n0, const float *t1, size_t n1,
    const float *t2, size_t n2, const float *t3, size_t n3,
    size_t *out_len);

int go_kiln_decode_shard_meta(
    go_kiln_ctx_t *ctx, const uint8_t *wire, size_t wlen,
    int32_t *out_vocab, int32_t *out_hidden, int32_t *out_ffn,
    size_t out_offs[4], size_t out_nbytes[4]);

int go_kiln_encode_request(
    go_kiln_ctx_t *ctx, int64_t req_id, const uint8_t *model, size_t model_len,
    float temperature, int32_t batch, int32_t seq,
    const int64_t *a0, const int64_t *a1, const int64_t *a2, size_t n_elems,
    size_t *out_len);

int go_kiln_decode_request_meta(
    go_kiln_ctx_t *ctx, const uint8_t *wire, size_t wlen,
    int64_t *out_req_id, size_t *out_model_off, size_t *out_model_len,
    float *out_temp, int32_t *out_batch, int32_t *out_seq,
    size_t out_offs[3], size_t *out_nbytes);

#endif /* GO_KILN_ASM_C_H */
