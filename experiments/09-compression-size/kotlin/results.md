# Experiment 9 results — kotlin

**Date:** 2026-08-28
**Raw file:** `experiments/09-compression-size/kotlin/logs/kotlin/2026-08-27-181751.csv`
**Language:** kotlin
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 4.28.3 | 13.3 | 7.41 | 20.5 | 50 | 71 | Protocol Buffers | fastest | yes | 92 |
| moshi-codegen | 1.15.2 | 10.2 | 13.0 | 23.5 | 158 | 141 | JSON — fast writer from Experiment 1 | similar | yes | 88 |
| jackson | 2.18.3 | 32.1 | 40.0 | 73.5 | 158 | 141 | JSON — common default | slower | yes | 87 |
| msgpack | 0.9.8 | 36.8 | 42.3 | 78.4 | 114 | 118 | MessagePack | slower | yes | 88 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| moshi-codegen | 1.15.2 | 18.8 | 19.1 | 38.2 | 411 | 281 | JSON — fast writer from Experiment 1 | fastest | yes | 88 |
| protobuf | 4.28.3 | 25.2 | 15.9 | 41.3 | 368 | 278 | Protocol Buffers | similar | yes | 87 |
| jackson | 2.18.3 | 39.4 | 61.4 | 106 | 411 | 281 | JSON — common default | slower | yes | 91 |
| msgpack | 0.9.8 | 52.6 | 64.9 | 121 | 346 | 274 | MessagePack | slower | yes | 92 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 4.28.3 | 35.9 | 23.8 | 59.2 | 1061 | 1080 | Protocol Buffers | fastest | yes | 93 |
| moshi-codegen | 1.15.2 | 35.6 | 63.8 | 102 | 2407 | 1317 | JSON — fast writer from Experiment 1 | slower | yes | 90 |
| msgpack | 0.9.8 | 73.1 | 95.0 | 170 | 1212 | 1172 | MessagePack | slower | yes | 96 |
| jackson | 2.18.3 | 72.3 | 125 | 199 | 2407 | 1317 | JSON — common default | slower | yes | 91 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `protobuf`, `moshi-codegen`. Small gap: —. Time/size front: `protobuf`.

**sample E (words), N = 1, memory** — not clearly slower: `moshi-codegen`, `protobuf`. Small gap: —. Time/size front: `moshi-codegen`, `protobuf`, `msgpack`.

**sample C (sensor), N = 1, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

