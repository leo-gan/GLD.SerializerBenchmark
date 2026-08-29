# Cap’n Proto C ABI

C wrapper around the official Cap’n Proto C++ runtime. Generated types live in
`../gen/capnp/` (from `cpp/schemas/benchmark.capnp`). The header/source pair
follows the same C ABI as Swift’s CapnpBridge so Zig 0.16 can call
`MallocMessageBuilder` / `FlatArrayMessageReader` without the 0.17-only Zig plugin.

Regenerate C++ with `./zig/scripts/generate-capnp.sh`.
