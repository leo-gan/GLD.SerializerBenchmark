# Parquet

Parquet is a columnar file format. The catalog is an uncompressed file with a footer, not a layout-only size claim. `parquet` and `parquet-uncompressed` share that language’s Parquet reader.

Spec: [Parquet file format](https://parquet.apache.org/docs/file-format/).

| Version | Catalog |
|---------|---------|
| File format | `compliance/data/parquet/file-format.json` |

Pass/fail cells are on the [Dashboard → Compliance](../dashboard/#compliance) view, standard **Parquet**.
