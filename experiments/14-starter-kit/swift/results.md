# Experiment 14 results — swift

**Date:** 2026-10-11
**Raw file:** `experiments/14-starter-kit/swift/logs/swift/2026-10-11-151257.csv`
**Language:** swift
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| SwiftProtobuf | 1.38.1 | 5.58 | 4.96 | 10.5 | 155 | 174 | yes | fastest | yes | 77 |
| IkigaJSON | 2.5.4 | 18.3 | 32.7 | 50.8 | 448 | 229 | yes | slower | yes | 83 |
| Foundation.JSONEncoder | Foundation | 22.1 | 29.8 | 52.0 | 448 | 232 | yes | slower | yes | 84 |
| SwiftMsgpack | 1.2.1 | 47.0 | 34.4 | 81.3 | 329 | 230 | yes | slower | yes | 85 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| SwiftProtobuf | 18.5 | 6.50 | 25.0 | copied |
| IkigaJSON | 51.6 | 35.2 | 86.7 | copied |
| Foundation.JSONEncoder | 55.9 | 32.2 | 88.4 | copied |
| SwiftMsgpack | 73.4 | 36.3 | 110 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest library in this starter kit? A faster row is not automatically the right public format.

**Not clearly slower on this sample:** `SwiftProtobuf`.
**Not both slower and larger than another library in the kit:** `SwiftProtobuf`.

