# Experiment 5 results — swift

**Date:** 2026-08-17
**Raw file:** `experiments/05-event-log-formats/swift/logs/swift/2026-08-17-113838.csv`
**Language:** swift
**Sample:** one event (`event`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SwiftProtobuf | 1.38.1 | 3.71 | 3.16 | 6.88 | 123 | — | Protocol Buffers | fastest | yes | 79 |
| IkigaJSON | 2.5.3 | 11.6 | 17.5 | 29.0 | 257 | — | JSON — Experiment 1 | slower | yes | 86 |
| SwiftAvroCore | 2.3.0 | 60.9 | 17.0 | 77.7 | 105 | — | Avro | slower | yes | 91 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SwiftProtobuf | 1.38.1 | 120 | 110 | 231 | 12477 | — | Protocol Buffers | fastest | yes | 88 |
| IkigaJSON | 2.5.3 | 602 | 1043 | 1644 | 25746 | — | JSON — Experiment 1 | slower | yes | 91 |
| SwiftAvroCore | 2.3.0 | 4305 | 1074 | 5368 | 10448 | — | Avro | slower | yes | 88 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| SwiftProtobuf | 1 | 14.2 | 4.52 | 18.7 | copied |
| IkigaJSON | 1 | 30.0 | 18.8 | 48.7 | copied |
| SwiftAvroCore | 1 | 72.4 | 19.1 | 91.8 | copied |
| SwiftProtobuf | 100 | 1008 | 111 | 1119 | copied |
| IkigaJSON | 100 | 2419 | 1035 | 3457 | copied |
| SwiftAvroCore | 100 | 5008 | 1059 | 6064 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one event. Groups are computed **separately** for 1 record and for 100 records. Speed cannot override a failed compatibility story.

**N = 1, memory** — not clearly slower: `SwiftProtobuf`. Small gap: —. Time/size front: `SwiftProtobuf`, `SwiftAvroCore`.

**N = 100, memory** — not clearly slower: `SwiftProtobuf`. Small gap: —. Time/size front: `SwiftProtobuf`, `SwiftAvroCore`.

