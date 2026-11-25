# 3.5 Row vs. Columnar at System Scale

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/leo-gan/GLD.SerializerBenchmark/blob/master/docs/theory/notebooks/301/row_vs_columnar.ipynb)

## Problem Statement

Most production organizations run two structurally opposed workloads over the same business domain:

1. **Operational services (OLTP / RPC / messaging):** Read or write entire records one entity at a time (a user profile, payment command, or telemetry event) under millisecond latency targets.
2. **Analytical processing (OLAP / ML / reporting):** Scan millions or billions of records while projecting only a small subset of attributes (for example, summing revenue by region and day).

Collapsing both workloads onto one encoding—"everything is Protobuf" or "everything is Parquet"—imposes either prohibitive analytical I/O costs or prohibitive per-request overhead. At system scale, the row-versus-columnar axis introduced in [1.2 Data science perspective](../101/data_science_perspective.md) becomes a **workload-boundary architecture decision**.

---

## Layout Economics: Row Messages vs. Columnar Tables

!!! note "Definition: Row-Oriented vs. Columnar Storage"
    In a **row-oriented** layout, all fields of record $i$ occupy contiguous bytes, minimizing seeks when fetching a single entity. In a **columnar** layout, all values of attribute $j$ across a batch of $N$ records occupy contiguous bytes, enabling **column pruning** (reading only referenced attributes), **predicate pushdown** (skipping row groups via min/max statistics), and homogeneous **column encodings** (dictionary, run-length, delta, and bit-packing).[^1]

Let a table contain $N$ rows and $C$ equally sized columns, and let an analytical query reference $k \ll C$ columns. A row-oriented archive must read and parse $O(N \cdot C)$ field values, whereas a columnar store reads $O(N \cdot k)$ values before compression and statistics pruning—and achieves higher compression ratios because adjacent values share a single data type and distribution. Conversely, constructing a columnar file for a single record ($N = 1$) pays fixed metadata, footer, and alignment overhead that dwarfs the payload.

| Dimension | Row-Oriented Messages | Columnar Tables and Files |
|---|---|---|
| **Unit of work** | Single entity or event (all or most fields) | Bulk scan or aggregate over $k \ll C$ columns |
| **I/O and memory shape** | Whole record stored contiguously | Contiguous column chunks; row-group min/max pruning |
| **Latency regime** | Microseconds to low milliseconds per message | Throughput-oriented batch, streaming micro-batch, or interactive queries |
| **Schema governance** | Per-message schema registry or IDL repository | Table catalog, file footers, and partition metadata |
| **Compression** | Optional framing-level codec (zstd, gzip) | Type-aware dictionary, RLE, delta, plus per-page codecs |
| **Typical home** | Public/internal RPC, queues, caches, operational events | Object-storage data lakes, warehouses, feature stores, notebooks |

### In-Memory Interchange vs. On-Disk Storage

Columnar formats split further by role:

- **Apache Arrow**[^2] specifies a language-independent **in-memory** columnar buffer layout (and IPC stream format) for zero-copy interchange between analytical engines, data frames, and GPUs.
- **Apache Parquet**[^3] and **Apache ORC** specify **on-disk** columnar file formats optimized for object storage (S3-class buckets), adding row-group footers, column statistics, bloom filters, and page-level compression.

---

## Architectural Decision Frame

```text
  Do readers usually access MOST fields of FEW records (point lookup, RPC, per-event)?
        yes → row-oriented message codec (JSON, Protobuf, Avro, MessagePack)
  Do readers usually access FEW fields across MANY records (analytical scans, aggregations)?
        yes → columnar storage (Parquet/ORC) or in-memory columnar IPC (Arrow)
  Do both workloads exist over the same domain?
        yes → two-hop architecture: row events on the bus, periodic compaction into columnar partitions
```

| Workload | Appropriate Default | Anti-Pattern |
|---|---|---|
| Public or internal RPC | Row message (JSON, Protobuf, MessagePack) | Opening Parquet files per request |
| Per-event Kafka stream | Row message (Avro, Protobuf, or schema-validated JSON) | Columnar files per single event |
| Historical data lake on object storage | Parquet or ORC with partitioning and table catalog | Millions of small Protobuf or JSON files as the query store |
| Interactive multi-million-row analytics | Arrow in-memory interchange over Parquet storage | Repeatedly parsing nested JSON Lines |
| Cache lookup by primary key | Row message | Reading a columnar file for one key |

### Common Failure Modes

1. **The Protobuf data lake:** Archiving raw RPC or event messages as millions of small files forces analytical engines to incur high object-store listing overhead and parse every unused field.
2. **Parquet on a low-latency RPC path:** File footer construction, schema serialization, and page framing add severe latency and allocation cost at $N = 1$.
3. **Partition neglect:** Storing columnar files without partitioning by common filter keys (such as event date or tenant) forces full-table scans despite columnar layout.
4. **Conflating Arrow and Parquet:** Treating Arrow IPC as a long-term compressed archive or Parquet as an in-memory compute representation misallocates CPU and storage budgets.

