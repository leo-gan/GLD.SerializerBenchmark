# Experiment 3 results — kotlin

**Date:** 2026-08-28
**Raw file:** `experiments/03-one-language-store/kotlin/logs/kotlin/2026-08-27-181718.csv`
**Language:** kotlin
**Sample:** one flat record (`message`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 4.28.3 | 25.5 | 12.8 | 39.0 | 50 | 71 | other languages can read — Protocol Buffers | fastest | yes | 94 |
| fory | 1.3.0 | 27.8 | 22.8 | 51.2 | 133 | 149 | one language — Apache Fory | slower | yes | 93 |
| kryo | 5.6.2 | 35.7 | 23.4 | 59.6 | 46 | 67 | one language — Kryo | slower | yes | 89 |
| kotlinx-json | 1.8.1 | 38.0 | 68.9 | 108 | 158 | 141 | other languages can read — JSON | slower | yes | 88 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| protobuf | 1 | 14.2 | 11.6 | 25.8 | real |
| kryo | 1 | 21.0 | 14.1 | 35.3 | real |
| fory | 1 | 21.1 | 18.4 | 39.1 | copied |
| kotlinx-json | 1 | 21.6 | 38.0 | 58.4 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`, `kryo`.

