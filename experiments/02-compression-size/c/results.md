# Experiment 9 results — c

**Date:** 2026-11-12
**Raw file:** `experiments/02-compression-size/c/logs/c/2026-11-12-100839.csv`
**Language:** c
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 0.23 | 0.27 | 0.51 | 56 | 77 | Protocol Buffers — in-tree wire helper | fastest | yes | 93 |
| gld-kiln | 0.2.0 | 0.43 | 0.54 | 0.98 | 61 | 76 | positional binary — no field names | slower | yes | 92 |
| mpack | 1.1.1 | 0.44 | 1.06 | 1.50 | 128 | 127 | MessagePack | slower | yes | 92 |
| yyjson | 0.10.0 | 1.46 | 0.97 | 2.44 | 171 | 141 | JSON — fast writer fast named JSON | slower | yes | 93 |
| cJSON | 1.7.19 | 3.53 | 2.39 | 5.95 | 172 | 141 | JSON — common C library | slower | yes | 92 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 0.49 | 0.41 | 0.91 | 356 | 270 | Protocol Buffers — in-tree wire helper | fastest | yes | 87 |
| gld-kiln | 0.2.0 | 0.72 | 1.26 | 2.00 | 424 | 290 | positional binary — no field names | slower | yes | 85 |
| mpack | 1.1.1 | 0.62 | 1.50 | 2.15 | 334 | 264 | MessagePack | slower | yes | 92 |
| yyjson | 0.10.0 | 1.55 | 2.48 | 4.04 | 399 | 276 | JSON — fast writer fast named JSON | slower | yes | 84 |
| cJSON | 1.7.19 | 4.21 | 5.09 | 9.34 | 399 | 276 | JSON — common C library | slower | yes | 90 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 0.37 | 0.54 | 0.92 | 1181 | 1139 | Protocol Buffers — in-tree wire helper | fastest | yes | 84 |
| gld-kiln | 0.2.0 | 0.76 | 0.82 | 1.60 | 1068 | 1082 | positional binary — no field names | slower | yes | 88 |
| mpack | 1.1.1 | 0.90 | 2.37 | 3.30 | 1207 | 1166 | MessagePack | slower | yes | 84 |
| yyjson | 0.10.0 | 6.18 | 4.98 | 11.2 | 2409 | 1324 | JSON — fast writer fast named JSON | slower | yes | 82 |
| cJSON | 1.7.19 | 113 | 28.7 | 141 | 2446 | 1345 | JSON — common C library | slower | yes | 87 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| yyjson | 1 | 1.07 | 0.66 | 1.74 | real |
| yyjson | 1 | 1.19 | 1.87 | 3.06 | real |
| yyjson | 1 | 5.18 | 3.99 | 9.19 | real |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `protobuf-wire`. Small gap: —. Time/size front: `protobuf-wire`.

**sample E (words), N = 1, memory** — not clearly slower: `protobuf-wire`. Small gap: —. Time/size front: `protobuf-wire`, `mpack`.

**sample C (sensor), N = 1, memory** — not clearly slower: `protobuf-wire`. Small gap: —. Time/size front: `protobuf-wire`, `gld-kiln`.

