# Experiment 4 results — c

**Date:** 2026-09-30
**Raw file:** `experiments/04-sensor-list-size/c/logs/c/2026-09-29-184151.csv`
**Language:** c
**Sample:** one sensor record (`telemetry`), list lengths 8, 32, 128, 512
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 8 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 0.18 | 0.24 | 0.43 | 105 | 741 | Protocol Buffers — in-tree wire helper | fastest | yes | 89 |
| nanopb | 0.4.9.2 | 0.21 | 0.25 | 0.46 | 105 | 741 | Protocol Buffers — nanopb (read the C page before quoting) | slower | yes | 86 |
| mpack | 1.1.1 | 0.42 | 0.94 | 1.37 | 129 | 768 | MessagePack | slower | yes | 92 |
| tinycbor | 0.6.0 | 0.57 | 1.55 | 2.13 | 129 | 766 | CBOR — Intel tinycbor | slower | yes | 96 |
| qcbor | 1.6.1 | 0.86 | 1.55 | 2.41 | 129 | 766 | CBOR — small-device writer | slower | yes | 94 |
| yyjson | 0.10.0 | 1.36 | 1.06 | 2.42 | 226 | 865 | JSON — fast writer from Experiment 1 | slower | yes | 90 |
| zcbor | 0.9 | 0.67 | 2.35 | 3.05 | 132 | 768 | CBOR — structured (zcbor) | slower | yes | 94 |
| cJSON | 1.7.19 | 8.66 | 3.31 | 11.9 | 226 | 874 | JSON — common C library | slower | yes | 96 |

## In memory — 32 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 0.23 | 0.31 | 0.53 | 317 | 741 | Protocol Buffers — in-tree wire helper | fastest | yes | 89 |
| nanopb | 0.4.9.2 | 0.25 | 0.32 | 0.56 | 317 | 741 | Protocol Buffers — nanopb (read the C page before quoting) | close | yes | 95 |
| mpack | 1.1.1 | 0.60 | 1.32 | 1.92 | 343 | 768 | MessagePack | slower | yes | 94 |
| yyjson | 0.10.0 | 2.22 | 2.01 | 4.26 | 661 | 865 | JSON — fast writer from Experiment 1 | slower | yes | 97 |
| tinycbor | 0.6.0 | 0.79 | 7.02 | 7.83 | 342 | 766 | CBOR — Intel tinycbor | slower | yes | 93 |
| qcbor | 1.6.1 | 1.44 | 7.03 | 8.49 | 342 | 766 | CBOR — small-device writer | slower | yes | 88 |
| zcbor | 0.9 | 0.93 | 8.30 | 9.25 | 344 | 768 | CBOR — structured (zcbor) | slower | yes | 95 |
| cJSON | 1.7.19 | 28.0 | 7.89 | 35.9 | 667 | 874 | JSON — common C library | slower | yes | 93 |

## In memory — 128 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 0.31 | 0.49 | 0.81 | 1187 | 741 | Protocol Buffers — in-tree wire helper | fastest | yes | 86 |
| nanopb | 0.4.9.2 | 0.33 | 0.49 | 0.82 | 1187 | 741 | Protocol Buffers — nanopb (read the C page before quoting) | similar | yes | 88 |
| mpack | 1.1.1 | 0.89 | 2.19 | 3.11 | 1213 | 768 | MessagePack | slower | yes | 86 |
| yyjson | 0.10.0 | 5.44 | 4.45 | 9.87 | 2418 | 865 | JSON — fast writer from Experiment 1 | slower | yes | 94 |
| tinycbor | 0.6.0 | 1.40 | 84.3 | 85.7 | 1212 | 766 | CBOR — Intel tinycbor | slower | yes | 90 |
| qcbor | 1.6.1 | 3.18 | 84.5 | 87.6 | 1212 | 766 | CBOR — small-device writer | slower | yes | 86 |
| zcbor | 0.9 | 1.89 | 90.2 | 92.2 | 1214 | 768 | CBOR — structured (zcbor) | slower | yes | 96 |
| cJSON | 1.7.19 | 103 | 27.7 | 131 | 2448 | 874 | JSON — common C library | slower | yes | 89 |

