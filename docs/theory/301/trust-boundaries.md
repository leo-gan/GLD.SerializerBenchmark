# Trust Boundaries: Portable vs. Language-Native Formats

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/leo-gan/GLD.SerializerBenchmark/blob/master/docs/theory/notebooks/301/trust_boundaries.ipynb)

## Problem Statement

Language-native serializers—such as Python `pickle`, Java `ObjectInputStream`, and legacy .NET `BinaryFormatter`[^4]—serialize arbitrary in-memory object graphs with minimal boilerplate, preserving class identities, shared references, and cycles. Because they avoid intermediate data-transfer models, they frequently appear competitive on single-runtime benchmarks.

When bytes produced by a native serializer leave the originating process and enter a shared cache, message queue, durable object store, or network API, the engineering problem changes fundamentally. Deserializing untrusted or cross-team native payloads introduces remote code execution via gadget chains, brittle runtime coupling across class upgrades, and permanent lock-in to a single language ecosystem. Format selection across system hops must therefore evaluate **trust and interoperability boundaries** before comparing throughput.

---

## Trust Domains and Format Classes

!!! note "Definition: Trust Domain and Trust Boundary"
    A **trust domain** is an execution boundary within which a single operator controls both the code producing serialized bytes and the code consuming them, under shared security and deployment assumptions. A **trust boundary** is crossed whenever bytes are produced or consumed by another process, team, tenant, programming language, or external network.

