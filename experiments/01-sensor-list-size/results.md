# When is JSON too big for a sensor?

**Question:** As a list of sensor numbers grows, when does JSON no longer fit a small radio packet?
**Date:** 2026-11-12
**Sample:** `telemetry`, one record, list lengths [8, 32, 128, 512] · [`sample.json`](sample.json)
**Settings:** [`experiment.yaml`](experiment.yaml)
**Machine-readable file:** [`results.json`](results.json)

Times in two languages are **not** one contest. **Size** is the first number on this curve. We mark two example packet sizes: **128 bytes** and **512 bytes**. Your radio may differ.

We do not name a single winner. Groups are separate for each list length.

## Size curve (in memory)

Bytes written. Lower is smaller. Marks: 128 B, 512 B.

### rust

| Library | 8 nums | 32 nums | 128 nums | 512 nums | vs 128 / 512 at 512 nums | Role |
|---------|--------|--------|--------|--------|--------------------------|------|
| gld-kiln | 107 | 302 | 1066 | 4143 | >128, >512 | positional binary — no field names |
| postcard | 91 | 286 | 1051 | 4128 | >128, >512 | postcard — compact Rust |
| prost | 94 | 290 | 1054 | 4131 | >128, >512 | Protocol Buffers |
| rmp-serde | 135 | 356 | 1216 | 4677 | >128, >512 | MessagePack |
| ciborium | 135 | 355 | 1215 | 4677 | >128, >512 | CBOR |
| serde_json | 234 | 672 | 2420 | 9415 | >128, >512 | JSON — usual Rust library |
| sonic-rs | 234 | 672 | 2420 | 9415 | >128, >512 | JSON — fast writer fast named JSON |

### c

| Library | 8 nums | 32 nums | 128 nums | 512 nums | vs 128 / 512 at 512 nums | Role |
|---------|--------|--------|--------|--------|--------------------------|------|
| protobuf-wire | 105 | 317 | 1187 | 4640 | >128, >512 | Protocol Buffers — in-tree wire helper |
| nanopb | 105 | 317 | 1187 | 4640 | >128, >512 | Protocol Buffers — nanopb (read the C page before quoting) |
| gld-kiln | 112 | 300 | 1074 | 4143 | >128, >512 | positional binary — no field names |
| mpack | 129 | 343 | 1213 | 4666 | >128, >512 | MessagePack |
| tinycbor | 129 | 342 | 1212 | 4666 | >128, >512 | CBOR — Intel tinycbor |
| yyjson | 226 | 661 | 2418 | 9371 | >128, >512 | JSON — fast writer fast named JSON |
| qcbor | 129 | 342 | 1212 | 4666 | >128, >512 | CBOR — small-device writer |
| zcbor | 132 | 344 | 1214 | 4667 | >128, >512 | CBOR — structured (zcbor) |
| cJSON | 226 | 667 | 2448 | 9482 | >128, >512 | JSON — common C library |

### kotlin

| Library | 8 nums | 32 nums | 128 nums | 512 nums | vs 128 / 512 at 512 nums | Role |
|---------|--------|--------|--------|--------|--------------------------|------|
| moshi-codegen | 220 | 663 | 2407 | 9363 | >128, >512 | JSON — fast writer fast named JSON |
| protobuf | 94 | 291 | 1061 | 4128 | >128, >512 | Protocol Buffers |
| kotlinx-cbor | 127 | 347 | 1213 | 4664 | >128, >512 | CBOR |
| kotlinx-json | 220 | 663 | 2407 | 9363 | >128, >512 | JSON — compiler-generated kotlinx.serialization |
| jackson-cbor | 125 | 346 | 1212 | 4664 | >128, >512 | CBOR — Jackson |
| msgpack | 124 | 346 | 1212 | 4663 | >128, >512 | MessagePack |

### php

| Library | 8 nums | 32 nums | 128 nums | 512 nums | vs 128 / 512 at 512 nums | Role |
|---------|--------|--------|--------|--------|--------------------------|------|
| json | 217 | 654 | 2406 | 9380 | >128, >512 | JSON — stdlib |
| rybakit-msgpack | 121 | 339 | 1203 | 4659 | >128, >512 | MessagePack |
| cbor | 121 | 338 | 1202 | 4659 | >128, >512 | CBOR |
| protobuf | 91 | 284 | 1052 | 4124 | >128, >512 | Protocol Buffers |

### zig

