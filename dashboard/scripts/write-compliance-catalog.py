#!/usr/bin/env python3
"""Author compliance/serializer-standards.json and dashboard/compliance-catalog.js.

Runtime source of truth for Standard membership is
compliance/serializer-standards.json. The dashboard classifier and every
language compliance runner read that file. This script authors it (plus
docs/evidence for the dashboard). Edit CATALOG below, then re-run.
Do not invent formats from the serializer name.
"""
from __future__ import annotations

from pathlib import Path

# language, name, formats, official docs URL, evidence quote/paraphrase
# formats=[] means no public interchange spec in the Compliance catalog.
CATALOG: list[tuple[str, str, list[str], str, str]] = []


def add(lang: str, name: str, formats: list[str], docs: str, evidence: str) -> None:
    CATALOG.append((lang, name, formats, docs, evidence))


# --- C (official project docs) ---
add("c", "cJSON", ["json"], "https://github.com/DaveGamble/cJSON",
    'README: "Ultralightweight JSON parser in ANSI C" and points at json.org.')
add("c", "jansson", ["json"], "https://jansson.readthedocs.io/",
    'Docs: "C library for encoding, decoding and manipulating JSON data"; RFC 4627/8259 conformance page.')
add("c", "yyjson", ["json"], "https://github.com/ibireme/yyjson",
    'Project docs: "high performance JSON library" targeting ANSI C; API is JSON document read/write.')
add("c", "json-c", ["json"], "https://github.com/json-c/json-c",
    'README: "A JSON implementation in C" that "aims to conform to RFC 8259".')
add("c", "parson", ["json"], "https://github.com/kgabis/parson",
    'README: "Parson is a lightweight json library written in C" (links json.org).')
add("c", "mpack", ["msgpack"], "https://github.com/ludocode/mpack",
    'README: "C implementation of an encoder and decoder for the MessagePack serialization format" (msgpack.org[C]).')
add("c", "msgpack-c", ["msgpack"], "https://github.com/msgpack/msgpack-c/blob/c_master/README.md",
    'Official C library: "MessagePack is an efficient binary serialization format".')
add("c", "tinycbor", ["cbor"], "https://github.com/intel/tinycbor",
    'Intel README title: "Concise Binary Object Representation (CBOR) Library".')
add("c", "cbor-encode", ["cbor"], "https://github.com/intel/tinycbor",
    "Older log name for the tinycbor encode path; same Intel TinyCBOR CBOR library.")
add("c", "libcbor", ["cbor"], "https://github.com/PJK/libcbor",
    'libcbor: "CBOR protocol implementation for C" (RFC 7049 / 8949).')
add("c", "libcbor-stream", ["cbor"], "https://github.com/PJK/libcbor",
    "Same libcbor project; this row times the streaming encoder (cbor_encode_*).")
add("c", "qcbor", ["cbor"], "https://github.com/laurencelundblade/QCBOR",
    "QCBOR: Comprehensive, Safe, Professional, and Fast CBOR (RFC 8949) encoder/decoder.")
add("c", "zcbor", ["cbor"], "https://github.com/NordicSemiconductor/zcbor",
    "Nordic zcbor: CBOR encoder/decoder and CDDL code generator.")
add("c", "libbson", ["bson"], "https://mongoc.org/libbson/current/",
    'Official libbson: "builds, parses, and iterates BSON documents" (bsonspec.org).')
add("c", "ubj", ["ubjson"], "https://ubjson.org/",
    "Suite in-tree UBJSON marker codec; format is Universal Binary JSON (ubjson.org).")
add("c", "flatcc", ["flatbuffers"], "https://github.com/dvidelabs/flatcc",
    'README: "FlatCC FlatBuffers in C for C"; generates FlatBuffers code from a schema.')
add("c", "avro-c", ["avro"], "https://avro.apache.org/docs/1.11.3/api/c/",
    "Official Apache Avro C API: compact binary Avro encoding.")
add("c", "nanopb", ["protobuf"], "https://jpa.kapsi.fi/nanopb/",
    "Official nanopb: Protocol Buffers implementation in C.")
add("c", "protobuf-c", ["protobuf"], "https://github.com/protobuf-c/protobuf-c",
    "Official protobuf-c: C bindings for Google Protocol Buffers.")
add("c", "protobuf", ["protobuf"], "https://protobuf.dev/",
    "Google libprotobuf C++ runtime (C suite Google row).")
add("c", "protobuf-wire", ["protobuf"], "https://protobuf.dev/programming-guides/encoding/",
    "In-tree proto3 tag reader implementing the published Protocol Buffers encoding guide.")
add("c", "custom-binary", [], "https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/docs/c/index.md",
    "Suite length-prefixed V2 baseline; no public interchange spec.")

# --- Python ---
add("python", "json", ["json"], "https://docs.python.org/3/library/json.html",
    "stdlib json: JSON encoder/decoder (RFC 7159 / 8259).")
add("python", "orjson", ["json"], "https://github.com/ijl/orjson",
    'README: "fast, correct JSON library for Python".')
add("python", "msgspec", ["json"], "https://jcristharif.com/msgspec/",
    "Official docs: msgspec.json encode/decode (this row times the JSON path).")
add("python", "msgspec-msgpack", ["msgpack"], "https://jcristharif.com/msgspec/api.html#msgspec.msgpack",
    "Official API: msgspec.msgpack.Encoder/Decoder — MessagePack.")
add("python", "rapidjson", ["json"], "https://python-rapidjson.readthedocs.io/",
    "python-rapidjson: Python wrapper of RapidJSON (JSON).")
add("python", "pydantic", ["json"], "https://docs.pydantic.dev/latest/concepts/json/",
    "Pydantic docs: JSON serialization via TypeAdapter / model_dump_json.")
