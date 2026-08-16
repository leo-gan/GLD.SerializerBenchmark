# Experiment 1 results — csharp

**Date:** 2026-08-16
**Raw file:** `experiments/01-json-library-bakeoff/csharp/logs/csharp/2026-08-16-150610.csv`
**Language:** csharp
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 7.61 | 5.39 | 12.9 | 440 | — | yes | fastest | yes | 91 |
| NetJSON | 1.0.0 | 10.6 | 12.5 | 23.0 | 440 | — | yes | slower | yes | 90 |
| Utf8Json | 1.3.7 | 12.6 | 13.9 | 26.3 | 440 | — | yes | slower | yes | 90 |
| MS Bond Json | .NET 8.0.28 | 17.6 | 18.8 | 36.2 | 440 | — | yes | slower | yes | 90 |
| Jil | 2.17.0 | 23.9 | 14.4 | 38.4 | 440 | — | yes | slower | yes | 88 |
| System.Text.Json | 8.0.0.0 | 32.2 | 31.8 | 63.9 | 588 | — | yes | slower | yes | 93 |
| ServiceStack Json | 6.11.0 | 37.5 | 35.0 | 72.4 | 440 | — | yes | slower | yes | 87 |
| fastJson | 2.4.0.4 | 37.2 | 48.4 | 85.7 | 972 | — | yes | slower | yes | 91 |
| Json.Net (Helper) | 13.0.4 | 38.6 | 46.7 | 86.9 | 541 | — | yes | slower | yes | 90 |
| Json.Net | 13.0.4 | 37.3 | 49.0 | 87.3 | 560 | — | yes | slower | yes | 91 |
| FsPicklerJson | 5.3.2 | 47.8 | 43.7 | 92.6 | 1024 | — | yes | slower | yes | 91 |
| MS DataContract Json | .NET 8.0.28 | 32.0 | 60.5 | 93.2 | 588 | — | yes | slower | yes | 95 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| SpanJson | 9.55 | 7.88 | 17.6 | text_on_stream |
| Utf8Json | 13.1 | 16.2 | 29.2 | text_on_stream |
| NetJSON | 11.8 | 17.5 | 29.7 | copied |
| Jil | 24.4 | 16.9 | 41.5 | text_on_stream |
| MS Bond Json | 18.9 | 23.4 | 43.2 | text_on_stream |
| System.Text.Json | 32.8 | 28.7 | 61.4 | text_on_stream |
| ServiceStack Json | 41.2 | 41.8 | 83.0 | text_on_stream |
| fastJson | 37.6 | 55.3 | 92.4 | copied |
| FsPicklerJson | 47.3 | 46.3 | 92.7 | text_on_stream |
| Json.Net | 40.4 | 55.8 | 96.3 | text_on_stream |
| MS DataContract Json | 35.1 | 71.2 | 105 | text_on_stream |
| Json.Net (Helper) | 46.6 | 58.6 | 107 | text_on_stream |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest named-JSON library?

**Not clearly slower on this sample:** `SpanJson`.
**Not both slower and larger than another named-JSON library:** `SpanJson`.

