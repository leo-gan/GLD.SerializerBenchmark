# 3.2 Untrusted Input, Parser Risk, and Payload Surfaces

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/leo-gan/GLD.SerializerBenchmark/blob/master/docs/theory/notebooks/301/untrusted_input.ipynb)

## Problem Statement

Any deserialization path reachable by external clients, partners, or multi-tenant workloads processes **attacker-controlled bytes**. Switching away from language-native serializers ([3.1 Trust boundaries](trust-boundaries.md)) eliminates arbitrary object-instantiation code execution, yet leaves two serious production risk classes:

1. **Parser resource exhaustion and logic bugs:** Hostile portable payloads can trigger stack overflow, memory exhaustion, CPU algorithmic worst cases, or type-confusion bugs before business validation ever executes.
2. **Cleartext payload leakage across secondary surfaces:** Transport encryption (TLS) protects bytes only in flight. Once serialized or logged, sensitive credentials and personally identifiable information (PII) routinely leak into application logs, APM traces, dead-letter queues (DLQs), and crash dumps.

---

## Defensive Parsing Controls

!!! note "Definition: Pure-Data Portable Format"
    A **pure-data portable format** encodes values and nested containers without invoking runtime constructors, class loaders, or virtual-machine opcodes during decode. Even pure-data parsers remain attack surfaces requiring explicit resource bounds.

Enforce resource limits **prior to or streaming during parse**—rejecting an oversized message only after allocating a full object graph still pays the denial-of-service cost.[^1]

| Threat Vector | Typical Mechanism | Required Control |
|---|---|---|
| **Code execution (RCE)** | `pickle`, Java `ObjectInputStream`, unsafe YAML `load`, legacy `.NET BinaryFormatter` | Ban native deserializers on untrusted or multi-tenant paths; use safe loaders (`safe_load`) |
| **Expansion / decompression bombs** | XML DTD entity expansion (*billion laughs*); compressed payloads expanding to gigabytes | Disable XML DTD/external entities; cap **decompressed** byte length during streaming inflate |
| **Deep nesting / stack overflow** | Thousands of nested `[` or `{` tokens in JSON, CBOR, or MessagePack; nested Protobuf submessages | Configure strict maximum recursion/nesting depth (e.g., 32–64 levels) |
| **Allocation storms** | Millions of tiny keys/elements or hash-collision keys inside a single valid body | Cap total body size, collection cardinality, and string length; use collision-resistant hash tables |
| **Type confusion / duplicate keys** | Ambiguous JSON duplicate keys (`{"role":"user","role":"admin"}`), numeric-vs-string coercion | Enforce strict schema validation at ingress; reject duplicate object keys where parsers diverge[^2] |
| **Unverified zero-copy offsets** | Crafted relative offsets in FlatBuffers / Cap'n Proto buffers | Execute the format's structural verifier (`VerifyBuffer`) unconditionally before field access[^3] |

Authentication alone does not remove parser risk: an authenticated user or compromised internal caller can still send malformed nesting bombs. Enforce size and depth limits at both the API gateway *and* the service parser so sidecars or internal admin routes cannot bypass edge guards.

---

## Secrets, PII, and Payload Surfaces {#payload-surfaces}

Every serialization step creates an artifact that downstream infrastructure can inspect, copy, or retain. Format choice (JSON vs. binary) changes casual readability, **not** data-protection obligations—binary traffic is routinely decoded into JSON by observability pipelines and error handlers.

| Data Classification | Handling Policy Across Serialized Surfaces |
|---|---|
| **Credentials and secrets** (passwords, API keys, private keys) | Never embed in durable business events, logs, or caches; use short-lived scoped tokens at auth edges only |
| **Regulated PII** (names, emails, government IDs, payment data) | Minimize fields in payloads; tokenize or encrypt sensitive attributes; enforce explicit retention TTLs |
| **Internal domain identifiers** (order IDs, correlation IDs) | Safe for structured logs and tracing; prefer logging IDs and error codes over full message bodies |
| **Diagnostic payload captures** | Disabled by default; require explicit opt-in sampling, field-level allowlist redaction, access control, and short TTL |

### Common Secondary Leakage Sinks

