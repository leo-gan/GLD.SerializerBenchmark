# Suite data model (v2)

This page is a **short pointer**. The full data-type catalog, size knobs, run configs, and generator contracts live in one place:

**→ [Test data configuration](test_data_configuration.md)**

### Why “v2”?

The suite’s public sample shapes are versioned as **data model v2**. Each type has a **data set**, the parent of the data type. The **suite** set is `message`, `document`, `telemetry`, `strings`, and `event`, at `@n=1` and `@n=100`. The **columnar** set is `table`, `table_project`, `nested_table`, and `signal` (the aligned record). Columnar cells are selected by `config/library/columnar.yaml`, not by the default matrix. A serializer is measured only on the data sets it supports. Older internal names still appear in some code paths as “fixture”; **user-facing docs say data type**. The catalog is `schemas/data_catalog_v2.yaml`. Standard ids live in `compliance/serializer-standards.json` and the dimension contract is `config/dimensions.yaml`.

### What to read next

| Need | Page |
|------|------|
| Shapes, sizes, CSV names | [Test data](test_data_configuration.md) |
| Bytes vs stream, smoke vs full | [Modes](modes.md) |
| How rows become published numbers | [Methodology](ANALYSIS_METHODOLOGY.md) |
| Wire labs (Protobuf-oriented) | [Serialization 401](../theory/401/index.md) |
