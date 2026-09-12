# Mojo Serializer Benchmark

Native Mojo 1.0 benchmark runner for Data Model v2 fixtures (`message`, `document`, `telemetry`, `strings`, `event`).

## Serializers (9)

| Name | Category | Package | Notes |
|------|----------|---------|-------|
| EmberJson | JSON | emberjson 0.3.4 | Reflection `serialize` / `deserialize` |
| ehsanmok-json | JSON | ehsanmok/json 0.3.1 | `serialize_json` encode; `loads` + Value walk decode |
| mojo-json | JSON | leo-gan/gld-json 0.3.0 | Typed WireWriter / WireReader encode / decode (vendored sources) |
| mojo-cbor | Binary | leo-gan/gld-cbor | `CborDatum` encode / decode (vendored sources) |
| mojo-protobuf | Schema | leo-gan/gld-protobuf | Generated suite messages (vendored sources) |
| mojo-avro | Schema | leo-gan/gld-avro | `AvroDatum` encode / decode (conda) |
| mojo-toml | Text | DataBooth/mojo-toml | `to_toml` / `parse` (vendored source) |
| mojo-yaml | Text | leo-gan/gld-yaml 0.2.0 | `YamlValue` encode / decode (vendored sources) |
| mojo-msgpack | Binary | leo-gan/gld-messagepack 0.3.0 | WireWriter / WireReader (vendored sources) |

mojo-avro’s conda package owns the `runtime` / `wire` / `json` module names. JSON, CBOR, Protobuf, YAML, and MessagePack are compiled from `vendor/` with those internals renamed so they can live in one process. `./mojo/scripts/fetch-vendors.sh` prefers sibling checkouts under `…/GLD/gld-*` and falls back to GitHub.

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
