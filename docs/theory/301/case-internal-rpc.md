# Case 2: Internal High-QPS RPC

> **Design brief:** Go and Rust services exchange compact, stable payment-authorization records at high QPS over a private mutual-TLS network, while an offline Python batch job occasionally reads the same schema.

---

## Scenario and Hard Constraints

- **Topology:** Synchronous request/response path between Go and Rust services over private mTLS; Python participates offline only.
- **Payload profile:** Small, fixed-structure records (IDs, integer minor-unit amounts, status enums) requiring low $p_{99}$ latency and multi-year additive evolution.
- **Hard constraints:**
  - Private mTLS mitigates external exposure, but cross-process boundaries still forbid language-native serializers ([3.1 Trust boundaries](trust-boundaries.md)) and still enforce maximum message-size and nesting bounds ([3.2 Untrusted input](untrusted-input.md)).
  - Offline Python participation must remain feasible without dictating the hot-path runtime.

---

## Candidate Options and Trade-Offs

| Dimension | A. Schema-Driven IDL (Protobuf) | B. Schemaless Binary (MessagePack/CBOR) | C. Internal JSON | D. Language-Native |
|---|---|---|---|---|
| **CPU & wire density** | High (compact tags, no key strings) | Medium–high | Lower (text parsing, repeated keys) | Disqualified |
| **Multi-language interop** | Strong (shared `.proto` + codegen for Go, Rust, Python) | Good if conventions are documented | Universal | Fails cross-language requirement |
| **Schema evolution** | Automated field-number checks (`buf breaking`) | Requires manual discipline & custom tests | Requires JSON Schema discipline | Brittle across releases |
| **Enum & stable-struct fit** | Native typed enums and fields | Convention-only | String/int conventions | N/A |
| **Incident debugging** | Requires descriptor-aware CLI (`grpcurl`, `protoc`) | Requires decoder tool | Directly readable | Opaque |

---

## Recommended Architecture

1. **Choose Option A (Protocol Buffers + shared `.proto` repository):** The records are compact, stable, and shared across compiled languages (Go and Rust) with mature codegen and Python support. Enforce field-number evolution rules in CI ([3.3 Schema cultures](two-schema-cultures.md)).
2. **Select libraries locally per language:** Use the Dashboard on Standard `Protocol Buffers` for Go and Rust separately to pin fast, faithful implementations (e.g., `prost` in Rust, `google.golang.org/protobuf` or a verified fast Go implementation; see [3.9 Implementation variance](using-this-suite.md#implementation-variance)).
3. **Keep RPC DTOs narrow:** Carry only authorization fields on the synchronous hop; avoid embedding full order histories ([3.7 RPC and messaging](rpc-and-messaging.md)).
4. **Reject Option D** completely; consider Option C only if uniform JSON simplicity is an organizational mandate *and* load tests verify JSON meets the $p_{99}$ SLO with headroom.

---

## Verification Plan and Suite Limits

- **Within this suite:** Inspect Go and Rust Dashboard slices on `(Language, Protocol Buffers, Suite, message/telemetry)` for median latency, wire size, and `mean_fidelity = 1.0`.
- **Outside this suite:** Run a $3 \times 3$ Go/Rust/Python interop matrix ([3.6 Multi-language systems](polyglot-estates.md)), enforce CI `buf breaking` checks, and load-test end-to-end $p_{99}$ latency and GC/allocation rates under target QPS ([3.10 Latency tails](latency-tails-and-gc.md)).
- **What would change the answer:** Highly variable semi-structured documents favor JSON or CBOR + schema validation; browser clients directly on this hop require a JSON edge gateway.

---

## Discussion Prompts

1. Why is `mTLS` on a private VPC insufficient to permit Go `gob` or Rust `bincode` on this hop?

??? note "Guidance"
    First, the hop crosses **two languages** (Go and Rust, plus offline Python), making single-language formats unusable. Second, even between two services in the same language, native/reflection formats couple wire layout to internal types and break rolling deployments when structs evolve.

2. Should this service enable `gzip` compression on 250-byte Protobuf authorization RPCs across a datacenter LAN?

??? note "Guidance"
    No. A 250-byte Protobuf record transmits in microseconds on a datacenter LAN; gzip compression/decompression CPU overhead will exceed wire savings and inflate $p_{99}$ latency ([3.10 System compression](latency-tails-and-gc.md#compression-as-system-choice)).
