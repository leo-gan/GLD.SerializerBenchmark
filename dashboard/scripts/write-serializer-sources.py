#!/usr/bin/env python3
"""Author config/serializer-sources.json and the dashboard copy.

Each registered serializer gets a source URL (GitHub / stdlib tree / this
repo for in-tree baselines), the last measured SerializerVersion from the
latest bench JSON, and a short origin paragraph: why the library exists,
what problem it solved, and how.

The compliance catalog supplies the registered (language, name) list.
Edit URL_OVERRIDE and SPECIFICS here, then re-run. Do not hand-edit the
JSON except to inspect it. Versions are filled from
dashboard/public/data/<lang>_latest.json.gz — never typed in this file.

    python3 dashboard/scripts/write-serializer-sources.py
"""
from __future__ import annotations

import gzip
import importlib.util
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPTS = Path(__file__).resolve().parent
CONFIG_OUT = ROOT / "config" / "serializer-sources.json"
DASH_OUT = ROOT / "dashboard" / "public" / "data" / "serializer-sources.json"

GITHUB_RE = re.compile(r"https?://github\.com/([^/]+)/([^/#?]+)")
CODEBERG_RE = re.compile(r"https?://codeberg\.org/([^/]+)/([^/#?]+)")


def _load_compliance_catalog():
    path = SCRIPTS / "write-compliance-catalog.py"
    spec = importlib.util.spec_from_file_location("write_compliance_catalog", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return list(mod.CATALOG)


def _repo_root_from_url(url: str) -> str | None:
    m = GITHUB_RE.search(url)
    if m:
        owner, repo = m.group(1), m.group(2)
        if repo.endswith(".git"):
            repo = repo[:-4]
        # Keep tree/blob paths that already point at a stdlib subtree.
        if "/tree/" in url or "/blob/" in url:
            return url.split("#")[0].rstrip("/")
        return f"https://github.com/{owner}/{repo}"
    m = CODEBERG_RE.search(url)
    if m:
        owner, repo = m.group(1), m.group(2)
        if repo.endswith(".git"):
            repo = repo[:-4]
        return f"https://codeberg.org/{owner}/{repo}"
    return None


# Prefer the project's source repository over a docs-site URL.
URL_OVERRIDE: dict[tuple[str, str], str] = {
    # C
    ("c", "jansson"): "https://github.com/akheron/jansson",
    ("c", "msgpack-c"): "https://github.com/msgpack/msgpack-c",
    ("c", "libbson"): "https://github.com/mongodb/mongo-c-driver",
    ("c", "ubj"): "https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/c/src/ser_ubj.c",
    ("c", "avro-c"): "https://github.com/apache/avro",
    ("c", "nanopb"): "https://github.com/nanopb/nanopb",
    ("c", "protobuf"): "https://github.com/protocolbuffers/protobuf",
    ("c", "protobuf-wire"): "https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/c/src/ser_upb.c",
    ("c", "custom-binary"): "https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/c/src/ser_custom_binary.c",
    ("c", "libyaml"): "https://github.com/yaml/libyaml",
    # Python
    ("python", "json"): "https://github.com/python/cpython/tree/main/Lib/json",
    ("python", "msgspec"): "https://github.com/jcrist/msgspec",
    ("python", "msgspec-msgpack"): "https://github.com/jcrist/msgspec",
    ("python", "rapidjson"): "https://github.com/python-rapidjson/python-rapidjson",
    ("python", "pydantic"): "https://github.com/pydantic/pydantic",
    ("python", "yaml"): "https://github.com/yaml/pyyaml",
    ("python", "cbor2"): "https://github.com/agronholm/cbor2",
    ("python", "msgpack"): "https://github.com/msgpack/msgpack-python",
    ("python", "protobuf"): "https://github.com/protocolbuffers/protobuf",
    ("python", "avro"): "https://github.com/fastavro/fastavro",
    ("python", "flatbuffers"): "https://github.com/google/flatbuffers",
    ("python", "pickle"): "https://github.com/python/cpython/tree/main/Lib/pickle.py",
    ("python", "dill"): "https://github.com/uqfoundation/dill",
    ("python", "tomllib"): "https://github.com/python/cpython/tree/main/Lib/tomllib",
    ("python", "amazon-ion"): "https://github.com/amazon-ion/ion-python",
    ("python", "bson"): "https://github.com/mongodb/mongo-python-driver",
    ("python", "flexbuffers"): "https://github.com/google/flatbuffers",
    ("python", "newsmile"): "https://github.com/FasterXML/smile-format-specification",
    ("python", "plistlib"): "https://github.com/python/cpython/tree/main/Lib/plistlib.py",
    # JavaScript
    ("javascript", "JSON.stringify"): "https://github.com/nodejs/node",
    ("javascript", "json-pack-msgpack"): "https://github.com/jsonjoy-com/json-pack",
    ("javascript", "bson"): "https://github.com/mongodb/js-bson",
    ("javascript", "flatbuffers"): "https://github.com/google/flatbuffers",
    ("javascript", "flexbuffers"): "https://github.com/google/flatbuffers",
    ("javascript", "v8-serializer"): "https://github.com/nodejs/node",
    ("javascript", "bser"): "https://github.com/facebook/watchman",
    # Go
    ("go", "encoding/json"): "https://github.com/golang/go/tree/master/src/encoding/json",
    ("go", "protobuf"): "https://github.com/protocolbuffers/protobuf-go",
    ("go", "mongo-bson"): "https://github.com/mongodb/mongo-go-driver",
    ("go", "encoding/gob"): "https://github.com/golang/go/tree/master/src/encoding/gob",
    ("go", "vmihailenco/msgpack"): "https://github.com/vmihailenco/msgpack",
    # Java
    ("java", "jsoniter"): "https://github.com/json-iterator/java",
    ("java", "protobuf"): "https://github.com/protocolbuffers/protobuf",
    ("java", "avro"): "https://github.com/apache/avro",
    ("java", "bson"): "https://github.com/mongodb/mongo-java-driver",
    ("java", "ion"): "https://github.com/amazon-ion/ion-java",
    ("java", "flatbuffers"): "https://github.com/google/flatbuffers",
    ("java", "capnproto"): "https://github.com/capnproto/capnproto-java",
    ("java", "java-serialization"): "https://github.com/openjdk/jdk",
    ("java", "fory"): "https://github.com/apache/fory",
    ("java", "hessian"): "https://github.com/ebourg/hessian",
    # Kotlin
    ("kotlin", "protobuf"): "https://github.com/protocolbuffers/protobuf",
    ("kotlin", "protobuf-kotlin"): "https://github.com/protocolbuffers/protobuf",
    ("kotlin", "avro"): "https://github.com/apache/avro",
    ("kotlin", "kotlinx-ion"): "https://github.com/amazon-ion/ion-java",
    ("kotlin", "flatbuffers"): "https://github.com/google/flatbuffers",
    ("kotlin", "capnproto"): "https://github.com/capnproto/capnproto-java",
    ("kotlin", "thrift"): "https://github.com/apache/thrift",
    ("kotlin", "fory"): "https://github.com/apache/fory",
    ("kotlin", "obor"): "https://github.com/orandja/obor",
    # C#
    ("csharp", "System.Text.Json"): "https://github.com/dotnet/runtime",
    ("csharp", "Json.Net"): "https://github.com/JamesNK/Newtonsoft.Json",
    ("csharp", "Json.Net (Helper)"): "https://github.com/JamesNK/Newtonsoft.Json",
    ("csharp", "ServiceStack Json"): "https://github.com/ServiceStack/ServiceStack.Text",
    ("csharp", "ServiceStack"): "https://github.com/ServiceStack/ServiceStack.Text",
    ("csharp", "FsPicklerJson"): "https://github.com/mbraceproject/FsPickler",
    ("csharp", "FsPickler"): "https://github.com/mbraceproject/FsPickler",
    ("csharp", "MS DataContract Json"): "https://github.com/dotnet/runtime",
    ("csharp", "MS DataContract"): "https://github.com/dotnet/runtime",
    ("csharp", "MS XmlSerializer"): "https://github.com/dotnet/runtime",
    ("csharp", "MS Binary"): "https://github.com/dotnet/runtime",
    ("csharp", "MS Bond Json"): "https://github.com/microsoft/bond",
    ("csharp", "MS Bond Compact"): "https://github.com/microsoft/bond",
    ("csharp", "MS Bond Fast"): "https://github.com/microsoft/bond",
    ("csharp", "Google.Protobuf"): "https://github.com/protocolbuffers/protobuf",
    ("csharp", "Apache.Avro"): "https://github.com/apache/avro",
    ("csharp", "CsvHelper"): "https://github.com/JoshClose/CsvHelper",
    # Rust
    ("rust", "serde_json"): "https://github.com/serde-rs/json",
    ("rust", "simd-json"): "https://github.com/simd-lite/simd-json",
    ("rust", "sonic-rs"): "https://github.com/cloudwego/sonic-rs",
    ("rust", "serde_yaml"): "https://github.com/dtolnay/serde-yaml",
    ("rust", "ciborium"): "https://github.com/enarx/ciborium",
    ("rust", "minicbor"): "https://github.com/twittner/minicbor",
    ("rust", "rmp-serde"): "https://github.com/3Hren/msgpack-rust",
    ("rust", "prost"): "https://github.com/tokio-rs/prost",
    ("rust", "serde_avro_fast"): "https://github.com/Ten0/serde_avro_fast",
    ("rust", "bson"): "https://github.com/mongodb/bson-rust",
    ("rust", "flexbuffers"): "https://github.com/google/flatbuffers",
    ("rust", "bincode"): "https://github.com/bincode-org/bincode",
    ("rust", "bitcode"): "https://github.com/SoftbearStudios/bitcode",
    ("rust", "nanoserde"): "https://github.com/not-fl3/nanoserde",
    ("rust", "postcard"): "https://github.com/jamesmunns/postcard",
    ("rust", "speedy"): "https://github.com/koute/speedy",
    ("rust", "rkyv"): "https://github.com/rkyv/rkyv",
    # C++
    ("cpp", "nlohmann_json"): "https://github.com/nlohmann/json",
    ("cpp", "nlohmann_cbor"): "https://github.com/nlohmann/json",
    ("cpp", "nlohmann_msgpack"): "https://github.com/nlohmann/json",
    ("cpp", "nlohmann_bson"): "https://github.com/nlohmann/json",
    ("cpp", "nlohmann_ubjson"): "https://github.com/nlohmann/json",
    ("cpp", "rapidjson"): "https://github.com/Tencent/rapidjson",
    ("cpp", "simdjson"): "https://github.com/simdjson/simdjson",
    ("cpp", "arduinojson"): "https://github.com/bblanchon/ArduinoJson",
    ("cpp", "protobuf"): "https://github.com/protocolbuffers/protobuf",
    ("cpp", "protobuf-wire"): "https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/cpp/src/ser_protobuf_wire.cpp",
    ("cpp", "avro"): "https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/docs/cpp/index.md",
    ("cpp", "avro_c"): "https://github.com/apache/avro",
    ("cpp", "flatbuffers"): "https://github.com/google/flatbuffers",
    ("cpp", "flexbuffers"): "https://github.com/google/flatbuffers",
    ("cpp", "capnproto"): "https://github.com/capnproto/capnproto",
    ("cpp", "thrift"): "https://github.com/apache/thrift",
    ("cpp", "cereal"): "https://github.com/USCiLab/cereal",
    ("cpp", "custom_binary"): "https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/docs/cpp/index.md",
    ("cpp", "boost_serialization"): "https://github.com/boostorg/serialization",
    ("cpp", "yaml-cpp"): "https://github.com/jbeder/yaml-cpp",
    # Swift
    ("swift", "Foundation.JSONEncoder"): "https://github.com/apple/swift-foundation",
    ("swift", "Foundation.PropertyListEncoder"): "https://github.com/apple/swift-foundation",
    ("swift", "FlatBuffers"): "https://github.com/google/flatbuffers",
    ("swift", "CapnProto"): "https://github.com/capnproto/capnproto",
    ("swift", "protobuf-wire"): "https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/docs/swift/index.md",
    ("swift", "SwiftAvroCore"): "https://github.com/lynixliu/SwiftAvroCore",
    ("swift", "SwiftCbor"): "https://github.com/nnabeyang/swift-cbor",
    ("swift", "BinaryCodable"): "https://github.com/christophhagen/BinaryCodable",
    # PHP
    ("php", "json"): "https://github.com/php/php-src/tree/master/ext/json",
    ("php", "serialize"): "https://github.com/php/php-src",
    ("php", "symfony-json"): "https://github.com/symfony/serializer",
    ("php", "symfony-xml"): "https://github.com/symfony/serializer",
    ("php", "jms-json"): "https://github.com/schmittjoh/serializer",
    ("php", "yaml"): "https://github.com/symfony/yaml",
    ("php", "protobuf"): "https://github.com/protocolbuffers/protobuf",
    ("php", "avro"): "https://github.com/flix-tech/avro-php",
    ("php", "simdjson"): "https://github.com/crazyxman/simdjson_php",
    ("php", "igbinary"): "https://github.com/igbinary/igbinary",
    ("php", "msgpack-pecl"): "https://github.com/msgpack/msgpack-php",
    ("php", "bson"): "https://github.com/mongodb/mongo-php-driver",
    ("php", "yaml-pecl"): "https://github.com/php/pecl-file_formats-yaml",
    # Zig
    ("zig", "std.json"): "https://github.com/ziglang/zig",
    ("zig", "std.json.scanner"): "https://github.com/ziglang/zig",
    ("zig", "std.zon"): "https://github.com/ziglang/zig",
    ("zig", "serde.json"): "https://github.com/OrlovEvgeny/serde.zig",
    ("zig", "serde.yaml"): "https://github.com/OrlovEvgeny/serde.zig",
    ("zig", "serde.toml"): "https://github.com/OrlovEvgeny/serde.zig",
    ("zig", "serde.msgpack"): "https://github.com/OrlovEvgeny/serde.zig",
    ("zig", "serde.zon"): "https://github.com/OrlovEvgeny/serde.zig",
    ("zig", "serde.xml"): "https://github.com/OrlovEvgeny/serde.zig",
    ("zig", "zbor"): "https://codeberg.org/r4gus/zbor",
    ("zig", "protobuf"): "https://github.com/Arwalk/zig-protobuf",
    ("zig", "protobuf-wire"): "https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/docs/zig/index.md",
    ("zig", "flatbuffers"): "https://github.com/nDimensional/zig-flatbuffers",
    ("zig", "capnproto"): "https://github.com/capnproto/capnproto",
    ("zig", "comptime-bin"): "https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/docs/zig/index.md",
    # Mojo
    ("mojo", "EmberJson"): "https://github.com/bgreni/EmberJson",
}

# Extra rows that are benchmarked but not in the compliance catalog.
EXTRA_ROWS: list[tuple[str, str, str]] = [
    ("php", "simdjson", "https://github.com/crazyxman/simdjson_php"),
    ("php", "igbinary", "https://github.com/igbinary/igbinary"),
    ("php", "msgpack-pecl", "https://github.com/msgpack/msgpack-php"),
    ("php", "bson", "https://github.com/mongodb/mongo-php-driver"),
    ("php", "yaml-pecl", "https://github.com/php/pecl-file_formats-yaml"),
    ("go", "shamaton/msgpack (array)", "https://github.com/shamaton/msgpack"),
    ("javascript", "bebop", "https://github.com/6over3/bebop"),
]

# Shared origin stories: why the library exists, the problem, the solution.
SPECIFICS: dict[str, str] = {
    "cjson": (
        "cJSON was written as an ultralightweight JSON parser in ANSI C for "
        "embedded and application code that could not afford a heavy toolkit. "
        "The problem was that existing C JSON stacks pulled large dependencies "
        "or a C++ runtime. cJSON solves that with a single-file DOM: parse to "
        "a tree of `cJSON` nodes, mutate, and print."
    ),
    "jansson": (
        "Jansson was created to give C a complete, documented JSON library "
        "with a stable API — encode, decode, and manipulate values — not just "
        "a minimal parser. The problem was that many C JSON snippets were "
        "incomplete or awkward to embed. Jansson solves it with a reference-"
        "counted value type and an API aimed at RFC 8259."
    ),
    "yyjson": (
        "yyjson was written for high-performance JSON in ANSI C: fast parse "
        "and print without giving up a usable DOM. The problem was that "
        "lightweight C parsers were slow, and fast parsers were often C++ "
        "or SAX-only. yyjson solves that with a compact C implementation "
        "and mutable/immutable document APIs."
    ),
    "json-c": (
        "json-c is a long-running C implementation of JSON intended to be "
        "the practical library for Unix/C programs. The problem was the lack "
        "of a maintained, RFC-oriented JSON C library for system software. "
        "It solves that with a C API that aims at RFC 8259."
    ),
    "parson": (
        "Parson was written as a small, single-file JSON library in C that "
        "is easy to drop into a project. The problem was boilerplate-heavy "
        "C JSON stacks. Parson solves it with a compact DOM around json.org "
        "JSON."
    ),
    "mpack": (
        "MPack is a C encoder/decoder for MessagePack, aimed at correctness "
        "and a clean buffer/stream API. The problem was that C MessagePack "
        "options were either incomplete or awkward to embed. MPack solves it "
        "with a documented pack/unpack implementation of the MessagePack spec."
    ),
    "msgpack-c": (
        "msgpack-c is the official C/C++ implementation of MessagePack. "
        "MessagePack was created to be as small and fast as a binary format "
        "while staying as simple as JSON. The C library solves that with "
        "pack/unpack APIs (and a separate C++ API in the same repository)."
    ),
    "tinycbor": (
        "Intel TinyCBOR was written so constrained and systems software "
        "could speak IETF CBOR (RFC 7049 / 8949). The problem was that CBOR "
        "needed a small, well-specified C encoder/decoder. TinyCBOR solves "
        "it with a buffer-oriented C API."
    ),
    "libcbor": (
        "libcbor is a CBOR protocol implementation for C targeting RFC 7049 "
        "and RFC 8949. The problem was the need for a full-featured C CBOR "
        "DOM and streaming encoder. It solves that with `cbor_load` for "
        "documents and `cbor_encode_*` for streaming."
    ),
    "qcbor": (
        "QCBOR was written as a comprehensive, safety-oriented CBOR "
        "implementation for professional and embedded use (RFC 8949). The "
        "problem was that CBOR stacks were either incomplete or hard to "
        "audit. QCBOR solves it with a carefully bounded C encoder/decoder."
    ),
    "zcbor": (
        "Nordic zcbor was created to generate C from CDDL and to encode/"
        "decode CBOR on constrained devices. The problem was writing CBOR "
        "by hand against a schema. zcbor solves it with a CBOR codec plus "
        "a CDDL code generator."
    ),
    "libbson": (
        "libbson is MongoDB's C library for building and iterating BSON "
        "documents. BSON exists so MongoDB can store JSON-like documents "
        "with a binary, traversable layout. libbson solves that with "
        "`bson_append_*` / `bson_iter_*`."
    ),
    "ubj": (
        "This row is the suite's in-tree UBJSON marker codec around the V2 "
        "binary payload. UBJSON was created as a binary cousin of JSON with "
        "explicit types. The harness implements the markers so C has a UBJSON "
        "size/speed point without a third-party dependency."
    ),
    "flatcc": (
        "flatcc is the maintained C implementation of FlatBuffers. FlatBuffers "
        "was created at Google so games and other clients could read serialized "
        "data without a parsing/unpacking step. flatcc solves the C side with "
        "a schema compiler and a C builder/reader."
    ),
    "avro-c": (
        "Apache Avro was created for Hadoop-era data: a compact binary "
        "encoding with the schema stored out of band so field names are not "
        "repeated. avro-c is the official C implementation of that encoding."
    ),
    "nanopb": (
        "nanopb was written so Protocol Buffers could run on microcontrollers. "
        "The problem was that Google's C++ protobuf runtime is far too large "
        "for tiny devices. nanopb solves it with a small C implementation "
        "and a generator aimed at static allocation."
    ),
    "protobuf-c": (
        "protobuf-c provides C bindings for Google Protocol Buffers. The "
        "problem was that official protobuf was C++-first. protobuf-c solves "
        "it with `protoc-gen-c` and a C runtime for the same wire format."
    ),
    "protobuf": (
        "Protocol Buffers were created at Google so many languages could "
        "share a compact, evolving binary contract without hand-written "
        "parsers. The problem was ad-hoc binary formats and verbose XML. "
        "Protobuf solves it with an IDL, generated code, and a documented "
        "tag/length wire format."
    ),
    "protobuf-wire": (
        "This row is the suite's in-tree proto3 tag reader/writer. It exists "
        "to measure the published Protocol Buffers encoding itself, without "
        "a particular vendor runtime. Field numbers match "
        "`schemas/v2/protobuf/benchmark_v2.proto`."
    ),
    "custom-binary": (
        "This is the suite's length-prefixed V2 baseline, not a published "
        "format. It exists so every language has a simple binary control "
        "point: write fields with explicit lengths, read them back, no "
        "schema compiler."
    ),
    "cpython-json": (
        "The CPython `json` module is the language's standard JSON "
        "encoder/decoder (RFC 8259). It was added so Python programs had a "
        "stdlib way to speak the web's data format. The implementation is a "
        "C-accelerated codec over Python objects; this suite times that path "
        "as the baseline."
    ),
    "orjson": (
        "orjson was written to give CPython a JSON codec that is both fast "
        "and correct. The problem was that stdlib `json` is slow on large "
        "payloads, while many speed-focused alternatives cut corners on "
        "Unicode, strictness, or types. orjson solves that with a Rust "
        "extension that implements RFC 8259 on dataclasses and common types."
    ),
    "msgspec": (
        "msgspec was created as a high-performance serialization library "
        "for Python with typed structures, not just dicts. The problem was "
        "that fast JSON libraries still paid for untyped Python objects, "
        "and validation libraries were slow. msgspec solves it with "
        "array-like Structs and a compiled encode/decode path (JSON and "
        "MessagePack)."
    ),
    "rapidjson-py": (
        "python-rapidjson wraps Tencent RapidJSON so CPython can use that "
        "C++ parser/generator. RapidJSON was written for speed with a SAX "
        "and DOM API. The Python binding exposes `dumps`/`loads` on dicts."
    ),
    "pydantic": (
        "Pydantic was created to validate and serialize Python data for "
        "APIs (later FastAPI). The problem was that ad-hoc dicts and "
        "hand-written validators were error-prone. Pydantic solves it with "
        "typed models and JSON dump/load (`model_dump_json` / TypeAdapter)."
    ),
    "mashumaro": (
        "mashumaro was written to serialize Python dataclasses to JSON and "
        "other formats with code generation, not runtime reflection on "
        "every call. The problem was slow dataclass codecs. This row times "
        "the ORJSON encoder/decoder path."
    ),
    "serpyco-rs": (
        "serpyco-rs is a fast dataclass JSON serializer (Rust core) for "
        "Python. The problem was that dataclass-to-JSON in pure Python is "
        "slow. It solves that by compiling the dump/load path and using "
        "orjson on the wire."
    ),
    "libyaml": (
        "libyaml is the official C library for YAML 1.1, written so other "
        "languages (PyYAML, Yams, ext-yaml) can share one parser/emitter. "
        "YAML exists as a human-friendly config language. This row times "
        "the C library directly."
    ),
    "pyyaml": (
        "PyYAML is the long-standing YAML 1.1 processor for Python. YAML "
        "was created as a human-friendly superset of JSON for config and "
        "documents. PyYAML implements that model with dump/load."
    ),
    "cbor2": (
        "cbor2 is a Python implementation of IETF CBOR (RFC 8949). CBOR "
        "was created as a binary JSON-like format for constrained devices "
        "and IETF protocols. cbor2 solves the Python side with a widely "
        "used encoder/decoder."
    ),
    "msgpack-py": (
        "msgpack-python is the official MessagePack implementation for "
        "Python. MessagePack was created to be as compact as a binary "
        "format and as simple as JSON. The package exposes pack/unpack "
        "(and stream APIs) on Python objects."
    ),
    "fastavro": (
        "fastavro is a Cython Avro reader/writer for Python. Avro was "
        "created so data systems could store compact records with the "
        "schema out of band. fastavro solves the CPython performance "
        "problem of the older pure-Python Avro stack."
    ),
    "flatbuffers": (
        "FlatBuffers was created at Google so games and clients could "
        "access serialized data without an unpack step. The problem was "
        "that protobuf-style decode allocated a full object graph. "
        "FlatBuffers solves it with a schema and a binary layout that "
        "can be traversed in place."
    ),
    "pickle": (
        "pickle is CPython's native object serializer. It exists so Python "
        "processes can snapshot almost any object graph. That power is also "
        "the problem: loading untrusted pickle can run arbitrary code. This "
        "row times the stdlib C implementation."
    ),
    "cloudpickle": (
        "cloudpickle extends pickle so cluster and serverless runtimes can "
        "ship functions and dynamic objects, not just importable classes. "
        "The problem was that pickle cannot serialize many constructs that "
        "job schedulers need. cloudpickle solves that by capturing more of "
        "the Python object model — with the same security caveats."
    ),
    "dill": (
        "dill extends pickle further for scientific Python: graphs, "
        "lambdas, and interpreter state. The problem was that pickle and "
        "even cloudpickle still failed on objects researchers actually "
        "use. dill solves that with a broader, mostly pure-Python save path."
    ),
    "tomllib": (
        "tomllib is CPython's stdlib TOML 1.0 parser (3.11+). TOML was "
        "created as an obvious, minimal config language. The stdlib module "
        "solves 'every project vendors a TOML parser' by shipping one."
    ),
    "amazon-ion": (
        "Amazon Ion was created at Amazon as a rich, self-describing "
        "superset of JSON (text and binary) for internal services. The "
        "problem was JSON's limited types. ion-python is the official "
        "Python implementation."
    ),
    "bson": (
        "BSON (Binary JSON) was created for MongoDB so documents could be "
        "stored and traversed without a text parse. Official language "
        "drivers implement that spec. This row times that library's "
        "serialize/deserialize path."
    ),
    "flexbuffers": (
        "FlexBuffers is the schemaless cousin of FlatBuffers. It was "
        "created so you can have a FlatBuffers-family binary without "
        "compiling a schema. The same Google repository implements it."
    ),
    "smile": (
        "Smile is FasterXML's binary JSON: Jackson-compatible data with a "
        "smaller, faster binary encoding. The problem was JSON text cost "
        "in JVM services that already used Jackson. Smile solves it with "
        "a documented binary JSON token stream."
    ),
    "plistlib": (
        "plistlib is CPython's reader/writer for Apple property lists. "
        "plists exist so Apple platforms can store typed configuration. "
        "The stdlib module speaks that format from Python."
    ),
    "py-ubjson": (
        "py-ubjson implements Universal Binary JSON in Python. UBJSON was "
        "created as a binary form of JSON with explicit type markers. The "
        "library is a straightforward encoder/decoder of that spec."
    ),
    "json-stringify": (
        "`JSON.stringify` / `JSON.parse` are the ECMAScript standard JSON "
        "APIs. They exist so every JavaScript host can speak RFC 8259 "
        "without a library. This row times Node's V8 implementation."
    ),
    "fast-json-stringify": (
        "fast-json-stringify was created in the Fastify ecosystem to "
        "serialize JSON from a JSON Schema much faster than "
        "`JSON.stringify`. The problem was that schema-known objects still "
        "paid for a fully dynamic walk. It compiles a serializer once and "
        "reuses it; this suite decodes with `JSON.parse`."
    ),
    "simdjson-js": (
        "simdjson was created to parse JSON at memory-bandwidth speeds "
        "using SIMD. The problem was that conventional parsers were far "
        "from hardware limits. This row uses simdjson only for parse; "
        "serialize is still `JSON.stringify`."
    ),
    "js-yaml": (
        "js-yaml is the usual Node YAML 1.2 parser/dumper. YAML exists as "
        "a human-friendly config language. js-yaml solves the JavaScript "
        "side with a widely deployed implementation."
    ),
    "msgpack-js": (
        "The official MessagePack JavaScript implementation (`@msgpack/"
        "msgpack`). MessagePack was created as compact binary JSON. This "
        "package is the reference encode/decode API for JS."
    ),
    "msgpackr": (
        "msgpackr was written for high-throughput MessagePack in Node, "
        "with reusable Packr/Unpackr instances. The problem was that "
        "generic MessagePack libraries allocated too much per call. "
        "msgpackr solves that with a performance-oriented encoder/decoder."
    ),
    "json-pack": (
        "json-pack (jsonjoy) is a family of binary codecs including "
        "MessagePack. It was written to give JavaScript a fast, modular "
        "binary JSON toolkit. This row times the MsgPack encoder/decoder."
    ),
    "node-cbor": (
        "node-cbor implements IETF CBOR (RFC 8949) for Node. CBOR exists "
        "as the IETF's binary JSON-like format. The library is a full "
        "encode/decode implementation of that RFC."
    ),
    "cbor-x": (
        "cbor-x is a high-performance CBOR encoder/decoder for JS, from "
        "the same author as msgpackr. The problem was slow or allocating "
        "CBOR stacks in Node. It solves that with reusable Encoder/"
        "Decoder instances."
    ),
    "avsc": (
        "avsc brings Apache Avro to JavaScript. Avro was created for "
        "compact, schema-driven records in data pipelines. avsc solves "
        "the JS side with `Type.forSchema` and buffer encode/decode."
    ),
    "protobufjs": (
        "protobuf.js is a popular JavaScript Protocol Buffers "
        "implementation that can work from a `.proto` or a JSON "
        "descriptor. The problem was that Google's JS protobuf was "
        "awkward in Node. protobuf.js solves it with a JS-native API."
    ),
    "protobuf-es": (
        "protobuf-es is Buf's Protocol Buffers implementation for "
        "ECMAScript. The problem was that existing JS protobuf stacks "
        "did not match modern TypeScript and the official proto3 "
        "feature set. It generates TypeScript and times `toBinary` / "
        "`fromBinary`."
    ),
    "google-protobuf-js": (
        "This is Google's official JavaScript protobuf runtime (`google-"
        "protobuf` / jspb). It exists so the same `.proto` contracts can "
        "run in JS. The suite times `serializeBinary` / `deserializeBinary`."
    ),
    "bebop": (
        "Bebop is a schema-driven binary format created as a simpler, "
        "faster alternative to protobuf-like IDL stacks for games and "
        "services. The problem was heavy generated code and slow "
        "encoders. Bebop solves it with a compact schema and generated "
        "writers."
    ),
    "v8-serializer": (
        "Node's `v8.serialize` / `v8.deserialize` snapshot V8 values. "
        "They exist so the engine can persist structured clones, not as "
        "a portable wire format. This row times that Node-only API."
    ),
    "devalue": (
        "devalue was written (SvelteKit and friends) to stringify richer "
        "JavaScript values than JSON allows — dates, maps, cyclical "
        "graphs — without `eval`. The problem was JSON's limited types "
        "and `eval`-based hydrators. devalue solves it with a custom "
        "text format."
    ),
    "sia": (
        "Sia is Timeleap's compact binary tag format for JS values. It "
        "was created as a project-specific, typed binary encoding rather "
        "than a public interchange standard. This row times those "
        "primitive writers."
    ),
    "bser": (
        "BSER is Facebook Watchman's binary protocol: a compact encoding "
        "for the watchman's client/server messages. The problem was JSON "
        "overhead in a local file-watching daemon. This row times the "
        "Node `bser` dump/load path."
    ),
    "go-json": (
        "Go's `encoding/json` is the standard library JSON codec. It "
        "exists so every Go program can speak RFC 8259 with struct tags. "
        "This row is the baseline other Go JSON libraries try to beat."
    ),
    "goccy-json": (
        "goccy/go-json was written as a faster drop-in for `encoding/json`. "
        "The problem was stdlib JSON cost in high-QPS Go services. It "
        "keeps the same API and implements a faster encode/decode path."
    ),
    "jsoniter-go": (
        "json-iterator/go was created as a high-performance, "
        "stdlib-compatible JSON library for Go. The problem was the same "
        "stdlib bottleneck. It solves it with a compatible config and a "
        "faster implementation."
    ),
    "segmentio-json": (
        "segmentio/encoding/json is a production fork of a faster Go JSON "
        "stack, kept as a drop-in for `encoding/json`. The problem was "
        "stdlib JSON in large Go services. This row times that API."
    ),
    "sonic": (
        "Bytedance sonic was written to push Go JSON through JIT and SIMD "
        "on the hot path. The problem was that even fast reflection JSON "
        "was not enough at ByteDance scale. sonic solves it with "
        "`ConfigDefault` plus optional Pretouch."
    ),
    "ugorji": (
        "ugorji/go (go-codec) was created as one Go library that speaks "
        "several formats (JSON, MessagePack, CBOR, Binc) through a shared "
        "handle/encoder model. The problem was maintaining a separate "
        "stack per format. This row times one handle of that multi-format "
        "codec."
    ),
    "goccy-yaml": (
        "goccy/go-yaml is a high-performance YAML 1.2 library for Go. "
        "The problem was that go-yaml v2/v3 was often the slow path in "
        "config-heavy services. It aims at a faster Marshal/Unmarshal."
    ),
    "fxamacker-cbor": (
        "fxamacker/cbor is a widely used Go CBOR codec for RFC 8949. "
        "CBOR is the IETF binary JSON-like format. This library focuses "
        "on correctness options (including deterministic modes) and "
        "reusable Enc/DecMode values."
    ),
    "vmihailenco-msgpack": (
        "vmihailenco/msgpack is a popular MessagePack library for Go. "
        "MessagePack exists as compact binary JSON. This implementation "
        "emphasizes a familiar Encoder/Decoder API with buffer reuse."
    ),
    "shamaton-msgpack": (
        "shamaton/msgpack is another Go MessagePack implementation, "
        "including a struct-as-array mode that omits field-name keys. "
        "The problem was MessagePack map overhead for known structs. "
        "Array mode solves that with positional fields."
    ),
    "hamba-avro": (
        "hamba/avro is a high-performance Avro library for Go. Avro was "
        "created for compact, schema-driven records. hamba focuses on a "
        "frozen API and schema cache so the timed path is encode/decode, "
        "not schema parse."
    ),
    "goavro": (
        "LinkedIn goavro is an Avro binary codec for Go, used in "
        "Kafka/Avro pipelines. Avro exists so producers and consumers "
        "share a schema. goavro speaks BinaryFromNative maps (OCF is a "
        "different format)."
    ),
    "go-toml": (
        "pelletier/go-toml is a TOML 1.0 parser/encoder for Go. TOML was "
        "created as an obvious config language. This library is a common "
        "Go implementation of that spec."
    ),
    "gob": (
        "encoding/gob is Go's native binary stream for Go types. It was "
        "created so Go programs can RPC and persist values without an "
        "IDL. It is not a cross-language wire format."
    ),
    "kelindar-binary": (
        "kelindar/binary is a compact, Go-only packer. It was written "
        "for high-throughput in-process and Go-to-Go payloads where a "
        "public schema is not required. Encoder.Reset is the reuse path."
    ),
    "jackson": (
        "Jackson was created as the standard data-binding toolkit for "
        "Java JSON (and later many binary/text formats). The problem was "
        "that Java needed a fast, annotation-driven mapper for REST and "
        "services. Jackson solves it with ObjectMapper / ObjectWriter "
        "and format modules (CBOR, Smile, YAML, Ion, MessagePack)."
    ),
    "gson": (
        "Gson was created at Google to convert Java objects to JSON and "
        "back with a simple API. The problem was boilerplate-heavy Java "
        "JSON. Gson solves it with reflection over POJOs and a "
        "JsonWriter/Reader stream API."
    ),
    "fastjson2": (
        "fastjson2 is Alibaba's rewrite of fastjson for high-performance "
        "JSON on the JVM. The problem was JSON cost in large Java "
        "services (and security issues in fastjson 1.x). fastjson2 "
        "solves it with a new FieldBased API."
    ),
    "dsl-json": (
        "dsl-json was written for very high-performance JSON on the JVM "
        "with compile-time binding. The problem was reflection mappers "
        "allocating too much. It reuses a JsonWriter buffer on the hot "
        "path."
    ),
    "moshi": (
        "Moshi was created at Square as a modern JSON library for Java "
        "and Android, successor-minded to Gson. The problem was Gson's "
        "older model on Android. Moshi solves it with JsonAdapter, "
        "codegen or reflection, and Okio."
    ),
    "jsoniter-java": (
        "jsoniter for Java was created as a high-performance JSON "
        "library with an optional codegen path. The problem was Jackson/"
        "Gson overhead. This suite uses DYNAMIC mode plus javassist."
    ),
    "msgpack-java": (
        "msgpack-java is the official MessagePack library for the JVM. "
        "MessagePack exists as compact binary JSON. This suite times the "
        "Jackson MessagePack mapper on that stack."
    ),
    "avro": (
        "Apache Avro was created for Hadoop-era pipelines: compact "
        "binary records with the schema stored out of band. Official "
        "language runtimes implement that encoding. This row times the "
        "platform's Avro library."
    ),
    "ion": (
        "Amazon Ion was created as a rich, self-describing superset of "
        "JSON (text and binary) for Amazon services. Official Ion "
        "libraries and Jackson Ion modules implement that model."
    ),
    "capnproto": (
        "Cap'n Proto was created by Kenton Varda (after protobuf 2) so "
        "RPC and storage could use a binary layout that is already the "
        "in-memory representation — no encode step. The problem was "
        "protobuf's parse/serialize cost. Cap'n Proto solves it with an "
        "IDL and packed/unpacked segments."
    ),
    "java-serialization": (
        "Java Object Serialization (`ObjectOutputStream`) is the "
        "language's built-in graph serializer. It exists so the JVM can "
        "persist and RMI Java objects. It is not a portable wire format."
    ),
    "kryo": (
        "Kryo was written as a fast binary serializer for JVM object "
        "graphs (games, caches, RPC). The problem was Java serialization "
        "being slow and verbose. Kryo solves it with a compact binary "
        "and reusable Output/Input."
    ),
    "fory": (
        "Apache Fory (formerly Fury) was created for high-performance, "
        "cross-language serialization. The problem was that JVM-centric "
        "binary codecs and slow portable formats left a gap. Fory "
        "registers types and serializes with a compact binary protocol."
    ),
    "hessian": (
        "Hessian is Caucho's compact binary web-service protocol from "
        "the Dubbo/Caucho era. The problem was SOAP/XML RPC overhead. "
        "Hessian2 write/readObject is the binary that this row times."
    ),
    "protostuff": (
        "protostuff was created to serialize Java objects with "
        "protobuf-like efficiency without writing `.proto` files. The "
        "problem was protobuf's IDL tax for internal graphs. Runtime "
        "schemas and LinkedBuffer reuse are the solution this row times."
    ),
    "kotlinx-serialization": (
        "kotlinx.serialization is JetBrains' official serialization "
        "framework for Kotlin. The problem was that Kotlin needed "
        "compile-time serializers, not Java reflection, across JSON and "
        "other formats. The compiler plugin generates serializers; "
        "format libraries plug in."
    ),
    "kaml": (
        "kaml is YAML for kotlinx.serialization. YAML exists as a "
        "human-friendly config language. kaml solves Kotlin YAML by "
        "implementing a format on the same `@Serializable` types."
    ),
    "obor": (
        "obor is an alternative CBOR implementation for kotlinx."
        "serialization. CBOR is the IETF binary JSON-like format. obor "
        "exists as a different kotlinx CBOR stack from the official one."
    ),
    "avro4k": (
        "avro4k brings Apache Avro to kotlinx.serialization. Avro exists "
        "for compact, schema-driven records. avro4k generates the Avro "
        "path from `@Serializable` types instead of Java reflect."
    ),
    "kbson": (
        "kbson is BSON for kotlinx.serialization. BSON exists for "
        "MongoDB documents. kbson lets Kotlin `@Serializable` types "
        "dump/load BSON without a separate mapper."
    ),
    "tomlkt": (
        "tomlkt is TOML for kotlinx.serialization. TOML exists as an "
        "obvious config language. tomlkt encodes `@Serializable` types "
        "to TOML text."
    ),
    "thrift": (
        "Apache Thrift was created at Facebook so many languages could "
        "share RPC and serialization from one IDL. The problem was "
        "hand-written cross-language services. Thrift solves it with a "
        "schema compiler and protocols such as TCompactProtocol."
    ),
    "hocon": (
        "HOCON (Human-Optimized Config Object Notation) was created at "
        "Typesafe/Lightbend for Play/Akka configuration. The problem was "
        "JSON/YAML config that was awkward for humans. kotlinx-"
        "serialization-hocon speaks that format."
    ),
    "stj": (
        "System.Text.Json is the built-in JSON serializer for modern "
        ".NET. It was created so the platform had a fast, AOT-friendly "
        "JSON stack without Newtonsoft. It solves that with a serializer "
        "in the runtime and source-generation options."
    ),
    "newtonsoft": (
        "Json.NET (Newtonsoft.Json) became the de-facto JSON library for "
        ".NET long before System.Text.Json. The problem was limited "
        "framework JSON. James Newton-King built a flexible, "
        "attribute-driven serializer that still defines much of the "
        "ecosystem."
    ),
    "jil": (
        "Jil was written by Kevin Montrose for very fast JSON on .NET "
        "using Sigil-generated IL. The problem was JSON cost in Stack "
        "Overflow-scale services. Jil solves it with a compiled "
        "serialize/deserialize path."
    ),
    "spanjson": (
        "SpanJson was created to serialize JSON on .NET using `Span<T>` "
        "and modern memory primitives. The problem was older JSON "
        "libraries allocating too many strings. It writes UTF-8 directly "
        "from spans."
    ),
    "utf8json": (
        "Utf8Json was written by Yoshifumi Kawai (neuecc) as a fast UTF-8 "
        "JSON serializer for C#. The problem was string-heavy JSON APIs. "
        "It encodes directly to UTF-8 bytes."
    ),
    "netjson": (
        "NetJSON is a small, fast JSON serializer for .NET. It was "
        "created as a lighter alternative to the large JSON frameworks. "
        "This row times its default encode/decode path."
    ),
    "fastjson-cs": (
        "fastJSON (mgholam) is a small .NET JSON serializer. It was "
        "written to keep JSON simple and dependency-light. This row "
        "times that compact implementation."
    ),
    "servicestack": (
        "ServiceStack.Text is the serializer stack behind ServiceStack. "
        "It was created so that framework had a fast, built-in JSON "
        "(and JSV) codec. This suite times the JSON path and the "
        "non-JSON type serializer as separate rows."
    ),
    "fspickler": (
        "FsPickler is an F#/.NET pickler for fast binary (and JSON) "
        "serialization of .NET objects. It was created in the MBrace "
        "project so distributed F# could ship graphs efficiently."
    ),
    "datacontract": (
        "DataContractSerializer and DataContractJsonSerializer are "
        "framework WCF-era serializers. They exist so .NET services "
        "could share an explicit data-contract model (XML or JSON) "
        "without XmlSerializer's older rules."
    ),
    "bond": (
        "Microsoft Bond was created for large-scale Microsoft services "
        "that needed a schema, several binary protocols, and codegen — "
        "in the same design space as Thrift/protobuf. Compact, Fast, "
        "and JSON protocols share one schema."
    ),
    "yamldotnet": (
        "YamlDotNet is the usual YAML library for .NET. YAML exists as "
        "a human-friendly config language. YamlDotNet implements YAML "
        "1.1/1.2 serialize/deserialize."
    ),
    "sharpyaml": (
        "SharpYaml is a YAML parser/emitter for .NET (a port/evolution "
        "of YamlDotNet lineage ideas). It exists as another maintained "
        "YAML stack for C#."
    ),
    "msgpack-csharp": (
        "MessagePack-CSharp is the official MessagePack implementation "
        "for .NET (neuecc / MessagePack-CSharp). MessagePack exists as "
        "compact binary JSON. This library is the standard .NET codec, "
        "including a contractless resolver."
    ),
    "protobuf-net": (
        "protobuf-net was created so .NET could speak Protocol Buffers "
        "without Google's generated C# being the only path. The problem "
        "was protobuf's IDL-first workflow for POCO-heavy .NET code. "
        "It attributes existing types (`[ProtoContract]`) and generates "
        "or interprets a protobuf-compatible encoding."
    ),
    "lightproto": (
        "LightProto is a source-generated, protobuf-net-style serializer "
        "for modern .NET. The problem was reflection-based protobuf-net "
        "on AOT and hot paths. LightProto generates parsers at compile "
        "time from `[LightProto.ProtoContract]`."
    ),
    "flatsharp": (
        "FlatSharp is a FlatBuffers implementation for .NET. FlatBuffers "
        "exists so readers can use serialized data without unpacking. "
        "FlatSharp generates C# from `.fbs` and times builder/parse on "
        "those tables."
    ),
    "xmlserializer": (
        "XmlSerializer is classic .NET XML serialization. It exists so "
        "the framework could map objects to XML documents. This row is "
        "real domain XML when the attributes allow it."
    ),
    "yaxlib": (
        "YAXLib is a flexible XML serializer for .NET. The problem was "
        "XmlSerializer and DataContract being rigid about XML shape. "
        "YAXLib lets you control the XML more directly on domain types."
    ),
    "extendedxml": (
        "ExtendedXmlSerializer is an XML serializer for .NET. In this "
        "suite the timed path is an envelope: ExtendedXml of `{TypeName, "
        "Json}`, not native domain XML. See the language inventory."
    ),
    "csvhelper": (
        "CsvHelper was written so .NET could read and write CSV with a "
        "robust, mapping-based API. CSV exists as the simplest tabular "
        "exchange format. This row projects supported types to rows."
    ),
    "binaryformatter": (
        "BinaryFormatter is legacy .NET binary serialization. It exists "
        "so the early framework could persist object graphs. It is "
        "obsolete and unsafe for untrusted input; the suite keeps the "
        "row as a historical baseline."
    ),
    "binarypack": (
        "BinaryPack is a compact binary serializer for .NET POCOs. It "
        "was written for fast, allocation-conscious binary packing of "
        "types that have a public parameterless constructor."
    ),
    "ceras": (
        "Ceras is a binary serializer for .NET object graphs. It was "
        "created as a modern, feature-rich alternative to "
        "BinaryFormatter-style packing without that formatter's "
        "security model."
    ),
    "grobuf": (
        "GroBuf is a binary serializer from SKB Kontur for high-"
        "throughput .NET services. The problem was slow built-in "
        "serializers. GroBuf generates a compact binary for .NET types."
    ),
    "hyperion": (
        "Hyperion is the binary serializer from the Akka.NET lineage "
        "(formerly Wire). It exists so an actor system can ship .NET "
        "messages efficiently. This row times that graph codec."
    ),
    "memorypack": (
        "MemoryPack was created by Yoshifumi Kawai for extremely fast, "
        "source-generated binary serialization on modern .NET. The "
        "problem was existing binary libraries allocating and reflecting "
        "too much. `[MemoryPackable]` types get generated encode/decode."
    ),
    "migrant": (
        "Migrant is Antmicro's .NET binary serializer for object graphs. "
        "In this suite the timed path is a JSON envelope, not native "
        "Migrant domain graphs. See the language inventory."
    ),
    "netserializer": (
        "NetSerializer is a compact, fast binary serializer for .NET. "
        "It was written to pack predefined types with very little "
        "overhead compared to BinaryFormatter."
    ),
    "sharpserializer": (
        "SharpSerializer is a .NET serializer that can write binary or "
        "XML. It was created as a simple, portable alternative to "
        "framework serializers for app persistence."
    ),
    "zeroformatter": (
        "ZeroFormatter was created (neuecc) as a fast, zero-encoding-"
        "style binary serializer for .NET, inspired by FlatBuffers/"
        "Cap'n Proto ideas. Dynamic IL is broken on .NET 8; this suite "
        "uses KeyTuple shapes."
    ),
    "serde-json": (
        "serde_json is the standard JSON backend for Rust's serde. Serde "
        "was created so Rust types could implement Serialize/Deserialize "
        "once and plug in many formats. serde_json is the JSON instance "
        "of that idea."
    ),
    "simd-json": (
        "simd-json is a SIMD JSON parser for Rust (the simdjson port). "
        "The problem was parse speed vs serde_json. This row uses SIMD "
        "for parse; serialize still goes through serde_json."
    ),
    "sonic-rs": (
        "sonic-rs is a SIMD-oriented JSON library for Rust, in the same "
        "family as ByteDance sonic. The problem was JSON cost on the "
        "hot path. It offers a serde-compatible encode/decode."
    ),
    "serde-yaml": (
        "serde_yaml is YAML via serde. YAML exists as a human-friendly "
        "config language. This crate is the usual Rust YAML backend "
        "(unmaintained upstream; still the historical serde path)."
    ),
    "ciborium": (
        "ciborium is a CBOR implementation for serde (Enarx). CBOR is "
        "the IETF binary JSON-like format. The crate exists to give Rust "
        "a serde CBOR backend."
    ),
    "minicbor": (
        "minicbor is a compact, often no_std CBOR codec with its own "
        "Encode/Decode traits. The problem was serde overhead and no_std "
        "needs. It implements RFC 8949 directly on structs."
    ),
    "rmp-serde": (
        "rmp-serde is MessagePack for serde (msgpack-rust). MessagePack "
        "exists as compact binary JSON. This crate maps serde types to "
        "named MessagePack maps."
    ),
    "prost": (
        "prost is the de-facto Protocol Buffers implementation for Rust "
        "(tokio-rs). The problem was that Google does not ship an "
        "official Rust runtime. prost-build generates Rust from `.proto` "
        "and times encode/decode on those messages."
    ),
    "serde-avro-fast": (
        "serde_avro_fast is a high-performance Avro datum codec for "
        "serde. Avro exists for compact, schema-driven records. This "
        "crate avoids the official apache-avro Value intermediate, which "
        "is multi-× slower on small records."
    ),
    "bincode": (
        "bincode is a compact binary format for serde. It was created so "
        "Rust programs could pack serde types without a public schema. "
        "It is a Rust-centric encoding, not a cross-language standard."
    ),
    "bitcode": (
        "bitcode is a bit-packed binary format for serde. It was written "
        "to squeeze serialized Rust values smaller than typical "
        "byte-aligned packers."
    ),
    "nanoserde": (
        "nanoserde is a tiny, dependency-light serializer for Rust "
        "(SerBin/DeBin). The problem was serde's compile-time and "
        "dependency weight in constrained crates. nanoserde generates a "
        "minimal binary path."
    ),
    "postcard": (
        "postcard is a compact, no_std-friendly binary format for serde "
        "(James Munns). It was created for embedded Rust where alloc and "
        "self-describing formats are too heavy."
    ),
    "speedy": (
        "speedy is a fast binary framework for Rust with its own "
        "Writable/Readable traits. It was written to beat generic serde "
        "binaries on the encode/decode hot path."
    ),
    "rkyv": (
        "rkyv is a zero-copy deserialization framework for Rust. The "
        "problem was that even fast binary codecs still allocate an "
        "owned value on decode. rkyv archives data so it can be accessed "
        "in place; this suite still materializes owned `T` for fidelity."
    ),
    "nlohmann": (
        "nlohmann/json is the de-facto modern C++ JSON library. It was "
        "created so C++ could use a JSON value type with an intuitive, "
        "STL-like API. The same library also maps that DOM to CBOR, "
        "MessagePack, BSON, and UBJSON."
    ),
    "rapidjson": (
        "RapidJSON was written at Tencent for high-performance JSON in "
        "C++ with SAX and DOM APIs. The problem was slow or awkward C++ "
        "JSON stacks. It became a standard hot-path parser/generator."
    ),
    "simdjson": (
        "simdjson was created to parse JSON at near memory bandwidth "
        "using SIMD. The problem was that conventional parsers left "
        "most of the CPU unused. This suite times parse; serialize is "
        "prepared minified JSON."
    ),
    "arduinojson": (
        "ArduinoJson was written so microcontrollers and Arduino-class "
        "devices could speak JSON in a tiny RAM budget. The problem was "
        "desktop JSON libraries being far too large. It uses a "
        "fixed-capacity document model."
    ),
    "glaze": (
        "glaze was created for extremely fast, reflection-based JSON "
        "(and other formats) on modern C++. The problem was that C++ "
        "JSON usually meant a DOM or hand-written macros. glaze maps "
        "structs directly with compile-time reflection."
    ),
    "yaml-cpp": (
        "yaml-cpp is a YAML parser/emitter for C++. YAML exists as a "
        "human-friendly config language. yaml-cpp is the usual C++ "
        "implementation of that model."
    ),
    "jsoncons": (
        "jsoncons is a C++ library for JSON and binary JSON-family "
        "formats (CBOR, BSON, MessagePack). It was written as a "
        "consistent, typed encode/decode toolkit rather than a single "
        "DOM."
    ),
    "bitsery": (
        "bitsery is an explicit-schema binary serializer for C++. The "
        "problem was that many C++ binaries were either reflection-slow "
        "or ad-hoc. bitsery makes the schema the API (`object` / "
        "`container`)."
    ),
    "cereal": (
        "cereal was created as a C++11 header-only archive library "
        "(binary, JSON, XML) in the Boost.Serialization design space, "
        "but simpler. The problem was Boost.Serialization's weight. "
        "cereal uses output/input archives on existing types."
    ),
    "cista": (
        "Cista++ serializes C++ object graphs as offset-based, "
        "pointer-free images. The problem was that pointer graphs are "
        "not portable or mmap-friendly. Cista writes a relocatable "
        "layout."
    ),
    "yas": (
        "YAS (Yet Another Serializer) is a high-performance C++ binary "
        "archive library. It was written as a microbenchmark staple: "
        "serialize structs with very little abstraction cost."
    ),
    "zpp-bits": (
        "zpp_bits is a compile-time binary serializer for modern C++. "
        "The problem was runtime reflection and verbose archive APIs. "
        "It uses template `out` / `in` over tuples and structs."
    ),
    "boost-ser": (
        "Boost.Serialization is the classic C++ archive framework. It "
        "was created so C++ programs could persist object graphs "
        "portably across Boost archives. This row times the binary "
        "archive."
    ),
    "foundation-json": (
        "Foundation's JSONEncoder/JSONDecoder are Apple's standard "
        "Codable JSON codecs. They exist so Swift can speak JSON with "
        "the language's Codable model. On Linux this is swift-corelibs-"
        "foundation, not the Apple OS binary."
    ),
    "ikigajson": (
        "IkigaJSON is a server-oriented JSON encoder/decoder for Swift. "
        "The problem was Foundation JSON performance on Linux servers. "
        "IkigaJSON implements Codable with a faster core."
    ),
    "yams": (
        "Yams is a Swift wrapper around libyaml. YAML exists as a "
        "human-friendly config language. Yams is the usual Swift YAML "
        "library."
    ),
    "swift-cbor": (
        "swift-cbor is a Codable CBOR implementation for Swift. CBOR is "
        "the IETF binary JSON-like format. The library maps Codable "
        "types to RFC 8949."
    ),
    "swift-msgpack": (
        "swift-msgpack is a Codable MessagePack implementation for "
        "Swift. MessagePack exists as compact binary JSON. This library "
        "is a straightforward Codable backend."
    ),
    "swift-protobuf": (
        "swift-protobuf is Apple's official Protocol Buffers runtime for "
        "Swift. Protobuf exists as a language-neutral IDL and wire "
        "format. This package generates Swift from `.proto`."
    ),
    "swift-avro": (
        "SwiftAvroCore implements Apache Avro for Swift. Avro exists for "
        "compact, schema-driven records. The library encodes binary Avro "
        "with a schema."
    ),
    "swift-bson": (
        "swift-bson is MongoDB's official BSON library for Swift. BSON "
        "exists so MongoDB can store typed documents. This package "
        "implements that spec for Codable-style use."
    ),
    "swift-toml": (
        "mattt/swift-toml (toml++) is a TOML library for Swift. TOML "
        "exists as an obvious config language. This row times that "
        "implementation (map-root wrap for N>1)."
    ),
    "plist": (
        "Foundation PropertyListEncoder writes Apple property lists. "
        "plists exist so Apple platforms can store typed configuration. "
        "This row times the binary plist path."
    ),
    "xmlcoder": (
        "XMLCoder is a Codable XML encoder/decoder for Swift. The "
        "problem was that Swift had JSON Codable but not a first-class "
        "XML Codable. XMLCoder maps Codable types to XML elements."
    ),
    "binarycodable": (
        "BinaryCodable is a pure-Swift binary Codable implementation. "
        "It was written so Swift types could have a simple binary "
        "encoding without an IDL — Swift-only, not a public standard."
    ),
    "php-json": (
        "PHP's `json_encode` / `json_decode` are the language's standard "
        "JSON APIs. They exist so PHP can speak the web's data format "
        "without a package. This row times the bundled ext-json."
    ),
    "php-serialize": (
        "PHP `serialize` / `unserialize` is the language's native object "
        "format. It exists so PHP can persist values across requests. "
        "It is PHP-only and unsafe for untrusted input."
    ),
    "symfony-ser": (
        "The Symfony Serializer component was created so Symfony apps "
        "had a normalizer/encoder pipeline for JSON, XML, and more. The "
        "problem was ad-hoc `json_encode` of domain objects. This suite "
        "times the JSON and XML encoders."
    ),
    "jms": (
        "JMS Serializer was created for PHP applications that needed "
        "annotation-driven object serialization (especially APIs). The "
        "problem was mapping rich object graphs to JSON. This row times "
        "the JSON encoder."
    ),
    "symfony-yaml": (
        "The Symfony YAML component is a pure-PHP YAML parser/dumper. "
        "YAML exists as a human-friendly config language. Symfony YAML "
        "is the common userland implementation in PHP apps."
    ),
    "rybakit-msgpack": (
        "rybakit/msgpack is a pure-PHP MessagePack implementation. "
        "MessagePack exists as compact binary JSON. This package is the "
        "userland baseline versus the PECL extension."
    ),
    "cbor-php": (
        "spomky-labs/cbor-php implements RFC 8949 CBOR in PHP. CBOR is "
        "the IETF binary JSON-like format. The library is a PHP encoder/"
        "decoder of that RFC."
    ),
    "avro-php": (
        "flix-tech/avro-php is a PHP implementation of Apache Avro. "
        "Avro exists for compact, schema-driven records. This row times "
        "binary Avro (not the object container file format)."
    ),
    "php-simdjson": (
        "ext-simdjson binds the simdjson parser to PHP. simdjson was "
        "created to parse JSON at memory-bandwidth speeds. This row uses "
        "SIMD only for decode; encode is `json_encode`."
    ),
    "igbinary": (
        "igbinary is a PECL replacement for PHP `serialize` with a more "
        "compact binary. The problem was PHP's verbose native serializer "
        "in caches and sessions. igbinary drops duplicate strings and "
        "uses a denser layout."
    ),
    "msgpack-pecl": (
        "ext-msgpack is the official PECL MessagePack extension for PHP. "
        "MessagePack exists as compact binary JSON. The C extension is "
        "the fast path versus userland MessagePack."
    ),
    "yaml-pecl": (
        "ext-yaml is the PECL binding to LibYAML. YAML exists as a "
        "human-friendly config language. The extension is the C-speed "
        "path versus Symfony's pure-PHP YAML."
    ),
    "zig-std-json": (
        "Zig's `std.json` is the standard-library JSON codec. It exists "
        "so Zig programs can speak JSON without a package. This suite "
        "times typed `parseFromSlice` and, separately, the Scanner path."
    ),
    "zig-zon": (
        "ZON (Zig Object Notation) is Zig's own data notation, in the "
        "standard library. It exists as a Zig-native text format for "
        "config and data. This row times official stringify/parse."
    ),
    "serde-zig": (
        "serde.zig is a format-agnostic serialization framework for Zig "
        "that walks types with `@typeInfo` at comptime. The problem was "
        "writing a new field walk per format. One API covers JSON, "
        "MessagePack, YAML, TOML, ZON, and XML."
    ),
    "zig-msgpack": (
        "zigcc/zig-msgpack is a MessagePack implementation for Zig. "
        "MessagePack exists as compact binary JSON. This package exposes "
        "a Payload encode/decode API."
    ),
    "json-zig": (
        "lalinsky/json.zig is a typed JSON library for Zig: the encoder and "
        "decoder are comptime-specialized into the Zig type, so there is no "
        "DOM and no runtime schema. It exists to make JSON cheap for APIs "
        "with a fixed schema, and it reads and writes std.Io readers and "
        "writers, so a value larger than the buffer still decodes."
    ),
    "msgpack-zig": (
        "lalinsky/msgpack.zig is another MessagePack library for Zig "
        "with a typed encode/decode API. It exists as a native Zig "
        "implementation of the same MessagePack spec."
    ),
    "zbor": (
        "zbor is a native Zig CBOR library. CBOR is the IETF binary "
        "JSON-like format. zbor implements stringify/parse for Zig types."
    ),
    "s2s": (
        "s2s (struct to stream) is a Zig-only binary encoder that writes "
        "structs to a stream. It was created as a simple native binary "
        "path, not a public interchange standard."
    ),
    "zig-protobuf": (
        "Arwalk/zig-protobuf generates Zig from `.proto` files. "
        "Protocol Buffers exist as a language-neutral IDL. This package "
        "is the Zig implementation this suite uses."
    ),
    "zig-flatbuffers": (
        "nDimensional/zig-flatbuffers generates Zig from FlatBuffers "
        "schemas. FlatBuffers exists so readers can use data without "
        "unpacking. This is the Zig codegen this suite times."
    ),
    "comptime-bin": (
        "comptime-bin is the suite's in-tree Zig baseline: a comptime "
        "`@typeInfo` walk that writes little-endian, length-prefixed "
        "fields. It exists because `@bitCast` of a live fixture is not "
        "a valid encoding (slices are pointers)."
    ),
    "emberjson": (
        "EmberJson is a Mojo JSON library using language reflection. "
        "Mojo is a young language; EmberJson exists to give it a "
        "community JSON serialize/deserialize path. This row times that "
        "reflection API."
    ),
    "ehsanmok-json": (
        "ehsanmok/json is a Mojo JSON parser/serializer. It was written "
        "to give Mojo a JSON stack with a Value tree and a "
        "`serialize_json` path. Decode in this suite is `loads` plus a "
        "Value walk."
    ),
    "gld-json": (
        "gld-json (leo-gan) is a typed JSON WireWriter/Reader for Mojo. "
        "It was created because Mojo lacked a suite-ready, typed JSON "
        "codec aligned with this benchmark's domain types."
    ),
    "gld-cbor": (
        "gld-cbor (leo-gan) implements CBOR for Mojo via a `CborDatum` "
        "trait. CBOR is the IETF binary JSON-like format. The library "
        "exists to give Mojo a first-class CBOR encode/decode."
    ),
    "gld-protobuf": (
        "gld-protobuf (leo-gan) is a Protocol Buffers implementation for "
        "Mojo. Protobuf exists as a language-neutral IDL. This library "
        "generates Mojo from the suite `.proto` and times encode/decode."
    ),
    "gld-avro": (
        "gld-avro (leo-gan) implements Apache Avro for Mojo via "
        "`AvroDatum`. Avro exists for compact, schema-driven records. "
        "The library gives Mojo that encoding."
    ),
    "mojo-toml": (
        "DataBooth/mojo-toml is a TOML library for Mojo. TOML exists as "
        "an obvious config language. This is the published Mojo TOML "
        "implementation (`gld-toml` is not out yet)."
    ),
    "gld-yaml": (
        "gld-yaml (leo-gan) implements YAML encode/decode for Mojo. YAML "
        "exists as a human-friendly config language. The library was "
        "written so Mojo can speak YAML on suite types."
    ),
    "gld-msgpack": (
        "gld-messagepack (leo-gan) is a MessagePack WireWriter/Reader "
        "for Mojo. MessagePack exists as compact binary JSON. The "
        "library gives Mojo that format."
    ),
}

# (language, name) -> SPECIFICS key. Default: try the name, then a heuristic.
SPEC_KEY: dict[tuple[str, str], str] = {
    ("c", "cJSON"): "cjson",
    ("c", "jansson"): "jansson",
    ("c", "yyjson"): "yyjson",
    ("c", "json-c"): "json-c",
    ("c", "parson"): "parson",
    ("c", "mpack"): "mpack",
    ("c", "msgpack-c"): "msgpack-c",
    ("c", "tinycbor"): "tinycbor",
    ("c", "cbor-encode"): "tinycbor",
    ("c", "libcbor"): "libcbor",
    ("c", "libcbor-stream"): "libcbor",
    ("c", "qcbor"): "qcbor",
    ("c", "zcbor"): "zcbor",
    ("c", "libbson"): "libbson",
    ("c", "ubj"): "ubj",
    ("c", "flatcc"): "flatcc",
    ("c", "avro-c"): "avro-c",
    ("c", "nanopb"): "nanopb",
    ("c", "protobuf-c"): "protobuf-c",
    ("c", "protobuf"): "protobuf",
    ("c", "protobuf-wire"): "protobuf-wire",
    ("c", "custom-binary"): "custom-binary",
    ("c", "libyaml"): "libyaml",
    ("python", "json"): "cpython-json",
    ("python", "orjson"): "orjson",
    ("python", "msgspec"): "msgspec",
    ("python", "msgspec-msgpack"): "msgspec",
    ("python", "rapidjson"): "rapidjson-py",
    ("python", "pydantic"): "pydantic",
    ("python", "mashumaro"): "mashumaro",
    ("python", "serpyco-rs"): "serpyco-rs",
    ("python", "yaml"): "pyyaml",
    ("python", "cbor2"): "cbor2",
    ("python", "msgpack"): "msgpack-py",
    ("python", "protobuf"): "protobuf",
    ("python", "avro"): "fastavro",
    ("python", "flatbuffers"): "flatbuffers",
    ("python", "pickle"): "pickle",
    ("python", "cloudpickle"): "cloudpickle",
    ("python", "dill"): "dill",
    ("python", "tomllib"): "tomllib",
    ("python", "amazon-ion"): "amazon-ion",
    ("python", "bson"): "bson",
    ("python", "flexbuffers"): "flexbuffers",
    ("python", "newsmile"): "smile",
    ("python", "plistlib"): "plistlib",
    ("python", "py-ubjson"): "py-ubjson",
    ("javascript", "JSON.stringify"): "json-stringify",
    ("javascript", "fast-json-stringify"): "fast-json-stringify",
    ("javascript", "simdjson-parse+JSON.stringify"): "simdjson-js",
    ("javascript", "js-yaml"): "js-yaml",
    ("javascript", "@msgpack/msgpack"): "msgpack-js",
    ("javascript", "msgpackr"): "msgpackr",
    ("javascript", "json-pack-msgpack"): "json-pack",
    ("javascript", "cbor"): "node-cbor",
    ("javascript", "cbor-x"): "cbor-x",
    ("javascript", "bson"): "bson",
    ("javascript", "avsc"): "avsc",
    ("javascript", "protobufjs"): "protobufjs",
    ("javascript", "protobuf-es"): "protobuf-es",
    ("javascript", "google-protobuf"): "google-protobuf-js",
    ("javascript", "flatbuffers"): "flatbuffers",
    ("javascript", "flexbuffers"): "flexbuffers",
    ("javascript", "bebop"): "bebop",
    ("javascript", "v8-serializer"): "v8-serializer",
    ("javascript", "devalue"): "devalue",
    ("javascript", "sia"): "sia",
    ("javascript", "bser"): "bser",
    ("go", "encoding/json"): "go-json",
    ("go", "goccy/go-json"): "goccy-json",
    ("go", "jsoniter"): "jsoniter-go",
    ("go", "segmentio/encoding/json"): "segmentio-json",
    ("go", "sonic"): "sonic",
    ("go", "ugorji/json"): "ugorji",
    ("go", "ugorji/cbor"): "ugorji",
    ("go", "ugorji/msgpack"): "ugorji",
    ("go", "goccy/go-yaml"): "goccy-yaml",
    ("go", "fxamacker/cbor"): "fxamacker-cbor",
    ("go", "vmihailenco/msgpack"): "vmihailenco-msgpack",
    ("go", "shamaton/msgpack"): "shamaton-msgpack",
    ("go", "shamaton/msgpack (array)"): "shamaton-msgpack",
    ("go", "protobuf"): "protobuf",
    ("go", "hamba/avro"): "hamba-avro",
    ("go", "linkedin/goavro"): "goavro",
    ("go", "mongo-bson"): "bson",
    ("go", "pelletier/go-toml"): "go-toml",
    ("go", "encoding/gob"): "gob",
    ("go", "kelindar/binary"): "kelindar-binary",
    ("java", "jackson"): "jackson",
    ("java", "jackson-yaml"): "jackson",
    ("java", "jackson-cbor"): "jackson",
    ("java", "jackson-smile"): "jackson",
    ("java", "gson"): "gson",
    ("java", "fastjson2"): "fastjson2",
    ("java", "dsl-json"): "dsl-json",
    ("java", "moshi"): "moshi",
    ("java", "jsoniter"): "jsoniter-java",
    ("java", "msgpack"): "msgpack-java",
    ("java", "protobuf"): "protobuf",
    ("java", "avro"): "avro",
    ("java", "bson"): "bson",
    ("java", "ion"): "ion",
    ("java", "flatbuffers"): "flatbuffers",
    ("java", "capnproto"): "capnproto",
    ("java", "java-serialization"): "java-serialization",
    ("java", "kryo"): "kryo",
    ("java", "fory"): "fory",
    ("java", "hessian"): "hessian",
    ("java", "protostuff"): "protostuff",
    ("kotlin", "kotlinx-json"): "kotlinx-serialization",
    ("kotlin", "kotlinx-cbor"): "kotlinx-serialization",
    ("kotlin", "kotlinx-protobuf"): "kotlinx-serialization",
    ("kotlin", "kotlinx-properties"): "kotlinx-serialization",
    ("kotlin", "kotlinx-hocon"): "hocon",
    ("kotlin", "jackson"): "jackson",
    ("kotlin", "jackson-cbor"): "jackson",
    ("kotlin", "gson"): "gson",
    ("kotlin", "moshi-codegen"): "moshi",
    ("kotlin", "moshi-reflect"): "moshi",
    ("kotlin", "kaml"): "kaml",
    ("kotlin", "obor"): "obor",
    ("kotlin", "msgpack"): "msgpack-java",
    ("kotlin", "protobuf"): "protobuf",
    ("kotlin", "protobuf-kotlin"): "protobuf",
    ("kotlin", "avro"): "avro",
    ("kotlin", "avro4k"): "avro4k",
    ("kotlin", "kbson"): "kbson",
    ("kotlin", "kotlinx-ion"): "ion",
    ("kotlin", "tomlkt"): "tomlkt",
    ("kotlin", "flatbuffers"): "flatbuffers",
    ("kotlin", "capnproto"): "capnproto",
    ("kotlin", "thrift"): "thrift",
    ("kotlin", "kryo"): "kryo",
    ("kotlin", "fory"): "fory",
    ("kotlin", "protostuff"): "protostuff",
    ("csharp", "System.Text.Json"): "stj",
    ("csharp", "Json.Net"): "newtonsoft",
    ("csharp", "Json.Net (Helper)"): "newtonsoft",
    ("csharp", "Jil"): "jil",
    ("csharp", "SpanJson"): "spanjson",
    ("csharp", "Utf8Json"): "utf8json",
    ("csharp", "NetJSON"): "netjson",
    ("csharp", "fastJson"): "fastjson-cs",
    ("csharp", "ServiceStack Json"): "servicestack",
    ("csharp", "ServiceStack"): "servicestack",
    ("csharp", "FsPicklerJson"): "fspickler",
    ("csharp", "FsPickler"): "fspickler",
    ("csharp", "MS DataContract Json"): "datacontract",
    ("csharp", "MS DataContract"): "datacontract",
    ("csharp", "MS Bond Json"): "bond",
    ("csharp", "MS Bond Compact"): "bond",
    ("csharp", "MS Bond Fast"): "bond",
    ("csharp", "YamlDotNet"): "yamldotnet",
    ("csharp", "SharpYaml"): "sharpyaml",
    ("csharp", "MessagePack-CSharp"): "msgpack-csharp",
    ("csharp", "Google.Protobuf"): "protobuf",
    ("csharp", "ProtoBuf"): "protobuf-net",
    ("csharp", "LightProto"): "lightproto",
    ("csharp", "Apache.Avro"): "avro",
    ("csharp", "FlatSharp"): "flatsharp",
    ("csharp", "MS XmlSerializer"): "xmlserializer",
    ("csharp", "YAXLib"): "yaxlib",
    ("csharp", "ExtendedXmlSerializer"): "extendedxml",
    ("csharp", "CsvHelper"): "csvhelper",
    ("csharp", "MS Binary"): "binaryformatter",
    ("csharp", "BinaryPack"): "binarypack",
    ("csharp", "Ceras"): "ceras",
    ("csharp", "GroBuf"): "grobuf",
    ("csharp", "Hyperion"): "hyperion",
    ("csharp", "MemoryPack"): "memorypack",
    ("csharp", "Migrant"): "migrant",
    ("csharp", "NetSerializer"): "netserializer",
    ("csharp", "SharpSerializer"): "sharpserializer",
    ("csharp", "ZeroFormatter"): "zeroformatter",
    ("rust", "serde_json"): "serde-json",
    ("rust", "simd-json"): "simd-json",
    ("rust", "sonic-rs"): "sonic-rs",
    ("rust", "serde_yaml"): "serde-yaml",
    ("rust", "ciborium"): "ciborium",
    ("rust", "minicbor"): "minicbor",
    ("rust", "rmp-serde"): "rmp-serde",
    ("rust", "prost"): "prost",
    ("rust", "serde_avro_fast"): "serde-avro-fast",
    ("rust", "bson"): "bson",
    ("rust", "flexbuffers"): "flexbuffers",
    ("rust", "bincode"): "bincode",
    ("rust", "bitcode"): "bitcode",
    ("rust", "nanoserde"): "nanoserde",
    ("rust", "postcard"): "postcard",
    ("rust", "speedy"): "speedy",
    ("rust", "rkyv"): "rkyv",
    ("cpp", "nlohmann_json"): "nlohmann",
    ("cpp", "nlohmann_cbor"): "nlohmann",
    ("cpp", "nlohmann_msgpack"): "nlohmann",
    ("cpp", "nlohmann_bson"): "nlohmann",
    ("cpp", "nlohmann_ubjson"): "nlohmann",
    ("cpp", "rapidjson"): "rapidjson",
    ("cpp", "simdjson"): "simdjson",
    ("cpp", "yyjson"): "yyjson",
    ("cpp", "arduinojson"): "arduinojson",
    ("cpp", "glaze"): "glaze",
    ("cpp", "yaml-cpp"): "yaml-cpp",
    ("cpp", "msgpack"): "msgpack-c",
    ("cpp", "jsoncons_msgpack"): "jsoncons",
    ("cpp", "jsoncons_cbor"): "jsoncons",
    ("cpp", "jsoncons_bson"): "jsoncons",
    ("cpp", "protobuf"): "protobuf",
    ("cpp", "protobuf-wire"): "protobuf-wire",
    ("cpp", "avro"): "avro",
    ("cpp", "avro_c"): "avro-c",
    ("cpp", "flatbuffers"): "flatbuffers",
    ("cpp", "flexbuffers"): "flexbuffers",
    ("cpp", "capnproto"): "capnproto",
    ("cpp", "thrift"): "thrift",
    ("cpp", "bitsery"): "bitsery",
    ("cpp", "cereal"): "cereal",
    ("cpp", "cista"): "cista",
    ("cpp", "custom_binary"): "custom-binary",
    ("cpp", "yas"): "yas",
    ("cpp", "zpp_bits"): "zpp-bits",
    ("cpp", "boost_serialization"): "boost-ser",
    ("swift", "Foundation.JSONEncoder"): "foundation-json",
    ("swift", "IkigaJSON"): "ikigajson",
    ("swift", "Yams"): "yams",
    ("swift", "SwiftCbor"): "swift-cbor",
    ("swift", "SwiftMsgpack"): "swift-msgpack",
    ("swift", "SwiftProtobuf"): "swift-protobuf",
    ("swift", "protobuf-wire"): "protobuf-wire",
    ("swift", "FlatBuffers"): "flatbuffers",
    ("swift", "SwiftAvroCore"): "swift-avro",
    ("swift", "SwiftBSON"): "swift-bson",
    ("swift", "CapnProto"): "capnproto",
    ("swift", "TOML"): "swift-toml",
    ("swift", "Foundation.PropertyListEncoder"): "plist",
    ("swift", "XMLCoder"): "xmlcoder",
    ("swift", "BinaryCodable"): "binarycodable",
    ("php", "json"): "php-json",
    ("php", "serialize"): "php-serialize",
    ("php", "symfony-json"): "symfony-ser",
    ("php", "symfony-xml"): "symfony-ser",
    ("php", "jms-json"): "jms",
    ("php", "yaml"): "symfony-yaml",
    ("php", "rybakit-msgpack"): "rybakit-msgpack",
    ("php", "protobuf"): "protobuf",
    ("php", "avro"): "avro-php",
    ("php", "cbor"): "cbor-php",
    ("php", "simdjson"): "php-simdjson",
    ("php", "igbinary"): "igbinary",
    ("php", "msgpack-pecl"): "msgpack-pecl",
    ("php", "bson"): "bson",
    ("php", "yaml-pecl"): "yaml-pecl",
    ("zig", "std.json"): "zig-std-json",
    ("zig", "std.json.scanner"): "zig-std-json",
    ("zig", "std.zon"): "zig-zon",
    ("zig", "serde.json"): "serde-zig",
    ("zig", "serde.yaml"): "serde-zig",
    ("zig", "serde.toml"): "serde-zig",
    ("zig", "serde.msgpack"): "serde-zig",
    ("zig", "serde.zon"): "serde-zig",
    ("zig", "serde.xml"): "serde-zig",
    ("zig", "zig-msgpack"): "zig-msgpack",
    ("zig", "msgpack.zig"): "msgpack-zig",
    ("zig", "json.zig"): "json-zig",
    ("zig", "zbor"): "zbor",
    ("zig", "s2s"): "s2s",
    ("zig", "protobuf"): "zig-protobuf",
    ("zig", "protobuf-wire"): "protobuf-wire",
    ("zig", "flatbuffers"): "zig-flatbuffers",
    ("zig", "capnproto"): "capnproto",
    ("zig", "comptime-bin"): "comptime-bin",
    ("mojo", "EmberJson"): "emberjson",
    ("mojo", "ehsanmok-json"): "ehsanmok-json",
    ("mojo", "mojo-json"): "gld-json",
    ("mojo", "mojo-cbor"): "gld-cbor",
    ("mojo", "mojo-protobuf"): "gld-protobuf",
    ("mojo", "mojo-avro"): "gld-avro",
    ("mojo", "mojo-toml"): "mojo-toml",
    ("mojo", "gld-yaml"): "gld-yaml",
    ("mojo", "mojo-msgpack"): "gld-msgpack",
}

# Extra sentence for a specific row (path / format variant).
EXTRA: dict[tuple[str, str], str] = {
    ("python", "msgspec-msgpack"): (
        "This row times the MessagePack encoder/decoder on the same Struct types."
    ),
    ("c", "libcbor-stream"): (
        "This row times libcbor's streaming `cbor_encode_*` API, not the DOM `cbor_load` decoder."
    ),
    ("c", "cbor-encode"): (
        "Older log name for the TinyCBOR encode path; same Intel TinyCBOR library."
    ),
    ("javascript", "simdjson-parse+JSON.stringify"): (
        "Only deserialize uses SIMD; serialize is stdlib `JSON.stringify`."
    ),
    ("go", "shamaton/msgpack (array)"): (
        "This row uses struct-as-array (no field-name keys) and the matching stream helpers."
    ),
    ("go", "ugorji/json"): "This row times the JsonHandle.",
    ("go", "ugorji/cbor"): "This row times the CborHandle.",
    ("go", "ugorji/msgpack"): "This row times the MsgpackHandle.",
    ("java", "jackson-cbor"): "This row times Jackson's CBOR mapper.",
    ("java", "jackson-smile"): "This row times Jackson's Smile (binary JSON) mapper.",
    ("java", "jackson-yaml"): "This row times Jackson's YAML mapper.",
    ("kotlin", "moshi-codegen"): (
        "This row times KSP-generated JsonAdapters on the same domain types as moshi-reflect."
    ),
    ("kotlin", "moshi-reflect"): (
        "This row times reflection adapters (`KotlinJsonAdapterFactory`) on the same types as moshi-codegen."
    ),
    ("kotlin", "protobuf-kotlin"): (
        "This row uses the generated Kotlin DSL builders on the same protobuf wire types as the Java API row."
    ),
    ("csharp", "Json.Net (Helper)"): "This row times a helper call path of the same Newtonsoft library.",
    ("csharp", "MS Bond Compact"): "This row times Bond Compact Binary.",
    ("csharp", "MS Bond Fast"): "This row times Bond Fast Binary.",
    ("csharp", "MS Bond Json"): "This row times the Bond JSON protocol.",
    ("csharp", "ServiceStack"): "This row times the non-JSON ServiceStack type serializer.",
    ("csharp", "ServiceStack Json"): "This row times ServiceStack.Text JSON.",
    ("cpp", "nlohmann_cbor"): "This row times `to_cbor` / `from_cbor`.",
    ("cpp", "nlohmann_msgpack"): "This row times `to_msgpack` / `from_msgpack`.",
    ("cpp", "nlohmann_bson"): "This row times `to_bson` / `from_bson`.",
    ("cpp", "nlohmann_ubjson"): "This row times `to_ubjson` / `from_ubjson`.",
    ("cpp", "jsoncons_cbor"): "This row times jsoncons `cbor::encode` / `decode`.",
    ("cpp", "jsoncons_msgpack"): "This row times jsoncons `msgpack::encode` / `decode`.",
    ("cpp", "jsoncons_bson"): "This row times jsoncons `bson::encode` / `decode`.",
    ("zig", "std.json.scanner"): (
        "Decode is `Scanner` + `parseFromTokenSource`; stringify is the same as `std.json`."
    ),
    ("zig", "serde.json"): "This row is the JSON backend of serde.zig.",
    ("zig", "serde.msgpack"): "This row is the MessagePack backend of serde.zig.",
    ("zig", "serde.yaml"): "This row is the YAML backend of serde.zig (message / strings only).",
    ("zig", "serde.toml"): "This row is the TOML backend of serde.zig.",
    ("zig", "serde.zon"): "This row is the ZON backend of serde.zig.",
    ("zig", "serde.xml"): "This row is the XML backend of serde.zig (message / strings only).",
}


def load_measured_versions() -> dict[tuple[str, str], str]:
    """Map (language, SerializerName) → SerializerVersion from latest benches."""
    out: dict[tuple[str, str], str] = {}
    data_dir = ROOT / "dashboard" / "public" / "data"
    for path in sorted(data_dir.glob("*_latest.json.gz")):
        stem = path.name.removesuffix("_latest.json.gz")
        if stem.startswith("stats_"):
            continue
        lang = stem
        try:
            payload = json.loads(gzip.open(path).read())
        except (OSError, json.JSONDecodeError) as exc:
            print(f"WARN skip versions in {path.name}: {exc}", file=sys.stderr)
            continue
        items = ((payload.get("configs") or {}).get("serializers") or {}).get("items") or []
        for it in items:
            name = it.get("name")
            ver = it.get("version")
            if name and ver:
                out[(lang, str(name))] = str(ver)
        for g in ((payload.get("stats") or {}).get("groups") or []):
            name = g.get("serializer")
            ver = g.get("serializer_version")
            if name and ver:
                out.setdefault((lang, str(name)), str(ver))
    return out


def source_url(lang: str, name: str, docs: str) -> str:
    if (lang, name) in URL_OVERRIDE:
        return URL_OVERRIDE[(lang, name)]
    repo = _repo_root_from_url(docs)
    if repo:
        return repo
    return docs


def specifics_text(lang: str, name: str) -> str:
    key = SPEC_KEY.get((lang, name))
    base = SPECIFICS.get(key or "", "")
    extra = EXTRA.get((lang, name), "")
    parts = [p for p in (base, extra) if p]
    if parts:
        return " ".join(parts)
    return (
        f"{name} is a registered serializer in the {lang} suite. "
        "This page links its upstream source; the language inventory table "
        "describes the timed call path."
    )


def _record(lang: str, name: str, docs: str, versions: dict[tuple[str, str], str]) -> dict[str, str]:
    rec = {"source_url": source_url(lang, name, docs)}
    ver = versions.get((lang, name))
    if ver:
        rec["version"] = ver
    rec["specifics"] = specifics_text(lang, name)
    return rec


def build() -> dict:
    versions = load_measured_versions()
    languages: dict[str, dict[str, dict[str, str]]] = defaultdict(dict)
    for lang, name, _formats, docs, _evidence in _load_compliance_catalog():
        languages[lang][name] = _record(lang, name, docs, versions)
    for lang, name, url in EXTRA_ROWS:
        languages[lang].setdefault(name, _record(lang, name, url, versions))
    missing_keys = []
    n_ver = 0
    for lang, items in languages.items():
        for name, rec in items.items():
            if rec["specifics"].startswith(f"{name} is a registered"):
                missing_keys.append(f"{lang}/{name}")
            if rec.get("version"):
                n_ver += 1
    if missing_keys:
        print("WARN fallback specifics:", ", ".join(missing_keys), file=sys.stderr)
    print(f"attached SerializerVersion to {n_ver} / {sum(len(v) for v in languages.values())} rows")
    return {
        "version": 1,
        "description": (
            "Source repository (or stdlib / in-tree path), last measured "
            "SerializerVersion from the latest bench, and origin text for "
            "every registered serializer. Dashboard name links and "
            "docs/<lang>/index.md Specifics are generated from this file."
        ),
        "languages": {k: dict(sorted(v.items())) for k, v in sorted(languages.items())},
    }


def main() -> int:
    data = build()
    text = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    CONFIG_OUT.parent.mkdir(parents=True, exist_ok=True)
    DASH_OUT.parent.mkdir(parents=True, exist_ok=True)
    CONFIG_OUT.write_text(text, encoding="utf-8")
    DASH_OUT.write_text(text, encoding="utf-8")
    n = sum(len(v) for v in data["languages"].values())
    print(f"wrote {n} serializers → {CONFIG_OUT.relative_to(ROOT)} and {DASH_OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
