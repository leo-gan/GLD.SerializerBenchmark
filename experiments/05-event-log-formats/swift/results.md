# Experiment 5 results — swift

**Date:** 2026-10-11
**Raw file:** `experiments/05-event-log-formats/swift/logs/swift/2026-10-11-150104.csv`
**Language:** swift
**Sample:** one event (`event`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SwiftProtobuf | 1.38.1 | 4.89 | 3.76 | 8.67 | 123 | 4317 | Protocol Buffers | fastest | yes | 81 |
| IkigaJSON | 2.5.4 | 11.0 | 17.5 | 28.5 | 257 | 4266 | JSON — Experiment 1 | slower | yes | 81 |
| SwiftAvroCore | 2.3.0 | 61.7 | 17.2 | 78.9 | 105 | 3708 | Avro | slower | yes | 84 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SwiftProtobuf | 1.38.1 | 127 | 115 | 243 | 12477 | 4317 | Protocol Buffers | fastest | yes | 75 |
| IkigaJSON | 2.5.4 | 560 | 939 | 1503 | 25746 | 4266 | JSON — Experiment 1 | slower | yes | 94 |
| SwiftAvroCore | 2.3.0 | 3881 | 963 | 4846 | 10448 | 3708 | Avro | slower | yes | 92 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| SwiftProtobuf | 1 | 14.6 | 4.93 | 19.6 | copied |
| IkigaJSON | 1 | 29.7 | 19.0 | 48.7 | copied |
| SwiftAvroCore | 1 | 72.5 | 19.0 | 91.6 | copied |
| SwiftProtobuf | 100 | 970 | 120 | 1091 | copied |
| IkigaJSON | 100 | 2295 | 958 | 3254 | copied |
| SwiftAvroCore | 100 | 4645 | 994 | 5638 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one event. Groups are computed **separately** for 1 record and for 100 records. Speed cannot override a failed compatibility story.

**N = 1, memory** — not clearly slower: `SwiftProtobuf`. Small gap: —. Time/size front: `SwiftProtobuf`, `SwiftAvroCore`.

**N = 100, memory** — not clearly slower: `SwiftProtobuf`. Small gap: —. Time/size front: `SwiftProtobuf`, `SwiftAvroCore`.

