# 1.3 Engineering Perspective

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/leo-gan/GLD.SerializerBenchmark/blob/master/docs/theory/notebooks/101/engineering_perspective.ipynb)

Backend services, distributed RPC meshes, caches, and public APIs place simultaneous demands on serialization: low tail latency, bounded memory allocation, safe handling of untrusted input, multi-language interoperability, and zero-downtime schema evolution. This chapter applies the [four-layer model](index.md#the-serialization-model) to service engineering decisions.

---

## Service-Level Format Selection

Decide the **workload** and **standard** before comparing concrete libraries ([how to compare](index.md#how-to-compare); full family overview in [Families](../../analysis/families.md)). For a given network or storage hop, four sequential questions narrow the standard class:

1. **Must humans, browsers, or third-party integrators inspect payloads directly?**
   - *Yes* → Select **JSON** (RFC 8259)[^1] paired with an explicit external contract (OpenAPI or JSON Schema).
2. **Does the hop require a strict, long-lived multi-language contract with generated types and compatibility rules?**
   - *Yes* → Select a **schema-driven binary** standard: Protocol Buffers, Avro, FlatBuffers, Cap'n Proto, Thrift, or SBE.
3. **Is the payload strictly confined to a single trusted runtime and process boundary (or requires full runtime object-graph fidelity)?**
   - *Yes, single trusted runtime only* → A language-native serializer is permissible only with documented trust assumptions and accepted lock-in.
   - *Shared nodes across languages* → Use a portable graph-capable encoding (such as non-packed Dagr layouts; see this suite's `graph` data set).
   - *No* → Select a **schemaless binary** standard (MessagePack or CBOR)[^2] with explicit validation at service edges.
4. **Which library implements that standard best in our runtime?**
   - Open the [Dashboard](../../dashboard/index.html) filtered to the target **Language**, **Standard**, **Data set**, and **Data type**, and verify specification adherence under [Compliance](../../dashboard/index.html#compliance).

### Summary of Service Format Classes

- **Text (JSON, XML, YAML, TOML):** JSON dominates public HTTP APIs for universal tooling and log inspectability. XML remains relevant where legacy enterprise contracts require it. YAML and TOML target human-authored configuration rather than high-throughput RPC; untrusted YAML requires safe loaders and awareness of YAML 1.1 implicit-typing hazards (see [JSON and the web](historical_perspective.md#json-and-the-web)).
- **Schemaless binary (MessagePack, CBOR, BSON):** Retain a JSON-like dynamic model while avoiding decimal text parsing. Suitable for internal caches and volatile payloads; validation and evolution policy remain application responsibilities.
- **Schema-driven binary (Protocol Buffers, Thrift, Avro, FlatBuffers, Cap'n Proto):** Move field names out of band into a shared IDL. Protocol Buffers and Thrift focus on compact RPC messages; Avro focuses on writer/reader schema resolution; FlatBuffers and Cap'n Proto focus on in-place zero-copy reads.
- **Language-native (`pickle`, Java serialization, legacy `.NET BinaryFormatter`):** Treat as unsafe by default on any network, queue, or multi-tenant boundary.

---

## Performance Mechanics

Measured numbers live on the [Dashboard](../../dashboard/index.html); interpreting them requires understanding four underlying hardware and runtime mechanisms (developed quantitatively in [Part II: Mechanisms](../201/index.md)):

### 1. Memory Locality and CPU Caches

Sequential access over contiguous byte buffers exploits hardware prefetching and L1/L2 cache lines. Pointer-chasing across scattered heap objects causes cache misses on every dereference. Consequently, **payload shape** (flat records versus deeply nested object graphs) frequently shifts latency as strongly as format selection.

### 2. Allocation Rate and Tail Latency (GC Pressure)

In garbage-collected runtimes (Java, C#, Go, Python, JavaScript), allocating short-lived objects per field drives GC frequency and degrades **99th-percentile ($p_{99}$) tail latency** even when mean throughput appears acceptable.

| Implementation Pattern | Effect on Allocator and GC |
|---|---|
| Allocate new `String` / map entry per decoded field | High allocation rate; elevated $p_{99}$ GC pause risk |
| Reuse pooled output buffers across calls | Eliminates per-request buffer churn |
| Borrow slices / spans over the input buffer | Avoids heap copies for unescaped string fields |
| Zero-copy layouts (FlatBuffers, Cap'n Proto) | Bounds-checked offset reads instead of full object-graph allocation |

### 3. Zero-Copy Deserialization Trade-Offs

Traditional decoders parse bytes into newly allocated language objects. **Zero-copy** layouts (FlatBuffers, Cap'n Proto, FlexBuffers, Rust `rkyv`, C++ `cista`, Bebop) align fields and relative offsets so readers inspect values directly in the receive buffer. (Note that this suite times Rust `rkyv` as a full materialization into an owned value; see [Zero-copy](../201/zero-copy.md).) Zero-copy reads reduce allocation overhead on large, sparsely accessed, mostly immutable messages, at the cost of non-trivial builder encoding, stricter buffer-lifetime management, awkward in-place mutation, and mandatory buffer verification on untrusted input.

### 4. Text Parsing vs. Wire Density

Text parsers spend CPU cycles on token discovery, UTF-8/escape handling, and decimal–binary numeric conversion. Binary codecs avoid decimal conversion, yet encode/decode speed still depends heavily on implementation architecture (compiled/SIMD codegen vs. runtime reflection). Smaller raw payloads reduce network and storage cost, though on fast local networks CPU and allocation cost often outweigh modest byte savings.

---

## Deserialization Security

Treat every byte crossing an untrusted boundary as potentially adversarial:[^3]

| Threat Class | Affected Formats | Required Mitigation |
|---|---|---|
| **Remote code execution (RCE)** | Java serialization, `pickle`, unsafe YAML `load`, legacy `.NET BinaryFormatter` | Forbid native deserializers on untrusted paths; use pure data formats with allowlisted types |
| **Entity expansion DoS (*billion laughs*)** | XML | Disable external entities and DTD processing in parser configuration |
| **Resource exhaustion** | Deeply nested JSON, CBOR, MessagePack; unbounded arrays or decompression bombs | Enforce strict limits on payload byte length, nesting depth, and decoded element count |
| **Type confusion / logic bypass** | Unvalidated JSON or schemaless binary | Validate decoded payloads against a strict schema or typed model at the ingress boundary |
| **Out-of-bounds reads** | Unverified FlatBuffers / zero-copy buffers | Always run the format's structural verifier before dereferencing untrusted offsets |

**Design invariant:** The more expressive a deserializer is (arbitrary class instantiation, dynamic code loading, recursive references), the narrower the trust boundary it may face.

---

## Schema Evolution and Operational Concerns

Distributed services roll out incrementally, so old readers routinely encounter new messages and vice versa:

- **Protocol Buffers:** Add optional fields with fresh field numbers; never repurpose identifiers; mark deleted numbers and names `reserved`.[^4]
- **JSON APIs:** Treat changes as additive by default; avoid silent renames; version endpoints or media types when breaking removals are unavoidable.
- **Avro / event streams:** Enforce compatibility modes (BACKWARD, FORWARD, FULL) automatically in CI via a schema registry.[^5]

Beyond wire efficiency, production operations depend on **observability** (text logs vs. schema-aware binary decoders), **proxy/gateway compatibility** (HTTP/2 and gRPC framing through load balancers), **CI code-generation reproducibility** (pinned `protoc`/IDL compiler versions), **polyglot conventions** (shared timestamp, decimal, and error representations across languages), and **graceful error handling** on truncated or corrupt frames.

### Common Service Patterns

| Scenario | Typical Default | Primary Rationale |
|---|---|---|
| Public HTTP API for external clients | JSON + OpenAPI / JSON Schema | Minimal integrator friction and direct log inspectability |
| Internal multi-language microservice RPC | Protocol Buffers (or equivalent IDL) | Compact wire format, generated static types, explicit evolution rules |
| Internal cache of volatile documents | MessagePack, CBOR, or fast JSON | Compactness without IDL build ceremony; validate on read/write |
| Large, read-heavy immutable client payloads | FlatBuffers / Cap'n Proto | Sparse in-place reads with minimal decode allocation |
| Analytical export from online services | Parquet (via pipeline) | Separates OLAP lake storage from OLTP message contracts ([Data science perspective](data_science_perspective.md)) |

---

## Illustrative API Patterns

These minimal Python snippets contrast the three common service models (for orientation only, not library rankings):

```python
# 1. Text interchange (JSON)
import json
raw_json = json.dumps({"id": 1234, "scores": [95, 87]}, separators=(",", ":")).encode("utf-8")
parsed = json.loads(raw_json)

# 2. Schemaless binary (MessagePack)
import msgpack
raw_mp = msgpack.packb({"id": 1234, "scores": [95, 87]})
parsed_mp = msgpack.unpackb(raw_mp)

# 3. Schema-driven binary (Protocol Buffers, after code generation)
user = mini_pb2.MiniUser(id=1234, name="Ada")
raw_pb = user.SerializeToString()
user_out = mini_pb2.MiniUser.FromString(raw_pb)
```

---

## Exercises

1. **Tail-latency diagnosis:** A Go service achieves strong mean throughput with a reflection-based JSON codec, yet $p_{99}$ latency spikes under burst load. Name two serialization-level changes that reduce GC pressure *without* changing the public JSON wire contract.

??? note "Solution"
    1. Replace runtime reflection with a code-generated or SIMD-accelerated JSON implementation in the same language (e.g., comparing candidates on the Go JSON Dashboard slice).
    2. Reuse pooled output buffers (`sync.Pool` / `bytes.Buffer`) and decode directly into typed structs rather than `map[string]any`, eliminating per-field heap allocations and map overhead while keeping the identical RFC 8259 JSON contract.

2. **Zero-copy security check:** A service receives FlatBuffers messages from mobile clients over the public internet and skips `VerifyBuffer` to save 8% CPU time. What failure mode does this introduce?

??? note "Solution"
    FlatBuffers accessors follow relative byte offsets embedded directly in the untrusted buffer. Without structural verification (`VerifyBuffer`), a crafted payload containing out-of-range offsets, overlapping tables, or invalid vtables can trigger out-of-bounds memory reads, crashes, or denial of service.

3. **Edge vs. internal split:** Explain why a payment platform should keep JSON on its public merchant API even after measurements show Protocol Buffers is 4× faster on internal Go-to-Rust RPC hops.

??? note "Solution"
    External merchant integrators operate outside the organization's build pipeline and rely on standard HTTP tools, `curl`, and browser debugging—forcing `protoc` codegen onto third parties creates prohibitive integration friction. Internal Go-to-Rust hops share one CI pipeline and high internal fan-out, where IDL discipline and binary efficiency pay off.

---

## References

[^1]: Bray, T. (Ed.). (2017). *The JavaScript Object Notation (JSON) Data Interchange Format*. IETF RFC 8259. <https://www.rfc-editor.org/rfc/rfc8259>
[^2]: Bormann, C., & Hoffman, P. (2020). *Concise Binary Object Representation (CBOR)*. IETF RFC 8949. <https://www.rfc-editor.org/rfc/rfc8949>
[^3]: OWASP Foundation. *Deserialization Cheat Sheet*. <https://cheatsheetseries.owasp.org/cheatsheets/Deserialization_Cheat_Sheet.html>
[^4]: Protocol Buffers Documentation. *Language Guide (proto3) and Encoding*. <https://protobuf.dev/programming-guides/proto3/>
[^5]: Kleppmann, M. (2017). *Designing Data-Intensive Applications*, Chapter 4. O'Reilly Media.
