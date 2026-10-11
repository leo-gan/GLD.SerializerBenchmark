# Does one record rank the same as one hundred?

**Question:** Does the library that is fastest for one record stay fastest when we write one hundred records at once?
**Date:** 2026-10-11
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
| mojo | — | mojo-protobuf | — | mojo-avro | — | no | [mojo/results.md](mojo/results.md) |
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
| mojo | B (flat) | mojo-protobuf | mojo-protobuf | yes |
| mojo | D (event) | mojo-avro | mojo-json | no |
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
| moshi-codegen | 24.5 | 254 | fastest |
| protobuf | 35.0 | 123 | slower |
| msgpack | 78.5 | 196 | slower |
| jackson | 81.6 | 254 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf | 191 | 12477 | fastest |
| moshi-codegen | 212 | 25446 | slower |
| jackson | 300 | 25446 | slower |
| msgpack | 390 | 19548 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf | 32.9 | 50 | fastest |
| moshi-codegen | 43.7 | 158 | slower |
| msgpack | 111 | 114 | slower |
| jackson | 119 | 158 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf | 92.8 | 4841 | fastest |
| moshi-codegen | 188 | 15546 | slower |
| jackson | 264 | 15546 | slower |
| msgpack | 274 | 11031 | slower |

### php

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| json | 3.88 | 267 | fastest |
| rybakit-msgpack | 13.2 | 209 | slower |
| protobuf | 110 | 133 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| json | 217 | 25976 | fastest |
| rybakit-msgpack | 770 | 20078 | slower |
| protobuf | 9124 | 12717 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| json | 3.31 | 168 | fastest |
| rybakit-msgpack | 9.11 | 126 | slower |
| protobuf | 50.6 | 54 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| json | 158 | 16337 | fastest |
| rybakit-msgpack | 424 | 11818 | slower |
| protobuf | 3657 | 4665 | slower |

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
| SwiftProtobuf | 8.54 | 123 | fastest |
| IkigaJSON | 28.3 | 257 | slower |
| Foundation.JSONEncoder | 30.1 | 257 | slower |
| SwiftMsgpack | 43.8 | 199 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SwiftProtobuf | 244 | 12477 | fastest |
| Foundation.JSONEncoder | 1411 | 25746 | slower |
| IkigaJSON | 1524 | 25746 | slower |
| SwiftMsgpack | 2628 | 19848 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SwiftProtobuf | 4.32 | 50 | fastest |
| IkigaJSON | 20.1 | 168 | slower |
| Foundation.JSONEncoder | 20.9 | 168 | slower |
| SwiftMsgpack | 27.0 | 124 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SwiftProtobuf | 59.2 | 4841 | fastest |
| Foundation.JSONEncoder | 679 | 16546 | slower |
| IkigaJSON | 770 | 16546 | slower |
| SwiftMsgpack | 1144 | 12041 | slower |

### zig

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| comptime-bin | 0.39 | 142 | fastest |
| serde.msgpack | 0.74 | 199 | slower |
| flatbuffers | 0.83 | 296 | slower |
| protobuf | 0.83 | 123 | slower |
| std.json | 1.76 | 257 | slower |
| capnproto | 9.81 | 256 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| comptime-bin | 22.5 | 14549 | fastest |
| flatbuffers | 38.8 | 31124 | slower |
| serde.msgpack | 42.0 | 20249 | slower |
| protobuf | 51.2 | 12649 | slower |
| std.json | 145 | 26049 | slower |
| capnproto | 659 | 26820 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| comptime-bin | 0.18 | 57 | fastest |
| protobuf | 0.39 | 50 | slower |
| flatbuffers | 0.40 | 108 | slower |
| serde.msgpack | 0.51 | 124 | slower |
| std.json | 1.08 | 168 | slower |
| capnproto | 4.29 | 96 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| comptime-bin | 6.11 | 5758 | fastest |
| flatbuffers | 16.5 | 10644 | slower |
| protobuf | 16.8 | 5045 | slower |
| serde.msgpack | 23.6 | 12432 | slower |
| std.json | 76.3 | 16849 | slower |
| capnproto | 213 | 9572 | slower |

### mojo

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| mojo-avro | 2.56 | 105 | fastest |
| mojo-protobuf | 2.66 | 123 | similar |
| mojo-json | 2.84 | 257 | close |
| mojo-cbor | 3.55 | 199 | slower |
| mojo-flatbuffers | 3.95 | 272 | slower |
| EmberJson | 5.53 | 257 | slower |
| ehsanmok-json | 6.87 | 257 | slower |
| mojo-toml | 38.5 | 271 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| mojo-json | 99.2 | 25756 | fastest |
| mojo-protobuf | 107 | 12477 | slower |
| mojo-avro | 144 | 10448 | slower |
| EmberJson | 172 | 25756 | slower |
| mojo-flatbuffers | 181 | 25968 | slower |
| mojo-cbor | 205 | 19854 | slower |
| ehsanmok-json | 317 | 25756 | slower |
| mojo-toml | 4249 | 27954 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| mojo-protobuf | 1.16 | 50 | fastest |
| mojo-avro | 1.51 | 44 | slower |
| mojo-json | 2.08 | 164 | slower |
| mojo-flatbuffers | 2.47 | 104 | slower |
| mojo-cbor | 2.82 | 124 | slower |
| EmberJson | 4.95 | 168 | slower |
| ehsanmok-json | 6.72 | 168 | slower |
| mojo-toml | 20.3 | 167 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| mojo-protobuf | 22.7 | 4841 | fastest |
| mojo-avro | 33.0 | 4051 | slower |
| mojo-json | 34.3 | 16114 | slower |
| mojo-flatbuffers | 45.4 | 8032 | slower |
| EmberJson | 83.9 | 16556 | slower |
| mojo-cbor | 95.5 | 12037 | slower |
| ehsanmok-json | 251 | 16556 | slower |
| mojo-toml | 1463 | 17554 | slower |

### fortran

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| custom-binary | 1.35 | 113 | fastest |
| json-fortran | 27.8 | 258 | slower |
| fortran-messagepack | 48.7 | 197 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| custom-binary | 99.7 | 12029 | fastest |
| json-fortran | 1733 | 26647 | slower |
| fortran-messagepack | 3295 | 20443 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| custom-binary | 0.94 | 44 | fastest |
| json-fortran | 24.5 | 172 | slower |
| fortran-messagepack | 28.6 | 120 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| custom-binary | 67.2 | 4956 | fastest |
| fortran-messagepack | 1168 | 12536 | slower |
| json-fortran | 1525 | 17806 | slower |

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

