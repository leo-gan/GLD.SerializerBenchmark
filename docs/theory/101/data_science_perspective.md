# 1.2 Data Science Perspective

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/leo-gan/GLD.SerializerBenchmark/blob/master/docs/theory/notebooks/101/data_science_perspective.ipynb)

Analytical, data-engineering, and machine-learning workloads differ structurally from online service APIs. Rather than exchanging isolated request/response messages, data platforms move large partitioned tables, multi-year event logs, feature batches, multidimensional numeric arrays, and model weight artifacts. Choosing an appropriate standard starts from the unit of work and the dominant access pattern ([how standards differ](index.md#how-standards-differ)).

---

## Workload Profiles in Data Systems

| Workload | Typical Unit | Primary Optimization Goals |
|---|---|---|
| **Analytical tables** | Partitioned files on object storage (S3, GCS, HDFS) | Column projection, compression ratio, multi-year schema stability |
| **Streaming event logs** | Append-only records on brokers (Kafka, Pulsar) | Independent producer/consumer evolution under compatibility checks |
| **Engine-to-engine exchange** | In-memory DataFrames (Python, DuckDB, Polars, Spark) | Minimal conversion and zero-copy inter-process transfer |
| **Scientific arrays and tensors** | Dense N-dimensional numeric grids and model weights | Contiguous memory layout, hyperslab/slice reads, safe non-executable loading |
| **Interactive exploration** | Local CSV, JSON, and notebook checkpoints | Low human friction versus reproducibility and portability |

---

## Formats in Analytical and ML Pipelines

### CSV (RFC 4180)

Comma-Separated Values[^1] remains the lowest common denominator for tabular exports and spreadsheet exchange, but it is a **weakly typed** format. Nulls versus empty strings, date formats, quoting edge cases, leading zeros (which spreadsheet importers routinely coerce into integers), and uncoordinated column changes cause silent corruption. Use CSV at human-facing edges; avoid it as a durable system of record.

### JSON and JSON Lines (JSONL)

JSON serves well for semi-structured ingestion, webhook landing zones, and metadata configuration. **JSON Lines** places one self-contained JSON object per newline, enabling streaming appends and parallel line-based splitting without parsing an entire file into memory. For large analytical scans, however, repeating keys per row and parsing decimal text remains far more expensive in storage and CPU than binary columnar formats, even under gzip or zstd compression.

### Language-Native Checkpoints (`pickle`, `cloudpickle`, `joblib`)

Scientific Python ecosystems rely heavily on `pickle` and `joblib` because they snapshot arbitrary object graphs—including fitted scikit-learn pipelines and custom classes—with a single call. Two constraints restrict their legitimate scope (see [historical context](historical_perspective.md#native-graphs) and [Trust boundaries](../301/trust-boundaries.md)):

- **Security:** Unpickling executes arbitrary opcodes; loading a file from an untrusted source constitutes remote code execution.[^2]
- **Longevity and portability:** Native blobs are coupled to Python module paths and library versions and cannot be consumed directly by non-Python serving engines.

Restrict `pickle`-backed checkpoints to ephemeral, single-environment, fully trusted training workflows. Before sharing or promoting artifacts to production, convert tables to Parquet/Arrow and model weights to non-executable portable formats.

### Apache Avro

Avro encodes row-oriented binary records compactly while treating the schema as a first-class artifact stored either in container file headers or in an external **schema registry**.[^3] Because Avro resolves a *writer schema* against a *reader schema* using explicit defaults and field aliases, it excels for long-lived event streams where producers and consumers upgrade on independent schedules.

### Apache Parquet and Apache ORC

Parquet and ORC store values **column by column** inside row groups or stripes.[^4] Grouping homogeneous column values together enables three major gains for analytical queries:

1. **Column projection:** Queries touching 3 columns of a 200-column table read only those 3 columns from storage.
2. **Type-aware compression:** Dictionary encoding, run-length encoding (RLE), and delta encoding exploit low-cardinality and monotonic columns far more effectively than row-wise compression.
3. **Predicate pushdown:** Min/max statistics in page and stripe headers let engines skip entire blocks that cannot match a filter.

Columnar file formats are poorly suited to low-latency single-record lookups: for a single row, file footers, metadata headers, and alignment padding dominate both size and latency.

### Apache Arrow

Arrow specifies a standardized **in-memory** columnar buffer layout (explicit null bitmaps, 64-byte alignment recommendations, nested list/struct buffers) plus an IPC streaming format.[^5] When processes such as Python, DuckDB, Polars, and Spark share Arrow buffers, data crosses language boundaries with minimal or zero serialization copying. Arrow complements rather than replaces Parquet: a standard modern architecture uses **Parquet on disk** for archival compression and **Arrow in memory/IPC** between execution engines.

### Scientific Array and Tensor Formats

Dense multidimensional grids and neural-network weights introduce requirements distinct from relational tables:

- **HDF5, NetCDF, and ADIOS2** support chunked multidimensional arrays and interior **hyperslab / window reads** without loading entire grids into memory (evaluated under this suite's `array` data set).
- **Safe tensor formats** (such as Safetensors, ONNX, Arrow IPC tensors, FlatBuffers, or Kiln) store shape, dtype, and contiguous numeric buffers without executing arbitrary code on load. For quantized (e.g., 4-bit or 8-bit) weights, the format must also document group size, scaling factors, and whether stored order differs from the blocked layout required by matrix-multiplication kernels ([Bit width is not bus width](../201/bit-width-and-bus-width.md)).

### MessagePack, CBOR, BSON, and Protocol Buffers

Schemaless binary formats (MessagePack, CBOR, BSON) fit compact internal caches and dynamic feature buses, while schema-driven RPC formats (Protocol Buffers, Thrift) fit online inference and feature-serving boundaries. Neither replaces columnar files for bulk offline analytics; mature platforms routinely run Protocol Buffers on online serving paths and Parquet in the analytical lake.

---

## Schema Evolution and Data Contracts

Analytical datasets often outlive multiple generations of application code. Schema evolution strategies vary by retention horizon:

| Mechanism | Typical Context | Operational Requirement |
|---|---|---|
| Writer/reader schema resolution | Avro + schema registry on event logs | Automated compatibility checks (BACKWARD / FORWARD / FULL) in CI |
| Stable numeric field tags | Protocol Buffers on online serving paths | Additive optional fields; never reuse deleted field numbers |
| Catalog-managed table schemas | Parquet + Iceberg / Delta / Hive catalogs | Explicit nullability, partition evolution, and type-promotion rules |
| Append-only key conventions | JSON Lines landing zones | External validation (JSON Schema, Pydantic, `msgspec`) before promotion |

A wire format defines syntax and primitive types; a **data contract** must additionally document units, timezone semantics, null interpretations, and categorical codebooks.[^6]

---

## Format Selection Guide

Select the standard from the primary access pattern first, then compare concrete library implementations within one language ([how to compare](index.md#how-to-compare)):

| Access Pattern / Requirement | Default Standard Class | Notes |
|---|---|---|
| Wide-table analytical scans | **Parquet** (disk) + **Arrow** (memory/IPC) | Best projection and columnar compression |
| Multi-year event stream with independent consumers | **Avro** (or Protocol Buffers) + schema registry | Enforce compatibility modes in CI |
| Human-edited or spreadsheet exchange | **CSV** | Edge adapter only; document schema separately |
| Semi-structured API or landing logs | **JSON / JSONL** + JSON Schema or typed validator | Inspectable; migrate to Parquet for bulk analytics |
| Compact dynamic cache / feature payload | **MessagePack** or **CBOR** | Validate shapes at trust boundaries |
| Low-latency online feature / inference RPC | **Protocol Buffers** (or FlatBuffers) | See [Engineering perspective](engineer_perspective.md) |
| Chunked scientific grids with window reads | **HDF5**, **NetCDF**, or **ADIOS2** | Measured in this suite's `array` data set |
| Zero-copy or portable model tensors | **Arrow IPC**, **FlatBuffers**, **Kiln**, **Safetensors** / **ONNX** | Avoid `pickle` across trust or language boundaries |

---

## Scope of This Benchmark Suite

The [Dashboard](../../dashboard/index.html) measures single-node encode latency, decode latency, round-trip fidelity, and payload size across controlled data types (`suite`, `columnar`, `graph`, `array`, and `tensor`; see [Data sets](../../analysis/test_data_configuration.md)). End-to-end data-platform performance also depends on file partitioning, object-store I/O latency, query-engine execution, and schema governance—factors that must be evaluated alongside single-codec benchmarks.

---

## Exercises

1. **Columnar vs. row storage:** A telemetry table contains 150 columns and 100 million rows. A daily aggregation reads only `device_id`, `timestamp`, and `temperature_c`. Explain why converting the archive from gzip-compressed JSON Lines to Parquet reduces both I/O volume and CPU time even if raw compression ratios are comparable.

??? note "Solution"
    With gzip-compressed JSON Lines, the query engine must read and decompress the entire file and parse all 150 fields of every row to extract 3 columns. With Parquet, the engine reads only the column chunks for `device_id`, `timestamp`, and `temperature_c` (roughly 2% of the columns), skips irrelevant row groups via min/max statistics, and avoids JSON tokenization and decimal–binary float parsing.

2. **Parquet on small messages:** Why is Apache Parquet a poor choice for an online service that fetches one 300-byte user profile per HTTP request?

??? note "Solution"
    Parquet's advantages—column projection, dictionary/RLE compression across many values, and stripe statistics—require large batches of rows (thousands to millions). For a single 300-byte record, Parquet file metadata, Thrift footers, and column-page framing inflate size dramatically and add substantial per-request encode/decode overhead compared with JSON or Protocol Buffers.

3. **Artifact promotion boundary:** A data scientist saves a trained model and preprocessing pipeline with `joblib.dump` (backed by `pickle`) during experimentation and hands the file to a Rust inference team. Identify two concrete problems with this handoff and propose a portable alternative.

??? note "Solution"
    1. **Language lock-in:** Rust cannot natively execute Python `pickle` opcodes or reconstruct Python scikit-learn classes.
    2. **Security and reproducibility:** `pickle` files execute arbitrary code on load and break silently across Python/library version upgrades.
    *Alternative:* Export the model graph and weights to **ONNX** (or export weights in Safetensors alongside explicit JSON/Arrow preprocessing parameters) so the Rust runtime loads pure, non-executable data.

---

## References

[^1]: Shafranovich, Y. (2005). *Common Format and MIME Type for Comma-Separated Values (CSV) Files*. IETF RFC 4180. <https://www.rfc-editor.org/rfc/rfc4180>
[^2]: Python Software Foundation. *`pickle` — Python object serialization*. Python 3 Documentation. <https://docs.python.org/3/library/pickle.html>
[^3]: Apache Software Foundation. *Apache Avro Specification*. <https://avro.apache.org/docs/>
[^4]: Apache Software Foundation. *Apache Parquet Format Specification*. <https://parquet.apache.org/docs/>
[^5]: Apache Software Foundation. *Apache Arrow Columnar Format Specification*. <https://arrow.apache.org/docs/format/Columnar.html>
[^6]: Kleppmann, M. (2017). *Designing Data-Intensive Applications*, Chapter 4. O'Reilly Media.
