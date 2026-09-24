# Vendored Mojo libraries

`gldjson_src/`, `cbor_src/`, `pb_src/`, `yaml_src/`, `msgpack_src/`,
`fb_src/`, and `avro_src/` are copies of the leo-gan `gld-*` libraries with
colliding top-level packages renamed (`json` → `gldjson` or `avro_json`,
`runtime` → `gldjson_runtime` / `cbor_runtime` / `pb_runtime` /
`yaml_runtime` / `msgpack_runtime` / `avro_runtime`, and the matching
`wire` / `schema` / `codegen` prefixes).

`emberjson_src/emberjson/` is EmberJson 0.3.4. The conda package ships a
Mojo 1.0 `.mojoc`, so the harness compiles these sources instead.

`toml_src/` is `DataBooth/mojo-toml` unchanged (`toml` does not collide).
`gld-toml` is not published yet, so this harness does not vendor it.

`ehsanmok_src/ehsanmok_json/` is `ehsanmok/json` v0.4.0 renamed off the `json`
package name. `InlineArray` is spelled `Array` because Mojo 1.1 removed that
alias. `gpu/__init__.mojo` is a stub:
the GPU path needs Modular `max`, and this harness times the CPU parser only.

Refresh with `./mojo/scripts/fetch-vendors.sh`.
