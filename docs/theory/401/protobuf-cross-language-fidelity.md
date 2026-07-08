# Same bytes, three runtimes

## Problem

“We all use Protobuf” does not guarantee that Python, Rust, and C produce **bit-identical** payloads or that round-trips preserve every logical field across languages. Fidelity bugs hide in defaults, field naming, timestamps, packed repeated, UTF-8, and test harness mapping—not in the marketing name.

## Short answer

**Fidelity** here means: given one logical value and one `.proto`, each runtime’s encode/decode behaves as a correct Protobuf implementation for that schema, and **cross-language** pairs interoperate for the fields you care about. Prefer proving interoperability with **golden vectors** and **matrix tests** (encode in A, decode in B), not with suite speed tables. This suite’s harnesses are **per-language**; they do not automatically prove cross-runtime byte identity ([301 polyglot estates](../301/polyglot-estates.md) is product contract choice; this page is **byte/logic discipline**).

Assumes [wire format](protobuf-wire-format.md) and at least one language path ([Python](protobuf-python.md), [Rust](protobuf-rust-prost.md), [C](protobuf-c-protobuf-c.md)).

This monorepo already has Python, Rust, and C Protobuf entries—use them when available. Outside the suite, the same discipline applies with any three official runtimes.

## Prerequisites

- Shared schema discipline (`schemas/benchmark_data.proto` in this repo, or a tiny shared `mini.proto`).  
- Soft: [301 using this suite](../301/using-this-suite.md)—do not use Results as fidelity proofs.

## Mental model

```text
  logical value  ──A.encode──►  bytes₁
  logical value  ──B.encode──►  bytes₂

  bytes₁ ──B.decode──► logical'   must equal logical (for agreed fields)
  bytes₂ ──A.decode──► logical''

  bytes₁ == bytes₂ ?   nice when true; NOT required by the Protobuf spec
```

Protobuf requires **semantic** compatibility (decode understands encode), not that two encoders emit the same field order or the same omission pattern for defaults.

## What “same bytes” can mean (be precise)

| Claim | Meaning | Required by spec? |
|-------|---------|-------------------|
| **Interoperable** | A’s bytes decode in B to the same logical fields | **Yes** (for the schema subset you use) |
| **Bit-identical encode** | A and B produce equal `bytes` for one value | **No** |
| **Harness fidelity** | Serialize then deserialize in **one** language matches fixture compare | Suite-local only |
| **Canonical encode** | Deterministic field order / map order | Optional (`deterministic` in some APIs) |

Serializer developers should chase **interoperability** first; bit-identity second (debugging, signing, caches).

## Step-by-step fidelity discipline

### 1. Freeze the schema

- One `.proto` (or generated sources from one commit).  
- No silent field renumbering.  
- Document packed vs unpacked repeated if versions differ.

### 2. Freeze the logical fixture

Define values in a language-neutral way:

- Integers and bools exact.  
- Strings: Unicode code points (not “whatever my editor saved”).  
- Timestamps: explicit unit (suite often uses ms—see harness notes).  
- Floats/doubles: prefer values with exact binary reps when asserting bit-identity; otherwise assert with tolerances only where product allows.  
- Nested/repeated: full structure, including empty vs omitted.

### 3. Encode matrix

| Encoder \ Decoder | Python | Rust | C (protobuf-c) |
|-------------------|--------|------|----------------|
| Python | A→A round-trip (logical assert) | A→B cross-decode (logical assert) | A→B cross-decode (logical assert) |
| Rust | A→B cross-decode | A→A round-trip | A→B cross-decode |
| C | A→B cross-decode | A→B cross-decode | A→A round-trip |

Every cell asserts `logical_equal(fixture, decode(encode(fixture)))`. Diagonal = same-language round-trip; off-diagonal = cross-language interop. Minimum useful set: **all round-trips** + **each encoder once into each other decoder**.

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

If bit-identity fails but logical cross-decode works, document **why** (field order, default omission, map order).

### 5. Golden vectors for the subset you hand-rolled

Use the [lab](lab-mini-protobuf-encoder.md) goldens (e.g. `08 01 12 03 41 64 61`) as the **minimal cross-runtime test**. Encode the same logical `MiniUser` in Python, Rust, and C, then decode in the other two runtimes. This is the cheapest way to prove that your three implementations actually speak the same wire.

### 6. Track known semantic footguns