add("python", "mashumaro", ["json"], "https://github.com/Fatal1ty/mashumaro",
    "mashumaro: dataclass JSON (and other) codecs; this row times ORJSON JSON.")
add("python", "serpyco-rs", ["json"], "https://github.com/opengovsg/serpyco-rs",
    "serpyco-rs: fast Python dataclass JSON serialization.")
add("python", "yaml", ["yaml"], "https://pyyaml.org/wiki/PyYAMLDocumentation",
    "PyYAML: YAML 1.1 processor.")
add("python", "cbor2", ["cbor"], "https://cbor2.readthedocs.io/",
    "cbor2: pure-Python CBOR (RFC 8949) implementation.")
add("python", "msgpack", ["msgpack"], "https://msgpack.org/",
    "Official msgpack Python package: MessagePack serialization.")
add("python", "protobuf", ["protobuf"], "https://protobuf.dev/",
    "Google protobuf Python runtime.")
add("python", "avro", ["avro"], "https://fastavro.readthedocs.io/",
    "fastavro: Apache Avro schemaless binary reader/writer.")
add("python", "flatbuffers", ["flatbuffers"], "https://flatbuffers.dev/",
    "Official FlatBuffers Python runtime (Builder / GetRootAs).")
add("python", "pickle", [], "https://docs.python.org/3/library/pickle.html",
    "stdlib pickle: Python-specific protocol, not a public interchange spec.")
add("python", "cloudpickle", [], "https://github.com/cloudpipe/cloudpickle",
    "Extended pickle; same Python-only protocol family.")
add("python", "dill", [], "https://dill.readthedocs.io/",
    "dill: extended pickle; Python-only.")
add("python", "tomllib", ["toml"], "https://docs.python.org/3/library/tomllib.html",
    "stdlib tomllib: TOML 1.0 parser.")
add("python", "amazon-ion", ["ion"], "https://amazon-ion.github.io/ion-docs/",
    "amazon.ion: official Amazon Ion library.")
add("python", "bson", ["bson"], "https://www.mongodb.com/docs/languages/python/pymongo-driver/current/data-formats/bson/",
    "pymongo bson: BSON documents.")
add("python", "flexbuffers", ["flatbuffers"], "https://flatbuffers.dev/flexbuffers.html",
    "Official FlexBuffers (FlatBuffers schemaless) docs.")
add("python", "newsmile", ["smile"], "https://github.com/FasterXML/smile-format-specification",
    "Smile binary JSON format (Jackson Smile spec).")
add("python", "plistlib", ["plist"], "https://docs.python.org/3/library/plistlib.html",
    "stdlib plistlib: Apple property lists.")
add("python", "py-ubjson", ["ubjson"], "https://github.com/Iotic-Labs/py-ubjson",
    "py-ubjson: Universal Binary JSON.")

# --- JavaScript ---
add("javascript", "JSON.stringify", ["json"], "https://tc39.es/ecma262/#sec-json.stringify",
    "ECMA-262 JSON.stringify / JSON.parse.")
add("javascript", "fast-json-stringify", ["json"], "https://github.com/fastify/fast-json-stringify",
    "fastify: schema-compiled JSON serializer.")
add("javascript", "simdjson-parse+JSON.stringify", ["json"], "https://github.com/simdjson/simdjson",
    "simdjson parse + JSON.stringify encode; JSON text.")
add("javascript", "js-yaml", ["yaml"], "https://github.com/nodeca/js-yaml",
    "js-yaml: YAML 1.2 parser/dumper.")
add("javascript", "@msgpack/msgpack", ["msgpack"], "https://github.com/msgpack/msgpack-javascript",
    "Official MessagePack JavaScript implementation.")
add("javascript", "msgpackr", ["msgpack"], "https://github.com/kriszyp/msgpackr",
    "msgpackr: MessagePack encoder/decoder.")
add("javascript", "json-pack-msgpack", ["msgpack"], "https://jsonjoy.com/libs/json-pack",
    "json-pack MsgPackEncoder/Decoder: MessagePack.")
add("javascript", "cbor", ["cbor"], "https://github.com/hildjj/node-cbor",
    "node-cbor: RFC 8949 CBOR.")
add("javascript", "cbor-x", ["cbor"], "https://github.com/kriszyp/cbor-x",
    "cbor-x: CBOR encoder/decoder.")
add("javascript", "bson", ["bson"], "https://www.mongodb.com/docs/drivers/node/current/data-formats/bson/",
    "Official MongoDB Node bson package.")
add("javascript", "avsc", ["avro"], "https://github.com/mtth/avsc",
    "avsc: Apache Avro for JavaScript.")
add("javascript", "protobufjs", ["protobuf"], "https://github.com/protobufjs/protobuf.js",
    "protobuf.js: Protocol Buffers for JavaScript.")
add("javascript", "protobuf-es", ["protobuf"], "https://github.com/bufbuild/protobuf-es",
    "Buf protobuf-es: Protocol Buffers for ECMAScript.")
add("javascript", "google-protobuf", ["protobuf"], "https://github.com/protocolbuffers/protobuf-javascript",
    "Official Google protobuf JavaScript runtime.")
add("javascript", "flatbuffers", ["flatbuffers"], "https://flatbuffers.dev/",
    "Official FlatBuffers JS/TS runtime.")
add("javascript", "flexbuffers", ["flatbuffers"], "https://flatbuffers.dev/flexbuffers.html",
    "Official FlexBuffers API in the FlatBuffers JS package.")
add("javascript", "bebop", ["bebop"], "https://github.com/6over3/bebop",
    "Bebop: schema-driven binary format (official bebop.dev).")
