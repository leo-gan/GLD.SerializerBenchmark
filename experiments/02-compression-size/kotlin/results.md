# Experiment 9 results — kotlin

**Date:** 2026-11-12
**Raw file:** `experiments/02-compression-size/kotlin/logs/kotlin/2026-11-12-163813.csv`
**Language:** kotlin
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 4.36.2 | 12.8 | 7.13 | 19.9 | 50 | 71 | Protocol Buffers | fastest | yes | 83 |
| moshi-codegen | 1.15.2 | 9.53 | 12.8 | 22.9 | 158 | 141 | JSON — fast writer fast named JSON | close | yes | 89 |
| msgpack | 0.9.12 | 35.8 | 41.8 | 80.5 | 114 | 118 | MessagePack | slower | yes | 88 |
| jackson | 2.22.4 | 31.5 | 48.4 | 83.6 | 158 | 141 | JSON — common default | slower | yes | 93 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| moshi-codegen | 1.15.2 | 19.8 | 20.9 | 41.4 | 411 | 281 | JSON — fast writer fast named JSON | fastest | yes | 92 |
| protobuf | 4.36.2 | 27.8 | 16.8 | 46.1 | 368 | 278 | Protocol Buffers | similar | yes | 91 |
| jackson | 2.22.4 | 44.5 | 66.4 | 111 | 411 | 281 | JSON — common default | slower | yes | 94 |
| msgpack | 0.9.12 | 61.0 | 64.9 | 128 | 346 | 274 | MessagePack | slower | yes | 94 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 4.36.2 | 44.7 | 27.9 | 73.5 | 1061 | 1080 | Protocol Buffers | fastest | yes | 92 |
| moshi-codegen | 1.15.2 | 36.7 | 61.0 | 96.9 | 2407 | 1317 | JSON — fast writer fast named JSON | slower | yes | 92 |
| msgpack | 0.9.12 | 62.7 | 70.0 | 135 | 1212 | 1172 | MessagePack | slower | yes | 92 |
| jackson | 2.22.4 | 76.1 | 125 | 204 | 2407 | 1317 | JSON — common default | slower | yes | 93 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `protobuf`. Small gap: `moshi-codegen`. Time/size front: `protobuf`.

**sample E (words), N = 1, memory** — not clearly slower: `moshi-codegen`, `protobuf`. Small gap: —. Time/size front: `moshi-codegen`, `protobuf`, `msgpack`.

**sample C (sensor), N = 1, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