| Library | 8 nums | 32 nums | 128 nums | 512 nums | vs 128 / 512 at 512 nums | Role |
|---------|--------|--------|--------|--------|--------------------------|------|
| comptime-bin | 107 | 303 | 1073 | 4140 | >128, >512 | comptime packed |
| flatbuffers | 156 | 348 | 1124 | 4188 | >128, >512 | FlatBuffers |
| serde.msgpack | 124 | 346 | 1212 | 4663 | >128, >512 | MessagePack |
| protobuf | 94 | 291 | 1061 | 4128 | >128, >512 | Protocol Buffers |
| serde.json | 220 | 663 | 2407 | 9363 | >128, >512 | JSON — serde.zig |
| std.json | 220 | 663 | 2407 | 9363 | >128, >512 | JSON — stdlib |
| gld-kiln | 107 | 303 | 1073 | 4140 | >128, >512 | positional binary — no field names |
| capnproto | 152 | 344 | 1120 | 4184 | >128, >512 | Cap’n Proto |

### mojo

| Library | 8 nums | 32 nums | 128 nums | 512 nums | vs 128 / 512 at 512 nums | Role |
|---------|--------|--------|--------|--------|--------------------------|------|
| gld-kiln | 107 | 303 | 1073 | 4140 | >128, >512 | positional binary — no field names |
| mojo-avro | 92 | 288 | 1059 | 4126 | >128, >512 | Avro |
| mojo-protobuf | 94 | 291 | 1061 | 4128 | >128, >512 | Protocol Buffers |
| mojo-cbor | 124 | 345 | 1211 | 4663 | >128, >512 | CBOR |
| mojo-json | 177 | 486 | 1716 | 6621 | >128, >512 | JSON — mojo-json |
| mojo-flatbuffers | 160 | 352 | 1128 | 4192 | >128, >512 | FlatBuffers |
| EmberJson | 220 | 663 | 2407 | 9363 | >128, >512 | JSON — EmberJson |
| ehsanmok-json | 220 | 663 | 2407 | 9363 | >128, >512 | JSON — ehsanmok/json |
| mojo-toml | 227 | 694 | 2534 | 9874 | >128, >512 | TOML |

## Time and groups, by list length

Write + read middle values in microseconds. Lower is better **inside that language**.

### rust

**8 numbers** — not clearly slower: `gld-kiln`. Small gap: `postcard`.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| gld-kiln | 0.83 | 107 | fastest |
| postcard | 0.99 | 91 | close |
| prost | 1.02 | 94 | slower |
| rmp-serde | 1.83 | 135 | slower |
| ciborium | 2.62 | 135 | slower |
| serde_json | 2.78 | 234 | slower |
| sonic-rs | 3.04 | 234 | slower |

**32 numbers** — not clearly slower: `gld-kiln`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| gld-kiln | 0.75 | 302 | fastest |
| postcard | 0.95 | 286 | slower |
| prost | 1.14 | 290 | slower |
| rmp-serde | 1.93 | 356 | slower |
| ciborium | 3.02 | 355 | slower |
| sonic-rs | 4.01 | 672 | slower |
| serde_json | 4.02 | 672 | slower |

**128 numbers** — not clearly slower: `gld-kiln`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| gld-kiln | 0.85 | 1066 | fastest |
| postcard | 1.23 | 1051 | slower |
| prost | 1.59 | 1054 | slower |
| rmp-serde | 2.40 | 1216 | slower |
| ciborium | 4.69 | 1215 | slower |
| serde_json | 9.16 | 2420 | slower |
| sonic-rs | 9.37 | 2420 | slower |

**512 numbers** — not clearly slower: `gld-kiln`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| gld-kiln | 1.11 | 4143 | fastest |
| postcard | 2.16 | 4128 | slower |
| prost | 2.92 | 4131 | slower |
| rmp-serde | 4.40 | 4677 | slower |
| ciborium | 12.1 | 4677 | slower |
| serde_json | 28.5 | 9415 | slower |
| sonic-rs | 29.3 | 9415 | slower |

### c

**8 numbers** — not clearly slower: `protobuf-wire`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf-wire | 0.49 | 105 | fastest |
| nanopb | 0.55 | 105 | slower |
| gld-kiln | 1.17 | 112 | slower |
| mpack | 1.61 | 129 | slower |
| tinycbor | 2.34 | 129 | slower |
| yyjson | 2.78 | 226 | slower |
| qcbor | 2.85 | 129 | slower |
| zcbor | 3.56 | 132 | slower |
| cJSON | 13.2 | 226 | slower |

**32 numbers** — not clearly slower: `protobuf-wire`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf-wire | 0.56 | 317 | fastest |
| nanopb | 0.64 | 317 | slower |
| gld-kiln | 1.18 | 300 | slower |
| mpack | 1.97 | 343 | slower |
| yyjson | 4.46 | 661 | slower |
| tinycbor | 8.16 | 342 | slower |
| qcbor | 9.02 | 342 | slower |
| zcbor | 10.0 | 344 | slower |
| cJSON | 35.6 | 667 | slower |

