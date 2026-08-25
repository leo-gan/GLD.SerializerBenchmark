# Same bytes, three runtimes

## Why this article exists

Saying “we all use Protocol Buffers” does not guarantee that Python, Rust, and C produce **bit-identical** payloads. It also does not guarantee that round-trips preserve every logical field across languages. Fidelity bugs hide in defaults, field naming, timestamps, packed repeated fields, UTF-8 handling, and test-benchmark runner mapping. They do not hide in the marketing name of the format.

In this article you will learn a disciplined way to prove that three runtimes interoperate. After reading it, you should be able to design a small encode/decode matrix. You should be able to state when bit-identity is required. You should also avoid treating suite speed tables as fidelity proofs.

## Short answer

In this course, **fidelity** means two related claims. First, given one logical value and one `.proto`, each runtime’s encode and decode behaves as a correct Protocol Buffers implementation for that schema. Second, **cross-language** pairs interoperate for the fields you care about: bytes produced in language A decode correctly in language B.

Prefer proving interoperability with **golden vectors** (known-correct hex sequences) and **matrix tests** (encode in A, decode in B). Do not treat suite speed tables as fidelity proofs. This suite’s benchmark runners are **per-language**. They do not automatically prove cross-runtime byte identity. [301 multi-language systems (polyglot estates)](../301/polyglot-estates.md) is about product contract choice. This page is about **byte and logic discipline**.

This article assumes the [wire format](protobuf-wire-format.md) article and at least one language path ([Python](protobuf-python.md), [Rust](protobuf-rust-prost.md), [C](protobuf-c-protobuf-c.md)).

This shared code repository already has Python, Rust, and C Protocol Buffers entries. Use them when available. Outside the suite, the same discipline applies with any three official runtimes.

## Prerequisites

- Shared schema discipline (`schemas/v2/protobuf/benchmark_v2.proto` in this repo, or a tiny shared `mini.proto`).
- Soft: [301 using this suite](../301/using-this-suite.md)—do not use Dashboard numbers as fidelity proofs.

## Mental model

Start from one logical value and two encoders. Then ask two separate questions. Do the decoders recover the logical value? Do the encoders emit exactly the same bytes?

```text
  logical value  ──A.encode──►  bytes₁
  logical value  ──B.encode──►  bytes₂

  bytes₁ ──B.decode──► logical'   must equal logical (for agreed fields)
  bytes₂ ──A.decode──► logical''

  bytes₁ == bytes₂ ?   nice when true; NOT required by the Protobuf spec
```

Protocol Buffers requires **semantic** compatibility. A decoder must understand what an encoder wrote. It does **not** require that two encoders emit the same field order. It also does not require the same omission pattern for default values.

## What “same bytes” can mean (be precise)

Students often collapse several different claims into the phrase “same bytes.” Keep the following distinctions clear.

| Claim | Meaning | Required by spec? |
|-------|---------|-------------------|
| **Interoperable** | A’s bytes decode in B to the same logical fields | **Yes** (for the schema subset you use) |
| **Bit-identical encode** | A and B produce equal `bytes` for one value | **No** |
| **Benchmark runner fidelity** | Serialize then deserialize in **one** language matches the fixture compare | Suite-local only |
| **Canonical encode** | Deterministic field order / map order | Optional (`deterministic` in some APIs) |

Serializer developers should chase **interoperability** first and **bit-identity** second. Bit-identity is useful for debugging, signing, and caches.

## Step-by-step fidelity discipline

### 1. Freeze the schema

Without a shared schema, cross-language tests are meaningless. Do the following first:

- Use one `.proto` file (or generated sources from one commit).
- Do not renumber fields silently.
- Document packed versus unpacked repeated fields if generator versions differ.

### 2. Freeze the logical fixture

Define values in a language-neutral way:

- Integers and bools are exact.
- Strings are defined by Unicode code points (not “whatever my editor saved”).
- Timestamps use an explicit unit (this suite often uses milliseconds—see benchmark runner notes).
- Floats and doubles: prefer values with exact binary representations when asserting bit-identity. Otherwise assert with tolerances only where the product allows it.
- Nested and repeated fields: specify the full structure, including empty versus omitted.

### 3. Encode matrix

The table below is the skeleton of a matrix test. Each cell asserts that decoding recovers the fixture’s logical fields.

| Encoder \ Decoder | Python | Rust | C (protobuf-c) |
|-------------------|--------|------|----------------|
| Python | A→A round-trip (logical assert) | A→B cross-decode (logical assert) | A→B cross-decode (logical assert) |
| Rust | A→B cross-decode | A→A round-trip | A→B cross-decode |
| C | A→B cross-decode | A→B cross-decode | A→A round-trip |

Every cell asserts `logical_equal(fixture, decode(encode(fixture)))`. The diagonal is same-language round-trip. Off-diagonal cells are cross-language interop. A minimum useful set is **all round-trips** plus **each encoder once into each other decoder**.

### 4. Assert logical equality, not only `memcmp`

```text
for each pair (enc_lang, dec_lang):
  bytes = encode_lang(fixture)
  out = decode_lang(bytes)
  assert logical_equal(fixture, out)  # field-wise
```

Optionally:

```text
assert encode_python(fixture) == encode_rust(fixture)  # bit-identity (strict)
```

If bit-identity fails but logical cross-decode works, document **why** (field order, default omission, map order). That documentation is itself a useful artifact. It shows you understand the format, not only the test harness.

