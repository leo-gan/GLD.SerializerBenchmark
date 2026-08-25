# Untrusted input and parser risk

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/leo-gan/GLD.SerializerBenchmark/blob/master/docs/theory/notebooks/301/untrusted_input.ipynb)
**Lab notebook:** [Untrusted input experiment](../notebooks/301/untrusted_input.ipynb)

## Problem

Every public or multi-tenant deserialize path accepts **attacker-controlled bytes**. In plain language: if someone outside your process can choose what you parse, you should assume those bytes may be hostile.

The classic failures are not “the codec was a bit slow.” They are:

- **Remote code execution** through native deserializers. That means running attacker code on your machine.
- **Resource exhaustion** through nested or huge payloads. That means using up memory or CPU until the service fails.
- **Logic bugs** from unvalidated schemaless data. That means accepting a shape that your business code never expected.

Teams often discover these risks after an incident. They then retrofit limits that should have been part of the original boundary design. This page is the operational playbook. The goal is that retrofit is not your first lesson.

---

## Short answer

Assume untrusted input is **hostile**. Prefer **portable pure-data formats** with explicit validation at the trust boundary. See [trust boundaries](trust-boundaries.md). A **portable pure-data format** encodes values and structure. It does not have the power to reconstruct arbitrary program types. It also does not run code during parse.

Enforce **maximum body size, nesting depth, and collection cardinality** before or during parse. In other words, refuse messages that are too large. Refuse messages that are nested too deep. Refuse messages that contain enormous arrays or maps.

Never run language-native deserialize on untrusted bytes. That ban covers pickle, Java serialization, unsafe YAML load, and legacy binary formatters. For zero-copy layouts, **verify** the buffer before field access. See 201 [zero-copy](../201/zero-copy.md). Suite speed numbers do not measure adversarial robustness.

This page assumes the security notes from the 101 engineering lens. Here we own the **operational playbook**.

---

## Constraints that matter

| Control | Why it matters |
|---------|----------------|
| **Who can send bytes?** | Internet clients, partners, internal multi-tenant callers, or only the same process |
| **Deserializer power** | Can the format reconstruct arbitrary types and code, or only pure data? |
| **Resource budget** | CPU, memory, and wall-clock time allowed per request |
| **Validation layer** | Schema checks, typed models, allowlists of accepted shapes |
| **Logging of payloads** | Captured bodies create cost and leak risk; see [payload surfaces](payload-surfaces.md) |

This matters because the “who” question changes the whole design. A parser that is fine for trusted same-process checkpoints is not fine for a public HTTP body.

---

## Decision frame

```text
  Untrusted producer?
    no  → still enforce size limits; the written security assumptions may be weaker
    yes → portable format + hard limits + validation
           never native deserialize
```

Even when the producer is trusted, size limits remain a good default. When the producer is untrusted, portable formats are mandatory. Hard resource caps are mandatory. Validation is mandatory.

| Risk class | Typical vectors | Mitigations |
|------------|-----------------|-------------|
| **Code execution** | pickle, Java serialization, gadget chains, unsafe YAML | Ban these on the boundary; accept pure data only |
| **Expansion and denial of service (DoS)** | Entity expansion, nested bombs, huge arrays | Disable dangerous features; enforce depth and size caps |
| **Allocation storms** | Many small objects created from one message | Caps; streaming parsers where appropriate |
| **Type confusion** | JSON number versus string; duplicate keys | Schema or typed decode; strict parsers |
| **Unverified zero-copy** | Crafted offsets into a buffer | Run a verifier before use |

**Denial of service (DoS)** means making a system unavailable by exhausting its resources. A nested “bomb” is a tiny message that expands into a huge structure during parse.

---

## Failure modes

| Mistake | Outcome |
|---------|---------|
| Treating “internal network” as fully trusted | Lateral movement inside the network becomes remote code execution |
| Putting limits only at the gateway | A sidecar or admin path bypasses them |
| Validating only after building full language objects in memory | You already paid the denial-of-service cost |
| Never running fuzz tests | Edge cases ship straight to production |
| Choosing a codec by Dashboard numbers alone | A fast but unsafe path wins the architecture decision record |