**128 numbers** — not clearly slower: `protobuf-wire`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf-wire | 0.88 | 1187 | fastest |
| nanopb | 0.96 | 1187 | slower |
| gld-kiln | 1.41 | 1074 | slower |
| mpack | 3.12 | 1213 | slower |
| yyjson | 10.4 | 2418 | slower |
| tinycbor | 90.2 | 1212 | slower |
| qcbor | 91.9 | 1212 | slower |
| zcbor | 102 | 1214 | slower |
| cJSON | 135 | 2448 | slower |

**512 numbers** — not clearly slower: `protobuf-wire`, `nanopb`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf-wire | 2.34 | 4640 | fastest |
| nanopb | 2.38 | 4640 | similar |
| gld-kiln | 3.48 | 4143 | slower |
| mpack | 8.63 | 4666 | slower |
| yyjson | 35.8 | 9371 | slower |
| cJSON | 641 | 9482 | slower |
| tinycbor | 1422 | 4666 | slower |
| qcbor | 1423 | 4666 | slower |
| zcbor | 1558 | 4667 | slower |

### kotlin

**8 numbers** — not clearly slower: `moshi-codegen`. Small gap: `protobuf`.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| moshi-codegen | 47.4 | 220 | fastest |
| protobuf | 57.8 | 94 | close |
| kotlinx-cbor | 78.7 | 127 | slower |
| kotlinx-json | 116 | 220 | slower |
| jackson-cbor | 141 | 125 | slower |
| msgpack | 155 | 124 | slower |

**32 numbers** — not clearly slower: `protobuf`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf | 35.4 | 291 | fastest |
| moshi-codegen | 46.0 | 663 | slower |
| kotlinx-cbor | 51.7 | 347 | slower |
| jackson-cbor | 87.3 | 346 | slower |
| kotlinx-json | 89.5 | 663 | slower |
| msgpack | 95.6 | 346 | slower |

**128 numbers** — not clearly slower: `protobuf`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf | 26.6 | 1061 | fastest |
| kotlinx-cbor | 37.1 | 1213 | slower |
| msgpack | 56.6 | 1212 | slower |
| jackson-cbor | 57.8 | 1212 | slower |
| moshi-codegen | 61.6 | 2407 | slower |
| kotlinx-json | 92.2 | 2407 | slower |

**512 numbers** — not clearly slower: `protobuf`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf | 29.7 | 4128 | fastest |
| kotlinx-cbor | 59.1 | 4664 | slower |
| jackson-cbor | 67.8 | 4664 | slower |
| msgpack | 69.2 | 4663 | slower |
| kotlinx-json | 185 | 9363 | slower |
| moshi-codegen | 187 | 9363 | slower |

### php

**8 numbers** — not clearly slower: `json`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| json | 8.31 | 217 | fastest |
| rybakit-msgpack | 11.2 | 121 | slower |
| cbor | 55.6 | 121 | slower |
| protobuf | 68.4 | 91 | slower |

**32 numbers** — not clearly slower: `rybakit-msgpack`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| rybakit-msgpack | 20.5 | 339 | fastest |
| json | 24.9 | 654 | slower |
| cbor | 101 | 338 | slower |
| protobuf | 115 | 284 | slower |

**128 numbers** — not clearly slower: `rybakit-msgpack`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| rybakit-msgpack | 53.3 | 1203 | fastest |
| json | 87.9 | 2406 | slower |
| cbor | 270 | 1202 | slower |
| protobuf | 291 | 1052 | slower |

**512 numbers** — not clearly slower: `rybakit-msgpack`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| rybakit-msgpack | 185 | 4659 | fastest |
| json | 338 | 9380 | slower |
| cbor | 948 | 4659 | slower |
| protobuf | 1006 | 4124 | slower |

### zig

**8 numbers** — not clearly slower: `comptime-bin`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| comptime-bin | 0.34 | 107 | fastest |
| flatbuffers | 0.56 | 156 | slower |
| serde.msgpack | 0.62 | 124 | slower |
| protobuf | 0.82 | 94 | slower |
| serde.json | 1.44 | 220 | slower |
| std.json | 1.85 | 220 | slower |
| gld-kiln | 7.21 | 107 | slower |
| capnproto | 7.46 | 152 | slower |

