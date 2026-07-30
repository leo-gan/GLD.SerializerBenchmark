# Trust boundaries: portable vs native

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/leo-gan/GLD.SerializerBenchmark/blob/master/docs/theory/notebooks/301/trust_boundaries.ipynb)
**Lab notebook:** [Trust boundaries experiment](../notebooks/301/trust_boundaries.ipynb)

## Problem

Imagine you finish a class project in Python. You have a complex object in memory—nested dictionaries, custom classes, timestamps—and you want to save it for later. A language-native serializer such as Python’s `pickle` (or Java serialization, or many .NET binary formatters) can “dump the object graph” in one call. That convenience is real: such tools often look strong on microbenchmarks for complex graphs, and they preserve type details that portable formats handle awkwardly.

Teams then take those same bytes and place them on a **queue** (a store that hands messages to other processes), a **cache shared across services**, a **file that other teams can open**, or a **network API**. At that moment the problem changes. The security and portability failure modes are not subtle. You can get **gadget chains** (unexpected object graphs that trigger dangerous code during deserialize), **remote code execution** (an attacker runs code on your machine by sending crafted bytes), version skew that only appears at runtime, and permanent lock-in to one programming language.

The design question is not “is the native format fast?” The design question is **which trust and interoperability boundary the bytes cross**.

In this section we treat **trust** as first-class. Performance remains secondary until the trust test passes.

---

## Short answer

Treat **language-native** encodings as **unsafe by default** for anything outside a single-process trust domain (or a tightly controlled same-stack path with authenticated peers and no untrusted input). Prefer **portable** formats—text or binary, self-describing or schema-driven—whenever data is stored long-term, shared across languages, accepted from clients, or exposed to multi-tenant input.

A **portable** format is one that many languages and tools can read using documented rules. Examples include JSON, MessagePack, and Protocol Buffers. A **language-native** format is built for one runtime’s object model; it is not a general interchange language.

Native formats remain useful for **trusted, same-runtime** checkpoints and caches when the threat model explicitly allows them and operators accept the lock-in.

This page assumes the 201 article on [self-describing vs schema](../201/self-describing-vs-schema-dependent.md) for where field identity lives. Here we own **trust and portability policy**.

---

## Constraints that matter

| Constraint | Portable (JSON, MessagePack, Protobuf, and similar) | Language-native (pickle, Java serialization, and similar) |
|------------|-----------------------------------------------------|-----------------------------------------------------------|
| **Who may produce the bytes?** | Often untrusted clients or other teams | Must be fully trusted writers only |
| **Who may consume the bytes?** | Any language with a suitable library | Typically one runtime family |
| **Lifetime** | Can live for years on disk or in a log | Often breaks when class or layout definitions change |
| **Security** | You still need size limits and validation | Deserialization can become **code execution** |
| **Operations** | Debuggable with open tools (especially text formats) | Opaque without the exact type graph from the original deployment |
| **Performance** | Implementation-dependent (see the suite) | Sometimes excellent on graphs—and **irrelevant if the path is unsafe** |

In other words, portable formats buy you a wider world of readers and writers. Native formats buy convenience inside one runtime. The table above is not a speed ranking; it is a policy map.

---

## Decision frame

Ask one primary question first: **do these bytes leave this process or trust domain?**

A **trust domain** is a region where you control both who writes the data and who reads it under the same security assumptions. Crossing a trust domain means a different process, team, language, tenant, or the public internet may touch the bytes.

