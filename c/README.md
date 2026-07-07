# C Serializer Benchmark

Native C harness emitting timestamped `logs/c/YYYY-MM-DD-HHMMSS.csv` (nanoseconds, `Language=c`).

## Serializers (19)

See [docs/c/index.md](../docs/c/index.md) for the full inventory (JSON / binary / schema). All registered entries use **real library APIs** (or documented in-tree codecs for `ubj` and `upb` wire).

## Dependencies

```bash
./c/scripts/fetch-and-build-deps.sh   # once; vendors + builds static deps
```

Requires: `cmake`, `curl`, `pkg-config`, `libjson-c-dev` (or equivalent), `zlib`, `liblzma` for avro-c.

## Build & run

```bash
./scripts/run-benchmarks.sh smoke
./scripts/run-benchmarks.sh full
```

Analysis: install `analysis/`, then `analyze-benchmarks -l c` (see root README).
