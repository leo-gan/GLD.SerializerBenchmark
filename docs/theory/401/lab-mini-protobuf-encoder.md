# Lab: mini Protobuf subset encoder/decoder

> Build a **deliberately small** Protocol Buffers binary codec for a teaching message. This is not production Protocol Buffers, and it is not the full benchmark suite fixture.

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/leo-gan/GLD.SerializerBenchmark/blob/master/docs/theory/notebooks/401/lab_mini_protobuf_encoder.ipynb)
**Lab notebook:** [lab_mini_protobuf_encoder.ipynb](../notebooks/401/lab_mini_protobuf_encoder.ipynb) · wire playground: [wire_format_playground.ipynb](../notebooks/401/wire_format_playground.ipynb)

## Goal

Implement a MiniUser subset encoder and decoder. Validate your bytes against **golden sequences** (known-correct hex) and against an official parser. Refuse truncated or hostile shapes instead of reading past the end of a buffer. You will practice the wire rules from [Protobuf wire format](protobuf-wire-format.md). You are not rebuilding `protoc` (the Protocol Buffers compiler that turns `.proto` files into language code).

## Subset (in / out)

Labeling what you leave out is part of being honest about a teaching subset.

| In scope | Out of scope (do not implement for “done”) |
|----------|-----------------------------------------------|
| `uint32` as a varint (variable-length integer) | `sint32` zigzag, full 64-bit edge cases |
| `string` (UTF-8, length-delimited) | `bytes` blobs beyond the strings you need |
| Nested message (length-delimited) | `google.protobuf.Any`, well-known types |
| `repeated uint32` **unpacked** (one tag per element) | Packed repeated (stretch goal only) |
| Skip unknown varint and length-delimited fields on decode | Store or round-trip unknown fields for re-encode |
| proto3-style omit empty/default scalars | proto2 required fields, extensions, maps, oneofs |
| Reject truncated LEN, short buffers, overlong varints | Full production hardening |

### Teaching schema

This is **not** the suite schema at `schemas/v2/protobuf/benchmark_v2.proto`. Use a tiny local `mini.proto` (or equivalent) when you need an official oracle:

```protobuf
syntax = "proto3";
message MiniUser {
  uint32 id = 1;
  string name = 2;
  MiniUser manager = 3;      // optional nested
  repeated uint32 tags = 4;  // unpacked
}
```

## Wire checklist

Work through these until each item is true of your code:

- [ ] `key = (field_number << 3) | wire_type`  
- [ ] Varint encode and decode for unsigned values, with a maximum length  
- [ ] LEN fields on the wire: key, then length varint, then payload (in that order)  
- [ ] Nested messages: the payload is a full message encoding  
- [ ] Unpacked repeated fields: one tag per element  
- [ ] Decode: loop until the input is exhausted; skip unknown fields by wire type  
- [ ] Bounds: never read past the end of the buffer  

## Steps (encode)

Implement in **any language you choose**. The pseudocode below is deliberately language-agnostic. The validation section uses Python as one convenient official oracle, but **protobuf-c** or **prost** work equally well.

```text
function encode_varint(u):
  while u > 0x7f:
    emit (u & 0x7f) | 0x80
    u >>= 7
  emit u & 0x7f

function encode_key(field_number, wire_type):
  encode_varint((field_number << 3) | wire_type)

function encode_string(field_number, s):
  b = utf8(s)
  encode_key(field_number, 2)
  encode_varint(len(b))
  emit b

function encode_mini_user(u):
  if u.id != 0:
    encode_key(1, 0); encode_varint(u.id)
  if u.name:                    # omit empty string (proto3-style)
    encode_string(2, u.name)
  if u.manager is not null:
    inner = encode_mini_user(u.manager)  # stage payload, then key|len|payload
    encode_key(3, 2); encode_varint(len(inner)); emit inner
  for t in u.tags:
    encode_key(4, 0); encode_varint(t)
  return bytes
```

### Golden vectors

These hex sequences are fixed reference answers. Your encoder should match them under the same “omit default fields” rules.

| Case | Logical value | Hex (spaces optional) |
|------|---------------|------------------------|
| G1 | `id=1, name="Ada"` | `08 01 12 03 41 64 61` |
| G2 | empty message | *(empty byte string)* |
| G3 | `id=300` only | `08 ac 02` |
| G4 | `tags=[1,2]` only | `20 01 20 02` |
| G5 | `manager={id=2}` only | `1a 02 08 02` |

**G1 detail:** field 1 key is `08`, value varint is `01`; field 2 key is `12`, length is `03`, payload `41 64 61` is UTF-8 for `Ada`.  
**G4:** field 4 key = `(4<<3)|0` = `32` = `0x20`.  
**G5:** field 3 key = `(3<<3)|2` = `26` = `0x1a`; the inner message is two bytes long; those bytes are `08 02`.

