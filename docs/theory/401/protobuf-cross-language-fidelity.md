# 4.7 Cross-Language Interoperability and Fidelity

## Problem Statement

Sharing a `.proto` file across Python, Rust, and C does not automatically prove that three services interoperate cleanly in production—nor does it imply that all three runtimes emit identical bytes. Subtle interoperability failures arise from proto3 default-value omission, packed vs. unpacked repeated fields, unknown enum policies, strict vs. lenient UTF-8 checks, timestamp units, and domain-model conversion bugs.

This lecture formalizes four distinct correctness claims that engineers routinely conflate and specifies a minimal $m \times m$ cross-language interoperability matrix.

---

## Four Distinct Correctness Claims

| Claim | Formal Meaning | Required by Protobuf Spec? | Verified by This Suite's `mean_fidelity`? |
|---|---|---|---|
| **Local round-trip fidelity** | $\text{decode}_A(\text{encode}_A(x)) \equiv x$ inside one language $A$ | Necessary baseline | **Yes** (single-runner check only) |
| **Cross-language interoperability** | $\forall A, B:\ \text{decode}_B(\text{encode}_A(x)) \equiv x$ (logical equality) | **Yes** (primary contract goal) | **No** (must test across runtimes) |
| **Bit-identical (canonical) encode** | $\text{encode}_A(x) = \text{encode}_B(x)$ byte-for-byte | **No**[^1] | **No** |
| **Specification conformance** | Library passes upstream spec edge-case suite across all features | Standard-defined | **Separately** on [Compliance](../../dashboard/index.html#compliance) |

!!! note "Theorem (Non-Uniqueness of Protobuf Wire Encodings)"
    The Protocol Buffers binary format is **many-to-one**: multiple distinct byte sequences decode to the same logical message. Valid encoders may vary field order, omit or explicitly emit default values (under explicit presence), order map entries differently, or choose packed vs. unpacked encoding for repeated scalars.

Consequently, **logical interoperability** is the mandatory requirement across services; **bit-identity** is an optional constraint required only when raw wire bytes are hashed as cache keys or passed directly into cryptographic signatures (where deterministic serialization or canonical signing wrappers must be enforced explicitly).

---

## Designing an $m \times m$ Interoperability Matrix

```text
  Canonical logical record x (frozen schema + frozen test vectors)
       ├──► Python encode ──► b_py  ──► decode in {Python, Rust, C} ──► assert logical_eq
       ├──► Rust encode   ──► b_rs  ──► decode in {Python, Rust, C} ──► assert logical_eq
       └──► C encode      ──► b_c   ──► decode in {Python, Rust, C} ──► assert logical_eq
```

| Encoder $\backslash$ Decoder | Python (`google.protobuf`) | Rust (`prost`) | C (`protobuf-c`) |
|---|---|---|---|
| **Python** | Local round-trip | Cross-decode ($L_{\text{py}} \to L_{\text{rs}}$) | Cross-decode ($L_{\text{py}} \to L_{\text{c}}$) |
| **Rust** | Cross-decode ($L_{\text{rs}} \to L_{\text{py}}$) | Local round-trip | Cross-decode ($L_{\text{rs}} \to L_{\text{c}}$) |
| **C** | Cross-decode ($L_{\text{c}} \to L_{\text{py}}$) | Cross-decode ($L_{\text{c}} \to L_{\text{rs}}$) | Local round-trip |

### Protocol Steps

1. **Freeze one schema commit:** Compile Python (`protoc --python_out`), Rust (`prost-build`), and C (`protoc --c_out`) from the exact same `.proto` revision. Never hand-edit generated files in one language.
2. **Author language-neutral edge-case vectors:** Define explicit logical inputs covering:
   - Default/zero scalars (`0`, `""`, `false`) vs. non-default values,
   - Multi-byte UTF-8 code points (beyond ASCII),
   - Large 64-bit signed/unsigned boundary values,
   - Empty vs. populated nested submessages and repeated fields,
   - Floating-point tolerances (exact binary floats for strict checks; explicit policy for `NaN` / `-0.0`).
3. **Run all $m^2$ cells and assert logical field equality:** Every off-diagonal pair $(A \to B)$ must recover the identical logical record.
4. **Test forward compatibility (unknown-field skip):** Append an unknown field such as `28 63` (field 5, `VARINT`, value 99) to bytes produced by each encoder and verify that all decoders recover known fields without error.
5. **Document bit-identity diffs separately:** Compare `b_py == b_rs == b_c`. When bytes differ yet cross-decode cleanly, record the exact cause (e.g., packed vs. unpacked repeated tags, map iteration order, or explicit defaults).

### Minimal `MiniUser` Runbook

Using `mini.proto` from [4.2 Lab](lab-mini-protobuf-encoder.md) with `G1` (`MiniUser { id = 1, name = "Ada" }`, golden hex `08 01 12 03 41 64 61`) and `G5` (`manager = { id = 2 }`, golden hex `1a 02 08 02`):

1. Encode `G1` and `G5` in Python (`SerializeToString`), Rust (`encode_to_vec`), and C (`protobuf_c_message_pack`).
2. Feed each runtime's bytes into the other two decoders and assert `id == 1 && name == "Ada"` (and `manager.id == 2`).
3. Append `28 63` to each encoded `G1` buffer and verify all three decoders skip field 5 cleanly.

---

## Common Cross-Language Failure Modes

| Failure Source | Typical Symptom | Mitigation |
|---|---|---|
| **Proto3 default vs. optional presence** | Explicit `0` emitted by one runtime, omitted by another | Assert logical field equality, or declare `optional` explicitly when presence matters |
| **Unknown enum values** | Open proto3 enums preserve unknown integers in some runtimes while strict parsers reject them | Standardize enum-evolution policy across runtimes |
| **Strict UTF-8 validation** | Lenient C decoder accepts non-UTF-8 bytes in `string`; Python/Rust reject with `DecodeError` | Use `bytes` for non-UTF-8 payloads; validate UTF-8 at ingress |
| **Static caps (`nanopb`) vs. heap (`protobuf-c`)** | Valid message rejected by MCU | Document `max_size`/`max_count` in the shared contract ([4.6 `nanopb` vs. `protobuf-c`](protobuf-c-nanopb-compare.md)) |
| **Adapter mapping bugs** | Suite `prepare` drops or rounds a field (e.g., timestamp ms vs. ns) | Unit-test domain-to-proto adapters independently of wire decode |

---

## Exercises

1. **Signing raw wire bytes:** Service A (Python) encodes a `PaymentOrder` Protobuf message, computes an HMAC-SHA256 over the serialized bytes, and sends both to Service B (Rust). Service B decodes the message, re-encodes it with `prost`, and verifies the HMAC over its re-encoded bytes—and verification fails intermittently when a `map<string, string>` field is present. Why, and what is the correct design?

??? note "Solution"
    Protobuf binary encoding is **not canonical**: map iteration order (and field/default emission across runtimes) is unspecified, so Service B's re-encoded bytes need not match Service A's original bytes even for identical logical data.[^1] Service B must verify the HMAC over the **exact raw bytes received on the wire** *before* decoding (or wrap the serialized payload inside an envelope `{ bytes payload = 1; bytes signature = 2; }`).

2. **Matrix size vs. local fidelity:** An organization runs 5 languages on a shared internal RPC boundary. How many cells exist in the full $5 \times 5$ interoperability matrix, and how many of those cells are actually tested by running per-language local round-trip fidelity checks?

??? note "Solution"
    The full matrix has $5^2 = 25$ cells. Per-language round-trip checks test only the **5 diagonal cells** ($L_i \to L_i$), leaving **20 cross-language cells** ($L_i \to L_j,\ i \ne j$) completely untested.

3. **Distinguishing compliance from interop:** Why might a $3 \times 3$ matrix over `MiniUser` pass 100% while one of the three libraries still fails the upstream Protobuf Conformance Test Suite?

??? note "Solution"
    `MiniUser` exercises only `uint32`, `string`, nested messages, and unpacked repeated `uint32`. It never tests maps, `oneof` last-one-wins merging, packed-vs-unpacked merging, ZigZag negatives, `sint64` boundaries, or invalid UTF-8 rejection—all of which are verified only by the comprehensive upstream conformance suite.[^2]

---

## References

[^1]: Google Protocol Buffers Documentation. *Encoding — Implications (Serialization Is Not Deterministic)*. <https://protobuf.dev/programming-guides/encoding/#implications>
[^2]: Protocol Buffers Repository. *Conformance Test Suite*. <https://github.com/protocolbuffers/protobuf/tree/main/conformance>