| Footgun | What breaks |
|---------|-------------|
| proto3 default omission | One side sets `0`/`""` explicitly, other omits; both valid |
| Enum unknown values | Preservation vs error differs by runtime/settings |
| UTF-8 validation | Strict vs lenient string decode |
| `int64` in JSON mapping | Not wire binary—but dual APIs confuse tests |
| Float ordering / NaN | Equality and bit patterns |
| Field name vs number | Codegen renames (`FirstName` vs `first_name`)—wire is numbers only |
| Harness mapping | Suite `prepare` converts domain objects—bugs look like codec bugs |

### 7. Separate harness fidelity from product fidelity

This suite may:

- Convert fixtures to native messages **outside** timed paths.  
- Apply language-specific compare callbacks (in C, the per-serializer compare function often named something like `fidelity_fx`—**suite-local round-trip check**, not multi-language proof).  
- Exclude types Protobuf cannot express (`ObjectGraph`, bare `Integer` in some langs).

Passing suite fidelity means **that language entry** round-trips under **that** compare function—not that three languages share bytes.

## MiniUser matrix runbook (~10 minutes)

Teaching schema only—create `mini.proto` (same as the [lab](lab-mini-protobuf-encoder.md)); it is **not** suite `benchmark_data.proto`.

**Logical fixture:** `MiniUser { id = 1, name = "Ada" }`  
**Golden:** `08 01 12 03 41 64 61`

| Step | Action |
|------|--------|
| 1 | Write `mini.proto` with MiniUser fields 1–4 as in the lab. |
| 2 | **Python:** `protoc --python_out=. mini.proto` → `mini_pb2.MiniUser`, set fields, `SerializeToString()`, assert hex equals golden (or logical equal after parse). |
| 3 | **Rust:** `prost-build` on `mini.proto` (or temporary `build.rs`), `encode_to_vec()`, same asserts. |
| 4 | **C:** `protoc --c_out=. mini.proto`, pack with protobuf-c (or label nanopb separately—**do not mix engines mid-matrix without labeling**). |
| 5 | Cross-decode: each language’s bytes → other two decoders → `id==1`, `name=="Ada"`. |
| 6 | Record whether the three encodes are bit-identical (`memcmp` / `==` on bytes). |
| 7 | Append unknown field `28 63` to Python bytes; confirm Rust and C still yield id/name (skip-unknown). |

Optional second fixture: lab G5 `1a 02 08 02` (nested manager) for nested LEN confidence.

## Worked mini protocol (summary)

1. Take lab message `MiniUser { id=1, name="Ada" }`.  
2. Encode with Python `SerializeToString`, Rust `encode_to_vec`, C `protobuf_c_message_pack` (or nanopb if that is your C choice—label it).  
3. Decode each blob with the other two.  
4. Record whether encodes are bit-identical.  
5. Append unknown field `28 63` and confirm logical id/name still round-trip where skip-unknown works.

## Decision frame: when bit-identity matters

| Need | Practice |
|------|----------|
| Cache key = hash(bytes) | Force one encoder, or canonical deterministic mode |
| Digital signature over payload | Same—canonicalize or sign logical fields |
| Multi-language microservices | Interoperability matrix; bit-identity optional |
| Debugging “who is wrong?” | Golden vector + one reference implementation |

## In this suite

| Asset | Fidelity role |
|-------|----------------|
| `schemas/benchmark_data.proto` | Shared field numbers for suite types |
| Python `protobuf` / Rust `prost` / C `protobuf-c` & `nanopb` | Separate encode paths (pins on language articles) |
| Per-language fidelity hooks | Local round-trip checks only |
| Results / ops | **Not** interoperability proofs |
| [301 polyglot estates](../301/polyglot-estates.md) | One **product** contract; this page tests **bytes/logic** |

## Common mistakes

- Declaring victory from three green language Results charts.  
- Testing only A→A round-trips.  
- Comparing floats with `==` across languages without a policy.  
- Mixing nanopb static limits with “full” protobuf-c fixtures and calling it a wire bug.  
- Editing generated code in one language only (schema drift).  
- Using suite Person for a first matrix when MiniUser goldens are enough.

## What this article is not

- A full conformance suite (use upstream Protobuf conformance tests for serious work).  
- Product advice on JSON vs Protobuf ([301](../301/index.md)).  
- Engine deep-dives (see language path articles).

## Key takeaways

- Require **cross-decode interoperability**; treat **bit-identical encode** as optional/strict.  
- Prove with **matrix tests and goldens**, not benchmark ranks.  
- Defaults, packing, and harness mapping cause most “Protobuf mismatch” bugs.  
- Suite fidelity ≠ multi-runtime fidelity—bridge them with explicit tests you own.
