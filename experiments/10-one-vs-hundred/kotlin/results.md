# Experiment 10 results — kotlin

**Date:** 2026-08-28
**Raw file:** `experiments/10-one-vs-hundred/kotlin/logs/kotlin/2026-08-27-181757.csv`
**Language:** kotlin
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| moshi-codegen | 1.15.2 | 9.07 | 9.76 | 19.1 | 254 | 2474 | JSON — fast writer from Experiment 1 | fastest | yes | 88 |
| protobuf | 4.28.3 | 14.7 | 11.6 | 26.7 | 123 | 2150 | Protocol Buffers | slower | yes | 84 |
| jackson | 2.18.3 | 27.3 | 35.2 | 65.5 | 254 | 2474 | JSON — common default | slower | yes | 84 |
| msgpack | 0.9.8 | 31.1 | 35.2 | 66.8 | 196 | 2282 | MessagePack | slower | yes | 85 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 4.28.3 | 106 | 80.7 | 186 | 12477 | 2150 | Protocol Buffers | fastest | yes | 95 |
| moshi-codegen | 1.15.2 | 114 | 114 | 228 | 25446 | 2474 | JSON — fast writer from Experiment 1 | slower | yes | 90 |
| jackson | 2.18.3 | 99.8 | 220 | 322 | 25446 | 2474 | JSON — common default | slower | yes | 93 |
| msgpack | 0.9.8 | 146 | 264 | 413 | 19548 | 2282 | MessagePack | slower | yes | 89 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 4.28.3 | 22.8 | 12.1 | 35.0 | 50 | 2150 | Protocol Buffers | fastest | yes | 95 |
| moshi-codegen | 1.15.2 | 20.8 | 23.8 | 47.5 | 158 | 2474 | JSON — fast writer from Experiment 1 | slower | yes | 89 |
| msgpack | 0.9.8 | 60.0 | 73.3 | 132 | 114 | 2282 | MessagePack | slower | yes | 91 |
| jackson | 2.18.3 | 56.2 | 91.2 | 147 | 158 | 2474 | JSON — common default | slower | yes | 92 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 4.28.3 | 67.6 | 52.5 | 120 | 4841 | 2150 | Protocol Buffers | fastest | yes | 97 |
| moshi-codegen | 1.15.2 | 102 | 117 | 225 | 15546 | 2474 | JSON — fast writer from Experiment 1 | slower | yes | 94 |
| jackson | 2.18.3 | 112 | 228 | 338 | 15546 | 2474 | JSON — common default | slower | yes | 90 |
| msgpack | 0.9.8 | 153 | 226 | 388 | 11031 | 2282 | MessagePack | slower | yes | 92 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample D (event), N = 1, memory** — not clearly slower: `moshi-codegen`. Small gap: —. Time/size front: `moshi-codegen`, `protobuf`.

**sample D (event), N = 100, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

**sample B (flat), N = 1, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

**sample B (flat), N = 100, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

