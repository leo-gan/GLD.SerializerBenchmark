# Data Science Perspective

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/leo-gan/GLD.SerializerBenchmark/blob/master/docs/theory/notebooks/101/data_science_perspective.ipynb)
**Lab notebook:** [Data science lab](../notebooks/101/data_science_perspective.ipynb)

## Who this page is for

This lens is written for people who move **tables, events, features, and models**—not only single API messages:

- Analysts and analytics engineers who move data between warehouses, lakes, and notebooks  
- Machine-learning engineers who checkpoint models, features, and batch scores  
- Data platform engineers who choose formats for [Kafka](https://en.wikipedia.org/wiki/Apache_Kafka "Apache Kafka — distributed event streaming platform")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> topics, [S3](https://en.wikipedia.org/wiki/Amazon_S3 "Amazon S3 — object storage service")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> layouts, and interchange with [Spark](https://en.wikipedia.org/wiki/Apache_Spark "Apache Spark — unified analytics engine")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />, [DuckDB](https://en.wikipedia.org/wiki/DuckDB "DuckDB — in-process analytical SQL database")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />, or Polars  
- Scientists who currently “just pickle everything” and want a safer mental model  

---

## How data work differs from service work

In services, [serialization](https://en.wikipedia.org/wiki/Serialization "Serialization — converting structures to a byte sequence and back")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> often means **one message in, one message out**. In data work it usually means one or more of the following:

| Workload | Typical unit | What you usually optimize for |
|----------|--------------|-------------------------------|
| **Batch tables** | Partitions of rows or columns on object storage | Scan cost, compression, schema evolution over years |
| **Streaming events** | Records on a log (Kafka and similar) | Compatibility between old and new producers and consumers |
| **Notebook ↔ production** | [DataFrames](https://en.wikipedia.org/wiki/pandas_%28software%29 "pandas — tabular data library commonly used via DataFrames")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />, dictionaries, artifacts | Friction versus portability and safety |
| **Model artifacts** | Weights plus preprocessing graph | Load speed, versioning, who is allowed to load the file |
| **Feature interchange** | Training and serving feature payloads | Stable types, low training/serving skew, predictable nulls |

Different workloads want different points on the [core trade-off axes](index.md#core-trade-offs): text versus binary, schema versus schemaless, row versus columnar, portable versus language-native.

---

## A short history of formats in data work

1. **Fixed-width layouts and [CSV](https://en.wikipedia.org/wiki/Comma-separated_values "CSV — Comma-Separated Values")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />** — still everywhere for exports and simple tables; weak typing; awkward nesting.  
2. **Language-native blobs (`pickle`, joblib, many machine-learning checkpoints)** — maximum Python convenience; poor multi-language story; **unsafe on untrusted bytes**. See [pickle](https://en.wikipedia.org/wiki/Serialization#Python "pickle — Python object serialization")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> under language-native formats.  
3. **JSON documents and JSON Lines** — universal glue; fine for small or medium configs and APIs; painful as a primary lake format at huge scale.  
4. **[Avro](https://en.wikipedia.org/wiki/Apache_Avro "Apache Avro — row-oriented binary with schemas")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> (plus schema registry patterns)** — row-oriented binary with a serious **evolution** story for event streams.  
5. **[Parquet](https://en.wikipedia.org/wiki/Apache_Parquet "Apache Parquet — columnar storage format")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> / [ORC](https://en.wikipedia.org/wiki/Apache_ORC "Apache ORC — Optimized Row Columnar")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />** — **columnar** on-disk formats for analytic scans.  
6. **[Arrow](https://en.wikipedia.org/wiki/Apache_Arrow "Apache Arrow — in-memory columnar format")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />** — shared **in-memory** columnar layout so engines exchange tables without endless convert-and-copy cycles.  
7. **Validators ([JSON Schema](https://en.wikipedia.org/wiki/JSON#Schema_and_metadata "JSON Schema — vocabulary for validating JSON")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />, Pydantic, msgspec, and similar)** — structure and types when the wire format stays JSON or [MessagePack](https://en.wikipedia.org/wiki/MessagePack "MessagePack — binary serialization of JSON-like values")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />.

---

## Common formats in plain language

### CSV

**Use it when** humans edit data, you need a quick export or import, or you need the smallest common denominator between tools.

**Avoid it as the system of record when** types matter (dates, nulls versus empty strings), nesting appears, or multiple producers change columns silently.

CSV is not “wrong.” It is a **lossy social format**. Treat it as an edge adapter, not as the core of a data lake.

### JSON and JSON Lines

**Use them when** you need semi-structured logs, configuration, small-to-medium interchange, or a landing zone before a typed table format.

**Costs include** repeated keys on every object, ambiguity around numbers and dates, and parse cost that stays higher than mature columnar binary formats for large analytics—even when compression shrinks the file.

**JSON Lines** (one JSON object per line, often abbreviated JSONL) is a pragmatic compromise for streaming and batch: append-friendly, parallelizable by line, still text.

### Pickle and friends

**Trust boundary check—do this every time:**

- Is the byte stream from a fully trusted source you control?
  - **No** → do not unpickle and do not use other native “deserialize anything” APIs.
  - **Yes** → still prefer portable formats for anything long-lived or multi-language.

| Approach | Strength | Risk |
|----------|----------|------|
| `pickle` / `cloudpickle` | Almost any Python object graph | Code execution on load; Python-only |
| `joblib` | Convenient for [scikit-learn](https://en.wikipedia.org/wiki/Scikit-learn "scikit-learn — Python ML library")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />-style arrays and pipelines | Same trust issues when backed by pickle-like protocols |
| Framework checkpoints (often pickle-based) | One-command save and load inside that stack | Environment coupling; supply-chain and tampering risk |

**Practical rule:** use native formats for **ephemeral, trusted, same-environment** artifacts. For sharing, audit, or multi-year storage, prefer **explicit weight formats** (framework-specific safe loaders), **Arrow or Parquet tables**, or **versioned model registries**—not a raw pickle file in an open bucket.

### Avro

**Avro** stores values compactly and treats the **schema as a first-class object** (in file headers or an external registry). Reader and writer schemas can differ under documented compatibility rules (defaults, field addition and removal policies).

**Prefer Avro when:**

- Producers and consumers change on different schedules  
- You need a long-lived event log with compatibility checks  
- Row-oriented access (full events) matters more than wide analytic scans  

**Operational reality:** the schema **process** (registry, continuous-integration checks, compatibility mode) matters as much as the binary encoding itself.

### Parquet and ORC

**Columnar** layout stores each column’s values together. That enables:

- Reading only the columns a query needs  
- Better compression, because similar values sit next to each other  
- Predicate pushdown and page skipping in mature engines  

**Prefer these when** you run data lakes, warehouse extracts, Spark/DuckDB/Polars/[Athena](https://en.wikipedia.org/wiki/Amazon_Athena "Amazon Athena — serverless SQL over data lakes")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />-style scans, wide tables, or read-heavy analytics.

**Avoid them when** you mostly fetch one nested document by key at low latency. That is still a **row or document** problem (or a specialized store), not Parquet’s sweet spot.

### Arrow

**Arrow** (the project was co-founded with **[Wes McKinney](https://en.wikipedia.org/wiki/Wes_McKinney "Wes McKinney — creator of pandas; co-founder of Apache Arrow")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />** and others) standardizes **in-memory** columnar buffers: types, null bitmaps, nested layouts. When two tools speak Arrow, transfer can be a pointer handoff or a cheap [inter-process communication (IPC)](https://en.wikipedia.org/wiki/Inter-process_communication "IPC — Inter-process communication")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> stream instead of “write CSV, then parse again.”

**Prefer Arrow when:**

- You cross process boundaries in a data plane (Python ↔ DuckDB ↔ Polars ↔ Spark components, for example)  
- You build zero-copy or low-copy pipelines  
- You want one logical table type across languages  

Arrow is complementary to Parquet. A common modern pattern is **Parquet on disk in the lake**, **Arrow in memory between engines**. Arrow is not usually your only long-term archive format by itself.

### MessagePack, BSON, and CBOR

These are **schemaless binary** encodings of JSON-like values:

| Format | Note for data work |
|--------|--------------------|
| **MessagePack** | Compact caches, internal service payloads, some feature buses |
| **BSON** | Document database heritage ([MongoDB](https://en.wikipedia.org/wiki/MongoDB "MongoDB — document-oriented database")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />); extra types such as datetime and binary |
| **CBOR** | Standards-track; strong story for constrained devices and some security/[IoT](https://en.wikipedia.org/wiki/Internet_of_things "IoT — Internet of Things")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> stacks |

They help when JSON is too slow or large but you still want a **dynamic** model. They do **not** replace Parquet for lake analytics.

### Protocol Buffers and Thrift

Schema-driven remote-procedure-call formats show up when machine-learning **serving** or feature stores talk to microservices. They are excellent **online** contracts. They are usually a poor **sole** lake format compared with Parquet for bulk analytics. Many platforms use **both**: Protocol Buffers online, columnar formats offline.

---

## Schema evolution in data platforms

“We added a field” is easy in a notebook and hard in a multi-year lake or event bus.

| Strategy | Idea | Typical home |
|----------|------|--------------|
| **Positional fixed width** | Every field has a byte offset | Legacy finance and mainframe feeds |
| **Writer schema plus resolution** | Old and new schemas reconciled by rules | Avro plus a registry |
| **Field numbers** | Stable numeric tags; ignore unknown fields | Protocol Buffers-style systems |
| **Table schemas in the catalog** | Lakehouse table metadata plus file footers | Parquet plus Glue/Hive/Unity-style catalogs |
| **“Only append columns, never reuse names”** | A social contract | JSON Lines and ad-hoc pipelines (fragile) |

**Takeaway for data science:** pick a format whose **evolution story matches your retention**. Ephemeral experiment? JSON Lines is often fine. Seven years of events? Invest in Avro plus a registry (or an equivalent contract process). Analytic tables? Plan column adds carefully and document null and default semantics.

---

## Machine-learning guidance

### Features and tables

- Store large training and feature tables as **Parquet** (or an equivalent columnar format) with explicit data types and a partitioned layout (time, region, and so on).  
- Interchange between training jobs with **Arrow** where the stack supports it.  
- Keep a **data contract** (schema plus the meaning of nulls, units, and categorical encodings). Format choice cannot replace documentation.

### Model artifacts

| Need | Prefer |
|------|--------|
| Same machine, trusted, rapid iteration | Framework-native checkpoint (understand its trust model) |
| Portable inference across languages | [ONNX](https://en.wikipedia.org/wiki/Open_Neural_Network_Exchange "ONNX — Open Neural Network Exchange")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />, framework export formats, or dedicated model servers |
| Bundle preprocessing and model for one Python service | Still better with a versioned registry and immutable artifact IDs than ad-hoc pickles in chat threads |
| Audit and compliance | Formats and stores that support signing, lineage, and non-executable weights where possible |

### Experiments versus production

Experiment trackers often accept pickles and arbitrary blobs. **Production promotion** should re-materialize critical data into **portable tables** and **reviewed model formats**, not “whatever was left in `/tmp`.”

---

## JSON validation

Data platforms still emit JSON for APIs, webhooks, and configuration. Pair text or schemaless payloads with an explicit contract:

- **JSON Schema** or **[OpenAPI](https://en.wikipedia.org/wiki/OpenAPI_Specification "OpenAPI — standard for HTTP API descriptions")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />** for cross-team [HTTP](https://en.wikipedia.org/wiki/HTTP "HTTP — Hypertext Transfer Protocol")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> boundaries  
- **Pydantic, msgspec, or similar** for Python services that ingest JSON or MessagePack  
- Table-level quality checks (orthogonal to wire format, but part of the same reliability story)

Validation is how you keep the flexibility of schemaless formats without surprise `null` values in production training jobs.

---

## Decision guide

**What is the primary access pattern?**

| If you need… | Prefer… |
|--------------|---------|
| Analytic scans over many rows and few columns | **Parquet** (disk/lake) plus **Arrow** (memory/engines) |
| Event stream with long retention and multiple consumer versions | **Avro** (or similar) plus a schema registry and a compatibility policy |
| Human-edited or lowest-common-denominator export | **CSV** (document the schema separately) |
| Application or API interchange, semi-structured, multi-language | **JSON** (plus schema or validation if the contract matters) |
| Compact internal dynamic payloads (not a lake table) | **MessagePack** or **CBOR** (still validate at boundaries) |
| Online low-latency service contract (features, inference input/output) | **Schema-driven** formats (Protocol Buffers and similar)—see the [engineering perspective](engineer_perspective.md) |
| Python-only, trusted, short-lived object graph | **pickle** or **joblib** only with eyes open; plan a portable exit path |

### Quick comparison

| Format family | Human-readable | Best at | Weak at |
|---------------|----------------|---------|---------|
| CSV | Yes | Exchange with humans and tools | Types, nesting, evolution |
| JSON / JSON Lines | Yes | Universal semi-structured glue | Huge analytic tables |
| pickle / native | No | Rich Python graphs | Trust, portability, longevity |
| Avro | No | Evolving event records | “Just open in Excel” |
| Parquet / ORC | No | Lake analytics | Point lookups of one blob |
| Arrow | No (binary IPC) | In-memory multi-engine share | Being your only on-disk archive format (usually pair with Parquet) |
| MessagePack / CBOR | No | Compact dynamic messages | Replacing columnar lakes |
| Protocol Buffers and similar | No | Online contracts and RPC | Sole format for wide analytics |

---

## How this suite helps (and what it does not)

This repository benchmarks **serializers** across languages and categories (JSON family, schemaless binary, schema-driven, language-native). That is invaluable for **encode and decode cost** of in-memory objects.

Data platform success also depends on **input/output layout, compression, partitioning, cluster execution, and schema governance**—topics larger than a single serialize call. Use suite **Results** to compare libraries; use this page to pick the **paradigm** before you micro-optimize a codec.

---

## Further reading

- Kleppmann, *Designing Data-Intensive Applications* — a systems view of encoding and evolution  
- Apache Parquet, Arrow, and Avro official documentation  
