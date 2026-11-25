# 4.12 Case Study: Auditing Parse-Only and DOM Adapters (C++)

## Problem Statement

**`simdjson`** is renowned for multi-gigabyte-per-second SIMD JSON parsing,[^1] yet it is **strictly a parser—it provides no serializer**. Because this benchmark suite reports encode, decode, and combined throughput for every registered row, the C++ **`simdjson`** adapter must pair `simdjson` parsing with a second library (`nlohmann::json`) for encoding and intermediate DOM bridging.

Reading the Dashboard table without inspecting the adapter invites the false conclusion *"simdjson is slower than Glaze and comparable to nlohmann."* This case study demonstrates how to audit **`native_kind: dom`** and parse-only wrapper rows before quoting any benchmark number ([Timing honesty](../../analysis/TIMING_HONESTY.md)).

> **Illustrative L1 snapshot (`document`, $n = 1$, `bytes` mode):** Live authoritative numbers belong to the [C++ JSON Dashboard slice](../../dashboard/index.html?lang=cpp&standard=json&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=simdjson&ser=simdjson&ser=glaze#detailed-analytics) ([Claims L1](../../analysis/CLAIMS_AND_REPLICATION.md) · [C++ Overview](../../cpp/index.md)).

| Metric (Quoted L1 Snapshot) | `simdjson` (This Wrapper) | `Glaze` 2.9.5 | `nlohmann::json` |
|---|---:|---:|---:|
| Throughput (encode + decode) | 78k ops/s | **378k ops/s** | 83k ops/s |
| Encode path | `nlohmann::json::dump()` *(not simdjson)* | **706 ns** (direct struct write) | 3.22 µs |
| Decode latency | 12.6 µs *(includes DOM bridge)* | **1.94 µs** | 8.84 µs |
| Encoded wire size | **458 B** | **458 B** | **458 B** |

---

## Source-Level Call Sites

Inspecting `SimdjsonSer` in `cpp/src/serializers/ser_json.cpp` exposes exactly what sits inside the timed loop:

```cpp
// cpp/src/serializers/ser_json.cpp (SimdjsonSer, native_kind = "dom")
void prepare(const Fixture& fx) override {
  type_id_ = fx.type_id;
  n_ = fx.instance_count;
  prepared_ = value_to_json(fx.value);               // nlohmann::json object (untimed)
}

std::vector<uint8_t> serialize_bytes(const Fixture&) override {
  std::string s = prepared_.dump();                  // timed JSON encode via nlohmann
  return std::vector<uint8_t>(s.begin(), s.end());
}

Value deserialize_bytes(const std::vector<uint8_t>& data) override {
  simdjson::padded_string ps(
      reinterpret_cast<const char*>(data.data()), data.size());
  simdjson::dom::element el = parser_.parse(ps);     // Stage 1: simdjson DOM parse
  return json_to_value(simd_to_json(el), type_id_, n_); // Stages 2–3: bridge to nlohmann, then Value
}
```

Contrast this with **`Glaze`** (`cpp/src/serializers/ser_glaze.cpp`),[^2] which binds JSON directly to C++ struct fields at compile time without any intermediate generic DOM:

```cpp
std::vector<uint8_t> serialize_bytes(const Fixture&) override {
  std::visit([&](const auto& v) { write_json_into(v, buf_); }, value_);
  return std::vector<uint8_t>(buf_.begin(), buf_.end());
}
// decode: decode_json directly into bench::Value (single pass, zero intermediate DOM)
```

---

## Mechanistic Analysis: What the Wrapper Actually Measures

### 1. Encode Does Not Call `simdjson`

`serialize_bytes` calls `nlohmann::json::dump()`, making the encode column functionally identical to the `nlohmann` row. *(An earlier revision cached the minified string in `prepare` and timed only a `std::vector` copy at ~217 ns; replacing that copy with real `prepared_.dump()` restored timing honesty while exposing that `simdjson` itself performs zero encoding.)*

### 2. Decode Pays Extra Allocation and Bridging Stages

Inside `deserialize_bytes`, `simdjson::dom::parser::parse` runs quickly on the 458-byte payload, but three additional costs surround it:

| Stage in `SimdjsonSer::deserialize_bytes` | Work Performed | Role |
|---|---|---|
| 1. `simdjson::padded_string` copy | Allocates and copies `data` with SIMD padding bytes | Required by `simdjson` when caller buffer lacks `SIMDJSON_PADDING` trailing bytes |
| 2. `parser_.parse(ps)` | SIMD structural indexing and DOM tape construction | Actual `simdjson` work |
| 3. `simd_to_json(el)` | Recursively walks `simdjson::dom::element` and heap-allocates a full `nlohmann::json` object tree | Adapter bridge so the runner can reuse `json_to_value` *(older snapshots even minified and re-parsed via `nlohmann::json::parse`)* |
| 4. `json_to_value(...)` | Copies fields from `nlohmann::json` into `bench::Value` | Suite round-trip fidelity boundary |

`Glaze` parses directly from the raw JSON bytes into the target C++ struct in one pass (1.94 µs) with no generic DOM allocation. The `simdjson` wrapper therefore measures **`simdjson` used as a front end to a `nlohmann::json` pipeline**, *not* direct `simdjson` On-Demand struct extraction.

---

## Audit Checklist for `native_kind: dom` Rows

The same wrapper pattern appears in other languages (for example, JavaScript's `simdjson-parse+JSON.stringify`; see [JavaScript: JSON vs. `google-protobuf`](../../analysis/call-sites/javascript-json-vs-protobuf.md)). Before quoting any row tagged `native_kind: dom` or any parse-only library:

1. **Check encode attribution:** Does `serialize` call the named library, a fallback library (`nlohmann`, `JSON.stringify`), or a cached copy?
2. **Check decode conversion layers:** Does `deserialize` bind directly into typed application structs (e.g., `simdjson::ondemand` directly to `bench::Document`), or allocate an intermediate generic DOM (`nlohmann::json`) first?
3. **Check buffer padding assumptions:** Did the adapter allocate a `padded_string` copy on every decode iteration because the benchmark buffer lacked `SIMDJSON_PADDING` bytes?
4. **Compare like-for-like:** Only compare direct struct-binding parsers (`Glaze`, direct `simdjson::ondemand`) against each other, and DOM-to-DOM bridges separately.

---

## Exercises

1. **Designing a direct `simdjson` decode path:** Which stages of `SimdjsonSer::deserialize_bytes` would you replace to benchmark `simdjson`'s true struct-parsing speed on `bench::Document`, and what would happen to the decode latency relative to `nlohmann::json`?

??? note "Solution"
    Replace `simd_to_json(el)` + `json_to_value(...)` with a direct **`simdjson::ondemand::parser`** (or direct `simdjson::dom::element` field extractor) that writes fields straight into `bench::Document` without constructing an intermediate `nlohmann::json` tree—and pre-allocate the input buffer with `SIMDJSON_PADDING` extra bytes to avoid copying into `padded_string` inside the timed call. Decode latency would drop dramatically, moving below `nlohmann` and approaching struct-binding parsers like `Glaze`.

2. **Why `simdjson` wins more on large payloads:** Even with direct `ondemand` extraction, why does SIMD structural indexing (`simdjson`) show a much larger advantage over scalar parsers on a 1 MB JSON file than on a 458-byte `document`?

??? note "Solution"
    SIMD stage-1 indexing amortizes vector setup, parser state initialization, and branchless structural scanning across thousands of 64-byte SIMD blocks. On a tiny 458-byte payload (only ~8 SIMD blocks), fixed per-call setup and padding overhead represent a large share of total decode time.

3. **Benchmark label hygiene:** Why is naming a row `simdjson-parse+nlohmann-dump` (matching JavaScript's explicit `simdjson-parse+JSON.stringify` label) superior to labeling the composite wrapper simply `simdjson`?

??? note "Solution"
    A composite label makes the asymmetric encode fallback immediately visible in charts and tables, preventing readers from misattributing `nlohmann::json::dump()` encode times or `nlohmann` DOM-bridging overhead to `simdjson`.

---

## References

[^1]: Langdale, G., & Lemire, D. (2019). *Parsing Gigabytes of JSON per Second*. The VLDB Journal, 28(6), 941–960. <https://github.com/simdjson/simdjson>
[^2]: Glaze Contributors. *Glaze: High-Performance C++ Compile-Time JSON/BEVE Library*. <https://github.com/stephenberry/glaze>
