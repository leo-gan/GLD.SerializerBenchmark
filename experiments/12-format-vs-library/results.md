# Is it the format, or the library?

**Question:** If one library can write several formats, how much of the difference is the format, and how much is that library?
**Date:** 2026-09-04
**Sample:** `document`, 1 record(s) per write · [`sample.json`](sample.json)
**Settings:** [`experiment.yaml`](experiment.yaml)
**Machine-readable file:** [`results.json`](results.json)

Times in two languages are **not** one contest. Read each row as an answer inside that language only.

We do not name a single winner. This sample is one small order. A different record can change who is first. **Similar** means we cannot tell the library apart from the fastest in the comparison set on this sample. **Close** means a small gap. Holding one library still is not a claim about every writer of that format.

## At a glance

| Language | Status | Not clearly slower | Small gap | Time/size front | Full table |
|----------|--------|--------------------|-----------|-----------------|------------|
| java | ok | `jsoniter` | — | `jsoniter`, `jackson-smile` | [java/results.md](java/results.md) |
| kotlin | ok | `moshi-codegen` | — | `moshi-codegen`, `kotlinx-cbor`, `kotlinx-protobuf` | [kotlin/results.md](kotlin/results.md) |
| php | ok | `json` | — | `json`, `rybakit-msgpack`, `protobuf` | [php/results.md](php/results.md) |
| cpp | ok | `nlohmann_json`, `nlohmann_bson`, `nlohmann_msgpack`, `nlohmann_cbor`, `nlohmann_ubjson` | — | `nlohmann_json`, `nlohmann_msgpack` | [cpp/results.md](cpp/results.md) |
| go | ok | `goccy/go-json` | — | `goccy/go-json`, `ugorji/msgpack`, `shamaton/msgpack` | [go/results.md](go/results.md) |
| csharp | ok | `MS Bond Fast` | — | `MS Bond Fast`, `MS Bond Compact` | [csharp/results.md](csharp/results.md) |
| javascript | ok | `google-protobuf` | — | `google-protobuf` | [javascript/results.md](javascript/results.md) |
| zig | ok | `comptime-bin` | — | `comptime-bin`, `protobuf` | [zig/results.md](zig/results.md) |

## In memory, by language

Every listed library (same library across formats, and same format across libraries). Times are middle values in microseconds. Lower is better **inside that language**.

### java

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| jsoniter | 48.6 | 440 | JSON — another library (jsoniter, Experiment 1) | fastest |
| gson | 91.6 | 440 | JSON — another library (Gson) | slower |
| jackson-smile | 104 | 233 | Jackson — Smile | slower |
| jackson-cbor | 105 | 334 | Jackson — CBOR | slower |
| jackson | 110 | 440 | Jackson — JSON | slower |
| msgpack | 132 | 317 | Jackson — MessagePack | slower |
| ion | 258 | 380 | Jackson — Ion | slower |

### kotlin

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| moshi-codegen | 48.2 | 440 | JSON — another library (Moshi) | fastest |
| kotlinx-cbor | 70.0 | 335 | kotlinx.serialization — CBOR | slower |
| kotlinx-protobuf | 76.6 | 155 | kotlinx.serialization — ProtoBuf | slower |
| kotlinx-json | 95.3 | 440 | kotlinx.serialization — JSON | slower |
| gson | 100.0 | 440 | JSON — another library (Gson) | slower |
| jackson-cbor | 144 | 334 | Jackson — CBOR | slower |
| jackson | 144 | 440 | Jackson — JSON | slower |
| msgpack | 170 | 317 | MessagePack | slower |

### php

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| json | 5.76 | 454 | stdlib — JSON | fastest |
| symfony-json | 7.76 | 454 | Symfony — JSON | slower |
| rybakit-msgpack | 21.7 | 335 | rybakit — MessagePack | slower |
| protobuf | 197 | 160 | google/protobuf | slower |
| cbor | 240 | 339 | cbor-php — CBOR | slower |
| yaml | 282 | 515 | Symfony — YAML | slower |

