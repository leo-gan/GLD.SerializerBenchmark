# Catalog-Only and Single-Version Format Specifications

This reference page consolidates ten standards whose compliance definitions consist of in-tree JSON case catalogs without extended per-format narrative notes. Live pass/fail results for wired decoders appear on the [Dashboard → Compliance](../dashboard/index.html#compliance) view.

---

## Format Catalog Table

| Standard | Version(s) | Specification | In-Tree Catalog | Runner Notes |
|---|---|---|---|---|
| **Bebop** | 1 | [Wire format](https://github.com/6over3/bebop/wiki/Wire-format) | `compliance/data/bebop/spec.json` | JavaScript `bebop` row has limited coverage |
| **Bond** | Compact, Fast | [Bond C++ manual](https://microsoft.github.io/bond/manual/bond_cpp.html) | `compliance/data/bond/compact.json`, `fast.json` | Catalog-only until wired per runtime |
| **Cap'n Proto** | Encoding, Packed | [Encoding](https://capnproto.org/encoding.html) · [Packing](https://capnproto.org/encoding.html#packing) | `compliance/data/capnp/encoding.json`, `packed.json` | Decoders require generated code; unwired languages show empty cells |
| **HOCON** | 1 | [HOCON spec](https://github.com/lightbend/config/blob/main/HOCON.md) | `compliance/data/hocon/v1.json` | JSON superset for configuration; no Python adapter wired |
| **ORC** | v1 | [ORC v1](https://orc.apache.org/specification/ORCv1/) | `compliance/data/orc/v1.json` | ORC v2 draft excluded; `orc` and `orc-uncompressed` share each language's ORC reader |
| **Parquet** | File format | [Parquet file format](https://parquet.apache.org/docs/file-format/) | `compliance/data/parquet/file-format.json` | Uncompressed file with footer; `parquet` and `parquet-uncompressed` share each language's Parquet reader |
| **Property List** | XML, Binary | [Apple XML plist](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/PropertyLists/UnderstandXMLPlist/UnderstandXMLPlist.html) | `compliance/data/plist/xml.json`, `binary.json` | Python scores against stdlib `plistlib` |
| **SBE** | 1.0 | [SBE 1.0 message structure](https://github.com/FIXTradingCommunity/fix-simple-binary-encoding/blob/master/v1-0-STANDARD/doc/03MessageStructure.md) | `compliance/data/sbe/v1.0.json` | Fixed-layout `Signal` message; SBE 2.0 draft excluded; no Python SBE row |
| **Thrift** | Binary, Compact | [Binary](https://github.com/apache/thrift/blob/master/doc/specs/thrift-binary-protocol.md) · [Compact](https://github.com/apache/thrift/blob/master/doc/specs/thrift-compact-protocol.md) | `compliance/data/thrift/binary.json`, `compact.json` | No Python adapter wired; cells stay empty until a runner decodes them |
| **ZON** | 1 | [Zig Object Notation](https://ziglang.org/documentation/master/#Zig-Object-Notation-ZON) | `compliance/data/zon/v1.json` | Zig configuration notation; catalog in-tree |

See [Reading compliance results](reading-results.md) for pass/fail semantics and [Language adapters](adapters.md) for adding new decoders.
