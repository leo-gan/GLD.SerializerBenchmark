# Experiment 4 results — c

**Date:** 2026-08-16
**Raw file:** `experiments/04-sensor-list-size/c/logs/c/2026-08-16-161218.csv`
**Language:** c
**Sample:** one sensor record (`telemetry`), list lengths 8, 32, 128, 512
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 8 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| nanopb | 0.4.9 | 0.14 | 0.15 | 0.30 | 321 | — | Protocol Buffers — nanopb (read the C page before quoting) | fastest | yes | 90 |
| protobuf-wire | wire-v2 | 0.14 | 0.16 | 0.30 | 321 | — | Protocol Buffers — in-tree wire helper | similar | yes | 85 |
| mpack | 1.1 | 0.32 | 1.30 | 1.63 | 347 | — | MessagePack | slower | yes | 91 |
| yyjson | 0.10.0 | 1.28 | 1.58 | 2.87 | 657 | — | JSON — fast writer from Experiment 1 | slower | yes | 94 |
| tinycbor | 0.6.0 | 0.49 | 6.14 | 6.61 | 346 | — | CBOR — Intel tinycbor | slower | yes | 90 |
| qcbor | 1.5.1 | 1.16 | 6.19 | 7.31 | 346 | — | CBOR — small-device writer | slower | yes | 94 |
| zcbor | 0.9 | 0.59 | 7.29 | 7.87 | 348 | — | CBOR — structured (zcbor) | slower | yes | 94 |
| cJSON | 1.7.18 | 21.2 | 4.78 | 26.0 | 663 | — | JSON — common C library | slower | yes | 87 |

## In memory — 32 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| nanopb | 0.4.9 | 0.13 | 0.16 | 0.29 | 317 | — | Protocol Buffers — nanopb (read the C page before quoting) | fastest | yes | 95 |
| protobuf-wire | wire-v2 | 0.14 | 0.16 | 0.30 | 317 | — | Protocol Buffers — in-tree wire helper | similar | yes | 91 |
| mpack | 1.1 | 0.34 | 1.30 | 1.64 | 343 | — | MessagePack | slower | yes | 98 |
| yyjson | 0.10.0 | 1.36 | 1.61 | 2.90 | 661 | — | JSON — fast writer from Experiment 1 | slower | yes | 92 |
| tinycbor | 0.6.0 | 0.50 | 6.28 | 6.77 | 342 | — | CBOR — Intel tinycbor | slower | yes | 96 |
| qcbor | 1.5.1 | 1.18 | 6.25 | 7.46 | 342 | — | CBOR — small-device writer | slower | yes | 92 |
| zcbor | 0.9 | 0.60 | 7.43 | 8.01 | 344 | — | CBOR — structured (zcbor) | slower | yes | 90 |
| cJSON | 1.7.18 | 22.3 | 5.01 | 27.3 | 667 | — | JSON — common C library | slower | yes | 93 |

## In memory — 128 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| nanopb | 0.4.9 | 0.13 | 0.16 | 0.29 | 323 | — | Protocol Buffers — nanopb (read the C page before quoting) | fastest | yes | 92 |
| protobuf-wire | wire-v2 | 0.14 | 0.16 | 0.31 | 323 | — | Protocol Buffers — in-tree wire helper | slower | yes | 94 |
| mpack | 1.1 | 0.34 | 1.34 | 1.67 | 349 | — | MessagePack | slower | yes | 95 |
| yyjson | 0.10.0 | 1.32 | 1.63 | 2.94 | 667 | — | JSON — fast writer from Experiment 1 | slower | yes | 93 |
| tinycbor | 0.6.0 | 0.49 | 6.31 | 6.80 | 348 | — | CBOR — Intel tinycbor | slower | yes | 94 |
| qcbor | 1.5.1 | 1.18 | 6.22 | 7.38 | 348 | — | CBOR — small-device writer | slower | yes | 90 |
| zcbor | 0.9 | 0.59 | 7.43 | 8.03 | 350 | — | CBOR — structured (zcbor) | slower | yes | 93 |
| cJSON | 1.7.18 | 22.9 | 5.06 | 28.1 | 678 | — | JSON — common C library | slower | yes | 93 |

