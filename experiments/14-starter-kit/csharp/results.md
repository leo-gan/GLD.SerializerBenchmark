# Experiment 14 results — csharp

**Date:** 2026-08-29
**Raw file:** `experiments/14-starter-kit/csharp/logs/csharp/2026-08-28-182304.csv`
**Language:** csharp
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 8.36 | 5.84 | 14.1 | 440 | 237 | yes | fastest | yes | 88 |
| MessagePack-CSharp | 2.5.302 | 13.4 | 8.69 | 22.1 | 188 | 184 | yes | slower | yes | 89 |
| Google.Protobuf | 3.35.1 | 11.7 | 10.6 | 22.3 | 208 | 202 | yes | slower | yes | 91 |
| System.Text.Json | 8.0.0.0 | 35.2 | 31.7 | 68.7 | 440 | 237 | yes | slower | yes | 93 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| SpanJson | 9.52 | 6.76 | 16.3 | text_on_stream |
| Google.Protobuf | 9.70 | 10.3 | 20.1 | real |
| MessagePack-CSharp | 19.5 | 9.43 | 29.0 | real |
| System.Text.Json | 32.8 | 33.2 | 65.7 | text_on_stream |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest library in this starter kit? A faster row is not automatically the right public format.

**Not clearly slower on this sample:** `SpanJson`.
**Not both slower and larger than another library in the kit:** `SpanJson`, `MessagePack-CSharp`.

