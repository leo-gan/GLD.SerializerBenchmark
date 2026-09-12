#!/usr/bin/env python3
"""Expand Protobuf / Avro / BSON / FlexBuffers to official-suite scale.

Avro: official BINARY_ENCODINGS + SCHEMAS_TO_VALIDATE from apache/avro
(Apache-2.0). Encoded here with fastavro so the catalog stays static.

Protobuf / FlexBuffers: encodings generated from the public rules
(protobuf.dev, flexbuffers.html). Google conformance/ is a runner
protocol, not a static file; we do not vendor it.

BSON: full type matrix recreated from bsonspec.org. MongoDB bson-corpus
is CC BY-NC-SA and is not copied (including the copy inside libbson).

  python3 compliance/scripts/expand_schema_formats.py
"""

from __future__ import annotations

import io
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
VENDOR = ROOT / "vendor"
AVRO_SRC = Path("/tmp/compliance-suites/avro")
FB_SRC = Path("/tmp/compliance-suites/flatbuffers")


def dump(rel: str, doc: dict) -> None:
    path = DATA / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(doc, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"wrote {path.relative_to(ROOT)} ({len(doc['cases'])} cases)")


def C(**kwargs) -> dict:
    return kwargs


def _merge(official: list[dict], extras: list[dict]) -> list[dict]:
    seen = {c["id"] for c in official}
    out = list(official)
    for item in extras:
        if item["id"] not in seen:
            out.append(item)
            seen.add(item["id"])
    return out


def _load_existing(rel: str) -> list[dict]:
    path = DATA / rel
    if not path.is_file():
        return []
    return list(json.loads(path.read_text(encoding="utf-8")).get("cases") or [])


def _avro_hex(schema: object, datum: object) -> str:
    import fastavro

    buf = io.BytesIO()
    fastavro.schemaless_writer(buf, schema, datum)
    return buf.getvalue().hex()


def write_avro() -> None:
    spec = "https://avro.apache.org/docs/1.11.1/specification/"
    cases: list[dict] = []

    # Official apache/avro lang/py/avro/test/test_io.py BINARY_ENCODINGS.
    for value, hx in (
        (0, "00"),
        (-1, "01"),
        (1, "02"),
        (-2, "03"),
        (2, "04"),
        (-64, "7f"),
        (64, "8001"),
        (8192, "808001"),
        (-8193, "818001"),
    ):
        cases.append(
            C(
                id=f"avro-io-int-{str(value).replace('-', 'm')}",
                title=f"Official zigzag int {value}",
                section="4.2",
                section_title="int",
                section_url=f"{spec}#schema-int",
                paragraph="An int is written as a variable-length zigzag long. Vendored from apache/avro test_io.BINARY_ENCODINGS (Apache-2.0).",
                requirement="MUST",
                expect="accept",
                input=hx,
                input_encoding="hex",
                decoded=value,
                schema="int",
                notes="Vendored from apache/avro lang/py/avro/test/test_io.py BINARY_ENCODINGS.",
            )
        )

    official_datums: list[tuple[str, object, object]] = [
        ("null", "null", None),
        ("boolean-true", "boolean", True),
        ("boolean-false", "boolean", False),
        ("string-kelp", "string", "kelp"),
        ("bytes-kelp", "bytes", b"kelp"),
        ("int-1234", "int", 1234),
        ("long-1234", "long", 1234),
        ("float-1", "float", 1.0),
        ("double-1", "double", 1.0),
        ("enum-b", {"type": "enum", "name": "Harbor", "symbols": ["A", "B"]}, "B"),
        ("array-long", {"type": "array", "items": "long"}, [1, 3, 2]),
        ("map-long", {"type": "map", "values": "long"}, {"harbor": 1, "kelp": 3}),
        ("union-null", ["string", "null", "long"], None),
        ("union-string", ["null", "string"], "kelp"),
        (
            "record-f",
            {"type": "record", "name": "Berth", "fields": [{"name": "f", "type": "long"}]},
            {"f": 5},
        ),
        ("fixed-1", {"type": "fixed", "name": "Tide", "size": 1}, b"B"),
    ]
    for slug, schema, datum in official_datums:
        hx = _avro_hex(schema, datum)
        decoded: object
        if isinstance(datum, bytes):
            decoded = {"$hex": datum.hex()}
        else:
            decoded = datum
        cases.append(
            C(
                id=f"avro-io-{slug}",
                title=f"Official datum {slug}",
                section="4",
                section_title="binary encoding",
                section_url=f"{spec}#encodings",
                paragraph="Schemaless binary encoding of one Avro value. Datum list follows apache/avro test_io.SCHEMAS_TO_VALIDATE (Apache-2.0); names were kept only where they are type names.",
                requirement="MUST",
                expect="accept",
                input=hx,
                input_encoding="hex",
                decoded=decoded,
                schema=schema,
                notes="Encoded from apache/avro official test datums (Apache-2.0).",
            )
        )

    rejects = [
        C(
            id="avro-trunc-int",
            title="Truncated zigzag int",
            section="4.2",
            section_title="int",
            section_url=f"{spec}#schema-int",
            paragraph="A continuation bit of 1 requires another byte.",
            requirement="MUST NOT",
            expect="reject",
            input="80",
            input_encoding="hex",
            schema="int",
        ),
        C(
            id="avro-trunc-string",
            title="String shorter than declared length",
            section="4.3",
            section_title="string",
            section_url=f"{spec}#schema-string",
            paragraph="A string is a long length plus that many UTF-8 bytes.",
            requirement="MUST NOT",
            expect="reject",
            input="086b65",
            input_encoding="hex",
            schema="string",
        ),
        C(
            id="avro-union-bad-index",
            title="Union branch index out of range",
            section="4.4",
            section_title="union",
            section_url=f"{spec}#unions",
            paragraph="The branch index must refer to an existing union arm.",
            requirement="MUST NOT",
            expect="reject",
            input="04",
            input_encoding="hex",
            schema=["null", "string"],
        ),
        C(
            id="avro-enum-bad",
            title="Enum index out of range",
            section="4.3",
            section_title="enum",
            section_url=f"{spec}#schema-enum",
            paragraph="An enum is a zigzag int that must be a valid symbol index.",
            requirement="MUST NOT",
            expect="reject",
            input="04",
            input_encoding="hex",
            schema={"type": "enum", "name": "Harbor", "symbols": ["A", "B"]},
        ),
        C(
            id="avro-fixed-short",
            title="Fixed value shorter than size",
            section="4.3",
            section_title="fixed",
            section_url=f"{spec}#schema-fixed",
            paragraph="A fixed value is exactly size bytes.",
            requirement="MUST NOT",
            expect="reject",
            input="42",
            input_encoding="hex",
            schema={"type": "fixed", "name": "Tide", "size": 4},
        ),
        C(
            id="avro-array-trunc",
            title="Array block truncated",
            section="4.4",
            section_title="array",
            section_url=f"{spec}#schema-array",
            paragraph="An array is a sequence of blocks ended by a zero count.",
            requirement="MUST NOT",
            expect="reject",
            input="02",
            input_encoding="hex",
            schema={"type": "array", "items": "long"},
        ),
    ]
    extras = [
        c
        for c in _load_existing("avro/binary-1.11.json")
        if not str(c["id"]).startswith("avro-io-")
    ]
    all_cases = _merge(cases + rejects, extras)
    for rel, version, url, note in (
        (
            "avro/binary-1.8.json",
            "1.8",
            "https://avro.apache.org/docs/1.8.2/spec.html",
            "Official encodings that exist since 1.8, plus rejects.",
        ),
        (
            "avro/binary-1.11.json",
            "1.11",
            spec,
            "Official apache/avro test_io encodings (Apache-2.0) plus original extras.",
        ),
        (
            "avro/binary-1.12.json",
            "1.12",
            "https://avro.apache.org/docs/1.12.0/specification/",
            "Same binary encoding as 1.11 for these types.",
        ),
    ):
        keep = all_cases
        if version == "1.8":
            keep = [c for c in all_cases if c["id"] not in {"avro-union-string", "avro-union-null", "avro-io-union-null", "avro-io-union-string", "avro-union-bad-index"}]
        dump(
            rel,
            {
                "format": "avro",
                "standard": f"Apache Avro {version} binary",
                "version": version,
                "standard_url": url,
                "provenance": "apache/avro+original-work",
                "notes": note,
                "cases": keep,
            },
        )


