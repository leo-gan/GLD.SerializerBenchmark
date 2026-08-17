# Experiment 10 results — swift

**Date:** 2026-08-17
**Raw file:** `experiments/10-one-vs-hundred/swift/logs/swift/2026-08-17-110815.csv`
**Language:** swift
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SwiftProtobuf | 1.38.1 | 4.00 | 3.35 | 7.35 | 123 | — | Protocol Buffers | fastest | yes | 82 |
| IkigaJSON | 2.5.3 | 11.6 | 18.0 | 29.5 | 257 | — | JSON — fast writer from Experiment 1 | slower | yes | 81 |
| Foundation.JSONEncoder | Foundation | 14.7 | 17.0 | 31.6 | 257 | — | JSON — ships with Swift | slower | yes | 84 |
| SwiftMsgpack | 1.2.1 | 25.9 | 19.3 | 45.1 | 199 | — | MessagePack | slower | yes | 82 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SwiftProtobuf | 1.38.1 | 115 | 105 | 222 | 12477 | — | Protocol Buffers | fastest | yes | 78 |
| Foundation.JSONEncoder | Foundation | 666 | 767 | 1438 | 25746 | — | JSON — ships with Swift | slower | yes | 95 |
| IkigaJSON | 2.5.3 | 577 | 981 | 1559 | 25746 | — | JSON — fast writer from Experiment 1 | slower | yes | 94 |
| SwiftMsgpack | 1.2.1 | 1435 | 1282 | 2720 | 19848 | — | MessagePack | slower | yes | 89 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SwiftProtobuf | 1.38.1 | 1.85 | 1.84 | 3.71 | 50 | — | Protocol Buffers | fastest | yes | 89 |
| IkigaJSON | 2.5.3 | 7.75 | 11.9 | 19.6 | 168 | — | JSON — fast writer from Experiment 1 | slower | yes | 87 |
| Foundation.JSONEncoder | Foundation | 8.41 | 11.6 | 20.0 | 168 | — | JSON — ships with Swift | slower | yes | 81 |
| SwiftMsgpack | 1.2.1 | 15.2 | 10.0 | 25.3 | 124 | — | MessagePack | slower | yes | 83 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SwiftProtobuf | 1.38.1 | 28.4 | 27.8 | 56.4 | 4841 | — | Protocol Buffers | fastest | yes | 78 |
| Foundation.JSONEncoder | Foundation | 279 | 420 | 703 | 16546 | — | JSON — ships with Swift | slower | yes | 94 |
| IkigaJSON | 2.5.3 | 307 | 489 | 797 | 16546 | — | JSON — fast writer from Experiment 1 | slower | yes | 83 |
| SwiftMsgpack | 1.2.1 | 667 | 524 | 1191 | 12041 | — | MessagePack | slower | yes | 92 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample D (event), N = 1, memory** — not clearly slower: `SwiftProtobuf`. Small gap: —. Time/size front: `SwiftProtobuf`.

**sample D (event), N = 100, memory** — not clearly slower: `SwiftProtobuf`. Small gap: —. Time/size front: `SwiftProtobuf`.

**sample B (flat), N = 1, memory** — not clearly slower: `SwiftProtobuf`. Small gap: —. Time/size front: `SwiftProtobuf`.

**sample B (flat), N = 100, memory** — not clearly slower: `SwiftProtobuf`. Small gap: —. Time/size front: `SwiftProtobuf`.