## In memory — 512 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| nanopb | 0.4.9 | 0.13 | 0.17 | 0.29 | 320 | — | Protocol Buffers — nanopb (read the C page before quoting) | fastest | yes | 95 |
| protobuf-wire | wire-v2 | 0.15 | 0.16 | 0.31 | 320 | — | Protocol Buffers — in-tree wire helper | slower | yes | 91 |
| mpack | 1.1 | 0.35 | 1.34 | 1.66 | 346 | — | MessagePack | slower | yes | 96 |
| yyjson | 0.10.0 | 1.32 | 1.65 | 2.95 | 659 | — | JSON — fast writer from Experiment 1 | slower | yes | 96 |
| tinycbor | 0.6.0 | 0.50 | 6.46 | 6.95 | 345 | — | CBOR — Intel tinycbor | slower | yes | 95 |
| qcbor | 1.5.1 | 1.23 | 6.38 | 7.63 | 345 | — | CBOR — small-device writer | slower | yes | 93 |
| zcbor | 0.9 | 0.59 | 7.59 | 8.23 | 347 | — | CBOR — structured (zcbor) | slower | yes | 94 |
| cJSON | 1.7.18 | 20.5 | 5.12 | 25.7 | 656 | — | JSON — common C library | slower | yes | 96 |

## Stream call (side note)

| Library | Points | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|--------|------------|-----------|-------------------|---------------------------|
| nanopb | 8 | 0.31 | 0.32 | 0.62 | copied |
| protobuf-wire | 8 | 0.33 | 0.32 | 0.65 | copied |
| mpack | 8 | 0.53 | 0.97 | 1.50 | copied |
| yyjson | 8 | 1.52 | 1.26 | 2.77 | copied |
| tinycbor | 8 | 0.67 | 6.31 | 6.99 | copied |
| qcbor | 8 | 1.38 | 6.29 | 7.72 | copied |
| zcbor | 8 | 0.78 | 7.47 | 8.23 | copied |
| cJSON | 8 | 22.0 | 5.60 | 27.6 | copied |
| protobuf-wire | 32 | 0.33 | 0.33 | 0.65 | copied |
| nanopb | 32 | 0.33 | 0.33 | 0.66 | copied |
| mpack | 32 | 0.54 | 1.00 | 1.54 | copied |
| yyjson | 32 | 1.60 | 1.30 | 2.93 | copied |
| tinycbor | 32 | 0.71 | 6.42 | 7.12 | copied |
| qcbor | 32 | 1.43 | 6.44 | 7.88 | copied |
| zcbor | 32 | 0.82 | 7.60 | 8.46 | copied |
| cJSON | 32 | 22.9 | 5.81 | 28.8 | copied |
| nanopb | 128 | 0.33 | 0.33 | 0.66 | copied |
| protobuf-wire | 128 | 0.34 | 0.33 | 0.67 | copied |
| mpack | 128 | 0.55 | 1.02 | 1.57 | copied |
| yyjson | 128 | 1.60 | 1.32 | 2.94 | copied |
| tinycbor | 128 | 0.71 | 6.54 | 7.24 | copied |
| qcbor | 128 | 1.43 | 6.52 | 8.02 | copied |
| zcbor | 128 | 0.81 | 7.70 | 8.52 | copied |
| cJSON | 128 | 24.1 | 5.93 | 30.1 | copied |
| nanopb | 512 | 0.32 | 0.33 | 0.65 | copied |
| protobuf-wire | 512 | 0.34 | 0.33 | 0.66 | copied |
| mpack | 512 | 0.56 | 1.03 | 1.57 | copied |
| yyjson | 512 | 1.61 | 1.31 | 2.96 | copied |
| tinycbor | 512 | 0.72 | 6.67 | 7.38 | copied |
| qcbor | 512 | 1.44 | 6.65 | 8.12 | copied |
| zcbor | 512 | 0.81 | 7.74 | 8.55 | copied |
| cJSON | 512 | 21.3 | 5.91 | 27.2 | copied |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each list length. Size is the first number we care about.

**8 numbers, memory** — not clearly slower: `nanopb`, `protobuf-wire`. Small gap: —. Time/size front: `nanopb`, `protobuf-wire`.

**32 numbers, memory** — not clearly slower: `nanopb`, `protobuf-wire`. Small gap: —. Time/size front: `nanopb`.

**128 numbers, memory** — not clearly slower: `nanopb`. Small gap: —. Time/size front: `nanopb`.

**512 numbers, memory** — not clearly slower: `nanopb`. Small gap: —. Time/size front: `nanopb`.

