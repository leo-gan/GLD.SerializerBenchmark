# When is JSON too large for a sensor list?

**Question:** As the list of numbers grows, when does JSON’s size become more than a small radio packet can hold?
**Date:** 2026-08-17
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

## What we saw

Read the **Rust** size curve. C sizes do **not** grow with the list, so C cannot answer this question on this machine.

In Rust, JSON is 234 bytes at 8 numbers (already over a 128-byte packet) and 672 bytes at 32 numbers (over a 512-byte packet). `postcard` and `prost` stay about half that size. They still fit a 512-byte packet at 32 numbers (about 286–290 bytes) and overflow it at 128 numbers (about 1051 bytes). MessagePack and CBOR sit between JSON and postcard.

C rows stay near 320–670 bytes at every list length. That is not a growing list of numbers on the wire. Do not quote those C sizes as a device answer.

## What this page is not

- It is not a ranking of languages.
- It is not the size of the library in flash memory.
- It is not battery use, and it is not a promise that your radio uses 128 or 512 bytes.
- C `nanopb` and `protobuf-wire` are not a full generated Google pack.

