# Rust Tested Serializers

| Serializer | Category | Crate | Optimal API | Notes |
|------------|----------|-------|-------------|-------|
| serde_json | JSON | `serde_json` | `to_vec` / `from_slice` | Industry standard |
| simd-json | JSON | `simd-json` | `serde::from_slice` on mut buf | SIMD parse; serialize via serde_json |
| sonic-rs | JSON | `sonic-rs` | `to_vec` / `from_slice` | Very fast JSON |
| rmp-serde | MessagePack | `rmp-serde` | `to_vec_named` / `from_slice` | Named maps for struct fidelity |
| ciborium | CBOR | `ciborium` | `into_writer` / `from_reader` | IETF CBOR |
| bincode | Binary | `bincode` 2 | `serde::encode_to_vec` | Compact, Rust-centric |
| postcard | Binary | `postcard` | `to_allocvec` / `from_bytes` | no_std friendly |
| bitcode | Binary | `bitcode` | `serialize` / `deserialize` | Bit-packed |
| flexbuffers | Schema-ish | `flexbuffers` | `FlexbufferSerializer` / `Reader` | FlatBuffers FlexBuffers |
| minicbor | CBOR | `minicbor` | `to_vec` / `decode` | Light CBOR (wrapper path for untagged enum) |
| rkyv | Zero-copy | `rkyv` 0.8 | `to_bytes` / `access` + `deserialize` | Archives inner postcard payload |
| prost-wire | Protobuf-style | `prost` + hand wire | field-1 length-delimited | Stand-in until `.proto` codegen is wired |

## Caveats (read before citing in a paper)

- **rkyv** and **prost-wire** measure realistic *patterns* (zero-copy archive, protobuf wire) but are not full end-to-end `#[derive(Archive)]` / `prost-build` codegen paths. Extend with generated types for publication-grade schema benchmarks.
- **minicbor** currently encodes intermediate `Vec<u8>` (JSON bytes) as CBOR for untagged `Fixture` enum compatibility; replace with direct `#[derive(Encode, Decode)]` types for fair minicbor numbers.
