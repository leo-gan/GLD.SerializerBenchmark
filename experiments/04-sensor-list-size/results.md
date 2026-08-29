# When is JSON too big for a sensor?

**Question:** As a list of sensor numbers grows, when does JSON no longer fit a small radio packet?
**Date:** 2026-08-29
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
| sonic-rs | 234 | 672 | 2420 | 9415 | >128, >512 | JSON — fast writer from Experiment 1 |
| ciborium | 135 | 355 | 1215 | 4677 | >128, >512 | CBOR |
| serde_json | 234 | 672 | 2420 | 9415 | >128, >512 | JSON — usual Rust library |

### c

| Library | 8 nums | 32 nums | 128 nums | 512 nums | vs 128 / 512 at 512 nums | Role |
|---------|--------|--------|--------|--------|--------------------------|------|
| nanopb | 105 | 317 | 1187 | 4640 | >128, >512 | Protocol Buffers — nanopb (read the C page before quoting) |
| protobuf-wire | 105 | 317 | 1187 | 4640 | >128, >512 | Protocol Buffers — in-tree wire helper |
| mpack | 129 | 343 | 1213 | 4666 | >128, >512 | MessagePack |
| tinycbor | 129 | 342 | 1212 | 4666 | >128, >512 | CBOR — Intel tinycbor |
| yyjson | 226 | 661 | 2418 | 9371 | >128, >512 | JSON — fast writer from Experiment 1 |
| qcbor | 129 | 342 | 1212 | 4666 | >128, >512 | CBOR — small-device writer |
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

## Time and groups, by list length

Write + read middle values in microseconds. Lower is better **inside that language**.

### rust

**8 numbers** — not clearly slower: `postcard`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| postcard | 0.21 | 91 | fastest |
| prost | 0.35 | 94 | slower |
| rmp-serde | 0.37 | 135 | slower |
| sonic-rs | 0.73 | 234 | slower |
| ciborium | 0.75 | 135 | slower |
| serde_json | 0.84 | 234 | slower |

**32 numbers** — not clearly slower: `postcard`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| postcard | 0.29 | 286 | fastest |
| prost | 0.50 | 290 | slower |
| rmp-serde | 0.61 | 356 | slower |
| ciborium | 1.14 | 355 | slower |
| sonic-rs | 1.58 | 672 | slower |
| serde_json | 1.67 | 672 | slower |

**128 numbers** — not clearly slower: `postcard`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| postcard | 0.51 | 1051 | fastest |
| prost | 0.77 | 1054 | slower |
| rmp-serde | 1.16 | 1216 | slower |
| ciborium | 2.79 | 1215 | slower |
| sonic-rs | 5.05 | 2420 | slower |
| serde_json | 5.22 | 2420 | slower |

**512 numbers** — not clearly slower: `postcard`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| postcard | 1.18 | 4128 | fastest |
| prost | 1.58 | 4131 | slower |
| rmp-serde | 3.05 | 4677 | slower |
| ciborium | 8.78 | 4677 | slower |
| serde_json | 18.2 | 9415 | slower |
| sonic-rs | 18.5 | 9415 | slower |

### c

**8 numbers** — not clearly slower: `nanopb`, `protobuf-wire`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| nanopb | 0.27 | 105 | fastest |
| protobuf-wire | 0.27 | 105 | similar |
| mpack | 1.12 | 129 | slower |
| tinycbor | 1.46 | 129 | slower |
| yyjson | 1.49 | 226 | slower |
| qcbor | 1.85 | 129 | slower |
| zcbor | 2.10 | 132 | slower |
| cJSON | 8.66 | 226 | slower |

**32 numbers** — not clearly slower: `protobuf-wire`, `nanopb`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf-wire | 0.40 | 317 | fastest |
| nanopb | 0.40 | 317 | similar |
| mpack | 1.84 | 343 | slower |
| yyjson | 3.23 | 661 | slower |
| tinycbor | 6.60 | 342 | slower |
| qcbor | 7.40 | 342 | slower |
| zcbor | 8.04 | 344 | slower |
| cJSON | 29.5 | 667 | slower |

**128 numbers** — not clearly slower: `protobuf-wire`. Small gap: `nanopb`.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf-wire | 0.64 | 1187 | fastest |
| nanopb | 0.65 | 1187 | close |
| mpack | 3.33 | 1213 | slower |
| yyjson | 7.58 | 2418 | slower |
| tinycbor | 79.6 | 1212 | slower |
| qcbor | 80.6 | 1212 | slower |
| zcbor | 88.2 | 1214 | slower |
| cJSON | 117 | 2448 | slower |

**512 numbers** — not clearly slower: `protobuf-wire`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf-wire | 1.57 | 4640 | fastest |
| nanopb | 1.76 | 4640 | slower |
| mpack | 7.06 | 4666 | slower |
| yyjson | 28.7 | 9371 | slower |
| cJSON | 579 | 9482 | slower |
| tinycbor | 1195 | 4666 | slower |
| qcbor | 1209 | 4666 | slower |
| zcbor | 1302 | 4667 | slower |

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

## What we saw

Read the **Rust** size curve. C sizes do **not** grow with the list, so C cannot answer this question on this machine.

In Rust, JSON is 234 bytes at 8 numbers (already over a 128-byte packet) and 672 bytes at 32 numbers (over a 512-byte packet). `postcard` and `prost` stay about half that size. They still fit a 512-byte packet at 32 numbers (about 286–290 bytes) and overflow it at 128 numbers (about 1051 bytes). MessagePack and CBOR sit between JSON and postcard.

C rows stay near 320–670 bytes at every list length. That is not a growing list of numbers on the wire. Do not quote those C sizes as a device answer.

## What this page is not

- It is not a ranking of languages.
- It is not the size of the library in flash memory.
- It is not battery use, and it is not a promise that your radio uses 128 or 512 bytes.
- C `nanopb` and `protobuf-wire` are not a full generated Google pack.

