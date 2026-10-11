# Experiment 10 results — swift

**Date:** 2026-10-11
**Raw file:** `experiments/10-one-vs-hundred/swift/logs/swift/2026-10-11-150632.csv`
**Language:** swift
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SwiftProtobuf | 1.38.1 | 4.74 | 3.78 | 8.54 | 123 | 2150 | Protocol Buffers | fastest | yes | 79 |
| IkigaJSON | 2.5.4 | 10.9 | 17.5 | 28.3 | 257 | 2492 | JSON — fast writer from Experiment 1 | slower | yes | 85 |
| Foundation.JSONEncoder | Foundation | 14.3 | 15.8 | 30.1 | 257 | 2493 | JSON — ships with Swift | slower | yes | 80 |
| SwiftMsgpack | 1.2.1 | 24.9 | 18.9 | 43.8 | 199 | 2302 | MessagePack | slower | yes | 84 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SwiftProtobuf | 1.38.1 | 128 | 115 | 244 | 12477 | 2150 | Protocol Buffers | fastest | yes | 84 |
| Foundation.JSONEncoder | Foundation | 651 | 755 | 1411 | 25746 | 2493 | JSON — ships with Swift | slower | yes | 97 |
| IkigaJSON | 2.5.4 | 568 | 958 | 1524 | 25746 | 2492 | JSON — fast writer from Experiment 1 | slower | yes | 93 |
| SwiftMsgpack | 1.2.1 | 1397 | 1229 | 2628 | 19848 | 2302 | MessagePack | slower | yes | 95 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SwiftProtobuf | 1.38.1 | 2.27 | 2.05 | 4.32 | 50 | 2150 | Protocol Buffers | fastest | yes | 77 |
| IkigaJSON | 2.5.4 | 7.85 | 12.1 | 20.1 | 168 | 2492 | JSON — fast writer from Experiment 1 | slower | yes | 82 |
| Foundation.JSONEncoder | Foundation | 8.67 | 12.2 | 20.9 | 168 | 2493 | JSON — ships with Swift | slower | yes | 76 |
| SwiftMsgpack | 1.2.1 | 16.2 | 10.8 | 27.0 | 124 | 2302 | MessagePack | slower | yes | 85 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SwiftProtobuf | 1.38.1 | 30.2 | 28.7 | 59.2 | 4841 | 2150 | Protocol Buffers | fastest | yes | 84 |
| Foundation.JSONEncoder | Foundation | 267 | 406 | 679 | 16546 | 2493 | JSON — ships with Swift | slower | yes | 95 |
| IkigaJSON | 2.5.4 | 296 | 472 | 770 | 16546 | 2492 | JSON — fast writer from Experiment 1 | slower | yes | 97 |
| SwiftMsgpack | 1.2.1 | 641 | 500 | 1144 | 12041 | 2302 | MessagePack | slower | yes | 93 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample D (event), N = 1, memory** — not clearly slower: `SwiftProtobuf`. Small gap: —. Time/size front: `SwiftProtobuf`.

**sample D (event), N = 100, memory** — not clearly slower: `SwiftProtobuf`. Small gap: —. Time/size front: `SwiftProtobuf`.

**sample B (flat), N = 1, memory** — not clearly slower: `SwiftProtobuf`. Small gap: —. Time/size front: `SwiftProtobuf`.

**sample B (flat), N = 100, memory** — not clearly slower: `SwiftProtobuf`. Small gap: —. Time/size front: `SwiftProtobuf`.

