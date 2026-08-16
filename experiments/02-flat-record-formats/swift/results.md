# Experiment 2 results — swift

**Date:** 2026-08-16
**Raw file:** `experiments/02-flat-record-formats/swift/logs/swift/2026-08-16-154240.csv`
**Language:** swift
**Sample:** one flat record (`message`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SwiftProtobuf | 1.38.1 | 1.83 | 1.77 | 3.61 | 50 | — | Protocol Buffers | fastest | yes | 87 |
| IkigaJSON | 2.5.3 | 7.50 | 11.8 | 19.3 | 168 | — | JSON — fast writer from Experiment 1 | slower | yes | 89 |
| Foundation.JSONEncoder | Foundation | 8.44 | 11.6 | 20.0 | 168 | — | JSON — ships with Swift | slower | yes | 84 |
| SwiftMsgpack | 1.2.1 | 15.0 | 10.4 | 25.4 | 124 | — | MessagePack | slower | yes | 86 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SwiftProtobuf | 1.38.1 | 25.7 | 24.8 | 51.4 | 4841 | — | Protocol Buffers | fastest | yes | 78 |
| Foundation.JSONEncoder | Foundation | 263 | 402 | 668 | 16546 | — | JSON — ships with Swift | slower | yes | 95 |
| IkigaJSON | 2.5.3 | 290 | 461 | 752 | 16546 | — | JSON — fast writer from Experiment 1 | slower | yes | 90 |
| SwiftMsgpack | 1.2.1 | 633 | 498 | 1132 | 12041 | — | MessagePack | slower | yes | 95 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| SwiftProtobuf | 1 | 6.90 | 2.99 | 9.88 | copied |
| IkigaJSON | 1 | 20.3 | 13.4 | 33.7 | copied |
| Foundation.JSONEncoder | 1 | 21.8 | 13.2 | 35.0 | copied |
| SwiftMsgpack | 1 | 25.4 | 12.0 | 37.3 | copied |
| SwiftProtobuf | 100 | 351 | 27.1 | 378 | copied |
| Foundation.JSONEncoder | 100 | 1357 | 403 | 1764 | copied |
| IkigaJSON | 100 | 1384 | 466 | 1851 | copied |
| SwiftMsgpack | 100 | 1464 | 481 | 1947 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. Groups are computed **separately** for 1 record and for 100 records.

**N = 1, memory** — not clearly slower: `SwiftProtobuf`. Small gap: —. Time/size front: `SwiftProtobuf`.

**N = 100, memory** — not clearly slower: `SwiftProtobuf`. Small gap: —. Time/size front: `SwiftProtobuf`.

