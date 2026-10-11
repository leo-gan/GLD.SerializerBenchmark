# Experiment 9 results — swift

**Date:** 2026-10-11
**Raw file:** `experiments/09-compression-size/swift/logs/swift/2026-10-11-150527.csv`
**Language:** swift
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SwiftProtobuf | 1.38.1 | 2.28 | 2.08 | 4.36 | 50 | 71 | Protocol Buffers | fastest | yes | 78 |
| IkigaJSON | 2.5.4 | 7.78 | 12.3 | 20.1 | 168 | 138 | JSON — fast writer from Experiment 1 | slower | yes | 79 |
| Foundation.JSONEncoder | Foundation | 8.88 | 12.5 | 21.4 | 168 | 140 | JSON — ships with Swift | slower | yes | 82 |
| SwiftMsgpack | 1.2.1 | 15.8 | 10.6 | 26.3 | 124 | 124 | MessagePack | slower | yes | 87 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SwiftProtobuf | 1.38.1 | 2.31 | 3.40 | 5.70 | 368 | 278 | Protocol Buffers | fastest | yes | 75 |
| IkigaJSON | 2.5.4 | 13.4 | 18.8 | 32.3 | 411 | 281 | JSON — fast writer from Experiment 1 | slower | yes | 72 |
| Foundation.JSONEncoder | Foundation | 19.7 | 16.5 | 36.3 | 411 | 281 | JSON — ships with Swift | slower | yes | 85 |
| SwiftMsgpack | 1.2.1 | 29.9 | 25.2 | 55.1 | 346 | 274 | MessagePack | slower | yes | 82 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SwiftProtobuf | 1.38.1 | 3.27 | 3.09 | 6.29 | 1061 | 1080 | Protocol Buffers | fastest | yes | 97 |
| IkigaJSON | 2.5.4 | 64.9 | 58.8 | 124 | 2407 | 1317 | JSON — fast writer from Experiment 1 | slower | yes | 91 |
| Foundation.JSONEncoder | Foundation | 74.4 | 61.2 | 136 | 2407 | 1319 | JSON — ships with Swift | slower | yes | 97 |
| SwiftMsgpack | 1.2.1 | 93.6 | 74.2 | 167 | 1212 | 1172 | MessagePack | slower | yes | 96 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `SwiftProtobuf`. Small gap: —. Time/size front: `SwiftProtobuf`.

**sample E (words), N = 1, memory** — not clearly slower: `SwiftProtobuf`. Small gap: —. Time/size front: `SwiftProtobuf`, `SwiftMsgpack`.

**sample C (sensor), N = 1, memory** — not clearly slower: `SwiftProtobuf`. Small gap: —. Time/size front: `SwiftProtobuf`.

