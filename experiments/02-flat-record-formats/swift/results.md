# Experiment 2 results — swift

**Date:** 2026-10-11
**Raw file:** `experiments/02-flat-record-formats/swift/logs/swift/2026-10-11-145823.csv`
**Language:** swift
**Sample:** one flat record (`message`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SwiftProtobuf | 1.38.1 | 2.26 | 2.03 | 4.32 | 50 | 2114 | Protocol Buffers | fastest | yes | 78 |
| IkigaJSON | 2.5.4 | 7.83 | 12.3 | 20.2 | 168 | 2469 | JSON — fast writer from Experiment 1 | slower | yes | 79 |
| Foundation.JSONEncoder | Foundation | 8.95 | 13.0 | 22.0 | 168 | 2458 | JSON — ships with Swift | slower | yes | 76 |
| SwiftMsgpack | 1.2.1 | 16.2 | 10.9 | 27.1 | 124 | 2278 | MessagePack | slower | yes | 80 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SwiftProtobuf | 1.38.1 | 31.0 | 29.8 | 60.9 | 4841 | 2114 | Protocol Buffers | fastest | yes | 86 |
| Foundation.JSONEncoder | Foundation | 281 | 421 | 705 | 16546 | 2458 | JSON — ships with Swift | slower | yes | 95 |
| IkigaJSON | 2.5.4 | 308 | 489 | 799 | 16546 | 2469 | JSON — fast writer from Experiment 1 | slower | yes | 95 |
| SwiftMsgpack | 1.2.1 | 670 | 527 | 1198 | 12041 | 2278 | MessagePack | slower | yes | 95 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| SwiftProtobuf | 1 | 7.38 | 3.18 | 10.5 | copied |
| IkigaJSON | 1 | 21.0 | 13.6 | 34.6 | copied |
| Foundation.JSONEncoder | 1 | 22.1 | 14.2 | 36.6 | copied |
| SwiftMsgpack | 1 | 26.5 | 12.2 | 38.8 | copied |
| SwiftProtobuf | 100 | 367 | 32.5 | 400 | copied |
| Foundation.JSONEncoder | 100 | 1419 | 423 | 1841 | copied |
| IkigaJSON | 100 | 1441 | 490 | 1933 | copied |
| SwiftMsgpack | 100 | 1530 | 512 | 2055 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. Groups are computed **separately** for 1 record and for 100 records.

**N = 1, memory** — not clearly slower: `SwiftProtobuf`. Small gap: —. Time/size front: `SwiftProtobuf`.

**N = 100, memory** — not clearly slower: `SwiftProtobuf`. Small gap: —. Time/size front: `SwiftProtobuf`.

