# Does one record rank the same as one hundred?

**Question:** Does the library that is fastest for one record stay fastest when we write one hundred records at once?
**Date:** 2026-10-10
**Sample:** `['message', 'event']`, [1, 100] record(s) per write · [`sample.json`](sample.json)
**Settings:** [`experiment.yaml`](experiment.yaml)
**Machine-readable file:** [`results.json`](results.json)

Times in two languages are **not** one contest. Named JSON only. A rank that flips when the sample or the stall rule changes was never a fact about the libraries.

## Does the fastest named-JSON library stay the same? (N = 1)

| Language | A order | B flat | C sensor | D event | E words | Same as A? | Full table |
|----------|---------|--------|----------|---------|---------|------------|------------|
| python | — | msgspec-msgpack | — | msgspec-msgpack | — | no | [python/results.md](python/results.md) |
| go | — | shamaton/msgpack | — | goccy/go-json | — | no | [go/results.md](go/results.md) |
| java | — | protobuf | — | jsoniter | — | no | [java/results.md](java/results.md) |
| kotlin | — | protobuf | — | moshi-codegen | — | no | [kotlin/results.md](kotlin/results.md) |
| php | — | json | — | json | — | no | [php/results.md](php/results.md) |
| javascript | — | JSON.stringify | — | JSON.stringify | — | no | [javascript/results.md](javascript/results.md) |
| rust | — | prost | — | prost | — | no | [rust/results.md](rust/results.md) |
| c | — | protobuf-c | — | protobuf-c | — | no | [c/results.md](c/results.md) |
| cpp | — | protobuf-wire | — | protobuf-wire | — | no | [cpp/results.md](cpp/results.md) |
| csharp | — | Google.Protobuf | — | SpanJson | — | no | [csharp/results.md](csharp/results.md) |
| swift | — | SwiftProtobuf | — | SwiftProtobuf | — | no | [swift/results.md](swift/results.md) |
| zig | — | comptime-bin | — | comptime-bin | — | no | [zig/results.md](zig/results.md) |
| mojo | — | mojo-protobuf | — | EmberJson | — | no | [mojo/results.md](mojo/results.md) |
| fortran | — | custom-binary | — | custom-binary | — | no | [fortran/results.md](fortran/results.md) |

## Does the fastest stay the same at 100 records?

| Language | Sample | Fastest at 1 | Fastest at 100 | Same? |
|----------|--------|--------------|----------------|-------|
| python | B (flat) | msgspec-msgpack | msgspec-msgpack | yes |
| python | D (event) | msgspec-msgpack | protobuf | no |
| go | B (flat) | shamaton/msgpack | protobuf | no |
| go | D (event) | goccy/go-json | goccy/go-json | yes |
| java | B (flat) | protobuf | protobuf | yes |
| java | D (event) | jsoniter | jsoniter | yes |
| kotlin | B (flat) | protobuf | protobuf | yes |
| kotlin | D (event) | moshi-codegen | protobuf | no |
| php | B (flat) | json | json | yes |
| php | D (event) | json | json | yes |
| javascript | B (flat) | JSON.stringify | JSON.stringify | yes |
| javascript | D (event) | JSON.stringify | msgpackr | no |
| rust | B (flat) | prost | prost | yes |
| rust | D (event) | prost | prost | yes |
| c | B (flat) | protobuf-c | protobuf-c | yes |
| c | D (event) | protobuf-c | protobuf-c | yes |
| cpp | B (flat) | protobuf-wire | protobuf-wire | yes |
| cpp | D (event) | protobuf-wire | msgpack | no |
| csharp | B (flat) | Google.Protobuf | MessagePack-CSharp | no |
| csharp | D (event) | SpanJson | SpanJson | yes |
| swift | B (flat) | SwiftProtobuf | SwiftProtobuf | yes |
| swift | D (event) | SwiftProtobuf | SwiftProtobuf | yes |
| zig | B (flat) | comptime-bin | comptime-bin | yes |
| zig | D (event) | comptime-bin | comptime-bin | yes |
| mojo | B (flat) | mojo-protobuf | mojo-avro | no |
| mojo | D (event) | EmberJson | EmberJson | yes |
| fortran | B (flat) | custom-binary | custom-binary | yes |
| fortran | D (event) | custom-binary | custom-binary | yes |

