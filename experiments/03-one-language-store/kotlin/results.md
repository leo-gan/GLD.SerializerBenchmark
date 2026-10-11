# Experiment 3 results — kotlin

**Date:** 2026-10-11
**Raw file:** `experiments/03-one-language-store/kotlin/logs/kotlin/2026-10-11-145949.csv`
**Language:** kotlin
**Sample:** one flat record (`message`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 4.35.0 | 20.7 | 11.6 | 32.2 | 50 | 71 | other languages can read — Protocol Buffers | fastest | yes | 90 |
| fory | 1.3.0 | 24.0 | 20.7 | 44.7 | 133 | 149 | one language — Apache Fory | slower | yes | 92 |
| kryo | 5.6.2 | 33.3 | 21.4 | 54.7 | 46 | 67 | one language — Kryo | slower | yes | 89 |
| kotlinx-json | 1.8.1 | 30.5 | 60.7 | 90.7 | 158 | 141 | other languages can read — JSON | slower | yes | 96 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| protobuf | 1 | 14.7 | 10.9 | 26.6 | real |
| kryo | 1 | 20.3 | 12.6 | 33.2 | real |
| fory | 1 | 17.9 | 16.5 | 34.6 | copied |
| kotlinx-json | 1 | 21.7 | 36.4 | 57.9 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`, `kryo`.

