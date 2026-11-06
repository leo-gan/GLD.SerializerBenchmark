# Tensor

The **tensor** data set is five data types: `tensor`, `tensor_view`, `prompt`, `shard`, and `request`. They run from `tensor.yaml` and `tensor-smoke.yaml`. N stays 1. `all@` does not include them. An empty serializer filter selects the serializers mapped to this set.

Floats are row-major float32. Fidelity is bit-identical float32, including the sign of zero and the NaN payload, and exact integers and strings.

## Why this set

The tensor set is machine-learning payloads: a float matrix, a borrowed read of that matrix, a token prompt, a block of weights, and a request that wraps them. It exists because document codecs and tensor codecs are built for different shapes. A nested document does not show a 4 MiB matrix, a read that must not copy that matrix, or a checkpoint made of several arrays. Typical uses are model serving, training checkpoints, and inference requests. A borrowed read uses the encoded bytes in place. Only libraries that can carry these shapes are measured here.

The generator contract and the other sets are on [Data sets](test_data_configuration.md).

## tensor

A tensor is one 1024 by 1024 matrix of 32-bit floats, 4 MiB of values before any wrapper, read back as an owned copy. It exists as the plain path that returns the matrix. Index 0 is negative zero and index 1 is the quiet NaN `0x7fc00000`, so a reader that rewrites floats does not score a perfect round trip. Typical uses are an activation, an embedding table, or a batch of features.

## tensor_view

Tensor view is the same matrix as `tensor`, for the same seed, and the read borrows the payload from the encoded buffer instead of copying it. It exists to show designs that avoid a second allocation of those 4 MiB. An owned copy, including a copy followed by a view of the copy, is not a `tensor_view` result. The owned `tensor` type is the comparison: same bytes, different read. Typical uses are serving a weight or an activation without copying the matrix. The longer account of in-place reads is [Zero-copy](../theory/201/zero-copy.md).

## prompt

A prompt is padded token inputs: `input_ids`, `attention_mask`, and `position_ids`, each `int64[4, 256]`. It exists because model servers send tokens, not one float matrix. A float matrix would miss the integer path and the three parallel arrays. Each row is padded with zeros after a content prefix. Typical uses are a batch of prompts waiting for inference.

## shard

A shard is one transformer block of 32-bit weights: an embedding, attention, a feed-forward layer, and a norm. It exists so a checkpoint-shaped payload is in the set, not only a single matrix. One matrix cannot show several named arrays in one value. Typical uses are saving or shipping one layer of a model.

```text
tok_emb   float32[1024, 256]
attn      float32[256, 256]
ffn       float32[512, 256]
norm      float32[256]
```

## request

A request pairs a request id (`int64`), a model name (utf8), and a temperature (`float32`) with the prompt tensors. It exists because a real inference call is metadata plus tensors. A naked prompt would hide whether the codec can carry a string and a scalar next to the integer matrices. Typical uses are an inference request body.