### 5. Golden vectors for the subset you hand-rolled

Use the [lab](lab-mini-protobuf-encoder.md) goldens (for example `08 01 12 03 41 64 61`) as the **minimal cross-runtime test**. Encode the same logical `MiniUser` in Python, Rust, and C. Then decode in the other two runtimes. That is the cheapest way to prove that your three implementations actually speak the same wire language.

### 6. Track known semantic footguns

| Footgun | What breaks |
|---------|-------------|
| proto3 default omission | One side sets `0` or `""` explicitly; the other omits the field; both encodings can be valid |
| Enum unknown values | Preservation versus error differs by runtime and settings |
| UTF-8 validation | Strict versus lenient string decode |
| `int64` in JSON mapping | Not wire binary—but dual APIs confuse tests |
| Float ordering / NaN | Equality and bit patterns |
| Field name vs number | Codegen renames (`FirstName` vs `first_name`)—the wire carries numbers only |
| Benchmark runner mapping | Suite `prepare` converts domain objects—bugs can look like codec bugs |

### 7. Separate benchmark runner fidelity from product fidelity

This suite may:

- Convert fixtures to native messages **outside** timed paths.
- Apply language-specific compare callbacks (in C, the per-serializer compare function is often named something like `fidelity_fx`—a **suite-local round-trip check**, not multi-language proof).
- Exclude fixtures that a given language schema does not define.

Passing suite fidelity means **that language entry** round-trips under **that** compare function. It does not mean that three languages share the same bytes.

## MiniUser matrix runbook (~10 minutes)

Teaching schema only—create `mini.proto` (same as the [lab](lab-mini-protobuf-encoder.md)). It is **not** the suite `schemas/v2/protobuf/benchmark_v2.proto`.

**Logical fixture:** `MiniUser { id = 1, name = "Ada" }`  
**Golden:** `08 01 12 03 41 64 61`

| Step | Action |
|------|--------|
| 1 | Write `mini.proto` with MiniUser fields 1–4 as in the lab. |
| 2 | **Python:** `protoc --python_out=. mini.proto` → `mini_pb2.MiniUser`, set fields, call `SerializeToString()`, assert hex equals the golden (or logical equality after parse). |
| 3 | **Rust:** `prost-build` on `mini.proto` (or a temporary `build.rs`), call `encode_to_vec()`, same asserts. |
| 4 | **C:** `protoc --c_out=. mini.proto`, pack with protobuf-c (or label nanopb separately—**do not mix engines mid-matrix without labeling**). |
| 5 | Cross-decode: feed each language’s bytes into the other two decoders; check `id==1` and `name=="Ada"`. |
| 6 | Record whether the three encodes are bit-identical (`memcmp` or `==` on bytes). |
| 7 | Append the unknown field `28 63` to the Python bytes; confirm Rust and C still yield id and name (skip-unknown). |

Optional second fixture: lab G5 `1a 02 08 02` (nested manager) for nested LEN confidence.

## Worked mini protocol (summary)

1. Take the lab message `MiniUser { id=1, name="Ada" }`.
2. Encode with Python `SerializeToString`, Rust `encode_to_vec`, and C `protobuf_c_message_pack` (or nanopb if that is your C choice—label it).
3. Decode each blob with the other two runtimes.
4. Record whether the encodes are bit-identical.
5. Append the unknown field `28 63` and confirm logical id and name still round-trip where skip-unknown works.

## Decision frame: when bit-identity matters

| Need | Practice |
|------|----------|
| Cache key = hash(bytes) | Force one encoder, or use a canonical deterministic mode |
| Digital signature over payload | Same—canonicalize, or sign logical fields instead of raw bytes |
| Multi-language microservices | Interoperability matrix; bit-identity is optional |
| Debugging “who is wrong?” | Golden vector plus one reference implementation |

## In this suite

| Asset | Fidelity role |
|-------|----------------|
| `schemas/v2/protobuf/benchmark_v2.proto` | Shared field numbers for suite types |
| Python `protobuf` / Rust `prost` / C Google `protobuf` (+ C helper rows) | Separate encode paths (pins and honesty notes are on the language articles / [C Overview](../../c/index.md)) |
| Per-language fidelity hooks | Local round-trip checks only |
| Dashboard / ops | **Not** interoperability proofs |
| [301 multi-language systems (polyglot estates)](../301/polyglot-estates.md) | One **product** contract; this page tests **bytes and logic** |

## Common mistakes

- Declaring victory from three green language Dashboard charts.
- Testing only A→A round-trips.
- Comparing floats with `==` across languages without a policy.
- Mixing nanopb static limits with “full” protobuf-c fixtures and calling the mismatch a wire bug.
- Editing generated code in one language only (schema drift).
- Using suite fixtures for a first matrix when MiniUser goldens are enough.

## What this article is not

- A full suite of tests that check every language implements the same contract (use upstream Protocol Buffers conformance tests for serious work).
- Product advice on JSON versus Protocol Buffers ([301](../301/index.md)).
- Engine deep-dives (see the language-path articles).

## Key takeaways

- Require **cross-decode interoperability**. Treat **bit-identical encode** as an optional strict check.
- Prove fidelity with **matrix tests and goldens**, not with benchmark ranks.
- Defaults, packing, and benchmark runner mapping cause most “Protocol Buffers mismatch” bugs.
- Suite fidelity is not multi-runtime fidelity. Bridge them with explicit tests you own.
