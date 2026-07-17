# Data Science Perspective

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/leo-gan/GLD.SerializerBenchmark/blob/master/docs/theory/notebooks/101/data_science_perspective.ipynb)
**Lab notebook:** [Data science lab](../notebooks/101/data_science_perspective.ipynb)


## Audience

- Analysts and analytics engineers moving data between warehouses, lakes, and notebooks  
- ML engineers checkpointing models, features, and batch scores  
- Data platform folks choosing formats for [Kafka](https://en.wikipedia.org/wiki/Apache_Kafka "Apache Kafka — distributed event streaming platform")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> topics, [S3](https://en.wikipedia.org/wiki/Amazon_S3 "Amazon S3 — object storage service")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> layouts, and interchange with [Spark](https://en.wikipedia.org/wiki/Apache_Spark "Apache Spark — unified analytics engine")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />/[DuckDB](https://en.wikipedia.org/wiki/DuckDB "DuckDB — in-process analytical SQL database")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />/Polars  
- Scientists who currently “just pickle everything” and want a safer mental model  

---

## In data work

In services, [serialization](https://en.wikipedia.org/wiki/Serialization "Serialization — converting structures to a byte sequence and back")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> often means **one message in, one message out**. In data work it usually means one or more of:

| Workload | Typical unit | What you optimize for |
|----------|--------------|------------------------|
| **Batch tables** | Partitions of rows/columns on object storage | Scan cost, compression, schema evolution over years |
| **Streaming events** | Records on a log (Kafka, etc.) | Compatibility between old/new producers & consumers |
| **Notebook ↔ production** | [DataFrames](https://en.wikipedia.org/wiki/pandas_%28software%29 "pandas — tabular data library commonly used via DataFrames")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />, dicts, artifacts | Friction vs portability and safety |
| **Model artifacts** | Weights + preprocessing graph | Load speed, versioning, who may load the file |
| **Feature interchange** | Training/serving feature payloads | Stable types, low skew, predictable nulls |

Different workloads want different points on the [core trade-off axes](index.md#core-trade-offs) (text/binary, schema, row/columnar, portable/native).

---

## Brief history

1. **Fixed-width & [CSV](https://en.wikipedia.org/wiki/Comma-separated_values "CSV — Comma-Separated Values")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />** — still everywhere for exports and simple tables; weak typing; awkward nesting.  
2. **Language-native blobs (`pickle`, joblib, many ML checkpoints)** — maximum Python convenience; poor multi-language story; **unsafe on untrusted bytes**. See [pickle](https://en.wikipedia.org/wiki/Serialization#Python "pickle — Python object serialization")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> under language-native formats.  
3. **JSON lines / JSON documents** — universal glue; fine for small/medium configs and APIs; painful as a primary lake format at huge scale.  
4. **[Avro](https://en.wikipedia.org/wiki/Apache_Avro "Apache Avro — row-oriented binary with schemas")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> (+ schema registry patterns)** — row-oriented binary with a serious **evolution** story for event streams.  
5. **[Parquet](https://en.wikipedia.org/wiki/Apache_Parquet "Apache Parquet — columnar storage format")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> / [ORC](https://en.wikipedia.org/wiki/Apache_ORC "Apache ORC — Optimized Row Columnar")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />** — **columnar** on-disk formats for analytic scans.  
6. **[Arrow](https://en.wikipedia.org/wiki/Apache_Arrow "Apache Arrow — in-memory columnar format")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />** — shared **in-memory** columnar layout so engines exchange tables without endless convert/copy.  
7. **Validators ([JSON Schema](https://en.wikipedia.org/wiki/JSON#Schema_and_metadata "JSON Schema — vocabulary for validating JSON")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />, Pydantic, msgspec, …)** — structure and types when the wire format stays JSON or [MessagePack](https://en.wikipedia.org/wiki/MessagePack "MessagePack — binary serialization of JSON-like values")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />.

---

## Common formats

### CSV

**Use when:** humans edit data; quick export/import; smallest common denominator.

**Avoid as system of record when:** types matter (dates, nulls vs empty strings), nesting appears, or multiple producers change columns silently.

CSV is not “wrong”—it is a **lossy social format**. Treat it as an edge adapter, not a lake core.

### JSON / JSONL

**Use when:** semi-structured logs, configs, small-to-medium interchange, landing zones before a typed table format.

**Costs:** repeated keys; number/date ambiguity; large files compress well but still parse slower than columnar binary for analytics.

**JSONL** (one JSON object per line) is a pragmatic streaming/batch compromise: append-friendly, parallelizable by line, still text.

### Pickle & friends

**Trust boundary check (do this every time):**

- Is the byte stream from a fully trusted source you control?
  - **No** → do not unpickle / do not use native deserialize
  - **Yes** → still prefer portable formats for anything long-lived or multi-language

| Approach | Strength | Risk |
|----------|----------|------|
| `pickle` / `cloudpickle` | Almost any Python object graph | Code execution on load; Python-only |
| `joblib` | Convenient for [scikit-learn](https://en.wikipedia.org/wiki/Scikit-learn "scikit-learn — Python ML library")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />-style arrays/pipelines | Same trust issues when backed by pickle-like protocols |
| Framework checkpoints (often pickle-based) | One-command save/load in that stack | Environment coupling; supply-chain & tampering risk |

**Practical rule:** use native formats for **ephemeral, trusted, same-environment** artifacts. For sharing, audit, or multi-year storage, prefer **explicit weights formats** (framework-specific safe loaders), **Arrow/Parquet tables**, or **versioned model registries**—not a raw pickle in an open bucket.

### Avro

**Avro** stores values compactly and treats the **schema as a first-class object** (in file headers or an external registry). Reader and writer schemas can differ under documented compatibility rules (defaults, field addition/removal policies).

**Prefer when:**

- Producers and consumers change on different schedules  
- You need a long-lived event log with compatibility checks  
- Row-oriented access (full events) matters more than wide analytic scans  

**Operational reality:** schema **process** (registry, CI checks, compatibility mode) matters as much as the binary encoding.

### Parquet & ORC

**Columnar** layout stores each column’s values together, enabling:

- Reading only the columns a query needs  
- Better compression (similar values co-located)  
- Predicate pushdown / page skipping in mature engines  

**Prefer when:** data lakes, warehouse extracts, Spark/DuckDB/Polars/[Athena](https://en.wikipedia.org/wiki/Amazon_Athena "Amazon Athena — serverless SQL over data lakes")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />-style scans, wide tables, read-heavy analytics.

**Avoid when:** you mostly fetch one nested document by key at low latency—that is still a **row/document** problem (or a specialized store), not Parquet’s sweet spot.

### Arrow

**Arrow** (project co-founded with **[Wes McKinney](https://en.wikipedia.org/wiki/Wes_McKinney "Wes McKinney — creator of pandas; co-founder of Apache Arrow")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />** and others) standardizes **in-memory** columnar buffers (types, null bitmaps, nested layouts). When two tools speak Arrow, transfer can be a pointer handoff or a cheap [IPC](https://en.wikipedia.org/wiki/Inter-process_communication "IPC — Inter-process communication")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> stream instead of “to_csv → parse again.”

**Prefer when:**

- Crossing process boundaries in a data plane (Python ↔ DuckDB ↔ Polars ↔ Spark components, etc.)  
- Building zero-copy or low-copy pipelines  
- You want one logical table type across languages  

Arrow is complementary to Parquet: **Parquet on disk / in the lake**, **Arrow in memory / between engines** is a common modern pattern.

### MessagePack / BSON / CBOR

These are **schemaless binary** encodings of JSON-like values:

| Format | Data-relevant note |
|--------|--------------------|
| **MessagePack** | Compact caches, internal service payloads, some feature buses |
| **BSON** | Document DB heritage ([MongoDB](https://en.wikipedia.org/wiki/MongoDB "MongoDB — document-oriented database")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />); extra types (datetime, binary) |
| **CBOR** | Standards-track; constrained devices and some security/[IoT](https://en.wikipedia.org/wiki/Internet_of_things "IoT — Internet of Things")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> stacks |

They help when JSON is too slow/large but you still want a **dynamic** model. They do **not** replace Parquet for lake analytics.

### Protobuf & Thrift

Schema-driven RPC formats show up when ML **serving** or feature stores talk to microservices. They are excellent **online** contracts; they are usually a poor **sole** lake format compared with Parquet for bulk analytics. Many platforms use **both**: Protobuf online, columnar offline.

---

## Schema evolution

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

## ML guidance

### Features & tables

- Store large training/feature tables as **Parquet** (or equivalent columnar) with explicit dtypes and partitioned layout (time, region, etc.).  
- Interchange between training jobs with **Arrow** where the stack supports it.  
- Keep a **data contract** (schema + meaning of nulls, units, categorical encodings)—format choice cannot replace documentation.

### Model artifacts

| Need | Prefer |
|------|--------|
| Same machine, trusted, rapid iteration | Framework native checkpoint (understand its trust model) |
| Portable inference, multi-language runtimes | [ONNX](https://en.wikipedia.org/wiki/Open_Neural_Network_Exchange "ONNX — Open Neural Network Exchange")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> / framework export formats / dedicated model servers |
| Bundle preprocessing + model for one Python service | Still better with versioned registry + immutable artifact IDs than ad-hoc pickles in chat threads |
| Audit / compliance | Formats and stores that support signing, lineage, and non-executable weights where possible |

### Experiments vs production

Experiment trackers often accept pickles and arbitrary blobs. **Production promotion** should re-materialize critical data into **portable tables** and **reviewed model formats**, not “whatever was in `/tmp`.”

---

## JSON validation

Data platforms still emit JSON for APIs, webhooks, and config. Pair text/schemaless payloads with an explicit contract:

- **JSON Schema / [OpenAPI](https://en.wikipedia.org/wiki/OpenAPI_Specification "OpenAPI — standard for HTTP API descriptions")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />** for cross-team [HTTP](https://en.wikipedia.org/wiki/HTTP "HTTP — Hypertext Transfer Protocol")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> boundaries  
- **Pydantic / msgspec / similar** for Python services that ingest JSON or MessagePack  
- Table-level quality checks (orthogonal to wire format, but part of the same reliability story)

Validation is how you keep the flexibility of schemaless formats without surprise `null`s in production training jobs.

---

## Decision guide

**What is the primary access pattern?**

| If you need… | Prefer… |
|--------------|---------|
| Analytic scans over many rows, few columns | **Parquet** (disk/lake) + **Arrow** (memory/engines) |
| Event stream with long retention and multiple consumer versions | **Avro** (or similar) + schema registry + compatibility policy |
| Human-edited or lowest-common-denominator export | **CSV** (document the schema separately) |
| Application/API interchange, semi-structured, multi-language | **JSON** (+ schema/validation if the contract matters) |
| Compact internal dynamic payloads (not a lake table) | **MessagePack** / **CBOR** (still validate at boundaries) |
| Online low-latency service contract (features, inference I/O) | **Schema-driven** (Protobuf/…) — see [engineering perspective](engineer_perspective.md) |
| Python-only, trusted, short-lived object graph | **pickle** / **joblib** only with eyes open; plan a portable exit path |

### Quick comparison

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

## This suite

This repository benchmarks **serializers** across languages and categories (JSON family, schemaless binary, schema-driven, language-native). That is invaluable for **encode/decode cost** of in-memory objects.

Data platform success also depends on **I/O layout, compression, partitioning, cluster execution, and schema governance**—topics larger than a single serialize call. Use suite **Results** to compare libraries; use this page to pick the **paradigm** before you micro-optimize a codec.

---

## Further reading

- Kleppmann, *Designing Data-Intensive Applications* — systems view of encoding & evolution  
- Apache Parquet, Arrow, and Avro official documentation  
