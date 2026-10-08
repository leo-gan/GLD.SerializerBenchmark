# Experiment 14 results — csharp

**Date:** 2026-09-30
**Raw file:** `experiments/14-starter-kit/csharp/logs/csharp/2026-09-29-185659.csv`
**Language:** csharp
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 9.39 | 6.10 | 15.5 | 440 | 237 | yes | fastest | yes | 86 |
| Google.Protobuf | 3.36.2 | 11.3 | 9.64 | 20.9 | 208 | 202 | yes | slower | yes | 80 |
| MessagePack-CSharp | 2.5.305 | 14.5 | 9.29 | 24.0 | 188 | 184 | yes | slower | yes | 87 |
| System.Text.Json | 8.0.0.0 | 33.4 | 30.8 | 64.4 | 440 | 237 | yes | slower | yes | 88 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| SpanJson | 9.85 | 7.25 | 17.1 | text_on_stream |
| Google.Protobuf | 10.0 | 10.7 | 20.7 | real |
| MessagePack-CSharp | 21.0 | 10.2 | 31.6 | real |
| System.Text.Json | 33.2 | 33.7 | 67.2 | text_on_stream |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest library in this starter kit? A faster row is not automatically the right public format.

**Not clearly slower on this sample:** `SpanJson`.
**Not both slower and larger than another library in the kit:** `SpanJson`, `Google.Protobuf`, `MessagePack-CSharp`.

