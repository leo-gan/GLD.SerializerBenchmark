# 3.9 Fair Benchmarking and Implementation Variance

## Problem Statement

Benchmark charts are routinely misused to justify architectural policy. A single summary bar—"library A is $3\times$ faster than library B"—invites invalid conclusions whenever A and B differ in **language**, **wire standard**, **payload shape**, **timing rules**, or **safety checks**. Organizations then execute expensive format migrations only to see negligible service improvement because the underlying comparison was misaligned.

A second, symmetric error stops at the format name ("we standardized on JSON" or "we use Protocol Buffers") without naming the concrete implementation. Even within one language and one standard, implementations routinely span an order of magnitude in latency, allocation rate, and edge-case compliance.

---

## Controlling the Experimental Cell

!!! note "Definition: Controlled Benchmark Cell"
    A valid same-runtime performance comparison in this suite holds five variables constant:
    $$\mathcal{C} = (\text{Language},\ \text{Standard},\ \text{Data set},\ \text{Data type},\ \text{Batch size})$$
    Only `SerializerName` rows belonging to the same cell $\mathcal{C}$—evaluated under identical warmup, outlier, and metric policies—compete directly on speed and wire size.

The [Dashboard](../../dashboard/index.html) filter bar implements $\mathcal{C}$ directly. Distinguish four terms that are often conflated:

1. **Family** ([Families](../../analysis/families.md)): A conceptual taxonomy (text, schemaless binary, schema-driven, columnar, language-native) used for architectural orientation, *not* a Dashboard ranking filter.
2. **Standard**: A concrete wire specification (e.g., JSON, Protocol Buffers, MessagePack, Apache Parquet). Standard selection is governed by trust, interoperability, and evolution constraints (Chapters 3.1–3.8).
3. **Data set and data type** ([Test data configuration](../../analysis/test_data_configuration.md)): `Suite` (`message`, `document`, `telemetry`, `strings`, `event`) vs. `Columnar` (`table`, `table_project`, `nested_table`, `signal`). Recall that `table_project` reads only `f_float_0`, whereas `message` decodes a full operational record.
4. **Implementation**: A concrete library and pinned version (`SerializerName` + `serializer_version`) implementing that standard in one language.

### Pre-Quotation Validity Checklist

Before citing any Dashboard number in an architecture decision record (ADR), verify every gate:

