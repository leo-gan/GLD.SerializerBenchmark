# Experiment 1 results — cpp

**Date:** 2026-09-04
**Raw file:** `experiments/01-json-library-bakeoff/cpp/logs/cpp/2026-09-04-111739.csv`
**Language:** cpp
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| yyjson | 0.10.0 | 4.45 | 18.7 | 23.5 | 458 | 238 | yes | fastest | yes | 95 |
| rapidjson | 1.1.0 | 5.64 | 20.9 | 26.8 | 458 | 238 | yes | slower | yes | 95 |
| simdjson | 3.10.1 | 8.96 | 20.3 | 29.3 | 458 | 238 | yes | slower | yes | 93 |
| arduinojson | 7.2.1 | 7.78 | 27.3 | 35.2 | 458 | 238 | yes | slower | yes | 94 |
| nlohmann_json | 3.11.3 | 9.05 | 26.5 | 35.4 | 458 | 238 | yes | slower | yes | 97 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| yyjson | 2.13 | 9.62 | 11.8 | copied |
| simdjson | 4.65 | 10.2 | 14.9 | copied |
| nlohmann_json | 5.62 | 14.7 | 20.4 | real |
| arduinojson | 7.15 | 19.5 | 26.7 | real |
| rapidjson | 6.88 | 21.5 | 28.7 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest named-JSON library?

**Not clearly slower on this sample:** `yyjson`.
**Not both slower and larger than another named-JSON library:** `yyjson`.

