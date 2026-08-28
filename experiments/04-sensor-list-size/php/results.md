# Experiment 4 results — php

**Date:** 2026-08-28
**Raw file:** `experiments/04-sensor-list-size/php/logs/php/2026-08-28-113554.csv`
**Language:** php
**Sample:** one sensor record (`telemetry`), list lengths 8, 32, 128, 512
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 8 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 4.60 | 3.10 | 7.66 | 217 | 859 | JSON — stdlib | fastest | yes | 91 |
| rybakit-msgpack | v0.9.2 | 5.18 | 5.92 | 11.1 | 121 | 758 | MessagePack | slower | yes | 94 |
| protobuf | v4.33.6+php | 40.3 | 25.4 | 65.9 | 91 | 686 | Protocol Buffers | slower | yes | 84 |
| cbor | 3.3.1 | 28.5 | 124 | 153 | 120 | 756 | CBOR | slower | yes | 84 |

## In memory — 32 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| rybakit-msgpack | v0.9.2 | 8.70 | 11.1 | 19.9 | 339 | 758 | MessagePack | fastest | yes | 74 |
| json | 8.3.19 | 15.6 | 7.96 | 23.5 | 654 | 859 | JSON — stdlib | slower | yes | 88 |
| protobuf | v4.33.6+php | 66.6 | 42.1 | 109 | 284 | 686 | Protocol Buffers | slower | yes | 83 |
| cbor | 3.3.1 | 50.9 | 390 | 441 | 337 | 756 | CBOR | slower | yes | 81 |

## In memory — 128 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| rybakit-msgpack | v0.9.2 | 21.5 | 31.6 | 53.3 | 1203 | 758 | MessagePack | fastest | yes | 93 |
| json | 8.3.19 | 59.5 | 27.1 | 87.2 | 2406 | 859 | JSON — stdlib | slower | yes | 89 |
| protobuf | v4.33.6+php | 177 | 110 | 288 | 1052 | 686 | Protocol Buffers | slower | yes | 93 |
| cbor | 3.3.1 | 145 | 1483 | 1630 | 1201 | 756 | CBOR | slower | yes | 90 |

## In memory — 512 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| rybakit-msgpack | v0.9.2 | 67.4 | 105 | 173 | 4659 | 758 | MessagePack | fastest | yes | 90 |
| json | 8.3.19 | 223 | 94.7 | 317 | 9380 | 859 | JSON — stdlib | slower | yes | 86 |
| protobuf | v4.33.6+php | 576 | 359 | 940 | 4124 | 686 | Protocol Buffers | slower | yes | 81 |
| cbor | 3.3.1 | 535 | 5600 | 6126 | 4658 | 756 | CBOR | slower | yes | 87 |

## Stream call (side note)

| Library | Points | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|--------|------------|-----------|-------------------|---------------------------|
| json | 8 | 4.89 | 3.65 | 8.54 | text_on_stream |
| rybakit-msgpack | 8 | 5.38 | 6.23 | 11.7 | copied |
| protobuf | 8 | 40.0 | 25.7 | 65.6 | copied |
| cbor | 8 | 29.1 | 124 | 153 | copied |
| rybakit-msgpack | 32 | 9.09 | 11.8 | 21.0 | copied |
| json | 32 | 15.7 | 8.10 | 23.7 | text_on_stream |
| protobuf | 32 | 67.4 | 42.8 | 110 | copied |
| cbor | 32 | 51.6 | 391 | 443 | copied |
| rybakit-msgpack | 128 | 21.3 | 31.0 | 52.5 | copied |
| json | 128 | 57.8 | 26.3 | 84.3 | text_on_stream |
| protobuf | 128 | 173 | 109 | 283 | copied |
| cbor | 128 | 142 | 1446 | 1590 | copied |
| rybakit-msgpack | 512 | 68.1 | 105 | 174 | copied |
| json | 512 | 225 | 96.5 | 322 | text_on_stream |
| protobuf | 512 | 581 | 363 | 947 | copied |
| cbor | 512 | 537 | 5590 | 6139 | copied |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each list length. Size is the first number we care about.

**8 numbers, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`, `rybakit-msgpack`, `protobuf`.

**32 numbers, memory** — not clearly slower: `rybakit-msgpack`. Small gap: —. Time/size front: `rybakit-msgpack`, `protobuf`.

**128 numbers, memory** — not clearly slower: `rybakit-msgpack`. Small gap: —. Time/size front: `rybakit-msgpack`, `protobuf`.

**512 numbers, memory** — not clearly slower: `rybakit-msgpack`. Small gap: —. Time/size front: `rybakit-msgpack`, `protobuf`.

