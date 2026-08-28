# Experiment 1 results — php

**Date:** 2026-08-28
**Raw file:** `experiments/01-json-library-bakeoff/php/logs/php/2026-08-28-113546.csv`
**Language:** php
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| json | 8.3.19 | 1.77 | 4.26 | 6.07 | 454 | 231 | yes | fastest | yes | 90 |
| symfony-json | v7.4.17 | 3.02 | 4.67 | 7.59 | 454 | 231 | yes | slower | yes | 88 |
| jms-json | 3.32.7 | 20.1 | 14.1 | 34.6 | 454 | 231 | yes | slower | yes | 78 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| json | 1.88 | 4.32 | 6.21 | text_on_stream |
| symfony-json | 3.10 | 5.02 | 8.10 | text_on_stream |
| jms-json | 20.2 | 14.3 | 34.4 | text_on_stream |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest named-JSON library?

**Not clearly slower on this sample:** `json`.
**Not both slower and larger than another named-JSON library:** `json`.

