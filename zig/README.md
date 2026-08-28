# Zig Serializer Benchmark

Native Zig benchmark runner for Data Model v2 fixtures (`message`, `document`, `telemetry`, `strings`, `event`).

Zig is in the suite because **comptime reflection** (`@typeInfo`) is a different implementation model from Java/Kotlin reflection, C# source generation, or Rust derives. The runner measures official `std.json` / `std.zon`, an in-tree comptime byte-packed baseline, serde.zig (JSON / MessagePack / YAML / TOML / ZON / XML), zig-msgpack, msgpack.zig, zbor, and s2s.

## Serializers

See [docs/zig/index.md](../docs/zig/index.md) for the mixed candidate inventory, what is wired, and what was left out.

## Host tools

```bash
./scripts/install-host-requirements.sh zig
```

Requires Zig **0.16.x** (latest stable). The installer places it at `~/.local/zig`.

## Run

```bash
./zig/scripts/run-benchmarks.sh smoke
./zig/scripts/run-benchmarks.sh all-single
```

## Tests

```bash
cd zig && zig build test
```

Analysis: `analyze-benchmarks -l zig` (see root README).
