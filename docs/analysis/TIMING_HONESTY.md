# What the timer is allowed to measure

This page is the suite’s **timing contract**. Every language runner and every serializer adapter must follow it. [Architecture](architecture.md) describes the loop. This page says **which work** belongs in each step.

If two adapters on the same Dashboard slice time different work, the rank is not a library comparison. The google-protobuf JavaScript row once encoded in `prepare` and timed a `Buffer` copy. That was a contract violation, not a fast encoder.

## The three steps

The runner calls three methods. Only two are timed.

| Step | When | Timed? | Allowed work | Forbidden work |
|------|------|--------|--------------|----------------|
| **prepare** | Once per cell, before the loop | **No** | Load a schema. Build or compile an encoder. Bind a type-specific function. Convert the suite value into the **library’s in-memory message** (a struct, a generated protobuf object, a `Document` DOM). Allocate reusable buffers. | Write the **output bytes**. Cache a finished encoding and hand it back later. |
| **serialize** | Every repetition | **Yes** | Walk that in-memory message and **emit bytes** (or the language’s in-memory equivalent). | Return a copy of bytes written in `prepare`. Rebuild the schema. Re-bind the type. |
| **deserialize** | Every repetition | **Yes** | Read those bytes and rebuild the library’s in-memory message. | Skip the library and parse with a second library “for convenience,” then ignore the first result. |

Fidelity (does the value still mean the same thing?) runs **after** deserialize. It is not timed.

```text
  suite value
       │
       ▼
  prepare          untimed     suite value → library message
       │
       ▼
  serialize        TIMED       library message → bytes
       │
       ▼
  deserialize      TIMED       bytes → library message
       │
       ▼
  to-domain        untimed     library message → suite value  (when the runner has this hook)
       │
       ▼
  fidelity         untimed     compare suite values
```

## One sentence

**The timer measures encode and decode. It does not measure setup. It does not measure a copy of work that already finished.**

## What “library message” means

The library’s normal in-memory type:

- Protocol Buffers: a generated `Message`, a protobufjs message, a `BinaryWriter` input object already built
- JSON with a DOM library: a `Document` / `JsonDocument` / `nlohmann::json` object
- JSON with `JSON.stringify`: the plain JavaScript object (there is no other native type)
- Speedy / Bitsery / custom-binary: the language struct itself

Building that object is **prepare**. Writing it out is **serialize**.

## Hard rules

1. **Do not cache output bytes in `prepare`.**  
   If `serialize` only copies a `string`, `Vec<u8>`, or `Buffer` that `prepare` already filled, the encode column is a memcpy. That is a bug. Parse-only libraries (simdjson has no encoder) must still **write JSON during `serialize`**, or the row must not report an encode time as if it were that library.

2. **Do not time schema compile, type registration, or `MakeGenericMethod`.**  
   Those belong in `prepare`. If the first timed call still builds the serializer, the first repetition is warmup (dropped) but later reps must not rebuild it.

3. **Domain ↔ library maps are untimed when the runner can do it — except a 401 pair that must share one end-to-end path.**  
   C#, Go, and most Java/Swift rows convert back to the suite value **after** the timer. The Java Protostuff / protobuf-java pair and the Swift FlatBuffers / SwiftProtobuf pair time suite value → bytes → suite value on both sides, because one library’s native type *is* the suite object.

4. **Both adapters in one 401 comparison must time the same kind of work.**  
   Those two pairs now share the suite-value path. Do not revert one adapter to “prepared native only” without changing the other.

5. **Encode N instances when the cell says N.**  
   `DataTypeInstanceCount=100` means the timed call encodes 100 values (or one documented batch frame of 100). Encoding one value and writing `100` is a critical bug.

6. **Stream mode must be a different API, or it must be labelled `adapted`.**  
   Bytes-then-`write` is not a native stream path.

7. **The row name must match the timed functions.**  
   A row named `simdjson` may use simdjson on decode. If encode is `nlohmann::json::dump`, the article and the inventory must say so. A row named `google-protobuf` must call that library’s writer on the timed encode.

## Allowed exceptions (must be labelled)

| Exception | Why it exists | How to label it |
|-----------|---------------|-----------------|
| Parse-only library (no public encoder) | simdjson is a parser | Encode is another JSON writer, timed. Decode is the parser. The 401 simdjson page is the model. |
| C# in-memory path is a `string` | Many .NET APIs return strings | Binary codecs often Base64 that string. Both sides of a C# pair must do the same. Do not compare those nanoseconds to a Rust `Vec<u8>` row. |
| Envelope / teaching wrapper | C `ubj` wraps custom-binary | The 401 page must say the envelope is the measured extra work. |
| In-place layout used as a classical decoder | rkyv `from_bytes` builds an owned struct | The 401 rkyv page must say `access` is not timed. |
| 401 pair whose other library has no separate native type | Protostuff and FlatBuffers encode the suite object | Both sides time suite value → bytes → suite value. |

If you need a new exception, write it on the language Overview **and** next to the Dashboard claim. Do not invent a silent one.