def write_protobuf() -> None:
    from google.protobuf import descriptor_pb2, descriptor_pool, message_factory
    from google.protobuf.json_format import MessageToJson

    wire = "https://protobuf.dev/programming-guides/encoding/"
    pjson = "https://protobuf.dev/programming-guides/json/"

    file_proto = descriptor_pb2.FileDescriptorProto()
    file_proto.name = "compliance_doc.proto"
    file_proto.package = "cmp"
    file_proto.syntax = "proto3"
    msg = file_proto.message_type.add()
    msg.name = "Doc"
    for name, number, typ, repeated in (
        ("n", 1, 5, False),
        ("s", 2, 9, False),
        ("ok", 3, 8, False),
        ("tags", 4, 5, True),
    ):
        field = msg.field.add()
        field.name = name
        field.number = number
        field.type = typ
        field.label = 3 if repeated else 1
    pool = descriptor_pool.DescriptorPool()
    pool.Add(file_proto)
    cls = message_factory.GetMessageClass(pool.FindMessageTypeByName("cmp.Doc"))

    def hx(**fields) -> str:
        m = cls()
        for k, v in fields.items():
            if k == "tags":
                m.tags.extend(v)
            else:
                setattr(m, k, v)
        return m.SerializeToString().hex()

    cases = [
        C(id="pb-empty", title="Empty proto3 message is valid", section="1", section_title="A Message", section_url=wire, paragraph="A message is a series of key-value records. Zero records is a valid message.", requirement="MUST", expect="accept", input="", input_encoding="hex", decoded={"n": 0, "s": "", "ok": False, "tags": []}),
        C(id="pb-varint-0", title="Varint field 1 = 0 is omitted in proto3", section="2", section_title="Base 128 Varints", section_url=f"{wire}#varints", paragraph="Default 0 is not written. An explicit 0 is still a valid varint record.", requirement="MUST", expect="accept", input=hx(n=0), input_encoding="hex", decoded={"n": 0, "s": "", "ok": False, "tags": []}),
        C(id="pb-varint-1", title="Varint field 1 = 1", section="2", section_title="Base 128 Varints", section_url=f"{wire}#varints", paragraph="Values below 128 fit in one data byte after the key.", requirement="MUST", expect="accept", input=hx(n=1), input_encoding="hex", decoded={"n": 1, "s": "", "ok": False, "tags": []}),
        C(id="pb-varint-7", title="Varint field 1 = 7", section="2", section_title="Base 128 Varints", section_url=f"{wire}#varints", paragraph="Each byte of a varint uses its lower 7 bits for data.", requirement="MUST", expect="accept", input=hx(n=7), input_encoding="hex", decoded={"n": 7, "s": "", "ok": False, "tags": []}),
        C(id="pb-varint-127", title="Varint field 1 = 127", section="2", section_title="Base 128 Varints", section_url=f"{wire}#varints", paragraph="127 is the largest one-byte varint payload.", requirement="MUST", expect="accept", input=hx(n=127), input_encoding="hex", decoded={"n": 127, "s": "", "ok": False, "tags": []}),
        C(id="pb-varint-128", title="Varint field 1 = 128", section="2", section_title="Base 128 Varints", section_url=f"{wire}#varints", paragraph="128 needs a continuation byte.", requirement="MUST", expect="accept", input=hx(n=128), input_encoding="hex", decoded={"n": 128, "s": "", "ok": False, "tags": []}),
        C(id="pb-varint-300", title="Varint field 1 = 300", section="2", section_title="Base 128 Varints", section_url=f"{wire}#varints", paragraph="300 is 0x12c and takes two varint bytes.", requirement="MUST", expect="accept", input=hx(n=300), input_encoding="hex", decoded={"n": 300, "s": "", "ok": False, "tags": []}),
        C(id="pb-varint-16384", title="Varint field 1 = 16384", section="2", section_title="Base 128 Varints", section_url=f"{wire}#varints", paragraph="16384 takes three varint payload bytes.", requirement="MUST", expect="accept", input=hx(n=16384), input_encoding="hex", decoded={"n": 16384, "s": "", "ok": False, "tags": []}),
        C(id="pb-string-empty", title="Empty string field 2", section="4", section_title="Length-Delimited", section_url=f"{wire}#length-types", paragraph="A length-delimited field may have length 0.", requirement="MUST", expect="accept", input=hx(s=""), input_encoding="hex", decoded={"n": 0, "s": "", "ok": False, "tags": []}),
        C(id="pb-string-kelp", title="Length-delimited field 2 = kelp", section="4", section_title="Length-Delimited", section_url=f"{wire}#length-types", paragraph="Wire type 2 is a varint length followed by that many payload bytes.", requirement="MUST", expect="accept", input=hx(s="kelp"), input_encoding="hex", decoded={"n": 0, "s": "kelp", "ok": False, "tags": []}),
        C(id="pb-string-harbor", title="Length-delimited field 2 = harbor", section="4", section_title="Length-Delimited", section_url=f"{wire}#length-types", paragraph="UTF-8 payload of length 6.", requirement="MUST", expect="accept", input=hx(s="harbor"), input_encoding="hex", decoded={"n": 0, "s": "harbor", "ok": False, "tags": []}),
        C(id="pb-bool-true", title="Bool field 3 = true", section="3", section_title="Message Structure", section_url=f"{wire}#structure", paragraph="A bool is a varint 0 or 1.", requirement="MUST", expect="accept", input=hx(ok=True), input_encoding="hex", decoded={"n": 0, "s": "", "ok": True, "tags": []}),
        C(id="pb-bool-false", title="Bool field 3 = false is default", section="3", section_title="Message Structure", section_url=f"{wire}#structure", paragraph="proto3 omits default false. An explicit 0 is still valid.", requirement="MUST", expect="accept", input=hx(ok=False), input_encoding="hex", decoded={"n": 0, "s": "", "ok": False, "tags": []}),
        C(id="pb-multi", title="Several fields in one message", section="3", section_title="Message Structure", section_url=f"{wire}#structure", paragraph="A message is the concatenation of records. Order is not significant.", requirement="MUST", expect="accept", input=hx(n=7, s="kelp", ok=True), input_encoding="hex", decoded={"n": 7, "s": "kelp", "ok": True, "tags": []}),
        C(id="pb-unknown-field", title="Unknown field number is skipped", section="3", section_title="Message Structure", section_url=f"{wire}#structure", paragraph="A decoder must skip a well-formed record whose field number it does not know.", requirement="MUST", expect="accept", input="7807", input_encoding="hex", decoded={"n": 0, "s": "", "ok": False, "tags": []}),
        C(id="pb-truncated-varint", title="Truncated varint is not well-formed", section="2", section_title="Base 128 Varints", section_url=f"{wire}#varints", paragraph="A continuation bit of 1 requires another byte.", requirement="MUST NOT", expect="reject", input="08ac", input_encoding="hex"),
        C(id="pb-truncated-string", title="Length-delimited payload shorter than declared", section="4", section_title="Length-Delimited", section_url=f"{wire}#length-types", paragraph="The declared length must be present in the remaining bytes.", requirement="MUST NOT", expect="reject", input="12046b65", input_encoding="hex"),
        C(id="pb-bad-wire-type", title="Wire type 7 is reserved / invalid", section="3", section_title="Message Structure", section_url=f"{wire}#structure", paragraph="The three-bit wire type 7 is not a defined encoding.", requirement="MUST NOT", expect="reject", input="0f", input_encoding="hex"),
        C(id="pb-truncated-key", title="Lone continuation in the key varint", section="3", section_title="Message Structure", section_url=f"{wire}#structure", paragraph="The field key is itself a varint and must be complete.", requirement="MUST NOT", expect="reject", input="80", input_encoding="hex"),
        C(id="pb-truncated-fixed64", title="Fixed64 record shorter than 8 bytes", section="3", section_title="Message Structure", section_url=f"{wire}#structure", paragraph="Wire type 1 is eight little-endian bytes.", requirement="MUST NOT", expect="reject", input="09aabbcc", input_encoding="hex"),
        C(id="pb-truncated-fixed32", title="Fixed32 record shorter than 4 bytes", section="3", section_title="Message Structure", section_url=f"{wire}#structure", paragraph="Wire type 5 is four little-endian bytes.", requirement="MUST NOT", expect="reject", input="0d0011", input_encoding="hex"),
    ]
    packed = [
        C(id="pb3-packed-tags", title="proto3 packed repeated int32 field 4", section="4.2", section_title="Packed Repeated Fields", section_url=f"{wire}#packed", paragraph="In proto3, scalar repeated fields use packed encoding: one length-delimited record of concatenated varints.", requirement="MUST", expect="accept", input=hx(tags=[1, 2, 3]), input_encoding="hex", decoded={"n": 0, "s": "", "ok": False, "tags": [1, 2, 3]}),
        C(id="pb3-packed-empty", title="Empty packed repeated is omitted", section="4.2", section_title="Packed Repeated Fields", section_url=f"{wire}#packed", paragraph="Zero elements produce no record.", requirement="MUST", expect="accept", input=hx(tags=[]), input_encoding="hex", decoded={"n": 0, "s": "", "ok": False, "tags": []}),
        C(id="pb3-packed-one", title="Packed repeated with one element", section="4.2", section_title="Packed Repeated Fields", section_url=f"{wire}#packed", paragraph="A single packed element is still length-delimited.", requirement="MUST", expect="accept", input=hx(tags=[7]), input_encoding="hex", decoded={"n": 0, "s": "", "ok": False, "tags": [7]}),
    ]
    unpacked = [
        C(id="pb2-unpacked-tags", title="proto2 unpacked repeated int32", section="4.2", section_title="Repeated Fields", section_url=f"{wire}#repeated", paragraph="proto2 writes one key+varint record per element.", requirement="MUST", expect="accept", input="200120022003", input_encoding="hex", decoded={"n": 0, "s": "", "ok": False, "tags": [1, 2, 3]}),
    ]
    json_cases = [
        C(id="pbj-object", title="JSON object maps to the message", section="JSON Mapping", section_title="message", section_url=pjson, paragraph="A JSON object’s keys are field names. proto3 JSON uses the same names as the .proto file by default.", requirement="MUST", expect="accept", input='{"n":7,"s":"kelp","ok":true}', input_encoding="utf-8", decoded={"n": 7, "s": "kelp", "ok": True, "tags": []}, schema="json"),
        C(id="pbj-empty", title="Empty JSON object is an empty message", section="JSON Mapping", section_title="message", section_url=pjson, paragraph="Missing fields take proto3 defaults.", requirement="MUST", expect="accept", input="{}", input_encoding="utf-8", decoded={"n": 0, "s": "", "ok": False, "tags": []}, schema="json"),
        C(id="pbj-null-field", title="JSON null means field default", section="JSON Mapping", section_title="null", section_url=pjson, paragraph="A JSON null for a proto3 singular field is treated as the default.", requirement="MUST", expect="accept", input='{"n":null}', input_encoding="utf-8", decoded={"n": 0, "s": "", "ok": False, "tags": []}, schema="json"),
        C(id="pbj-array-tags", title="JSON array maps to repeated field", section="JSON Mapping", section_title="repeated", section_url=pjson, paragraph="A JSON array becomes the repeated field.", requirement="MUST", expect="accept", input='{"tags":[1,2,3]}', input_encoding="utf-8", decoded={"n": 0, "s": "", "ok": False, "tags": [1, 2, 3]}, schema="json"),
        C(id="pbj-string-number", title="JSON string may hold an int32", section="JSON Mapping", section_title="int32", section_url=pjson, paragraph="Integer fields accept a JSON number or a decimal string.", requirement="MUST", expect="accept", input='{"n":"7"}', input_encoding="utf-8", decoded={"n": 7, "s": "", "ok": False, "tags": []}, schema="json"),
        C(id="pbj-reject-array", title="Top-level JSON array is not a message", section="JSON Mapping", section_title="message", section_url=pjson, paragraph="A message is a JSON object, not an array.", requirement="MUST NOT", expect="reject", input="[1,2]", input_encoding="utf-8", schema="json"),
        C(id="pbj-reject-scalar", title="Top-level JSON number is not a message", section="JSON Mapping", section_title="message", section_url=pjson, paragraph="A message is a JSON object.", requirement="MUST NOT", expect="reject", input="7", input_encoding="utf-8", schema="json"),
        C(id="pbj-reject-bad-json", title="Invalid JSON is not a proto3 JSON message", section="JSON Mapping", section_title="message", section_url=pjson, paragraph="The payload must be well-formed JSON.", requirement="MUST NOT", expect="reject", input="{", input_encoding="utf-8", schema="json"),
    ]
    extras3 = [c for c in _load_existing("protobuf/proto3.json") if c["id"] not in {x["id"] for x in cases + packed}]
    extras2 = [c for c in _load_existing("protobuf/proto2.json") if c["id"] not in {x["id"] for x in cases + unpacked}]
    extrasj = [c for c in _load_existing("protobuf/proto3-json.json") if c["id"] not in {x["id"] for x in json_cases}]
    dump("protobuf/proto3.json", {"format": "protobuf", "standard": "Protocol Buffers proto3", "version": "proto3", "standard_url": wire, "provenance": "original-work", "notes": "Full wire grammar from protobuf.dev (empty, varints, strings, packed, unknown, rejects).", "cases": _merge(cases + packed, extras3)})
    dump("protobuf/proto2.json", {"format": "protobuf", "standard": "Protocol Buffers proto2", "version": "proto2", "standard_url": "https://protobuf.dev/programming-guides/proto2/", "provenance": "original-work", "notes": "Same wire grammar; unpacked repeated scalars.", "cases": _merge(cases + unpacked, extras2)})
    dump("protobuf/proto3-json.json", {"format": "protobuf", "standard": "Protocol Buffers JSON mapping", "version": "proto3-json", "standard_url": pjson, "provenance": "original-work", "notes": "Official proto3 JSON mapping (protobuf.dev/programming-guides/json/).", "cases": _merge(json_cases, extrasj)})
    _ = MessageToJson  # imported for availability / future dump