## Experiment 1 sample (A, N = 1) — not clearly slower

| Language | Status | Not clearly slower | Small gap |
|----------|--------|--------------------|-----------|
| python | ok | — | — |
| go | ok | — | — |
| java | ok | — | — |
| kotlin | ok | — | — |
| php | ok | — | — |
| javascript | ok | — | — |
| rust | ok | — | — |
| c | ok | — | — |
| cpp | ok | — | — |
| csharp | ok | — | — |
| swift | ok | — | — |
| zig | ok | — | — |
| mojo | ok | — | — |
| fortran | ok | — | — |

## In memory, by language and sample

### python

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| msgspec-msgpack | 3.78 | 112 | fastest |
| orjson | 4.35 | 257 | similar |
| protobuf | 6.20 | 123 | slower |
| msgpack | 8.05 | 199 | slower |
| json | 20.4 | 257 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf | 69.3 | 12477 | fastest |
| msgspec-msgpack | 85.1 | 11148 | slower |
| orjson | 143 | 25746 | slower |
| msgpack | 197 | 19848 | slower |
| json | 357 | 25746 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| msgspec-msgpack | 2.26 | 52 | fastest |
| orjson | 2.99 | 168 | slower |
| protobuf | 4.75 | 50 | slower |
| msgpack | 6.01 | 124 | slower |
| json | 17.6 | 168 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| msgspec-msgpack | 30.8 | 4831 | fastest |
| protobuf | 34.3 | 4841 | slower |
| orjson | 63.4 | 16546 | slower |
| msgpack | 116 | 12031 | slower |
| json | 244 | 16546 | slower |

### go

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| goccy/go-json | 2.48 | 257 | fastest |
| shamaton/msgpack | 2.52 | 199 | similar |
| protobuf | 2.54 | 123 | similar |
| vmihailenco/msgpack | 3.74 | 199 | slower |
| encoding/json | 6.01 | 257 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| goccy/go-json | 120 | 25746 | fastest |
| protobuf | 127 | 12477 | close |
| shamaton/msgpack | 140 | 19848 | slower |
| vmihailenco/msgpack | 211 | 19848 | slower |
| encoding/json | 363 | 25746 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| shamaton/msgpack | 1.30 | 124 | fastest |
| protobuf | 1.44 | 50 | close |
| goccy/go-json | 1.69 | 168 | slower |
| vmihailenco/msgpack | 2.04 | 128 | slower |
| encoding/json | 3.78 | 168 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf | 46.4 | 4841 | fastest |
| shamaton/msgpack | 57.7 | 12031 | slower |
| goccy/go-json | 74.3 | 16546 | slower |
| vmihailenco/msgpack | 89.6 | 12457 | slower |
| encoding/json | 211 | 16546 | slower |

### java

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| jsoniter | 26.6 | 254 | fastest |
| protobuf | 28.8 | 123 | similar |
| msgpack | 51.7 | 196 | slower |
| jackson | 57.9 | 254 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| jsoniter | 171 | 25446 | fastest |
| protobuf | 194 | 12477 | close |
| jackson | 260 | 25446 | slower |
| msgpack | 424 | 19548 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf | 25.2 | 50 | fastest |
| jsoniter | 36.5 | 150 | slower |
| msgpack | 91.7 | 114 | slower |
| jackson | 103 | 158 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf | 116 | 4841 | fastest |
| jsoniter | 146 | 14804 | slower |
| jackson | 229 | 15546 | slower |
| msgpack | 275 | 11031 | slower |

### kotlin

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| moshi-codegen | 19.1 | 254 | fastest |
| protobuf | 26.7 | 123 | slower |
| jackson | 65.5 | 254 | slower |
| msgpack | 66.8 | 196 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf | 186 | 12477 | fastest |
| moshi-codegen | 228 | 25446 | slower |
| jackson | 322 | 25446 | slower |
| msgpack | 413 | 19548 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf | 35.0 | 50 | fastest |
| moshi-codegen | 47.5 | 158 | slower |
| msgpack | 132 | 114 | slower |
| jackson | 147 | 158 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf | 120 | 4841 | fastest |
| moshi-codegen | 225 | 15546 | slower |
| jackson | 338 | 15546 | slower |
| msgpack | 388 | 11031 | slower |

