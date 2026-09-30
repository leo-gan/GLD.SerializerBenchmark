# Experiment 7 results — c

**Date:** 2026-09-30
**Raw file:** `experiments/07-write-once-read-many/c/logs/c/2026-09-29-184359.csv`
**Language:** c
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| flatcc | 0.6.3 | 0.95 | 0.19 | 1.14 | 236 | 2096 | FlatBuffers — C | fastest | yes | 89 |
| protobuf-wire | wire-v2 | 0.77 | 0.50 | 1.26 | 166 | 2178 | Protocol Buffers — wire helper | slower | yes | 91 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 0.91 | 1.58 | 2.54 | 4637 | 2178 | Protocol Buffers — wire helper | fastest | yes | 93 |
| flatcc | 0.6.3 | 3.24 | 0.41 | 3.72 | 4164 | 2096 | FlatBuffers — C | slower | yes | 88 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| flatcc | 1 | 1.37 | 0.42 | 1.80 | copied |
| protobuf-wire | 1 | 1.11 | 0.75 | 1.86 | copied |
| protobuf-wire | 1 | 1.26 | 1.80 | 3.04 | copied |
| flatcc | 1 | 3.28 | 0.71 | 4.04 | copied |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `flatcc`. Small gap: —. Time/size front: `flatcc`, `protobuf-wire`.

**sample C (sensor), N = 1, memory** — not clearly slower: `protobuf-wire`. Small gap: —. Time/size front: `protobuf-wire`, `flatcc`.

