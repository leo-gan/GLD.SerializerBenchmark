# Experiment 4 results — c

**Date:** 2026-08-17
**Raw file:** `experiments/04-sensor-list-size/c/logs/c/2026-08-17-113556.csv`
**Language:** c
**Sample:** one sensor record (`telemetry`), list lengths 8, 32, 128, 512
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 8 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| nanopb | 0.4.9 | 0.12 | 0.15 | 0.27 | 105 | — | Protocol Buffers — nanopb (read the C page before quoting) | fastest | yes | 95 |
| protobuf-wire | wire-v2 | 0.12 | 0.15 | 0.27 | 105 | — | Protocol Buffers — in-tree wire helper | similar | yes | 95 |
| mpack | 1.1 | 0.26 | 0.85 | 1.12 | 129 | — | MessagePack | slower | yes | 91 |
| tinycbor | 0.6.0 | 0.38 | 1.08 | 1.46 | 129 | — | CBOR — Intel tinycbor | slower | yes | 89 |
| yyjson | 0.10.0 | 0.84 | 0.65 | 1.49 | 226 | — | JSON — fast writer from Experiment 1 | slower | yes | 91 |
| qcbor | 1.5.1 | 0.75 | 1.09 | 1.85 | 129 | — | CBOR — small-device writer | slower | yes | 93 |
| zcbor | 0.9 | 0.43 | 1.67 | 2.10 | 132 | — | CBOR — structured (zcbor) | slower | yes | 91 |
| cJSON | 1.7.18 | 6.75 | 1.93 | 8.66 | 226 | — | JSON — common C library | slower | yes | 92 |

## In memory — 32 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 0.15 | 0.25 | 0.40 | 317 | — | Protocol Buffers — in-tree wire helper | fastest | yes | 98 |
| nanopb | 0.4.9 | 0.15 | 0.25 | 0.40 | 317 | — | Protocol Buffers — nanopb (read the C page before quoting) | similar | yes | 97 |
| mpack | 1.1 | 0.36 | 1.47 | 1.84 | 343 | — | MessagePack | slower | yes | 99 |
| yyjson | 0.10.0 | 1.46 | 1.76 | 3.23 | 661 | — | JSON — fast writer from Experiment 1 | slower | yes | 89 |
| tinycbor | 0.6.0 | 0.59 | 6.02 | 6.60 | 342 | — | CBOR — Intel tinycbor | slower | yes | 97 |
| qcbor | 1.5.1 | 1.33 | 6.04 | 7.40 | 342 | — | CBOR — small-device writer | slower | yes | 96 |
| zcbor | 0.9 | 0.65 | 7.37 | 8.04 | 344 | — | CBOR — structured (zcbor) | slower | yes | 92 |
| cJSON | 1.7.18 | 23.9 | 5.53 | 29.5 | 667 | — | JSON — common C library | slower | yes | 93 |

## In memory — 128 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 0.23 | 0.41 | 0.64 | 1187 | — | Protocol Buffers — in-tree wire helper | fastest | yes | 95 |
| nanopb | 0.4.9 | 0.23 | 0.42 | 0.65 | 1187 | — | Protocol Buffers — nanopb (read the C page before quoting) | close | yes | 89 |
| mpack | 1.1 | 0.59 | 2.78 | 3.33 | 1213 | — | MessagePack | slower | yes | 93 |
| yyjson | 0.10.0 | 4.16 | 3.28 | 7.58 | 2418 | — | JSON — fast writer from Experiment 1 | slower | yes | 94 |
| tinycbor | 0.6.0 | 1.21 | 78.4 | 79.6 | 1212 | — | CBOR — Intel tinycbor | slower | yes | 95 |
| qcbor | 1.5.1 | 3.36 | 77.2 | 80.6 | 1212 | — | CBOR — small-device writer | slower | yes | 90 |
| zcbor | 0.9 | 1.36 | 86.5 | 88.2 | 1214 | — | CBOR — structured (zcbor) | slower | yes | 98 |
| cJSON | 1.7.18 | 92.5 | 23.9 | 117 | 2448 | — | JSON — common C library | slower | yes | 92 |

