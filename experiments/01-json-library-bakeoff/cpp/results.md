# Experiment 1 results — cpp

**Date:** 2026-08-16
**Raw file:** `experiments/01-json-library-bakeoff/cpp/logs/cpp/2026-08-16-150537.csv`
**Language:** cpp
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| simdjson | 3.10.1 | 0.16 | 8.96 | 9.11 | 458 | — | yes | fastest | yes | 85 |
| nlohmann_json | 3.11.3 | 2.48 | 7.24 | 9.71 | 458 | — | yes | slower | yes | 87 |
| yyjson | 0.10.0 | 1.06 | 9.08 | 10.1 | 458 | — | yes | slower | yes | 84 |
| rapidjson | 1.1.0 | 1.70 | 11.8 | 13.4 | 458 | — | yes | slower | yes | 89 |
| arduinojson | 7.2.1 | 2.70 | 12.9 | 15.6 | 458 | — | yes | slower | yes | 88 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| simdjson | 0.19 | 9.82 | 10.0 | copied |
| yyjson | 1.30 | 9.85 | 11.3 | copied |
| nlohmann_json | 3.77 | 9.64 | 13.4 | real |
| arduinojson | 5.75 | 16.0 | 21.7 | real |
| rapidjson | 4.82 | 19.6 | 24.5 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest named-JSON library?

**Not clearly slower on this sample:** `simdjson`.
**Not both slower and larger than another named-JSON library:** `simdjson`.

