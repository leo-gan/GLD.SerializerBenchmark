# C Serializer Benchmark

Native C harness emitting `logs/c/benchmark-log.csv` (nanoseconds, `Language=c`).

## Serializers (12)

| Name | Category | Notes |
|------|----------|-------|
| cJSON | JSON | Minimal JSON write/parse path (cJSON API family) |
| yyjson | JSON | Same minimal path; swap to vendored yyjson for production runs |
| jansson | JSON | Same; link system jansson when available |
| parson | JSON | Same; single-file parson when vendored |
| mpack | Binary | MessagePack-style envelope + packed struct |
| tinycbor | Binary | CBOR-style envelope |
| nanopb | Schema | Protobuf field-1 length-delimited style |
| protobuf-c | Schema | Alternate protobuf envelope |
| flatcc | Schema | FlatBuffers-style tag envelope |
| ubj | Binary | UBJSON-style tag |
| cbor-encode | Binary | libcbor-style tag |
| custom-binary | Binary | Direct struct packing baseline |

> **Honesty note for researchers:** The default build uses a portable minimal codec so CI works without external C deps. For publication runs, vendor/link real libraries and replace `json_write_fixture` / envelope wrappers with optimal APIs (`cJSON_PrintUnformatted`, `yyjson_mut_write`, `mpack_writer`, etc.). See [docs/c/index.md](../docs/c/index.md).

## Build & run

```bash
./scripts/run-benchmarks.sh smoke
./scripts/run-benchmarks.sh full
```

Cross-language analysis and docs snapshots: install `analysis/`, run `analyze-benchmarks` (see root README and [Benchmark architecture — Goals](../docs/analysis/architecture.md)). Write published tables/plots into `docs/analysis/` and `docs/<lang>/results.md` locally and commit; CI does not regenerate them.
