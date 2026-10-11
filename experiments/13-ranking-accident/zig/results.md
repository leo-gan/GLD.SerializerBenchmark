# Experiment 13 results — zig

**Date:** 2026-10-11
**Raw file:** `experiments/13-ranking-accident/zig/logs/zig/2026-10-11-151039.csv`
**Language:** zig
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| serde.json | 1.2.2 | 0.96 | 1.52 | 2.48 | 448 | 2758 | comptime framework — JSON | fastest | yes | 92 |
| std.json.scanner | 0.16.0 | 0.86 | 2.22 | 3.09 | 448 | 2758 | official streaming Scanner | slower | yes | 88 |
| std.json | 0.16.0 | 0.88 | 2.27 | 3.12 | 448 | 2758 | official stdlib typed JSON | slower | yes | 90 |

## In memory — sample A (order), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| serde.json | 1.2.2 | 84.3 | 134 | 219 | 45707 | 2758 | comptime framework — JSON | fastest | yes | 84 |
| std.json.scanner | 0.16.0 | 79.2 | 185 | 264 | 45707 | 2758 | official streaming Scanner | slower | yes | 86 |
| std.json | 0.16.0 | 78.5 | 185 | 264 | 45707 | 2758 | official stdlib typed JSON | slower | yes | 79 |

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| serde.json | 1.2.2 | 0.63 | 0.89 | 1.53 | 257 | 2758 | comptime framework — JSON | fastest | yes | 92 |
| std.json | 0.16.0 | 0.53 | 1.36 | 1.88 | 257 | 2758 | official stdlib typed JSON | slower | yes | 91 |
| std.json.scanner | 0.16.0 | 0.54 | 1.36 | 1.91 | 257 | 2758 | official streaming Scanner | slower | yes | 90 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| serde.json | 1.2.2 | 46.9 | 72.5 | 119 | 26049 | 2758 | comptime framework — JSON | fastest | yes | 83 |
| std.json.scanner | 0.16.0 | 45.2 | 98.9 | 144 | 26049 | 2758 | official streaming Scanner | slower | yes | 90 |
| std.json | 0.16.0 | 45.6 | 99.8 | 146 | 26049 | 2758 | official stdlib typed JSON | slower | yes | 77 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| serde.json | 1.2.2 | 0.39 | 0.56 | 0.94 | 168 | 2758 | comptime framework — JSON | fastest | yes | 95 |
| std.json.scanner | 0.16.0 | 0.34 | 0.70 | 1.04 | 168 | 2758 | official streaming Scanner | slower | yes | 91 |
| std.json | 0.16.0 | 0.35 | 0.73 | 1.07 | 168 | 2758 | official stdlib typed JSON | slower | yes | 94 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| serde.json | 1.2.2 | 25.1 | 39.5 | 64.9 | 16849 | 2758 | comptime framework — JSON | fastest | yes | 93 |
| std.json | 0.16.0 | 23.9 | 52.9 | 76.7 | 16849 | 2758 | official stdlib typed JSON | slower | yes | 89 |
| std.json.scanner | 0.16.0 | 24.0 | 53.5 | 77.6 | 16849 | 2758 | official streaming Scanner | slower | yes | 95 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| serde.json | 1.2.2 | 0.78 | 1.24 | 2.03 | 411 | 2758 | comptime framework — JSON | fastest | yes | 92 |
| std.json.scanner | 0.16.0 | 0.71 | 1.98 | 2.68 | 411 | 2758 | official streaming Scanner | slower | yes | 95 |
| std.json | 0.16.0 | 0.71 | 1.99 | 2.70 | 411 | 2758 | official stdlib typed JSON | slower | yes | 95 |

## In memory — sample E (words), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| serde.json | 1.2.2 | 81.6 | 141 | 223 | 41734 | 2758 | comptime framework — JSON | fastest | yes | 85 |
| std.json.scanner | 0.16.0 | 85.7 | 176 | 262 | 41734 | 2758 | official streaming Scanner | slower | yes | 86 |
| std.json | 0.16.0 | 87.3 | 176 | 264 | 41734 | 2758 | official stdlib typed JSON | slower | yes | 80 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| serde.json | 1.2.2 | 1.44 | 1.81 | 3.28 | 663 | 2758 | comptime framework — JSON | fastest | yes | 95 |
| std.json.scanner | 0.16.0 | 1.35 | 2.27 | 3.64 | 663 | 2758 | official streaming Scanner | slower | yes | 89 |
| std.json | 0.16.0 | 1.42 | 2.33 | 3.75 | 663 | 2758 | official stdlib typed JSON | slower | yes | 95 |

## In memory — sample C (sensor), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| serde.json | 1.2.2 | 132 | 165 | 298 | 66261 | 2758 | comptime framework — JSON | fastest | yes | 78 |
| std.json | 0.16.0 | 132 | 195 | 327 | 66261 | 2758 | official stdlib typed JSON | slower | yes | 80 |
| std.json.scanner | 0.16.0 | 132 | 194 | 327 | 66261 | 2758 | official streaming Scanner | slower | yes | 84 |

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

