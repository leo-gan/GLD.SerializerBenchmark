# Tensor

The **tensor** data set is five data types: `tensor`, `tensor_view`, `prompt`, `shard`, and `request`. They run from `tensor.yaml` and `tensor-smoke.yaml`. N stays 1. `all@` does not include them. An empty serializer filter selects the serializers mapped to this set.

Floats are row-major float32. Fidelity is bit-identical float32, including the sign of zero and the NaN payload, and exact integers and strings.

The generator contract and the other sets are on [Data sets](test_data_configuration.md).

## tensor

One owned read of `float32[1024, 1024]`. Index 0 is negative zero. Index 1 is the quiet NaN `0x7fc00000`.

## tensor_view

The same matrix, for the same seed, as `tensor`. The read must borrow bytes inside the encoded buffer. An owned copy is not a `tensor_view` result.

## prompt

`input_ids`, `attention_mask`, and `position_ids`, each `int64[4, 256]`. Each row is padded with zeros after a content prefix.

## shard

One transformer block:

```text
tok_emb   float32[1024, 256]
attn      float32[256, 256]
ffn       float32[512, 256]
norm      float32[256]
```

## request

One buffer: the request id (`int64`), the model name (utf8), the temperature (`float32`), and the prompt.
