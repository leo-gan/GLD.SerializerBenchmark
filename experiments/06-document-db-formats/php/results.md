# Experiment 6 results — php

**Date:** 2026-10-11
**Raw file:** `experiments/06-document-db-formats/php/logs/php/2026-10-11-150301.csv`
**Language:** php
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 1.91 | 4.51 | 6.42 | 454 | 231 | JSON | fastest | yes | 96 |
| rybakit-msgpack | v0.9.2 | 9.42 | 12.4 | 21.8 | 335 | 232 | MessagePack | slower | yes | 84 |
| cbor | 3.4.1 | 69.2 | 73.8 | 143 | 339 | 225 | CBOR | slower | yes | 84 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`, `rybakit-msgpack`.

