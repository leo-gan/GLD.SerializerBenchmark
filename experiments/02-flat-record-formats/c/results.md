# Experiment 2 results — c

**Date:** 2026-08-16
**Raw file:** `experiments/02-flat-record-formats/c/logs/c/2026-08-16-154213.csv`
**Language:** c
**Sample:** one flat record (`message`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-c | 1.5.0 | 0.11 | 0.10 | 0.21 | 51 | — | Protocol Buffers — protobuf-c (timed path is the suite wire codec) | fastest | yes | 97 |
| protobuf-wire | wire-v2 | 0.12 | 0.11 | 0.22 | 51 | — | Protocol Buffers — in-tree wire helper | close | yes | 96 |
| msgpack-c | 6.0.1 | 0.34 | 0.56 | 0.90 | 125 | — | MessagePack — official C library | slower | yes | 92 |
| mpack | 1.1 | 0.26 | 0.67 | 0.93 | 125 | — | MessagePack | slower | yes | 95 |
| yyjson | 0.10.0 | 0.83 | 0.41 | 1.24 | 170 | — | JSON — fast writer from Experiment 1 | slower | yes | 96 |
| cJSON | 1.7.18 | 2.15 | 1.18 | 3.34 | 170 | — | JSON — common C library | slower | yes | 93 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-c | 1.5.0 | 4.78 | 22.3 | 27.2 | 4932 | — | Protocol Buffers — protobuf-c (timed path is the suite wire codec) | fastest | yes | 90 |
| protobuf-wire | wire-v2 | 4.76 | 22.6 | 27.4 | 4932 | — | Protocol Buffers — in-tree wire helper | similar | yes | 89 |
| mpack | 1.1 | 10.6 | 45.3 | 55.8 | 12295 | — | MessagePack | slower | yes | 90 |
| msgpack-c | 6.0.1 | 18.2 | 40.0 | 58.0 | 12295 | — | MessagePack — official C library | slower | yes | 92 |
| yyjson | 0.10.0 | 53.7 | 48.8 | 103 | 16717 | — | JSON — fast writer from Experiment 1 | slower | yes | 92 |
| cJSON | 1.7.18 | 175 | 115 | 290 | 16741 | — | JSON — common C library | slower | yes | 95 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| protobuf-c | 1 | 0.33 | 0.28 | 0.60 | copied |
| protobuf-wire | 1 | 0.33 | 0.28 | 0.61 | copied |
| msgpack-c | 1 | 0.57 | 0.58 | 1.15 | copied |
| mpack | 1 | 0.49 | 0.70 | 1.21 | copied |
| yyjson | 1 | 1.04 | 0.57 | 1.62 | copied |
| cJSON | 1 | 2.43 | 1.39 | 3.83 | copied |
| protobuf-wire | 100 | 5.13 | 22.8 | 27.9 | copied |
| protobuf-c | 100 | 5.24 | 22.7 | 27.9 | copied |
| mpack | 100 | 11.2 | 45.2 | 56.4 | copied |
| msgpack-c | 100 | 18.7 | 40.1 | 58.8 | copied |
| yyjson | 100 | 53.9 | 49.3 | 103 | copied |
| cJSON | 100 | 176 | 116 | 293 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. Groups are computed **separately** for 1 record and for 100 records.

**N = 1, memory** — not clearly slower: `protobuf-c`. Small gap: `protobuf-wire`. Time/size front: `protobuf-c`.

**N = 100, memory** — not clearly slower: `protobuf-c`, `protobuf-wire`. Small gap: —. Time/size front: `protobuf-c`.

