# Vendored Mojo libraries

`gldjson_src/`, `cbor_src/`, `pb_src/`, `yaml_src/` and `msgpack_src/` are
copies of the leo-gan `gld-*` libraries with colliding top-level packages
renamed (`json` → `gldjson`, `runtime` → `gldjson_runtime` / `cbor_runtime` /
`pb_runtime` / `yaml_runtime` / `msgpack_runtime`, and the matching `wire` /
`schema` / `codegen` prefixes). mojo-avro’s conda package owns `runtime`,
`wire`, and `json` in one pixi env.

`toml_src/` is `DataBooth/mojo-toml` unchanged (`toml` does not collide).
`gld-toml` is not published yet, so this harness does not vendor it.

`ehsanmok_src/ehsanmok_json/` is `ehsanmok/json` v0.3.0 renamed off the `json`
package name so it can live next to mojo-avro. `gpu/__init__.mojo` is a stub:
the GPU path needs Modular `max`, and this harness times the CPU parser only.

Refresh with `./mojo/scripts/fetch-vendors.sh`.
