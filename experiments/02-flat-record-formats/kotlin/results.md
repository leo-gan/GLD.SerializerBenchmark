# Experiment 2 results — kotlin

**Date:** 2026-10-11
**Raw file:** `experiments/02-flat-record-formats/kotlin/logs/kotlin/2026-10-11-145909.csv`
**Language:** kotlin
**Sample:** one flat record (`message`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 4.35.0 | 23.6 | 12.9 | 37.1 | 50 | 2114 | Protocol Buffers | fastest | yes | 96 |
| moshi-codegen | 1.15.2 | 19.7 | 23.3 | 47.0 | 158 | 2452 | JSON — fast writer from Experiment 1 | slower | yes | 89 |
| kotlinx-json | 1.8.1 | 25.6 | 54.2 | 78.0 | 158 | 2452 | JSON — compiler-generated kotlinx.serialization | slower | yes | 86 |
| msgpack | 0.9.8 | 49.8 | 66.3 | 115 | 114 | 2254 | MessagePack | slower | yes | 89 |
| jackson | 2.19.0 | 50.0 | 79.6 | 131 | 158 | 2452 | JSON — common default | slower | yes | 91 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 4.35.0 | 36.2 | 36.2 | 76.8 | 4841 | 2114 | Protocol Buffers | fastest | yes | 90 |
| moshi-codegen | 1.15.2 | 86.7 | 116 | 205 | 15546 | 2452 | JSON — fast writer from Experiment 1 | slower | yes | 92 |
| kotlinx-json | 1.8.1 | 103 | 133 | 245 | 15546 | 2452 | JSON — compiler-generated kotlinx.serialization | slower | yes | 87 |
| jackson | 2.19.0 | 91.2 | 167 | 262 | 15546 | 2452 | JSON — common default | slower | yes | 87 |
| msgpack | 0.9.8 | 120 | 167 | 286 | 11031 | 2254 | MessagePack | slower | yes | 84 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| protobuf | 1 | 15.7 | 11.0 | 27.1 | real |
| moshi-codegen | 1 | 10.8 | 17.8 | 28.7 | real |
| kotlinx-json | 1 | 23.1 | 38.3 | 60.8 | real |
| msgpack | 1 | 33.7 | 46.4 | 77.7 | real |
| jackson | 1 | 29.3 | 51.1 | 81.3 | real |
| protobuf | 100 | 26.6 | 26.1 | 53.2 | real |
| kotlinx-json | 100 | 67.4 | 83.3 | 152 | real |
| moshi-codegen | 100 | 62.0 | 96.5 | 162 | real |
| jackson | 100 | 53.2 | 122 | 177 | real |
| msgpack | 100 | 63.7 | 122 | 188 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. Groups are computed **separately** for 1 record and for 100 records.

**N = 1, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

**N = 100, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