## How to check one adapter

Open the adapter. Answer four questions. All four must be yes, or the row is dishonest.

1. Does `prepare` stop before any function that **returns the encoded payload**?
2. Does timed `serialize` call the library’s **encode / dump / write / toBinary / SerializeToArray** (or the documented stand-in)?
3. Does timed `deserialize` call the library’s **decode / parse / read / fromBinary / ParseFromArray**?
4. If this adapter is compared with another in a 401 article, do both time the same kind of object (suite value vs prepared native message) on both encode and decode?

## Audit of the 401 comparison pairs

Checked against the adapters in this repository after the google-protobuf encode fix.

| Article | What the two timed paths actually do | Contract |
|---------|--------------------------------------|----------|
| [Python: orjson vs json](../theory/401/python-orjson-vs-json.md) | Both dump/load a prepared dict | Same work. Honest. |
| [Python: msgspec-msgpack vs orjson](../theory/401/python-msgspec-vs-orjson.md) | Struct encode vs dict JSON; maps untimed | Different layouts, same clock rule. Honest. |
| [Python: msgspec JSON vs MessagePack](../theory/401/python-msgspec-json-vs-msgpack.md) | Same Struct, two encoders | Same work. Honest. |
| [Rust: Speedy vs Bincode](../theory/401/rust-speedy-vs-bincode.md) | Speedy writes a `Document`. Bincode writes a `Fixture` enum through Serde | **Wrapper asymmetry**, already stated in the article. |
| [Rust: Speedy vs Postcard](../theory/401/rust-speedy-vs-postcard.md) | Same asymmetry as above | Documented. |
| [Rust: rkyv vs Speedy](../theory/401/rust-rkyv-vs-speedy.md) | Both fill an owned `Document`; rkyv does not use `access` | Documented. Honest for that choice. |
| [C: custom-binary vs ubj](../theory/401/c-custom-binary-vs-ubj.md) | ubj encodes custom-binary, then an envelope | Documented. Honest for that choice. |
| [C++: Bitsery vs YAS](../theory/401/cpp-bitsery-vs-yas.md) | Both encode the C++ value | Same work. Honest. |
| [C++: simdjson](../theory/401/cpp-simdjson-wrapper.md) | Encode is nlohmann `dump` of a prepared object. Decode is simdjson parse, then a DOM walk | Encode is **not** simdjson. Must stay labelled. |
| [C#: BinaryPack vs Bond Fast](../theory/401/csharp-binarypack-vs-bond.md) | Both encode then Base64 on the string path | Same extra work. Honest **within C#**. |
| [Go: kelindar vs Avro](../theory/401/go-kelindar-vs-avro.md) | Both encode domain structs | Same work. Honest. |
| [Java: Protostuff vs protobuf-java](../theory/401/java-protostuff-vs-protobuf.md) | Both time suite `Document` → bytes → suite `Document`. protobuf-java still builds a generated message in the middle | Same work at the suite boundary. |
| [JavaScript: JSON vs google-protobuf](../theory/401/javascript-json-vs-protobuf.md) | Both encode and decode on the clock | Same work. Honest (after the copy bug was fixed). |
| [JavaScript: three protobufs](../theory/401/javascript-three-protobufs.md) | All three encode in `serialize`. Decode rebuilds a library message; `toDomain` copies after the timer | Encode is the same kind of work. Decode implementations still differ. |
| [Swift: FlatBuffers vs SwiftProtobuf](../theory/401/swift-flatbuffers-vs-protobuf.md) | Both time suite `Document` → bytes → suite `Document` | Same work at the suite boundary. |

## Remaining contract gaps (not 401 pairs)

These rows violate the contract or mix two contracts. They are listed so a later change can close them. They are **not** silent.

| Gap | Where | What is wrong |
|-----|--------|----------------|
| Domain map on the clock | C `protobuf` `to_proto` / `from_proto` on every timed call | The C runner passes a distinct fixture per instance, so convert-in-prepare cannot cover N>1 without a `prepare_many` hook. Rust `prost` now converts every instance in untimed `prepare_many`. |
| Fixture vs inner struct | Rust Serde rows vs Speedy / rkyv / minicbor | Same as the 401 Speedy articles. Documented, not a silent bug. |
| Envelope instead of native model | C avro-c, flatcc, ubj | Timed path wraps custom-binary. Teaching rows; see the C 401 article. |
| C nanopb / protobuf-c / protobuf-wire | C schema rows | Same in-tree `pb_v2_encode` body under three names. Wiring the real libraries is a separate implementation task. |
| Some C# XML/JSON ctors still lazy | DataContract XML, XmlSerializer | Warmup drops rep 0. Bond now builds in `Initialize`. |

## Related pages

- [Architecture — what we measure](architecture.md#measurement-model)
- [Adding a serializer — timing honesty](ADDING_A_SERIALIZER.md#timing-honesty)
- [Modes](modes.md)
- [Serialization 401](../theory/401/index.md)
