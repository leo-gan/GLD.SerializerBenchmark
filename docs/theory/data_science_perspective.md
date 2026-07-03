# Data Science Perspective

**Question this page answers:** *What serialization choices matter for data work, analytics, and ML—and how do I choose among them?*

This is the **data & [ML](https://en.wikipedia.org/wiki/Machine_learning "ML — Machine learning")<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/Wikipedia-logo-v2.svg/16px-Wikipedia-logo-v2.svg.png" alt="" width="12" height="12" /> lens** of [Serialization 101](index.md). It assumes you have (or will get) the big-picture timeline from the [historical perspective](historical_perspective.md). It does **not** retell punched cards through [SOAP](https://en.wikipedia.org/wiki/SOAP "SOAP — Simple Object Access Protocol")<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/Wikipedia-logo-v2.svg/16px-Wikipedia-logo-v2.svg.png" alt="" width="12" height="12" />. For APIs, [RPC](https://en.wikipedia.org/wiki/Remote_procedure_call "RPC — Remote Procedure Call")<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/Wikipedia-logo-v2.svg/16px-Wikipedia-logo-v2.svg.png" alt="" width="12" height="12" />, caches, and systems performance, use the [engineering perspective](engineer_perspective.md).

Measured libraries and timings for **this suite** live under language **Overview** / **Results** and [Benchmarks](../analysis/index.md). This page is conceptual judgment for data practitioners.

> Linked terms with a small logo icon are first-occurrence encyclopedia links. Hover the term for a short tip. Only the icon marks the link type—no extra label text.

---

## Who this page is for

- Analysts and analytics engineers moving data between warehouses, lakes, and notebooks  
- ML engineers checkpointing models, features, and batch scores  
- Data platform folks choosing formats for [Kafka](https://en.wikipedia.org/wiki/Apache_Kafka "Apache Kafka — distributed event streaming platform")<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/Wikipedia-logo-v2.svg/16px-Wikipedia-logo-v2.svg.png" alt="" width="12" height="12" /> topics, [S3](https://en.wikipedia.org/wiki/Amazon_S3 "Amazon S3 — object storage service")<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/Wikipedia-logo-v2.svg/16px-Wikipedia-logo-v2.svg.png" alt="" width="12" height="12" /> layouts, and interchange with [Spark](https://en.wikipedia.org/wiki/Apache_Spark "Apache Spark — unified analytics engine")<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/Wikipedia-logo-v2.svg/16px-Wikipedia-logo-v2.svg.png" alt="" width="12" height="12" />/[DuckDB](https://en.wikipedia.org/wiki/DuckDB "DuckDB — in-process analytical SQL database")<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/Wikipedia-logo-v2.svg/16px-Wikipedia-logo-v2.svg.png" alt="" width="12" height="12" />/Polars  
- Scientists who currently “just pickle everything” and want a safer mental model  

If you only build [JSON](https://en.wikipedia.org/wiki/JSON "JSON — JavaScript Object Notation")<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/Wikipedia-logo-v2.svg/16px-Wikipedia-logo-v2.svg.png" alt="" width="12" height="12" /> [REST](https://en.wikipedia.org/wiki/REST "REST — Representational State Transfer")<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/Wikipedia-logo-v2.svg/16px-Wikipedia-logo-v2.svg.png" alt="" width="12" height="12" /> microservices, skim the decision guide and switch to [engineering](engineer_perspective.md).

---

## What “serialization” means in data work

In services, [serialization](https://en.wikipedia.org/wiki/Serialization "Serialization — converting structures to a byte sequence and back")<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/Wikipedia-logo-v2.svg/16px-Wikipedia-logo-v2.svg.png" alt="" width="12" height="12" /> often means **one message in, one message out**. In data work it usually means one or more of:

| Workload | Typical unit | What you optimize for |
|----------|--------------|------------------------|
| **Batch tables** | Partitions of rows/columns on object storage | Scan cost, compression, schema evolution over years |
| **Streaming events** | Records on a log (Kafka, etc.) | Compatibility between old/new producers & consumers |
| **Notebook ↔ production** | [DataFrames](https://en.wikipedia.org/wiki/pandas_%28software%29 "pandas — tabular data library commonly used via DataFrames")<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/Wikipedia-logo-v2.svg/16px-Wikipedia-logo-v2.svg.png" alt="" width="12" height="12" />, dicts, artifacts | Friction vs portability and safety |
| **Model artifacts** | Weights + preprocessing graph | Load speed, versioning, who may load the file |
| **Feature interchange** | Training/serving feature payloads | Stable types, low skew, predictable nulls |

Different workloads want different points on the [shared trade-off axes](index.md#shared-vocabulary-core-trade-offs) (text/binary, schema, row/columnar, portable/native).

---

## A minimal history for data people (only what you need)

Full story: [historical perspective](historical_perspective.md). The short version:

1. **Fixed-width & [CSV](https://en.wikipedia.org/wiki/Comma-separated_values "CSV — Comma-Separated Values")<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/Wikipedia-logo-v2.svg/16px-Wikipedia-logo-v2.svg.png" alt="" width="12" height="12" />** — still everywhere for exports and simple tables; weak typing; awkward nesting.  
2. **Language-native blobs (`pickle`, joblib, many ML checkpoints)** — maximum Python convenience; poor multi-language story; **unsafe on untrusted bytes**. See [pickle](https://en.wikipedia.org/wiki/Serialization#Python "pickle — Python object serialization")<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/Wikipedia-logo-v2.svg/16px-Wikipedia-logo-v2.svg.png" alt="" width="12" height="12" /> under language-native formats.  
3. **JSON lines / JSON documents** — universal glue; fine for small/medium configs and APIs; painful as a primary lake format at huge scale.  
4. **[Avro](https://en.wikipedia.org/wiki/Apache_Avro "Apache Avro — row-oriented binary with schemas")<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/Wikipedia-logo-v2.svg/16px-Wikipedia-logo-v2.svg.png" alt="" width="12" height="12" /> (+ schema registry patterns)** — row-oriented binary with a serious **evolution** story for event streams.  
5. **[Parquet](https://en.wikipedia.org/wiki/Apache_Parquet "Apache Parquet — columnar storage format")<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/Wikipedia-logo-v2.svg/16px-Wikipedia-logo-v2.svg.png" alt="" width="12" height="12" /> / [ORC](https://en.wikipedia.org/wiki/Apache_ORC "Apache ORC — Optimized Row Columnar")<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/Wikipedia-logo-v2.svg/16px-Wikipedia-logo-v2.svg.png" alt="" width="12" height="12" />** — **columnar** on-disk formats for analytic scans.  
6. **[Arrow](https://en.wikipedia.org/wiki/Apache_Arrow "Apache Arrow — in-memory columnar format")<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/Wikipedia-logo-v2.svg/16px-Wikipedia-logo-v2.svg.png" alt="" width="12" height="12" />** — shared **in-memory** columnar layout so engines exchange tables without endless convert/copy.  
7. **Validators ([JSON Schema](https://en.wikipedia.org/wiki/JSON#Schema_and_metadata "JSON Schema — vocabulary for validating JSON")<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/Wikipedia-logo-v2.svg/16px-Wikipedia-logo-v2.svg.png" alt="" width="12" height="12" />, Pydantic, msgspec, …)** — structure and types when the wire format stays JSON or [MessagePack](https://en.wikipedia.org/wiki/MessagePack "MessagePack — binary serialization of JSON-like values")<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/Wikipedia-logo-v2.svg/16px-Wikipedia-logo-v2.svg.png" alt="" width="12" height="12" />.

---

## The formats data teams actually live with

### CSV and “spreadsheet reality”

**Use when:** humans edit data; quick export/import; smallest common denominator.

**Avoid as system of record when:** types matter (dates, nulls vs empty strings), nesting appears, or multiple producers change columns silently.

CSV is not “wrong”—it is a **lossy social format**. Treat it as an edge adapter, not a lake core.

### JSON and JSON Lines (JSONL)

**Use when:** semi-structured logs, configs, small-to-medium interchange, landing zones before a typed table format.

**Costs:** repeated keys; number/date ambiguity; large files compress well but still parse slower than columnar binary for analytics.

**JSONL** (one JSON object per line) is a pragmatic streaming/batch compromise: append-friendly, parallelizable by line, still text.

### Language-native: pickle, joblib, and friends

```text
Trust boundary check (do this every time):
  Is the byte stream from a fully trusted source you control?
    NO  → do not unpickle / do not use native deserialize
    YES → still prefer portable formats for anything long-lived or multi-language
```

| Approach | Strength | Risk |
|----------|----------|------|
| `pickle` / `cloudpickle` | Almost any Python object graph | Code execution on load; Python-only |
| `joblib` | Convenient for [scikit-learn](https://en.wikipedia.org/wiki/Scikit-learn "scikit-learn — Python ML library")<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/Wikipedia-logo-v2.svg/16px-Wikipedia-logo-v2.svg.png" alt="" width="12" height="12" />-style arrays/pipelines | Same trust issues when backed by pickle-like protocols |
| Framework checkpoints (often pickle-based) | One-command save/load in that stack | Environment coupling; supply-chain & tampering risk |

**Practical rule:** use native formats for **ephemeral, trusted, same-environment** artifacts. For sharing, audit, or multi-year storage, prefer **explicit weights formats** (framework-specific safe loaders), **Arrow/Parquet tables**, or **versioned model registries**—not a raw pickle in an open bucket.

### Avro: events and evolving records

**Avro** stores values compactly and treats the **schema as a first-class object** (in file headers or an external registry). Reader and writer schemas can differ under documented compatibility rules (defaults, field addition/removal policies).

**Prefer when:**

- Producers and consumers change on different schedules  
- You need a long-lived event log with compatibility checks  
- Row-oriented access (full events) matters more than wide analytic scans  

**Operational reality:** schema **process** (registry, CI checks, compatibility mode) matters as much as the binary encoding.

### Parquet (and ORC): the analytic table default

**Columnar** layout stores each column’s values together, enabling:

- Reading only the columns a query needs  
- Better compression (similar values co-located)  
- Predicate pushdown / page skipping in mature engines  

**Prefer when:** data lakes, warehouse extracts, Spark/DuckDB/Polars/[Athena](https://en.wikipedia.org/wiki/Amazon_Athena "Amazon Athena — serverless SQL over data lakes")<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/Wikipedia-logo-v2.svg/16px-Wikipedia-logo-v2.svg.png" alt="" width="12" height="12" />-style scans, wide tables, read-heavy analytics.

**Avoid when:** you mostly fetch one nested document by key at low latency—that is still a **row/document** problem (or a specialized store), not Parquet’s sweet spot.

### Apache Arrow: stop converting DataFrames for a living

**Arrow** (project co-founded with **[Wes McKinney](https://en.wikipedia.org/wiki/Wes_McKinney "Wes McKinney — creator of pandas; co-founder of Apache Arrow")<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/Wikipedia-logo-v2.svg/16px-Wikipedia-logo-v2.svg.png" alt="" width="12" height="12" />** and others) standardizes **in-memory** columnar buffers (types, null bitmaps, nested layouts). When two tools speak Arrow, transfer can be a pointer handoff or a cheap [IPC](https://en.wikipedia.org/wiki/Inter-process_communication "IPC — Inter-process communication")<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/Wikipedia-logo-v2.svg/16px-Wikipedia-logo-v2.svg.png" alt="" width="12" height="12" /> stream instead of “to_csv → parse again.”

**Prefer when:**

- Crossing process boundaries in a data plane (Python ↔ DuckDB ↔ Polars ↔ Spark components, etc.)  
- Building zero-copy or low-copy pipelines  
- You want one logical table type across languages  

Arrow is complementary to Parquet: **Parquet on disk / in the lake**, **Arrow in memory / between engines** is a common modern pattern.

### MessagePack, [BSON](https://en.wikipedia.org/wiki/BSON "BSON — Binary JSON (MongoDB)")<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/Wikipedia-logo-v2.svg/16px-Wikipedia-logo-v2.svg.png" alt="" width="12" height="12" />, [CBOR](https://en.wikipedia.org/wiki/CBOR "CBOR — Concise Binary Object Representation")<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/Wikipedia-logo-v2.svg/16px-Wikipedia-logo-v2.svg.png" alt="" width="12" height="12" /> in data paths

These are **schemaless binary** encodings of JSON-like values:

| Format | Data-relevant note |
|--------|--------------------|
| **MessagePack** | Compact caches, internal service payloads, some feature buses |
| **BSON** | Document DB heritage ([MongoDB](https://en.wikipedia.org/wiki/MongoDB "MongoDB — document-oriented database")<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/Wikipedia-logo-v2.svg/16px-Wikipedia-logo-v2.svg.png" alt="" width="12" height="12" />); extra types (datetime, binary) |
| **CBOR** | Standards-track; constrained devices and some security/[IoT](https://en.wikipedia.org/wiki/Internet_of_things "IoT — Internet of Things")<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/Wikipedia-logo-v2.svg/16px-Wikipedia-logo-v2.svg.png" alt="" width="12" height="12" /> stacks |

They help when JSON is too slow/large but you still want a **dynamic** model. They do **not** replace Parquet for lake analytics.

### [Protobuf](https://en.wikipedia.org/wiki/Protocol_Buffers "Protocol Buffers — schema-driven binary format")<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/Wikipedia-logo-v2.svg/16px-Wikipedia-logo-v2.svg.png" alt="" width="12" height="12" /> / [Thrift](https://en.wikipedia.org/wiki/Apache_Thrift "Apache Thrift — IDL and RPC framework")<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/Wikipedia-logo-v2.svg/16px-Wikipedia-logo-v2.svg.png" alt="" width="12" height="12" /> at the data boundary

Schema-driven RPC formats show up when ML **serving** or feature stores talk to microservices. They are excellent **online** contracts; they are usually a poor **sole** lake format compared with Parquet for bulk analytics. Many platforms use **both**: Protobuf online, columnar offline.

---

## Schema evolution (the data team’s real pain)

“We added a field” is easy in a notebook and hard in a multi-year lake or event bus.

| Strategy | Idea | Typical home |
|----------|------|--------------|
| **Positional fixed width** | Every field has a byte offset | Legacy finance/mainframe feeds |
| **Writer schema + resolution** | Old/new schemas reconciled by rules | Avro + registry |
| **Field numbers** | Stable tags; ignore unknown | Protobuf-style systems |
| **Table schemas in the catalog** | Lakehouse table metadata + file footers | Parquet + Glue/Hive/Unity-style catalogs |
| **“Only append columns, never reuse names”** | Social contract | JSONL / ad-hoc pipelines (fragile) |

**Data science takeaway:** pick a format whose **evolution story matches your retention**. Ephemeral experiment? JSONL is fine. Seven years of events? Invest in Avro/registry or an equivalent contract process. Analytic tables? Plan column adds carefully and document null/default semantics.

---

## ML-specific guidance

### Features and training tables

- Store large training/feature tables as **Parquet** (or equivalent columnar) with explicit dtypes and partitioned layout (time, region, etc.).  
- Interchange between training jobs with **Arrow** where the stack supports it.  
- Keep a **data contract** (schema + meaning of nulls, units, categorical encodings)—format choice cannot replace documentation.

### Model artifacts

| Need | Prefer |
|------|--------|
| Same machine, trusted, rapid iteration | Framework native checkpoint (understand its trust model) |
| Portable inference, multi-language runtimes | [ONNX](https://en.wikipedia.org/wiki/Open_Neural_Network_Exchange "ONNX — Open Neural Network Exchange")<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/Wikipedia-logo-v2.svg/16px-Wikipedia-logo-v2.svg.png" alt="" width="12" height="12" /> / framework export formats / dedicated model servers |
| Bundle preprocessing + model for one Python service | Still better with versioned registry + immutable artifact IDs than ad-hoc pickles in chat threads |
| Audit / compliance | Formats and stores that support signing, lineage, and non-executable weights where possible |

### Experiment tracking vs production

Experiment trackers often accept pickles and arbitrary blobs. **Production promotion** should re-materialize critical data into **portable tables** and **reviewed model formats**, not “whatever was in `/tmp`.”

---

## Validation when JSON still wins

Data platforms still emit JSON for APIs, webhooks, and config. Pair text/schemaless payloads with an explicit contract:

- **JSON Schema / [OpenAPI](https://en.wikipedia.org/wiki/OpenAPI_Specification "OpenAPI — standard for HTTP API descriptions")<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/Wikipedia-logo-v2.svg/16px-Wikipedia-logo-v2.svg.png" alt="" width="12" height="12" />** for cross-team [HTTP](https://en.wikipedia.org/wiki/HTTP "HTTP — Hypertext Transfer Protocol")<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/Wikipedia-logo-v2.svg/16px-Wikipedia-logo-v2.svg.png" alt="" width="12" height="12" /> boundaries  
- **Pydantic / msgspec / similar** for Python services that ingest JSON or MessagePack  
- Table-level quality checks (orthogonal to wire format, but part of the same reliability story)

Validation is how you keep the flexibility of schemaless formats without surprise `null`s in production training jobs.

---

## Decision guide (start here when choosing)

```text
What is the primary access pattern?
│
├─ Analytic scans over many rows, few columns
│    → Parquet (disk/lake) + Arrow (memory/engines)
│
├─ Event stream with long retention & multiple consumer versions
│    → Avro (or similar) + schema registry + compatibility policy
│
├─ Human-edited or lowest-common-denominator export
│    → CSV (document the schema separately!)
│
├─ Application/API interchange, semi-structured, multi-language
│    → JSON (+ schema/validation if the contract matters)
│
├─ Compact internal dynamic payloads (not a lake table)
│    → MessagePack / CBOR (still validate at boundaries)
│
├─ Online low-latency service contract (features, inference I/O)
│    → Schema-driven (Protobuf/…) — see engineering perspective
│
└─ Python-only, trusted, short-lived object graph
     → pickle/joblib only with eyes open; plan a portable exit path
```

### Quick comparison for data workloads

| Format family | Human-readable | Best at | Weak at |
|---------------|----------------|---------|---------|
| CSV | Yes | Exchange with humans/tools | Types, nesting, evolution |
| JSON / JSONL | Yes | Universal semi-structured glue | Huge analytic tables |
| pickle / native | No | Rich Python graphs | Trust, portability, longevity |
| Avro | No | Evolving event records | “Just open in Excel” |
| Parquet / ORC | No | Lake analytics | Point lookups of one blob |
| Arrow | No (binary IPC) | In-memory multi-engine share | Being your only on-disk archive format (usually paired with Parquet) |
| MessagePack / CBOR | No | Compact dynamic messages | Replacing columnar lakes |
| Protobuf (etc.) | No | Online contracts / RPC | Sole format for wide analytics |

---

## How this suite relates (and what it does not replace)

This repository benchmarks **serializers** across languages and [categories](../analysis/serialization_categories.md) (JSON family, schemaless binary, schema-driven, language-native). That is invaluable for **encode/decode cost** of in-memory objects.

Data platform success also depends on **I/O layout, compression, partitioning, cluster execution, and schema governance**—topics larger than a single serialize call. Use suite **Results** to compare libraries; use this page to pick the **paradigm** before you micro-optimize a codec.

---

## Further reading

- [Historical perspective](historical_perspective.md) — why these designs appeared  
- [Engineering perspective](engineer_perspective.md) — services, security, performance mechanics  
- [Serialization categories](../analysis/serialization_categories.md) — suite taxonomy  
- [Benchmarks](../analysis/index.md) — measured results  
- Kleppmann, *Designing Data-Intensive Applications* — systems view of encoding & evolution  
- Apache Parquet, Arrow, and Avro official documentation  

---

**Next:** [Engineering perspective](engineer_perspective.md) if you also ship services, or [course home](index.md) / [benchmarks](../analysis/index.md) to go empirical.