add("javascript", "v8-serializer", [], "https://nodejs.org/api/v8.html#serialization-api",
    "Node v8.serialize: V8-only snapshot, not a public interchange spec.")
add("javascript", "devalue", [], "https://github.com/Rich-Harris/devalue",
    "devalue: JS-value stringifier, not a published interchange standard.")
add("javascript", "sia", [], "https://github.com/TimeleapLabs/sia",
    "Sia: project-specific binary tags, no public MUST/MUST NOT spec.")
add("javascript", "bser", [], "https://facebook.github.io/watchman/docs/bser.html",
    "Watchman BSER: Facebook Watchman binary protocol, not a general interchange spec.")

# --- Go ---
add("go", "encoding/json", ["json"], "https://pkg.go.dev/encoding/json",
    "Go stdlib encoding/json: RFC 7159 JSON.")
add("go", "goccy/go-json", ["json"], "https://github.com/goccy/go-json",
    "goccy/go-json: fast encoding/json-compatible JSON library.")
add("go", "jsoniter", ["json"], "https://github.com/json-iterator/go",
    "json-iterator: high-performance JSON for Go.")
add("go", "segmentio/encoding/json", ["json"], "https://github.com/segmentio/encoding",
    "segmentio/encoding/json: drop-in encoding/json replacement.")
add("go", "sonic", ["json"], "https://github.com/bytedance/sonic",
    "Bytedance sonic: JIT/SIMD JSON library for Go.")
add("go", "ugorji/json", ["json"], "https://github.com/ugorji/go",
    "ugorji/go codec JsonHandle: JSON.")
add("go", "goccy/go-yaml", ["yaml"], "https://github.com/goccy/go-yaml",
    "goccy/go-yaml: YAML 1.2 library.")
add("go", "fxamacker/cbor", ["cbor"], "https://github.com/fxamacker/cbor",
    "fxamacker/cbor: CBOR RFC 8949 codec.")
add("go", "ugorji/cbor", ["cbor"], "https://github.com/ugorji/go",
    "ugorji/go codec CborHandle: CBOR.")
add("go", "vmihailenco/msgpack", ["msgpack"], "https://github.com/vmihailenco/msgpack",
    "vmihailenco/msgpack: MessagePack for Go.")
add("go", "shamaton/msgpack", ["msgpack"], "https://github.com/shamaton/msgpack",
    "shamaton/msgpack: MessagePack for Go.")
add("go", "ugorji/msgpack", ["msgpack"], "https://github.com/ugorji/go",
    "ugorji/go codec MsgpackHandle: MessagePack.")
add("go", "protobuf", ["protobuf"], "https://pkg.go.dev/google.golang.org/protobuf",
    "Official Go protobuf API.")
add("go", "hamba/avro", ["avro"], "https://github.com/hamba/avro",
    "hamba/avro: Apache Avro for Go.")
add("go", "linkedin/goavro", ["avro"], "https://github.com/linkedin/goavro",
    "LinkedIn goavro: Apache Avro binary codec.")
add("go", "mongo-bson", ["bson"], "https://pkg.go.dev/go.mongodb.org/mongo-driver/bson",
    "Official MongoDB Go BSON package.")
add("go", "pelletier/go-toml", ["toml"], "https://github.com/pelletier/go-toml",
    "go-toml: TOML parser/encoder (TOML 1.0).")
add("go", "encoding/gob", [], "https://pkg.go.dev/encoding/gob",
    "Go gob: Go-only binary stream, not a public interchange spec.")
add("go", "kelindar/binary", [], "https://github.com/kelindar/binary",
    "kelindar/binary: Go-only compact packer.")

# --- Java ---
add("java", "jackson", ["json"], "https://github.com/FasterXML/jackson-databind",
    "jackson-databind: JSON data-binding (JSON).")
add("java", "jackson-yaml", ["yaml"], "https://github.com/FasterXML/jackson-dataformats-text",
    "jackson-dataformat-yaml: YAML via Jackson.")
add("java", "jackson-cbor", ["cbor"], "https://github.com/FasterXML/jackson-dataformats-binary",
    "jackson-dataformat-cbor: CBOR via Jackson.")
add("java", "jackson-smile", ["smile"], "https://github.com/FasterXML/jackson-dataformats-binary",
    "jackson-dataformat-smile: Smile (binary JSON) via Jackson.")
add("java", "gson", ["json"], "https://github.com/google/gson",
    "Google Gson: Java JSON library.")
add("java", "fastjson2", ["json"], "https://github.com/alibaba/fastjson2",
    "Alibaba fastjson2: JSON library.")
add("java", "dsl-json", ["json"], "https://github.com/ngs-doo/dsl-json",
    "dsl-json: high-performance JSON for Java.")
add("java", "moshi", ["json"], "https://github.com/square/moshi",
    "Square Moshi: JSON library for Android/Java.")
add("java", "jsoniter", ["json"], "https://jsoniter.com/",
    "jsoniter: JSON for Java.")
add("java", "msgpack", ["msgpack"], "https://github.com/msgpack/msgpack-java",
    "Official msgpack-java (Jackson MessagePack mapper in this suite).")
add("java", "protobuf", ["protobuf"], "https://protobuf.dev/",
    "Official protobuf-java runtime.")
add("java", "avro", ["avro"], "https://avro.apache.org/docs/current/api/java/",
    "Official Apache Avro Java API.")
add("java", "bson", ["bson"], "https://www.mongodb.com/docs/languages/java/reactive-streams-driver/current/bson/",
    "MongoDB Java BSON.")
add("java", "ion", ["ion"], "https://amazon-ion.github.io/ion-docs/",
    "Amazon Ion via jackson-dataformat-ion.")
add("java", "flatbuffers", ["flatbuffers"], "https://flatbuffers.dev/",
    "Official FlatBuffers Java runtime.")
