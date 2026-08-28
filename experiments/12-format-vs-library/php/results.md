# Experiment 12 results — php

**Date:** 2026-08-28
**Raw file:** `experiments/12-format-vs-library/php/logs/php/2026-08-28-113623.csv`
**Language:** php
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 1.73 | 4.06 | 5.76 | 454 | 231 | stdlib — JSON | fastest | yes | 88 |
| symfony-json | v7.4.17 | 2.98 | 4.73 | 7.76 | 454 | 231 | Symfony — JSON | slower | yes | 90 |
| rybakit-msgpack | v0.9.2 | 9.46 | 12.3 | 21.7 | 335 | 232 | rybakit — MessagePack | slower | yes | 81 |
| protobuf | v4.33.6+php | 128 | 69.1 | 197 | 160 | 178 | google/protobuf | slower | yes | 91 |
| cbor | 3.3.1 | 149 | 91.1 | 240 | 339 | 225 | cbor-php — CBOR | slower | yes | 82 |
| yaml | v7.4.17 | 69.3 | 212 | 282 | 515 | 228 | Symfony — YAML | slower | yes | 93 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| json | 1 | 1.94 | 4.40 | 6.42 | text_on_stream |
| symfony-json | 1 | 3.10 | 4.99 | 8.12 | text_on_stream |
| rybakit-msgpack | 1 | 9.81 | 12.8 | 22.7 | copied |
| protobuf | 1 | 129 | 71.2 | 201 | copied |
| cbor | 1 | 152 | 91.7 | 243 | copied |
| yaml | 1 | 71.4 | 217 | 289 | text_on_stream |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Holding one library still is not a claim about every writer of that format.

**N = 1, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`, `rybakit-msgpack`, `protobuf`.

