# Experiment 4 results — kotlin

**Date:** 2026-08-28
**Raw file:** `experiments/04-sensor-list-size/kotlin/logs/kotlin/2026-08-27-181722.csv`
**Language:** kotlin
**Sample:** one sensor record (`telemetry`), list lengths 8, 32, 128, 512
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 8 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| moshi-codegen | 1.15.2 | 22.0 | 27.9 | 52.2 | 220 | 862 | JSON — fast writer from Experiment 1 | fastest | yes | 89 |
| protobuf | 4.28.3 | 34.1 | 19.0 | 54.2 | 94 | 697 | Protocol Buffers | similar | yes | 91 |
| kotlinx-cbor | 1.8.1 | 39.6 | 37.1 | 77.5 | 127 | 771 | CBOR | slower | yes | 88 |
| kotlinx-json | 1.8.1 | 37.1 | 67.4 | 109 | 220 | 862 | JSON — compiler-generated kotlinx.serialization | slower | yes | 89 |
| jackson-cbor | 2.18.3 | 52.5 | 77.4 | 137 | 125 | 771 | CBOR — Jackson | slower | yes | 88 |
| msgpack | 0.9.8 | 62.3 | 87.7 | 157 | 124 | 770 | MessagePack | slower | yes | 89 |

## In memory — 32 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 4.28.3 | 14.3 | 12.7 | 27.3 | 291 | 697 | Protocol Buffers | fastest | yes | 88 |
| moshi-codegen | 1.15.2 | 15.2 | 24.5 | 40.8 | 663 | 862 | JSON — fast writer from Experiment 1 | slower | yes | 89 |
| kotlinx-cbor | 1.8.1 | 23.3 | 22.2 | 46.2 | 347 | 771 | CBOR | slower | yes | 92 |
| jackson-cbor | 2.18.3 | 32.8 | 37.2 | 71.4 | 346 | 771 | CBOR — Jackson | slower | yes | 88 |
| kotlinx-json | 1.8.1 | 29.7 | 47.9 | 77.6 | 663 | 862 | JSON — compiler-generated kotlinx.serialization | slower | yes | 90 |
| msgpack | 0.9.8 | 43.6 | 48.1 | 92.3 | 346 | 770 | MessagePack | slower | yes | 90 |

## In memory — 128 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 4.28.3 | 9.70 | 9.56 | 19.4 | 1061 | 697 | Protocol Buffers | fastest | yes | 87 |
| kotlinx-cbor | 1.8.1 | 14.3 | 18.4 | 33.0 | 1213 | 771 | CBOR | slower | yes | 92 |
| jackson-cbor | 2.18.3 | 24.1 | 30.5 | 54.5 | 1212 | 771 | CBOR — Jackson | slower | yes | 86 |
| moshi-codegen | 1.15.2 | 17.4 | 39.2 | 56.4 | 2407 | 862 | JSON — fast writer from Experiment 1 | slower | yes | 84 |
| msgpack | 0.9.8 | 29.0 | 36.9 | 67.1 | 1212 | 770 | MessagePack | slower | yes | 92 |
| kotlinx-json | 1.8.1 | 29.9 | 51.9 | 82.0 | 2407 | 862 | JSON — compiler-generated kotlinx.serialization | slower | yes | 92 |

## In memory — 512 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 4.28.3 | 12.0 | 13.6 | 25.3 | 4128 | 697 | Protocol Buffers | fastest | yes | 89 |
| kotlinx-cbor | 1.8.1 | 26.6 | 29.2 | 56.3 | 4664 | 771 | CBOR | slower | yes | 88 |
| jackson-cbor | 2.18.3 | 31.9 | 40.3 | 72.7 | 4664 | 771 | CBOR — Jackson | slower | yes | 88 |
| msgpack | 0.9.8 | 31.2 | 46.6 | 78.0 | 4663 | 770 | MessagePack | slower | yes | 93 |
| kotlinx-json | 1.8.1 | 61.6 | 106 | 168 | 9363 | 862 | JSON — compiler-generated kotlinx.serialization | slower | yes | 85 |
| moshi-codegen | 1.15.2 | 50.2 | 118 | 169 | 9363 | 862 | JSON — fast writer from Experiment 1 | slower | yes | 83 |

## Stream call (side note)

| Library | Points | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|--------|------------|-----------|-------------------|---------------------------|
| moshi-codegen | 8 | 15.5 | 21.0 | 37.6 | real |
| protobuf | 8 | 22.7 | 18.0 | 39.0 | real |
| kotlinx-cbor | 8 | 25.5 | 24.4 | 51.0 | copied |
| kotlinx-json | 8 | 25.3 | 44.1 | 71.0 | real |
| jackson-cbor | 8 | 34.3 | 54.2 | 87.0 | real |
| msgpack | 8 | 44.2 | 67.4 | 112 | real |
| protobuf | 32 | 16.1 | 16.9 | 33.1 | real |
| kotlinx-cbor | 32 | 18.6 | 20.7 | 39.5 | copied |
| moshi-codegen | 32 | 14.1 | 27.7 | 42.2 | real |
| kotlinx-json | 32 | 27.0 | 45.1 | 71.5 | real |
| jackson-cbor | 32 | 31.1 | 42.1 | 74.2 | real |
| msgpack | 32 | 37.9 | 45.8 | 83.4 | real |
| protobuf | 128 | 7.27 | 7.24 | 14.9 | real |
| kotlinx-cbor | 128 | 11.7 | 14.5 | 26.9 | copied |
| msgpack | 128 | 15.5 | 28.5 | 44.0 | real |
| jackson-cbor | 128 | 20.4 | 27.1 | 47.9 | real |
| moshi-codegen | 128 | 16.2 | 35.9 | 52.5 | real |
| kotlinx-json | 128 | 24.2 | 34.2 | 58.1 | real |
| protobuf | 512 | 16.8 | 16.7 | 34.2 | real |
| kotlinx-cbor | 512 | 27.6 | 26.5 | 54.0 | copied |
| jackson-cbor | 512 | 25.9 | 36.9 | 66.2 | real |
| msgpack | 512 | 26.7 | 41.0 | 68.1 | real |
| kotlinx-json | 512 | 58.2 | 104 | 162 | real |
| moshi-codegen | 512 | 49.7 | 127 | 178 | real |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each list length. Size is the first number we care about.

**8 numbers, memory** — not clearly slower: `moshi-codegen`, `protobuf`. Small gap: —. Time/size front: `moshi-codegen`, `protobuf`.

**32 numbers, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

**128 numbers, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

**512 numbers, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