---

## Mapping to This Benchmark Suite

This suite keeps row-oriented and columnar measurements on distinct data types so that workloads are never ranked across incompatible tasks:

- **Suite row data types (`all@all`, `all@1`, `all@100`):** Cover the five operational message shapes (`message`, `document`, `telemetry`, `strings`, `event`).
- **Columnar data set (`table`, `table_project`, `nested_table`, `signal`):** Defined in [Test data configuration](../../analysis/test_data_configuration.md) and configured in [`config/library/columnar.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/library/columnar.yaml). On `table_project`, every measured implementation writes the full table or row set and reads only the single projected column `f_float_0`, directly demonstrating column-pruning economics.
- **SBE (Simple Binary Encoding):**[^4] Measured on `signal`, `table`, and `table_project` (not `nested_table`) for fixed-stride message comparisons. SBE is a **schema-driven row layout** where each record spans a fixed stride (plus optional variable-length data)—it is *not* a columnar lake format like Parquet or ORC.

Always filter the [Dashboard](../../dashboard/index.html) to a single language, standard, data set, and data type; never rank `arrow-ipc` on `table_project` against a JSON codec on `message`. See [Columnar formats in this suite](../../analysis/columnar.md) and [3.9 Fair benchmarking and implementation variance](using-this-suite.md).

---

## Empirical Evaluation Protocol

To validate a row-versus-columnar boundary for a real workload:

1. **Measure selectivity and batch size:** Record the fraction of columns touched ($k / C$), typical rows scanned per query ($N$), and latency target (interactive $p_{99}$ vs. batch scan time).
2. **Benchmark representative queries on actual data:** Load a realistic multi-gigabyte sample both as row records (e.g., compressed JSON Lines or Protobuf files) and as partitioned Parquet/ORC files. Measure **bytes scanned**, **query wall time**, and **storage footprint**.
3. **Benchmark the operational serving hop separately:** Evaluate row codecs on the serving path using the Dashboard slice for your runtime and record shape, followed by a service-level load test.
4. **Design the compaction bridge:** When both paths exist, ingest with row events on the message bus and run a scheduled or streaming compaction job that writes properly sized, partitioned columnar files (typically tens to hundreds of megabytes per file) registered in a table catalog.

**Limits of this benchmark suite:** Single-node codec measurements cannot capture object-storage request latency, warehouse query-planner pushdown, Iceberg/Delta Lake metadata overhead, compaction scheduling, or sub-byte packed tensor storage (see [2.2 Bit width is not bus width](../201/bit-width-and-bus-width.md)).

---

## Exercises

1. **Column-pruning cost model:** A telemetry table contains $10^7$ rows and 80 fixed-width 8-byte columns (640 bytes/row raw). An analytical query aggregates 4 columns without indexes. Ignoring compression and headers, compare the minimum raw bytes read under a row-oriented layout versus a columnar layout.

??? note "Solution"
    - **Row-oriented:** Must read all 80 columns of all $10^7$ rows: $10^7 \times 640\text{ B} = 6.4\text{ GB}$.
    - **Columnar:** Reads only the 4 projected columns: $10^7 \times (4 \times 8\text{ B}) = 320\text{ MB}$ — a $20\times$ reduction in raw I/O before dictionary, RLE, or page compression is even applied.

2. **Two-hop architecture:** A telemetry pipeline ingests 50,000 events/second from edge devices into Kafka, where a fraud detector scores each event within 20 ms while data scientists run daily aggregations across 12 months of history. Propose the serialization architecture across both paths.

??? note "Solution"
    Use a schema-driven **row format** (Protobuf or Avro with a registry) on Kafka so the fraud consumer decodes individual events in microseconds with strict evolution checks. Run a dedicated streaming or micro-batch **compaction job** that buffers events and writes date-partitioned **Parquet** files into object storage registered in a table catalog for analytical queries.

3. **Benchmark cell validity:** Why is comparing `parquet` on `table_project` against `orjson` on `message` an invalid basis for choosing an HTTP API codec?

??? note "Solution"
    The two measurements differ in **both standard and data type** (and workload shape): `table_project` measures batch columnar projection of one column (`f_float_0`) over a table, whereas `message` measures whole-record operational serialization. A format that excels at projected batch scans incurs unacceptable per-request overhead on small single-record HTTP responses.

---

## References

[^1]: Abadi, D., Boncz, P., Harizopoulos, S., Idreos, S., & Madden, S. (2013). *The Design and Implementation of Modern Column-Oriented Database Systems*. Foundations and Trends in Databases, 5(3), 197–280.
[^2]: Apache Software Foundation. *Apache Arrow Columnar Format Specification*. <https://arrow.apache.org/docs/format/Columnar.html>
[^3]: Apache Software Foundation. *Apache Parquet Format Specification*. <https://parquet.apache.org/docs/file-format/>
[^4]: FIX Trading Community. *Simple Binary Encoding (SBE) Technical Specification*. <https://www.fixtrading.org/standards/sbe/>
