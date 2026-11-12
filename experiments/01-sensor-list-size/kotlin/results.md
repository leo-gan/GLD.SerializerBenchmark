# Experiment 4 results — kotlin

**Date:** 2026-11-12
**Raw file:** `experiments/01-sensor-list-size/kotlin/logs/kotlin/2026-11-12-163709.csv`
**Language:** kotlin
**Sample:** one sensor record (`telemetry`), list lengths 8, 32, 128, 512
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 8 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| moshi-codegen | 1.15.2 | 22.4 | 26.3 | 47.4 | 220 | 862 | JSON — fast writer fast named JSON | fastest | yes | 88 |
| protobuf | 4.36.2 | 37.3 | 21.0 | 57.8 | 94 | 697 | Protocol Buffers | close | yes | 91 |
| kotlinx-cbor | 1.12.0 | 37.8 | 39.2 | 78.7 | 127 | 771 | CBOR | slower | yes | 91 |
| kotlinx-json | 1.12.0 | 42.4 | 69.3 | 116 | 220 | 862 | JSON — compiler-generated kotlinx.serialization | slower | yes | 88 |
| jackson-cbor | 2.22.4 | 53.6 | 87.9 | 141 | 125 | 771 | CBOR — Jackson | slower | yes | 90 |
| msgpack | 0.9.12 | 69.2 | 85.3 | 155 | 124 | 770 | MessagePack | slower | yes | 91 |

## In memory — 32 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 4.36.2 | 18.9 | 15.5 | 35.4 | 291 | 697 | Protocol Buffers | fastest | yes | 89 |
| moshi-codegen | 1.15.2 | 18.4 | 27.2 | 46.0 | 663 | 862 | JSON — fast writer fast named JSON | slower | yes | 88 |
| kotlinx-cbor | 1.12.0 | 27.4 | 24.3 | 51.7 | 347 | 771 | CBOR | slower | yes | 88 |
| jackson-cbor | 2.22.4 | 38.3 | 48.1 | 87.3 | 346 | 771 | CBOR — Jackson | slower | yes | 92 |
| kotlinx-json | 1.12.0 | 33.6 | 55.0 | 89.5 | 663 | 862 | JSON — compiler-generated kotlinx.serialization | slower | yes | 87 |
| msgpack | 0.9.12 | 45.7 | 49.2 | 95.6 | 346 | 770 | MessagePack | slower | yes | 86 |

## In memory — 128 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 4.36.2 | 11.2 | 12.4 | 26.6 | 1061 | 697 | Protocol Buffers | fastest | yes | 90 |
| kotlinx-cbor | 1.12.0 | 16.6 | 20.0 | 37.1 | 1213 | 771 | CBOR | slower | yes | 82 |
| msgpack | 0.9.12 | 25.3 | 30.6 | 56.6 | 1212 | 770 | MessagePack | slower | yes | 93 |
| jackson-cbor | 2.22.4 | 25.0 | 33.0 | 57.8 | 1212 | 771 | CBOR — Jackson | slower | yes | 90 |
| moshi-codegen | 1.15.2 | 19.3 | 41.7 | 61.6 | 2407 | 862 | JSON — fast writer fast named JSON | slower | yes | 88 |
| kotlinx-json | 1.12.0 | 30.3 | 59.5 | 92.2 | 2407 | 862 | JSON — compiler-generated kotlinx.serialization | slower | yes | 95 |

## In memory — 512 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 4.36.2 | 14.6 | 15.2 | 29.7 | 4128 | 697 | Protocol Buffers | fastest | yes | 94 |
| kotlinx-cbor | 1.12.0 | 28.8 | 30.4 | 59.1 | 4664 | 771 | CBOR | slower | yes | 96 |
| jackson-cbor | 2.22.4 | 27.4 | 40.1 | 67.8 | 4664 | 771 | CBOR — Jackson | slower | yes | 89 |
| msgpack | 0.9.12 | 34.6 | 35.2 | 69.2 | 4663 | 770 | MessagePack | slower | yes | 88 |
| kotlinx-json | 1.12.0 | 59.6 | 127 | 185 | 9363 | 862 | JSON — compiler-generated kotlinx.serialization | slower | yes | 89 |
| moshi-codegen | 1.15.2 | 56.2 | 130 | 187 | 9363 | 862 | JSON — fast writer fast named JSON | slower | yes | 86 |

## Stream call (side note)

| Library | Points | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|--------|------------|-----------|-------------------|---------------------------|
| moshi-codegen | 8 | 12.1 | 18.6 | 30.5 | real |
| protobuf | 8 | 19.4 | 13.4 | 33.3 | real |
| kotlinx-cbor | 8 | 23.5 | 21.5 | 45.3 | copied |
| kotlinx-json | 8 | 21.3 | 39.1 | 59.9 | real |
| jackson-cbor | 8 | 28.1 | 41.1 | 69.0 | real |
| msgpack | 8 | 36.2 | 47.6 | 85.6 | real |
| protobuf | 32 | 13.4 | 16.3 | 31.1 | real |
| moshi-codegen | 32 | 13.2 | 27.2 | 40.5 | real |
| kotlinx-cbor | 32 | 20.3 | 20.2 | 41.8 | copied |
| jackson-cbor | 32 | 29.9 | 34.8 | 64.2 | real |
| msgpack | 32 | 27.6 | 39.3 | 69.6 | real |
| kotlinx-json | 32 | 24.8 | 45.4 | 71.7 | real |
| protobuf | 128 | 9.01 | 10.2 | 20.6 | real |
| kotlinx-cbor | 128 | 15.5 | 21.5 | 36.8 | copied |
| jackson-cbor | 128 | 16.4 | 26.6 | 42.8 | real |
| msgpack | 128 | 21.7 | 28.7 | 51.2 | real |
| moshi-codegen | 128 | 18.5 | 41.6 | 61.2 | real |
| kotlinx-json | 128 | 25.7 | 54.2 | 80.3 | real |
| protobuf | 512 | 14.5 | 18.6 | 33.3 | real |
| jackson-cbor | 512 | 18.2 | 30.8 | 50.1 | real |
| kotlinx-cbor | 512 | 27.1 | 24.1 | 51.3 | copied |
| msgpack | 512 | 25.8 | 32.8 | 60.0 | real |
| kotlinx-json | 512 | 58.4 | 112 | 172 | real |
| moshi-codegen | 512 | 52.6 | 133 | 184 | real |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each list length. Size is the first number we care about.

**8 numbers, memory** — not clearly slower: `moshi-codegen`. Small gap: `protobuf`. Time/size front: `moshi-codegen`, `protobuf`.

**32 numbers, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

**128 numbers, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

**512 numbers, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

