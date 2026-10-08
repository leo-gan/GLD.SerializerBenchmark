# Vendored Mojo libraries

`gldjson_src/`, `cbor_src/`, `pb_src/`, `yaml_src/`, `msgpack_src/`,
`fb_src/`, `avro_src/`, `bson_src/`, `ion_src/`, `smile_src/`, `arrow_src/`, and `parquet_src/` are copies of the leo-gan `gld-*` libraries with
colliding top-level packages renamed (`json` → `gldjson` or `avro_json`,
`runtime` → `gldjson_runtime` / `cbor_runtime` / `pb_runtime` /
`yaml_runtime` / `msgpack_runtime` / `avro_runtime`, and the matching
`wire` / `schema` / `codegen` prefixes).

`emberjson_src/emberjson/` is EmberJson 0.3.4. The conda package ships a
Mojo 1.0 `.mojoc`, so the harness compiles these sources instead.

`toml_src/` is `DataBooth/mojo-toml` unchanged. The benchmark row is `mojo-toml`.
`gldtoml_src/` is leo-gan/gld-toml with `toml` / `wire` / `runtime` / `schema` / `codegen` renamed to `gldtoml*`. The benchmark row is `gld-toml`. The two libraries both ship a top-level `toml` package, so one process cannot import them under that name.

`smile_src` keeps one guard that gld-smile 0.2.0 does not have. A buffer that starts with `0x3A` and is shorter than four bytes is a truncated header. The 0.2.0 decoder left those bytes in place and looped. This copy raises end-of-input instead. `fetch-vendors.sh` puts that guard back after each copy.

`ehsanmok_src/ehsanmok_json/` is `ehsanmok/json` v0.4.0 renamed off the `json`
package name. `InlineArray` is spelled `Array` because Mojo 1.1 removed that
alias. `gpu/__init__.mojo` is a stub:
the GPU path needs Modular `max`, and this harness times the CPU parser only.

Refresh with `./mojo/scripts/fetch-vendors.sh`.
