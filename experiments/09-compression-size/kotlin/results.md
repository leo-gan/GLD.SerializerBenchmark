# Experiment 9 results — kotlin

**Date:** 2026-10-11
**Raw file:** `experiments/09-compression-size/kotlin/logs/kotlin/2026-10-11-150556.csv`
**Language:** kotlin
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 4.35.0 | 14.8 | 7.46 | 23.3 | 50 | 71 | Protocol Buffers | fastest | yes | 89 |
| moshi-codegen | 1.15.2 | 10.0 | 13.5 | 23.3 | 158 | 141 | JSON — fast writer from Experiment 1 | close | yes | 89 |
| jackson | 2.19.0 | 34.9 | 47.0 | 81.8 | 158 | 141 | JSON — common default | slower | yes | 90 |
| msgpack | 0.9.8 | 39.6 | 45.6 | 85.9 | 114 | 118 | MessagePack | slower | yes | 91 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| moshi-codegen | 1.15.2 | 19.9 | 20.6 | 41.4 | 411 | 281 | JSON — fast writer from Experiment 1 | fastest | yes | 85 |
| protobuf | 4.35.0 | 30.0 | 17.2 | 46.8 | 368 | 278 | Protocol Buffers | close | yes | 89 |
| jackson | 2.19.0 | 44.3 | 65.9 | 108 | 411 | 281 | JSON — common default | slower | yes | 92 |
| msgpack | 0.9.8 | 58.0 | 70.1 | 129 | 346 | 274 | MessagePack | slower | yes | 93 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 4.35.0 | 48.9 | 27.6 | 75.4 | 1061 | 1080 | Protocol Buffers | fastest | yes | 92 |
| moshi-codegen | 1.15.2 | 40.4 | 69.1 | 109 | 2407 | 1317 | JSON — fast writer from Experiment 1 | slower | yes | 95 |
| msgpack | 0.9.8 | 71.7 | 95.1 | 166 | 1212 | 1172 | MessagePack | slower | yes | 93 |
| jackson | 2.19.0 | 89.5 | 148 | 242 | 2407 | 1317 | JSON — common default | slower | yes | 94 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `protobuf`. Small gap: `moshi-codegen`. Time/size front: `protobuf`.

**sample E (words), N = 1, memory** — not clearly slower: `moshi-codegen`. Small gap: `protobuf`. Time/size front: `moshi-codegen`, `protobuf`, `msgpack`.

**sample C (sensor), N = 1, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