![Trust boundaries: process, set of services the organization runs, public untrusted](../assets/diagrams/301-trust-boundaries.svg#only-light)
![Trust boundaries: process, set of services the organization runs, public untrusted](../assets/diagrams/301-trust-boundaries-dark.svg#only-dark)

Building on [Self-describing vs. schema-dependent](../201/self-describing-vs-schema-dependent.md), the choice between **portable** and **language-native** encodings is primarily a security and lifecycle policy:

| Dimension | Portable (JSON, MessagePack, CBOR, Protocol Buffers, Avro, Parquet) | Language-Native (`pickle`, Java serialization, legacy `.NET BinaryFormatter`) |
|---|---|---|
| **Permitted producers** | Public clients, partners, multi-tenant or cross-team services | Strictly authenticated, same-trust-domain writers only |
| **Permitted consumers** | Any language with a compliant library | Single runtime family (often same library/class versions) |
| **Security model** | Pure data decoding; requires bounds and schema validation | Decoding executes runtime construction logic or opcodes (**RCE risk**)[^1][^2] |
| **Retention horizon** | Suitable for multi-year storage and logs with schema evolution | Fragile across class refactors and runtime upgrades |
| **Observability** | Inspectable with standard or schema-aware tooling | Opaque without the exact originating type graph |

### Policy Matrix by Deployment Context

| Context | Recommended Class | Rationale |
|---|---|---|
| Public or partner HTTP/RPC API | Portable (typically JSON + schema, or IDL binary) | Untrusted writers and heterogeneous clients require safe, documented wire semantics |
| Internal multi-language services | Portable schema-driven or schemaless binary | Prevents runtime lock-in and decouples release cycles |
| Durable storage, event logs, data lakes | Portable (Avro, Parquet, Protocol Buffers, or validated JSON) | Data outlives individual application binaries and class layouts |
| Shared cache (Redis / Memcached) read by multiple services | Portable | Even internal caches cross service and language boundaries over time |
| Ephemeral, single-binary private cache or single-stack ML checkpoint | Native *permissible* only if trust assumptions and lock-in are documented | Acceptable only when no untrusted input can influence the stored payload; migrate to portable weight formats (e.g., Safetensors, ONNX) before sharing |

---

## Failure Modes

1. **Arbitrary code execution via gadget chains:** Native deserializers instantiate arbitrary classes or execute embedded opcodes during decode. Even when application code never imports dangerous types directly, classes already present on the classpath or module path can be chained into remote code execution.[^1][^3]
2. **False "internal network" assumptions:** Treating any private VPC or internal message bus as trusted ignores lateral movement and multi-tenant isolation bugs. A server-side request forgery (SSRF) or cache-poisoning defect that lets an external caller influence a cached `pickle` or Java serialized blob immediately escalates a data-integrity bug into code execution.
3. **Silent version skew:** Renaming a class, altering a field type, or upgrading a runtime can break deserialization of stored native blobs without an explicit compatibility check.
4. **Ecosystem lock-in and forensic opacity:** When a second service written in another language needs access to a Redis cache or archive populated with native blobs, teams face dual-write migrations or brittle reverse-engineering. Incident responders likewise cannot inspect payloads without reproducing the original runtime environment.
5. **Conflating portability with parser safety:** Switching to a portable format eliminates *object-instantiation* code execution, but does not remove all parser risks. Untrusted portable payloads still require size caps, nesting-depth limits, and schema or buffer verification ([Untrusted input](untrusted-input.md)).

---

## Boundary Audit Protocol and Benchmark Limits

Before using performance measurements to select a codec, audit each hop in the data path:

1. **Map every hop:** Trace the byte stream from producer through intermediate stores, queues, caches, and logs to every consumer (including backup and analytics readers).
2. **Classify trust and runtime diversity:** For each hop, determine whether *(a)* an untrusted or multi-tenant principal can influence the bytes, *(b)* more than one language runtime may read the bytes now or later, or *(c)* retention exceeds a single deployment lifecycle.
3. **Apply the disqualification gate:** If any condition in step 2 holds, **disqualify language-native serializers** regardless of throughput.
4. **Select among permitted codecs:** Only after the candidate set is restricted to policy-compliant portable standards, use the [Dashboard](../../dashboard/index.html) (fixing language, standard, data set, and data type) to evaluate implementation cost.

Where native and portable codecs both appear for a language on the Dashboard (labeled in [Families](../../analysis/families.md) and each language Overview), treat the gap solely as a measure of the **runtime cost of portability**, never as clearance to place native bytes on a network or shared store.

### What This Benchmark Suite Cannot Answer

- Whether a specific runtime classpath or Python environment contains exploitable deserialization gadget chains.
- The effective isolation of your network, IAM policies, cache keyspace, or multi-tenant job scheduler.
- Regulatory or organizational compliance mandates restricting executable or opaque artifact formats at rest.
- Operational migration cost when a previously single-language store later acquires consumers in a second language.

---

## Exercises

1. **Cache boundary evaluation:** A Python web service stores user session objects in a Redis instance using `pickle` and observes a 2× decode speedup over `orjson`. Six months later, an internal Go authentication proxy must read session metadata from the same Redis cluster, and a security review notes that an adjacent microservice shares the Redis namespace. Evaluate whether `pickle` remains permissible and specify an alternative.

??? note "Solution"
    `pickle` fails **two** independent boundary conditions: *(1)* multi-language consumption (Go cannot safely or portably decode Python `pickle` opcodes) and *(2)* shared-namespace trust risk (any compromise or key collision in the adjacent service can inject malicious `pickle` payloads into the Python service). Replace `pickle` with a portable encoding—such as JSON (with `orjson` or `msgspec`) or MessagePack/Protocol Buffers—enforcing explicit schema validation and keyspace isolation.

2. **Model checkpoint promotion:** A research team saves intermediate training checkpoints with `pickle`-backed framework files on a private cluster, then plans to publish the final model weights for inference services written in C++ and Rust. At what boundary must the serialization format change, and why?

??? note "Solution"
    The format must change at the **training-to-serving / publication boundary**. While ephemeral checkpoints inside a single trusted training stack may tolerate native formats, publishing artifacts for cross-language inference crosses both a language boundary and a trust/audit boundary. Export weights into a non-executable, portable tensor representation (e.g., Safetensors, ONNX, or an explicit binary layout) before promotion.

3. **Portable format security check:** Does replacing Java `ObjectInputStream` with JSON or FlatBuffers eliminate the need for input validation on a public API? Explain briefly.

??? note "Solution"
    No. Portable formats eliminate runtime object-instantiation RCE, but hostile callers can still trigger denial-of-service or logic errors via deeply nested JSON, oversized payloads, type confusion, or—in zero-copy formats like FlatBuffers—corrupted relative offsets if the buffer verifier is skipped ([Untrusted input](untrusted-input.md)).

---

## References

[^1]: OWASP Foundation. *Deserialization Cheat Sheet*. <https://cheatsheetseries.owasp.org/cheatsheets/Deserialization_Cheat_Sheet.html>
[^2]: Python Software Foundation. *`pickle` — Python object serialization (Security Warning)*. Python 3 Documentation. <https://docs.python.org/3/library/pickle.html>
[^3]: Bloch, J. (2018). *Effective Java* (3rd ed.), Item 85: "Prefer alternatives to Java serialization." Addison-Wesley.
[^4]: Microsoft. *BinaryFormatter security guide*. .NET Documentation. <https://learn.microsoft.com/en-us/dotnet/standard/serialization/binaryformatter-security-guide>
