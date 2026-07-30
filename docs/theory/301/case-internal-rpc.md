# Case study: internal high-QPS RPC

> Internal services exchange dense records at high QPS (queries or requests per second) on a private network. How should payloads be encoded?

This case study is the internal counterpart of the public REST case. The clients are other services you control, the records are stable and dense, and latency budgets are tight. Those facts change the recommendation without relaxing trust or portability rules.

---

## Context and goals

**Setting:** Payment authorization path. Services run in Go and Rust (with a Python batch sibling that is not on the hot path). The network is private with mutual TLS service identity. Messages are compact structured records (identifiers, amounts, status enums)—not arbitrary documents. The target is low p99 latency and stable multi-year evolution.

**Mutual TLS** means both client and server present certificates, so identity is stronger than “we share a private network.” **QPS** means queries (or requests) per second—how many messages the path must handle.

**Goals:**

- High throughput encode and decode on the hot path.
- A shared contract across Go and Rust.
- Safe rolling deploys through additive evolution.
- No browser clients on this hop.

---

## Non-goals and hard constraints

- This is not public third-party HTTP ([public REST case](case-public-rest-api.md)).
- This is not cross-organization untrusted input (you still validate size and depth).
- Language-native codecs are disallowed across services ([trust boundaries](trust-boundaries.md)).
- Python appears only offline—it must not dictate the hot-path format, but speaking the format later must remain possible.

In other words, the hop is internal and high-QPS, but it is still an interchange boundary between processes and languages.

---

## Options on the table

| Option | Sketch |
|--------|--------|
| **A. Schema-driven IDL (Protobuf-class)** | Shared `.proto`; code generation; field-number culture |
| **B. Schemaless binary (MessagePack/CBOR-class)** | Flexible maps; organization-owned validation |
| **C. JSON internal** | Same style as public APIs, but on a private network |
| **D. Language-native per service** | Fastest local graph dump |

An **IDL** (interface definition language) is a formal description of messages from which libraries generate typed code.

---

## Trade-off matrix

| Axis | A. IDL binary | B. Schemaless binary | C. JSON | D. Native |
|------|---------------|----------------------|---------|-----------|
| Density and CPU potential | High | Medium to high | Lower | Often high, **unsafe here** |
| Multi-language | Excellent with code generation | Good if libraries are mature | Excellent | Fails polyglot requirements |
| Evolution | Field-number process | Ad hoc unless disciplined | Ad hoc unless a schema layer exists | Brittle |
| Debug | Tooling needed | Tooling needed | Easy | Opaque |
| Fit for enums and stable records | Strong | Weaker unless careful | OK with care | Not applicable |

This matters because “internal” does not mean “native is fine.” It means you can choose denser portable formats more freely than on a public REST edge.

---

## Recommendation (under these constraints)

**Prefer A (Protobuf-class IDL binary)** for the hot hop: stable record shape, two compiled languages, and evolution via field numbers and continuous-integration breaking-change checks ([two schema cultures](two-schema-cultures.md)). Select **implementations per language** with suite Results in the schema-driven family ([implementation variance](implementation-variance.md)).

**Keep B** as an alternative if the team refuses IDL tooling *and* will fund validation and compatibility tests equivalent to a registry or IDL process. That combination is rare on high-QPS money paths.

**Keep C** only if service-level objectives are met with JSON after the best libraries, and the organization values uniform JSON everywhere more than density. Validate that claim with measurement, not taste.

**Reject D** at the service boundary.

---

## Experiments

**Question:** For internal high-QPS RPC, how do schema-driven binary, schemaless binary, and JSON compare under the stated QPS and evolution constraints?

### Setup

1. Fix language or languages, QPS, p99 budget, and payload fixture.
2. Consider families: JSON, MessagePack/CBOR-class, Protobuf/Avro-class.
3. Use suite Results plus a load generator.

### Procedure

1. Take a fair suite slice per family ([using this suite](using-this-suite.md)).
2. Load-test shortlisted implementations at target QPS; record p99 and CPU.
3. Score evolution needs (field adds, multi-service rollout).
4. Apply trust constraints (internal mesh versus any plan to expose the hop).
5. Recommend with an evidence table.

### Decision rule

- If you miss p99 at target QPS, move to a denser or faster family or implementation.
- If evolution needs are strong and multiple services share the hop, prefer schema-driven despite a small speed gap.

---

## Metrics

| Metric / signal | Role |
|-----------------|------|
| **p99 RPC latency at target QPS** | **Primary** |
| CPU percent on serialize and deserialize | Capacity |
| Suite median serialize/deserialize and size | Shortlist |
| Schema evolution pain (qualitative plus incident count) | Long-term cost |
| `mean_fidelity` | Correctness |
| Cross-family leaderboard | Do not use raw |

---

## What would change the answer

- Document-shaped, highly variable payloads may fit schemaless binary or JSON with validation better.
- Many dynamic consumers without code generation lean toward resolution culture and events ([event case](case-event-stream.md)).
- A browser on the same hop is not this case; add a gateway with JSON.

---

## Key takeaways

- Internal high-QPS **stable records** lean toward **schema-driven IDL**, not native codecs.
- The suite picks **libraries per language** after the family is fixed.
- Evolution process is part of the recommendation—not an afterthought.
