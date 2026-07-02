# Proposed analysis updates (not applied yet)

After the Rust harness expansion, consider these analysis-side changes when you are ready:

1. **Serializer inventory docs** — `docs/analysis/serialization_categories.md` still lists older Rust names (`prost-wire`, envelope minicbor/rkyv). Update to `prost`, direct `minicbor`/`rkyv`, and new `bson` / `nanoserde` / `speedy`.

2. **Results regeneration** — run a full `cargo run --release -- 100` into `logs/rust/`, then:
   ```bash
   analyze-benchmarks -l rust
   ```
   to refresh `docs/rust/results.md` and `docs/analysis/plots/violin/rust_*.png`.

3. **Optional CSV columns** (future) — Python-style `native_kind` / `stream_mode` are on the Rust trait but not written to CSV yet. Adding optional columns would need a coordinated multi-language schema change in `analysis/`.

4. **Category pivots** — bitcode/speedy/nanoserde/bincode/postcard should be compared **within** “Rust-centric binary”; sonic-rs vs serde_json within JSON; prost alone in schema.

5. **Fidelity notes** — prost datetime ms conversion may need the same semantic datetime tolerance the Python comparer uses if strict JSON equality is re-enabled in analysis.
