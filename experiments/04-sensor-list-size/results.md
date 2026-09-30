# When is JSON too big for a sensor?

**Question:** As a list of sensor numbers grows, when does JSON no longer fit a small radio packet?
**Date:** 2026-09-30
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
| protobuf | 91 | 284 | 1052 | 4124 | >128, >512 | Protocol Buffers |
| cbor | 120 | 337 | 1201 | 4658 | >128, >512 | CBOR |

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
| mojo-avro | 103 | 295 | 1071 | 4135 | >128, >512 | Avro |
| mojo-json | 186 | 491 | 1727 | 6627 | >128, >512 | JSON — mojo-json |
| mojo-cbor | 135 | 352 | 1223 | 4672 | >128, >512 | CBOR |
| EmberJson | 229 | 668 | 2419 | 9368 | >128, >512 | JSON — EmberJson |
| mojo-protobuf | 105 | 298 | 1073 | 4137 | >128, >512 | Protocol Buffers |
| mojo-flatbuffers | 176 | 368 | 1136 | 4200 | >128, >512 | FlatBuffers |
| ehsanmok-json | 229 | 668 | 2419 | 9368 | >128, >512 | JSON — ehsanmok/json |
| mojo-toml | 236 | 699 | 2546 | 9879 | >128, >512 | TOML |

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

**8 numbers** — not clearly slower: `moshi-codegen`, `protobuf`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| moshi-codegen | 52.2 | 220 | fastest |
| protobuf | 54.2 | 94 | similar |
| kotlinx-cbor | 77.5 | 127 | slower |
| kotlinx-json | 109 | 220 | slower |
| jackson-cbor | 137 | 125 | slower |
| msgpack | 157 | 124 | slower |

**32 numbers** — not clearly slower: `protobuf`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf | 27.3 | 291 | fastest |
| moshi-codegen | 40.8 | 663 | slower |
| kotlinx-cbor | 46.2 | 347 | slower |
| jackson-cbor | 71.4 | 346 | slower |
| kotlinx-json | 77.6 | 663 | slower |
| msgpack | 92.3 | 346 | slower |

**128 numbers** — not clearly slower: `protobuf`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf | 19.4 | 1061 | fastest |
| kotlinx-cbor | 33.0 | 1213 | slower |
| jackson-cbor | 54.5 | 1212 | slower |
| moshi-codegen | 56.4 | 2407 | slower |
| msgpack | 67.1 | 1212 | slower |
| kotlinx-json | 82.0 | 2407 | slower |

**512 numbers** — not clearly slower: `protobuf`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf | 25.3 | 4128 | fastest |
| kotlinx-cbor | 56.3 | 4664 | slower |
| jackson-cbor | 72.7 | 4664 | slower |
| msgpack | 78.0 | 4663 | slower |
| kotlinx-json | 168 | 9363 | slower |
| moshi-codegen | 169 | 9363 | slower |

### php

**8 numbers** — not clearly slower: `json`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| json | 7.66 | 217 | fastest |
| rybakit-msgpack | 11.1 | 121 | slower |
| protobuf | 65.9 | 91 | slower |
| cbor | 153 | 120 | slower |

**32 numbers** — not clearly slower: `rybakit-msgpack`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| rybakit-msgpack | 19.9 | 339 | fastest |
| json | 23.5 | 654 | slower |
| protobuf | 109 | 284 | slower |
| cbor | 441 | 337 | slower |

**128 numbers** — not clearly slower: `rybakit-msgpack`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| rybakit-msgpack | 53.3 | 1203 | fastest |
| json | 87.2 | 2406 | slower |
| protobuf | 288 | 1052 | slower |
| cbor | 1630 | 1201 | slower |

**512 numbers** — not clearly slower: `rybakit-msgpack`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| rybakit-msgpack | 173 | 4659 | fastest |
| json | 317 | 9380 | slower |
| protobuf | 940 | 4124 | slower |
| cbor | 6126 | 4658 | slower |

### zig

**8 numbers** — not clearly slower: `comptime-bin`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| comptime-bin | 0.24 | 107 | fastest |
| flatbuffers | 0.39 | 156 | slower |
| serde.msgpack | 0.59 | 124 | slower |
| protobuf | 0.61 | 94 | slower |
| serde.json | 1.16 | 220 | slower |
| std.json | 1.66 | 220 | slower |
| capnproto | 3.34 | 152 | slower |

