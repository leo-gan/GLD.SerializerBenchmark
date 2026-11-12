# Experiment 4 results — c

**Date:** 2026-11-12
**Raw file:** `experiments/01-sensor-list-size/c/logs/c/2026-11-12-100604.csv`
**Language:** c
**Sample:** one sensor record (`telemetry`), list lengths 8, 32, 128, 512
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 8 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 0.23 | 0.27 | 0.49 | 105 | 741 | Protocol Buffers — in-tree wire helper | fastest | yes | 91 |
| nanopb | 0.4.9.2 | 0.25 | 0.29 | 0.55 | 105 | 741 | Protocol Buffers — nanopb (read the C page before quoting) | slower | yes | 96 |
| gld-kiln | 0.2.0 | 0.52 | 0.66 | 1.17 | 112 | 706 | positional binary — no field names | slower | yes | 91 |
| mpack | 1.1.1 | 0.47 | 1.14 | 1.61 | 129 | 768 | MessagePack | slower | yes | 92 |
| tinycbor | 0.6.1 | 0.64 | 1.72 | 2.34 | 129 | 766 | CBOR — Intel tinycbor | slower | yes | 87 |
| yyjson | 0.10.0 | 1.57 | 1.25 | 2.78 | 226 | 865 | JSON — fast writer fast named JSON | slower | yes | 94 |
| qcbor | 1.6.1 | 1.06 | 1.77 | 2.85 | 129 | 766 | CBOR — small-device writer | slower | yes | 96 |
| zcbor | 0.9 | 0.94 | 2.63 | 3.56 | 132 | 768 | CBOR — structured (zcbor) | slower | yes | 90 |
| cJSON | 1.7.19 | 9.67 | 3.47 | 13.2 | 226 | 874 | JSON — common C library | slower | yes | 96 |

## In memory — 32 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 0.27 | 0.28 | 0.56 | 317 | 741 | Protocol Buffers — in-tree wire helper | fastest | yes | 90 |
| nanopb | 0.4.9.2 | 0.30 | 0.34 | 0.64 | 317 | 741 | Protocol Buffers — nanopb (read the C page before quoting) | slower | yes | 87 |
| gld-kiln | 0.2.0 | 0.54 | 0.64 | 1.18 | 300 | 706 | positional binary — no field names | slower | yes | 85 |
| mpack | 1.1.1 | 0.58 | 1.38 | 1.97 | 343 | 768 | MessagePack | slower | yes | 92 |
| yyjson | 0.10.0 | 2.27 | 2.16 | 4.46 | 661 | 865 | JSON — fast writer fast named JSON | slower | yes | 89 |
| tinycbor | 0.6.1 | 0.78 | 7.35 | 8.16 | 342 | 766 | CBOR — Intel tinycbor | slower | yes | 93 |
| qcbor | 1.6.1 | 1.56 | 7.48 | 9.02 | 342 | 766 | CBOR — small-device writer | slower | yes | 88 |
| zcbor | 0.9 | 1.19 | 8.81 | 10.0 | 344 | 768 | CBOR — structured (zcbor) | slower | yes | 93 |
| cJSON | 1.7.19 | 28.3 | 7.38 | 35.6 | 667 | 874 | JSON — common C library | slower | yes | 89 |

## In memory — 128 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 0.38 | 0.49 | 0.88 | 1187 | 741 | Protocol Buffers — in-tree wire helper | fastest | yes | 84 |
| nanopb | 0.4.9.2 | 0.41 | 0.54 | 0.96 | 1187 | 741 | Protocol Buffers — nanopb (read the C page before quoting) | slower | yes | 85 |
| gld-kiln | 0.2.0 | 0.68 | 0.73 | 1.41 | 1074 | 706 | positional binary — no field names | slower | yes | 81 |
| mpack | 1.1.1 | 0.89 | 2.22 | 3.12 | 1213 | 768 | MessagePack | slower | yes | 85 |
| yyjson | 0.10.0 | 5.73 | 4.65 | 10.4 | 2418 | 865 | JSON — fast writer fast named JSON | slower | yes | 88 |
| tinycbor | 0.6.1 | 1.46 | 88.8 | 90.2 | 1212 | 766 | CBOR — Intel tinycbor | slower | yes | 91 |
| qcbor | 1.6.1 | 3.41 | 88.7 | 91.9 | 1212 | 766 | CBOR — small-device writer | slower | yes | 83 |
| zcbor | 0.9 | 2.04 | 99.2 | 102 | 1214 | 768 | CBOR — structured (zcbor) | slower | yes | 95 |
| cJSON | 1.7.19 | 107 | 27.7 | 135 | 2448 | 874 | JSON — common C library | slower | yes | 92 |

## In memory — 512 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 0.94 | 1.35 | 2.34 | 4640 | 741 | Protocol Buffers — in-tree wire helper | fastest | yes | 89 |
| nanopb | 0.4.9.2 | 0.97 | 1.37 | 2.38 | 4640 | 741 | Protocol Buffers — nanopb (read the C page before quoting) | similar | yes | 81 |
| gld-kiln | 0.2.0 | 1.90 | 1.57 | 3.48 | 4143 | 706 | positional binary — no field names | slower | yes | 86 |
| mpack | 1.1.1 | 2.43 | 6.11 | 8.63 | 4666 | 768 | MessagePack | slower | yes | 90 |
| yyjson | 0.10.0 | 19.9 | 15.7 | 35.8 | 9371 | 865 | JSON — fast writer fast named JSON | slower | yes | 93 |
| cJSON | 1.7.19 | 416 | 225 | 641 | 9482 | 874 | JSON — common C library | slower | yes | 91 |
| tinycbor | 0.6.1 | 4.48 | 1418 | 1422 | 4666 | 766 | CBOR — Intel tinycbor | slower | yes | 97 |
| qcbor | 1.6.1 | 11.2 | 1412 | 1423 | 4666 | 766 | CBOR — small-device writer | slower | yes | 93 |
| zcbor | 0.9 | 5.93 | 1550 | 1558 | 4667 | 768 | CBOR — structured (zcbor) | slower | yes | 93 |

## Stream call (side note)

| Library | Points | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|--------|------------|-----------|-------------------|---------------------------|
| yyjson | 8 | 1.09 | 0.84 | 1.93 | real |
| yyjson | 32 | 1.76 | 1.33 | 3.10 | real |
| yyjson | 128 | 4.93 | 3.94 | 8.88 | real |
| yyjson | 512 | 17.8 | 13.5 | 31.4 | real |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each list length. Size is the first number we care about.

**8 numbers, memory** — not clearly slower: `protobuf-wire`. Small gap: —. Time/size front: `protobuf-wire`.

**32 numbers, memory** — not clearly slower: `protobuf-wire`. Small gap: —. Time/size front: `protobuf-wire`, `gld-kiln`.

**128 numbers, memory** — not clearly slower: `protobuf-wire`. Small gap: —. Time/size front: `protobuf-wire`, `gld-kiln`.

**512 numbers, memory** — not clearly slower: `protobuf-wire`, `nanopb`. Small gap: —. Time/size front: `protobuf-wire`, `gld-kiln`.

