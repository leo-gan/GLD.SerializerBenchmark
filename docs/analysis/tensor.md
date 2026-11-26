# Tensor Data Set

The **`tensor`** data set evaluates machine-learning and numerical payloads—dense 32-bit float matrices, borrowed zero-copy views, padded integer token prompts, multi-tensor checkpoint shards, and combined inference requests—via `config/library/tensor.yaml` and `tensor-smoke.yaml` ($N = 1$, `bytes` mode, `compression.mode: none`).

## Motivation and Fidelity Contract

General-purpose document serializers rarely expose contiguous aligned tensor buffers or borrowed views over multi-megabyte weights. Every type in `tensor` uses row-major `float32` tensors and enforces **bit-identical `float32` fidelity**, including negative zero (`-0.0`) at index `0` and quiet NaN (`0x7fc00000`) at index `1`, alongside exact integer and UTF-8 string equality. Per [Timing contract rule 9](TIMING_HONESTY.md), allocating host source arrays stays in `prepare`, while writing and reading the payload are timed.

## Data Types

### `tensor`

A single dense $1024 \times 1024$ `float32` matrix (4 MiB raw payload) decoded back as an **owned copy**, serving as the copying baseline for activations, embeddings, or feature matrices.

### `tensor_view`

Identical input matrix and seed to `tensor`, but timed `deserialize` must return a **borrowed zero-copy view** backed directly by the encoded payload buffer without copying the 4 MiB matrix (comparing `tensor` vs. `tensor_view` isolates the memory-bandwidth cost of allocation and copying; see [2.7 Zero-copy](../theory/201/zero-copy.md)). Copying the buffer and taking a view of the copy is invalid.

### `prompt`

Padded integer inference inputs consisting of three parallel `int64[4, 256]` arrays (`input_ids`, `attention_mask`, `position_ids`), each containing a non-zero content prefix followed by zero padding.

### `shard`

A four-tensor transformer-layer checkpoint testing multi-tensor named payloads within a single serialized artifact:

```text
tok_emb : float32[1024, 256]
attn    : float32[256, 256]
ffn     : float32[512, 256]
norm    : float32[256]
```

### `request`

A composite inference RPC body pairing scalar/string metadata (`request_id: int64`, `model: utf8_string`, `temperature: float32`) with the three integer `prompt` tensors, testing mixed metadata and dense array framing in one call.
