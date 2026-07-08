# Case study: internal high-QPS RPC

> Internal services exchange dense records at high QPS on a private network—how should payloads be encoded?

## Context & goals

**Setting:** Payment authorization path. Services in Go and Rust (with a Python batch sibling not on the hot path). Private network, mTLS service identity. Messages are compact structured records (ids, amounts, status enums)—not arbitrary documents. Target: low p99 latency and stable multi-year evolution.

**Goals:**

- High throughput encode/decode on the hot path.  
- Shared contract across Go and Rust.  
- Safe rolling deploys (additive evolution).  
- No browser clients on this hop.

## Non-goals / hard constraints

- Not public third-party HTTP ([public REST case](case-public-rest-api.md)).  
- Not cross-org untrusted input (still validate size/depth).  
- Language-native codecs disallowed across services ([trust boundaries](trust-boundaries.md)).  
- Python appears only offline—must not dictate hot-path format, but must not be impossible to speak later.

## Options on the table

| Option | Sketch |
|--------|--------|
| **A. Schema-driven IDL (Protobuf-class)** | Shared `.proto`; codegen; field-number culture |
| **B. Schemaless binary (MessagePack/CBOR-class)** | Flexible maps; org-owned validation |
| **C. JSON internal** | Same as public style, private network |
| **D. Language-native per service** | Fastest local graph dump | 

## Trade-off matrix

| Axis | A. IDL binary | B. Schemaless binary | C. JSON | D. Native |
|------|---------------|----------------------|---------|-----------|
| Density / CPU potential | High | Medium–high | Lower | Often high, **unsafe here** |
| Multi-language | Excellent with codegen | Good if libs mature | Excellent | Fail polyglot |
| Evolution | Field-number process | Ad hoc unless disciplined | Ad hoc unless schema layer | Brittle |
| Debug | Tooling needed | Tooling needed | Easy | Opaque |
| Fit for enums/stable records | Strong | Weaker unless careful | OK with care | N/A |

## Recommendation (under these constraints)

**Prefer A (Protobuf-class IDL binary)** for the hot hop: stable record shape, two compiled languages, evolution via field numbers and CI breaking-change checks ([two schema cultures](two-schema-cultures.md)). Select **implementations per language** with suite Results in the schema-driven family ([implementation variance](implementation-variance.md)).

**Keep B** as alternative if the team refuses IDL tooling *and* will fund validation + compatibility tests equivalent to a registry/IDL process—rare on high-QPS money paths.

**Keep C** only if SLOs are met with JSON after best libraries and the org values uniform JSON everywhere more than density—validate with measurement, not taste.

**Reject D** at the service boundary.



## Experiments

**Question:** Internal high-QPS RPC—schema-driven binary vs schemaless binary vs JSON—under the stated QPS and evolution constraints?

### Setup
1. Fix language(s), QPS, p99 budget, payload fixture.  
2. Families: JSON, MessagePack/CBOR-class, Protobuf/Avro-class.  
3. Suite Results + load generator.

### Procedure
1. Fair suite slice per family ([using this suite](using-this-suite.md)).  
2. Load-test shortlisted impls at target QPS; record p99 and CPU.  
3. Score evolution needs (field adds, multi-service).  
4. Apply trust (internal mesh vs expose).  
5. Recommend with evidence table.

### Decision rule
- Miss p99 at QPS ⇒ denser/faster family or impl.  
- Strong evolution + multi-service ⇒ prefer schema-driven despite small speed gap.

## Metrics

| Metric / signal | Role |
|-----------------|------|
| **p99 RPC latency @ target QPS** | **Primary** |
| CPU % on ser/deser | Capacity |
| Suite median ser/deser + size | Shortlist |
| Schema evolution pain (qualitative + incident count) | Long-term cost |
| `mean_fidelity` | Correctness |
| Cross-family leaderboard | Do not use raw |

## What would change the answer

- Document-shaped, highly variable payloads → schemaless binary or JSON with validation may fit better.  
- Many dynamic consumers without codegen → resolution culture / events ([event case](case-event-stream.md)).  
- Need browser on same hop → not this case; add a gateway with JSON.

## Key takeaways

- Internal high-QPS **stable records** lean **schema-driven IDL**, not native codecs.  
- Suite picks **libraries per language** after the family is fixed.  
- Evolution process is part of the recommendation—not an afterthought.
