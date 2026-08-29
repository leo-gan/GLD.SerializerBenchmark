# Experiment 14 results — swift

**Date:** 2026-08-29
**Raw file:** `experiments/14-starter-kit/swift/logs/swift/2026-08-28-182314.csv`
**Language:** swift
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| SwiftProtobuf | 1.38.1 | 9.57 | 6.76 | 16.7 | 155 | 174 | yes | fastest | yes | 94 |
| IkigaJSON | 2.5.3 | 21.7 | 38.0 | 59.7 | 448 | 229 | yes | slower | yes | 93 |
| Foundation.JSONEncoder | Foundation | 28.7 | 36.2 | 65.1 | 448 | 233 | yes | slower | yes | 94 |
| SwiftMsgpack | 1.2.1 | 53.0 | 38.8 | 91.8 | 329 | 230 | yes | slower | yes | 91 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| SwiftProtobuf | 20.6 | 7.37 | 27.9 | copied |
| IkigaJSON | 54.8 | 37.4 | 93.0 | copied |
| Foundation.JSONEncoder | 59.7 | 35.4 | 95.1 | copied |
| SwiftMsgpack | 78.3 | 39.5 | 117 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest library in this starter kit? A faster row is not automatically the right public format.

**Not clearly slower on this sample:** `SwiftProtobuf`.
**Not both slower and larger than another library in the kit:** `SwiftProtobuf`.

