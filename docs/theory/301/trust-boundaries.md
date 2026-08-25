# Trust boundaries: portable vs native

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/leo-gan/GLD.SerializerBenchmark/blob/master/docs/theory/notebooks/301/trust_boundaries.ipynb)
**Lab notebook:** [Trust boundaries experiment](../notebooks/301/trust_boundaries.ipynb)

## Problem

Imagine you finish a class project in Python. You have a complex object in memory. It may hold nested dictionaries, custom classes, and timestamps. You want to save it for later. A language-native serializer can dump the whole object graph in one call. Python’s `pickle` is one example. Java serialization and many .NET binary formatters are others. That convenience is real. Such tools often look strong on microbenchmarks for complex graphs. They also preserve type details that portable formats handle awkwardly.

Teams then take those same bytes and place them on a **queue**. A queue is a store that hands messages to other processes. Teams also put the bytes in a **cache shared across services**. They put them in a **file that other teams can open**. Or they put them on a **network API**. At that moment the problem changes. The security and portability failures are not subtle. You can get **gadget chains**. Those are unexpected object graphs that trigger dangerous code during deserialize. You can get **remote code execution**. That means an attacker runs code on your machine by sending crafted bytes. You can also get version skew that only appears at runtime. And you can get permanent lock-in to one programming language.

The design question is not “is the native format fast?” The design question is **which trust and interoperability boundary the bytes cross**.

In this section we treat **trust** as first-class. Performance stays secondary until the trust test passes.

---

## Short answer

Treat **language-native** formats as **unsafe by default**. Use them only inside one process that you fully control. You may also use them on a tightly controlled same-stack path with authenticated peers and no untrusted input. Prefer **portable** formats whenever data is stored long-term. Prefer them when data is shared across languages. Prefer them when data is accepted from clients. Prefer them when data is exposed to multi-tenant input. Portable formats may be text or binary. They may be self-describing or schema-driven.

A **portable** format is one that many languages and tools can read using documented rules. Examples include JSON, MessagePack, and Protocol Buffers. A **language-native** format is built for one runtime’s object model. It is not a general interchange language.

Native formats remain useful for **trusted, same-runtime** checkpoints and caches. That is only true when the written security assumptions explicitly allow them (who is allowed to send data). Operators must also accept the lock-in.

This page assumes the 201 article on [self-describing vs schema](../201/self-describing-vs-schema-dependent.md). That article explains where field identity lives. Here we own **trust and portability policy**.

---

## Constraints that matter

| Constraint | Portable (JSON, MessagePack, Protobuf, and similar) | Language-native (pickle, Java serialization, and similar) |
|------------|-----------------------------------------------------|-----------------------------------------------------------|
| **Who may produce the bytes?** | Often untrusted clients or other teams | Must be fully trusted writers only |
| **Who may consume the bytes?** | Any language with a suitable library | Typically one runtime family |
| **Lifetime** | Can live for years on disk or in a log | Often breaks when class or layout definitions change |
| **Security** | You still need size limits and validation | Deserialization can become **code execution** |
| **Operations** | Debuggable with open tools (especially text formats) | Opaque without the exact type graph from the original deployment |
| **Performance** | Implementation-dependent (see the suite) | Sometimes excellent on graphs, and **irrelevant if the path is unsafe** |

In other words, portable formats buy you a wider world of readers and writers. Native formats buy convenience inside one runtime. The table above is not a speed ranking. It is a policy map.

---

## Decision frame

Ask one primary question first: **do these bytes leave this process or trust domain?**

A **trust domain** is a region where you control both who writes the data and who reads it. Both sides share the same security assumptions. Crossing a trust domain means a different process, team, language, or tenant may touch the bytes. The public internet may also touch them.

