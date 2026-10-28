# Kiln

Kiln is a positional little-endian layout. The reader knows the type, so the bytes do not carry field names. Multi-byte integers are little-endian. The current spec is wire version 2. Profile 0 is Frozen. A tensor directory is a Frozen value whose version byte is 2.

The catalog is original. The bytes were produced by `gld-kiln` `spec/reference/gen_v2_cases.py` and then frozen. Mojo scores them with `gld-kiln` 0.3.0 (`decode` and `decode_framed`). C, C++, C#, Go, Java, JavaScript, Python, Rust, Swift, and Zig score the same 46 cases with `gld-kiln` 0.2.0. A language with no Kiln library has no cell.

Spec: [Kiln wire format, version 2](https://leo-gan.github.io/gld-kiln/spec/).

| Version | Catalog | Library |
|---------|---------|---------|
| v2 | `compliance/data/kiln/v2.json` | Mojo gld-kiln 0.3.0; other ports gld-kiln 0.2.0 |

The cases cover the version-2 directory, a `tensors` field, the frame hash of that field, and the allocation check on lists. A case fails when the library accepts a byte the spec forbids, or when an accepted value does not match the case.

Pass/fail cells are on the [Dashboard → Compliance](../dashboard/#compliance) view, standard **Kiln**, column **Kiln wire v2**.
