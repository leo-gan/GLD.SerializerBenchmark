# Arrow IPC

Arrow IPC is the streaming interchange for an Apache Arrow record batch.
The catalog covers the IPC stream format, not the random-access file format.

Spec: [IPC streaming format](https://arrow.apache.org/docs/format/Columnar.html#ipc-streaming-format).

| Version | Catalog |
|---------|---------|
| IPC stream | `compliance/data/arrow/ipc-stream.json` |

Each language decodes with its own Arrow reader. Pass/fail cells are on the [Dashboard → Compliance](../dashboard/#compliance) view, standard **Arrow IPC**.

Fortran `gld-arrow` 0.2.0 is the Arrow C Data Interface for a contiguous numeric array. It does not read an IPC stream. The catalog buffers are rejected: the three illegal streams pass, and the two-row `berth` stream fails.