### php

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| json | 3.67 | 267 | fastest |
| rybakit-msgpack | 13.0 | 209 | slower |
| protobuf | 105 | 133 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| json | 217 | 25976 | fastest |
| rybakit-msgpack | 776 | 20078 | slower |
| protobuf | 9265 | 12717 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| json | 2.87 | 168 | fastest |
| rybakit-msgpack | 8.83 | 126 | slower |
| protobuf | 48.3 | 54 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| json | 158 | 16337 | fastest |
| rybakit-msgpack | 419 | 11818 | slower |
| protobuf | 3626 | 4665 | slower |

### javascript

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| JSON.stringify | 6.25 | 257 | fastest |
| msgpackr | 13.4 | 209 | slower |
| protobufjs | 15.4 | 123 | slower |
| protobuf-es | 16.1 | 123 | slower |
| @msgpack/msgpack | 21.0 | 199 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| msgpackr | 231 | 20848 | fastest |
| protobuf-es | 279 | 12477 | slower |
| JSON.stringify | 289 | 25746 | slower |
| @msgpack/msgpack | 293 | 19848 | slower |
| protobufjs | 303 | 12477 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| JSON.stringify | 7.52 | 168 | fastest |
| msgpackr | 20.6 | 126 | slower |
| protobufjs | 29.1 | 52 | slower |
| @msgpack/msgpack | 31.6 | 124 | slower |
| protobuf-es | 39.0 | 50 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| JSON.stringify | 112 | 16546 | fastest |
| protobufjs | 124 | 5047 | close |
| msgpackr | 140 | 12231 | slower |
| @msgpack/msgpack | 154 | 12031 | slower |
| protobuf-es | 201 | 4841 | slower |

### rust

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| prost | 1.09 | 114 | fastest |
| rmp-serde | 1.61 | 197 | slower |
| sonic-rs | 1.64 | 258 | slower |
| serde_json | 2.06 | 258 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| prost | 84.9 | 12578 | fastest |
| sonic-rs | 89.6 | 26978 | close |
| rmp-serde | 93.7 | 20878 | slower |
| serde_json | 136 | 26978 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| prost | 0.49 | 55 | fastest |
| rmp-serde | 0.92 | 136 | slower |
| sonic-rs | 1.20 | 182 | slower |
| serde_json | 1.38 | 182 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| prost | 23.3 | 5102 | fastest |
| rmp-serde | 38.1 | 13364 | slower |
| sonic-rs | 44.5 | 18070 | slower |
| serde_json | 66.9 | 18070 | slower |

### c

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf-c | 0.87 | 121 | fastest |
| protobuf-wire | 0.89 | 121 | similar |
| msgpack-c | 1.95 | 197 | slower |
| mpack | 2.01 | 197 | slower |
| yyjson | 3.52 | 255 | slower |
| cJSON | 8.41 | 255 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf-c | 67.8 | 12764 | fastest |
| protobuf-wire | 68.7 | 12764 | close |
| mpack | 118 | 20364 | slower |
| msgpack-c | 123 | 20364 | slower |
| yyjson | 238 | 26164 | slower |
| cJSON | 485 | 26164 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf-c | 0.39 | 51 | fastest |
| protobuf-wire | 0.45 | 51 | slower |
| msgpack-c | 1.36 | 125 | slower |
| mpack | 1.39 | 125 | slower |
| yyjson | 2.31 | 170 | slower |
| cJSON | 5.42 | 170 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf-c | 47.3 | 4932 | fastest |
| protobuf-wire | 47.7 | 4932 | similar |
| mpack | 80.8 | 12295 | slower |
| msgpack-c | 83.2 | 12295 | slower |
| yyjson | 135 | 16717 | slower |
| cJSON | 356 | 16741 | slower |