**32 numbers** — not clearly slower: `comptime-bin`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| comptime-bin | 0.40 | 303 | fastest |
| flatbuffers | 0.74 | 348 | slower |
| serde.msgpack | 0.88 | 346 | slower |
| protobuf | 1.40 | 291 | slower |
| serde.json | 3.48 | 663 | slower |
| std.json | 4.01 | 663 | slower |
| gld-kiln | 7.43 | 303 | slower |
| capnproto | 8.76 | 344 | slower |

**128 numbers** — not clearly slower: `comptime-bin`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| comptime-bin | 0.61 | 1073 | fastest |
| flatbuffers | 0.94 | 1124 | slower |
| serde.msgpack | 1.42 | 1212 | slower |
| protobuf | 2.56 | 1061 | slower |
| gld-kiln | 7.75 | 1073 | slower |
| serde.json | 11.1 | 2407 | slower |
| capnproto | 11.3 | 1120 | slower |
| std.json | 12.8 | 2407 | slower |

**512 numbers** — not clearly slower: `comptime-bin`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| comptime-bin | 1.10 | 4140 | fastest |
| serde.msgpack | 3.54 | 4663 | slower |
| flatbuffers | 6.45 | 4188 | slower |
| protobuf | 7.11 | 4128 | slower |
| gld-kiln | 9.09 | 4140 | slower |
| capnproto | 19.2 | 4184 | slower |
| serde.json | 42.3 | 9363 | slower |
| std.json | 47.4 | 9363 | slower |

### mojo

**8 numbers** — not clearly slower: `gld-kiln`, `mojo-avro`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| gld-kiln | 2.03 | 107 | fastest |
| mojo-avro | 2.28 | 92 | similar |
| mojo-protobuf | 3.46 | 94 | slower |
| mojo-cbor | 3.51 | 124 | slower |
| mojo-json | 4.78 | 177 | slower |
| mojo-flatbuffers | 5.30 | 160 | slower |
| EmberJson | 7.62 | 220 | slower |
| ehsanmok-json | 15.2 | 220 | slower |
| mojo-toml | 39.9 | 227 | slower |

**32 numbers** — not clearly slower: `gld-kiln`. Small gap: `mojo-avro`.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| gld-kiln | 1.68 | 303 | fastest |
| mojo-avro | 2.49 | 288 | close |
| mojo-protobuf | 2.99 | 291 | slower |
| mojo-cbor | 3.48 | 345 | slower |
| mojo-flatbuffers | 4.23 | 352 | slower |
| mojo-json | 5.11 | 486 | slower |
| EmberJson | 8.21 | 663 | slower |
| ehsanmok-json | 18.8 | 663 | slower |
| mojo-toml | 70.4 | 694 | slower |

**128 numbers** — not clearly slower: `gld-kiln`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| gld-kiln | 3.02 | 1073 | fastest |
| mojo-avro | 4.52 | 1059 | slower |
| mojo-protobuf | 5.15 | 1061 | slower |
| mojo-cbor | 7.31 | 1211 | slower |
| mojo-flatbuffers | 7.70 | 1128 | slower |
| mojo-json | 13.3 | 1716 | slower |
| EmberJson | 18.7 | 2407 | slower |
| ehsanmok-json | 48.4 | 2407 | slower |
| mojo-toml | 228 | 2534 | slower |

**512 numbers** — not clearly slower: `gld-kiln`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| gld-kiln | 3.30 | 4140 | fastest |
| mojo-protobuf | 6.79 | 4128 | slower |
| mojo-flatbuffers | 9.73 | 4192 | slower |
| mojo-avro | 10.4 | 4126 | slower |
| mojo-cbor | 18.5 | 4663 | slower |
| mojo-json | 36.3 | 6621 | slower |
| EmberJson | 49.9 | 9363 | slower |
| ehsanmok-json | 145 | 9363 | slower |
| mojo-toml | 809 | 9874 | slower |

## What we saw

Read the **Rust** size curve. C sizes do **not** grow with the list, so C cannot answer this question on this machine.

In Rust, JSON is 234 bytes at 8 numbers (already over a 128-byte packet) and 672 bytes at 32 numbers (over a 512-byte packet). `postcard` and `prost` stay about half that size. They still fit a 512-byte packet at 32 numbers (about 286–290 bytes) and overflow it at 128 numbers (about 1051 bytes). MessagePack and CBOR sit between JSON and postcard.

C rows stay near 320–670 bytes at every list length. That is not a growing list of numbers on the wire. Do not quote those C sizes as a device answer.

## What this page is not

- It is not a ranking of languages.
- It is not the size of the library in flash memory.
- It is not battery use, and it is not a promise that your radio uses 128 or 512 bytes.
- C `nanopb` and `protobuf-wire` are not a full generated Google pack.

