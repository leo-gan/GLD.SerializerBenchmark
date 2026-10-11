# Experiment 4 results — php

**Date:** 2026-10-11
**Raw file:** `experiments/04-sensor-list-size/php/logs/php/2026-10-11-150024.csv`
**Language:** php
**Sample:** one sensor record (`telemetry`), list lengths 8, 32, 128, 512
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 8 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 4.67 | 3.30 | 8.07 | 217 | 859 | JSON — stdlib | fastest | yes | 97 |
| rybakit-msgpack | v0.9.2 | 4.93 | 5.76 | 10.7 | 121 | 758 | MessagePack | slower | yes | 86 |
| cbor | 3.4.1 | 27.2 | 26.5 | 53.8 | 121 | 757 | CBOR | slower | yes | 90 |
| protobuf | v4.33.6+php | 40.2 | 25.4 | 65.8 | 91 | 686 | Protocol Buffers | slower | yes | 84 |

## In memory — 32 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| rybakit-msgpack | v0.9.2 | 8.43 | 10.9 | 19.3 | 339 | 758 | MessagePack | fastest | yes | 77 |
| json | 8.3.19 | 15.4 | 7.79 | 23.1 | 654 | 859 | JSON — stdlib | slower | yes | 94 |
| cbor | 3.4.1 | 45.2 | 49.7 | 95.1 | 338 | 757 | CBOR | slower | yes | 79 |
| protobuf | v4.33.6+php | 66.6 | 41.9 | 109 | 284 | 686 | Protocol Buffers | slower | yes | 83 |

## In memory — 128 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| rybakit-msgpack | v0.9.2 | 20.6 | 30.2 | 50.8 | 1203 | 758 | MessagePack | fastest | yes | 88 |
| json | 8.3.19 | 58.7 | 27.2 | 86.0 | 2406 | 859 | JSON — stdlib | slower | yes | 90 |
| cbor | 3.4.1 | 118 | 143 | 263 | 1202 | 757 | CBOR | slower | yes | 85 |
| protobuf | v4.33.6+php | 173 | 108 | 282 | 1052 | 686 | Protocol Buffers | slower | yes | 86 |

## In memory — 512 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| rybakit-msgpack | v0.9.2 | 67.2 | 105 | 172 | 4659 | 758 | MessagePack | fastest | yes | 92 |
| json | 8.3.19 | 222 | 97.6 | 321 | 9380 | 859 | JSON — stdlib | slower | yes | 91 |
| cbor | 3.4.1 | 397 | 503 | 901 | 4659 | 757 | CBOR | slower | yes | 92 |
| protobuf | v4.33.6+php | 582 | 362 | 946 | 4124 | 686 | Protocol Buffers | slower | yes | 90 |

## Stream call (side note)

| Library | Points | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|--------|------------|-----------|-------------------|---------------------------|
| json | 8 | 4.99 | 3.89 | 8.96 | text_on_stream |
| rybakit-msgpack | 8 | 5.31 | 6.19 | 11.5 | copied |
| cbor | 8 | 27.8 | 27.2 | 55.0 | copied |
| protobuf | 8 | 41.4 | 26.2 | 67.6 | copied |
| rybakit-msgpack | 32 | 8.63 | 11.2 | 19.9 | copied |
| json | 32 | 15.6 | 8.10 | 23.8 | text_on_stream |
| cbor | 32 | 46.1 | 50.5 | 96.7 | copied |
| protobuf | 32 | 66.8 | 42.3 | 109 | copied |
| rybakit-msgpack | 128 | 21.5 | 30.6 | 52.4 | copied |
| json | 128 | 58.8 | 27.8 | 87.0 | text_on_stream |
| cbor | 128 | 122 | 145 | 269 | copied |
| protobuf | 128 | 178 | 111 | 291 | copied |
| rybakit-msgpack | 512 | 66.0 | 102 | 168 | copied |
| json | 512 | 220 | 97.2 | 317 | text_on_stream |
| cbor | 512 | 387 | 492 | 881 | copied |
| protobuf | 512 | 567 | 355 | 923 | copied |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each list length. Size is the first number we care about.

**8 numbers, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`, `rybakit-msgpack`, `protobuf`.

**32 numbers, memory** — not clearly slower: `rybakit-msgpack`. Small gap: —. Time/size front: `rybakit-msgpack`, `cbor`, `protobuf`.

**128 numbers, memory** — not clearly slower: `rybakit-msgpack`. Small gap: —. Time/size front: `rybakit-msgpack`, `cbor`, `protobuf`.

**512 numbers, memory** — not clearly slower: `rybakit-msgpack`. Small gap: —. Time/size front: `rybakit-msgpack`, `protobuf`.

