# When is JSON too big for a sensor?

**Question:** As a list of sensor numbers grows, when does JSON no longer fit a small radio packet?
**Date:** 2026-10-11
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
| postcard | 91 | 286 | 1051 | 4128 | >128, >512 | postcard — compact Rust |
| prost | 94 | 290 | 1054 | 4131 | >128, >512 | Protocol Buffers |
| rmp-serde | 135 | 356 | 1216 | 4677 | >128, >512 | MessagePack |
| serde_json | 234 | 672 | 2420 | 9415 | >128, >512 | JSON — usual Rust library |
| sonic-rs | 234 | 672 | 2420 | 9415 | >128, >512 | JSON — fast writer from Experiment 1 |
| ciborium | 135 | 355 | 1215 | 4677 | >128, >512 | CBOR |

### c

| Library | 8 nums | 32 nums | 128 nums | 512 nums | vs 128 / 512 at 512 nums | Role |
|---------|--------|--------|--------|--------|--------------------------|------|
| protobuf-wire | 105 | 317 | 1187 | 4640 | >128, >512 | Protocol Buffers — in-tree wire helper |
| nanopb | 105 | 317 | 1187 | 4640 | >128, >512 | Protocol Buffers — nanopb (read the C page before quoting) |
| mpack | 129 | 343 | 1213 | 4666 | >128, >512 | MessagePack |
| tinycbor | 129 | 342 | 1212 | 4666 | >128, >512 | CBOR — Intel tinycbor |
| qcbor | 129 | 342 | 1212 | 4666 | >128, >512 | CBOR — small-device writer |
| yyjson | 226 | 661 | 2418 | 9371 | >128, >512 | JSON — fast writer from Experiment 1 |
| zcbor | 132 | 344 | 1214 | 4667 | >128, >512 | CBOR — structured (zcbor) |
| cJSON | 226 | 667 | 2448 | 9482 | >128, >512 | JSON — common C library |

### kotlin

| Library | 8 nums | 32 nums | 128 nums | 512 nums | vs 128 / 512 at 512 nums | Role |
|---------|--------|--------|--------|--------|--------------------------|------|
| moshi-codegen | 220 | 663 | 2407 | 9363 | >128, >512 | JSON — fast writer from Experiment 1 |
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
| capnproto | 152 | 344 | 1120 | 4184 | >128, >512 | Cap’n Proto |

### mojo

| Library | 8 nums | 32 nums | 128 nums | 512 nums | vs 128 / 512 at 512 nums | Role |
|---------|--------|--------|--------|--------|--------------------------|------|
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

**8 numbers** — not clearly slower: `postcard`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| postcard | 0.45 | 91 | fastest |
| prost | 0.60 | 94 | slower |
| rmp-serde | 0.98 | 135 | slower |
| serde_json | 1.47 | 234 | slower |
| sonic-rs | 1.53 | 234 | slower |
| ciborium | 1.57 | 135 | slower |

**32 numbers** — not clearly slower: `postcard`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| postcard | 0.61 | 286 | fastest |
| prost | 0.87 | 290 | slower |
| rmp-serde | 1.25 | 356 | slower |
| ciborium | 2.19 | 355 | slower |
| serde_json | 2.71 | 672 | slower |
| sonic-rs | 2.91 | 672 | slower |

**128 numbers** — not clearly slower: `postcard`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| postcard | 0.86 | 1051 | fastest |
| prost | 1.38 | 1054 | slower |
| rmp-serde | 1.73 | 1216 | slower |
| ciborium | 4.11 | 1215 | slower |
| serde_json | 6.88 | 2420 | slower |
| sonic-rs | 7.97 | 2420 | slower |

**512 numbers** — not clearly slower: `postcard`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| postcard | 1.85 | 4128 | fastest |
| prost | 2.86 | 4131 | slower |
| rmp-serde | 3.75 | 4677 | slower |
| ciborium | 11.6 | 4677 | slower |
| serde_json | 22.7 | 9415 | slower |
| sonic-rs | 27.8 | 9415 | slower |

### c

**8 numbers** — not clearly slower: `protobuf-wire`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf-wire | 0.43 | 105 | fastest |
| nanopb | 0.46 | 105 | slower |
| mpack | 1.37 | 129 | slower |
| tinycbor | 2.13 | 129 | slower |
| qcbor | 2.41 | 129 | slower |
| yyjson | 2.42 | 226 | slower |
| zcbor | 3.05 | 132 | slower |
| cJSON | 11.9 | 226 | slower |

