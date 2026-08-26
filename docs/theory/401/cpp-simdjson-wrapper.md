# C++: what the simdjson row is actually timing

## Why this article exists

simdjson is famous for parsing JSON at very high speed (Geoff Langdale and Daniel Lemire, papers 2018–2019). It has **no encoder**. The suite still needs an encode column, so this wrapper writes JSON with **nlohmann::json** and reads JSON with simdjson plus a second parse.

A results table invites the wrong sentence: “simdjson is slow to decode.” This page opens the wrapper. After reading it you should be able to say which library writes the bytes, why decode calls **two** JSON parsers, and how to read any row that sets `native_kind` to `dom`. The [timing contract](../../analysis/TIMING_HONESTY.md) is why encode must be a real write, not a copy of bytes built in `prepare`.

Numbers in the table below are a **quoted L1 slice** (document, n=1, bytes)
from this suite’s packed Dashboard data. They illustrate the gap; they are
not a universal ranking.

[Open this slice on the Dashboard](../../dashboard/?lang=cpp&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=simdjson&ser=simdjson&ser=glaze#detailed-analytics)
· [Claims (L1)](../../analysis/CLAIMS_AND_REPLICATION/)
· [C++ overview](../../cpp/)

## Short answer

Glaze is faster than the simdjson row (378 thousand versus 78 thousand cycles per second on the last packed L1 slice). We can see that in the table. The simdjson row does **not** time simdjson encode. simdjson cannot encode. It does **not** time “simdjson parse into a suite `Document`.”

1. **Encode** writes compact JSON with **nlohmann::json** (`prepared_.dump()`). `prepare` only builds the nlohmann object. That is the same kind of encode as the nlohmann row. An older adapter cached the dump and timed a `vector` copy (217 ns). That copy is gone.
2. **Decode** runs simdjson’s DOM parse, then walks that DOM into the suite value. It does not parse the JSON text a second time.

Glaze writes JSON from the C++ struct during the timed encode and reads JSON back into that struct during the timed decode. That is why Glaze has the higher cycle rate. The decode column is the one that contains simdjson, and it still includes two extra stages.

| | simdjson (this wrapper) | Glaze 2.9.5 | nlohmann |
|--|-------------------------|-------------|----------|
| Mean encode + decode, document, *n* = 1 | 78 thousand / s | **378 thousand / s** | 83 thousand / s |
| Encode | nlohmann `dump()` (was 217 ns when it was a copy) | 706 ns (struct JSON write) | 3.22 µs |
| Decode | **12.6 µs** (last published L1: parse + minify + parse) | **1.94 µs** | 8.84 µs |
| Encoded size | **458 B** | **458 B** | **458 B** |

Equal size: all three emit compact JSON. Decode is not comparable to Glaze: only Glaze stops at one struct.

## The timed functions

`cpp/src/serializers/ser_json.cpp`, class `SimdjsonSer`:

```cpp
void prepare(const Fixture& fx) override {
    type_id_ = fx.type_id;
    n_ = fx.instance_count;
    prepared_ = value_to_json(fx.value);   // nlohmann object, untimed
}

std::vector<uint8_t> serialize_bytes(const Fixture&) override {
    std::string s = prepared_.dump();      // timed JSON write
    return std::vector<uint8_t>(s.begin(), s.end());
}

Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    simdjson::padded_string ps(
        reinterpret_cast<const char*>(data.data()), data.size());
    simdjson::dom::element el = parser_.parse(ps);   // simdjson — real
    return json_to_value(simd_to_json(el), type_id_, n_);
}
```

The comment above the class states the intent: “DOM parse (library strength); ser = prepared minified JSON.” The leaderboard does not repeat that sentence. Students who only read the table will mis-rank the library.

**Glaze**, for contrast (`cpp/src/serializers/ser_glaze.cpp`), writes during the timed encode:

```cpp
std::vector<uint8_t> serialize_bytes(const Fixture&) override {
    std::visit([&](const auto& v) { write_json_into(v, buf_); }, value_);
    return std::vector<uint8_t>(buf_.begin(), buf_.end());
}
```

`write_json_into` is Glaze’s compile-time walk of the struct. Decode is `decode_json` into the suite `Value`. No second parser.

## Why decode is 12.6 µs

Four stages sit inside one timed function:

| Stage | What it does | Why it is there |
|-------|----------------|-----------------|
| `parser_.parse` | simdjson builds a DOM | The library’s advertised strength |
| `minify` | Walk that DOM back to compact text | Adapter: nlohmann wants a string |
| `nlohmann::json::parse` | Parse the same JSON **again** | Adapter: suite mapping is written for nlohmann |
| `json_to_value` | Copy DOM fields into `bench::Document` | Fidelity: the suite compares domain values |

simdjson is doing its job in stage one. Stages two and three exist because this wrapper treats simdjson as a **front end** to the nlohmann document model. That is a legitimate integration pattern. It is not a measurement of simdjson decode into an application struct.

nlohmann alone (8.84 µs decode) parses once and maps once. Glaze (1.94 µs) never builds a generic document tree.

## How this happens in other languages

JavaScript’s row `simdjson-parse+JSON.stringify` is the same shape: a parse-focused library plus a second tool to produce suite values. Decode there is about 15 µs. The lesson travels.

An earlier JavaScript google-protobuf adapter had the same encode-side problem: if `prepare` writes the bytes, the encode column measures a copy. That adapter now encodes in `serialize`. See [JSON versus google-protobuf](javascript-json-vs-protobuf.md).

## How to read any “DOM” row

When `native_kind` is `dom` (this wrapper reports exactly that), ask:

1. Is encode a real write, or a copy of text built in `prepare`?
2. Does decode stop at the library’s document model, or does it parse again into another model?
3. Is there a struct-backed JSON row (here: Glaze) that times the path an application would actually write?

If encode is a second library’s dump, decode parses again, and a struct-backed row exists, do not use this row to rank simdjson against Glaze.

**History.** simdjson answered a 2010s question: can we find `{`, `}`, and `"` in a JSON byte stream with one processor instruction on many bytes? The papers are about **parse**. They are not about “replace nlohmann in a benchmark runner.” Using the parse as a stage in a longer pipeline is normal. Reporting that pipeline under the name `simdjson` is what this page exists to unpack.

## Self-check

1. Which library’s function writes the bytes in `serialize_bytes`, and why is that function not simdjson?
2. After the contract fix, how many times is the JSON text parsed in `deserialize_bytes`? Which library does that parse?
3. You want to measure “simdjson into `bench::Document`.” Which two stages would you delete or replace, and what would you expect to happen to the 12.6 µs?
