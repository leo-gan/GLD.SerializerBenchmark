# Analysis updates (applied)

Status as of the Rust harness expansion:

| Item | Status |
|------|--------|
| Inventory in `serialization_categories.md` | **Done** — `prost`, direct minicbor/rkyv, bson/nanoserde/speedy |
| Full run + `analyze-benchmarks -l rust` | **Done** — see `logs/rust/2026-07-02-152534.csv`, `docs/rust/results.md` |
| Optional CSV `NativeKind` / `StreamMode` | **Done** — written by Rust harness; parser accepts if present |
| Within-category pivots (Rust) | **Done** — section in `docs/rust/results.md` |
| Fidelity notes (prost/rkyv/simd-json) | **Done** — in results.md |

Future optional work:

- Emit `NativeKind`/`StreamMode` from Python/C#/JS harnesses for cross-language metadata.
- Category maps for other languages (Python already has inventory docs).
