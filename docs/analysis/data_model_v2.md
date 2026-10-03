# Suite data model (v2)

This page is a **short pointer**. The full data-type catalog, size knobs, run configs, and generator contracts live in one place:

**→ [Test data configuration](test_data_configuration.md)**

### Why “v2”?

The suite’s public sample shapes are versioned as **data model v2**. The publication matrix is five data types (`message`, `document`, `telemetry`, `strings`, `event`) at `@n=1` and `@n=100`. Four more types live in the same catalog for columnar and aligned-record runs: `table`, `table_project`, `nested_table`, and `signal`. Those cells are selected by `config/library/columnar.yaml`, not by the default matrix. Older internal names still appear in some code paths as “fixture”; **user-facing docs say data type**. The catalog is `schemas/data_catalog_v2.yaml`.

### What to read next

| Need | Page |
|------|------|
| Shapes, sizes, CSV names | [Test data](test_data_configuration.md) |
| Bytes vs stream, smoke vs full | [Modes](modes.md) |
| How rows become published numbers | [Methodology](ANALYSIS_METHODOLOGY.md) |
| Wire labs (Protobuf-oriented) | [Serialization 401](../theory/401/index.md) |
