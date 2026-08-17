# Experiment 8 results — csharp

**Date:** 2026-08-17
**Raw file:** `experiments/08-human-files/csharp/logs/csharp/2026-08-17-110433.csv`
**Language:** csharp
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| System.Text.Json | 8.0.0.0 | 53.9 | 41.8 | 96.3 | 588 | — | JSON | fastest | yes | 99 |
| MS XmlSerializer | .NET 8.0.28 | 58.7 | 67.5 | 128 | 1258 | — | XML | close | yes | 96 |
| YamlDotNet | 17.1.0 | 466 | 391 | 867 | 421 | — | YAML | slower | yes | 93 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| System.Text.Json | 8.0.0.0 | 34.4 | 25.9 | 60.3 | 548 | — | JSON | fastest | yes | 97 |
| MS XmlSerializer | .NET 8.0.28 | 56.1 | 83.4 | 140 | 1187 | — | XML | slower | yes | 91 |
| YamlDotNet | 17.1.0 | 426 | 319 | 746 | 406 | — | YAML | slower | yes | 95 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| System.Text.Json | 1 | 43.6 | 40.3 | 83.2 | text_on_stream |
| MS XmlSerializer | 1 | 59.5 | 70.8 | 136 | text_on_stream |
| YamlDotNet | 1 | 461 | 381 | 873 | text_on_stream |
| System.Text.Json | 1 | 26.6 | 22.8 | 48.5 | text_on_stream |
| MS XmlSerializer | 1 | 47.1 | 69.6 | 119 | text_on_stream |
| YamlDotNet | 1 | 395 | 324 | 722 | text_on_stream |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `System.Text.Json`. Small gap: `MS XmlSerializer`. Time/size front: `System.Text.Json`, `YamlDotNet`.

**sample E (words), N = 1, memory** — not clearly slower: `System.Text.Json`. Small gap: —. Time/size front: `System.Text.Json`, `YamlDotNet`.