Your encoder may omit default fields. Decoders must accept any field order. An empty `name=""` should encode like G2 if you omit defaults (no field 2 appears on the wire).

## Steps (decode)

```text
function decode_varint(buf, i) -> (value, new_i):
  value = 0; shift = 0; bytes_read = 0
  while true:
    if i >= len(buf): error "truncated varint"
    b = buf[i]; i += 1; bytes_read += 1
    if bytes_read > 10: error "overlong varint"   # 64-bit cap
    value |= (b & 0x7f) << shift
    if (b & 0x80) == 0: break
    shift += 7
  return (value, i)

function require(buf, i, n):
  if i + n > len(buf): error "truncated payload"
  return buf[i : i+n], i+n

function decode_mini_user(buf):
  i = 0; user = defaults
  while i < len(buf):
    key, i = decode_varint(buf, i)
    fn = key >> 3; wt = key & 7
    if wt == 0:
      v, i = decode_varint(buf, i)
      if fn == 1: user.id = v
      elif fn == 4: user.tags.append(v)
      # else: already consumed (skip unknown varint)
    elif wt == 2:
      n, i = decode_varint(buf, i)
      payload, i = require(buf, i, n)   # must not overrun
      if fn == 2: user.name = utf8_decode(payload)
      elif fn == 3: user.manager = decode_mini_user(payload)
      # else: skip unknown LEN
    elif wt == 1:
      _, i = require(buf, i, 8)         # skip fixed64
    elif wt == 5:
      _, i = require(buf, i, 4)         # skip fixed32
    else:
      error "unsupported wire type"
  return user
```

**Unknown field test:** append `28 63` (field 5 with varint value 99) to the G1 bytes. Your decoder should still yield the same logical `id` and `name`, and should ignore field 5.

**Bounds tests (required for “done”):**

| Input idea | Expected |
|------------|----------|
| LEN claims `n=10` but only 2 bytes remain | error |
| Single byte `0x80` (varint says “more follows,” then end of file) | error |
| Fixed64 wire type with fewer than 8 bytes left | error |

## Done when

All of the following are true:

1. **Encode** matches goldens G1–G5 (including empty G2) under the same omit-default rules.  
2. **Unknown skip:** G1 plus `28 63` decodes to the same logical `id` and `name`.  
3. **Round-trip:** `decode(encode(x)) == x` for a small set of values (several ids and names, one manager level, a few tags).  
4. **Bounds:** at least the three bounds tests above fail cleanly (an error, not a silent truncate or an out-of-bounds read).  
5. **Official parser (required):** at least the G1 encode (or the hex golden) parses in Python `google.protobuf`, in prost, or in protobuf-c from a local `mini.proto`.

## Validate

### 1. Golden match

Encoder output for G1–G5 must equal the hex table above (for the same logical omit rules).

### 2. Official parser

Install `protoc` (or use any official decoder). Minimal `.proto` plus Python:

```python
# After: protoc --python_out=. mini.proto
# mini.proto defines MiniUser (teaching schema — not suite benchmark_data)
import mini_pb2

raw = bytes.fromhex("08011203416461")
m = mini_pb2.MiniUser()
m.ParseFromString(raw)
assert m.id == 1 and m.name == "Ada"

# Cross-check your encoder:
mine = encode_mini_user(...)  # your function
m2 = mini_pb2.MiniUser()
m2.ParseFromString(mine)
assert m2.id == 1 and m2.name == "Ada"
```

protobuf-c or prost work equally well as oracles if you prefer those stacks.

### 3. Round-trip and bounds

Match the criteria listed under **Done when**.

## Extension ideas

- Packed `repeated uint32` (a single LEN field whose payload is concatenated varints)—see the packed hex in the wire article.  
- `uint64` or fixed32.  
- Reject remaining garbage after a nested length (strict nested consume).  
- Fuzz skip paths with random unknown tags, using the [301 untrusted input](../301/untrusted-input.md) mindset.  
- **Same goldens in another language:** [Go](../notebooks/companions/go/) · [Rust](../notebooks/companions/rust/) appendices (encode MiniUser until G1–G5 match).

## What this lab is not

- Production-grade Protocol Buffers.  
- Full fidelity to suite fixtures.  
- A replacement for the language runtimes described in [Python](protobuf-python.md), [Rust](protobuf-rust-prost.md), and [C](protobuf-c-protobuf-c.md).

## Key takeaways

- A few wire primitives are enough to implement a useful teaching subset.  
- Golden bytes plus an official parse beat “this hex dump looks plausible.”  
- Skipping unknowns **and** refusing truncated input are both part of being a real decoder.  
- Real systems still use code-generated runtimes. This lab builds **judgment**, not a product codec.
