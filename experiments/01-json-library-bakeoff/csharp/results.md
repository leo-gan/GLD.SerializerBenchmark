# Experiment 1 results — csharp

**Date:** 2026-09-30
**Raw file:** `experiments/01-json-library-bakeoff/csharp/logs/csharp/2026-09-29-184038.csv`
**Language:** csharp
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 8.61 | 5.53 | 14.2 | 440 | 237 | yes | fastest | yes | 88 |
| NetJSON | 1.0.0 | 9.66 | 12.9 | 22.7 | 440 | 237 | yes | slower | yes | 91 |
| Utf8Json | 1.3.7 | 13.1 | 14.0 | 26.7 | 440 | 237 | yes | slower | yes | 86 |
| MS Bond Json | .NET 8.0.28 | 18.4 | 19.0 | 37.3 | 440 | 237 | yes | slower | yes | 91 |
| Jil | 2.17.0 | 26.6 | 13.9 | 40.8 | 440 | 241 | yes | slower | yes | 87 |
| System.Text.Json | 8.0.0.0 | 31.9 | 29.7 | 62.0 | 440 | 237 | yes | slower | yes | 87 |
| ServiceStack Json | 6.11.0 | 38.4 | 34.8 | 73.2 | 440 | 237 | yes | slower | yes | 91 |
| fastJson | 2.4.0.4 | 37.5 | 49.8 | 87.0 | 972 | 363 | yes | slower | yes | 95 |
| MS DataContract Json | .NET 8.0.28 | 31.4 | 56.5 | 87.8 | 440 | 237 | yes | slower | yes | 94 |
| FsPicklerJson | 5.3.2 | 48.7 | 42.7 | 91.9 | 768 | 422 | yes | slower | yes | 93 |
| Json.Net | 13.0.4 | 41.7 | 50.3 | 92.6 | 560 | 265 | yes | slower | yes | 96 |
| Json.Net (Helper) | 13.0.4 | 44.1 | 49.8 | 93.9 | 541 | 264 | yes | slower | yes | 93 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| SpanJson | 10.3 | 7.42 | 17.8 | text_on_stream |
| NetJSON | 11.2 | 17.3 | 28.5 | copied |
| Utf8Json | 14.4 | 17.4 | 31.8 | text_on_stream |
| Jil | 27.2 | 17.8 | 45.4 | text_on_stream |
| MS Bond Json | 20.6 | 25.7 | 46.1 | text_on_stream |
| System.Text.Json | 32.1 | 25.6 | 58.3 | text_on_stream |
| ServiceStack Json | 41.5 | 40.8 | 82.1 | text_on_stream |
| fastJson | 35.6 | 52.9 | 89.3 | copied |
| MS DataContract Json | 32.2 | 58.3 | 90.8 | text_on_stream |
| FsPicklerJson | 53.4 | 52.5 | 107 | text_on_stream |
| Json.Net | 49.7 | 64.6 | 113 | text_on_stream |
| Json.Net (Helper) | 53.0 | 63.5 | 117 | text_on_stream |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest named-JSON library?

**Not clearly slower on this sample:** `SpanJson`.
**Not both slower and larger than another named-JSON library:** `SpanJson`.