**32 numbers** — not clearly slower: `comptime-bin`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| comptime-bin | 0.33 | 303 | fastest |
| flatbuffers | 0.49 | 348 | slower |
| protobuf | 1.12 | 291 | slower |
| serde.msgpack | 1.15 | 346 | slower |
| serde.json | 2.77 | 663 | slower |
| capnproto | 3.46 | 344 | slower |
| std.json | 3.65 | 663 | slower |

**128 numbers** — not clearly slower: `comptime-bin`. Small gap: `flatbuffers`.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| comptime-bin | 0.58 | 1073 | fastest |
| flatbuffers | 0.62 | 1124 | close |
| serde.msgpack | 1.98 | 1212 | slower |
| protobuf | 2.23 | 1061 | slower |
| capnproto | 3.77 | 1120 | slower |
| serde.json | 8.79 | 2407 | slower |
| std.json | 11.0 | 2407 | slower |

**512 numbers** — not clearly slower: `comptime-bin`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| comptime-bin | 1.61 | 4140 | fastest |
| serde.msgpack | 4.82 | 4663 | slower |
| capnproto | 4.93 | 4184 | slower |
| flatbuffers | 6.65 | 4188 | slower |
| protobuf | 6.94 | 4128 | slower |
| serde.json | 35.5 | 9363 | slower |
| std.json | 42.6 | 9363 | slower |

### mojo

**8 numbers** — not clearly slower: `mojo-avro`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| mojo-avro | 1.03 | 103 | fastest |
| mojo-json | 1.12 | 186 | slower |
| mojo-cbor | 1.53 | 135 | slower |
| EmberJson | 1.55 | 229 | slower |
| mojo-protobuf | 1.60 | 105 | slower |
| mojo-flatbuffers | 2.04 | 176 | slower |
| ehsanmok-json | 5.12 | 229 | slower |
| mojo-toml | 20.8 | 236 | slower |

**32 numbers** — not clearly slower: `mojo-avro`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| mojo-avro | 1.57 | 295 | fastest |
| mojo-cbor | 2.48 | 352 | slower |
| mojo-flatbuffers | 2.49 | 368 | slower |
| mojo-protobuf | 2.51 | 298 | slower |
| mojo-json | 2.55 | 491 | slower |
| EmberJson | 3.38 | 668 | slower |
| ehsanmok-json | 11.6 | 668 | slower |
| mojo-toml | 54.2 | 699 | slower |

**128 numbers** — not clearly slower: `mojo-avro`. Small gap: `mojo-flatbuffers`.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| mojo-avro | 3.26 | 1071 | fastest |
| mojo-flatbuffers | 3.29 | 1136 | close |
| mojo-protobuf | 5.05 | 1073 | slower |
| mojo-cbor | 5.67 | 1223 | slower |
| mojo-json | 7.95 | 1727 | slower |
| EmberJson | 10.3 | 2419 | slower |
| ehsanmok-json | 35.4 | 2419 | slower |
| mojo-toml | 181 | 2546 | slower |

**512 numbers** — not clearly slower: `mojo-flatbuffers`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| mojo-flatbuffers | 5.85 | 4200 | fastest |
| mojo-avro | 9.37 | 4135 | slower |
| mojo-protobuf | 13.6 | 4137 | slower |
| mojo-cbor | 17.4 | 4672 | slower |
| mojo-json | 29.1 | 6627 | slower |
| EmberJson | 39.5 | 9368 | slower |
| ehsanmok-json | 130 | 9368 | slower |
| mojo-toml | 681 | 9879 | slower |

## What we saw

Read the **Rust** size curve. C sizes do **not** grow with the list, so C cannot answer this question on this machine.

In Rust, JSON is 234 bytes at 8 numbers (already over a 128-byte packet) and 672 bytes at 32 numbers (over a 512-byte packet). `postcard` and `prost` stay about half that size. They still fit a 512-byte packet at 32 numbers (about 286–290 bytes) and overflow it at 128 numbers (about 1051 bytes). MessagePack and CBOR sit between JSON and postcard.

C rows stay near 320–670 bytes at every list length. That is not a growing list of numbers on the wire. Do not quote those C sizes as a device answer.

## What this page is not

- It is not a ranking of languages.
- It is not the size of the library in flash memory.
- It is not battery use, and it is not a promise that your radio uses 128 or 512 bytes.
- C `nanopb` and `protobuf-wire` are not a full generated Google pack.

