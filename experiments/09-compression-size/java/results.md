# Experiment 9 results — java

**Date:** 2026-08-17
**Raw file:** `experiments/09-compression-size/java/logs/java/2026-08-17-115843.csv`
**Language:** java
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 4.28.3 | 5.62 | 7.30 | 13.0 | 50 | 71 | Protocol Buffers | fastest | yes | 81 |
| jsoniter | 0.9.23 | 7.90 | 7.55 | 15.6 | 150 | 136 | JSON — fast writer from Experiment 1 | slower | yes | 83 |
| jackson | 2.18.3 | 16.6 | 20.4 | 37.1 | 158 | 141 | JSON — common default | slower | yes | 86 |
| msgpack | 0.9.8 | 21.3 | 18.8 | 40.6 | 114 | 118 | MessagePack | slower | yes | 82 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| jsoniter | 0.9.23 | 13.3 | 13.5 | 28.2 | 411 | 281 | JSON — fast writer from Experiment 1 | fastest | yes | 90 |
| protobuf | 4.28.3 | 9.48 | 18.3 | 28.3 | 368 | 278 | Protocol Buffers | similar | yes | 84 |
| jackson | 2.18.3 | 23.7 | 26.4 | 53.5 | 411 | 281 | JSON — common default | slower | yes | 90 |
| msgpack | 0.9.8 | 35.0 | 26.9 | 65.1 | 346 | 274 | MessagePack | slower | yes | 84 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| jsoniter | 0.9.23 | 20.0 | 24.7 | 46.9 | 1328 | 745 | JSON — fast writer from Experiment 1 | fastest | yes | 87 |
| protobuf | 4.28.3 | 19.3 | 35.6 | 55.4 | 1061 | 1080 | Protocol Buffers | slower | yes | 90 |
| msgpack | 0.9.8 | 38.2 | 36.1 | 76.1 | 1212 | 1172 | MessagePack | slower | yes | 88 |
| jackson | 2.18.3 | 41.3 | 65.6 | 103 | 2407 | 1317 | JSON — common default | slower | yes | 82 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

**sample E (words), N = 1, memory** — not clearly slower: `jsoniter`, `protobuf`. Small gap: —. Time/size front: `jsoniter`, `protobuf`, `msgpack`.

**sample C (sensor), N = 1, memory** — not clearly slower: `jsoniter`. Small gap: —. Time/size front: `jsoniter`, `protobuf`.