add("java", "capnproto", ["capnp"], "https://capnproto.org/",
    "Official Cap'n Proto Java runtime.")
add("java", "java-serialization", [], "https://docs.oracle.com/en/java/javase/21/docs/specs/serialization/",
    "Java Object Serialization: Java-only stream.")
add("java", "kryo", [], "https://github.com/EsotericSoftware/kryo",
    "Kryo: Java binary graph serializer; no public interchange spec.")
add("java", "fory", [], "https://fory.apache.org/",
    "Apache Fory: cross-language but not a cited RFC/IDL in this catalog.")
add("java", "hessian", [], "http://hessian.caucho.com/",
    "Caucho Hessian: RPC binary protocol, not in the Compliance catalog.")
add("java", "protostuff", [], "https://github.com/protostuff/protostuff",
    "protostuff-runtime: schema-from-class binary; not the protobuf wire spec.")

# --- Kotlin ---
add("kotlin", "kotlinx-json", ["json"], "https://github.com/Kotlin/kotlinx.serialization",
    "kotlinx-serialization-json: official Kotlin JSON.")
add("kotlin", "jackson", ["json"], "https://github.com/FasterXML/jackson-module-kotlin",
    "jackson-module-kotlin: JSON.")
add("kotlin", "jackson-cbor", ["cbor"], "https://github.com/FasterXML/jackson-dataformats-binary",
    "jackson-dataformat-cbor + Kotlin module.")
add("kotlin", "gson", ["json"], "https://github.com/google/gson",
    "Google Gson JSON.")
add("kotlin", "moshi-codegen", ["json"], "https://github.com/square/moshi",
    "Moshi KSP generated JSON adapters.")
add("kotlin", "moshi-reflect", ["json"], "https://github.com/square/moshi",
    "Moshi reflection JSON adapters.")
add("kotlin", "kaml", ["yaml"], "https://github.com/charleskorn/kaml",
    "kaml: YAML for kotlinx.serialization.")
add("kotlin", "kotlinx-cbor", ["cbor"], "https://github.com/Kotlin/kotlinx.serialization",
    "kotlinx-serialization-cbor: official Kotlin CBOR.")
add("kotlin", "obor", ["cbor"], "https://github.com/andreypfau/kotlinx-serialization-cbor",
    "obor: kotlinx CBOR alternative.")
add("kotlin", "msgpack", ["msgpack"], "https://github.com/msgpack/msgpack-java",
    "msgpack-java MessagePack mapper.")
add("kotlin", "protobuf", ["protobuf"], "https://protobuf.dev/",
    "protobuf-java from Kotlin.")
add("kotlin", "protobuf-kotlin", ["protobuf"], "https://protobuf.dev/reference/kotlin/api-docs/",
    "Official protobuf-kotlin DSL + wire.")
add("kotlin", "kotlinx-protobuf", ["protobuf"], "https://github.com/Kotlin/kotlinx.serialization",
    "kotlinx-serialization-protobuf.")
add("kotlin", "avro", ["avro"], "https://avro.apache.org/",
    "Apache Avro Java/Kotlin.")
add("kotlin", "avro4k", ["avro"], "https://github.com/avro-kotlin/avro4k",
    "avro4k: Avro for kotlinx.serialization.")
add("kotlin", "kbson", ["bson"], "https://github.com/jershell/kbson",
    "kbson: BSON for kotlinx.serialization.")
add("kotlin", "kotlinx-ion", ["ion"], "https://amazon-ion.github.io/ion-docs/",
    "Amazon Ion via ion-java + kotlinx encoder.")
add("kotlin", "kotlinx-hocon", ["hocon"], "https://github.com/lightbend/config",
    "HOCON via kotlinx-serialization-hocon / Typesafe Config.")
add("kotlin", "tomlkt", ["toml"], "https://github.com/Peanuuutz/tomlkt",
    "tomlkt: TOML for kotlinx.serialization.")
add("kotlin", "flatbuffers", ["flatbuffers"], "https://flatbuffers.dev/",
    "Official FlatBuffers Java runtime from Kotlin.")
add("kotlin", "capnproto", ["capnp"], "https://capnproto.org/",
    "Official Cap'n Proto.")
add("kotlin", "thrift", ["thrift"], "https://thrift.apache.org/",
    "Apache Thrift TCompactProtocol.")
add("kotlin", "kotlinx-properties", [], "https://github.com/Kotlin/kotlinx.serialization",
    "java.util.Properties map, not a catalogued interchange spec.")
add("kotlin", "kryo", [], "https://github.com/EsotericSoftware/kryo",
    "Kryo: Java/Kotlin-native binary.")
add("kotlin", "fory", [], "https://fory.apache.org/",
    "Apache Fory: not a cited RFC/IDL in this catalog.")
add("kotlin", "protostuff", [], "https://github.com/protostuff/protostuff",
    "protostuff-runtime, not protobuf wire.")

# --- C# ---
add("csharp", "System.Text.Json", ["json"], "https://learn.microsoft.com/dotnet/api/system.text.json",
    "Microsoft docs: System.Text.Json JSON serializer.")
add("csharp", "Json.Net", ["json"], "https://www.newtonsoft.com/json/help/html/Introduction.htm",
    "Newtonsoft Json.NET: JSON framework.")
add("csharp", "Json.Net (Helper)", ["json"], "https://www.newtonsoft.com/json/help/html/Introduction.htm",
    "Same Json.NET library, helper call path.")
add("csharp", "Jil", ["json"], "https://github.com/kevin-montrose/Jil",
    "Jil: fast JSON serializer for .NET.")
add("csharp", "SpanJson", ["json"], "https://github.com/Tornhoof/SpanJson",
    "SpanJson: .NET JSON serializer.")
