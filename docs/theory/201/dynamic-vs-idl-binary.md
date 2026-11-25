# 2.6 Dynamic vs. IDL Binary Formats

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/leo-gan/GLD.SerializerBenchmark/blob/master/docs/theory/notebooks/201/dynamic_vs_idl_binary.ipynb)

## Problem Statement

Once an engineering team determines that text JSON is too verbose or CPU-intensive for a given hop, two primary binary alternatives emerge:

1. **Dynamic (schemaless) binary formats**—such as MessagePack, CBOR, and BSON—which preserve a JSON-like dynamic data model while replacing decimal text with binary type tags.
2. **IDL / schema-driven binary formats**—such as Protocol Buffers, Thrift, and Avro—which define record layouts out of band in an Interface Definition Language (IDL) and omit field names from the wire.

Choosing between them depends primarily on **data-model stability and cross-team contract longevity**, rather than binary speed alone.

---

## Mechanisms Compared

```text
                       Binary encoding needed
                                 │
              ┌──────────────────┴──────────────────┐
              ▼                                     ▼
     Dynamic binary (no IDL)               IDL / schema binary
     MessagePack, CBOR, BSON               Protocol Buffers, Thrift, Avro
     · Type tags + string keys on wire     · Field numbers / schema order
     · Flexible maps, low build ceremony   · Generated types + CI evolution rules
```

### Dynamic Binary (MessagePack / CBOR Class)

Dynamic binary encodings mirror JSON's dynamic tree (maps, arrays, integers, floats, strings, booleans, null) while adding native raw binary byte-string types (and, in CBOR and BSON, extensible semantic tags such as timestamps).[^1][^2] For a record `{id: 42, label: "x"}`, a MessagePack map emits roughly:

```text
  [map(2)]  [str(2) "id"]  [fixint 42]  [str(5) "label"]  [str(1) "x"]
```

Decimal digit parsing disappears, yet structural type tags and repeated string keys remain on the wire unless the application explicitly switches to positional arrays (which reintroduces an implicit positional contract). Validation and compatibility remain application-level responsibilities.

### IDL Binary (Protocol Buffers Class)

An IDL declares message structure once (`message Item { int32 id = 1; string label = 2; }`), and compilers generate typed encoders and decoders for each target language.[^3] On the wire, field numbers (`1`, `2`) replace `"id"` and `"label"`, shrinking payloads and allowing generated decoders to dispatch on small integer tags without hashing string keys. Unknown field numbers can be skipped safely by wire type ([2.5 Schema evolution](schema-evolution.md)).

### Side-by-Side Comparison for `{id: 42, label: "x"}`

| Encoding Class | Wire Metadata | Inspectable Without Schema? | Typical Size Tendency |
|---|---|---|---|
| **JSON text** | Delimiters + string keys + decimal text | Yes (human-readable) | Largest |
| **Dynamic binary (map)** | Binary type tags + string keys | Yes (via generic decoder) | Smaller than JSON; keys still repeat |
| **IDL binary (tagged)** | Field numbers + wire types | Wire types only; names require IDL | Smallest for stable multi-field records |

*(Note: Comparing two schema-driven cultures—such as Protocol Buffers vs. Avro—is distinct and examined in Part III; zero-copy offset layouts such as FlatBuffers are covered in [2.7 Zero-copy layouts](zero-copy.md).)*

---

## Trade-Offs and Selection Criteria

| Axis | Dynamic Binary (MessagePack, CBOR) | IDL Binary (Protocol Buffers, Thrift) |
|---|---|---|
| **Wire density** | Smaller than JSON; string keys limit density on short records | High density; field names absent on wire |
| **CPU cost** | Fast parsers exist; map key hashing remains unless positional | Very strong with compile-time codegen; weaker if purely reflective |
| **Model flexibility** | High; accommodates ad-hoc, rapidly evolving document shapes | Deliberate; schema updates flow through codegen and review |
| **Multi-language rigor** | Broad library support; type drift across teams is easy | Generated types keep polyglot services aligned |
| **Build & CI complexity** | Minimal (add library dependency only) | Requires pinned IDL compilers, codegen steps, and compatibility checks |
| **Observability** | Generic CLI tools print readable maps/trees | Requires schema registries or compiled descriptors for log decoding |

