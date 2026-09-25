# Mojo Serializer Benchmark

Native Mojo 1.0 benchmark runner for Data Model v2 fixtures (`message`, `document`, `telemetry`, `strings`, `event`).

## Serializers (14)

| Name | Category | Package | Notes |
|------|----------|---------|-------|
| EmberJson | JSON | emberjson 0.3.4 | Reflection `serialize` / `deserialize` |
| ehsanmok-json | JSON | ehsanmok/json 0.4.0 | `serialize_json` encode; `loads` + Value walk decode |
| mojo-json | JSON | leo-gan/gld-json 0.4.0 | Typed WireWriter / WireReader encode / decode (vendored sources) |
| mojo-cbor | Binary | leo-gan/gld-cbor 0.7.0 | `CborDatum` encode / decode (vendored sources) |
| mojo-protobuf | Schema | leo-gan/gld-protobuf | Generated suite messages (vendored sources) |
| mojo-flatbuffers | Schema | leo-gan/gld-flatbuffers 0.2.0 | Reused Builder and generated tables from `cpp/schemas/benchmark.fbs` (vendored sources) |
| mojo-avro | Schema | leo-gan/gld-avro | `AvroDatum` encode / decode (conda) |
| mojo-toml | Text | DataBooth/mojo-toml | `to_toml` / `parse` (vendored source) |
| gld-yaml | Text | [leo-gan/gld-yaml](https://github.com/leo-gan/gld-yaml) 0.4.0 | `yaml.encode` / `yaml.decode` on suite types (vendored sources) |
| mojo-msgpack | Binary | leo-gan/gld-messagepack 0.3.0 | WireWriter / WireReader (vendored sources) |
| dagr-packed | Schema | dagr 2026.9.0 (generator) | Generated from `schemas/v2/dagr/schema.py` into `src/gen/dagr/`: generated direct builder into one reused `Builder` (`write_{root}_graph_direct`), lazy reader decode (`read_{root}_root`) |
| dagr-regular | Schema | dagr 2026.9.0 (generator) | Same schema, `<Type>RegularGraph` (all nodes `regular`, vtables): no direct builder for this layout, so the suite value is copied into the generated arena and written with `write_{root}_graph(b, arena)` into a reused per-graph `Builder` (both timed); lazy reader decode |
| dagr-frozen | Schema | dagr 2026.9.0 (generator) | Same schema, `<Type>FrozenGraph` (all nodes `frozen`, fixed layout, no evolution): generated arena + `write_{root}_graph` into a reused `Builder` (both timed); lazy reader decode |
| dagr-frozen-packed | Schema | dagr 2026.9.0 (generator) | Same schema, `<Type>FrozenPackedGraph` (all nodes `frozen` + `packed`): generated direct builder into one reused `Builder`, like `dagr-packed`; lazy reader decode |

mojo-avro’s conda package owns the `runtime` / `wire` / `json` module names. JSON, CBOR, Protobuf, YAML, MessagePack, and FlatBuffers are compiled from `vendor/` with those internals renamed so they can live in one process. Dagr's generated code (`src/gen/dagr/`, from `dagr build`) imports its modules by bare name, so builds add `-I src/gen/dagr`. `./mojo/scripts/fetch-vendors.sh` prefers sibling checkouts under `…/GLD/gld-*` and falls back to GitHub.

## Host tools

```bash
./scripts/install-host-requirements.sh mojo
```

That installs [pixi](https://pixi.sh) if needed and runs `pixi install` in `mojo/` (Mojo 1.0, EmberJson, mojo-avro).

## Run

```bash
./mojo/scripts/run-benchmarks.sh smoke
./mojo/scripts/run-benchmarks.sh all-single
./mojo/scripts/run-benchmarks.sh all-single EmberJson message
```

I/O mode is **bytes only**. Times are nanoseconds. `Language=mojo`.
