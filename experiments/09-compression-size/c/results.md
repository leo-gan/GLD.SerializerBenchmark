# Experiment 9 results — c

**Date:** 2026-08-17
**Raw file:** `experiments/09-compression-size/c/logs/c/2026-08-17-115904.csv`
**Language:** c
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 0.15 | 0.17 | 0.32 | 56 | 77 | Protocol Buffers — in-tree wire helper | fastest | yes | 94 |
| mpack | 1.1 | 0.31 | 0.77 | 1.07 | 128 | 127 | MessagePack | slower | yes | 93 |
| yyjson | 0.10.0 | 1.17 | 0.64 | 1.82 | 171 | 141 | JSON — fast writer from Experiment 1 | slower | yes | 94 |
| cJSON | 1.7.18 | 2.76 | 1.71 | 4.50 | 172 | 141 | JSON — common C library | slower | yes | 97 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 0.43 | 0.37 | 0.81 | 356 | 270 | Protocol Buffers — in-tree wire helper | fastest | yes | 93 |
| mpack | 1.1 | 0.50 | 1.33 | 1.84 | 334 | 264 | MessagePack | slower | yes | 92 |
| yyjson | 0.10.0 | 1.32 | 2.11 | 3.41 | 399 | 276 | JSON — fast writer from Experiment 1 | slower | yes | 88 |
| cJSON | 1.7.18 | 3.69 | 4.65 | 8.34 | 399 | 276 | JSON — common C library | slower | yes | 95 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 0.29 | 0.43 | 0.72 | 1181 | 1139 | Protocol Buffers — in-tree wire helper | fastest | yes | 91 |
| mpack | 1.1 | 0.74 | 2.01 | 2.74 | 1207 | 1166 | MessagePack | slower | yes | 92 |
| yyjson | 0.10.0 | 5.27 | 4.03 | 9.31 | 2409 | 1324 | JSON — fast writer from Experiment 1 | slower | yes | 90 |
| cJSON | 1.7.18 | 99.9 | 24.9 | 125 | 2446 | 1345 | JSON — common C library | slower | yes | 96 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| protobuf-wire | 1 | 0.39 | 0.38 | 0.76 | copied |
| mpack | 1 | 0.57 | 0.97 | 1.54 | copied |
| yyjson | 1 | 1.44 | 0.81 | 2.26 | copied |
| cJSON | 1 | 3.15 | 1.92 | 5.08 | copied |
| protobuf-wire | 1 | 0.71 | 0.57 | 1.28 | copied |
| mpack | 1 | 0.78 | 1.52 | 2.31 | copied |
| yyjson | 1 | 1.58 | 2.34 | 3.90 | copied |
| cJSON | 1 | 4.33 | 5.65 | 10.0 | copied |
| protobuf-wire | 1 | 0.62 | 0.67 | 1.28 | copied |
| mpack | 1 | 1.05 | 2.26 | 3.30 | copied |
| yyjson | 1 | 5.67 | 4.37 | 10.1 | copied |
| cJSON | 1 | 101 | 27.3 | 129 | copied |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `protobuf-wire`. Small gap: —. Time/size front: `protobuf-wire`.

**sample E (words), N = 1, memory** — not clearly slower: `protobuf-wire`. Small gap: —. Time/size front: `protobuf-wire`, `mpack`.

**sample C (sensor), N = 1, memory** — not clearly slower: `protobuf-wire`. Small gap: —. Time/size front: `protobuf-wire`.