## In memory — 512 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 0.64 | 1.25 | 1.92 | 4640 | 741 | Protocol Buffers — in-tree wire helper | fastest | yes | 93 |
| nanopb | 0.4.9.2 | 0.67 | 1.46 | 2.13 | 4640 | 741 | Protocol Buffers — nanopb (read the C page before quoting) | close | yes | 92 |
| mpack | 1.1.1 | 2.45 | 6.40 | 8.97 | 4666 | 768 | MessagePack | slower | yes | 94 |
| yyjson | 0.10.0 | 18.7 | 14.1 | 32.9 | 9371 | 865 | JSON — fast writer from Experiment 1 | slower | yes | 95 |
| cJSON | 1.7.19 | 403 | 222 | 624 | 9482 | 874 | JSON — common C library | slower | yes | 97 |
| tinycbor | 0.6.0 | 4.43 | 1322 | 1326 | 4666 | 766 | CBOR — Intel tinycbor | slower | yes | 96 |
| qcbor | 1.6.1 | 10.3 | 1332 | 1342 | 4666 | 766 | CBOR — small-device writer | slower | yes | 92 |
| zcbor | 0.9 | 6.20 | 1452 | 1460 | 4667 | 768 | CBOR — structured (zcbor) | slower | yes | 99 |

## Stream call (side note)

| Library | Points | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|--------|------------|-----------|-------------------|---------------------------|
| protobuf-wire | 8 | 0.46 | 0.46 | 0.92 | copied |
| nanopb | 8 | 0.47 | 0.48 | 0.95 | copied |
| mpack | 8 | 0.71 | 1.21 | 1.93 | copied |
| tinycbor | 8 | 0.84 | 1.87 | 2.72 | copied |
| qcbor | 8 | 1.16 | 1.86 | 3.04 | copied |
| zcbor | 8 | 0.96 | 2.65 | 3.63 | copied |
| yyjson | 8 | 2.21 | 1.61 | 3.86 | real |
| cJSON | 8 | 9.41 | 3.84 | 13.3 | copied |
| protobuf-wire | 32 | 0.47 | 0.51 | 0.98 | copied |
| nanopb | 32 | 0.48 | 0.52 | 1.01 | copied |
| mpack | 32 | 0.82 | 1.57 | 2.40 | copied |
| yyjson | 32 | 3.31 | 2.59 | 5.89 | real |
| tinycbor | 32 | 1.03 | 7.34 | 8.38 | copied |
| qcbor | 32 | 1.69 | 7.34 | 9.03 | copied |
| zcbor | 32 | 1.23 | 8.50 | 9.79 | copied |
| cJSON | 32 | 29.0 | 8.72 | 37.6 | copied |
| protobuf-wire | 128 | 0.65 | 0.74 | 1.38 | copied |
| nanopb | 128 | 0.66 | 0.74 | 1.41 | copied |
| mpack | 128 | 1.20 | 2.44 | 3.67 | copied |
| yyjson | 128 | 6.64 | 5.00 | 11.7 | real |
| tinycbor | 128 | 1.75 | 84.4 | 86.4 | copied |
| qcbor | 128 | 3.50 | 84.4 | 87.8 | copied |
| zcbor | 128 | 2.19 | 90.1 | 92.6 | copied |
| cJSON | 128 | 104 | 30.4 | 134 | copied |
| protobuf-wire | 512 | 1.05 | 1.58 | 2.65 | copied |
| nanopb | 512 | 1.07 | 1.86 | 2.93 | copied |
| mpack | 512 | 2.79 | 6.55 | 9.49 | copied |
| yyjson | 512 | 20.4 | 15.1 | 35.6 | real |
| cJSON | 512 | 399 | 228 | 627 | copied |
| tinycbor | 512 | 4.78 | 1304 | 1308 | copied |
| qcbor | 512 | 10.7 | 1301 | 1313 | copied |
| zcbor | 512 | 6.18 | 1427 | 1434 | copied |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each list length. Size is the first number we care about.

**8 numbers, memory** — not clearly slower: `protobuf-wire`. Small gap: —. Time/size front: `protobuf-wire`.

**32 numbers, memory** — not clearly slower: `protobuf-wire`. Small gap: `nanopb`. Time/size front: `protobuf-wire`.

**128 numbers, memory** — not clearly slower: `protobuf-wire`, `nanopb`. Small gap: —. Time/size front: `protobuf-wire`.

**512 numbers, memory** — not clearly slower: `protobuf-wire`. Small gap: `nanopb`. Time/size front: `protobuf-wire`.

