"""
Dagr schema for GLD.SerializerBenchmark Data Model v2.

Mirrors schemas/v2/protobuf/benchmark_v2.proto: one DataGraph per suite type, rooted at
that type (the harness frames N instances itself, so no Batch_* wrappers), in each of the
four node layouts. The packed graphs (`MessageGraph`, …) back the `dagr-packed` rows — the layout
Dagr recommends for evolving, schema-driven payloads; `dagr-regular`, `dagr-frozen` and
`dagr-frozen-packed` use the other three.
Regenerate with `dagr build` (emits the per-language code + dagr.lock.json).
"""

from dagr.dsl import DataGraph, Node, raw, t
from dagr.config import Library, Rust, Swift, Go, TypeScript, Python, Mojo

# The four node layouts (spec/16): packed (tagged, evolvable — the `dagr-packed` row), regular
# (vtable), frozen (positional) and frozen+packed (positional, self-sizing). Frozen layouts
# trade all schema evolution for speed/size, so they compare with speedy / bincode /
# FlatBuffers-style codecs rather than with protobuf.
FLAVOURS = {                  # graph-name suffix -> Node layout kwargs
    "": dict(packed=True),
    "Regular": dict(),
    "Frozen": dict(frozen=True),
    "FrozenPacked": dict(frozen=True, packed=True),
}


def graphs(suffix: str, **layout):
    """The five suite graphs in one layout. Graphs are append-only here (nothing deletes
    nodes), so `deletable=False` drops the arena's generation bookkeeping."""
    def g(name, root, nodes):
        return DataGraph(f"{name}{suffix}Graph", root_type=t.ref(root), node_types=nodes, deletable=False)

    return [
        g("Message", "Message", [
            Node("Message", fields=[
                "f_bool" >> t.bool,
                "f_int32" >> t.i32,
                "f_int64" >> t.i64,
                # The suite's float64s are random full-mantissa doubles (never fit a shorter
                # float form), so the packed probe always ends at 8 raw bytes: `raw` writes
                # them directly.
                "f_float64" >> t.f64 >> raw,
                "f_string" >> t.utf8,
                "f_bool_2" >> t.bool,
                "f_int32_2" >> t.i32,
                "f_string_2" >> t.utf8,
            ], **layout),
        ]),
        g("Document", "Document", [
            Node("DocumentMeta", fields=["region" >> t.utf8, "version" >> t.i32], **layout),
            Node("DocumentItem", fields=["sku" >> t.utf8, "qty" >> t.i32, "price_minor" >> t.i64], **layout),
            Node("Document", fields=[
                "id" >> t.utf8,
                "status" >> t.i32,
                "meta" >> t.ref("DocumentMeta"),
                "items" >> t.ref("DocumentItem").array,
            ], **layout),
        ]),
        g("Telemetry", "Telemetry", [
            Node("Telemetry", fields=[
                "source" >> t.utf8,
                "ts" >> t.i64,
                "tags" >> t.utf8.array,
                # Random doubles don't compress: `raw` stores them native-LE (spec/39), as
                # protobuf's packed `repeated double` does, instead of probing each element.
                "values" >> t.f64.array >> raw,
            ], **layout),
        ]),
        g("Strings", "Strings", [
            Node("Strings", fields=["items" >> t.utf8.array], **layout),
        ]),
        g("Event", "Event", [
            Node("EventAttr", fields=["key" >> t.utf8, "value" >> t.utf8], **layout),
            Node("Event", fields=[
                "event_id" >> t.utf8,
                "event_type" >> t.utf8,
                "occurred_at" >> t.i64,
                "producer" >> t.utf8,
                "attrs" >> t.ref("EventAttr").array,
            ], **layout),
        ]),
    ]


ALL_GRAPHS = [gr for suffix, layout in FLAVOURS.items() for gr in graphs(suffix, **layout)]
# The packed graphs keep their original names (MessageGraph, …) for the `dagr-packed` row.
MessageGraph, DocumentGraph, TelemetryGraph, StringsGraph, EventGraph = ALL_GRAPHS[:5]

library = Library(
    'BenchmarkV2',
    schemas=ALL_GRAPHS,
    # Output dirs are relative to this directory; each lands where that language's
    # harness keeps its other generated code.
    targets=[
        Rust(out="../../../rust/dagr_gen", features=["lazy"]),
        Swift(out="../../../swift/DagrGen", features=["lazy"]),
        # package-per-graph: the flavours share node names (Message, …), so each graph
        # needs its own Go package.
        Go(out="../../../go/gen/dagrv2", package="dagrv2", layout="package-per-graph"),
        TypeScript(out="../../../javascript/src/generated/dagr"),
        Python(out="../../../python/generated/dagr"),
        Mojo(out="../../../mojo/src/gen/dagr"),
    ],
    wire_format_version=1,
)
