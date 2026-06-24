# Rust Ecosystem

Rust serialization is dominated by the **serde** data model: libraries implement `Serialize`/`Deserialize` once, then plug in format backends.

## Benchmark harness

- Directory: `rust/` (repository root)
- Output: `logs/rust/benchmark-log.csv` (`Language=rust`, times in **nanoseconds**)
- Runner: `rust/scripts/run-benchmarks.sh {smoke|all-single|full|research}`

## Design choices

1. **Prepare outside the loop** — fixtures built once with seed `42`.
2. **Optimal APIs** — `to_vec`/`from_slice` style; no pretty-print; named MessagePack maps via `to_vec_named`.
3. **Dual mode** — `bytes` and `stream` (stream currently uses the same buffer path; extend with `Write`/`Read` adapters per crate for stricter stream realism).
4. **ObjectGraph** — skipped (most serde formats do not support cycles without extensions).

## Serializers

See [Rust tested serializers](rust_tested_serializers.md).
