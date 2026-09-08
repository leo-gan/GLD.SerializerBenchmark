# Mojo Serializer Benchmark

Native Mojo 1.0 benchmark runner for Data Model v2 fixtures (`message`, `document`, `telemetry`, `strings`, `event`).

## Serializers (6)

| Name | Category | Package | Notes |
|------|----------|---------|-------|
| EmberJson | JSON | emberjson 0.3.4 | Reflection `serialize` / `deserialize` |
| ehsanmok-json | JSON | ehsanmok/json 0.3.0 | `dumps` / `loads` on `Value` |
| mojo-cbor | Binary | leo-gan/gld-cbor | `CborDatum` encode / decode (vendored sources) |
| mojo-protobuf | Schema | leo-gan/gld-protobuf | Generated suite messages (vendored sources) |
| mojo-avro | Schema | leo-gan/gld-avro | `AvroDatum` encode / decode (conda) |
| mojo-toml | Text | DataBooth/mojo-toml | `to_toml` / `parse` (vendored source) |

mojo-avro’s conda package owns the `runtime` / `wire` / `json` module names. CBOR and Protobuf are compiled from `vendor/cbor_src` and `vendor/pb_src` with those internals renamed so all three can live in one process.

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