For example, suppose validation runs only after you have already built a giant object tree in memory. A malicious payload has already hurt you. That is true even if you eventually reject it.

---

## Real-world sketch

An internal API accepts MessagePack from other services. Later it also accepts MessagePack from a partner VPN. There is no maximum nesting depth. A nested map bomb locks workers. Separately, a debug endpoint still accepts pickle “for support tools.”

The pickle path is the incident class that ends careers. The depth bomb is the one that ends reliability targets (*service-level objectives*, or SLOs). One example is “99% of requests finish within 200 ms.” Both failures are **boundary design** failures. They are not “we picked the wrong MessagePack library.”

---

## In this suite

| Resource | Role |
|----------|------|
| Language **Overview** | Notes on native codecs and fidelity—not security proofs |
| **Dashboard** | Encode and decode cost under **benign** fixtures |
| [Using this suite](using-this-suite.md) | Why you must not treat speed as safety |
| [Trust boundaries](trust-boundaries.md) | Portable versus native policy |

This benchmark runner does **not** run adversarial fuzz campaigns. It does not claim parser security. **Fuzzing** means feeding large numbers of random or semi-random inputs to find crashes and edge cases.

---

## Experiments

**Question:** For this deserialize path, are **hostile-payload controls** sufficient, and is the codec class acceptable?

### Setup

1. Identify every public or multi-tenant parse entry point.
2. Note the codec (JSON, Protobuf, native, and so on) and the maximum request size at the edge.
3. Gather parser settings. Include depth limits and document size limits. Note known CVE posture. **CVE** means common vulnerabilities and exposures. Those are published security issues in software.

### Procedure

1. Walk a threat checklist. Cover code execution through native deserialize. Cover expansion bombs. Cover huge allocations. Cover deeply nested structures.
2. Verify **hard limits** on body size, depth, and collection cardinality before or during parse.
3. Confirm that native, pickle, and Java serialization paths are **banned** on untrusted routes.
4. Optionally fuzz or inject adversarial fixtures. Watch process memory and time-to-failure.
5. Use the Dashboard only for performance among **safe** portable codecs.

### Decision rule

- Any untrusted path with native deserialize is a **fail**. Any untrusted path with no size or depth limits is also a **fail**. Fix that before optimizing.
- Among safe codecs, use the implementation-variance and latency experiments as usual.

---

## Metrics

| Metric / signal | Role |
|-----------------|------|
| **Max body size enforced** | **Primary** control metric |
| **Max depth and array size** | Expansion and stack risk |
| **Time and memory to reject** huge or nested payloads | Denial-of-service resistance |
| Parser error rate on fuzz inputs | Robustness signal |
| CVE and advisory state of the library | Eligibility filter |
| Suite speed and size | Secondary after the safety pass |
| `mean_fidelity` | Still required for correctness |

**Conclusion style:** “The edge enforces 1 MB and depth 32; we use JSON library X; native deserialize is banned.”

---

## What this suite cannot tell you

- Whether a library is free of known CVEs.
- The correct absolute limits for *your* memory budget.
- How effective your WAF rules or service-mesh policies are. A **WAF** is a web application firewall. It is a filter in front of HTTP services.
- Whether gadgets exist in *your* dependency graph.

---

## Common mistakes

- Enabling “convenient” native deserialize behind authentication only. Authentication answers “who are you?” It does not make hostile bytes safe to execute as code.
- Logging full hostile bodies. That amplifies cost and leak risk.
- Skipping verification on FlatBuffers-class buffers for speed.

---

## Key takeaways

- Deserialize is an **attack surface**. Design limits first.
- Portable formats plus validation plus size and depth caps is the default for untrusted bytes.
- Native deserialize is a special case of “trusted only.”
- Dashboard numbers answer cost under honest fixtures. They do not answer adversarial hardness.