### When Each Class Fits

- **Prefer dynamic binary** for internal caches, session stores, or telemetry documents whose keys change rapidly across experiments and where avoiding a schema-compiler pipeline matters more than strict multi-year contracts. Still validate untrusted inputs at runtime.
- **Prefer IDL binary** for long-lived, multi-language RPC interfaces or event backbones owned by separate teams, where static generated types and automated breaking-change checks prevent runtime surprises.

---

## Connection to the Benchmark Suite

This suite benchmarks both classes across most languages (e.g., `msgpack`, `cbor2`, `msgpackr`, `rmp-serde`, `zbor` alongside `protobuf`, `avro`, `flatbuffers`, and `sbe`; see [Families](../../analysis/families.md)). Note that implementation design can narrow or invert class expectations: for instance, Python `msgspec-msgpack` using positional `array_like=True` structs omits map keys and behaves closer to a positional schema codec than generic dictionary MessagePack ([Python: msgspec-msgpack vs. orjson](../401/python-msgspec-vs-orjson.md)). Always compare within one language, data set, and data type on the [Dashboard](../../dashboard/index.html).

---

## Exercises

1. **Key-overhead threshold:** Consider an array of 10,000 small records `{lat: 47.6, lon: -122.3, alt: 54.0}`. Why does MessagePack (map mode) show a far larger wire-size penalty relative to Protocol Buffers on this payload than on a single record containing one 50 KB UTF-8 text body?

??? note "Solution"
    On 10,000 tiny records, repeating the three string keys (`"lat"`, `"lon"`, `"alt"`) 10,000 times adds ~120 KB of pure key overhead in MessagePack maps, whereas Protocol Buffers uses 1-byte field tags. On a single record holding a 50 KB text body, field-name metadata is only ~10–20 bytes (<0.05% of total size), so wire sizes of JSON, MessagePack, and Protocol Buffers converge closely.

2. **Positional MessagePack trade-off:** A team encodes MessagePack records as positional arrays (`[42, "x"]`) instead of maps (`{"id": 42, "label": "x"}`) to cut wire size by 50%. What operational property of dynamic binary did they just give up?

??? note "Solution"
    They gave up **self-description and safe field reordering/evolution**. Both producer and consumer now depend on an undocumented positional contract: inserting, reordering, or dropping a middle element silently shifts all subsequent slots for older readers without type-tag or field-number protection.

3. **Class choice:** Choose between CBOR and Protocol Buffers for *(a)* an internal Go–Java–Rust order-processing RPC service with a 5-year compatibility guarantee, and *(b)* an ephemeral Redis cache storing dynamic A/B feature-flag payloads owned by one Python web team.

??? note "Solution"
    - *(a)* **Protocol Buffers:** Long retention and three independent language teams benefit directly from a versioned IDL, generated types, and CI breaking-change checks.
    - *(b)* **CBOR (or MessagePack / fast JSON):** Single team, short TTL, and rapidly changing nested flag shapes favor low-ceremony dynamic encoding paired with application-side validation.

---

## References

[^1]: Bormann, C., & Hoffman, P. (2020). *Concise Binary Object Representation (CBOR)*. IETF RFC 8949. <https://www.rfc-editor.org/rfc/rfc8949>
[^2]: Furuhashi, S. *MessagePack Specification*. <https://github.com/msgpack/msgpack/blob/master/spec.md>
[^3]: Protocol Buffers Documentation. *Language Guide (proto3) and Encoding*. <https://protobuf.dev/programming-guides/proto3/>
