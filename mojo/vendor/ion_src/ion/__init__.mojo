from std.collections import List, Span

from ion_runtime.doc import (
    IonDoc,
    IonTime,
    K_BLOB,
    K_BOOL,
    K_CLOB,
    K_DECIMAL,
    K_FLOAT,
    K_INT,
    K_LIST,
    K_NULL,
    K_SEXP,
    K_STRING,
    K_STRUCT,
    K_SYMBOL,
    K_TIMESTAMP,
)
from ion_runtime.eq import ion_eq
from ion_runtime.error import DecodeError
from ion_runtime.options import EncodeOptions
from ion_runtime.symtab import Catalog, LocalTab, SharedTable
from ion_wire.binary import decode_binary
from ion_wire.text import decode_text
from ion_wire.writer import encode_binary, encode_text


def decode[origin: ImmOrigin](raw: Span[Byte, origin], cat: Catalog) raises DecodeError -> IonDoc:
    """Decode text or binary Ion. A leading Ion version marker selects binary."""
    if (
        len(raw) >= 4
        and Int(raw[0]) == 0xE0
        and Int(raw[1]) == 0x01
        and Int(raw[3]) == 0xEA
    ):
        return decode_binary(raw, cat)
    return decode_text(raw, cat)


def encode(doc: IonDoc, options: EncodeOptions, cat: Catalog) raises DecodeError -> List[Byte]:
    """Encode one document. `options.binary` selects the binary encoding."""
    if options.binary:
        return encode_binary(doc, options, cat)
    var text = encode_text(doc, options)
    var raw = text.as_bytes()
    var out = List[Byte]()
    var i = 0
    while i < len(raw):
        out.append(raw[i])
        i += 1
    return out^
