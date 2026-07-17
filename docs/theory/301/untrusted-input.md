# Untrusted input and parser risk

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/leo-gan/GLD.SerializerBenchmark/blob/master/docs/theory/notebooks/301/untrusted_input.ipynb)
**Lab notebook:** [Untrusted input experiment](../notebooks/301/untrusted_input.ipynb)


## Problem

Every public or multi-tenant deserialize path accepts **attacker-controlled bytes**. Classic failures are not slow codecs—they are remote code execution via native deserializers, resource exhaustion via nested or huge payloads, and logic bugs from unvalidated schemaless data. Teams discover this after an incident, then retrofit limits that should have been part of the original boundary design.

## Short answer

Assume untrusted input is **hostile**. Prefer **portable pure-data formats** with explicit validation at the trust boundary ([trust boundaries](trust-boundaries.md)). Enforce **maximum body size, nesting depth, and collection cardinality** before or during parse. Never run language-native deserialize (pickle, Java serialization, unsafe YAML load, legacy binary formatters) on untrusted bytes. For zero-copy layouts, **verify** before field access (201 [zero-copy](../201/zero-copy.md)). Suite speed numbers do not measure adversarial robustness.

Assumes 101 engineering security notes; this page owns the **operational playbook**.

## Constraints that matter

| Control | Why it matters |
|---------|----------------|
| **Who can send bytes?** | Internet, partner, internal multi-tenant, same process |
| **Deserializer power** | Arbitrary types / code vs pure data |
| **Resource budget** | CPU, memory, wall time per request |
| **Validation layer** | Schema, typed models, allowlists |
| **Logging of payloads** | See [payload surfaces](payload-surfaces.md) |

## Decision frame

```text
  Untrusted producer?
    no  → still size-limit; threat model may be weaker
    yes → portable format + hard limits + validate
           never native deserialize
```

| Risk class | Typical vectors | Mitigations |
|------------|-----------------|-------------|
| **Code execution** | pickle, Java ser, gadget chains, unsafe YAML | Ban on boundary; pure data only |
| **Expansion / DoS** | Entity expansion, nested bombs, huge arrays | Disable dangerous features; depth/size caps |
| **Allocation storms** | Many small objects from one message | Caps; streaming parsers where appropriate |
| **Type confusion** | JSON number vs string; duplicate keys | Schema / typed decode; strict parsers |
| **Unverified zero-copy** | Crafted offsets | Verifier before use |

## Failure modes

| Mistake | Outcome |
|---------|---------|
| “Internal network = trusted” | Lateral movement becomes RCE |
| Limits only at the gateway | Sidecar or admin path bypasses them |
| Validate after full materialization | DoS already paid |
| Fuzz never run | Edge cases ship to production |
| Choosing codec by Results alone | Fast unsafe path wins the ADR |

## Real-world sketch

An internal API accepts MessagePack from other services and later from a partner VPN. No max depth. A nested map bomb locks workers. Separately, a debug endpoint still accepts pickle “for support tools.” The pickle path is the incident class that ends careers; the depth bomb is the one that ends SLOs. Both are **boundary design** failures, not “we picked the wrong MessagePack library.”

## In this suite

| Resource | Role |
|----------|------|
| Language **Overview** | Notes on native / fidelity—not security proofs |
| **Results** | Encode/decode cost under **benign** fixtures |
| [Using this suite](using-this-suite.md) | Do not treat speed as safety |
| [Trust boundaries](trust-boundaries.md) | Portable vs native policy |

This harness does **not** run adversarial fuzz campaigns or claim parser security.


## Experiments

**Question:** For this deserialize path, are **hostile-payload controls** sufficient, and is the codec class acceptable?

### Setup
1. Identify every public or multi-tenant parse entrypoint.  
2. Note codec (JSON, Protobuf, native, …) and max request size at the edge.  
3. Gather parser settings: depth limits, document size, known CVE posture.

### Procedure
1. Threat checklist: code execution (native deser), expansion bombs, huge alloc, deeply nested structures.  
2. Verify **hard limits** (body size, depth, collection cardinality) before or during parse.  
3. Confirm native/pickle/Java serialization are **banned** on untrusted paths.  
4. Optional: fuzz or adversarial fixtures; watch process memory and time-to-failure.  
5. Suite Results optional for performance among **safe** portable codecs only.

### Decision rule
- Any untrusted path with native deserialize or no size/depth limits ⇒ **fail**; fix before optimizing.  
- Among safe codecs, use implementation-variance + latency experiments as usual.

## Metrics

| Metric / signal | Role |
|-----------------|------|
| **Max body size enforced** | **Primary** control metric |
| **Max depth / array size** | Expansion / stack risk |
| **Time and memory to reject** huge/nested payloads | DoS resistance |
| Parser error rate on fuzz | Robustness |
| CVE / advisory state of library | Eligibility |
| Suite speed / size | Secondary after safety pass |
| `mean_fidelity` on valid fixtures | Still required for correctness |

**Conclusion style:** “Edge enforces 1 MB + depth 32; JSON library X; native deser banned.”

## What this suite cannot tell you

- Whether a library is free of known CVEs.  
- Correct absolute limits for *your* memory budget.  
- Effectiveness of WAF rules or mesh policies.  
- Gadget availability in *your* dependency graph.

## Common mistakes

- Enabling “convenient” native deserialize behind auth only.  
- Logging full hostile bodies (amplifies cost and leak risk).  
- Skipping verification on FlatBuffers-class buffers for speed.

## Key takeaways

- Deserialize is an **attack surface**; design limits first.  
- Portable + validate + size/depth caps is the default for untrusted bytes.  
- Native deserialize is a special case of “trusted only.”  
- Suite Results answer cost under honest fixtures—not adversarial hardness.
