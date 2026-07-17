# Trust boundaries: portable vs native

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/leo-gan/GLD.SerializerBenchmark/blob/master/docs/theory/notebooks/301/trust_boundaries.ipynb)
**Lab notebook:** [Trust boundaries experiment](../notebooks/301/trust_boundaries.ipynb)


## Problem

Language-native serializers—Python `pickle`, Java serialization, many .NET binary formatters, and similar “dump the object graph” tools—are ergonomic inside one runtime. They often win microbenchmarks on complex graphs and preserve types that portable formats handle awkwardly. Teams then place those bytes on a **queue**, a **cache shared across services**, a **file that other teams can open**, or a **network API**. The security and portability failure modes are not subtle: gadget chains, version skew that only appears at runtime, and permanent lock-in to one language.

The design question is not “is native fast?” It is **which trust and interoperability boundary the bytes cross**.

## Short answer

Treat **language-native** encodings as **unsafe by default** for anything outside a single process trust domain (or a tightly controlled same-stack path with authenticated peers and no untrusted input). Prefer **portable** formats—text or binary, self-describing or schema-driven—whenever data is stored long-term, shared across languages, accepted from clients, or exposed to multi-tenant input. Native formats remain useful for **trusted, same-runtime** checkpoints and caches when the threat model explicitly allows them and operators accept the lock-in.

Assumes 201: [self-describing vs schema](../201/self-describing-vs-schema-dependent.md) for where field identity lives; this page owns **trust and portability policy**.

## Constraints that matter

| Constraint | Portable (JSON, MessagePack, Protobuf, …) | Language-native (pickle, Java ser, …) |
|------------|-------------------------------------------|----------------------------------------|
| **Who may produce bytes?** | Often untrusted clients or other teams | Must be fully trusted writers only |
| **Who may consume?** | Any language with a library | Typically one runtime family |
| **Lifetime** | Years on disk / in a log | Often broken by class/layout changes |
| **Security** | Still need limits and validation | Deserialization can become **code execution** |
| **Ops** | Debuggable with open tools (especially text) | Opaque without the exact type graph |
| **Performance** | Implementation-dependent (see suite) | Sometimes excellent on graphs—**irrelevant if unsafe** |

## Decision frame

```text
  Do bytes leave this process / trust domain?
        │
   no   │   yes
        │    │
        ▼    ▼
   Native    Portable format required
   may be    (choose family with 101/201 + categories)
   OK if
   trusted
   peers only
```

| Situation | Prefer | Avoid |
|-----------|--------|-------|
| Public or partner HTTP/RPC body | Portable (often JSON + validation, or IDL binary) | Native |
| Multi-language microservices | Portable schema-driven or schemaless binary | Native |
| Object store / lake / long-lived files | Portable (often columnar or Avro/Parquet-class for data) | Native blobs as system of record |
| Redis/memcache value, **same service binary only**, private network, no user input | Native *possible* if threat model documented | Native if any other service or language may read |
| ML checkpoint used only by one training stack | Native *common*; migrate to portable for sharing | Native as the only interchange with production services |
| “Faster than JSON in one language Results” | Use as **same-language** evidence only | Mandating native on the network |

## Failure modes

| Failure | What happens |
|---------|----------------|
| **Gadget / RCE** | Hostile or merely unexpected bytes trigger class loading or code paths during deserialize |
| **Silent version skew** | Writer and reader disagree on class shape; errors are runtime and intermittent |
| **Polyglot surprise** | A second language team cannot consume the cache without rewriting |
| **Backup / forensics gap** | Incident response cannot inspect payloads without the original deployment |
| **False safety** | “Internal network” treated as trusted while multi-tenant jobs share the bus |

## Real-world sketch

A Python service caches session graphs with `pickle` in Redis for speed. Latency improves on the language Results-style comparison of native vs JSON. Six months later a second service in Go needs the same session. Options become: keep dual writers, reverse-engineer a fragile parser, or migrate to MessagePack/JSON with an explicit schema. Separately, an SSRF-style bug lets an attacker influence a cache key path; if anything ever deserializes attacker-influenced pickle, the incident class changes from “data issue” to “remote code execution.” The original speed win did not price that risk.

## In this suite

| Resource | Role |
|----------|------|
| [Serialization categories](../../analysis/serialization_categories.md) | **Language-native** family vs portable families |
| Language **Overview** | Which native codecs are registered (if any) and caveats |
| Language **Results** | Speed/size **within one language**—never a reason to put native on the wire alone |
| [Using this suite](using-this-suite.md) | How not to misread those numbers |
| [Engineering perspective](../101/engineer_perspective.md) | Product framing of native vs portable |

When native and portable entries both appear for a language, compare them only to answer “what do we pay for portability **in this runtime**?”—not “is native a good public contract?”


## Experiments

**Question:** May these bytes use a **language-native** codec, or must they be **portable**?

### Setup
1. Draw the data path: producer process → store/queue/API → consumers.  
2. Mark each hop: same process, same trust domain, multi-tenant, public, multi-language.  
3. List candidate native vs portable codecs for the language (suite categories help label them).

### Procedure
1. For each hop, answer: *Can an untrusted or other-language principal supply or read bytes?*  
2. If **yes** on any long-lived or cross-service hop → portable required; native disqualified for that hop.  
3. If **no** (trusted same-runtime only) → native allowed *if* threat model and ops accept lock-in.  
4. Document the policy in the service boundary checklist.  
5. Optional suite check: compare native vs portable **only** for performance *after* policy allows native—never to override a failed trust test.

### Decision rule
- Trust/portability failure ⇒ portable, regardless of suite speed.  
- Suite timings may choose *which* portable family/impl, not whether native is safe.

## Metrics

| Metric / signal | Role |
|-----------------|------|
| **Trust-domain crossing** (yes/no per hop) | **Primary** decision variable |
| **Consumer language set** | Forces portable if >1 runtime family |
| **Attack surface** (untrusted producer?) | Forces portable + [untrusted input](untrusted-input.md) controls |
| **Retention / durability** | Long-lived native = version-skew risk |
| Suite `total_median_ns` / size | Secondary, only among **policy-allowed** codecs |
| `mean_fidelity` | Among allowed candidates |

**Conclusion style:** “Queue hop is multi-tenant → portable only; native pickle rejected despite speed.”  
**Not decision metrics:** native microbenchmark wins on unsafe boundaries.

## What this suite cannot tell you

- Whether a specific native stack has a known gadget chain in *your* dependency set.  
- Your network trust model, IAM boundaries, or multi-tenant isolation.  
- Compliance rules that forbid certain encodings at rest.  
- Cross-language feasibility of a native blob (by definition: poor).

## Common mistakes

- Equating “internal” with “trusted for deserialize.”  
- Using native speed on Results to justify a **public** or **multi-language** API.  
- Storing native blobs as the system of record “until we rewrite.”  
- Assuming schema-driven portable formats are “secure” without resource limits—portable reduces *portability* risk, not all parser risk.

## Key takeaways

- **Trust boundary** decides portable vs native more than peak ops/s.  
- Native = same-runtime convenience; default **no** for interchange.  
- Portable formats are the default once bytes leave the process or meet other languages.  
- Suite Results may show native as fast; that is a **cost of portability** data point, not a security clearance.  
- Document the threat model if you still choose native for a private cache.