### cpp

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| nlohmann_json | 26.0 | 458 | nlohmann — JSON | fastest |
| nlohmann_bson | 26.0 | 502 | nlohmann — BSON | similar |
| nlohmann_msgpack | 26.1 | 332 | nlohmann — MessagePack | similar |
| nlohmann_cbor | 26.4 | 338 | nlohmann — CBOR | similar |
| nlohmann_ubjson | 27.0 | 409 | nlohmann — UBJSON | similar |

### go

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| goccy/go-json | 2.89 | 448 | JSON — another library (Experiment 1) | fastest |
| ugorji/msgpack | 3.68 | 329 | ugorji — MessagePack | slower |
| shamaton/msgpack | 3.71 | 317 | MessagePack — another library | slower |
| ugorji/cbor | 4.02 | 332 | ugorji — CBOR | slower |
| ugorji/json | 4.84 | 448 | ugorji — JSON | slower |
| vmihailenco/msgpack | 5.06 | 397 | MessagePack — another library | slower |
| encoding/json | 8.66 | 448 | JSON — ships with Go | slower |

### csharp

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| MS Bond Fast | 10.3 | 376 | Bond — Fast Binary | fastest |
| MS Bond Compact | 11.8 | 208 | Bond — Compact Binary | slower |
| Google.Protobuf | 20.9 | 208 | Protocol Buffers — Google library | slower |
| ProtoBuf | 25.8 | 208 | Protocol Buffers — protobuf-net | slower |

### javascript

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| google-protobuf | 16.0 | 155 | Protocol Buffers — google-protobuf | fastest |
| protobufjs | 38.7 | 155 | Protocol Buffers — protobufjs | slower |
| protobuf-es | 68.9 | 155 | Protocol Buffers — protobuf-es | slower |

### zig

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| comptime-bin | 0.38 | 214 | in-tree — packed | fastest |
| s2s | 0.55 | 266 | s2s — native binary | slower |
| flatbuffers | 1.06 | 468 | FlatBuffers | slower |
| protobuf | 1.10 | 155 | Protocol Buffers — zig-protobuf | slower |
| serde.msgpack | 1.66 | 325 | serde.zig — MessagePack | slower |
| serde.json | 2.47 | 448 | serde.zig — JSON | slower |
| std.json | 3.46 | 448 | stdlib — JSON | slower |
| zbor | 3.97 | 332 | zbor — CBOR | slower |
| serde.toml | 5.06 | 508 | serde.zig — TOML | slower |
| zig-msgpack | 5.35 | 325 | zigcc — MessagePack | slower |
| capnproto | 7.57 | 376 | Cap’n Proto | slower |

## What we saw

On this one order, the **library** often moves time more than the **format** does. Times are not one contest across languages.

- **Java:** `jsoniter` (JSON) is not clearly slower (about 49 µs, 440 bytes). Jackson JSON is about 110 µs and the same size. Inside Jackson, Smile is smaller (233 bytes) and similar in time to Jackson JSON. Jackson MessagePack is slower than Jackson JSON. `gson` sits between `jsoniter` and Jackson.
- **C++:** All five nlohmann formats sit in a tight time band (about 9–10 µs). JSON is fastest. MessagePack and CBOR are smaller. BSON is **larger** than JSON.
- **Go:** `goccy/go-json` is fastest (about 2.89 µs, 448 bytes). Inside ugorji, MessagePack is a bit faster and smaller than JSON. `encoding/json` is about three times slower than `goccy/go-json`. The three MessagePack libraries are closer to each other than the three JSON libraries are.
- **C#:** Bond Fast is fastest and writes a larger file (376 bytes). Bond Compact is smaller (208 bytes). Both protobuf libraries write 208 bytes and are slower than Bond. Fast vs Compact is the size trade Microsoft wrote down.
- **JavaScript:** All three Protocol Buffers libraries write 155 bytes. `google-protobuf` is about 16 µs; `protobuf-es` is about 69 µs — same format, about four times the time.

“Move to binary” without naming the library is not a plan.

## What this page is not

- It is not a ranking of languages.
- It is not a world ranking of formats.
- It is not a claim about every MessagePack (or JSON) library — only the one library we held still, and the extra names listed for that format.
- It is not a promise that the same names stay on top if you change the record.

