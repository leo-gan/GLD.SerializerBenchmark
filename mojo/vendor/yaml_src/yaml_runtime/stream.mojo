from std.collections import List, Optional, Span

from yaml_runtime.error import DecodeError
from yaml_runtime.options import DecodeOptions, EncodeOptions
from yaml_runtime.value import YamlValue, decode_one, encode_value
from yaml_wire.reader import WireReader


struct StreamDecoder[origin: ImmOrigin](Movable):
    var reader: WireReader[Self.origin]
    var done: Bool
    var count: Int

    def __init__(
        out self,
        data: Span[Byte, Self.origin],
        options: DecodeOptions = DecodeOptions.default,
    ):
        self.reader = WireReader[Self.origin](data, options=options)
        self.done = False
        self.count = 0

    def next_value(mut self) raises DecodeError -> Optional[YamlValue]:
        if self.done:
            return Optional[YamlValue]()
        self.reader.skip_separation()
        if self.reader.remaining() == 0:
            self.done = True
            return Optional[YamlValue]()
        if self.reader.at_document_end():
            self.reader.skip_document_end()
            self.reader.skip_separation()
            if self.reader.remaining() == 0:
                self.done = True
                return Optional[YamlValue]()
        if self.count >= 1048576:
            raise DecodeError(DecodeError.KIND_RANGE, self.reader.position())
        var v = decode_one(self.reader)
        self.count += 1
        return Optional[YamlValue](v^)

    def skip(mut self) raises DecodeError:
        _ = self.next_value()


def encode_all_values(
    docs: List[YamlValue], options: EncodeOptions = EncodeOptions.block
) raises DecodeError -> List[Byte]:
    var out = List[Byte]()
    var i = 0
    while i < len(docs):
        if i > 0:
            var mark = String("---\n")
            var b = mark.as_bytes()
            var k = 0
            while k < len(b):
                out.append(b[k])
                k += 1
        var one = encode_value(docs[i], options)
        var j = 0
        while j < len(one):
            out.append(one[j])
            j += 1
        i += 1
    return out^


def decode_all_values[
    origin: ImmOrigin
](
    buf: Span[Byte, origin], options: DecodeOptions = DecodeOptions.default
) raises DecodeError -> List[YamlValue]:
    var out = List[YamlValue]()
    if len(buf) == 0:
        return out^
    var dec = StreamDecoder[origin](buf, options)
    while True:
        var n = dec.next_value()
        if not n:
            break
        out.append(n.value().copy())
    return out^