## In memory — 512 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 0.49 | 1.08 | 1.57 | 4640 | — | Protocol Buffers — in-tree wire helper | fastest | yes | 84 |
| nanopb | 0.4.9 | 0.59 | 1.15 | 1.76 | 4640 | — | Protocol Buffers — nanopb (read the C page before quoting) | slower | yes | 87 |
| mpack | 1.1 | 1.58 | 5.45 | 7.06 | 4666 | — | MessagePack | slower | yes | 91 |
| yyjson | 0.10.0 | 16.2 | 12.2 | 28.7 | 9371 | — | JSON — fast writer from Experiment 1 | slower | yes | 88 |
| cJSON | 1.7.18 | 370 | 209 | 579 | 9482 | — | JSON — common C library | slower | yes | 91 |
| tinycbor | 0.6.0 | 3.79 | 1191 | 1195 | 4666 | — | CBOR — Intel tinycbor | slower | yes | 88 |
| qcbor | 1.5.1 | 11.2 | 1198 | 1209 | 4666 | — | CBOR — small-device writer | slower | yes | 89 |
| zcbor | 0.9 | 4.00 | 1296 | 1302 | 4667 | — | CBOR — structured (zcbor) | slower | yes | 93 |

## Stream call (side note)

| Library | Points | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|--------|------------|-----------|-------------------|---------------------------|
| nanopb | 8 | 0.35 | 0.34 | 0.69 | copied |
| protobuf-wire | 8 | 0.36 | 0.33 | 0.70 | copied |
| mpack | 8 | 0.51 | 0.74 | 1.26 | copied |
| tinycbor | 8 | 0.60 | 1.28 | 1.88 | copied |
| yyjson | 8 | 1.09 | 0.83 | 1.92 | copied |
| qcbor | 8 | 1.00 | 1.30 | 2.31 | copied |
| zcbor | 8 | 0.68 | 1.86 | 2.55 | copied |
| cJSON | 8 | 7.17 | 2.28 | 9.45 | copied |
| protobuf-wire | 32 | 0.36 | 0.42 | 0.77 | copied |
| nanopb | 32 | 0.35 | 0.43 | 0.78 | copied |
| mpack | 32 | 0.58 | 1.04 | 1.62 | copied |
| yyjson | 32 | 1.71 | 1.43 | 3.18 | copied |
| tinycbor | 32 | 0.78 | 6.23 | 7.00 | copied |
| qcbor | 32 | 1.57 | 6.24 | 7.86 | copied |
| zcbor | 32 | 0.91 | 7.53 | 8.49 | copied |
| cJSON | 32 | 24.4 | 6.28 | 30.7 | copied |
| nanopb | 128 | 0.45 | 0.59 | 1.04 | copied |
| protobuf-wire | 128 | 0.46 | 0.58 | 1.05 | copied |
| mpack | 128 | 0.81 | 1.79 | 2.62 | copied |
| yyjson | 128 | 4.28 | 3.42 | 7.73 | copied |
| tinycbor | 128 | 1.41 | 76.1 | 77.4 | copied |
| qcbor | 128 | 3.62 | 75.9 | 80.1 | copied |
| zcbor | 128 | 1.58 | 83.6 | 85.7 | copied |
| cJSON | 128 | 93.4 | 26.1 | 119 | copied |
| protobuf-wire | 512 | 0.88 | 1.39 | 2.29 | copied |
| nanopb | 512 | 0.95 | 1.42 | 2.43 | copied |
| mpack | 512 | 2.02 | 5.19 | 7.37 | copied |
| yyjson | 512 | 16.3 | 12.7 | 29.0 | copied |
| cJSON | 512 | 377 | 214 | 593 | copied |
| tinycbor | 512 | 4.28 | 1212 | 1217 | copied |
| qcbor | 512 | 12.0 | 1206 | 1217 | copied |
| zcbor | 512 | 4.79 | 1306 | 1314 | copied |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each list length. Size is the first number we care about.

**8 numbers, memory** — not clearly slower: `nanopb`, `protobuf-wire`. Small gap: —. Time/size front: `nanopb`, `protobuf-wire`.

**32 numbers, memory** — not clearly slower: `protobuf-wire`, `nanopb`. Small gap: —. Time/size front: `protobuf-wire`.

**128 numbers, memory** — not clearly slower: `protobuf-wire`. Small gap: `nanopb`. Time/size front: `protobuf-wire`.

**512 numbers, memory** — not clearly slower: `protobuf-wire`. Small gap: —. Time/size front: `protobuf-wire`.

