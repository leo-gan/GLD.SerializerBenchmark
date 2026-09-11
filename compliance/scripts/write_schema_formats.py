#!/usr/bin/env python3
"""Original catalogs for schema/binary formats (not XML).

Protobuf / Avro / FlatBuffers cases follow the public encoding rules.
BSON is recreated from bsonspec.org (MongoDB corpus is CC BY-NC-SA and
must not be copied). See compliance/LEGAL.md.
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "data"


def dump(rel: str, doc: dict) -> None:
    path = ROOT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(doc, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"wrote {path.relative_to(ROOT.parent)} ({len(doc['cases'])} cases)")


def C(**kwargs) -> dict:
    return kwargs


def write_protobuf() -> None:
    wire = "https://protobuf.dev/programming-guides/encoding/"
    proto3 = "https://protobuf.dev/programming-guides/proto3/"
    proto2 = "https://protobuf.dev/programming-guides/proto2/"
    pjson = "https://protobuf.dev/programming-guides/json/"

    common_wire = [
        C(
            id="pb-empty",
            title="Empty proto3 message is valid",
            section="1",
            section_title="A Message",
            section_url=wire,
            paragraph="A message is a series of key-value records. Zero records is a valid message.",
            requirement="MUST",
            expect="accept",
            input="",
            input_encoding="hex",
            decoded={"n": 0, "s": "", "ok": False, "tags": []},
        ),
        C(
            id="pb-varint-7",
            title="Varint field 1 = 7",
            section="2",
            section_title="Base 128 Varints",
            section_url=f"{wire}#varints",
            paragraph="Each byte of a varint uses its lower 7 bits for data. Values below 128 fit in one byte.",
            requirement="MUST",
            expect="accept",
            input="0807",
            input_encoding="hex",
            decoded={"n": 7, "s": "", "ok": False, "tags": []},
        ),
        C(
            id="pb-varint-300",
            title="Varint field 1 = 300",
            section="2",
            section_title="Base 128 Varints",
            section_url=f"{wire}#varints",
            paragraph="300 is 0x12c and takes two varint bytes (0xac 0x02).",
            requirement="MUST",
            expect="accept",
            input="08ac02",
            input_encoding="hex",
            decoded={"n": 300, "s": "", "ok": False, "tags": []},
        ),
        C(
            id="pb-string-kelp",
            title="Length-delimited field 2 = kelp",
            section="4",
            section_title="Length-Delimited",
            section_url=f"{wire}#length-types",
            paragraph="Wire type 2 is a varint length followed by that many payload bytes.",
            requirement="MUST",
            expect="accept",
            input="12046b656c70",
            input_encoding="hex",
            decoded={"n": 0, "s": "kelp", "ok": False, "tags": []},
        ),
        C(
            id="pb-bool-true",
            title="Bool field 3 = true",
            section="3",
            section_title="Message Structure",
            section_url=f"{wire}#structure",
            paragraph="A bool is a varint 0 or 1. Field 3 key is (3<<3)|0 = 0x18.",
            requirement="MUST",
            expect="accept",
            input="1801",
            input_encoding="hex",
            decoded={"n": 0, "s": "", "ok": True, "tags": []},
        ),
        C(
            id="pb-truncated-varint",
            title="Truncated varint is not well-formed",
            section="2",
            section_title="Base 128 Varints",
            section_url=f"{wire}#varints",
            paragraph="A continuation bit of 1 requires another byte.",
            requirement="MUST NOT",
            expect="reject",
            input="08ac",
            input_encoding="hex",
        ),
        C(
            id="pb-truncated-string",
            title="Length-delimited payload shorter than declared",
            section="4",
            section_title="Length-Delimited",
            section_url=f"{wire}#length-types",
            paragraph="The declared length must be present in the remaining bytes.",
            requirement="MUST NOT",
            expect="reject",
            input="12046b65",
            input_encoding="hex",
        ),
        C(
            id="pb-bad-wire-type",
            title="Wire type 7 is reserved / invalid",
            section="3",
            section_title="Message Structure",
            section_url=f"{wire}#structure",
            paragraph="The three-bit wire type 7 is not a defined encoding.",
            requirement="MUST NOT",
            expect="reject",
            input="0f",
            input_encoding="hex",
        ),
    ]
    proto3_extra = [
        C(
            id="pb3-packed-tags",
            title="proto3 packed repeated int32 field 4",
            section="4.2",
            section_title="Packed Repeated Fields",
            section_url=f"{wire}#packed",
            paragraph="In proto3, scalar repeated fields use packed encoding: one length-delimited record of concatenated varints.",
            requirement="MUST",
            expect="accept",
            input="2203010203",
            input_encoding="hex",
            decoded={"n": 0, "s": "", "ok": False, "tags": [1, 2, 3]},
        ),
    ]
    proto2_extra = [
        C(
            id="pb2-unpacked-tags",
            title="proto2 unpacked repeated int32 field 4",
            section="4.1",
            section_title="Repeated Fields",
            section_url=proto2,
            paragraph="proto2 default for scalar repeated is unpacked: one key/value per element.",
            requirement="MUST",
            expect="accept",
            input="200120022003",
            input_encoding="hex",
            decoded={"n": 0, "s": "", "ok": False, "tags": [1, 2, 3]},
        ),
    ]
    json_cases = [
        C(
            id="pbj-object",
            title="proto3 JSON object with camelCase omitted defaults",
            section="JSON Mapping",
            section_title="JSON Mapping",
            section_url=pjson,
            paragraph="proto3 JSON uses JSON names; default scalar values may be omitted.",
            requirement="MUST",
            expect="accept",
            input='{"s":"kelp"}',
            decoded={"n": 0, "s": "kelp", "ok": False, "tags": []},
            schema="json",
        ),
        C(
            id="pbj-number",
            title="proto3 JSON int32 as JSON number",
            section="JSON Mapping",
            section_title="JSON Mapping",
            section_url=pjson,
            paragraph="int32 is a JSON number in the official mapping.",
            requirement="MUST",
            expect="accept",
            input='{"n":7}',
            decoded={"n": 7, "s": "", "ok": False, "tags": []},
            schema="json",
        ),
        C(
            id="pbj-unknown-ignore",
            title="Unknown JSON names are ignored",
            section="JSON Mapping",
            section_title="JSON Mapping",
            section_url=pjson,
            paragraph="Unknown fields in proto3 JSON are ignored by default.",
            requirement="SHOULD",
            expect="accept",
            input='{"s":"kelp","harbor":1}',
            decoded={"n": 0, "s": "kelp", "ok": False, "tags": []},
            schema="json",
        ),
        C(
            id="pbj-not-object",
            title="A JSON array is not a message",
            section="JSON Mapping",
            section_title="JSON Mapping",
            section_url=pjson,
            paragraph="A message maps to a JSON object.",
            requirement="MUST NOT",
            expect="reject",
            input="[1,2]",
            schema="json",
        ),
        C(
            id="pbj-bad-type",
            title="String where int32 is required",
            section="JSON Mapping",
            section_title="JSON Mapping",
            section_url=pjson,
            paragraph="int32 must be a JSON number (or string of digits), not an arbitrary string.",
            requirement="MUST NOT",
            expect="reject",
            input='{"n":"kelp"}',
            schema="json",
        ),
    ]
    dump(
        "protobuf/proto3.json",
        {
            "format": "protobuf",
            "standard": "Protocol Buffers proto3",
            "version": "proto3",
            "standard_url": proto3,
            "provenance": "original-work",
            "notes": "Wire examples from the public encoding guide, original field numbers and values.",
            "cases": common_wire + proto3_extra,
        },
    )
    dump(
        "protobuf/proto2.json",
        {
            "format": "protobuf",
            "standard": "Protocol Buffers proto2",
            "version": "proto2",
            "standard_url": proto2,
            "provenance": "original-work",
            "notes": "Same wire grammar; extras cover unpacked repeated fields.",
            "cases": common_wire + proto2_extra,
        },
    )
    dump(
        "protobuf/proto3-json.json",
        {
            "format": "protobuf",
            "standard": "Protocol Buffers JSON mapping",
            "version": "proto3-json",
            "standard_url": pjson,
            "provenance": "original-work",
            "notes": "Official proto3 JSON mapping, original names.",
            "cases": json_cases,
        },
    )


def write_avro() -> None:
    spec = "https://avro.apache.org/docs/1.11.1/specification/"
    cases_int = [
        C(
            id="avro-int-0",
            title="Avro int 0",
            section="4.2",
            section_title="int",
            section_url=f"{spec}#schema-int",
            paragraph="int is a variable-length zigzag varint. 0 encodes as a single 0x00.",
            requirement="MUST",
            expect="accept",
            input="00",
            input_encoding="hex",
            decoded=0,
            schema="int",
        ),
        C(
            id="avro-int-1",
            title="Avro int 1",
            section="4.2",
            section_title="int",
            section_url=f"{spec}#schema-int",
            paragraph="Zigzag maps 1 to 2, encoded as 0x02.",
            requirement="MUST",
            expect="accept",
            input="02",
            input_encoding="hex",
            decoded=1,
            schema="int",
        ),
        C(
            id="avro-int-neg1",
            title="Avro int -1",
            section="4.2",
            section_title="int",
            section_url=f"{spec}#schema-int",
            paragraph="Zigzag maps -1 to 1, encoded as 0x01.",
            requirement="MUST",
            expect="accept",
            input="01",
            input_encoding="hex",
            decoded=-1,
            schema="int",
        ),
        C(
            id="avro-bool-true",
            title="Avro boolean true",
            section="4.1",
            section_title="boolean",
            section_url=f"{spec}#schema-boolean",
            paragraph="boolean is a single byte, 0 or 1.",
            requirement="MUST",
            expect="accept",
            input="01",
            input_encoding="hex",
            decoded=True,
            schema="boolean",
        ),
        C(
            id="avro-string-kelp",
            title="Avro string kelp",
            section="4.3",
            section_title="string",
            section_url=f"{spec}#schema-string",
            paragraph="string is a long byte-count followed by UTF-8. Count 4 zigzag-encodes as 0x08.",
            requirement="MUST",
            expect="accept",
            input="086b656c70",
            input_encoding="hex",
            decoded="kelp",
            schema="string",
        ),
        C(
            id="avro-bytes-empty",
            title="Avro empty bytes",
            section="4.3",
            section_title="bytes",
            section_url=f"{spec}#schema-bytes",
            paragraph="bytes is a long count plus that many raw bytes. Count 0 is 0x00.",
            requirement="MUST",
            expect="accept",
            input="00",
            input_encoding="hex",
            decoded={"$hex": ""},
            schema="bytes",
        ),
        C(
            id="avro-null",
            title="Avro null has no payload",
            section="4.1",
            section_title="null",
            section_url=f"{spec}#schema-null",
            paragraph="null is written as zero bytes.",
            requirement="MUST",
            expect="accept",
            input="",
            input_encoding="hex",
            decoded=None,
            schema="null",
        ),
        C(
            id="avro-truncated-string",
            title="String count longer than remaining bytes",
            section="4.3",
            section_title="string",
            section_url=f"{spec}#schema-string",
            paragraph="The declared byte count must be present.",
            requirement="MUST NOT",
            expect="reject",
            input="086b65",
            input_encoding="hex",
            schema="string",
        ),
        C(
            id="avro-truncated-int",
            title="Truncated zigzag varint",
            section="4.2",
            section_title="int",
            section_url=f"{spec}#schema-int",
            paragraph="A continuation bit requires another byte.",
            requirement="MUST NOT",
            expect="reject",
            input="80",
            input_encoding="hex",
            schema="int",
        ),
    ]
    union = [
        C(
            id="avro-union-string",
            title="Union [null, string] with a string",
            section="4.4",
            section_title="union",
            section_url=f"{spec}#unions",
            paragraph="A union writes the branch index as a long, then the value. Branch 1 is 0x02.",
            requirement="MUST",
            expect="accept",
            input="02086b656c70",
            input_encoding="hex",
            decoded="kelp",
            schema=["null", "string"],
        ),
        C(
            id="avro-union-null",
            title="Union [null, string] with null",
            section="4.4",
            section_title="union",
            section_url=f"{spec}#unions",
            paragraph="Branch 0 (null) is a single 0x00.",
            requirement="MUST",
            expect="accept",
            input="00",
            input_encoding="hex",
            decoded=None,
            schema=["null", "string"],
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
    ]
    dump(
        "avro/binary-1.11.json",
        {
            "format": "avro",
            "standard": "Apache Avro 1.11 binary",
            "version": "1.11",
            "standard_url": spec,
            "provenance": "original-work",
            "notes": "Binary encoding from the Avro 1.11 specification. Original values.",
            "cases": cases_int + union,
        },
    )
    dump(
        "avro/binary-1.8.json",
        {
            "format": "avro",
            "standard": "Apache Avro 1.8 binary",
            "version": "1.8",
            "standard_url": "https://avro.apache.org/docs/1.8.2/spec.html",
            "provenance": "original-work",
            "notes": "Binary encoding is stable since 1.8 for these primitives.",
            "cases": cases_int,
        },
    )
    dump(
        "avro/binary-1.12.json",
        {
            "format": "avro",
            "standard": "Apache Avro 1.12 binary",
            "version": "1.12",
            "standard_url": "https://avro.apache.org/docs/1.12.0/specification/",
            "provenance": "original-work",
            "notes": "Same primitive binary encoding as 1.11.",
            "cases": cases_int + union,
        },
    )


def write_bson() -> None:
    spec = "https://bsonspec.org/spec.html"
    cases = [
        C(
            id="bson-empty",
            title="Empty document",
            section="Basic Types",
            section_title="document",
            section_url=spec,
            paragraph="A document is an int32 size, zero or more elements, and a trailing 0x00. The empty document is 5 bytes.",
            requirement="MUST",
            expect="accept",
            input="0500000000",
            input_encoding="hex",
            decoded={},
        ),
        C(
            id="bson-int32",
            title="int32 element n=7",
            section="BSON Types",
            section_title="int32",
            section_url=spec,
            paragraph="Type 0x10 is a cstring name plus a little-endian int32. Recreated; not from the MongoDB corpus.",
            requirement="MUST",
            expect="accept",
            input="0c000000106e000700000000",
            input_encoding="hex",
            decoded={"n": 7},
        ),
        C(
            id="bson-string",
            title="UTF-8 string s=kelp",
            section="BSON Types",
            section_title="string",
            section_url=spec,
            paragraph="Type 0x02 is a cstring name, int32 length including NUL, UTF-8 bytes, and NUL.",
            requirement="MUST",
            expect="accept",
            input="11000000027300050000006b656c700000",
            input_encoding="hex",
            decoded={"s": "kelp"},
        ),
        C(
            id="bson-bool-true",
            title="Boolean ok=true",
            section="BSON Types",
            section_title="boolean",
            section_url=spec,
            paragraph="Type 0x08 is a cstring name plus one byte 0x00 or 0x01.",
            requirement="MUST",
            expect="accept",
            input="0a000000086f6b000100",
            input_encoding="hex",
            decoded={"ok": True},
        ),
        C(
            id="bson-null",
            title="Null missing",
            section="BSON Types",
            section_title="null",
            section_url=spec,
            paragraph="Type 0x0A is a cstring name and no payload.",
            requirement="MUST",
            expect="accept",
            input="0e0000000a6d697373696e670000",
            input_encoding="hex",
            decoded={"missing": None},
        ),
        C(
            id="bson-truncated",
            title="Declared size longer than the buffer",
            section="Basic Types",
            section_title="document",
            section_url=spec,
            paragraph="The int32 size must match the actual byte length.",
            requirement="MUST NOT",
            expect="reject",
            input="0c000000106e00",
            input_encoding="hex",
        ),
        C(
            id="bson-missing-eoo",
            title="Document without trailing NUL",
            section="Basic Types",
            section_title="document",
            section_url=spec,
            paragraph="Every document ends with 0x00.",
            requirement="MUST NOT",
            expect="reject",
            input="0b000000106e0007000000",
            input_encoding="hex",
        ),
        C(
            id="bson-bad-type",
            title="Unknown element type",
            section="BSON Types",
            section_title="elements",
            section_url=spec,
            paragraph="The type byte must be a defined BSON type.",
            requirement="MUST NOT",
            expect="reject",
            input="0800000014780000",
            input_encoding="hex",
        ),
    ]
    dump(
        "bson/spec-1.1.json",
        {
            "format": "bson",
            "standard": "BSON 1.1",
            "version": "1.1",
            "standard_url": spec,
            "provenance": "original-work",
            "notes": "Recreated from bsonspec.org. MongoDB bson-corpus is CC BY-NC-SA and was not copied.",
            "cases": cases,
        },
    )
    dump(
        "bson/spec-1.0.json",
        {
            "format": "bson",
            "standard": "BSON 1.0",
            "version": "1.0",
            "standard_url": spec,
            "provenance": "original-work",
            "notes": "Same document framing as 1.1 for these types. Recreated; not MongoDB corpus.",
            "cases": [c for c in cases if c["id"] in {
                "bson-empty", "bson-int32", "bson-string", "bson-bool-true",
                "bson-truncated", "bson-missing-eoo",
            }],
        },
    )
    dec128 = [
        C(
            id="bson-decimal128-zero",
            title="decimal128 canonical zero (type 0x13)",
            section="BSON Types",
            section_title="decimal128",
            section_url=spec,
            paragraph="BSON 1.1 added type 0x13 decimal128 (16-byte IEEE 754-2008 decimal). Recreated payload is canonical +0.",
            requirement="MUST",
            expect="accept",
            input="180000001364000000000000000000000000000000403000",
            input_encoding="hex",
            notes="If the library has no decimal128, this may skip or fail. Not from MongoDB corpus.",
        ),
    ]
    dump(
        "bson/spec-1.1-decimal128.json",
        {
            "format": "bson",
            "standard": "BSON 1.1 decimal128",
            "version": "1.1-decimal128",
            "standard_url": spec,
            "provenance": "original-work",
            "notes": "BSON 1.1 decimal128 only. Recreated; MongoDB corpus not used.",
            "cases": dec128 + [cases[0], cases[-3]],
        },
    )


def write_flatbuffers() -> None:
    spec = "https://flatbuffers.dev/flatbuffers_internals/"
    flex = "https://flatbuffers.dev/flexbuffers.html"
    cases = [
        C(
            id="fb-flex-int",
            title="FlexBuffers integer 7",
            section="FlexBuffers",
            section_title="Numbers",
            section_url=flex,
            paragraph="A FlexBuffers integer root must decode to 7.",
            requirement="MUST",
            expect="accept",
            input="070401",
            input_encoding="hex",
            decoded=7,
        ),
        C(
            id="fb-flex-string",
            title="FlexBuffers string kelp",
            section="FlexBuffers",
            section_title="Strings",
            section_url=flex,
            paragraph="A FlexBuffers string root must decode to kelp.",
            requirement="MUST",
            expect="accept",
            input="046b656c7000051401",
            input_encoding="hex",
            decoded="kelp",
        ),
        C(
            id="fb-flex-map",
            title="FlexBuffers map harbor=kelp",
            section="FlexBuffers",
            section_title="Maps",
            section_url=flex,
            paragraph="A FlexBuffers map is a vector of keys plus values.",
            requirement="MUST",
            expect="accept",
            input="686172626f7200046b656c7000010e0101010a14022401",
            input_encoding="hex",
            decoded={"harbor": "kelp"},
        ),
        C(
            id="fb-flex-empty",
            title="Empty buffer is not a FlexBuffers root",
            section="FlexBuffers",
            section_title="Root",
            section_url=flex,
            paragraph="A root requires a parent width and type byte.",
            requirement="MUST NOT",
            expect="reject",
            input="",
            input_encoding="hex",
        ),
        C(
            id="fb-flex-truncated",
            title="Truncated FlexBuffers buffer",
            section="FlexBuffers",
            section_title="Root",
            section_url=flex,
            paragraph="The root offset must land inside the buffer.",
            requirement="MUST NOT",
            expect="reject",
            input="00",
            input_encoding="hex",
        ),
    ]

    dump(
        "flatbuffers/flexbuffers.json",
        {
            "format": "flatbuffers",
            "standard": "FlexBuffers",
            "version": "flexbuffers",
            "standard_url": flex,
            "provenance": "original-work",
            "notes": "Schemaless FlexBuffers (FlatBuffers sibling). Original values.",
            "cases": cases,
        },
    )
    dump(
        "flatbuffers/internals.json",
        {
            "format": "flatbuffers",
            "standard": "FlatBuffers internals",
            "version": "tables",
            "standard_url": spec,
            "provenance": "original-work",
            "notes": "Table buffers need generated code; well-formedness rejects only.",
            "cases": [
                C(
                    id="fb-empty",
                    title="Empty buffer is not a table",
                    section="Tables",
                    section_title="vtable",
                    section_url=spec,
                    paragraph="A table starts with a uoffset to a vtable.",
                    requirement="MUST NOT",
                    expect="reject",
                    input="",
                    input_encoding="hex",
                ),
                C(
                    id="fb-short",
                    title="Shorter than a uoffset",
                    section="Tables",
                    section_title="vtable",
                    section_url=spec,
                    paragraph="The first four bytes are a little-endian uoffset.",
                    requirement="MUST NOT",
                    expect="reject",
                    input="0000",
                    input_encoding="hex",
                ),
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
                C(
                    id="fb-id-truncated",
                    title="Identifier claimed but buffer too short",
                    section="File format",
                    section_title="file identifier",
                    section_url=spec,
                    paragraph="A file identifier is four bytes following the root uoffset.",
                    requirement="MUST NOT",
                    expect="reject",
                    input="04000000",
                    input_encoding="hex",
                ),
            ],
        },
    )


def main() -> None:
    write_protobuf()
    write_avro()
    write_bson()
    write_flatbuffers()


if __name__ == "__main__":
    main()