def write_bson() -> None:
    import bson

    spec = "https://bsonspec.org/spec.html"

    def hx(doc: dict) -> str:
        return bson.encode(doc).hex()

    types = [
        C(id="bson-empty", title="Empty document", section="Basic Types", section_title="document", section_url=spec, paragraph="A document is an int32 size, zero or more elements, and a trailing 0x00. The empty document is 5 bytes.", requirement="MUST", expect="accept", input=hx({}), input_encoding="hex", decoded={}),
        C(id="bson-double", title="double harbor=1.5", section="BSON Types", section_title="double", section_url=spec, paragraph="Type 0x01 is a cstring name plus an IEEE-754 little-endian float64.", requirement="MUST", expect="accept", input=hx({"harbor": 1.5}), input_encoding="hex", decoded={"harbor": 1.5}),
        C(id="bson-string", title="UTF-8 string s=kelp", section="BSON Types", section_title="string", section_url=spec, paragraph="Type 0x02 is a cstring name, int32 length including NUL, UTF-8 bytes, and NUL.", requirement="MUST", expect="accept", input=hx({"s": "kelp"}), input_encoding="hex", decoded={"s": "kelp"}),
        C(id="bson-string-empty", title="Empty string", section="BSON Types", section_title="string", section_url=spec, paragraph="A string length of 1 is the terminating NUL only.", requirement="MUST", expect="accept", input=hx({"s": ""}), input_encoding="hex", decoded={"s": ""}),
        C(id="bson-string-harbor", title="UTF-8 string harbor", section="BSON Types", section_title="string", section_url=spec, paragraph="Multi-byte names and values are UTF-8.", requirement="MUST", expect="accept", input=hx({"harbor": "kelp"}), input_encoding="hex", decoded={"harbor": "kelp"}),
        C(id="bson-embedded", title="Embedded document berth", section="BSON Types", section_title="document", section_url=spec, paragraph="Type 0x03 is a nested document with its own size prefix.", requirement="MUST", expect="accept", input=hx({"berth": {"n": 7}}), input_encoding="hex", decoded={"berth": {"n": 7}}),
        C(id="bson-array", title="Array tags=[1,2]", section="BSON Types", section_title="array", section_url=spec, paragraph="Type 0x04 is a document whose keys are the decimal indexes.", requirement="MUST", expect="accept", input=hx({"tags": [1, 2]}), input_encoding="hex", decoded={"tags": [1, 2]}),
        C(id="bson-array-empty", title="Empty array", section="BSON Types", section_title="array", section_url=spec, paragraph="An empty array is a 5-byte empty sub-document.", requirement="MUST", expect="accept", input=hx({"tags": []}), input_encoding="hex", decoded={"tags": []}),
        C(id="bson-binary", title="Binary subtype 0 generic", section="BSON Types", section_title="binary", section_url=spec, paragraph="Type 0x05 is int32 length, a subtype byte, and that many payload bytes.", requirement="MUST", expect="accept", input=hx({"blob": bson.Binary(b"kelp", 0)}), input_encoding="hex"),
        C(id="bson-bool-true", title="Boolean ok=true", section="BSON Types", section_title="boolean", section_url=spec, paragraph="Type 0x08 is a cstring name plus one byte 0x00 or 0x01.", requirement="MUST", expect="accept", input=hx({"ok": True}), input_encoding="hex", decoded={"ok": True}),
        C(id="bson-bool-false", title="Boolean ok=false", section="BSON Types", section_title="boolean", section_url=spec, paragraph="False is payload 0x00.", requirement="MUST", expect="accept", input=hx({"ok": False}), input_encoding="hex", decoded={"ok": False}),
        C(id="bson-null", title="Null missing", section="BSON Types", section_title="null", section_url=spec, paragraph="Type 0x0A is a cstring name and no payload.", requirement="MUST", expect="accept", input=hx({"missing": None}), input_encoding="hex", decoded={"missing": None}),
        C(id="bson-int32", title="int32 element n=7", section="BSON Types", section_title="int32", section_url=spec, paragraph="Type 0x10 is a cstring name plus a little-endian int32.", requirement="MUST", expect="accept", input=hx({"n": 7}), input_encoding="hex", decoded={"n": 7}),
        C(id="bson-int32-neg", title="int32 element n=-1", section="BSON Types", section_title="int32", section_url=spec, paragraph="int32 is two's complement little-endian.", requirement="MUST", expect="accept", input=hx({"n": -1}), input_encoding="hex", decoded={"n": -1}),
        C(id="bson-int64", title="int64 element n=2**40", section="BSON Types", section_title="int64", section_url=spec, paragraph="Type 0x12 is a cstring name plus a little-endian int64.", requirement="MUST", expect="accept", input=hx({"n": 2**40}), input_encoding="hex", decoded={"n": 2**40}),
        C(id="bson-two-fields", title="Two elements n and s", section="Basic Types", section_title="document", section_url=spec, paragraph="Elements follow one after another before the trailing NUL.", requirement="MUST", expect="accept", input=hx({"n": 7, "s": "kelp"}), input_encoding="hex", decoded={"n": 7, "s": "kelp"}),
    ]
    rejects = [
        C(id="bson-truncated", title="Declared size longer than the buffer", section="Basic Types", section_title="document", section_url=spec, paragraph="The int32 size must match the actual byte length.", requirement="MUST NOT", expect="reject", input="0c000000106e00", input_encoding="hex"),
        C(id="bson-missing-eoo", title="Document without trailing NUL", section="Basic Types", section_title="document", section_url=spec, paragraph="Every document ends with 0x00.", requirement="MUST NOT", expect="reject", input="0b000000106e0007000000", input_encoding="hex"),
        C(id="bson-bad-type", title="Unknown element type", section="BSON Types", section_title="elements", section_url=spec, paragraph="The type byte must be a defined BSON type. 0x14 is not one.", requirement="MUST NOT", expect="reject", input="0800000014780000", input_encoding="hex"),
        C(id="bson-empty-input", title="Empty buffer is not a document", section="Basic Types", section_title="document", section_url=spec, paragraph="A document is at least five bytes.", requirement="MUST NOT", expect="reject", input="", input_encoding="hex"),
        C(id="bson-short-size", title="Shorter than the size int32", section="Basic Types", section_title="document", section_url=spec, paragraph="The first four bytes are the document length.", requirement="MUST NOT", expect="reject", input="0500", input_encoding="hex"),
        C(id="bson-size-too-small", title="Size field smaller than 5", section="Basic Types", section_title="document", section_url=spec, paragraph="The smallest document is 5 bytes.", requirement="MUST NOT", expect="reject", input="0400000000", input_encoding="hex"),
        C(id="bson-truncated-string", title="String payload shorter than declared", section="BSON Types", section_title="string", section_url=spec, paragraph="The int32 length must match the remaining bytes plus NUL.", requirement="MUST NOT", expect="reject", input="0c000000027300050000006b00", input_encoding="hex"),
        C(id="bson-bad-bool", title="Boolean payload is not 0 or 1", section="BSON Types", section_title="boolean", section_url=spec, paragraph="A bool payload must be 0x00 or 0x01.", requirement="MUST NOT", expect="reject", input="0a000000086f6b000200", input_encoding="hex"),
    ]
    dec128 = [
        C(id="bson-decimal128-zero", title="decimal128 canonical zero (type 0x13)", section="BSON Types", section_title="decimal128", section_url=spec, paragraph="BSON 1.1 added type 0x13 decimal128 (16-byte IEEE 754-2008 decimal). Recreated payload is canonical +0.", requirement="MUST", expect="accept", input="180000001364000000000000000000000000000000403000", input_encoding="hex", notes="If the library has no decimal128, this may skip or fail. Not from MongoDB corpus."),
    ]
    extras = [c for c in _load_existing("bson/spec-1.1.json") if c["id"] not in {x["id"] for x in types + rejects}]
    all_11 = _merge(types + rejects, extras)
    dump("bson/spec-1.1.json", {"format": "bson", "standard": "BSON 1.1", "version": "1.1", "standard_url": spec, "provenance": "original-work", "notes": "Full type matrix recreated from bsonspec.org. MongoDB bson-corpus is CC BY-NC-SA and was not copied.", "cases": all_11})
    keep_10 = {c["id"] for c in types + rejects} - {"bson-null", "bson-decimal128-zero"}
    dump("bson/spec-1.0.json", {"format": "bson", "standard": "BSON 1.0", "version": "1.0", "standard_url": spec, "provenance": "original-work", "notes": "1.0 framing and types without null / decimal128. Recreated; not MongoDB corpus.", "cases": [c for c in all_11 if c["id"] in keep_10]})
    dump("bson/spec-1.1-decimal128.json", {"format": "bson", "standard": "BSON 1.1 decimal128", "version": "1.1-decimal128", "standard_url": spec, "provenance": "original-work", "notes": "BSON 1.1 decimal128 plus framing rejects. Recreated.", "cases": dec128 + [types[0], rejects[0], rejects[1]]})


