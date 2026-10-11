# Experiment 10 results — kotlin

**Date:** 2026-10-11
**Raw file:** `experiments/10-one-vs-hundred/kotlin/logs/kotlin/2026-10-11-150723.csv`
**Language:** kotlin
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| moshi-codegen | 1.15.2 | 11.2 | 12.5 | 24.5 | 254 | 2474 | JSON — fast writer from Experiment 1 | fastest | yes | 90 |
| protobuf | 4.35.0 | 19.2 | 15.8 | 35.0 | 123 | 2150 | Protocol Buffers | slower | yes | 89 |
| msgpack | 0.9.8 | 35.0 | 43.4 | 78.5 | 196 | 2282 | MessagePack | slower | yes | 89 |
| jackson | 2.19.0 | 36.2 | 45.4 | 81.6 | 254 | 2474 | JSON — common default | slower | yes | 85 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 4.35.0 | 109 | 80.5 | 191 | 12477 | 2150 | Protocol Buffers | fastest | yes | 89 |
| moshi-codegen | 1.15.2 | 98.4 | 112 | 212 | 25446 | 2474 | JSON — fast writer from Experiment 1 | slower | yes | 88 |
| jackson | 2.19.0 | 88.6 | 204 | 300 | 25446 | 2474 | JSON — common default | slower | yes | 88 |
| msgpack | 0.9.8 | 133 | 247 | 390 | 19548 | 2282 | MessagePack | slower | yes | 85 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 4.35.0 | 20.9 | 12.0 | 32.9 | 50 | 2150 | Protocol Buffers | fastest | yes | 92 |
| moshi-codegen | 1.15.2 | 17.9 | 22.8 | 43.7 | 158 | 2474 | JSON — fast writer from Experiment 1 | slower | yes | 88 |
| msgpack | 0.9.8 | 49.1 | 65.6 | 111 | 114 | 2282 | MessagePack | slower | yes | 89 |
| jackson | 2.19.0 | 46.8 | 69.9 | 119 | 158 | 2474 | JSON — common default | slower | yes | 90 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 4.35.0 | 47.4 | 42.8 | 92.8 | 4841 | 2150 | Protocol Buffers | fastest | yes | 96 |
| moshi-codegen | 1.15.2 | 82.2 | 106 | 188 | 15546 | 2474 | JSON — fast writer from Experiment 1 | slower | yes | 91 |
| jackson | 2.19.0 | 94.8 | 164 | 264 | 15546 | 2474 | JSON — common default | slower | yes | 85 |
| msgpack | 0.9.8 | 124 | 154 | 274 | 11031 | 2282 | MessagePack | slower | yes | 86 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample D (event), N = 1, memory** — not clearly slower: `moshi-codegen`. Small gap: —. Time/size front: `moshi-codegen`, `protobuf`.

**sample D (event), N = 100, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

**sample B (flat), N = 1, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

**sample B (flat), N = 100, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

