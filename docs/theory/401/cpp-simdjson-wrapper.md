# C++: what the simdjson row is actually timing

## Why this article exists

simdjson is famous for parsing JSON at very high speed (Geoff Langdale and Daniel Lemire, papers 2018–2019). On this suite’s **document** fixture, one instance, the row named **simdjson** reports encode at **217 nanoseconds** and decode at **12.6 microseconds**. Glaze, a C++ JSON library that really encodes and decodes the document, sits at 706 ns encode and 1.94 µs decode, and finishes about **4.8 times** as many total cycles per second.

A results table invites the wrong sentence: “simdjson is slow to decode.” This page opens the wrapper. After reading it you should be able to say what those 217 ns copy, why decode calls **two** JSON parsers, and how to read any row that sets `native_kind` to `dom`.

Numbers are from the committed C++ **Results** snapshot. See [C++ Results](../../cpp/results.md).

## Short answer

The simdjson wrapper does **not** time simdjson encode. It does **not** time “simdjson parse into a `Document`.”

1. **Encode** copies a `std::string` that `prepare` built with **nlohmann::json** (`value_to_json(...).dump()`). 217 ns is a `vector` construction from that cache.
2. **Decode** runs simdjson’s DOM parse, then `simdjson::minify`, then **nlohmann::json::parse** on the minified text, then `json_to_value`. The famous parser is the first third of a longer pipeline.

Glaze writes JSON from the C++ struct on the clock and reads JSON back into that struct. That is why Glaze wins the total while “losing” the encode column.

| | simdjson (this wrapper) | Glaze 2.9.5 | nlohmann |
|--|-------------------------|-------------|----------|
| Mean encode + decode, document, *n* = 1 | 78 thousand / s | **378 thousand / s** | 83 thousand / s |
| Encode | **217 ns** (copy of cached text) | 706 ns (real JSON write) | 3.22 µs |
| Decode | **12.6 µs** (parse + minify + parse + map) | **1.94 µs** | 8.84 µs |
| Encoded size | **458 B** | **458 B** | **458 B** |

Equal size: all three emit compact JSON. Unequal clocks: only Glaze and nlohmann time a full codec.

## The timed functions

`cpp/src/serializers/ser_json.cpp`, class `SimdjsonSer`:

```cpp
void prepare(const Fixture& fx) override {
    type_id_ = fx.type_id;
    n_ = fx.instance_count;
    cached_json_ = value_to_json(fx.value).dump();   // nlohmann, untimed
}

std::vector<uint8_t> serialize_bytes(const Fixture&) override {
    return std::vector<uint8_t>(cached_json_.begin(), cached_json_.end());
}

Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    simdjson::padded_string ps(
        reinterpret_cast<const char*>(data.data()), data.size());
    simdjson::dom::element el = parser_.parse(ps);   // simdjson — real
    std::string minified = simdjson::minify(el);     // extra pass
    auto j = nlohmann::json::parse(minified);        // second parser
    return json_to_value(j, type_id_, n_);           // DOM → domain
}
```

The comment above the class states the intent: “DOM parse (library strength); ser = prepared minified JSON.” The leaderboard does not repeat that sentence. Students who only read the table will mis-rank the library.

**Glaze**, for contrast (`cpp/src/serializers/ser_glaze.cpp`), writes on the clock:

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

The [google-protobuf encode cache](javascript-json-vs-protobuf.md) is the sibling warning on the encode side: if `prepare` does the real work, the encode column measures a copy.

## How to read any “DOM” row

When `native_kind` is `dom` (this wrapper reports exactly that), ask:

1. Is encode a real write, or a copy of text built in `prepare`?
2. Does decode stop at the library’s document model, or does it parse again into another model?
3. Is there a struct-backed JSON row (here: Glaze) that times the path an application would actually write?

If the answers are “copy,” “parse again,” and “yes,” do not use the row to rank the famous library against Glaze.

**History.** simdjson answered a 2010s question: can we find `{`, `}`, and `"` in a JSON byte stream with one processor instruction on many bytes? The papers are about **parse**. They are not about “replace nlohmann in a benchmark runner.” Using the parse as a stage in a longer pipeline is normal. Reporting that pipeline under the name `simdjson` is what this page exists to unpack.

## Self-check

1. What does the 217 ns encode allocate, and what library produced the characters it copies?
2. List the two `parse` calls inside `deserialize_bytes`. Which one is simdjson?
3. You want to measure “simdjson into `bench::Document`.” Which two stages would you delete or replace, and what would you expect to happen to the 12.6 µs?