1. **Same language?** Cross-language rankings compare runtimes (VM, JIT, GC, FFI), not wire formats. Use them only for rough orientation, never to crown a format.
2. **Same standard?** Cross-standard charts are informative only when weighing alternative contracts alongside trust, schema evolution, and ecosystem constraints.
3. **Conformance checked?** Speed rows do not measure specification compliance. Inspect [Compliance](../../dashboard/index.html#compliance) for standards with public test suites (formats with no public specification carry no compliance score).
4. **Fidelity gate passed?** `mean_fidelity` verifies local encode-then-decode round-trip correctness inside one runner—disqualify rows with fidelity failures or disqualifying Overview caveats (such as stream-only rows kept separate from buffer rows).
5. **Metric and sample policy stated?** Specify whether the claim cites encode median (`ser_median_ns`), decode median (`deser_median_ns`), total median (`total_median_ns`), throughput (`avg_ops_per_sec`), or wire size (`median_size_bytes`), along with the sample policy (warmup exclusion drops `RepetitionIndex == 0` by default, and IQR $1.5\times$ filtering excludes extreme outliers; see [Analysis methodology](../../analysis/ANALYSIS_METHODOLOGY.md)).[^1]

```text
  Question: "Which library should we ship on this boundary?"
        │
        ▼
  Fix architectural constraints first (trust, evolution, workload, polyglot contract)
        │  → determines Standard
        ▼
  Fix controlled cell (Language, Standard, Data set, Data type, Batch size, Metric)
        │
        ▼
  Filter Dashboard to faithful rows in that cell; inspect effect sizes & caveats
        │
        ▼
  Pin concrete library + version; validate tails and non-codec costs under load
```

---

## Implementation Variance Within a Standard {#implementation-variance}

Holding $\mathcal{C}$ constant isolates **pure implementation engineering quality**—for example, comparing `yyjson`, `simdjson`, and `nlohmann/json` in C++ on JSON, or `msgspec`, `orjson`, and stdlib `json` in Python. Large intra-standard spreads arise from five concrete engineering mechanisms:

| Source of Variance | Engineering Contrast | Typical Impact |
|---|---|---|
| **Parser architecture** | Full DOM tree construction vs. streaming/SAX vs. SIMD structural indexing | $3\times$–$20\times$ decode latency and peak memory spread |
| **Dispatch strategy** | Ahead-of-time code generation vs. runtime reflection / dynamic hash maps | Eliminates per-field metadata lookup and boxing overhead |
| **Allocation strategy** | Heap-allocating a new string per field vs. borrowed slices or reusable arenas | Directly governs managed GC pause frequency and allocator contention |
| **Wire encoding choices** | Positional arrays vs. string-keyed maps (e.g., MessagePack struct encodings) | Substantial wire size and decode-time differences under the same standard |
| **Safety and spec strictness** | Full UTF-8 validation, duplicate-key rejection, depth caps, and exact float parsing vs. permissive shortcuts | Faster libraries occasionally skip checks required on untrusted inputs |

Because implementation quality varies independently across ecosystems, **never copy a library decision across languages** or assume a brand name determines performance. An ADR stating "we use JSON for our public API" is operationally incomplete until each service language specifies and pins its concrete library version (e.g., `orjson` in Python, `encoding/json/v2` or `sonic` in Go) and verifies safety defaults.

---

## Common Failure Modes

| Mistake | Analytical Defect |
|---|---|
| **Global leaderboard mentality** | Selecting the top row of an unfiltered chart mixing languages, standards, or data types |
| **Averaging ranks across languages** | Collapsing incompatible runtimes into a meaningless composite rank[^2] |
| **Brand-only ADRs** | Naming "JSON" or "Protobuf" without pinning libraries, allowing services to drift onto slow or incompatible parsers |
| **Treating `mean_fidelity` as spec compliance** | A library can round-trip its own output cleanly while violating official RFC or protobuf edge-case rules |
| **Ignoring warmup and cold start** | Steady-state JIT timings (`RepetitionIndex > 0`) conceal cold-start penalties in short-lived serverless functions |
| **Equating microbenchmark time with service latency** | Benchmark runners time in-memory encode/decode only—excluding TLS, network RTT, validation middleware, and broker I/O |

---

## Verification Protocol and Benchmark Limits

When selecting a library for a production service:

1. **Freeze the contract:** Confirm the standard using Chapters 3.1–3.8 before opening speed charts.
2. **Pull a single controlled cell:** Filter the Dashboard to your exact `(Language, Standard, Data set, Data type)` and check both [Metrics](../../analysis/METRICS.md) and language Overview caveats.
3. **Check statistical significance:** Inspect dispersion and effect sizes (such as Cliff's $\delta$ in [Analysis methodology](../../analysis/ANALYSIS_METHODOLOGY.md)) before paying migration cost for a small median difference.
4. **Verify safety and maintenance:** Confirm active maintenance, fuzzing posture, UTF-8/depth-limit behavior, and license compliance.
5. **Pin and re-verify under load:** Pin `serializer_version` in lockfiles and re-measure under production concurrency ([3.10 Latency tails, GC, and system compression](latency-tails-and-gc.md)).

**Limits of this benchmark suite:** Single-node microbenchmarks do not evaluate dependency supply-chain risk, custom middleware/validation cost, network RTT, or cold-start behavior in ephemeral containers.

---

## Exercises

1. **Spotting a misaligned claim:** An engineering proposal quotes this suite to claim: *"Our Python REST API should switch from JSON to FlatBuffers because Rust FlatBuffers has a $15\times$ lower median decode time than Python `json`."* Identify **three** distinct methodological errors in that argument.

??? note "Solution"
    1. **Cross-language comparison:** Comparing Rust against Python conflates runtime/compiler speed with wire-format cost.
    2. **Implementation variance ignored:** Comparing against Python's stdlib `json` ignores faster C/Rust-backed Python JSON implementations (`orjson`, `msgspec`) within the *same* JSON standard.
    3. **Product constraints ignored:** Public REST APIs require external JSON ergonomics and inspectability; FlatBuffers on untrusted inputs also requires verifier overhead and changes the API contract.

2. **Warmup vs. serverless cold starts:** Why does this suite drop `RepetitionIndex == 0` by default in published steady-state summaries, and when should an engineer inspect cold-start measurements instead?

??? note "Solution"
    Dropping `RepetitionIndex == 0` removes one-time JIT compilation, dynamic library loading, and cold-cache effects so published tables reflect steady-state long-running server performance.[^1] For short-lived serverless functions (AWS Lambda, Cloud Run scale-to-zero) or CLI tools that execute once per process invocation, cold-start initialization and first-call decode dominate latency and must be measured separately without warmup exclusion.

3. **Fidelity vs. compliance:** A newly added YAML library scores `mean_fidelity = 1.0` on the benchmark suite's test records, yet fails 20% of cases in the YAML Compliance Suite. How can both results be true simultaneously?

??? note "Solution"
    `mean_fidelity = 1.0` only checks that the library can decode the specific subset of structures it just encoded itself. The YAML specification includes subtle features (anchors, aliases, multiline scalars, implicit type coercion such as the Norway problem `NO` $\to$ `false`) that may not appear in basic benchmark records but break specification compliance on real-world inputs.

---

## References

[^1]: Georges, A., Buytaert, D., & Eeckhout, L. (2007). *Statistically Rigorous Java Performance Evaluation*. OOPSLA '07, ACM SIGPLAN Notices, 42(10), 57–76.
[^2]: Fleming, P. J., & Wallace, J. J. (1986). *How Not to Lie with Statistics: The Correct Way to Summarize Benchmark Results*. Communications of the ACM, 29(3), 218–221.
