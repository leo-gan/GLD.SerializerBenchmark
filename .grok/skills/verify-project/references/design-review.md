# Design review

Read these once per verify. They own the rules. Do not copy them into the report.

| Contract | Path |
|----------|------|
| Timing, isolation, hot path | `docs/analysis/TIMING_HONESTY.md` |
| CSV, schedule, nanoseconds, modes | `docs/analysis/architecture.md` |
| Data sets and type ids | `docs/analysis/data_model_v2.md`, `schemas/data_catalog_v2.yaml` |
| I/O levels and what `all@` averages | `docs/analysis/modes.md`, `config/dimensions.yaml` |
| How a serializer is added | `docs/analysis/ADDING_A_SERIALIZER.md` |
| Who may publish a second I/O level | `config/dimensions.yaml`, `config/optional-io.txt`, `config/file-only.txt` |
| Standard label for a row | `analysis/src/benchmark_analysis/dimensions.py` (`standard_for`, `data_set_for_type`) |
| Schedule golden vector | `analysis/tests/test_schedule.py` |

A design flaw is a break in one of those contracts, or a second writer for a fact that already has a source in [artifacts.md](artifacts.md). An inconsistency is two artifacts that disagree. Report both. Do not grade style, naming taste, or upstream library quality.

## What to look for

- A label that is not the work: instance count N with one object encoded, stream that calls the bytes API, `native` on an adapted path, a file-only codec also emitting a bytes row.
- Setup inside the timed section: schema compile, codegen, domain mapping, buffer allocation the library says to reuse.
- Suite type names hard-coded in a wrapper when the runner can pass a type or a map. Generated tables and protobuf messages in their own folders are fine.
- `all@` or a ranking average that includes columnar, graph, or array types. Those sets have their own rows.
- A compliance percent with no corpus, or with no adapter in that language. An empty cell is not a score. `custom` / No public spec is unscored, not a failure.
- A published snapshot `sync-data.py` would refuse or would silently drop (columnar, Dagr, graph, or array splice).
- A hand-edited file under a generated tree, or a generator script whose tool version is not the CI version.
- A docs count, serializer list, or mode repetition that is not the registry or the config.
- An experiment whose `run` block does not measure the question in `experiment.yaml`.
- A dashboard control that can select a combination the data model forbids (a suite type while a columnar-only standard is selected, a second I/O level for an excluded language).
- A skill or internal note that a published page now treats as the contract.

## Out of scope

- Performance outliers, package-doc call-path research, and re-bench. That is `/review-suspicious-results`.
- Vendored upstream design. Only the pin and whether the runner matches `VERSIONS.md`.
- Regenerating schemas, snapshots, or the site. Those commands write the tree.