add("csharp", "Utf8Json", ["json"], "https://github.com/neuecc/Utf8Json",
    "Utf8Json: fast C# JSON serializer.")
add("csharp", "NetJSON", ["json"], "https://github.com/rpgmaker/NetJSON",
    "NetJSON: .NET JSON serializer.")
add("csharp", "fastJson", ["json"], "https://github.com/mgholam/fastJSON",
    "fastJSON: small .NET JSON serializer.")
add("csharp", "ServiceStack Json", ["json"], "https://docs.servicestack.net/json-format",
    "ServiceStack.Text JSON format.")
add("csharp", "FsPicklerJson", ["json"], "https://mbraceproject.github.io/FsPickler/",
    "FsPickler JSON pickler.")
add("csharp", "MS DataContract Json", ["json"], "https://learn.microsoft.com/dotnet/api/system.runtime.serialization.json.datacontractjsonserializer",
    "DataContractJsonSerializer: JSON.")
add("csharp", "MS Bond Json", ["json", "bond"], "https://microsoft.github.io/bond/manual/bond_cs.html",
    "Microsoft Bond JSON protocol (Bond + JSON).")
add("csharp", "YamlDotNet", ["yaml"], "https://github.com/aaubry/YamlDotNet",
    "YamlDotNet: YAML 1.1/1.2 for .NET.")
add("csharp", "SharpYaml", ["yaml"], "https://github.com/xoofx/SharpYaml",
    "SharpYaml: YAML parser/emitter for .NET.")
add("csharp", "MessagePack-CSharp", ["msgpack"], "https://github.com/MessagePack-CSharp/MessagePack-CSharp",
    "Official MessagePack for C#.")
add("csharp", "Google.Protobuf", ["protobuf"], "https://protobuf.dev/",
    "Official Google.Protobuf C# runtime.")
add("csharp", "ProtoBuf", ["protobuf"], "https://github.com/protobuf-net/protobuf-net",
    "protobuf-net: Protocol Buffers for .NET.")
add("csharp", "LightProto", ["protobuf"], "https://github.com/dameng324/LightProto",
    "LightProto: source-generated protobuf-net-style API.")
add("csharp", "Apache.Avro", ["avro"], "https://avro.apache.org/docs/current/api/csharp/html/",
    "Official Apache.Avro C#.")
add("csharp", "FlatSharp", ["flatbuffers"], "https://github.com/jamescourtney/FlatSharp",
    "FlatSharp: FlatBuffers implementation for .NET.")
add("csharp", "MS Bond Compact", ["bond"], "https://microsoft.github.io/bond/manual/bond_cs.html",
    "Microsoft Bond Compact Binary protocol.")
add("csharp", "MS Bond Fast", ["bond"], "https://microsoft.github.io/bond/manual/bond_cs.html",
    "Microsoft Bond Fast Binary protocol.")
add("csharp", "MS XmlSerializer", [], "https://learn.microsoft.com/dotnet/api/system.xml.serialization.xmlserializer",
    "XML is out of Compliance catalog scope.")
add("csharp", "MS DataContract", [], "https://learn.microsoft.com/dotnet/api/system.runtime.serialization.datacontractserializer",
    "XML DataContract; XML is out of catalog scope.")
add("csharp", "YAXLib", [], "https://github.com/sinairv/YAXLib",
    "YAXLib XML; XML is out of catalog scope.")
add("csharp", "ExtendedXmlSerializer", [], "https://github.com/wojtpl2/ExtendedXmlSerializer",
    "XML envelope of JSON; XML is out of catalog scope.")
add("csharp", "CsvHelper", [], "https://joshclose.github.io/CsvHelper/",
    "CSV; not a catalogued Compliance standard.")
add("csharp", "MS Binary", [], "https://learn.microsoft.com/dotnet/standard/serialization/binaryformatter-security-guide",
    "BinaryFormatter: .NET-only, obsolete, not a public interchange spec.")
add("csharp", "BinaryPack", [], "https://github.com/Sergio0694/BinaryPack",
    "BinaryPack: .NET-only binary.")
add("csharp", "Ceras", [], "https://github.com/rikimaru0345/Ceras",
    "Ceras: .NET binary serializer.")
add("csharp", "FsPickler", [], "https://mbraceproject.github.io/FsPickler/",
    "FsPickler binary: .NET pickler.")
add("csharp", "GroBuf", [], "https://github.com/skbkontur/GroBuf",
    "GroBuf: .NET binary serializer.")
add("csharp", "Hyperion", [], "https://github.com/akkadotnet/Hyperion",
    "Hyperion: Akka.NET binary serializer.")
add("csharp", "MemoryPack", [], "https://github.com/Cysharp/MemoryPack",
    "MemoryPack: .NET binary; no public RFC/IDL in this catalog.")
add("csharp", "Migrant", [], "https://github.com/antmicro/Migrant",
    "Migrant: .NET binary (suite row is a JSON envelope).")
add("csharp", "NetSerializer", [], "https://github.com/tomba/netserializer",
    "NetSerializer: .NET binary.")
add("csharp", "ServiceStack", [], "https://docs.servicestack.net/text-serializers",
    "ServiceStack JSV/type serializer, not a catalogued public spec.")
add("csharp", "SharpSerializer", [], "https://github.com/polenter/SharpSerializer",
    "SharpSerializer: .NET binary/XML.")
add("csharp", "ZeroFormatter", [], "https://github.com/neuecc/ZeroFormatter",
    "ZeroFormatter: .NET binary.")

# --- Rust ---
add("rust", "serde_json", ["json"], "https://docs.rs/serde_json",
    "serde_json: JSON for Serde.")
add("rust", "simd-json", ["json"], "https://docs.rs/simd-json",
    "simd-json: SIMD JSON parser.")