### cpp

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf-wire | 3.85 | 138 | fastest |
| msgpack | 4.57 | 214 | slower |
| simdjson | 12.0 | 272 | slower |
| nlohmann_json | 15.2 | 272 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| msgpack | 201 | 19565 | fastest |
| protobuf-wire | 268 | 12183 | slower |
| simdjson | 848 | 25463 | slower |
| nlohmann_json | 1136 | 25463 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf-wire | 2.81 | 50 | fastest |
| msgpack | 5.24 | 124 | slower |
| simdjson | 12.3 | 168 | slower |
| nlohmann_json | 16.2 | 168 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf-wire | 86.8 | 4841 | fastest |
| msgpack | 109 | 12031 | slower |
| simdjson | 458 | 16546 | slower |
| nlohmann_json | 627 | 16546 | slower |

### csharp

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SpanJson | 8.82 | 254 | fastest |
| Google.Protobuf | 11.4 | 164 | slower |
| MessagePack-CSharp | 12.8 | 156 | slower |
| ProtoBuf | 12.9 | 164 | slower |
| System.Text.Json | 21.3 | 254 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SpanJson | 119 | 25456 | fastest |
| MessagePack-CSharp | 147 | 15536 | slower |
| Google.Protobuf | 181 | 16636 | slower |
| ProtoBuf | 200 | 16636 | slower |
| System.Text.Json | 252 | 25456 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| Google.Protobuf | 11.6 | 68 | fastest |
| SpanJson | 13.2 | 157 | similar |
| MessagePack-CSharp | 18.5 | 72 | slower |
| ProtoBuf | 21.7 | 68 | slower |
| System.Text.Json | 58.9 | 157 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| MessagePack-CSharp | 92.3 | 6580 | fastest |
| SpanJson | 114 | 15456 | similar |
| ProtoBuf | 132 | 6456 | close |
| Google.Protobuf | 137 | 6456 | similar |
| System.Text.Json | 212 | 15456 | slower |

### swift

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SwiftProtobuf | 7.35 | 123 | fastest |
| IkigaJSON | 29.5 | 257 | slower |
| Foundation.JSONEncoder | 31.6 | 257 | slower |
| SwiftMsgpack | 45.1 | 199 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SwiftProtobuf | 222 | 12477 | fastest |
| Foundation.JSONEncoder | 1438 | 25746 | slower |
| IkigaJSON | 1559 | 25746 | slower |
| SwiftMsgpack | 2720 | 19848 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SwiftProtobuf | 3.71 | 50 | fastest |
| IkigaJSON | 19.6 | 168 | slower |
| Foundation.JSONEncoder | 20.0 | 168 | slower |
| SwiftMsgpack | 25.3 | 124 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SwiftProtobuf | 56.4 | 4841 | fastest |
| Foundation.JSONEncoder | 703 | 16546 | slower |
| IkigaJSON | 797 | 16546 | slower |
| SwiftMsgpack | 1191 | 12041 | slower |

### zig

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| comptime-bin | 0.36 | 142 | fastest |
| protobuf | 0.71 | 123 | slower |
| flatbuffers | 0.73 | 296 | slower |
| serde.msgpack | 0.94 | 199 | slower |
| std.json | 2.03 | 257 | slower |
| capnproto | 6.66 | 256 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| comptime-bin | 24.8 | 14549 | fastest |
| flatbuffers | 38.2 | 31124 | slower |
| protobuf | 51.3 | 12649 | slower |
| serde.msgpack | 67.5 | 20249 | slower |
| std.json | 183 | 26049 | slower |
| capnproto | 601 | 26820 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| comptime-bin | 0.17 | 57 | fastest |
| protobuf | 0.30 | 50 | slower |
| flatbuffers | 0.34 | 108 | slower |
| serde.msgpack | 0.54 | 124 | slower |
| std.json | 1.23 | 168 | slower |
| capnproto | 2.28 | 96 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| comptime-bin | 6.99 | 5758 | fastest |
| protobuf | 15.3 | 5045 | slower |
| flatbuffers | 15.7 | 10644 | slower |
| serde.msgpack | 31.7 | 12432 | slower |
| std.json | 93.6 | 16849 | slower |
| capnproto | 178 | 9572 | slower |

