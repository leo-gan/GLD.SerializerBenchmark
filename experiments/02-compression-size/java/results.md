# Experiment 9 results — java

**Date:** 2026-11-12
**Raw file:** `experiments/02-compression-size/java/logs/java/2026-11-12-163754.csv`
**Language:** java
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| jsoniter | 0.9.23 | 12.2 | 11.2 | 23.5 | 150 | 136 | JSON — fast writer fast named JSON | fastest | yes | 87 |
| gld-kiln | 0.2.0 | 9.30 | 15.8 | 25.8 | 57 | 72 | positional binary — no field names | close | yes | 87 |
| protobuf | 4.36.2 | 18.9 | 11.2 | 30.2 | 50 | 71 | Protocol Buffers | slower | yes | 88 |
| msgpack | 0.9.12 | 28.2 | 25.9 | 52.2 | 114 | 118 | MessagePack | slower | yes | 86 |
| jackson | 2.22.4 | 24.0 | 29.3 | 52.9 | 158 | 141 | JSON — common default | slower | yes | 89 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| jsoniter | 0.9.23 | 15.1 | 15.4 | 31.2 | 411 | 281 | JSON — fast writer fast named JSON | fastest | yes | 86 |
| gld-kiln | 0.2.0 | 21.2 | 23.0 | 44.4 | 436 | 300 | positional binary — no field names | slower | yes | 84 |
| jackson | 2.22.4 | 27.5 | 31.5 | 58.3 | 411 | 281 | JSON — common default | slower | yes | 85 |
| protobuf | 4.36.2 | 36.9 | 21.1 | 58.5 | 368 | 278 | Protocol Buffers | slower | yes | 83 |
| msgpack | 0.9.12 | 43.4 | 28.6 | 73.8 | 346 | 274 | MessagePack | slower | yes | 84 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 20.5 | 28.8 | 50.0 | 1073 | 1089 | positional binary — no field names | fastest | yes | 89 |
| jsoniter | 0.9.23 | 28.8 | 38.7 | 68.5 | 1328 | 745 | JSON — fast writer fast named JSON | slower | yes | 88 |
| protobuf | 4.36.2 | 63.5 | 39.9 | 105 | 1061 | 1080 | Protocol Buffers | slower | yes | 87 |
| msgpack | 0.9.12 | 62.4 | 47.5 | 116 | 1212 | 1172 | MessagePack | slower | yes | 91 |
| jackson | 2.22.4 | 70.7 | 111 | 176 | 2407 | 1317 | JSON — common default | slower | yes | 89 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `jsoniter`. Small gap: `gld-kiln`. Time/size front: `jsoniter`, `gld-kiln`, `protobuf`.

**sample E (words), N = 1, memory** — not clearly slower: `jsoniter`. Small gap: —. Time/size front: `jsoniter`, `protobuf`, `msgpack`.

**sample C (sensor), N = 1, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `protobuf`.

