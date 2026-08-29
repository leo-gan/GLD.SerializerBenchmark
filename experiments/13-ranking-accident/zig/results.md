# Experiment 13 results — zig

**Date:** 2026-08-29
**Raw file:** `experiments/13-ranking-accident/zig/logs/zig/2026-08-28-173417.csv`
**Language:** zig
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| serde.json | 1.0.7 | 1.04 | 1.35 | 2.38 | 448 | 2758 | comptime framework — JSON | fastest | yes | 90 |
| std.json.scanner | 0.16.0 | 0.99 | 2.42 | 3.40 | 448 | 2758 | official streaming Scanner | slower | yes | 88 |
| std.json | 0.16.0 | 0.99 | 2.41 | 3.41 | 448 | 2758 | official stdlib typed JSON | slower | yes | 86 |

## In memory — sample A (order), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| serde.json | 1.0.7 | 107 | 126 | 233 | 45707 | 2758 | comptime framework — JSON | fastest | yes | 84 |
| std.json.scanner | 0.16.0 | 100 | 231 | 332 | 45707 | 2758 | official streaming Scanner | slower | yes | 83 |
| std.json | 0.16.0 | 101 | 232 | 332 | 45707 | 2758 | official stdlib typed JSON | slower | yes | 80 |

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| serde.json | 1.0.7 | 0.64 | 0.77 | 1.40 | 257 | 2758 | comptime framework — JSON | fastest | yes | 93 |
| std.json | 0.16.0 | 0.59 | 1.48 | 2.07 | 257 | 2758 | official stdlib typed JSON | slower | yes | 90 |
| std.json.scanner | 0.16.0 | 0.60 | 1.48 | 2.08 | 257 | 2758 | official streaming Scanner | slower | yes | 91 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| serde.json | 1.0.7 | 61.0 | 73.0 | 134 | 26049 | 2758 | comptime framework — JSON | fastest | yes | 86 |
| std.json.scanner | 0.16.0 | 57.0 | 131 | 188 | 26049 | 2758 | official streaming Scanner | slower | yes | 84 |
| std.json | 0.16.0 | 57.0 | 131 | 188 | 26049 | 2758 | official stdlib typed JSON | slower | yes | 87 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| serde.json | 1.0.7 | 0.46 | 0.56 | 1.02 | 168 | 2758 | comptime framework — JSON | fastest | yes | 90 |
| std.json.scanner | 0.16.0 | 0.44 | 0.78 | 1.22 | 168 | 2758 | official streaming Scanner | slower | yes | 93 |
| std.json | 0.16.0 | 0.44 | 0.79 | 1.23 | 168 | 2758 | official stdlib typed JSON | slower | yes | 90 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| serde.json | 1.0.7 | 35.6 | 45.3 | 80.9 | 16849 | 2758 | comptime framework — JSON | fastest | yes | 85 |
| std.json.scanner | 0.16.0 | 32.3 | 62.6 | 95.2 | 16849 | 2758 | official streaming Scanner | slower | yes | 86 |
| std.json | 0.16.0 | 32.3 | 63.4 | 95.4 | 16849 | 2758 | official stdlib typed JSON | slower | yes | 83 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| serde.json | 1.0.7 | 0.91 | 1.03 | 1.95 | 411 | 2758 | comptime framework — JSON | fastest | yes | 94 |
| std.json.scanner | 0.16.0 | 0.83 | 2.22 | 3.05 | 411 | 2758 | official streaming Scanner | slower | yes | 93 |
| std.json | 0.16.0 | 0.84 | 2.29 | 3.14 | 411 | 2758 | official stdlib typed JSON | slower | yes | 91 |

## In memory — sample E (words), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| serde.json | 1.0.7 | 100 | 116 | 217 | 41734 | 2758 | comptime framework — JSON | fastest | yes | 85 |
| std.json.scanner | 0.16.0 | 111 | 246 | 358 | 41734 | 2758 | official streaming Scanner | slower | yes | 85 |
| std.json | 0.16.0 | 111 | 247 | 359 | 41734 | 2758 | official stdlib typed JSON | slower | yes | 87 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| serde.json | 1.0.7 | 1.34 | 1.55 | 2.90 | 663 | 2758 | comptime framework — JSON | fastest | yes | 92 |
| std.json | 0.16.0 | 1.37 | 2.44 | 3.81 | 663 | 2758 | official stdlib typed JSON | slower | yes | 93 |
| std.json.scanner | 0.16.0 | 1.37 | 2.44 | 3.82 | 663 | 2758 | official streaming Scanner | slower | yes | 93 |

## In memory — sample C (sensor), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| serde.json | 1.0.7 | 148 | 143 | 291 | 66261 | 2758 | comptime framework — JSON | fastest | yes | 82 |
| std.json.scanner | 0.16.0 | 145 | 219 | 364 | 66261 | 2758 | official streaming Scanner | slower | yes | 88 |
| std.json | 0.16.0 | 145 | 219 | 364 | 66261 | 2758 | official stdlib typed JSON | slower | yes | 84 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `serde.json`. Small gap: —. Time/size front: `serde.json`.

**sample A (order), N = 100, memory** — not clearly slower: `serde.json`. Small gap: —. Time/size front: `serde.json`.

**sample D (event), N = 1, memory** — not clearly slower: `serde.json`. Small gap: —. Time/size front: `serde.json`.

**sample D (event), N = 100, memory** — not clearly slower: `serde.json`. Small gap: —. Time/size front: `serde.json`.

**sample B (flat), N = 1, memory** — not clearly slower: `serde.json`. Small gap: —. Time/size front: `serde.json`.

**sample B (flat), N = 100, memory** — not clearly slower: `serde.json`. Small gap: —. Time/size front: `serde.json`.

**sample E (words), N = 1, memory** — not clearly slower: `serde.json`. Small gap: —. Time/size front: `serde.json`.

**sample E (words), N = 100, memory** — not clearly slower: `serde.json`. Small gap: —. Time/size front: `serde.json`.

**sample C (sensor), N = 1, memory** — not clearly slower: `serde.json`. Small gap: —. Time/size front: `serde.json`.

**sample C (sensor), N = 100, memory** — not clearly slower: `serde.json`. Small gap: —. Time/size front: `serde.json`.