add("rust", "sonic-rs", ["json"], "https://docs.rs/sonic-rs",
    "sonic-rs: SIMD JSON for Rust.")
add("rust", "serde_yaml", ["yaml"], "https://docs.rs/serde_yaml",
    "serde_yaml: YAML via Serde.")
add("rust", "ciborium", ["cbor"], "https://docs.rs/ciborium",
    "ciborium: CBOR for Serde.")
add("rust", "minicbor", ["cbor"], "https://docs.rs/minicbor",
    "minicbor: no_std CBOR codec.")
add("rust", "rmp-serde", ["msgpack"], "https://docs.rs/rmp-serde",
    "rmp-serde: MessagePack for Serde.")
add("rust", "prost", ["protobuf"], "https://docs.rs/prost",
    "prost: Protocol Buffers implementation for Rust.")
add("rust", "serde_avro_fast", ["avro"], "https://docs.rs/serde_avro_fast",
    "serde_avro_fast: Apache Avro via Serde.")
add("rust", "bson", ["bson"], "https://docs.rs/bson",
    "Official MongoDB Rust BSON crate.")
add("rust", "flexbuffers", ["flatbuffers"], "https://docs.rs/flexbuffers",
    "flexbuffers crate: FlatBuffers FlexBuffers.")
add("rust", "bincode", [], "https://docs.rs/bincode",
    "bincode: Rust/Serde binary, not a public interchange spec.")
add("rust", "bitcode", [], "https://docs.rs/bitcode",
    "bitcode: Rust bit-packed binary.")
add("rust", "nanoserde", [], "https://docs.rs/nanoserde",
    "nanoserde SerBin: Rust-only binary.")
add("rust", "postcard", [], "https://docs.rs/postcard",
    "postcard: COBS/no_std Rust binary, not in this catalog.")
add("rust", "speedy", [], "https://docs.rs/speedy",
    "speedy: Rust binary framework.")
add("rust", "rkyv", [], "https://rkyv.org/",
    "rkyv: Rust zero-copy archive, not a public RFC/IDL here.")

# --- C++ ---
add("cpp", "nlohmann_json", ["json"], "https://json.nlohmann.me/",
    "nlohmann::json dump/parse: JSON (RFC 8259). Other nlohmann_* rows cover sibling formats.")
add("cpp", "nlohmann_cbor", ["cbor"], "https://json.nlohmann.me/features/binary_formats/cbor/",
    "Official nlohmann docs: to_cbor / from_cbor (RFC 8949).")
add("cpp", "nlohmann_msgpack", ["msgpack"], "https://json.nlohmann.me/features/binary_formats/messagepack/",
    "Official nlohmann docs: to_msgpack / from_msgpack.")
add("cpp", "nlohmann_bson", ["bson"], "https://json.nlohmann.me/features/binary_formats/bson/",
    "Official nlohmann docs: to_bson / from_bson.")
add("cpp", "nlohmann_ubjson", ["ubjson"], "https://json.nlohmann.me/features/binary_formats/ubjson/",
    "Official nlohmann docs: to_ubjson / from_ubjson.")
add("cpp", "rapidjson", ["json"], "https://rapidjson.org/",
    "Tencent RapidJSON: JSON parser/generator.")
add("cpp", "simdjson", ["json"], "https://simdjson.org/",
    "simdjson: SIMD JSON parser.")
add("cpp", "yyjson", ["json"], "https://github.com/ibireme/yyjson",
    "yyjson: high-performance JSON library.")
add("cpp", "arduinojson", ["json"], "https://arduinojson.org/",
    "ArduinoJson: JSON for C++.")
add("cpp", "glaze", ["json"], "https://github.com/stephenberry/glaze",
    "glaze: C++ JSON (glz::write_json / read_json).")
add("cpp", "yaml-cpp", ["yaml"], "https://github.com/jbeder/yaml-cpp",
    "yaml-cpp: YAML parser/emitter.")
add("cpp", "msgpack", ["msgpack"], "https://github.com/msgpack/msgpack-c",
    "Official msgpack-c C++ API.")
add("cpp", "jsoncons_msgpack", ["msgpack"], "https://github.com/danielaparker/jsoncons",
    "jsoncons msgpack::encode/decode.")
add("cpp", "jsoncons_cbor", ["cbor"], "https://github.com/danielaparker/jsoncons",
    "jsoncons cbor::encode/decode.")
add("cpp", "jsoncons_bson", ["bson"], "https://github.com/danielaparker/jsoncons",
    "jsoncons bson::encode/decode.")
add("cpp", "protobuf", ["protobuf"], "https://protobuf.dev/",
    "Official libprotobuf C++.")
add("cpp", "protobuf-wire", ["protobuf"], "https://protobuf.dev/programming-guides/encoding/",
    "In-tree proto3 encoding-guide reader.")
add("cpp", "avro", ["avro"], "https://avro.apache.org/",
    "Apache Avro binary encoding.")
add("cpp", "avro_c", ["avro"], "https://avro.apache.org/docs/1.11.3/api/c/",
    "Apache Avro C library from C++.")
add("cpp", "flatbuffers", ["flatbuffers"], "https://flatbuffers.dev/",
    "Official Google FlatBuffers C++.")
add("cpp", "flexbuffers", ["flatbuffers"], "https://flatbuffers.dev/flexbuffers.html",
    "Official FlexBuffers C++ API.")
add("cpp", "capnproto", ["capnp"], "https://capnproto.org/",
    "Official Cap'n Proto C++.")
add("cpp", "thrift", ["thrift"], "https://thrift.apache.org/",
    "Apache Thrift TBinaryProtocol.")