- **Error-path logging:** Enabling "log full decoded payload on parse/validation failure" during debugging floods SIEM and log aggregators with PII whenever error rates spike.
- **Dead-letter queues (DLQs) and support exports:** Poison messages quarantined for investigation retain raw bodies; restrict DLQ access controls and prohibit copying production payloads into tickets or git test suites.
- **Metrics labels and APM breadcrumbs:** Embedding raw user identifiers or request bodies into telemetry tags bypasses body-level redaction filters.

---

## Verification Checklist and Benchmark Limits

Before optimizing codec speed on any external or multi-tenant boundary, verify five gates:

1. **Format allowlist:** Confirm zero native deserializers or unsafe YAML/XML features are reachable.
2. **Hard parser caps:** Confirm explicit maximum body size, nesting depth, array/map cardinality, and decompressed length are configured inside the service parser itself.
3. **Adversarial rejection test:** Feed oversized, deeply nested, truncated, and duplicate-key inputs and verify fast, bounded-memory rejection (consider continuous fuzzing on C/C++ parsers).
4. **Zero-copy verification:** If FlatBuffers or Cap'n Proto is used, verify that corrupt buffers fail closed in the verifier.
5. **Sink redaction audit:** Trigger an intentional deserialization error and verify that logs, APM traces, metrics, and DLQ viewers emit correlation IDs rather than raw secrets or PII.

### What This Benchmark Suite Cannot Answer

The [Dashboard](../../dashboard/index.html) measures throughput and size on **benign, well-formed data types**. It does not run adversarial fuzz campaigns, track library CVE histories, verify WAF/gateway rules, or audit legal compliance regimes (GDPR, HIPAA, PCI-DSS). Use [Dashboard · Compliance](../../dashboard/index.html#compliance) to check how a library handles malformed edge cases defined in published specifications (such as duplicate JSON keys or truncated varints).

---

## Exercises

1. **Duplicate-key discrepancy:** An API gateway written in Go parses `{"amount": 100, "amount": 1}` using last-key-wins semantics and approves a \$1 purchase, while a downstream Python risk engine parses the same raw JSON body with first-key-wins behavior. Why does RFC 8259 fail to guarantee identical behavior here, and how should the gateway prevent this class of bug?

??? note "Solution"
    RFC 8259 §4 states only that member names *should* be unique and explicitly notes that parser behavior on duplicate names is unpredictable.[^2] To eliminate parser differentials, configure the ingress gateway to reject duplicate keys strictly (or re-serialize the validated canonical struct before forwarding downstream so every internal service sees one unambiguous payload).

2. **Post-parse validation flaw:** A service enforces a 10 MB HTTP body limit and validates decoded JSON against a JSON Schema, yet a 500 KB JSON payload consisting of `[[[[...` (200,000 nested arrays) crashes worker processes with a stack overflow. Why did the existing controls fail, and what single control fixes it?

??? note "Solution"
    The body passed the 10 MB byte cap, and the JSON parser ran recursively *before* schema validation could execute. Enforcing a strict **maximum nesting depth** (e.g., depth $\le 64$) inside the JSON parser itself—or using an iterative parser with an explicit depth cap—terminates decoding in microseconds with bounded stack space.

3. **Binary error-log leak:** After migrating internal billing RPCs from JSON to Protocol Buffers, a team adds a helper that converts failed protobuf messages to JSON and writes them to application logs for easier debugging. Why is this a security regression?

??? note "Solution"
    TLS and binary wire encoding do not redact sensitive fields. Converting raw protobuf messages containing PII or payment tokens into cleartext error logs creates an unredacted secondary storage surface in the logging/SIEM pipeline. Log structured error codes, field tags, and correlation IDs instead, or apply an explicit field-level redaction allowlist.

---

## References

[^1]: OWASP Foundation. *Deserialization Cheat Sheet* and *REST Security Cheat Sheet*. <https://cheatsheetseries.owasp.org/>
[^2]: Bray, T. (Ed.). (2017). *The JavaScript Object Notation (JSON) Data Interchange Format* (§4 Objects — Duplicate Names). IETF RFC 8259. <https://www.rfc-editor.org/rfc/rfc8259#section-4>
[^3]: Google. *FlatBuffers Security and Buffer Verification*. <https://flatbuffers.dev/internals/>
