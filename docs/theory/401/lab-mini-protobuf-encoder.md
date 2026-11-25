# 4.2 Lab: MiniUser Subset Encoder and Decoder

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/leo-gan/GLD.SerializerBenchmark/blob/master/docs/theory/notebooks/401/lab_mini_protobuf_encoder.ipynb)

## Objective

Reading a wire specification is passive; implementing an encoder and decoder forces explicit handling of bit packing, buffer framing, recursion, unknown-field skipping, and bounds enforcement. In this lab you implement a minimal, self-contained Protocol Buffers binary codec for the four-field `MiniUser` teaching message ([4.1 Protocol Buffers wire format](protobuf-wire-format.md)) in any language, verify byte-exact conformance against five golden vectors (`G1`–`G5`), enforce bounds checks on hostile inputs, and cross-validate your output with an official Protocol Buffers runtime.

---

## Explicit Subset Contract

Documenting deliberate omissions prevents a teaching implementation from being confused with a production runtime:

| In Scope (Required) | Out of Scope (Deliberately Omitted) |
|---|---|
| Unsigned `uint32` base-128 varints (capped at 10 bytes) | ZigZag `sint32`/`sint64`, 64-bit signed edge cases |
| UTF-8 `string` (`LEN`, wire type 2) | `bytes`, `Any`, well-known types |
| Optional nested `MiniUser` (`LEN`, wire type 2) | `oneof`, `map`, proto2 `required` / extensions |
| Unpacked `repeated uint32` (one tag per element) | Packed repeated fields (optional extension) |
| Skip unknown `VARINT`, `I64`, `LEN`, `I32` fields on decode | Retaining unknown fields for re-serialization |
| Proto3 omission of default values (`0`, `""`, absent nested) | Full production DoS hardening (recursion/allocation limits) |
| Fail-closed bounds checks on truncated varints, `LEN`, and fixed fields | Streaming/incremental partial-buffer parsing |

### Schema (`mini.proto`)

Use this standalone schema for official-oracle verification (distinct from `schemas/v2/protobuf/benchmark_v2.proto`):

```protobuf
syntax = "proto3";
message MiniUser {
  uint32 id = 1;
  string name = 2;
  MiniUser manager = 3;      // optional nested message
  repeated uint32 tags = 4;  // unpacked in this lab
}
```

---

## Reference Algorithms

### Encoder

```text
function encode_varint(u):
    while u > 0x7f:
        emit (u & 0x7f) | 0x80
        u >>= 7
    emit u & 0x7f

function encode_key(field_number, wire_type):
    encode_varint((field_number << 3) | wire_type)

function encode_len_field(field_number, payload_bytes):
    encode_key(field_number, 2)
    encode_varint(len(payload_bytes))
    emit payload_bytes

function encode_mini_user(u):
    if u.id != 0:
        encode_key(1, 0); encode_varint(u.id)
    if len(u.name) > 0:
        encode_len_field(2, utf8(u.name))
    if u.manager is not null:
        inner = encode_mini_user(u.manager)   # stage first so length precedes payload
        encode_len_field(3, inner)
    for t in u.tags:
        encode_key(4, 0); encode_varint(t)
    return emitted_bytes
```

### Decoder

```text
function decode_varint(buf, i) -> (value, next_i):
    value = 0; shift = 0; count = 0
    loop:
        if i >= len(buf): error "truncated varint"
        b = buf[i]; i += 1; count += 1
        if count > 10: error "varint exceeds 10 bytes"
        value |= (b & 0x7f) << shift
        if (b & 0x80) == 0: return (value, i)
        shift += 7

function require_slice(buf, i, n) -> (slice, next_i):
    if n > len(buf) - i: error "truncated payload"   # overflow-safe check
    return (buf[i : i + n], i + n)

function decode_mini_user(buf):
    i = 0; user = MiniUser(id=0, name="", manager=null, tags=[])
    while i < len(buf):
        key, i = decode_varint(buf, i)
        fn = key >> 3; wt = key & 7
        if wt == 0:
            v, i = decode_varint(buf, i)
            if fn == 1: user.id = v
            elif fn == 4: user.tags.append(v)
        elif wt == 2:
            n, i = decode_varint(buf, i)
            payload, i = require_slice(buf, i, n)
            if fn == 2: user.name = utf8_decode(payload)
            elif fn == 3: user.manager = decode_mini_user(payload)
        elif wt == 1:
            _, i = require_slice(buf, i, 8)   # skip unknown I64
        elif wt == 5:
            _, i = require_slice(buf, i, 4)   # skip unknown I32
        else:
            error "unsupported wire type"
    return user
```