add("cpp", "bitsery", [], "https://github.com/fraillt/bitsery",
    "bitsery: C++ binary schema serializer, not a catalogued public spec.")
add("cpp", "cereal", [], "https://uscilab.github.io/cereal/",
    "cereal: C++ archive, C++-native.")
add("cpp", "cista", [], "https://github.com/felixguendling/cista",
    "Cista: C++ offset graphs.")
add("cpp", "custom_binary", [], "https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/docs/cpp/index.md",
    "Harness length-prefixed baseline.")
add("cpp", "yas", [], "https://github.com/niXman/yas",
    "YAS: C++ binary archive.")
add("cpp", "zpp_bits", [], "https://github.com/eyalz800/zpp_bits",
    "zpp_bits: C++ compile-time binary.")
add("cpp", "boost_serialization", [], "https://www.boost.org/doc/libs/release/libs/serialization/",
    "Boost.Serialization: C++-native archives.")

# --- Swift ---
add("swift", "Foundation.JSONEncoder", ["json"], "https://developer.apple.com/documentation/foundation/jsonencoder",
    "Foundation JSONEncoder/JSONDecoder: JSON.")
add("swift", "IkigaJSON", ["json"], "https://github.com/orlandos-nl/IkigaJSON",
    "IkigaJSON: Swift JSON encoder/decoder.")
add("swift", "Yams", ["yaml"], "https://github.com/jpsim/Yams",
    "Yams: libyaml wrapper for Swift (YAML).")
add("swift", "SwiftCbor", ["cbor"], "https://github.com/valpackett/swift-cbor",
    "swift-cbor: Codable CBOR.")
add("swift", "SwiftMsgpack", ["msgpack"], "https://github.com/nnabeyang/swift-msgpack",
    "swift-msgpack: Codable MessagePack.")
add("swift", "SwiftProtobuf", ["protobuf"], "https://github.com/apple/swift-protobuf",
    "Official Apple SwiftProtobuf.")
add("swift", "protobuf-wire", ["protobuf"], "https://protobuf.dev/programming-guides/encoding/",
    "In-tree proto3 encoding-guide reader used by the Swift compliance runner.")
add("swift", "FlatBuffers", ["flatbuffers"], "https://flatbuffers.dev/",
    "Official FlatBuffers Swift runtime.")
add("swift", "SwiftAvroCore", ["avro"], "https://github.com/barrettekra/SwiftAvroCore",
    "SwiftAvroCore: Apache Avro.")
add("swift", "SwiftBSON", ["bson"], "https://github.com/mongodb/swift-bson",
    "Official MongoDB swift-bson.")
add("swift", "CapnProto", ["capnp"], "https://capnproto.org/",
    "Official Cap'n Proto C++ runtime via C ABI.")
add("swift", "TOML", ["toml"], "https://github.com/mattt/swift-toml",
    "mattt/swift-toml: TOML.")
add("swift", "Foundation.PropertyListEncoder", ["plist"], "https://developer.apple.com/documentation/foundation/propertylistencoder",
    "Foundation PropertyListEncoder: Apple property lists.")
add("swift", "XMLCoder", [], "https://github.com/CoreOffice/XMLCoder",
    "XMLCoder: XML; XML is out of catalog scope.")
add("swift", "BinaryCodable", [], "https://github.com/jverkoey/BinaryCodable",
    "BinaryCodable: Swift-only binary Codable.")

# --- PHP ---
add("php", "json", ["json"], "https://www.php.net/manual/en/book.json.php",
    "PHP json_encode/json_decode (JSON).")
add("php", "symfony-json", ["json"], "https://symfony.com/doc/current/components/serializer.html",
    "Symfony Serializer JSON encoder.")
add("php", "jms-json", ["json"], "https://jmsyst.com/libs/serializer",
    "JMS Serializer JSON.")
add("php", "yaml", ["yaml"], "https://symfony.com/doc/current/components/yaml.html",
    "Symfony YAML component.")
add("php", "rybakit-msgpack", ["msgpack"], "https://github.com/rybakit/msgpack.php",
    "rybakit/msgpack: MessagePack for PHP.")
add("php", "protobuf", ["protobuf"], "https://protobuf.dev/",
    "Official google/protobuf PHP runtime.")
add("php", "avro", ["avro"], "https://avro.apache.org/",
    "flix-tech/avro-php: Apache Avro binary.")
add("php", "cbor", ["cbor"], "https://github.com/Spomky-Labs/cbor-php",
    "spomky-labs/cbor-php: RFC 8949.")
add("php", "serialize", [], "https://www.php.net/manual/en/function.serialize.php",
    "PHP serialize(): PHP-only format.")
add("php", "symfony-xml", [], "https://symfony.com/doc/current/components/serializer.html",
    "Symfony XML encoder; XML is out of catalog scope.")

# --- Zig ---
add("zig", "std.json", ["json"], "https://ziglang.org/documentation/master/std/#std.json",
    "Zig std.json: JSON stringify/parse.")
add("zig", "std.json.scanner", ["json"], "https://ziglang.org/documentation/master/std/#std.json.Scanner",
    "Zig std.json.Scanner: JSON tokenizer path.")
add("zig", "serde.json", ["json"], "https://github.com/getty-zig/getty",
    "serde.zig JSON path.")
add("zig", "serde.yaml", ["yaml"], "https://github.com/getty-zig/getty",
    "serde.zig YAML path.")
add("zig", "serde.toml", ["toml"], "https://github.com/getty-zig/getty",
    "serde.zig TOML path.")
add("zig", "serde.msgpack", ["msgpack"], "https://github.com/getty-zig/getty",
    "serde.zig MessagePack path.")
add("zig", "zig-msgpack", ["msgpack"], "https://github.com/zigcc/zig-msgpack",
    "zigcc/zig-msgpack: MessagePack.")
