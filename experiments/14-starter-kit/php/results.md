# Experiment 14 results — php

**Date:** 2026-08-29
**Raw file:** `experiments/14-starter-kit/php/logs/php/2026-08-28-182239.csv`
**Language:** php
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| json | 8.3.19 | 1.85 | 4.23 | 6.14 | 454 | 231 | yes | fastest | yes | 91 |
| rybakit-msgpack | v0.9.2 | 9.47 | 12.5 | 22.0 | 335 | 232 | yes | slower | yes | 75 |
| protobuf | v4.33.6+php | 129 | 70.6 | 199 | 160 | 178 | yes | slower | yes | 84 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| json | 1.93 | 4.27 | 6.27 | text_on_stream |
| rybakit-msgpack | 9.80 | 12.7 | 22.6 | copied |
| protobuf | 129 | 71.2 | 200 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest library in this starter kit? A faster row is not automatically the right public format.

**Not clearly slower on this sample:** `json`.
**Not both slower and larger than another library in the kit:** `json`, `rybakit-msgpack`, `protobuf`.

