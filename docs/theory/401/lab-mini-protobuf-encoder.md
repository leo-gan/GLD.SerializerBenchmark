# Lab: mini Protobuf subset encoder/decoder

> Build a **deliberately small** Protobuf binary codec for a teaching message—not production Protobuf, not suite `Person`.

## Goal

Implement a MiniUser subset encoder/decoder, validate against **golden bytes** and an official parser, and refuse truncated/hostile shapes. You will practice the wire rules from [Protobuf wire format](protobuf-wire-format.md)—not rebuild `protoc`.

## Subset (in / out)

| In scope | Out of scope (do not implement for “done”) |
|----------|-----------------------------------------------|
| `uint32` as varint | `sint32` zigzag, all 64-bit edge cases |
| `string` (UTF-8, length-delimited) | `bytes` blobs beyond strings you need |
| Nested message (length-delimited) | `google.protobuf.Any`, well-known types |
| `repeated uint32` **unpacked** | Packed repeated (stretch goal only) |
| Skip unknown varint / len-delimited on decode | Store/round-trip unknown fields |
| proto3-style omit empty/default scalars | proto2 required, extensions, maps, oneofs |
| Reject truncated LEN / short buffer / overlong varint | Full production hardening |

### Teaching schema

Not the suite `schemas/benchmark_data.proto`. Use a tiny local `mini.proto` (or equivalent) when you need an official oracle:

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

- [ ] `key = (field_number << 3) | wire_type`  
- [ ] Varint encode/decode (unsigned), with max length  
- [ ] LEN fields: key, len varint, payload (on the wire in that order)  
- [ ] Nested: payload is a full message encoding  
- [ ] Repeated unpacked: one tag per element  
- [ ] Decode: loop until input exhausted; skip unknown by wire type  
- [ ] Bounds: never read past end of buffer  

## Steps (encode)

Implement in **any language you choose**. The pseudocode below is deliberately language-agnostic; the validation section uses Python as one convenient oracle, but protobuf-c or prost work equally well.

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

| Case | Logical value | Hex (spaces optional) |
|------|---------------|------------------------|
| G1 | `id=1, name="Ada"` | `08 01 12 03 41 64 61` |
| G2 | empty message | *(empty byte string)* |
| G3 | `id=300` only | `08 ac 02` |
| G4 | `tags=[1,2]` only | `20 01 20 02` |
| G5 | `manager={id=2}` only | `1a 02 08 02` |

**G1 detail:** field1 key `08`, varint `01`; field2 key `12`, len `03`, `41 64 61` = `Ada`.  
**G4:** field 4 key = `(4<<3)|0` = `32` = `0x20`.  
**G5:** field 3 key = `(3<<3)|2` = `26` = `0x1a`; inner len 2; inner `08 02`.

Your encoder may omit default fields; decoders must accept any field order. Empty `name=""` should encode like G2 if you omit defaults (no field 2 on the wire).

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

**Unknown field test:** append `28 63` (field 5, varint 99) to G1; decoder should yield same logical `id`/`name` and ignore field 5.

**Bounds tests (required for done):**

| Input idea | Expected |
|------------|----------|
| LEN claims `n=10` but only 2 bytes remain | error |
| Single byte `0x80` (varint continues, EOF) | error |
| Fixed64 wire type with fewer than 8 bytes left | error |

## Done when

All of the following:

1. **Encode** matches goldens G1–G5 (and G2 empty) under the same omit-default rules.  
2. **Unknown skip:** G1 + `28 63` decodes to same logical `id`/`name`.  
3. **Round-trip:** `decode(encode(x)) == x` for a small set (ids, names, one manager level, a few tags).  
4. **Bounds:** at least the three bounds tests above fail cleanly (error, not silent truncate / OOB).  
5. **Official parser (required):** at least G1 encode (or the hex golden) parses in Python `google.protobuf`, prost, or protobuf-c from a local `mini.proto`.

## Validate

### 1. Golden match

Encoder output for G1–G5 must equal the hex tables (for the same logical omit rules).

### 2. Official parser

Install `protoc` (or use any official decoder). Minimal `.proto` + Python:

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

protobuf-c or prost work equally as oracles if you prefer those stacks.

### 3. Round-trip and bounds

As in **Done when**.

## Extension ideas

- Packed `repeated uint32` (single LEN field, concatenated varints)—see wire article packed hex.  
- `uint64` / fixed32.  
- Reject remaining garbage after a nested length (strict nested consume).  
- Fuzz skip paths with random unknown tags ([301 untrusted input](../301/untrusted-input.md) mindset).

## What this lab is not

- Production-grade Protobuf.  
- Full fidelity to suite `Person` fixtures.  
- A replacement for language runtimes in [Python](protobuf-python.md) / [Rust](protobuf-rust-prost.md) / [C](protobuf-c-protobuf-c.md).

## Key takeaways

- A few wire primitives implement a useful subset.  
- Golden bytes + official parse beat “looks right in hex.”  
- Skipping unknowns **and** refusing truncated input are both part of being a real decoder.  
- Real systems still use codegen runtimes—this lab builds **judgment**, not a product codec.
