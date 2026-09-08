# Vendored Mojo libraries

`cbor_src/` and `pb_src/` are copies of `leo-gan/gld-cbor` and
`leo-gan/gld-protobuf` with colliding top-level packages renamed
(`runtime` → `cbor_runtime` / `pb_runtime`, `wire` → `cbor_wire` /
`pb_wire`, and so on). mojo-avro’s conda package owns `runtime`, `wire`,
and `json` in one pixi env.

`toml_src/` is `DataBooth/mojo-toml` unchanged (`toml` does not collide).

`ehsanmok_src/ehsanmok_json/` is `ehsanmok/json` v0.3.0 renamed off the `json`
package name so it can live next to mojo-avro. `gpu/__init__.mojo` is a stub:
the GPU path needs Modular `max`, and this harness times the CPU parser only.

Refresh with `./mojo/scripts/fetch-vendors.sh`.
