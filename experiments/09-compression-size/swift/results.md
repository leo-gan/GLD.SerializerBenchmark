# Experiment 9 results — swift

**Date:** 2026-08-17
**Raw file:** `experiments/09-compression-size/swift/logs/swift/2026-08-17-115931.csv`
**Language:** swift
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SwiftProtobuf | 1.38.1 | 1.97 | 1.89 | 3.86 | 50 | 71 | Protocol Buffers | fastest | yes | 85 |
| IkigaJSON | 2.5.3 | 8.04 | 12.4 | 20.4 | 168 | 138 | JSON — fast writer from Experiment 1 | slower | yes | 89 |
| Foundation.JSONEncoder | Foundation | 9.07 | 12.5 | 21.6 | 168 | 138 | JSON — ships with Swift | slower | yes | 85 |
| SwiftMsgpack | 1.2.1 | 15.8 | 10.6 | 26.3 | 124 | 124 | MessagePack | slower | yes | 82 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SwiftProtobuf | 1.38.1 | 2.25 | 3.13 | 5.40 | 368 | 278 | Protocol Buffers | fastest | yes | 74 |
| IkigaJSON | 2.5.3 | 13.3 | 18.7 | 32.0 | 411 | 281 | JSON — fast writer from Experiment 1 | slower | yes | 72 |
| Foundation.JSONEncoder | Foundation | 19.8 | 16.4 | 36.2 | 411 | 281 | JSON — ships with Swift | slower | yes | 78 |
| SwiftMsgpack | 1.2.1 | 30.1 | 24.9 | 55.1 | 346 | 274 | MessagePack | slower | yes | 71 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SwiftProtobuf | 1.38.1 | 2.68 | 2.84 | 5.48 | 1061 | 1080 | Protocol Buffers | fastest | yes | 96 |
| IkigaJSON | 2.5.3 | 65.8 | 58.6 | 126 | 2407 | 1317 | JSON — fast writer from Experiment 1 | slower | yes | 94 |
| Foundation.JSONEncoder | Foundation | 74.8 | 61.3 | 136 | 2407 | 1317 | JSON — ships with Swift | slower | yes | 90 |
| SwiftMsgpack | 1.2.1 | 97.7 | 74.4 | 173 | 1212 | 1172 | MessagePack | slower | yes | 91 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `SwiftProtobuf`. Small gap: —. Time/size front: `SwiftProtobuf`.

**sample E (words), N = 1, memory** — not clearly slower: `SwiftProtobuf`. Small gap: —. Time/size front: `SwiftProtobuf`, `SwiftMsgpack`.

**sample C (sensor), N = 1, memory** — not clearly slower: `SwiftProtobuf`. Small gap: —. Time/size front: `SwiftProtobuf`.