**32 numbers** — not clearly slower: `protobuf-wire`. Small gap: `nanopb`.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf-wire | 0.53 | 317 | fastest |
| nanopb | 0.56 | 317 | close |
| mpack | 1.92 | 343 | slower |
| yyjson | 4.26 | 661 | slower |
| tinycbor | 7.83 | 342 | slower |
| qcbor | 8.49 | 342 | slower |
| zcbor | 9.25 | 344 | slower |
| cJSON | 35.9 | 667 | slower |

**128 numbers** — not clearly slower: `protobuf-wire`, `nanopb`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf-wire | 0.81 | 1187 | fastest |
| nanopb | 0.82 | 1187 | similar |
| mpack | 3.11 | 1213 | slower |
| yyjson | 9.87 | 2418 | slower |
| tinycbor | 85.7 | 1212 | slower |
| qcbor | 87.6 | 1212 | slower |
| zcbor | 92.2 | 1214 | slower |
| cJSON | 131 | 2448 | slower |

**512 numbers** — not clearly slower: `protobuf-wire`. Small gap: `nanopb`.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf-wire | 1.92 | 4640 | fastest |
| nanopb | 2.13 | 4640 | close |
| mpack | 8.97 | 4666 | slower |
| yyjson | 32.9 | 9371 | slower |
| cJSON | 624 | 9482 | slower |
| tinycbor | 1326 | 4666 | slower |
| qcbor | 1342 | 4666 | slower |
| zcbor | 1460 | 4667 | slower |

### kotlin

**8 numbers** — not clearly slower: `moshi-codegen`. Small gap: `protobuf`.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| moshi-codegen | 43.9 | 220 | fastest |
| protobuf | 56.2 | 94 | close |
| kotlinx-cbor | 67.8 | 127 | slower |
| kotlinx-json | 93.1 | 220 | slower |
| jackson-cbor | 123 | 125 | slower |
| msgpack | 131 | 124 | slower |

**32 numbers** — not clearly slower: `protobuf`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf | 30.0 | 291 | fastest |
| moshi-codegen | 42.1 | 663 | slower |
| kotlinx-cbor | 46.8 | 347 | slower |
| jackson-cbor | 73.6 | 346 | slower |
| kotlinx-json | 84.1 | 663 | slower |
| msgpack | 89.6 | 346 | slower |

**128 numbers** — not clearly slower: `protobuf`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf | 25.4 | 1061 | fastest |
| kotlinx-cbor | 34.9 | 1213 | slower |
| jackson-cbor | 54.5 | 1212 | slower |
| moshi-codegen | 55.5 | 2407 | slower |
| msgpack | 58.4 | 1212 | slower |
| kotlinx-json | 81.4 | 2407 | slower |

**512 numbers** — not clearly slower: `protobuf`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf | 21.0 | 4128 | fastest |
| kotlinx-cbor | 51.5 | 4664 | slower |
| jackson-cbor | 53.8 | 4664 | slower |
| msgpack | 62.8 | 4663 | slower |
| moshi-codegen | 168 | 9363 | slower |
| kotlinx-json | 172 | 9363 | slower |

### php

**8 numbers** — not clearly slower: `json`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| json | 8.07 | 217 | fastest |
| rybakit-msgpack | 10.7 | 121 | slower |
| cbor | 53.8 | 121 | slower |
| protobuf | 65.8 | 91 | slower |

**32 numbers** — not clearly slower: `rybakit-msgpack`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| rybakit-msgpack | 19.3 | 339 | fastest |
| json | 23.1 | 654 | slower |
| cbor | 95.1 | 338 | slower |
| protobuf | 109 | 284 | slower |

**128 numbers** — not clearly slower: `rybakit-msgpack`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| rybakit-msgpack | 50.8 | 1203 | fastest |
| json | 86.0 | 2406 | slower |
| cbor | 263 | 1202 | slower |
| protobuf | 282 | 1052 | slower |

**512 numbers** — not clearly slower: `rybakit-msgpack`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| rybakit-msgpack | 172 | 4659 | fastest |
| json | 321 | 9380 | slower |
| cbor | 901 | 4659 | slower |
| protobuf | 946 | 4124 | slower |

### zig

**8 numbers** — not clearly slower: `comptime-bin`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| comptime-bin | 0.28 | 107 | fastest |
| flatbuffers | 0.43 | 156 | slower |
| serde.msgpack | 0.59 | 124 | slower |
| protobuf | 0.71 | 94 | slower |
| serde.json | 1.28 | 220 | slower |
| std.json | 1.61 | 220 | slower |
| capnproto | 6.12 | 152 | slower |

