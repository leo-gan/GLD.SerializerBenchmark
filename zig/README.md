# Zig Serializer Benchmark

Native Zig benchmark runner for Data Model v2 fixtures (`message`, `document`, `telemetry`, `strings`, `event`).

Zig is in the suite because **comptime reflection** (`@typeInfo`) is a different implementation model from Java/Kotlin reflection, C# source generation, or Rust derives. The runner measures official `std.json` / `std.zon`, an in-tree comptime byte-packed baseline, serde.zig (JSON / MessagePack / YAML / TOML / ZON / XML), zig-msgpack, msgpack.zig, zbor, s2s, and schema codecs (protobuf, FlatBuffers, Cap’n Proto) generated from the shared suite IDLs.

## Serializers

See [docs/zig/index.md](../docs/zig/index.md) for the serializer inventory.

## Host tools

```bash
./scripts/install-host-requirements.sh zig
```

Requires Zig **0.16.x** (latest stable) and Cap’n Proto C++ 1.0.x (`libcapnp` / `libkj`) for the `capnproto` row. The installer places Zig at `~/.local/zig` and Cap’n Proto under `~/.local`.

## Run

```bash
./zig/scripts/run-benchmarks.sh smoke
./zig/scripts/run-benchmarks.sh all-single
```

## Schema codegen

Types come from the shared suite IDLs (not Zig-only schemas):

```bash
./zig/scripts/generate-protobuf.sh
./zig/scripts/generate-flatbuffers.sh
./zig/scripts/generate-capnp.sh
```

## Tests

```bash
cd zig && zig build test
```

Analysis: `analyze-benchmarks -l zig` (see root README).
