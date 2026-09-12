#!/usr/bin/env python3
"""Original catalogs for Thrift, Cap'n Proto, Bond, Bebop, HOCON, plist, ZON.

XML is out of scope. Cases are original (harbor / kelp). See LEGAL.md.
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


def write_thrift() -> None:
    spec = "https://github.com/apache/thrift/blob/master/doc/specs/thrift-binary-protocol.md"
    cases = [
        C(id="thrift-stop", title="Empty struct is a STOP byte", section="Struct", section_title="STOP", section_url=spec, paragraph="A struct is a sequence of fields ended by type STOP (0x00).", requirement="MUST", expect="accept", input="00", input_encoding="hex"),
        C(id="thrift-bool-true", title="Bool field 1 = true", section="Field", section_title="BOOL", section_url=spec, paragraph="Type 2 is bool. The field header is type + i16 id, then one byte 0 or 1.", requirement="MUST", expect="accept", input="02000101 00", input_encoding="hex"),
        C(id="thrift-i32", title="I32 field 1 = 7", section="Field", section_title="I32", section_url=spec, paragraph="Type 8 is a big-endian int32.", requirement="MUST", expect="accept", input="08000100000007 00", input_encoding="hex"),
        C(id="thrift-string", title="STRING field 1 = kelp", section="Field", section_title="STRING", section_url=spec, paragraph="Type 11 is an i32 length plus that many UTF-8 bytes.", requirement="MUST", expect="accept", input="0b0001000000046b656c70 00", input_encoding="hex"),
        C(id="thrift-empty", title="Empty buffer is not a struct", section="Struct", section_title="STOP", section_url=spec, paragraph="A struct must end with STOP.", requirement="MUST NOT", expect="reject", input="", input_encoding="hex"),
        C(id="thrift-trunc-i32", title="I32 field shorter than 4 bytes", section="Field", section_title="I32", section_url=spec, paragraph="An I32 payload is four bytes.", requirement="MUST NOT", expect="reject", input="0800010000", input_encoding="hex"),
        C(id="thrift-bad-type", title="Unknown field type", section="Field", section_title="type", section_url=spec, paragraph="The type byte must be a defined Thrift type.", requirement="MUST NOT", expect="reject", input="0f000100", input_encoding="hex"),
    ]
    dump("thrift/binary.json", {"format": "thrift", "standard": "Apache Thrift binary protocol", "version": "binary", "standard_url": spec, "provenance": "original-work", "notes": "TBinaryProtocol field headers. Original values.", "cases": cases})
    dump("thrift/compact.json", {"format": "thrift", "standard": "Apache Thrift compact protocol", "version": "compact", "standard_url": "https://github.com/apache/thrift/blob/master/doc/specs/thrift-compact-protocol.md", "provenance": "original-work", "notes": "Compact protocol uses a STOP byte 0x00 for an empty struct as well.", "cases": [
        C(id="thrift-c-stop", title="Empty compact struct is STOP", section="Struct", section_title="STOP", section_url="https://github.com/apache/thrift/blob/master/doc/specs/thrift-compact-protocol.md", paragraph="Compact protocol also ends a struct with 0x00.", requirement="MUST", expect="accept", input="00", input_encoding="hex"),
        C(id="thrift-c-empty", title="Empty buffer is not a compact struct", section="Struct", section_title="STOP", section_url="https://github.com/apache/thrift/blob/master/doc/specs/thrift-compact-protocol.md", paragraph="A struct must end with STOP.", requirement="MUST NOT", expect="reject", input="", input_encoding="hex"),
    ]})


def write_capnp() -> None:
    spec = "https://capnproto.org/encoding.html"
    cases = [
        C(id="capnp-empty-struct", title="Empty struct pointer is null", section="Pointers", section_title="struct", section_url=spec, paragraph="A null pointer is eight zero bytes and means an empty / default value.", requirement="MUST", expect="accept", input="0000000000000000", input_encoding="hex"),
        C(id="capnp-trunc", title="Shorter than one pointer word", section="Pointers", section_title="word", section_url=spec, paragraph="Every pointer is 64 bits. A 4-byte buffer is not a message.", requirement="MUST NOT", expect="reject", input="00000000", input_encoding="hex"),
        C(id="capnp-empty", title="Empty buffer is not a message", section="Messages", section_title="segment table", section_url=spec, paragraph="A message starts with a segment-count word.", requirement="MUST NOT", expect="reject", input="", input_encoding="hex"),
        C(id="capnp-seg-trunc", title="Segment table claims a segment that is missing", section="Messages", section_title="segment table", section_url=spec, paragraph="The first word is (segment count − 1). The declared words must follow.", requirement="MUST NOT", expect="reject", input="00000000", input_encoding="hex"),
    ]
    dump("capnp/encoding.json", {"format": "capnp", "standard": "Cap'n Proto encoding", "version": "encoding", "standard_url": spec, "provenance": "original-work", "notes": "Well-formedness of the pointer / segment framing. Table contents need generated code.", "cases": cases})
    dump("capnp/packed.json", {"format": "capnp", "standard": "Cap'n Proto packed encoding", "version": "packed", "standard_url": f"{spec}#packing", "provenance": "original-work", "notes": "Packed stream is a compression of the same words.", "cases": [
        C(id="capnp-pack-empty", title="Empty packed stream is not a message", section="Packing", section_title="packed", section_url=f"{spec}#packing", paragraph="A packed message still has a segment table after unpacking.", requirement="MUST NOT", expect="reject", input="", input_encoding="hex"),
        C(id="capnp-pack-trunc", title="Truncated packed tag", section="Packing", section_title="tag", section_url=f"{spec}#packing", paragraph="A tag byte that claims extra literal words must be followed by them.", requirement="MUST NOT", expect="reject", input="ff", input_encoding="hex"),
    ]})


def write_bond() -> None:
    spec = "https://microsoft.github.io/bond/manual/bond_cpp.html"
    cases = [
        C(id="bond-empty", title="Empty Compact Binary payload", section="Compact Binary", section_title="BT_STOP", section_url=spec, paragraph="A struct ends with BT_STOP (0x00).", requirement="MUST", expect="accept", input="00", input_encoding="hex"),
        C(id="bond-trunc", title="Empty buffer is not a Bond struct", section="Compact Binary", section_title="BT_STOP", section_url=spec, paragraph="A payload must include the STOP terminator.", requirement="MUST NOT", expect="reject", input="", input_encoding="hex"),
        C(id="bond-bad-type", title="Unknown type nibble", section="Compact Binary", section_title="field tag", section_url=spec, paragraph="The low nibble of a field tag is a Bond type id.", requirement="MUST NOT", expect="reject", input="0f01", input_encoding="hex"),
    ]
    dump("bond/compact.json", {"format": "bond", "standard": "Microsoft Bond Compact Binary", "version": "compact", "standard_url": spec, "provenance": "original-work", "notes": "Compact Binary STOP / field tags. Original.", "cases": cases})
    dump("bond/fast.json", {"format": "bond", "standard": "Microsoft Bond Fast Binary", "version": "fast", "standard_url": spec, "provenance": "original-work", "notes": "Fast Binary also terminates a struct with BT_STOP.", "cases": cases})


def write_bebop() -> None:
    spec = "https://github.com/6over3/bebop/wiki/Wire-format"
    cases = [
        C(id="bebop-empty-struct", title="Empty struct is zero bytes", section="Structs", section_title="empty", section_url=spec, paragraph="A struct with no fields encodes to zero bytes.", requirement="MUST", expect="accept", input="", input_encoding="hex"),
        C(id="bebop-bool-true", title="Bool true is 0x01", section="Types", section_title="bool", section_url=spec, paragraph="A bool is one byte, 0 or 1.", requirement="MUST", expect="accept", input="01", input_encoding="hex", decoded=True, schema="bool"),
        C(id="bebop-bool-false", title="Bool false is 0x00", section="Types", section_title="bool", section_url=spec, paragraph="A bool is one byte, 0 or 1.", requirement="MUST", expect="accept", input="00", input_encoding="hex", decoded=False, schema="bool"),
        C(id="bebop-guid-short", title="GUID shorter than 16 bytes", section="Types", section_title="guid", section_url=spec, paragraph="A guid is exactly 16 bytes.", requirement="MUST NOT", expect="reject", input="00000000", input_encoding="hex", schema="guid"),
        C(id="bebop-string-trunc", title="String shorter than declared length", section="Types", section_title="string", section_url=spec, paragraph="A string is a uint32 length plus that many UTF-8 bytes.", requirement="MUST NOT", expect="reject", input="040000006b65", input_encoding="hex", schema="string"),
    ]
    dump("bebop/spec.json", {"format": "bebop", "standard": "Bebop", "version": "1", "standard_url": spec, "provenance": "original-work", "notes": "Original well-formedness cases from the Bebop specification.", "cases": cases})


def write_hocon() -> None:
    spec = "https://github.com/lightbend/config/blob/main/HOCON.md"
    cases = [
        C(id="hocon-empty-object", title="Empty object", section="API / syntax", section_title="object", section_url=spec, paragraph="An object is braces around fields. {} is valid.", requirement="MUST", expect="accept", input="{}", decoded={}),
        C(id="hocon-unquoted", title="Unquoted key and value", section="Unquoted strings", section_title="unquoted", section_url=spec, paragraph="Keys and values may be unquoted if they are simple tokens.", requirement="MUST", expect="accept", input="harbor = kelp"),
        C(id="hocon-equals", title="Equals is a separator", section="Separators", section_title="= or :", section_url=spec, paragraph="A field may use = or : between key and value.", requirement="MUST", expect="accept", input="harbor: kelp"),
        C(id="hocon-comment", title="// comment is whitespace", section="Comments", section_title="//", section_url=spec, paragraph="// starts a comment to end of line.", requirement="MUST", expect="accept", input="harbor = kelp // berth"),
        C(id="hocon-nested", title="Nested object", section="API / syntax", section_title="object", section_url=spec, paragraph="Values may be nested objects.", requirement="MUST", expect="accept", input="harbor { berth = 7 }"),
        C(id="hocon-unclosed", title="Unclosed object", section="API / syntax", section_title="object", section_url=spec, paragraph="An object must close with }.", requirement="MUST NOT", expect="reject", input="harbor { berth = 7"),
        C(id="hocon-bare-eq", title="Equals without a key", section="Separators", section_title="= or :", section_url=spec, paragraph="A separator must follow a key.", requirement="MUST NOT", expect="reject", input="= kelp"),
    ]
    dump("hocon/v1.json", {"format": "hocon", "standard": "HOCON", "version": "1", "standard_url": spec, "provenance": "original-work", "notes": "Original cases from the Lightbend HOCON spec.", "cases": cases})


def write_plist() -> None:
    spec = "https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/PropertyLists/UnderstandXMLPlist/UnderstandXMLPlist.html"
    bin_spec = "https://medium.com/@karaiskc/understanding-apples-binary-property-list-format-281e6da00dbd"
    xml_cases = [
        C(id="plist-xml-empty-dict", title="Empty XML dictionary", section="XML Property Lists", section_title="dict", section_url=spec, paragraph="A plist document wraps one value. An empty dict is valid.", requirement="MUST", expect="accept", input='<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict/></plist>', decoded={}),
        C(id="plist-xml-string", title="XML string kelp", section="XML Property Lists", section_title="string", section_url=spec, paragraph="A <string> element is a Unicode string.", requirement="MUST", expect="accept", input='<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><string>kelp</string></plist>', decoded="kelp"),
        C(id="plist-xml-int", title="XML integer 7", section="XML Property Lists", section_title="integer", section_url=spec, paragraph="An <integer> element is a signed integer.", requirement="MUST", expect="accept", input='<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><integer>7</integer></plist>', decoded=7),
        C(id="plist-xml-true", title="XML true", section="XML Property Lists", section_title="true", section_url=spec, paragraph="<true/> is the boolean true.", requirement="MUST", expect="accept", input='<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><true/></plist>', decoded=True),
        C(id="plist-xml-unclosed", title="Unclosed plist", section="XML Property Lists", section_title="document", section_url=spec, paragraph="The document must be well-formed XML.", requirement="MUST NOT", expect="reject", input="<plist><dict>"),
        C(id="plist-xml-empty", title="Empty buffer is not a plist", section="XML Property Lists", section_title="document", section_url=spec, paragraph="A plist is an XML document or a bplist.", requirement="MUST NOT", expect="reject", input=""),
    ]
    bin_cases = [
        C(id="plist-bin-magic", title="Binary plist starts with bplist", section="Binary", section_title="header", section_url=bin_spec, paragraph="A binary plist begins with the ASCII magic bplist.", requirement="MUST NOT", expect="reject", input="00000000", input_encoding="hex"),
        C(id="plist-bin-short", title="Truncated bplist header", section="Binary", section_title="header", section_url=bin_spec, paragraph="The header is the 6-byte magic plus a 2-byte version.", requirement="MUST NOT", expect="reject", input="62706c697374", input_encoding="hex"),
    ]
    dump("plist/xml.json", {"format": "plist", "standard": "Apple XML property list", "version": "xml", "standard_url": spec, "provenance": "original-work", "notes": "XML plist 1.0. Original values.", "cases": xml_cases})
    dump("plist/binary.json", {"format": "plist", "standard": "Apple binary property list", "version": "binary", "standard_url": bin_spec, "provenance": "original-work", "notes": "bplist magic / header rejects. Accept cases come from plistlib in the runner if needed.", "cases": bin_cases})


def write_zon() -> None:
    spec = "https://ziglang.org/documentation/master/#Zig-Object-Notation-ZON"
    cases = [
        C(id="zon-empty-struct", title="Empty struct", section="ZON", section_title="struct", section_url=spec, paragraph="An anonymous struct is .{ }.", requirement="MUST", expect="accept", input=".{}"),
        C(id="zon-int", title="Integer 7", section="ZON", section_title="number", section_url=spec, paragraph="A ZON document may be a single integer.", requirement="MUST", expect="accept", input="7", decoded=7),
        C(id="zon-string", title="String kelp", section="ZON", section_title="string", section_url=spec, paragraph="A string is double-quoted.", requirement="MUST", expect="accept", input='"kelp"', decoded="kelp"),
        C(id="zon-field", title="Named field harbor", section="ZON", section_title="struct", section_url=spec, paragraph="A field is .name = value,", requirement="MUST", expect="accept", input=".{ .harbor = \"kelp\" }"),
        C(id="zon-unclosed", title="Unclosed struct", section="ZON", section_title="struct", section_url=spec, paragraph="A struct must close with }.", requirement="MUST NOT", expect="reject", input=".{ .harbor = \"kelp\""),
        C(id="zon-bare-eq", title="Equals without a field name", section="ZON", section_title="struct", section_url=spec, paragraph="A field starts with a leading dot and a name.", requirement="MUST NOT", expect="reject", input=".{ = 7 }"),
    ]
    dump("zon/v1.json", {"format": "zon", "standard": "Zig Object Notation", "version": "1", "standard_url": spec, "provenance": "original-work", "notes": "Original cases from the Zig language reference.", "cases": cases})


def main() -> None:
    write_thrift()
    write_capnp()
    write_bond()
    write_bebop()
    write_hocon()
    write_plist()
    write_zon()


if __name__ == "__main__":
    main()