add("zig", "msgpack.zig", ["msgpack"], "https://github.com/lalinsky/msgpack.zig",
    "lalinsky/msgpack.zig: MessagePack.")
add("zig", "zbor", ["cbor"], "https://github.com/r4gus/zbor",
    "zbor: native Zig CBOR.")
add("zig", "protobuf", ["protobuf"], "https://github.com/Arwalk/zig-protobuf",
    "Arwalk/zig-protobuf from the shared .proto.")
add("zig", "protobuf-wire", ["protobuf"], "https://protobuf.dev/programming-guides/encoding/",
    "In-tree proto3 encoding-guide reader.")
add("zig", "flatbuffers", ["flatbuffers"], "https://flatbuffers.dev/",
    "nDimensional/zig-flatbuffers from the shared .fbs.")
add("zig", "capnproto", ["capnp"], "https://capnproto.org/",
    "Official Cap'n Proto C++ runtime.")
add("zig", "std.zon", ["zon"], "https://ziglang.org/documentation/master/std/#std.zon",
    "Zig std.zon: Zig Object Notation.")
add("zig", "serde.zon", ["zon"], "https://github.com/getty-zig/getty",
    "serde.zig ZON path.")
add("zig", "serde.xml", [], "https://github.com/getty-zig/getty",
    "serde.zig XML; XML is out of catalog scope.")
add("zig", "comptime-bin", [], "https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/docs/zig/index.md",
    "In-tree comptime length-prefixed binary.")
add("zig", "s2s", [], "https://github.com/ziglibs/s2s",
    "s2s: Zig struct-to-stream, Zig-only.")

# --- Mojo ---
add("mojo", "EmberJson", ["json"], "https://github.com/MojoSerial/EmberJson",
    "EmberJson: Mojo JSON serialize/deserialize.")
add("mojo", "ehsanmok-json", ["json"], "https://github.com/ehsanmok/json",
    "ehsanmok/json: Mojo JSON parser.")
add("mojo", "mojo-json", ["json"], "https://github.com/leo-gan/gld-json",
    "gld-json: JSON WireWriter/Reader.")
add("mojo", "mojo-cbor", ["cbor"], "https://github.com/leo-gan/gld-cbor",
    "gld-cbor: CBOR datum encode/decode.")
add("mojo", "mojo-protobuf", ["protobuf"], "https://github.com/leo-gan/gld-protobuf",
    "gld-protobuf from the suite .proto.")
add("mojo", "mojo-avro", ["avro"], "https://github.com/leo-gan/gld-avro",
    "gld-avro: Avro datum encode/decode.")
add("mojo", "mojo-toml", ["toml"], "https://github.com/DataBooth/mojo-toml",
    "DataBooth/mojo-toml: TOML.")
add("mojo", "mojo-msgpack", ["msgpack"], "https://github.com/leo-gan/gld-messagepack",
    "gld-messagepack: MessagePack wire.")
add("mojo", "gld-yaml", ["yaml"], "https://github.com/leo-gan/gld-yaml",
    "gld-yaml: YAML value encode/decode.")


def main() -> int:
    import json

    seen: set[tuple[str, str]] = set()
    for lang, name, _fmts, docs, _ev in CATALOG:
        key = (lang, name)
        if key in seen:
            raise SystemExit(f"duplicate catalog entry: {lang}/{name}")
        seen.add(key)
        if not docs.startswith("http"):
            raise SystemExit(f"docs must be an http(s) URL: {lang}/{name}")

    repo = Path(__file__).resolve().parents[2]
    by_lang: dict[str, dict[str, list[str]]] = {}
    for lang, name, formats, _docs, _ev in CATALOG:
        by_lang.setdefault(lang, {})[name] = list(formats)
    json_path = repo / "compliance" / "serializer-standards.json"
    json_path.write_text(
        json.dumps({"schema": "gld.compliance.serializer-standards/1", "languages": by_lang}, indent=2)
        + "\n",
        encoding="utf-8",
    )
    print(f"Wrote {json_path.relative_to(repo)}")

    out = repo / "dashboard" / "compliance-catalog.js"
    lines = [
        "/**",
        " * Documented Standard membership for each registered serializer.",
        " *",
        " * Source of truth is official library / language documentation for the",
        " * API this suite times — not the spelling of the log name. formats is",
        " * empty when that API is not a public interchange spec in the",
        " * Compliance catalog (pickle, gob, Kryo, XML, suite-private binaries).",
        " *",
        " * Generated by dashboard/scripts/write-compliance-catalog.py.",
        " * Edit that script and re-run it; do not hand-edit this file.",
        " */",
        "",
        "/** @typedef {{ language: string, name: string, formats: string[], docs: string, evidence: string }} CatalogEntry */",
        "",
        "/** @type {CatalogEntry[]} */",
        "export const CATALOG = [",
    ]
    for lang, name, formats, docs, evidence in CATALOG:
        fmt_js = "[" + ", ".join(json_str(f) for f in formats) + "]"
        lines.append(
            "  {"
            f" language: {json_str(lang)},"
            f" name: {json_str(name)},"
            f" formats: {fmt_js},"
            f" docs: {json_str(docs)},"
            f" evidence: {json_str(evidence)}"
            " },"
        )
    lines.append("];")
    lines.append("")
    lines.append("/** @type {Map<string, CatalogEntry>} */")
    lines.append("export const CATALOG_BY_KEY = new Map(")
    lines.append("  CATALOG.map((e) => [`${e.language}\\0${e.name}`, e]),")
    lines.append(");")
    lines.append("")
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {out.relative_to(out.parents[1])} ({len(CATALOG)} entries)")
    return 0


def json_str(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


if __name__ == "__main__":
    raise SystemExit(main())
