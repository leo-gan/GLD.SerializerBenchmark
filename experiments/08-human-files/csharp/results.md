# Experiment 8 results — csharp

**Date:** 2026-09-30
**Raw file:** `experiments/08-human-files/csharp/logs/csharp/2026-09-29-184435.csv`
**Language:** csharp
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| System.Text.Json | 8.0.0.0 | 43.9 | 39.2 | 84.0 | 440 | 254 | JSON | fastest | yes | 97 |
| MS XmlSerializer | .NET 8.0.28 | 57.0 | 53.3 | 111 | 1258 | 390 | XML | slower | yes | 95 |
| YamlDotNet | 17.1.0 | 428 | 356 | 778 | 421 | 246 | YAML | slower | yes | 93 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| System.Text.Json | 8.0.0.0 | 27.6 | 17.8 | 45.4 | 410 | 254 | JSON | fastest | yes | 78 |
| MS XmlSerializer | .NET 8.0.28 | 50.5 | 69.3 | 119 | 1187 | 390 | XML | slower | yes | 91 |
| YamlDotNet | 17.1.0 | 397 | 321 | 727 | 406 | 246 | YAML | slower | yes | 97 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| System.Text.Json | 1 | 43.5 | 35.8 | 79.0 | text_on_stream |
| MS XmlSerializer | 1 | 59.5 | 68.6 | 132 | text_on_stream |
| YamlDotNet | 1 | 605 | 541 | 1151 | text_on_stream |
| System.Text.Json | 1 | 30.4 | 27.1 | 58.4 | text_on_stream |
| MS XmlSerializer | 1 | 63.9 | 83.3 | 147 | text_on_stream |
| YamlDotNet | 1 | 475 | 365 | 846 | text_on_stream |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `System.Text.Json`. Small gap: —. Time/size front: `System.Text.Json`, `YamlDotNet`.

**sample E (words), N = 1, memory** — not clearly slower: `System.Text.Json`. Small gap: —. Time/size front: `System.Text.Json`, `YamlDotNet`.

