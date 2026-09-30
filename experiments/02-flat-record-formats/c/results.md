# Experiment 2 results — c

**Date:** 2026-09-30
**Raw file:** `experiments/02-flat-record-formats/c/logs/c/2026-09-29-184052.csv`
**Language:** c
**Sample:** one flat record (`message`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 0.18 | 0.21 | 0.39 | 51 | 2073 | Protocol Buffers — in-tree wire helper | fastest | yes | 83 |
| protobuf-c | 1.5.2 | 0.19 | 0.20 | 0.39 | 51 | 2073 | Protocol Buffers — protobuf-c (timed path is the suite wire codec) | similar | yes | 90 |
| msgpack-c | 6.0.1 | 0.52 | 0.80 | 1.32 | 125 | 2277 | MessagePack — official C library | slower | yes | 90 |
| mpack | 1.1.1 | 0.40 | 0.96 | 1.36 | 125 | 2277 | MessagePack | slower | yes | 95 |
| yyjson | 0.10.0 | 1.28 | 0.84 | 2.13 | 170 | 2499 | JSON — fast writer from Experiment 1 | slower | yes | 92 |
| cJSON | 1.7.19 | 3.09 | 2.11 | 5.21 | 170 | 2505 | JSON — common C library | slower | yes | 97 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-c | 1.5.2 | 5.47 | 36.2 | 41.6 | 4932 | 2073 | Protocol Buffers — protobuf-c (timed path is the suite wire codec) | fastest | yes | 87 |
| protobuf-wire | wire-v2 | 5.32 | 36.5 | 41.7 | 4932 | 2073 | Protocol Buffers — in-tree wire helper | similar | yes | 87 |
| mpack | 1.1.1 | 11.4 | 59.9 | 71.2 | 12295 | 2277 | MessagePack | slower | yes | 90 |
| msgpack-c | 6.0.1 | 19.2 | 54.8 | 74.1 | 12295 | 2277 | MessagePack — official C library | slower | yes | 85 |
| yyjson | 0.10.0 | 54.6 | 65.2 | 119 | 16717 | 2499 | JSON — fast writer from Experiment 1 | slower | yes | 86 |
| cJSON | 1.7.19 | 175 | 139 | 314 | 16741 | 2505 | JSON — common C library | slower | yes | 81 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| protobuf-wire | 1 | 0.42 | 0.38 | 0.81 | copied |
| protobuf-c | 1 | 0.42 | 0.39 | 0.81 | copied |
| msgpack-c | 1 | 0.75 | 0.97 | 1.72 | copied |
| mpack | 1 | 0.65 | 1.15 | 1.79 | copied |
| yyjson | 1 | 2.07 | 1.29 | 3.36 | real |
| cJSON | 1 | 3.43 | 2.28 | 5.75 | copied |
| protobuf-wire | 100 | 5.78 | 36.4 | 42.4 | copied |
| protobuf-c | 100 | 5.91 | 36.5 | 42.5 | copied |
| mpack | 100 | 11.9 | 59.3 | 71.4 | copied |
| msgpack-c | 100 | 19.8 | 54.4 | 74.3 | copied |
| yyjson | 100 | 94.8 | 92.3 | 188 | real |
| cJSON | 100 | 176 | 140 | 317 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. Groups are computed **separately** for 1 record and for 100 records.

**N = 1, memory** — not clearly slower: `protobuf-wire`, `protobuf-c`. Small gap: —. Time/size front: `protobuf-wire`.

**N = 100, memory** — not clearly slower: `protobuf-c`, `protobuf-wire`. Small gap: —. Time/size front: `protobuf-c`.

