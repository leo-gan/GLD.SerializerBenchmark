# Experiment 10 results — java

**Date:** 2026-08-17
**Raw file:** `experiments/10-one-vs-hundred/java/logs/java/2026-08-17-110649.csv`
**Language:** java
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| jsoniter | 0.9.23 | 11.2 | 14.8 | 26.6 | 254 | — | JSON — fast writer from Experiment 1 | fastest | yes | 88 |
| protobuf | 4.28.3 | 6.66 | 21.4 | 28.8 | 123 | — | Protocol Buffers | similar | yes | 83 |
| msgpack | 0.9.8 | 24.8 | 26.4 | 51.7 | 196 | — | MessagePack | slower | yes | 88 |
| jackson | 2.18.3 | 23.4 | 30.5 | 57.9 | 254 | — | JSON — common default | slower | yes | 92 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| jsoniter | 0.9.23 | 69.9 | 103 | 171 | 25446 | — | JSON — fast writer from Experiment 1 | fastest | yes | 90 |
| protobuf | 4.28.3 | 70.0 | 125 | 194 | 12477 | — | Protocol Buffers | close | yes | 90 |
| jackson | 2.18.3 | 109 | 151 | 260 | 25446 | — | JSON — common default | slower | yes | 86 |
| msgpack | 0.9.8 | 198 | 225 | 424 | 19548 | — | MessagePack | slower | yes | 91 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 4.28.3 | 12.6 | 12.2 | 25.2 | 50 | — | Protocol Buffers | fastest | yes | 85 |
| jsoniter | 0.9.23 | 18.7 | 17.5 | 36.5 | 150 | — | JSON — fast writer from Experiment 1 | slower | yes | 90 |
| msgpack | 0.9.8 | 46.0 | 42.6 | 91.7 | 114 | — | MessagePack | slower | yes | 88 |
| jackson | 2.18.3 | 44.2 | 57.1 | 103 | 158 | — | JSON — common default | slower | yes | 93 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 4.28.3 | 43.4 | 73.2 | 116 | 4841 | — | Protocol Buffers | fastest | yes | 92 |
| jsoniter | 0.9.23 | 62.5 | 82.1 | 146 | 14804 | — | JSON — fast writer from Experiment 1 | slower | yes | 90 |
| jackson | 2.18.3 | 92.8 | 132 | 229 | 15546 | — | JSON — common default | slower | yes | 84 |
| msgpack | 0.9.8 | 143 | 127 | 275 | 11031 | — | MessagePack | slower | yes | 87 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample D (event), N = 1, memory** — not clearly slower: `jsoniter`, `protobuf`. Small gap: —. Time/size front: `jsoniter`, `protobuf`.

**sample D (event), N = 100, memory** — not clearly slower: `jsoniter`. Small gap: `protobuf`. Time/size front: `jsoniter`, `protobuf`.

**sample B (flat), N = 1, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

**sample B (flat), N = 100, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

