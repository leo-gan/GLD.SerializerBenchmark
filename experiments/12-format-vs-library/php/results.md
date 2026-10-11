# Experiment 12 results — php

**Date:** 2026-10-11
**Raw file:** `experiments/12-format-vs-library/php/logs/php/2026-10-11-150842.csv`
**Language:** php
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 1.96 | 4.56 | 6.50 | 454 | 231 | stdlib — JSON | fastest | yes | 97 |
| symfony-json | v7.4.18 | 3.20 | 5.28 | 8.56 | 454 | 231 | Symfony — JSON | slower | yes | 95 |
| rybakit-msgpack | v0.9.2 | 9.39 | 12.4 | 21.8 | 335 | 232 | rybakit — MessagePack | slower | yes | 81 |
| cbor | 3.4.1 | 69.8 | 74.3 | 144 | 339 | 225 | cbor-php — CBOR | slower | yes | 87 |
| protobuf | v4.33.6+php | 129 | 70.7 | 200 | 160 | 178 | google/protobuf | slower | yes | 81 |
| yaml | v7.4.18 | 76.0 | 216 | 292 | 515 | 228 | Symfony — YAML | slower | yes | 85 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| json | 1 | 2.08 | 4.77 | 6.83 | text_on_stream |
| symfony-json | 1 | 3.40 | 5.59 | 8.93 | text_on_stream |
| rybakit-msgpack | 1 | 9.73 | 12.9 | 22.6 | copied |
| cbor | 1 | 69.7 | 74.5 | 144 | copied |
| protobuf | 1 | 130 | 72.0 | 202 | copied |
| yaml | 1 | 76.4 | 218 | 294 | text_on_stream |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Holding one library still is not a claim about every writer of that format.

**N = 1, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`, `rybakit-msgpack`, `protobuf`.

