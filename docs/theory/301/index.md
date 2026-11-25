# Serialization 301: Production Systems

Part III examines architectural judgment when multiple production constraints conflict simultaneously—trust boundaries, untrusted input, long-lived schema governance, workload separation, multi-language interoperability, and tail-latency engineering.

**Prerequisites:** [Part I: Foundations (101)](../101/index.md) and [Part II: Mechanisms (201)](../201/index.md). Methodological and fair-comparison principles are stated in the [Course Syllabus](../index.md#methodological-principles). For byte-level wire formats and codec implementation, take the elective [Part IV: Codec Internals (401)](../401/index.md).

---

## Lectures

### Trust and Security
| Chapter | Topic | Core Focus | Companion Lab |
|---|---|---|---|
| [3.1 Trust boundaries](trust-boundaries.md) | Portable vs. language-native formats | Disqualifying native deserializers across process, team, or network boundaries | [Lab](../notebooks/301/trust_boundaries.ipynb) |
| [3.2 Untrusted input and payload surfaces](untrusted-input.md) | Parser DoS, resource bounds, secrets, and PII | Defensive parsing limits and controlling cleartext leakage in logs, traces, and queues | [Lab](../notebooks/301/untrusted_input.ipynb) |

### Contracts and Evolution
| Chapter | Topic | Core Focus | Companion Lab |
|---|---|---|---|
| [3.3 Schema cultures and registries](two-schema-cultures.md) | Avro resolution vs. Protobuf field numbers; compatibility modes | Choosing a control plane and enforcing BACKWARD, FORWARD, and FULL checks in CI | [Lab](../notebooks/301/two_schema_cultures.ipynb) |
| [3.4 Public API contracts and versioning](public-api-contracts.md) | OpenAPI/JSON Schema, expand/contract, dual-write, kill criteria | Governing external JSON contracts and executing non-additive migrations safely | — |

### Workload Architecture
| Chapter | Topic | Core Focus | Companion Lab |
|---|---|---|---|
| [3.5 Row vs. columnar at system scale](row-vs-columnar.md) | Online message paths vs. analytical lakes | Separating serving codecs from columnar storage and compaction pipelines | [Lab](../notebooks/301/row_vs_columnar.ipynb) |
| [3.6 Multi-language systems](polyglot-estates.md) | Polyglot contracts and cross-language interoperability | Standardizing one portable contract per boundary and verifying cross-language matrices | — |
| [3.7 RPC, messaging, caches, and queues](rpc-and-messaging.md) | Payload shape, fan-out, shared stores, poison messages | Designing narrow DTOs and portable, versioned payloads for shared infrastructure | — |
| [3.8 Zero-copy in production](zero-copy-in-production.md) | Operational viability of offset-based layouts | Evaluating builder ergonomics, mandatory buffer verification, and access patterns | — |

### Measurement and Performance Engineering
| Chapter | Topic | Core Focus | Companion Lab |
|---|---|---|---|
| [3.9 Fair benchmarking and implementation variance](using-this-suite.md) | Controlled Dashboard slicing and library selection | Avoiding misaligned comparisons and pinning concrete library implementations per language | — |
| [3.10 Latency tails, GC, and system compression](latency-tails-and-gc.md) | $p_{99}$ latency, allocation pressure, and compression placement | Measuring tail behavior under concurrency and placing gzip/zstd deliberately in the stack | — |

---

## Capstone Case Studies

Treat the six capstones as design-exam exercises applying Parts I–III under fixed constraints:

| Case Study | Architectural Tension |
|---|---|
| [Case 1: Public REST API](case-public-rest-api.md) | External JSON + hard schema contract vs. dual-stack binary negotiation |
| [Case 2: Internal high-QPS RPC](case-internal-rpc.md) | Schema-driven IDL binary vs. schemaless binary and JSON on private mTLS hops |
| [Case 3: Event backbone](case-event-stream.md) | Multi-year Avro or Protobuf schema governance under independent rolling deploys |
| [Case 4: Analytics lake](case-analytics-lake.md) | Compacted columnar Parquet/ORC tables vs. raw row-event archives on object storage |
| [Case 5: Cross-language service boundary](case-polyglot-boundary.md) | Enforcing one contract and interop matrix across TypeScript, Go, and Python |
| [Case 6: "We need it faster" postmortem](case-faster-postmortem.md) | Isolating wrong benchmark, library variance, and payload shape before rewriting a wire format |

See [Lab notebooks](../notebooks/README.md) for local and Colab setup, and [Dashboard](../../dashboard/index.html) for live suite measurements.