def write_flexbuffers() -> None:
    from flatbuffers import flexbuffers

    flex = "https://flatbuffers.dev/flexbuffers.html"
    spec = "https://flatbuffers.dev/internals/"

    def root_hex(build) -> str:
        return bytes(build()).hex()

    def int_root(n: int) -> str:
        b = flexbuffers.Builder()
        b.Int(n)
        return bytes(b.Finish()).hex()

    def str_root(s: str) -> str:
        b = flexbuffers.Builder()
        b.String(s)
        return bytes(b.Finish()).hex()

    def bool_root(v: bool) -> str:
        b = flexbuffers.Builder()
        b.Bool(v)
        return bytes(b.Finish()).hex()

    def float_root(v: float) -> str:
        b = flexbuffers.Builder()
        b.Float(v)
        return bytes(b.Finish()).hex()

    def blob_root(raw: bytes) -> str:
        b = flexbuffers.Builder()
        b.Blob(raw)
        return bytes(b.Finish()).hex()

    def vec_ints(vals: list[int]) -> str:
        b = flexbuffers.Builder()
        b.VectorFromElements(vals)
        return bytes(b.Finish()).hex()

    def map_str(d: dict) -> str:
        b = flexbuffers.Builder()
        b.MapFromElements(d)
        return bytes(b.Finish()).hex()

    cases = [
        C(id="fb-flex-int-0", title="FlexBuffers integer 0", section="FlexBuffers", section_title="Numbers", section_url=flex, paragraph="An integer root must decode to 0.", requirement="MUST", expect="accept", input=int_root(0), input_encoding="hex", decoded=0),
        C(id="fb-flex-int-7", title="FlexBuffers integer 7", section="FlexBuffers", section_title="Numbers", section_url=flex, paragraph="An integer root must decode to 7.", requirement="MUST", expect="accept", input=int_root(7), input_encoding="hex", decoded=7),
        C(id="fb-flex-int-neg", title="FlexBuffers integer -1", section="FlexBuffers", section_title="Numbers", section_url=flex, paragraph="Signed integers use two's complement.", requirement="MUST", expect="accept", input=int_root(-1), input_encoding="hex", decoded=-1),
        C(id="fb-flex-int-300", title="FlexBuffers integer 300", section="FlexBuffers", section_title="Numbers", section_url=flex, paragraph="Values that do not fit in one byte use a wider parent.", requirement="MUST", expect="accept", input=int_root(300), input_encoding="hex", decoded=300),
        C(id="fb-flex-true", title="FlexBuffers true", section="FlexBuffers", section_title="Booleans", section_url=flex, paragraph="A boolean root is a type byte plus a parent width.", requirement="MUST", expect="accept", input=bool_root(True), input_encoding="hex", decoded=True),
        C(id="fb-flex-false", title="FlexBuffers false", section="FlexBuffers", section_title="Booleans", section_url=flex, paragraph="False is a distinct type, not an integer 0.", requirement="MUST", expect="accept", input=bool_root(False), input_encoding="hex", decoded=False),
        C(id="fb-flex-float", title="FlexBuffers float 1.5", section="FlexBuffers", section_title="Numbers", section_url=flex, paragraph="A float root uses IEEE-754.", requirement="MUST", expect="accept", input=float_root(1.5), input_encoding="hex", decoded=1.5),
        C(id="fb-flex-string", title="FlexBuffers string kelp", section="FlexBuffers", section_title="Strings", section_url=flex, paragraph="A string is UTF-8 bytes plus a NUL, with a length prefix.", requirement="MUST", expect="accept", input=str_root("kelp"), input_encoding="hex", decoded="kelp"),
        C(id="fb-flex-string-empty", title="FlexBuffers empty string", section="FlexBuffers", section_title="Strings", section_url=flex, paragraph="The empty string is a valid root.", requirement="MUST", expect="accept", input=str_root(""), input_encoding="hex", decoded=""),
        C(id="fb-flex-string-harbor", title="FlexBuffers string harbor", section="FlexBuffers", section_title="Strings", section_url=flex, paragraph="Longer ASCII is still a string root.", requirement="MUST", expect="accept", input=str_root("harbor"), input_encoding="hex", decoded="harbor"),
        C(id="fb-flex-blob", title="FlexBuffers blob kelp", section="FlexBuffers", section_title="Blobs", section_url=flex, paragraph="A blob is uninterpreted bytes with a length.", requirement="MUST", expect="accept", input=blob_root(b"kelp"), input_encoding="hex", decoded={"$hex": "6b656c70"}),
        C(id="fb-flex-vec", title="FlexBuffers vector [1,2,3]", section="FlexBuffers", section_title="Vectors", section_url=flex, paragraph="A typed or untyped vector stores elements then a count.", requirement="MUST", expect="accept", input=vec_ints([1, 2, 3]), input_encoding="hex", decoded=[1, 2, 3]),
        C(id="fb-flex-vec-empty", title="FlexBuffers empty vector", section="FlexBuffers", section_title="Vectors", section_url=flex, paragraph="A vector may have zero elements.", requirement="MUST", expect="accept", input=vec_ints([]), input_encoding="hex", decoded=[]),
        C(id="fb-flex-map", title="FlexBuffers map harbor=kelp", section="FlexBuffers", section_title="Maps", section_url=flex, paragraph="A map is a vector of keys plus values.", requirement="MUST", expect="accept", input=map_str({"harbor": "kelp"}), input_encoding="hex", decoded={"harbor": "kelp"}),
        C(id="fb-flex-empty", title="Empty buffer is not a FlexBuffers root", section="FlexBuffers", section_title="Root", section_url=flex, paragraph="A root requires a parent width and type byte.", requirement="MUST NOT", expect="reject", input="", input_encoding="hex"),
        C(id="fb-flex-truncated", title="Truncated FlexBuffers buffer", section="FlexBuffers", section_title="Root", section_url=flex, paragraph="The root offset must land inside the buffer.", requirement="MUST NOT", expect="reject", input="00", input_encoding="hex"),
        C(id="fb-flex-short", title="Two-byte stub is not a root", section="FlexBuffers", section_title="Root", section_url=flex, paragraph="The trailing type and parent-width bytes must be present.", requirement="MUST NOT", expect="reject", input="0001", input_encoding="hex"),
    ]
    gold = FB_SRC / "tests" / "gold_flexbuffer_example.bin"
    if gold.is_file():
        cases.insert(
            0,
            C(
                id="fb-flex-gold",
                title="Official gold_flexbuffer_example.bin",
                section="FlexBuffers",
                section_title="example",
                section_url=flex,
                paragraph="Vendored official example from google/flatbuffers tests/ (Apache-2.0).",
                requirement="MUST",
                expect="accept",
                input=gold.read_bytes().hex(),
                input_encoding="hex",
                notes="Vendored from google/flatbuffers tests/gold_flexbuffer_example.bin (Apache-2.0).",
            ),
        )
    extras = [c for c in _load_existing("flatbuffers/flexbuffers.json") if c["id"] not in {x["id"] for x in cases}]
    dump("flatbuffers/flexbuffers.json", {"format": "flatbuffers", "standard": "FlexBuffers", "version": "flexbuffers", "standard_url": flex, "provenance": "google/flatbuffers+original-work", "notes": "Official gold example (Apache-2.0) plus a full type matrix from the FlexBuffers rules.", "cases": _merge(cases, extras)})
    dump(
        "flatbuffers/internals.json",
        {
            "format": "flatbuffers",
            "standard": "FlatBuffers internals",
            "version": "tables",
            "standard_url": spec,
            "provenance": "original-work",
            "notes": "Table buffers need generated code. These cases only ask whether the buffer is long enough to be a table.",
            "cases": [
                C(id="fb-empty", title="Empty buffer is not a table", section="Tables", section_title="vtable", section_url=spec, paragraph="A table starts with a uoffset to a vtable.", requirement="MUST NOT", expect="reject", input="", input_encoding="hex"),
                C(id="fb-short", title="Shorter than a uoffset", section="Tables", section_title="vtable", section_url=spec, paragraph="The first four bytes are a little-endian uoffset.", requirement="MUST NOT", expect="reject", input="0000", input_encoding="hex"),
                C(id="fb-three", title="Shorter than a uoffset (3 bytes)", section="Tables", section_title="vtable", section_url=spec, paragraph="A uoffset is four bytes.", requirement="MUST NOT", expect="reject", input="000000", input_encoding="hex"),
            ],
        },
    )
    dump(
        "flatbuffers/file-id.json",
        {
            "format": "flatbuffers",
            "standard": "FlatBuffers file identifier",
            "version": "file-id",
            "standard_url": spec,
            "provenance": "original-work",
            "notes": "Optional 4-byte file identifier after the root offset.",
            "cases": [
                C(id="fb-id-truncated", title="Identifier claimed but buffer too short", section="File format", section_title="file identifier", section_url=spec, paragraph="A file identifier is four bytes following the root uoffset.", requirement="MUST NOT", expect="reject", input="04000000", input_encoding="hex"),
                C(id="fb-id-empty", title="Empty buffer has no identifier", section="File format", section_title="file identifier", section_url=spec, paragraph="A file with an identifier is at least eight bytes.", requirement="MUST NOT", expect="reject", input="", input_encoding="hex"),
            ],
        },
    )


def copy_licenses() -> None:
    VENDOR.mkdir(parents=True, exist_ok=True)
    avro_lic = AVRO_SRC / "LICENSE.txt"
    if avro_lic.is_file():
        shutil.copyfile(avro_lic, VENDOR / "avro.Apache-2.0.txt")
        print("copied license avro.Apache-2.0.txt")
    fb_lic = FB_SRC / "LICENSE"
    if fb_lic.is_file():
        shutil.copyfile(fb_lic, VENDOR / "flatbuffers.Apache-2.0.txt")
        print("copied license flatbuffers.Apache-2.0.txt")


def main() -> None:
    copy_licenses()
    write_avro()
    write_protobuf()
    write_bson()
    write_flexbuffers()


if __name__ == "__main__":
    main()
