"""
Dagr schema for GLD.SerializerBenchmark Data Model v2.

Mirrors schemas/v2/protobuf/benchmark_v2.proto: one DataGraph per suite type, rooted at
that type (the harness frames N instances itself, so no Batch_* wrappers). Every node is
`packed` — the layout Dagr recommends for evolving, schema-driven payloads.
Regenerate with `dagr build` (emits the per-language code + dagr.lock.json).
"""

from dagr.dsl import DataGraph, Node, raw, t
from dagr.config import Library, Rust, Swift, Go, TypeScript, Python, Mojo

MessageGraph = DataGraph('MessageGraph', root_type=t.ref('Message'), node_types=[
    Node('Message', fields=[
        'f_bool' >> t.bool,
        'f_int32' >> t.i32,
        'f_int64' >> t.i64,
        'f_float64' >> t.f64,
        'f_string' >> t.utf8,
        'f_bool_2' >> t.bool,
        'f_int32_2' >> t.i32,
        'f_string_2' >> t.utf8,
    ], packed=True),
])

DocumentGraph = DataGraph('DocumentGraph', root_type=t.ref('Document'), node_types=[
    Node('DocumentMeta', fields=[
        'region' >> t.utf8,
        'version' >> t.i32,
    ], packed=True),
    Node('DocumentItem', fields=[
        'sku' >> t.utf8,
        'qty' >> t.i32,
        'price_minor' >> t.i64,
    ], packed=True),
    Node('Document', fields=[
        'id' >> t.utf8,
        'status' >> t.i32,
        'meta' >> t.ref('DocumentMeta'),
        'items' >> t.ref('DocumentItem').array,
    ], packed=True),
])

TelemetryGraph = DataGraph('TelemetryGraph', root_type=t.ref('Telemetry'), node_types=[
    Node('Telemetry', fields=[
        'source' >> t.utf8,
        'ts' >> t.i64,
        'tags' >> t.utf8.array,
        # Random doubles don't compress: `raw` stores them native-LE (spec/39), as
        # protobuf's packed `repeated double` does, instead of probing each element.
        'values' >> t.f64.array >> raw,
    ], packed=True),
])

StringsGraph = DataGraph('StringsGraph', root_type=t.ref('Strings'), node_types=[
    Node('Strings', fields=[
        'items' >> t.utf8.array,
    ], packed=True),
])

EventGraph = DataGraph('EventGraph', root_type=t.ref('Event'), node_types=[
    Node('EventAttr', fields=[
        'key' >> t.utf8,
        'value' >> t.utf8,
    ], packed=True),
    Node('Event', fields=[
        'event_id' >> t.utf8,
        'event_type' >> t.utf8,
        'occurred_at' >> t.i64,
        'producer' >> t.utf8,
        'attrs' >> t.ref('EventAttr').array,
    ], packed=True),
])

library = Library(
    'BenchmarkV2',
    schemas=[MessageGraph, DocumentGraph, TelemetryGraph, StringsGraph, EventGraph],
    # Output dirs are relative to this directory; each lands where that language's
    # harness keeps its other generated code.
    targets=[
        Rust(out="../../../rust/dagr_gen", features=["lazy"]),
        Swift(out="../../../swift/DagrGen", features=["lazy"]),
        Go(out="../../../go/gen/dagrv2", package="dagrv2"),
        TypeScript(out="../../../javascript/src/generated/dagr"),
        Python(out="../../../python/generated/dagr"),
        Mojo(out="../../../mojo/src/gen/dagr"),
    ],
    wire_format_version=1,
)
