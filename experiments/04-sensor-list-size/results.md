# When is JSON too large for a sensor list?

**Question:** As the list of numbers grows, when does JSON’s size become more than a small radio packet can hold?
**Date:** 2026-08-16
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
| nanopb | 321 | 317 | 323 | 320 | >128, ≤512 | Protocol Buffers — nanopb (read the C page before quoting) |
| protobuf-wire | 321 | 317 | 323 | 320 | >128, ≤512 | Protocol Buffers — in-tree wire helper |
| mpack | 347 | 343 | 349 | 346 | >128, ≤512 | MessagePack |
| yyjson | 657 | 661 | 667 | 659 | >128, >512 | JSON — fast writer from Experiment 1 |
| tinycbor | 346 | 342 | 348 | 345 | >128, ≤512 | CBOR — Intel tinycbor |
| qcbor | 346 | 342 | 348 | 345 | >128, ≤512 | CBOR — small-device writer |
| zcbor | 348 | 344 | 350 | 347 | >128, ≤512 | CBOR — structured (zcbor) |
| cJSON | 663 | 667 | 678 | 656 | >128, >512 | JSON — common C library |

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
| nanopb | 0.30 | 321 | fastest |
| protobuf-wire | 0.30 | 321 | similar |
| mpack | 1.63 | 347 | slower |
| yyjson | 2.87 | 657 | slower |
| tinycbor | 6.61 | 346 | slower |
| qcbor | 7.31 | 346 | slower |
| zcbor | 7.87 | 348 | slower |
| cJSON | 26.0 | 663 | slower |

**32 numbers** — not clearly slower: `nanopb`, `protobuf-wire`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| nanopb | 0.29 | 317 | fastest |
| protobuf-wire | 0.30 | 317 | similar |
| mpack | 1.64 | 343 | slower |
| yyjson | 2.90 | 661 | slower |
| tinycbor | 6.77 | 342 | slower |
| qcbor | 7.46 | 342 | slower |
| zcbor | 8.01 | 344 | slower |
| cJSON | 27.3 | 667 | slower |

**128 numbers** — not clearly slower: `nanopb`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| nanopb | 0.29 | 323 | fastest |
| protobuf-wire | 0.31 | 323 | slower |
| mpack | 1.67 | 349 | slower |
| yyjson | 2.94 | 667 | slower |
| tinycbor | 6.80 | 348 | slower |
| qcbor | 7.38 | 348 | slower |
| zcbor | 8.03 | 350 | slower |
| cJSON | 28.1 | 678 | slower |

**512 numbers** — not clearly slower: `nanopb`. Small gap: —.

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| nanopb | 0.29 | 320 | fastest |
| protobuf-wire | 0.31 | 320 | slower |
| mpack | 1.66 | 346 | slower |
| yyjson | 2.95 | 659 | slower |
| tinycbor | 6.95 | 345 | slower |
| qcbor | 7.63 | 345 | slower |
| zcbor | 8.23 | 347 | slower |
| cJSON | 25.7 | 656 | slower |

## What we saw

Read the **Rust** size curve. C sizes do **not** grow with the list, so C cannot answer this question on this machine.

In Rust, JSON is 234 bytes at 8 numbers (already over a 128-byte packet) and 672 bytes at 32 numbers (over a 512-byte packet). `postcard` and `prost` stay about half that size. They still fit a 512-byte packet at 32 numbers (about 286–290 bytes) and overflow it at 128 numbers (about 1051 bytes). MessagePack and CBOR sit between JSON and postcard.

C rows stay near 320–670 bytes at every list length. That is not a growing list of numbers on the wire. Do not quote those C sizes as a device answer.

## What this page is not

- It is not a ranking of languages.
- It is not the size of the library in flash memory.
- It is not battery use, and it is not a promise that your radio uses 128 or 512 bytes.
- C `nanopb` and `protobuf-wire` are not a full generated Google pack.