![Trust boundaries: process, service estate, public untrusted](../assets/diagrams/301-trust-boundaries.svg#only-light)
![Trust boundaries: process, service estate, public untrusted](../assets/diagrams/301-trust-boundaries-dark.svg#only-dark)

If the answer is yes, a portable format is required. If the answer is no, a native format may still be acceptable—only when every peer is trusted and the lock-in is documented.

| Situation | Prefer | Avoid |
|-----------|--------|-------|
| Public or partner HTTP or RPC body | Portable format (often JSON plus validation, or an IDL-based binary format) | Language-native encodings |
| Multi-language microservices | Portable schema-driven or schemaless binary | Language-native encodings |
| Object store, data lake, or long-lived files | Portable (often columnar or Avro/Parquet-class for analytics data) | Native blobs as the system of record |
| Redis or memcache value used by **the same service binary only**, on a private network, with no user input | Native is *possible* if the threat model is written down | Native if any other service or language may read the value |
| Machine-learning checkpoint used only by one training stack | Native is *common*; migrate to portable when sharing with other systems | Native as the only interchange with production services |
| “Faster than JSON on one language Results page” | Use that as **same-language** cost evidence only | Mandating native formats on the network |

This matters because a chart that shows native as “fast” never answers “is native safe as a public contract?”

---

## Failure modes

| Failure | What happens |
|---------|----------------|
| **Gadget chains and remote code execution (RCE)** | Hostile or merely unexpected bytes trigger class loading or dangerous code paths during deserialize |
| **Silent version skew** | Writer and reader disagree on class shape; errors show up at runtime and can be intermittent |
| **Polyglot surprise** | A second language team cannot consume the cache without rewriting the format |
| **Backup and forensics gap** | Incident response cannot inspect payloads without the original deployment’s type graph |
| **False safety** | “Internal network” is treated as trusted while multi-tenant jobs still share the bus |

For example, calling a network “internal” does not make every message trustworthy. Multi-tenant systems share infrastructure; a bug in one tenant can become input for another.

---

## Real-world sketch

A Python service caches session graphs with `pickle` in Redis for speed. Latency improves in a language Results-style comparison of native versus JSON. Six months later a second service written in Go needs the same session data. The options become: keep dual writers, reverse-engineer a fragile parser, or migrate to MessagePack or JSON with an explicit schema.

Separately, an SSRF-style bug (**server-side request forgery**—tricking a server into fetching a URL chosen by an attacker) lets an attacker influence a cache key path. If anything ever deserializes attacker-influenced pickle, the incident class changes from “data issue” to “remote code execution.” The original speed win did not price that risk.

---

## In this suite

| Resource | Role |
|----------|------|
| [Serialization categories](../../analysis/serialization_categories.md) | Labels the **language-native** family versus portable families |
| Language **Overview** | Shows which native codecs are registered (if any) and their caveats |
| Language **Results** | Speed and size **within one language**—never a reason by itself to put native bytes on the wire |
| [Using this suite](using-this-suite.md) | How not to misread those numbers |
| [Engineering perspective](../101/engineer_perspective.md) | Product framing of native versus portable choices |

When native and portable entries both appear for a language, compare them only to answer “what do we pay for portability **in this runtime**?” Do not treat the comparison as “is native a good public contract?”

---

## Experiments

**Question:** May these bytes use a **language-native** codec, or must they be **portable**?

### Setup

1. Draw the data path: producer process, then store or queue or API, then consumers.
2. Mark each hop: same process, same trust domain, multi-tenant, public, multi-language.
3. List candidate native and portable codecs for the language. Suite categories help label them.

### Procedure

1. For each hop, answer: *Can an untrusted principal or another language supply or read these bytes?*
2. If **yes** on any long-lived or cross-service hop, a portable format is required and native is disqualified for that hop.
3. If **no** (trusted same-runtime only), native is allowed *if* the threat model and operations team accept the lock-in.
4. Document the policy in the service boundary checklist.
5. Optional suite check: compare native versus portable **only** for performance *after* policy allows native. Never use speed to override a failed trust test.

### Decision rule

- If trust or portability fails, choose portable, regardless of suite speed.
- Suite timings may choose *which* portable family or implementation, not whether native is safe.

---

## Metrics

| Metric / signal | Role |
|-----------------|------|
| **Trust-domain crossing** (yes or no per hop) | **Primary** decision variable |
| **Consumer language set** | Forces portable if more than one runtime family is involved |
| **Attack surface** (untrusted producer?) | Forces portable formats plus [untrusted input](untrusted-input.md) controls |
| **Retention and durability** | Long-lived native data means long-lived version-skew risk |
| Suite `total_median_ns` and size | Secondary, only among **policy-allowed** codecs |
| `mean_fidelity` | Correctness filter among allowed candidates |

**Conclusion style:** “The queue hop is multi-tenant, so only portable formats are allowed; native pickle is rejected despite its speed.”

**Not decision metrics:** native microbenchmark wins on unsafe boundaries.

---

## What this suite cannot tell you

- Whether a specific native stack has a known gadget chain in *your* dependency set.
- Your network trust model, identity and access (IAM) boundaries, or multi-tenant isolation story.
- Compliance rules that forbid certain encodings at rest.
- Cross-language feasibility of a native blob (by definition, it is poor).

---

## Common mistakes

- Equating “internal” with “trusted for deserialize.”
- Using native speed on Results to justify a **public** or **multi-language** API.
- Storing native blobs as the system of record “until we rewrite.”
- Assuming schema-driven portable formats are “secure” without resource limits. Portable formats reduce *portability* risk; they do not remove all parser risk.

---

## Key takeaways

- The **trust boundary** decides portable versus native more than peak operations per second.
- Native formats are same-runtime convenience. The default answer for interchange is **no**.
- Portable formats are the default once bytes leave the process or meet other languages.
- Suite Results may show native formats as fast. That is a **cost of portability** data point, not a security clearance.
- Document the threat model if you still choose native for a private cache.
