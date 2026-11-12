# Experiment 9 results — swift

**Date:** 2026-11-12
**Raw file:** `experiments/02-compression-size/swift/logs/swift/2026-11-12-163820.csv`
**Language:** swift
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SwiftProtobuf | 1.38.1 | 2.50 | 2.16 | 4.64 | 50 | 71 | Protocol Buffers | fastest | yes | 86 |
| gld-kiln | 0.2.0 | 4.37 | 2.70 | 7.08 | 57 | 72 | positional binary — no field names | slower | yes | 87 |
| IkigaJSON | 2.5.4 | 8.40 | 13.1 | 21.5 | 168 | 138 | JSON — fast writer fast named JSON | slower | yes | 83 |
| Foundation.JSONEncoder | Foundation | 9.43 | 13.4 | 22.8 | 168 | 140 | JSON — ships with Swift | slower | yes | 75 |
| SwiftMsgpack | 1.2.1 | 16.8 | 11.4 | 28.3 | 124 | 124 | MessagePack | slower | yes | 82 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SwiftProtobuf | 1.38.1 | 2.45 | 3.46 | 5.94 | 368 | 278 | Protocol Buffers | fastest | yes | 79 |
| gld-kiln | 0.2.0 | 6.05 | 3.75 | 9.86 | 436 | 300 | positional binary — no field names | slower | yes | 86 |
| IkigaJSON | 2.5.4 | 13.8 | 19.6 | 33.6 | 411 | 281 | JSON — fast writer fast named JSON | slower | yes | 85 |
| Foundation.JSONEncoder | Foundation | 20.8 | 17.2 | 38.1 | 411 | 281 | JSON — ships with Swift | slower | yes | 88 |
| SwiftMsgpack | 1.2.1 | 31.3 | 25.9 | 57.0 | 346 | 274 | MessagePack | slower | yes | 85 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SwiftProtobuf | 1.38.1 | 6.18 | 5.43 | 11.7 | 1061 | 1080 | Protocol Buffers | fastest | yes | 87 |
| gld-kiln | 0.2.0 | 8.18 | 4.05 | 12.2 | 1073 | 1089 | positional binary — no field names | close | yes | 89 |
| IkigaJSON | 2.5.4 | 73.0 | 68.7 | 141 | 2407 | 1317 | JSON — fast writer fast named JSON | slower | yes | 93 |
| Foundation.JSONEncoder | Foundation | 83.7 | 70.8 | 155 | 2407 | 1320 | JSON — ships with Swift | slower | yes | 90 |
| SwiftMsgpack | 1.2.1 | 106 | 83.3 | 189 | 1212 | 1172 | MessagePack | slower | yes | 89 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `SwiftProtobuf`. Small gap: —. Time/size front: `SwiftProtobuf`.

**sample E (words), N = 1, memory** — not clearly slower: `SwiftProtobuf`. Small gap: —. Time/size front: `SwiftProtobuf`, `SwiftMsgpack`.

**sample C (sensor), N = 1, memory** — not clearly slower: `SwiftProtobuf`. Small gap: `gld-kiln`. Time/size front: `SwiftProtobuf`.

