# Benchmark Results

This page is a **static index** of per-language result snapshots. Pivot tables and violin plots live on each language **Results** page (maintainer-generated locally; not rewritten by CI).

Numbers on those pages depend on the machine and CSV used to generate them. Re-running benchmarks elsewhere may differ — that is expected.

## Results by language

- [C# results](../c-sharp/results.md)
- [Python results](../python/results.md)
- [Rust results](../rust/results.md)
- [C results](../c/results.md)
- [JavaScript results](../javascript/results.md)
- [Go results](../go/results.md)

## Inventories (what we measure)

Hand-written overviews (serializer lists and caveats):

- [C#](../c-sharp/index.md) · [Python](../python/index.md) · [Rust](../rust/index.md) · [C](../c/index.md) · [JavaScript](../javascript/index.md) · [Go](../go/index.md)

Related:

- [Serialization categories](serialization_categories.md)
- [Analysis methodology](ANALYSIS_METHODOLOGY.md)
- [Benchmark architecture](architecture.md)

## Regenerating language snapshots

This hub file is **not** rewritten by `analyze-benchmarks`. To refresh a language’s tables and plots only:

```bash
analyze-benchmarks -l python   # or rust, csharp, c, javascript, go
# or all languages (still does not modify this hub):
analyze-benchmarks
```

Commit the updated `docs/<lang>/results.md` and `docs/analysis/plots/violin/<lang>_*.png` paths as needed.