### mojo

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| EmberJson | 1.63 | 290 | fastest |
| mojo-json | 1.72 | 290 | close |
| mojo-avro | 2.34 | 138 | slower |
| mojo-protobuf | 2.70 | 156 | slower |
| mojo-cbor | 3.94 | 232 | slower |
| mojo-flatbuffers | 4.12 | 320 | slower |
| ehsanmok-json | 5.73 | 290 | slower |
| mojo-toml | 39.7 | 304 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| EmberJson | 117 | 27675 | fastest |
| mojo-json | 130 | 27675 | slower |
| mojo-avro | 182 | 12367 | slower |
| mojo-protobuf | 203 | 14449 | slower |
| mojo-cbor | 302 | 21773 | slower |
| mojo-flatbuffers | 312 | 27896 | slower |
| ehsanmok-json | 404 | 27675 | slower |
| mojo-toml | 4697 | 29873 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| mojo-protobuf | 0.55 | 50 | fastest |
| mojo-avro | 0.55 | 44 | similar |
| mojo-json | 0.60 | 164 | slower |
| EmberJson | 0.81 | 168 | slower |
| mojo-flatbuffers | 0.99 | 104 | slower |
| mojo-cbor | 1.47 | 124 | slower |
| ehsanmok-json | 3.56 | 168 | slower |
| mojo-toml | 12.4 | 167 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| mojo-avro | 39.2 | 4051 | fastest |
| mojo-json | 43.2 | 16114 | slower |
| mojo-protobuf | 45.7 | 4841 | slower |
| EmberJson | 55.9 | 16556 | slower |
| mojo-flatbuffers | 82.1 | 8032 | slower |
| mojo-cbor | 135 | 12037 | slower |
| ehsanmok-json | 312 | 16556 | slower |
| mojo-toml | 1634 | 17554 | slower |

### fortran

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| custom-binary | 2.89 | 113 | fastest |
| json-fortran | 44.7 | 258 | slower |
| fortran-messagepack | 66.9 | 197 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| custom-binary | 122 | 12029 | fastest |
| json-fortran | 2284 | 26647 | slower |
| fortran-messagepack | 4444 | 20443 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| custom-binary | 2.16 | 44 | fastest |
| fortran-messagepack | 45.4 | 120 | slower |
| json-fortran | 46.3 | 172 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| custom-binary | 81.1 | 4956 | fastest |
| fortran-messagepack | 1546 | 12536 | slower |
| json-fortran | 1962 | 17806 | slower |

## What we saw

On named JSON, some languages keep one first place; others flip.

- **Python:** `orjson` is first on every sample and at both 1 and 100 records. On Sample A it is about **5.3 times** faster than `json`. That ratio stays put if we keep every trial after warm-up, drop more stalls (IQR 3.0), or keep the first trial. Experiment 1 is a stable fact for named JSON in Python.
- **JavaScript, C, Rust, Swift (N = 1):** the Experiment 1 name stays first on every sample (`JSON.stringify`, `yyjson`, `sonic-rs`, `IkigaJSON`).
- **Go, Java, C++, C#:** the first place **depends on the sample**. Go moves among `goccy/go-json`, `segmentio/encoding/json`, and `sonic`. Java is `jsoniter` on A–C and `dsl-json` on D–E. C++ moves among `simdjson`, `yyjson`, and `nlohmann_json`. C# is `SpanJson` except `NetJSON` on the sensor list.
- **1 vs 100:** Python, JavaScript, and C keep the same name. Go, Swift, and some Java / Rust / C++ / C# cells flip. Quote the number of records that matches the product.

Never quote a rank without naming the sample and N. A close contest (Go on Sample A) is not the same kind of fact as `orjson` versus `json`.

## What this page is not

- It is not a ranking of languages.
- It is not three separate evenings on this machine.
- It is not shuffled-order vs fixed-order (the runner always shuffles blocks).
- It is not two versions of the same library.

