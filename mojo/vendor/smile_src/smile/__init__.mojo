from std.collections import List, Span

from smile_runtime.doc import SmileDoc
from smile_runtime.error import DecodeError
from smile_runtime.options import EncodeOptions
from smile_wire.codec import decode, encode


def decode_bytes[origin: ImmOrigin](raw: Span[Byte, origin]) raises DecodeError -> SmileDoc:
    """Decode one Smile section. A missing header defaults to shared names on."""
    return decode(raw, False)


def encode_doc(doc: SmileDoc, options: EncodeOptions) raises DecodeError -> List[Byte]:
    """Encode every top-level value with one header and the caller's layout flags."""
    return encode(doc, options)
