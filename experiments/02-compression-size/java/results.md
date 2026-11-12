# Experiment 9 results — java

**Date:** 2026-11-12
**Raw file:** `experiments/02-compression-size/java/logs/java/2026-11-12-100815.csv`
**Language:** java
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 10.6 | 16.3 | 27.8 | 57 | 72 | positional binary — no field names | fastest | yes | 94 |
| jsoniter | 0.9.23 | 14.2 | 13.6 | 28.1 | 150 | 136 | JSON — fast writer fast named JSON | similar | yes | 93 |
| protobuf | 4.36.2 | 23.3 | 11.7 | 35.9 | 50 | 71 | Protocol Buffers | close | yes | 90 |
| msgpack | 0.9.12 | 29.6 | 25.4 | 53.1 | 114 | 118 | MessagePack | slower | yes | 88 |
| jackson | 2.22.4 | 25.2 | 29.4 | 54.7 | 158 | 141 | JSON — common default | slower | yes | 86 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| jsoniter | 0.9.23 | 19.3 | 22.4 | 39.9 | 411 | 281 | JSON — fast writer fast named JSON | fastest | yes | 92 |
| gld-kiln | 0.2.0 | 25.3 | 29.3 | 52.9 | 436 | 300 | positional binary — no field names | slower | yes | 91 |
| jackson | 2.22.4 | 30.6 | 36.0 | 67.4 | 411 | 281 | JSON — common default | slower | yes | 88 |
| msgpack | 0.9.12 | 48.9 | 32.9 | 84.3 | 346 | 274 | MessagePack | slower | yes | 86 |
| protobuf | 4.36.2 | 56.8 | 31.4 | 89.9 | 368 | 278 | Protocol Buffers | slower | yes | 93 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 19.9 | 26.3 | 46.5 | 1073 | 1089 | positional binary — no field names | fastest | yes | 93 |
| jsoniter | 0.9.23 | 29.1 | 36.6 | 65.9 | 1328 | 745 | JSON — fast writer fast named JSON | slower | yes | 95 |
| protobuf | 4.36.2 | 59.0 | 38.8 | 98.9 | 1061 | 1080 | Protocol Buffers | slower | yes | 93 |
| msgpack | 0.9.12 | 54.4 | 47.7 | 106 | 1212 | 1172 | MessagePack | slower | yes | 95 |
| jackson | 2.22.4 | 66.1 | 105 | 172 | 2407 | 1317 | JSON — common default | slower | yes | 86 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `gld-kiln`, `jsoniter`. Small gap: `protobuf`. Time/size front: `gld-kiln`, `protobuf`.

**sample E (words), N = 1, memory** — not clearly slower: `jsoniter`. Small gap: —. Time/size front: `jsoniter`, `msgpack`.

**sample C (sensor), N = 1, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `protobuf`.

