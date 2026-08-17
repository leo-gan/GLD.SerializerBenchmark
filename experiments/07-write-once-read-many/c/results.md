# Experiment 7 results — c

**Date:** 2026-08-17
**Raw file:** `experiments/07-write-once-read-many/c/logs/c/2026-08-17-114043.csv`
**Language:** c
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| flatcc | 0.6.1 | 0.47 | 0.12 | 0.59 | 236 | — | FlatBuffers — C | fastest | yes | 89 |
| protobuf-wire | wire-v2 | 0.53 | 0.27 | 0.80 | 166 | — | Protocol Buffers — wire helper | slower | yes | 89 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 0.52 | 1.06 | 1.58 | 4637 | — | Protocol Buffers — wire helper | fastest | yes | 89 |
| flatcc | 0.6.1 | 1.67 | 0.31 | 1.97 | 4164 | — | FlatBuffers — C | close | yes | 99 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| flatcc | 1 | 0.74 | 0.31 | 1.04 | copied |
| protobuf-wire | 1 | 0.77 | 0.46 | 1.24 | copied |
| flatcc | 1 | 1.47 | 0.53 | 2.03 | copied |
| protobuf-wire | 1 | 0.90 | 1.33 | 2.24 | copied |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `flatcc`. Small gap: —. Time/size front: `flatcc`, `protobuf-wire`.

**sample C (sensor), N = 1, memory** — not clearly slower: `protobuf-wire`. Small gap: `flatcc`. Time/size front: `protobuf-wire`, `flatcc`.