![Trust boundaries: process, set of services the organization runs, public untrusted](../assets/diagrams/301-trust-boundaries.svg#only-light)
![Trust boundaries: process, set of services the organization runs, public untrusted](../assets/diagrams/301-trust-boundaries-dark.svg#only-dark)

If the answer is yes, a portable format is required. If the answer is no, a native format may still be acceptable. That is only true when every peer is trusted and the lock-in is documented.

| Situation | Prefer | Avoid |
|-----------|--------|-------|
| Public or partner HTTP or RPC body | Portable format (often JSON plus validation, or an IDL-based binary format) | Language-native encodings |
| Multi-language microservices | Portable schema-driven or schemaless binary | Language-native encodings |
| Object store, data lake, or long-lived files | Portable (often columnar or Avro/Parquet-class for analytics data) | Native blobs as the system of record |
| Redis or memcache value used by **the same service binary only**, on a private network, with no user input | Native is *possible* if the written security assumptions are documented | Native if any other service or language may read the value |
| Machine-learning checkpoint used only by one training stack | Native is *common*; migrate to portable when sharing with other systems | Native as the only interchange with production services |
| “Faster than JSON on one language Dashboard slice” | Use that as **same-language** cost evidence only | Mandating native formats on the network |

This matters because a chart that shows native as “fast” never answers “is native safe as a public contract?”

---

## Failure modes

| Failure | What happens |
|---------|----------------|
| **Gadget chains and remote code execution (RCE)** | Hostile or merely unexpected bytes trigger class loading or dangerous code paths during deserialize |
| **Silent version skew** | Writer and reader disagree on class shape; errors show up at runtime and can be intermittent |
| **Multi-language (polyglot) surprise** | A second language team cannot consume the cache without rewriting the format |
| **Backup and forensics gap** | Incident response cannot inspect payloads without the original deployment’s type graph |
| **False safety** | “Internal network” is treated as trusted while multi-tenant jobs still share the bus |

For example, calling a network “internal” does not make every message trustworthy. Multi-tenant systems share infrastructure. A bug in one tenant can become input for another.

---

## Real-world sketch

A Python service caches session graphs with `pickle` in Redis for speed. Latency improves in a language Dashboard-style comparison of native versus JSON. Six months later a second service written in Go needs the same session data. The options become unpleasant. The team can keep dual writers. They can reverse-engineer a fragile parser. Or they can migrate to MessagePack or JSON with an explicit schema.

Separately, an SSRF-style bug appears. **Server-side request forgery** means tricking a server into fetching a URL chosen by an attacker. That bug lets an attacker influence a cache key path. If anything ever deserializes attacker-influenced pickle, the incident class changes. It is no longer a “data issue.” It becomes “remote code execution.” The original speed win did not price that risk.

---

## In this suite

| Resource | Role |
|----------|------|
| [Serialization categories](../../analysis/serialization_categories.md) | Labels the **language-native** family versus portable families |
| Language **Overview** | Shows which native codecs are registered (if any) and their caveats |
| [Dashboard](../../dashboard/) | Speed and size **within one language**—never a reason by itself to put native bytes on the wire |
| [Using this suite](using-this-suite.md) | How not to misread those numbers |
| [Engineering perspective](../101/engineer_perspective.md) | Product framing of native versus portable choices |

When native and portable entries both appear for a language, compare them only to answer one question. That question is “what do we pay for portability **in this runtime**?” Do not treat the comparison as “is native a good public contract?”

---

## Experiments

**Question:** May these bytes use a **language-native** codec, or must they be **portable**?

### Setup

1. Draw the data path. Show the producer process, then the store or queue or API, then the consumers.
2. Mark each hop. Note same process, same trust domain, multi-tenant, public, or multi-language.
3. List candidate native and portable codecs for the language. Suite categories help label them.

### Procedure

1. For each hop, answer this question: *Can an untrusted principal or another language supply or read these bytes?*
2. If **yes** on any long-lived or cross-service hop, a portable format is required. Native is disqualified for that hop.
3. If **no**, the path is trusted same-runtime only. Native is allowed *if* the written security assumptions and operations team accept the lock-in.
4. Document the policy in the service boundary checklist.
5. Optional suite check: compare native versus portable **only** for performance *after* policy allows native. Never use speed to override a failed trust test.

### Decision rule

- If trust or portability fails, choose portable. Do this regardless of suite speed.
- Suite timings may choose *which* portable family or implementation. They do not decide whether native is safe.

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
- Cross-language feasibility of a native blob. By definition, that feasibility is poor.

---

## Common mistakes

- Equating “internal” with “trusted for deserialize.”
- Using native speed on the Dashboard to justify a **public** or **multi-language** API.
- Storing native blobs as the system of record “until we rewrite.”
- Assuming schema-driven portable formats are “secure” without resource limits. Portable formats reduce *portability* risk. They do not remove all parser risk.

---

## Key takeaways

- The **trust boundary** decides portable versus native more than peak operations per second.
- Native formats are same-runtime convenience. The default answer for interchange is **no**.
- Portable formats are the default once bytes leave the process or meet other languages.
- The Dashboard may show native formats as fast. That is a **cost of portability** data point. It is not a security clearance.
- Document the written security assumptions (who is allowed to send data) if you still choose native for a private cache.
