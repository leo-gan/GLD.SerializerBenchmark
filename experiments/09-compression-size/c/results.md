# Experiment 9 results — c

**Date:** 2026-09-30
**Raw file:** `experiments/09-compression-size/c/logs/c/2026-09-29-184456.csv`
**Language:** c
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 0.21 | 0.29 | 0.51 | 56 | 77 | Protocol Buffers — in-tree wire helper | fastest | yes | 90 |
| mpack | 1.1.1 | 0.46 | 1.17 | 1.64 | 128 | 127 | MessagePack | slower | yes | 87 |
| yyjson | 0.10.0 | 1.60 | 1.12 | 2.72 | 171 | 141 | JSON — fast writer from Experiment 1 | slower | yes | 97 |
| cJSON | 1.7.19 | 3.56 | 2.51 | 6.08 | 172 | 141 | JSON — common C library | slower | yes | 92 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 0.52 | 0.38 | 0.90 | 356 | 270 | Protocol Buffers — in-tree wire helper | fastest | yes | 93 |
| mpack | 1.1.1 | 0.59 | 1.37 | 1.97 | 334 | 264 | MessagePack | slower | yes | 90 |
| yyjson | 0.10.0 | 1.47 | 2.30 | 3.77 | 399 | 276 | JSON — fast writer from Experiment 1 | slower | yes | 87 |
| cJSON | 1.7.19 | 3.95 | 5.04 | 8.91 | 399 | 276 | JSON — common C library | slower | yes | 91 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 0.36 | 0.51 | 0.87 | 1181 | 1139 | Protocol Buffers — in-tree wire helper | fastest | yes | 80 |
| mpack | 1.1.1 | 0.90 | 2.56 | 3.45 | 1207 | 1166 | MessagePack | slower | yes | 90 |
| yyjson | 0.10.0 | 6.20 | 4.89 | 11.0 | 2409 | 1324 | JSON — fast writer from Experiment 1 | slower | yes | 85 |
| cJSON | 1.7.19 | 110 | 29.6 | 140 | 2446 | 1345 | JSON — common C library | slower | yes | 91 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| protobuf-wire | 1 | 0.47 | 0.52 | 0.98 | copied |
| mpack | 1 | 0.73 | 1.41 | 2.15 | copied |
| yyjson | 1 | 2.43 | 1.61 | 4.04 | real |
| cJSON | 1 | 4.12 | 2.76 | 6.91 | copied |
| protobuf-wire | 1 | 0.81 | 0.62 | 1.44 | copied |
| mpack | 1 | 0.88 | 1.80 | 2.68 | copied |
| yyjson | 1 | 2.61 | 3.04 | 5.68 | real |
| cJSON | 1 | 4.97 | 6.29 | 11.3 | copied |
| protobuf-wire | 1 | 0.72 | 0.77 | 1.51 | copied |
| mpack | 1 | 1.24 | 2.71 | 3.92 | copied |
| yyjson | 1 | 7.26 | 5.50 | 12.7 | real |
| cJSON | 1 | 109 | 31.4 | 140 | copied |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `protobuf-wire`. Small gap: —. Time/size front: `protobuf-wire`.

**sample E (words), N = 1, memory** — not clearly slower: `protobuf-wire`. Small gap: —. Time/size front: `protobuf-wire`, `mpack`.

**sample C (sensor), N = 1, memory** — not clearly slower: `protobuf-wire`. Small gap: —. Time/size front: `protobuf-wire`.