**32 numbers** — not clearly slower: `comptime-bin`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| comptime-bin | 0.33 | 303 | fastest |
| flatbuffers | 0.55 | 348 | slower |
| serde.msgpack | 0.85 | 346 | slower |
| protobuf | 1.27 | 291 | slower |
| serde.json | 3.20 | 663 | slower |
| std.json | 3.67 | 663 | slower |
| capnproto | 7.02 | 344 | slower |

**128 numbers** — not clearly slower: `comptime-bin`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| comptime-bin | 0.50 | 1073 | fastest |
| flatbuffers | 0.72 | 1124 | slower |
| serde.msgpack | 1.37 | 1212 | slower |
| protobuf | 2.27 | 1061 | slower |
| capnproto | 8.88 | 1120 | slower |
| serde.json | 10.5 | 2407 | slower |
| std.json | 11.6 | 2407 | slower |

**512 numbers** — not clearly slower: `comptime-bin`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| comptime-bin | 0.98 | 4140 | fastest |
| serde.msgpack | 3.69 | 4663 | slower |
| flatbuffers | 5.74 | 4188 | slower |
| protobuf | 6.59 | 4128 | slower |
| capnproto | 17.4 | 4184 | slower |
| serde.json | 41.6 | 9363 | slower |
| std.json | 44.7 | 9363 | slower |

### mojo

**8 numbers** — not clearly slower: `mojo-avro`, `mojo-protobuf`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| mojo-avro | 2.46 | 92 | fastest |
| mojo-protobuf | 2.65 | 94 | similar |
| mojo-cbor | 3.10 | 124 | slower |
| mojo-json | 3.40 | 177 | slower |
| mojo-flatbuffers | 3.90 | 160 | slower |
| EmberJson | 6.01 | 220 | slower |
| ehsanmok-json | 12.3 | 220 | slower |
| mojo-toml | 32.7 | 227 | slower |

**32 numbers** — not clearly slower: `mojo-avro`, `mojo-protobuf`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| mojo-avro | 2.56 | 288 | fastest |
| mojo-protobuf | 2.57 | 291 | similar |
| mojo-cbor | 3.47 | 345 | slower |
| mojo-flatbuffers | 3.69 | 352 | slower |
| mojo-json | 4.44 | 486 | slower |
| EmberJson | 7.62 | 663 | slower |
| ehsanmok-json | 15.1 | 663 | slower |
| mojo-toml | 63.8 | 694 | slower |

**128 numbers** — not clearly slower: `mojo-protobuf`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| mojo-protobuf | 3.29 | 1061 | fastest |
| mojo-avro | 4.02 | 1059 | slower |
| mojo-flatbuffers | 4.34 | 1128 | slower |
| mojo-cbor | 5.82 | 1211 | slower |
| mojo-json | 9.89 | 1716 | slower |
| EmberJson | 14.9 | 2407 | slower |
| ehsanmok-json | 34.5 | 2407 | slower |
| mojo-toml | 185 | 2534 | slower |

**512 numbers** — not clearly slower: `mojo-protobuf`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| mojo-protobuf | 5.17 | 4128 | fastest |
| mojo-flatbuffers | 6.25 | 4192 | slower |
| mojo-avro | 9.49 | 4126 | slower |
| mojo-cbor | 15.5 | 4663 | slower |
| mojo-json | 31.4 | 6621 | slower |
| EmberJson | 44.0 | 9363 | slower |
| ehsanmok-json | 117 | 9363 | slower |
| mojo-toml | 686 | 9874 | slower |

## What we saw

Read the **Rust** size curve. C sizes do **not** grow with the list, so C cannot answer this question on this machine.

In Rust, JSON is 234 bytes at 8 numbers (already over a 128-byte packet) and 672 bytes at 32 numbers (over a 512-byte packet). `postcard` and `prost` stay about half that size. They still fit a 512-byte packet at 32 numbers (about 286–290 bytes) and overflow it at 128 numbers (about 1051 bytes). MessagePack and CBOR sit between JSON and postcard.

C rows stay near 320–670 bytes at every list length. That is not a growing list of numbers on the wire. Do not quote those C sizes as a device answer.

## What this page is not

- It is not a ranking of languages.
- It is not the size of the library in flash memory.
- It is not battery use, and it is not a promise that your radio uses 128 or 512 bytes.
- C `nanopb` and `protobuf-wire` are not a full generated Google pack.

