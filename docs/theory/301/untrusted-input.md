# Untrusted input and parser risk

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/leo-gan/GLD.SerializerBenchmark/blob/master/docs/theory/notebooks/301/untrusted_input.ipynb)
**Lab notebook:** [Untrusted input experiment](../notebooks/301/untrusted_input.ipynb)

## Problem

Every public or multi-tenant deserialize path accepts **attacker-controlled bytes**. The classic failures are not “the codec was a bit slow.” They are remote code execution through native deserializers, resource exhaustion through nested or huge payloads, and logic bugs from unvalidated schemaless data.

Teams often discover these risks after an incident. They then retrofit limits that should have been part of the original boundary design.

## Short answer

Assume untrusted input is **hostile**. Prefer **portable pure-data formats** with explicit validation at the trust boundary (see [trust boundaries](trust-boundaries.md)). Enforce **maximum body size, nesting depth, and collection cardinality** before or during parse.

Never run language-native deserialize—pickle, Java serialization, unsafe YAML load, legacy binary formatters—on untrusted bytes. For zero-copy layouts, **verify** the buffer before field access (see 201 [zero-copy](../201/zero-copy.md)). Suite speed numbers do not measure adversarial robustness.

This page assumes the security notes from the 101 engineering lens. Here we own the **operational playbook**.

## Constraints that matter

| Control | Why it matters |
|---------|----------------|
| **Who can send bytes?** | Internet clients, partners, internal multi-tenant callers, or only the same process |
| **Deserializer power** | Can the format reconstruct arbitrary types and code, or only pure data? |
| **Resource budget** | CPU, memory, and wall-clock time allowed per request |
| **Validation layer** | Schema checks, typed models, allowlists of accepted shapes |
| **Logging of payloads** | Captured bodies create cost and leak risk; see [payload surfaces](payload-surfaces.md) |

## Decision frame

```text
  Untrusted producer?
    no  → still enforce size limits; the threat model may be weaker
    yes → portable format + hard limits + validation
           never native deserialize
```

Even when the producer is trusted, size limits remain a good default. When the producer is untrusted, portable formats, hard resource caps, and validation are mandatory.

| Risk class | Typical vectors | Mitigations |
|------------|-----------------|-------------|
| **Code execution** | pickle, Java serialization, gadget chains, unsafe YAML | Ban these on the boundary; accept pure data only |
| **Expansion and denial of service (DoS)** | Entity expansion, nested bombs, huge arrays | Disable dangerous features; enforce depth and size caps |
| **Allocation storms** | Many small objects created from one message | Caps; streaming parsers where appropriate |
| **Type confusion** | JSON number versus string; duplicate keys | Schema or typed decode; strict parsers |
| **Unverified zero-copy** | Crafted offsets into a buffer | Run a verifier before use |

## Failure modes

| Mistake | Outcome |
|---------|---------|
| Treating “internal network” as fully trusted | Lateral movement inside the network becomes remote code execution |
| Putting limits only at the gateway | A sidecar or admin path bypasses them |
| Validating only after full materialization | You already paid the denial-of-service cost |
| Never running fuzz tests | Edge cases ship straight to production |
| Choosing a codec by Results alone | A fast but unsafe path wins the architecture decision record |

## Real-world sketch

An internal API accepts MessagePack from other services and later from a partner VPN. There is no maximum nesting depth. A nested map bomb locks workers. Separately, a debug endpoint still accepts pickle “for support tools.”

The pickle path is the incident class that ends careers. The depth bomb is the one that ends service-level objectives (SLOs). Both are **boundary design** failures, not “we picked the wrong MessagePack library.”

## In this suite

| Resource | Role |
|----------|------|
| Language **Overview** | Notes on native codecs and fidelity—not security proofs |
| **Results** | Encode and decode cost under **benign** fixtures |
| [Using this suite](using-this-suite.md) | Why you must not treat speed as safety |
| [Trust boundaries](trust-boundaries.md) | Portable versus native policy |

This benchmark runner does **not** run adversarial fuzz campaigns or claim parser security.

## Experiments

**Question:** For this deserialize path, are **hostile-payload controls** sufficient, and is the codec class acceptable?

### Setup

1. Identify every public or multi-tenant parse entry point.
2. Note the codec (JSON, Protobuf, native, and so on) and the maximum request size at the edge.
3. Gather parser settings: depth limits, document size limits, and known CVE posture (common vulnerabilities and exposures).

### Procedure

1. Walk a threat checklist: code execution through native deserialize, expansion bombs, huge allocations, deeply nested structures.
2. Verify **hard limits** on body size, depth, and collection cardinality before or during parse.
3. Confirm that native, pickle, and Java serialization paths are **banned** on untrusted routes.
4. Optionally fuzz or inject adversarial fixtures; watch process memory and time-to-failure.
5. Use suite Results only for performance among **safe** portable codecs.

### Decision rule

- Any untrusted path with native deserialize or no size/depth limits is a **fail**. Fix that before optimizing.
- Among safe codecs, use the implementation-variance and latency experiments as usual.

## Metrics

| Metric / signal | Role |
|-----------------|------|
| **Max body size enforced** | **Primary** control metric |
| **Max depth and array size** | Expansion and stack risk |
| **Time and memory to reject** huge or nested payloads | Denial-of-service resistance |
| Parser error rate on fuzz inputs | Robustness signal |
| CVE and advisory state of the library | Eligibility filter |
| Suite speed and size | Secondary after the safety pass |
| `mean_fidelity` on valid fixtures | Still required for correctness |

**Conclusion style:** “The edge enforces 1 MB and depth 32; we use JSON library X; native deserialize is banned.”

## What this suite cannot tell you

- Whether a library is free of known CVEs.
- The correct absolute limits for *your* memory budget.
- How effective your WAF rules or service-mesh policies are.
- Whether gadgets exist in *your* dependency graph.

## Common mistakes

- Enabling “convenient” native deserialize behind authentication only.
- Logging full hostile bodies (this amplifies cost and leak risk).
- Skipping verification on FlatBuffers-class buffers for speed.

## Key takeaways

- Deserialize is an **attack surface**. Design limits first.
- Portable formats plus validation plus size and depth caps is the default for untrusted bytes.
- Native deserialize is a special case of “trusted only.”
- Suite Results answer cost under honest fixtures—not adversarial hardness.
