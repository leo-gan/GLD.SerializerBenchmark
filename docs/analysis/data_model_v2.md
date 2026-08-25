# Suite data model (v2)

This page is a **short pointer**. The full data-type catalog, size knobs, run configs, and generator contracts live in one place:

**→ [Test data configuration](test_data_configuration.md)**

### Why “v2”?

The suite’s public sample shapes are versioned as **data model v2**: five data types (`message`, `document`, `telemetry`, `strings`, `event`), optional batch sizes (`@n=1`, `@n=100`), and a shared catalog (`schemas/data_catalog_v2.yaml`). Older internal names still appear in some code paths as “fixture”; **user-facing docs say data type**.

### What to read next

| Need | Page |
|------|------|
| Shapes, sizes, CSV names | [Test data](test_data_configuration.md) |
| Bytes vs stream, smoke vs full | [Modes](modes.md) |
| How rows become published numbers | [Methodology](ANALYSIS_METHODOLOGY.md) |
| Wire labs (Protobuf-oriented) | [Serialization 401](../theory/401/index.md) |
