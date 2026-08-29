# Cap’n Proto C ABI

C wrapper around the official Cap’n Proto C++ runtime. Generated types live in
`../gen/capnp/` (from `cpp/schemas/benchmark.capnp`). The header/source pair
follows the same C ABI as Swift’s CapnpBridge so Zig 0.16 can call
`MallocMessageBuilder` / `FlatArrayMessageReader` without the 0.17-only Zig plugin.

`build.zig` compiles this tree with the **system** `c++` into `libzigcapnp.so`
(closing `libkj` / `libstdc++` inside that DSO). Zig links only the C ABI. Do
not feed `libkj.a` to Zig’s LLD — it cannot resolve GCC `std::exception_ptr`.

Regenerate C++ with `./zig/scripts/generate-capnp.sh`.
