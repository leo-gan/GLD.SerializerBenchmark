# Experiment 9 results — swift

**Date:** 2026-11-12
**Raw file:** `experiments/02-compression-size/swift/logs/swift/2026-11-12-100943.csv`
**Language:** swift
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SwiftProtobuf | 1.38.1 | 2.46 | 2.09 | 4.56 | 50 | 71 | Protocol Buffers | fastest | yes | 87 |
| gld-kiln | 0.2.0 | 4.36 | 2.75 | 7.13 | 57 | 72 | positional binary — no field names | slower | yes | 91 |
| IkigaJSON | 2.5.4 | 8.23 | 12.7 | 20.9 | 168 | 138 | JSON — fast writer fast named JSON | slower | yes | 84 |
| Foundation.JSONEncoder | Foundation | 9.15 | 12.9 | 22.1 | 168 | 139 | JSON — ships with Swift | slower | yes | 85 |
| SwiftMsgpack | 1.2.1 | 16.7 | 11.0 | 28.1 | 124 | 124 | MessagePack | slower | yes | 87 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SwiftProtobuf | 1.38.1 | 2.42 | 3.42 | 5.85 | 368 | 278 | Protocol Buffers | fastest | yes | 82 |
| gld-kiln | 0.2.0 | 5.79 | 3.60 | 9.51 | 436 | 300 | positional binary — no field names | slower | yes | 84 |
| IkigaJSON | 2.5.4 | 13.5 | 19.2 | 32.8 | 411 | 281 | JSON — fast writer fast named JSON | slower | yes | 86 |
| Foundation.JSONEncoder | Foundation | 20.2 | 16.9 | 37.4 | 411 | 281 | JSON — ships with Swift | slower | yes | 89 |
| SwiftMsgpack | 1.2.1 | 30.3 | 25.5 | 55.8 | 346 | 274 | MessagePack | slower | yes | 88 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SwiftProtobuf | 1.38.1 | 5.93 | 4.85 | 10.8 | 1061 | 1080 | Protocol Buffers | fastest | yes | 97 |
| gld-kiln | 0.2.0 | 8.69 | 4.21 | 13.1 | 1073 | 1089 | positional binary — no field names | close | yes | 97 |
| IkigaJSON | 2.5.4 | 69.2 | 66.2 | 136 | 2407 | 1317 | JSON — fast writer fast named JSON | slower | yes | 98 |
| Foundation.JSONEncoder | Foundation | 81.3 | 68.5 | 149 | 2407 | 1318 | JSON — ships with Swift | slower | yes | 98 |
| SwiftMsgpack | 1.2.1 | 104 | 82.4 | 187 | 1212 | 1172 | MessagePack | slower | yes | 94 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `SwiftProtobuf`. Small gap: —. Time/size front: `SwiftProtobuf`.

**sample E (words), N = 1, memory** — not clearly slower: `SwiftProtobuf`. Small gap: —. Time/size front: `SwiftProtobuf`, `SwiftMsgpack`.

**sample C (sensor), N = 1, memory** — not clearly slower: `SwiftProtobuf`. Small gap: `gld-kiln`. Time/size front: `SwiftProtobuf`.

