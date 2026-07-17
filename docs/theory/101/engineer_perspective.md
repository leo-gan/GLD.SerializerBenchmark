# Engineering Perspective

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/leo-gan/GLD.SerializerBenchmark/blob/master/docs/theory/notebooks/101/engineering_perspective.ipynb)
**Lab notebook:** [Engineering mini lab](../notebooks/101/engineering_perspective.ipynb) · JavaScript companion: [api_decision_sketch.mjs](../notebooks/companions/js/api_decision_sketch.mjs)

## Who this page is for

- Backend and platform engineers choosing API and [remote procedure call (RPC)](https://en.wikipedia.org/wiki/Remote_procedure_call "RPC — Remote Procedure Call")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> payloads  
- Performance-minded developers who care about processor time, allocations, and latency tails  
- Anyone who must deserialize **untrusted** input  
- Engineers aligning local choices with a multi-language estate  

---

## Four families (aligned with this suite)

The benchmark suite groups serializers into paradigms. Compare **within one paradigm and within one language** before crowning a global winner.

| Family | Examples | Schema on the wire | Human-readable | Typical home |
|--------|----------|--------------------|----------------|--------------|
| **Text / [JSON](https://en.wikipedia.org/wiki/JSON "JSON — JavaScript Object Notation")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> family** | JSON; sometimes [XML](https://en.wikipedia.org/wiki/XML "XML — Extensible Markup Language")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> or [YAML](https://en.wikipedia.org/wiki/YAML "YAML — human-friendly data serialization language")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> at edges | Optional or external | Yes | Public APIs, configuration, debug-friendly logs |
| **Schemaless binary** | [MessagePack](https://en.wikipedia.org/wiki/MessagePack "MessagePack — binary serialization of JSON-like values")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />, [CBOR](https://en.wikipedia.org/wiki/CBOR "CBOR — Concise Binary Object Representation")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />, [BSON](https://en.wikipedia.org/wiki/BSON "BSON — Binary JSON (MongoDB)")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />, many “binary JSON” codecs | Type tags or field names often present | No | Internal services, caches, queues |
| **Schema-driven** | [Protocol Buffers](https://en.wikipedia.org/wiki/Protocol_Buffers "Protocol Buffers — schema-driven binary format")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />, [Avro](https://en.wikipedia.org/wiki/Apache_Avro "Apache Avro — row-oriented binary with schemas")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />, [FlatBuffers](https://en.wikipedia.org/wiki/FlatBuffers "FlatBuffers — zero-copy serialization library")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />, Bond, many [interface description language (IDL)](https://en.wikipedia.org/wiki/Interface_description_language "IDL — Interface Description Language")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> tools | Numbers or layout from a schema | No | Stable contracts, high-throughput RPC and streams |
| **Language-native** | [pickle](https://en.wikipedia.org/wiki/Serialization#Python "pickle — Python object serialization")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />, [Java serialization](https://en.wikipedia.org/wiki/Java_serialization "Java object serialization — JVM native object encoding")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />, legacy .NET binary formatters | Runtime type metadata | No | Same-stack caches and graphs (**trust carefully**) |

### Decision sketch for services

Work through these questions in order:

1. **Do people need to read or edit the payload on the wire?**  
   - **Yes** → stay in the JSON family (add JSON Schema or OpenAPI when contracts matter).  
   - **No** → continue.  
2. **Do you need a shared IDL or schema and multi-language evolution rules?**  
   - **Yes** → schema-driven (Protocol Buffers-like, Avro-like, or zero-copy IDL designs).  
   - **No** → continue.  
3. **Is this a single language and runtime, with complex graphs and fully trusted data?**  
   - **Yes** → language-native formats only inside a hard trust boundary.  
   - **No** → schemaless binary (MessagePack, CBOR, and similar) **and** validation at the edges.

---

## Text-based interchange

**JSON** is the default public contract: universal parsers, easy logging, mediocre density and parse cost. Gaps (dates, binary data, integer versus floating-point numbers) are managed by **convention** or by a validation layer ([JSON Schema](https://en.wikipedia.org/wiki/JSON#Schema_and_metadata "JSON Schema — vocabulary for validating JSON")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />, [OpenAPI](https://en.wikipedia.org/wiki/OpenAPI_Specification "OpenAPI — standard for HTTP API descriptions")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />, typed request models).

**XML** remains in enterprise and document systems. Prefer it when the ecosystem already demands it, not as a greenfield API default.

**YAML** and **[TOML](https://en.wikipedia.org/wiki/TOML "TOML — Tom’s Obvious Minimal Language (config format)")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />** are configuration formats more than wire formats. YAML’s complexity has a long security history with “load untrusted YAML” mistakes—prefer safe loaders and locked-down schemas for untrusted input.

## Schemaless binary

**MessagePack**, **CBOR**, and **BSON** keep a dynamic data model while dropping text parsing. Field names or type tags usually still appear, so they are typically larger than a tight Protocol Buffers encoding but smaller and often faster than JSON.

**Typical engineering uses:** internal [HTTP](https://en.wikipedia.org/wiki/HTTP "HTTP — Hypertext Transfer Protocol")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> or RPC bodies, [Redis](https://en.wikipedia.org/wiki/Redis "Redis — in-memory data structure store")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />-style values, multi-language payloads without an IDL mandate.

**You still own** validation, compatibility, and documentation.

## Schema-driven binary

**Protocol Buffers** use field numbers, code generation, a strong multi-language story, and explicit evolution discipline (do not reuse field numbers; reserve deleted identifiers).

**[Apache Thrift](https://en.wikipedia.org/wiki/Apache_Thrift "Apache Thrift — IDL and RPC framework")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />** pairs an IDL with pluggable protocols and transports. Historically it appears in RPC-centric polyglot stacks.

**Apache Avro** is often chosen when **schema resolution** and data-platform interoperability matter (also covered under the [data science perspective](data_science_perspective.md)). It appears in event pipelines as much as in classical RPC.

**FlatBuffers** and **[Cap’n Proto](https://en.wikipedia.org/wiki/Cap%27n_Proto "Cap’n Proto — zero-copy serialization and RPC")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />** aim for **low-parse or zero-copy** access: excellent read paths, with different mutation and tooling ergonomics than classic “build a struct, then serialize” Protocol Buffers style.

## Language-native formats

These are convenient for object graphs inside one runtime. Treat them as **unsafe by default** on the network or any multi-tenant input path. Prefer portable formats whenever data leaves the process trust domain.

---

## Performance mechanics

Numbers belong on **Results** pages. These are the mechanisms those numbers come from.

### Data locality and processor caches

Modern processors are fast; **random memory access** is not. Serializers that scatter fields through pointer-rich object graphs cause cache misses. Designs that keep related bytes **contiguous** (and zero-copy formats that read from a single buffer) reduce stalls.

When you benchmark, payload **shape** matters as much as codec brand: deep pointer graphs punish every language; dense structures favor contiguous layouts.

### Allocations and [garbage collection](https://en.wikipedia.org/wiki/Garbage_collection_%28computer_science%29 "Garbage collection — automatic memory reclamation")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />

In managed runtimes (C#, Java, Python, JavaScript, Go), **allocation rate** drives garbage-collector work and latency spikes.

| Pattern | Effect |
|---------|--------|
| Allocate a new string or array per field | High garbage-collector pressure under load |
| Decode into reused buffers or pools | Lower allocator traffic |
| Span-like views over existing memory | Avoid copies when APIs allow |
| Zero-copy formats | “Deserialize” may mean bounds-checked views, not new objects |

“Faster serializer” often means **fewer allocations**, not only fewer processor instructions in the encode loop.

### Zero-copy deserialization

The traditional path is: bytes → parse → **new** language objects (a copy).

A **zero-copy** path (FlatBuffers, Cap’n Proto, and some buffer-oriented APIs) arranges the wire layout so fields are readable **in place**. Trade-offs include validation discipline (skipping a parse can skip structural checks if you are careless), less friendly partial mutation, and different operational tooling.

### Text parsing cost

JSON and XML must discover tokens, unescape strings, and convert decimal text to binary numbers. Binary formats largely avoid that work. At scale this is both **processor time** and **energy cost** in the datacenter—not only an academic microbenchmark.

### Size versus speed

Smaller payloads help networks and storage; the fastest codec is not always the smallest. Measure **your** payloads (see the suite topologies) rather than blog leaderboards alone.

---

## Security: deserialization

Untrusted bytes are **hostile input**.

| Risk | Where it shows up | Mitigation |
|------|-------------------|------------|
| **Remote code execution via native deserialize** | Java serialization, pickle, some legacy binary formatters, careless YAML `load` | Never deserialize untrusted native formats; prefer pure data formats plus explicit allowlists |
| **[Billion laughs](https://en.wikipedia.org/wiki/Billion_laughs_attack "Billion laughs — XML entity expansion DoS")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> / entity expansion** | XML | Disable external entities; use safe parser settings |
| **Resource exhaustion** | Huge nested JSON, deeply nested CBOR or MessagePack, unbounded collections | Limits on depth, size, and allocations |
| **Logic bugs from type confusion** | Schemaless JSON (“number or string?”) | Validate with a schema or typed model at the trust boundary |
| **Skipping verification in zero-copy paths** | FlatBuffers-style buffers used without a verifier | Always verify untrusted buffers before use |

**Rule of thumb:** the more powerful the deserializer (arbitrary types, dynamic code), the smaller the set of inputs it may see.

---

## Schema evolution for services

Services rarely deploy all at once. Plan for **old readers with new writers** and the reverse.

| Approach | Practical guidance |
|----------|-------------------|
| **Protocol Buffers field numbers** | Add optional fields; never repurpose numbers; mark deleted identifiers as reserved |
| **JSON and its consumers** | Additive changes are safer; renames break silently; use API versioning when removing fields |
| **Avro compatibility modes** | Encode policy in a registry and continuous integration (backward, forward, or full) |
| **“We will fix it in the client”** | Does not scale past one team |

Document whether fields are required, defaulted, or nullable. A **wire format cannot invent product semantics** by itself.

---

## Operational concerns

- **Debuggability:** JSON in logs versus binary that needs decoders and schema versions in observability tooling  
- **Gateways and service meshes:** some exotic RPC framings interact poorly with ordinary [HTTP/2](https://en.wikipedia.org/wiki/HTTP/2 "HTTP/2 — major revision of HTTP")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> load balancers and serverless edges  
- **Code generation in continuous integration:** schema-driven stacks need stable `protoc` or IDL pipelines and versioned generated artifacts  
- **Polyglot drift:** “we use Protocol Buffers” is incomplete without a shared style guide (well-known types, error model, timestamp policy)  
- **Partial failure:** corrupt and truncated frames need clear errors, not hung parsers  

---

## Worked choice patterns

| Scenario | Reasonable default | Why |
|----------|--------------------|-----|
| Public HTTP API for third parties | JSON plus OpenAPI | Ecosystem and debuggability dominate |
| Internal microservice RPC, multi-language | Protocol Buffers (or similar) over your standard transport | Compact, typed, evolvable |
| Hot cache of dynamic documents | MessagePack, CBOR, or JSON depending on clients | Schemaless binary if all consumers agree |
| Same-process or same-runtime trusted cache | Language-native **only if** the threat model allows | Otherwise portable binary |
| Ultra-low-latency read of large immutable messages | FlatBuffers / Cap’n Proto-class design | In-place access |
| Analytics export from a service | Write **[Parquet](https://en.wikipedia.org/wiki/Apache_Parquet "Apache Parquet — columnar storage format")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />** (or ship to a pipeline that does)—see [data science](data_science_perspective.md) | Do not force online message formats to be your lake |

---

## Illustrative snippets

These snippets are for orientation only—not library endorsements. (Site-wide fenced code uses plain highlighting; see `mkdocs.yml`.)

### JSON (public API style)

```python
import json

payload = {"name": "Alice", "scores": [95, 87]}
text = json.dumps(payload, separators=(",", ":"), sort_keys=True)
obj = json.loads(text)
```

### MessagePack (schemaless binary)

```python
import msgpack

packed = msgpack.packb({"nums": [1, 2, 3]})
assert msgpack.unpackb(packed) == {"nums": [1, 2, 3]}
```

### Protocol Buffers style (after code generation)

```python
# Generated module provides message classes (illustrative Google tutorial names).
person = addressbook_pb2.Person(id=1234, name="Alice")
data = person.SerializeToString()
person2 = addressbook_pb2.Person()
person2.ParseFromString(data)
```

---

## Key takeaways

1. **Pick a paradigm first**, then a library. The suite categories exist to prevent unfair cross-paradigm comparisons.  
2. **Public edge is not the same as an internal hot path.** JSON at the boundary and binary inside is a normal, historical pattern.  
3. **Performance is layout, allocations, and parsing**—not a single brand name.  
4. **Untrusted deserialize is a security boundary.** Native serializers are not “just faster JSON.”  
5. **Evolution is a process** (identifiers, registries, API versions), not only a file format.  
6. **Measure on your payloads** with this suite’s topologies and your language’s **Results**.

---

## References

- RFC 8259 (JSON); JSON Schema and OpenAPI documentation  
- MessagePack specification; CBOR RFC 8949  
- Protocol Buffers language guide and style guides  
- Apache Thrift and Apache Avro project docs  
- Cap’n Proto and FlatBuffers documentation (encoding plus security and verification notes)  
- Language security docs for pickle, Java serialization, and legacy binary formatters  
