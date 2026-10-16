# Kiln

Kiln wire v0 is a positional little-endian layout. The reader knows the type, so the bytes do not carry field names. Multi-byte integers are little-endian. Profile 0 is Frozen, and it is the layout these cases check.

The catalog is original. The bytes were produced by the Kiln reference codec and then frozen in the file. `gld-kiln` is the only library. It decodes values with `decode_value`, frames with `decode_framed`, and the tensor block with `read_f64`. A language with no Kiln library has no cell.

Spec: [Kiln wire v0](https://leo-gan.github.io/gld-kiln/spec/).

| Version | Catalog |
|---------|---------|
| v0 | `compliance/data/kiln/v0.json` |

The cases cover bool 0 and 1, little-endian integers, IEEE-754 bit patterns, UTF-8 strings, lists, optionals, structs, dict pairs, the 64-container depth limit, a buffer that must hold exactly one value, the `KLN0` frame, and the `KLNT` tensor. A case fails when the library accepts a byte the spec forbids, or when an accepted value does not match the case.

Pass/fail cells are on the [Dashboard → Compliance](../dashboard/#compliance) view, standard **Kiln**.
