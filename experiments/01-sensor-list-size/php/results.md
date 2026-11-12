# Experiment 4 results — php

**Date:** 2026-11-12
**Raw file:** `experiments/01-sensor-list-size/php/logs/php/2026-11-12-163717.csv`
**Language:** php
**Sample:** one sensor record (`telemetry`), list lengths 8, 32, 128, 512
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 8 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 4.84 | 3.46 | 8.31 | 217 | 859 | JSON — stdlib | fastest | yes | 97 |
| rybakit-msgpack | v0.9.2 | 5.27 | 5.87 | 11.2 | 121 | 758 | MessagePack | slower | yes | 79 |
| cbor | 3.4.2 | 28.3 | 27.2 | 55.6 | 121 | 757 | CBOR | slower | yes | 84 |
| protobuf | v4.33.6+php | 42.0 | 26.3 | 68.4 | 91 | 686 | Protocol Buffers | slower | yes | 78 |

## In memory — 32 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| rybakit-msgpack | v0.9.2 | 9.12 | 11.4 | 20.5 | 339 | 758 | MessagePack | fastest | yes | 87 |
| json | 8.3.19 | 16.3 | 8.56 | 24.9 | 654 | 859 | JSON — stdlib | slower | yes | 93 |
| cbor | 3.4.2 | 48.4 | 52.8 | 101 | 338 | 757 | CBOR | slower | yes | 86 |
| protobuf | v4.33.6+php | 70.7 | 44.2 | 115 | 284 | 686 | Protocol Buffers | slower | yes | 77 |

## In memory — 128 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| rybakit-msgpack | v0.9.2 | 21.7 | 31.5 | 53.3 | 1203 | 758 | MessagePack | fastest | yes | 90 |
| json | 8.3.19 | 60.5 | 27.4 | 87.9 | 2406 | 859 | JSON — stdlib | slower | yes | 89 |
| cbor | 3.4.2 | 122 | 148 | 270 | 1202 | 757 | CBOR | slower | yes | 94 |
| protobuf | v4.33.6+php | 179 | 112 | 291 | 1052 | 686 | Protocol Buffers | slower | yes | 92 |

## In memory — 512 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| rybakit-msgpack | v0.9.2 | 72.3 | 112 | 185 | 4659 | 758 | MessagePack | fastest | yes | 90 |
| json | 8.3.19 | 235 | 103 | 338 | 9380 | 859 | JSON — stdlib | slower | yes | 90 |
| cbor | 3.4.2 | 422 | 529 | 948 | 4659 | 757 | CBOR | slower | yes | 93 |
| protobuf | v4.33.6+php | 621 | 386 | 1006 | 4124 | 686 | Protocol Buffers | slower | yes | 91 |

## Stream call (side note)

| Library | Points | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|--------|------------|-----------|-------------------|---------------------------|
| json | 8 | 4.89 | 3.62 | 8.54 | text_on_stream |
| rybakit-msgpack | 8 | 5.40 | 6.26 | 11.7 | copied |
| cbor | 8 | 28.5 | 27.4 | 56.0 | copied |
| protobuf | 8 | 41.7 | 26.3 | 68.0 | copied |
| rybakit-msgpack | 32 | 9.20 | 11.7 | 20.8 | copied |
| json | 32 | 16.5 | 8.96 | 25.5 | text_on_stream |
| cbor | 32 | 48.0 | 52.4 | 100 | copied |
| protobuf | 32 | 69.9 | 44.3 | 115 | copied |
| rybakit-msgpack | 128 | 21.7 | 31.6 | 53.7 | copied |
| json | 128 | 60.4 | 27.9 | 88.5 | text_on_stream |
| cbor | 128 | 122 | 148 | 271 | copied |
| protobuf | 128 | 180 | 113 | 291 | copied |
| rybakit-msgpack | 512 | 71.0 | 110 | 182 | copied |
| json | 512 | 233 | 101 | 335 | text_on_stream |
| cbor | 512 | 420 | 527 | 947 | copied |
| protobuf | 512 | 615 | 382 | 1001 | copied |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each list length. Size is the first number we care about.

**8 numbers, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`, `rybakit-msgpack`, `protobuf`.

**32 numbers, memory** — not clearly slower: `rybakit-msgpack`. Small gap: —. Time/size front: `rybakit-msgpack`, `cbor`, `protobuf`.

**128 numbers, memory** — not clearly slower: `rybakit-msgpack`. Small gap: —. Time/size front: `rybakit-msgpack`, `cbor`, `protobuf`.

**512 numbers, memory** — not clearly slower: `rybakit-msgpack`. Small gap: —. Time/size front: `rybakit-msgpack`, `protobuf`.