---

## Verification Suite (Acceptance Criteria)

An implementation is complete only when all five test groups pass:

### 1. Golden Byte Vectors (`G1`–`G5`)

| Vector | Logical `MiniUser` Value | Expected Wire Hex | Byte Length |
|---|---|---|---:|
| **G1** | `id = 1, name = "Ada"` | `08 01 12 03 41 64 61` | 7 |
| **G2** | Empty message (all defaults) | *(empty byte string)* | 0 |
| **G3** | `id = 300` | `08 ac 02` | 3 |
| **G4** | `tags = [1, 2]` (unpacked) | `20 01 20 02` | 4 |
| **G5** | `manager = { id = 2 }` | `1a 02 08 02` | 4 |

### 2. Unknown-Field Skip

Append `28 63` (field 5, `VARINT`, value 99) to **G1** (`08 01 12 03 41 64 61 28 63`). Your decoder must ignore field 5 and recover `id = 1, name = "Ada"`.

### 3. Round-Trip Property

Verify `decode_mini_user(encode_mini_user(x)) == x` across varied IDs, non-ASCII UTF-8 strings, nested `manager` chains, and repeated `tags`. Also test decoding **G1** with fields reversed (`12 03 41 64 61 08 01`).

### 4. Fail-Closed Bounds Tests

Every malformed input below must return an explicit decode error—never panic, read out of bounds, or silently truncate:

| Hostile Input (Hex) | Defect |
|---|---|
| `12 0a 41 42` | `LEN` header claims $n = 10$ bytes, but only 2 remain |
| `08 80` | Varint continuation bit set at EOF |
| `08 80 80 80 80 80 80 80 80 80 80 01` | Overlong 11-byte varint |
| `09 01 02 03` | Field 1, `I64` wire type (`1`) with only 3 bytes remaining |

### 5. Official-Parser Oracle Cross-Check

Compile `mini.proto` with `protoc`[^1] and verify that an official runtime parses bytes emitted by your encoder (shown here with Python `google.protobuf`; Rust `prost` or C `protobuf-c` are equally valid oracles):

```python
# protoc --python_out=. mini.proto
import mini_pb2

raw = encode_mini_user(MiniUser(id=1, name="Ada"))
parsed = mini_pb2.MiniUser()
parsed.ParseFromString(raw)
assert parsed.id == 1 and parsed.name == "Ada"
```

Starter companions for implementing the same `G1`–`G5` suite in Go and Rust live in [companions/go](../notebooks/companions/go/README.md) and [companions/rust](../notebooks/companions/rust/README.md).

---

## Exercises

1. **Integer overflow in bounds checking:** Why is `if n > len(buf) - i` strictly safer than `if i + n > len(buf)` in fixed-width integer languages such as C or Rust (release builds)?

??? note "Solution"
    If `n` is decoded as a maliciously large 64-bit length (e.g., $n = 2^{64} - 1$) and $i > 0$, `i + n` wraps around modulo $2^{64}$ to a small integer smaller than `len(buf)`, bypassing the bounds check and causing an out-of-bounds read. Because $i \le \text{len}(\text{buf})$ is an invariant, `len(buf) - i` never underflows, making `n > len(buf) - i` immune to overflow.

2. **Supporting packed repeated fields:** Modify the `wt == 2` branch of `decode_mini_user` so it also accepts modern proto3 **packed** `tags` (e.g., `22 02 01 02`).

??? note "Solution"
    Inside `elif wt == 2:`, add a branch for `fn == 4`: loop `j = 0` while `j < len(payload)`, calling `v, j = decode_varint(payload, j)` and appending `v` to `user.tags`. Because the loop runs solely over the bounded `payload` slice, truncated elements inside the packed block fail closed automatically.

3. **Empty nested message distinction:** Suppose `u.manager = MiniUser()` (present, but all fields default). What wire bytes should `encode_mini_user(u)` emit for field 3, and how does the decoder distinguish "absent manager" from "present empty manager"?

??? note "Solution"
    `inner` is empty (0 bytes), so field 3 emits `1a 00` (key `0x1a`, length `0x00`, zero payload bytes). When `decode_mini_user` encounters `1a 00`, it invokes `decode_mini_user(b"")` and assigns a non-null empty `MiniUser` to `user.manager`, distinguishing explicit presence (`1a 00`) from an absent field (no `1a` tag on the wire).

---

## References

[^1]: Google Protocol Buffers Documentation. *Encoding* (<https://protobuf.dev/programming-guides/encoding/>) and *Protocol Buffers Compiler (`protoc`)*.
