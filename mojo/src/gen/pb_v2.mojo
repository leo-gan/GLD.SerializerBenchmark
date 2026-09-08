from std.collections import Dict, List, Optional, Span
from protobuf import (
    DecodeError,
    ProtoMessage,
    UnknownFieldSet,
    WireReader,
    WireType,
    WireWriter,
    decode as pb_decode,
    encode as pb_encode,
    i32_to_u64,
    i64_to_u64,
    tag_fixed32_len,
    tag_fixed64_len,
    tag_len_len,
    tag_varint_len,
    u64_to_i32,
    u64_to_i64,
    varint_len,
    zigzag_decode_i32,
    zigzag_decode_i64,
    zigzag_encode_i32,
    zigzag_encode_i64,
)

struct Message(
    Copyable, Movable, Defaultable, Deinitable, Writable, Equatable, ProtoMessage
):
    var f_bool: Bool
    var f_int32: Int32
    var f_int64: Int64
    var f_float64: Float64
    var f_string: String
    var f_bool_2: Bool
    var f_int32_2: Int32
    var f_string_2: String
    var unknown: UnknownFieldSet

    def __init__(out self):
        self.f_bool = False
        self.f_int32 = Int32(0)
        self.f_int64 = Int64(0)
        self.f_float64 = 0.0
        self.f_string = String()
        self.f_bool_2 = False
        self.f_int32_2 = Int32(0)
        self.f_string_2 = String()
        self.unknown = UnknownFieldSet()

    def encoded_len(self) -> Int:
        var n = 0
        if self.f_bool:
            n += tag_varint_len(1, UInt64(Int(self.f_bool)))
        if self.f_int32 != 0:
            n += tag_varint_len(2, i32_to_u64(self.f_int32))
        if self.f_int64 != 0:
            n += tag_varint_len(3, i64_to_u64(self.f_int64))
        if self.f_float64 != 0.0:
            n += tag_fixed64_len(4)
        if self.f_string.byte_length() != 0:
            n += tag_len_len(5, self.f_string.byte_length())
        if self.f_bool_2:
            n += tag_varint_len(6, UInt64(Int(self.f_bool_2)))
        if self.f_int32_2 != 0:
            n += tag_varint_len(7, i32_to_u64(self.f_int32_2))
        if self.f_string_2.byte_length() != 0:
            n += tag_len_len(8, self.f_string_2.byte_length())
        n += self.unknown.encoded_len()
        return n

    def encode_to(self, mut enc: WireWriter):
        if self.f_bool:
            enc.write_tag(1, WireType.VARINT)
            enc.write_varint(UInt64(Int(self.f_bool)))
        if self.f_int32 != 0:
            enc.write_tag(2, WireType.VARINT)
            enc.write_varint(i32_to_u64(self.f_int32))
        if self.f_int64 != 0:
            enc.write_tag(3, WireType.VARINT)
            enc.write_varint(i64_to_u64(self.f_int64))
        if self.f_float64 != 0.0:
            enc.write_tag(4, WireType.I64)
            enc.write_i64_le(UInt64(self.f_float64.to_bits()))
        if self.f_string.byte_length() != 0:
            enc.write_len_header(5, self.f_string.byte_length())
            enc.write_bytes(self.f_string.as_bytes())
        if self.f_bool_2:
            enc.write_tag(6, WireType.VARINT)
            enc.write_varint(UInt64(Int(self.f_bool_2)))
        if self.f_int32_2 != 0:
            enc.write_tag(7, WireType.VARINT)
            enc.write_varint(i32_to_u64(self.f_int32_2))
        if self.f_string_2.byte_length() != 0:
            enc.write_len_header(8, self.f_string_2.byte_length())
            enc.write_bytes(self.f_string_2.as_bytes())
        self.unknown.encode_to(enc)

    def merge_from[origin: ImmOrigin](mut self, mut dec: WireReader[origin]) raises DecodeError:
        while dec.remaining() > 0:
            var tag = dec.read_tag()
            var field = tag[0]
            var wire = tag[1]
            if field == 1 and wire == WireType.VARINT:
                self.f_bool = dec.read_varint() != 0
            elif field == 2 and wire == WireType.VARINT:
                self.f_int32 = u64_to_i32(dec.read_varint())
            elif field == 3 and wire == WireType.VARINT:
                self.f_int64 = u64_to_i64(dec.read_varint())
            elif field == 4 and wire == WireType.I64:
                self.f_float64 = Float64(from_bits=dec.read_i64_le())
            elif field == 5 and wire == WireType.LEN:
                self.f_string = dec.read_string()
            elif field == 6 and wire == WireType.VARINT:
                self.f_bool_2 = dec.read_varint() != 0
            elif field == 7 and wire == WireType.VARINT:
                self.f_int32_2 = u64_to_i32(dec.read_varint())
            elif field == 8 and wire == WireType.LEN:
                self.f_string_2 = dec.read_string()
            else:
                self.unknown.add(field, wire, dec)

    def encode(self) -> List[Byte]:
        return pb_encode(self)

    @staticmethod
    def decode[origin: ImmOrigin](buf: Span[Byte, origin]) raises DecodeError -> Self:
        return pb_decode[Self, origin](buf)

    def __eq__(self, other: Self) -> Bool:
        if self.f_bool != other.f_bool:
            return False
        if self.f_int32 != other.f_int32:
            return False
        if self.f_int64 != other.f_int64:
            return False
        if self.f_float64 != other.f_float64:
            return False
        if self.f_string != other.f_string:
            return False
        if self.f_bool_2 != other.f_bool_2:
            return False
        if self.f_int32_2 != other.f_int32_2:
            return False
        if self.f_string_2 != other.f_string_2:
            return False
        if self.unknown != other.unknown:
            return False
        return True

    def write_to[W: Writer](self, mut writer: W):
        writer.write("Message()")

struct BatchMessage(
    Copyable, Movable, Defaultable, Deinitable, Writable, Equatable, ProtoMessage
):
    var items: List[Message]
    var unknown: UnknownFieldSet

    def __init__(out self):
        self.items = List[Message]()
        self.unknown = UnknownFieldSet()

    def encoded_len(self) -> Int:
        var n = 0
        for i in range(len(self.items)):
            n += tag_len_len(1, self.items[i].encoded_len())
        n += self.unknown.encoded_len()
        return n

    def encode_to(self, mut enc: WireWriter):
        for i in range(len(self.items)):
            enc.write_len_header(1, self.items[i].encoded_len())
            self.items[i].encode_to(enc)
        self.unknown.encode_to(enc)

    def merge_from[origin: ImmOrigin](mut self, mut dec: WireReader[origin]) raises DecodeError:
        while dec.remaining() > 0:
            var tag = dec.read_tag()
            var field = tag[0]
            var wire = tag[1]
            if field == 1 and wire == WireType.LEN:
                var inner = dec.subreader(dec.read_len_span())
                var item = Message()
                item.merge_from(inner)
                self.items.append(item^)
            else:
                self.unknown.add(field, wire, dec)

    def encode(self) -> List[Byte]:
        return pb_encode(self)

    @staticmethod
    def decode[origin: ImmOrigin](buf: Span[Byte, origin]) raises DecodeError -> Self:
        return pb_decode[Self, origin](buf)

    def __eq__(self, other: Self) -> Bool:
        if len(self.items) != len(other.items):
            return False
        for i in range(len(self.items)):
            if self.items[i] != other.items[i]:
                return False
        if self.unknown != other.unknown:
            return False
        return True

    def write_to[W: Writer](self, mut writer: W):
        writer.write("BatchMessage()")

struct DocumentMeta(
    Copyable, Movable, Defaultable, Deinitable, Writable, Equatable, ProtoMessage
):
    var region: String
    var version: Int32
    var unknown: UnknownFieldSet

    def __init__(out self):
        self.region = String()
        self.version = Int32(0)
        self.unknown = UnknownFieldSet()

    def encoded_len(self) -> Int:
        var n = 0
        if self.region.byte_length() != 0:
            n += tag_len_len(1, self.region.byte_length())
        if self.version != 0:
            n += tag_varint_len(2, i32_to_u64(self.version))
        n += self.unknown.encoded_len()
        return n

    def encode_to(self, mut enc: WireWriter):
        if self.region.byte_length() != 0:
            enc.write_len_header(1, self.region.byte_length())
            enc.write_bytes(self.region.as_bytes())
        if self.version != 0:
            enc.write_tag(2, WireType.VARINT)
            enc.write_varint(i32_to_u64(self.version))
        self.unknown.encode_to(enc)

    def merge_from[origin: ImmOrigin](mut self, mut dec: WireReader[origin]) raises DecodeError:
        while dec.remaining() > 0:
            var tag = dec.read_tag()
            var field = tag[0]
            var wire = tag[1]
            if field == 1 and wire == WireType.LEN:
                self.region = dec.read_string()
            elif field == 2 and wire == WireType.VARINT:
                self.version = u64_to_i32(dec.read_varint())
            else:
                self.unknown.add(field, wire, dec)

    def encode(self) -> List[Byte]:
        return pb_encode(self)

    @staticmethod
    def decode[origin: ImmOrigin](buf: Span[Byte, origin]) raises DecodeError -> Self:
        return pb_decode[Self, origin](buf)

    def __eq__(self, other: Self) -> Bool:
        if self.region != other.region:
            return False
        if self.version != other.version:
            return False
        if self.unknown != other.unknown:
            return False
        return True

    def write_to[W: Writer](self, mut writer: W):
        writer.write("DocumentMeta()")

struct DocumentItem(
    Copyable, Movable, Defaultable, Deinitable, Writable, Equatable, ProtoMessage
):
    var sku: String
    var qty: Int32
    var price_minor: Int64
    var unknown: UnknownFieldSet

    def __init__(out self):
        self.sku = String()
        self.qty = Int32(0)
        self.price_minor = Int64(0)
        self.unknown = UnknownFieldSet()

    def encoded_len(self) -> Int:
        var n = 0
        if self.sku.byte_length() != 0:
            n += tag_len_len(1, self.sku.byte_length())
        if self.qty != 0:
            n += tag_varint_len(2, i32_to_u64(self.qty))
        if self.price_minor != 0:
            n += tag_varint_len(3, i64_to_u64(self.price_minor))
        n += self.unknown.encoded_len()
        return n

    def encode_to(self, mut enc: WireWriter):
        if self.sku.byte_length() != 0:
            enc.write_len_header(1, self.sku.byte_length())
            enc.write_bytes(self.sku.as_bytes())
        if self.qty != 0:
            enc.write_tag(2, WireType.VARINT)
            enc.write_varint(i32_to_u64(self.qty))
        if self.price_minor != 0:
            enc.write_tag(3, WireType.VARINT)
            enc.write_varint(i64_to_u64(self.price_minor))
        self.unknown.encode_to(enc)

    def merge_from[origin: ImmOrigin](mut self, mut dec: WireReader[origin]) raises DecodeError:
        while dec.remaining() > 0:
            var tag = dec.read_tag()
            var field = tag[0]
            var wire = tag[1]
            if field == 1 and wire == WireType.LEN:
                self.sku = dec.read_string()
            elif field == 2 and wire == WireType.VARINT:
                self.qty = u64_to_i32(dec.read_varint())
            elif field == 3 and wire == WireType.VARINT:
                self.price_minor = u64_to_i64(dec.read_varint())
            else:
                self.unknown.add(field, wire, dec)

    def encode(self) -> List[Byte]:
        return pb_encode(self)

    @staticmethod
    def decode[origin: ImmOrigin](buf: Span[Byte, origin]) raises DecodeError -> Self:
        return pb_decode[Self, origin](buf)

    def __eq__(self, other: Self) -> Bool:
        if self.sku != other.sku:
            return False
        if self.qty != other.qty:
            return False
        if self.price_minor != other.price_minor:
            return False
        if self.unknown != other.unknown:
            return False
        return True

    def write_to[W: Writer](self, mut writer: W):
        writer.write("DocumentItem()")

struct Document(
    Copyable, Movable, Defaultable, Deinitable, Writable, Equatable, ProtoMessage
):
    var id: String
    var status: Int32
    var meta: Optional[DocumentMeta]
    var items: List[DocumentItem]
    var unknown: UnknownFieldSet

    def __init__(out self):
        self.id = String()
        self.status = Int32(0)
        self.meta = None
        self.items = List[DocumentItem]()
        self.unknown = UnknownFieldSet()

    def encoded_len(self) -> Int:
        var n = 0
        if self.id.byte_length() != 0:
            n += tag_len_len(1, self.id.byte_length())
        if self.status != 0:
            n += tag_varint_len(2, i32_to_u64(self.status))
        if self.meta:
            n += tag_len_len(3, self.meta.value().encoded_len())
        for i in range(len(self.items)):
            n += tag_len_len(4, self.items[i].encoded_len())
        n += self.unknown.encoded_len()
        return n

    def encode_to(self, mut enc: WireWriter):
        if self.id.byte_length() != 0:
            enc.write_len_header(1, self.id.byte_length())
            enc.write_bytes(self.id.as_bytes())
        if self.status != 0:
            enc.write_tag(2, WireType.VARINT)
            enc.write_varint(i32_to_u64(self.status))
        if self.meta:
            ref child = self.meta.value()
            enc.write_len_header(3, child.encoded_len())
            child.encode_to(enc)
        for i in range(len(self.items)):
            enc.write_len_header(4, self.items[i].encoded_len())
            self.items[i].encode_to(enc)
        self.unknown.encode_to(enc)

    def merge_from[origin: ImmOrigin](mut self, mut dec: WireReader[origin]) raises DecodeError:
        while dec.remaining() > 0:
            var tag = dec.read_tag()
            var field = tag[0]
            var wire = tag[1]
            if field == 1 and wire == WireType.LEN:
                self.id = dec.read_string()
            elif field == 2 and wire == WireType.VARINT:
                self.status = u64_to_i32(dec.read_varint())
            elif field == 3 and wire == WireType.LEN:
                var inner = dec.subreader(dec.read_len_span())
                if not self.meta:
                    self.meta = DocumentMeta()
                self.meta.value().merge_from(inner)
            elif field == 4 and wire == WireType.LEN:
                var inner = dec.subreader(dec.read_len_span())
                var item = DocumentItem()
                item.merge_from(inner)
                self.items.append(item^)
            else:
                self.unknown.add(field, wire, dec)

    def encode(self) -> List[Byte]:
        return pb_encode(self)

    @staticmethod
    def decode[origin: ImmOrigin](buf: Span[Byte, origin]) raises DecodeError -> Self:
        return pb_decode[Self, origin](buf)

    def __eq__(self, other: Self) -> Bool:
        if self.id != other.id:
            return False
        if self.status != other.status:
            return False
        if Bool(self.meta) != Bool(other.meta):
            return False
        if self.meta:
            if self.meta.value() != other.meta.value():
                return False
        if len(self.items) != len(other.items):
            return False
        for i in range(len(self.items)):
            if self.items[i] != other.items[i]:
                return False
        if self.unknown != other.unknown:
            return False
        return True

    def write_to[W: Writer](self, mut writer: W):
        writer.write("Document()")

struct BatchDocument(
    Copyable, Movable, Defaultable, Deinitable, Writable, Equatable, ProtoMessage
):
    var items: List[Document]
    var unknown: UnknownFieldSet

    def __init__(out self):
        self.items = List[Document]()
        self.unknown = UnknownFieldSet()

    def encoded_len(self) -> Int:
        var n = 0
        for i in range(len(self.items)):
            n += tag_len_len(1, self.items[i].encoded_len())
        n += self.unknown.encoded_len()
        return n

    def encode_to(self, mut enc: WireWriter):
        for i in range(len(self.items)):
            enc.write_len_header(1, self.items[i].encoded_len())
            self.items[i].encode_to(enc)
        self.unknown.encode_to(enc)

    def merge_from[origin: ImmOrigin](mut self, mut dec: WireReader[origin]) raises DecodeError:
        while dec.remaining() > 0:
            var tag = dec.read_tag()
            var field = tag[0]
            var wire = tag[1]
            if field == 1 and wire == WireType.LEN:
                var inner = dec.subreader(dec.read_len_span())
                var item = Document()
                item.merge_from(inner)
                self.items.append(item^)
            else:
                self.unknown.add(field, wire, dec)

    def encode(self) -> List[Byte]:
        return pb_encode(self)

    @staticmethod
    def decode[origin: ImmOrigin](buf: Span[Byte, origin]) raises DecodeError -> Self:
        return pb_decode[Self, origin](buf)

    def __eq__(self, other: Self) -> Bool:
        if len(self.items) != len(other.items):
            return False
        for i in range(len(self.items)):
            if self.items[i] != other.items[i]:
                return False
        if self.unknown != other.unknown:
            return False
        return True

    def write_to[W: Writer](self, mut writer: W):
        writer.write("BatchDocument()")

struct Telemetry(
    Copyable, Movable, Defaultable, Deinitable, Writable, Equatable, ProtoMessage
):
    var source: String
    var ts: Int64
    var tags: List[String]
    var values: List[Float64]
    var unknown: UnknownFieldSet

    def __init__(out self):
        self.source = String()
        self.ts = Int64(0)
        self.tags = List[String]()
        self.values = List[Float64]()
        self.unknown = UnknownFieldSet()

    def encoded_len(self) -> Int:
        var n = 0
        if self.source.byte_length() != 0:
            n += tag_len_len(1, self.source.byte_length())
        if self.ts != 0:
            n += tag_varint_len(2, i64_to_u64(self.ts))
        for i in range(len(self.tags)):
            n += tag_len_len(3, self.tags[i].byte_length())
        if len(self.values) != 0:
            n += tag_len_len(4, len(self.values) * 8)
        n += self.unknown.encoded_len()
        return n

    def encode_to(self, mut enc: WireWriter):
        if self.source.byte_length() != 0:
            enc.write_len_header(1, self.source.byte_length())
            enc.write_bytes(self.source.as_bytes())
        if self.ts != 0:
            enc.write_tag(2, WireType.VARINT)
            enc.write_varint(i64_to_u64(self.ts))
        for i in range(len(self.tags)):
            enc.write_len_header(3, self.tags[i].byte_length())
            enc.write_bytes(self.tags[i].as_bytes())
        if len(self.values) != 0:
            enc.write_len_header(4, len(self.values) * 8)
            for i in range(len(self.values)):
                enc.write_i64_le(UInt64(self.values[i].to_bits()))
        self.unknown.encode_to(enc)

    def merge_from[origin: ImmOrigin](mut self, mut dec: WireReader[origin]) raises DecodeError:
        while dec.remaining() > 0:
            var tag = dec.read_tag()
            var field = tag[0]
            var wire = tag[1]
            if field == 1 and wire == WireType.LEN:
                self.source = dec.read_string()
            elif field == 2 and wire == WireType.VARINT:
                self.ts = u64_to_i64(dec.read_varint())
            elif field == 3 and wire == WireType.LEN:
                self.tags.append(dec.read_string())
            elif field == 4 and wire == WireType.I64:
                self.values.append(Float64(from_bits=dec.read_i64_le()))
            elif field == 4 and wire == WireType.LEN:
                var words = List[UInt64]()
                dec.read_packed_fixed64(words)
                for i in range(len(words)):
                    self.values.append(Float64(from_bits=words[i]))
            else:
                self.unknown.add(field, wire, dec)

    def encode(self) -> List[Byte]:
        return pb_encode(self)

    @staticmethod
    def decode[origin: ImmOrigin](buf: Span[Byte, origin]) raises DecodeError -> Self:
        return pb_decode[Self, origin](buf)

    def __eq__(self, other: Self) -> Bool:
        if self.source != other.source:
            return False
        if self.ts != other.ts:
            return False
        if len(self.tags) != len(other.tags):
            return False
        for i in range(len(self.tags)):
            if self.tags[i] != other.tags[i]:
                return False
        if len(self.values) != len(other.values):
            return False
        for i in range(len(self.values)):
            if self.values[i] != other.values[i]:
                return False
        if self.unknown != other.unknown:
            return False
        return True

    def write_to[W: Writer](self, mut writer: W):
        writer.write("Telemetry()")

struct BatchTelemetry(
    Copyable, Movable, Defaultable, Deinitable, Writable, Equatable, ProtoMessage
):
    var items: List[Telemetry]
    var unknown: UnknownFieldSet

    def __init__(out self):
        self.items = List[Telemetry]()
        self.unknown = UnknownFieldSet()

    def encoded_len(self) -> Int:
        var n = 0
        for i in range(len(self.items)):
            n += tag_len_len(1, self.items[i].encoded_len())
        n += self.unknown.encoded_len()
        return n

    def encode_to(self, mut enc: WireWriter):
        for i in range(len(self.items)):
            enc.write_len_header(1, self.items[i].encoded_len())
            self.items[i].encode_to(enc)
        self.unknown.encode_to(enc)

    def merge_from[origin: ImmOrigin](mut self, mut dec: WireReader[origin]) raises DecodeError:
        while dec.remaining() > 0:
            var tag = dec.read_tag()
            var field = tag[0]
            var wire = tag[1]
            if field == 1 and wire == WireType.LEN:
                var inner = dec.subreader(dec.read_len_span())
                var item = Telemetry()
                item.merge_from(inner)
                self.items.append(item^)
            else:
                self.unknown.add(field, wire, dec)

    def encode(self) -> List[Byte]:
        return pb_encode(self)

    @staticmethod
    def decode[origin: ImmOrigin](buf: Span[Byte, origin]) raises DecodeError -> Self:
        return pb_decode[Self, origin](buf)

    def __eq__(self, other: Self) -> Bool:
        if len(self.items) != len(other.items):
            return False
        for i in range(len(self.items)):
            if self.items[i] != other.items[i]:
                return False
        if self.unknown != other.unknown:
            return False
        return True

    def write_to[W: Writer](self, mut writer: W):
        writer.write("BatchTelemetry()")

struct Strings(
    Copyable, Movable, Defaultable, Deinitable, Writable, Equatable, ProtoMessage
):
    var items: List[String]
    var unknown: UnknownFieldSet

    def __init__(out self):
        self.items = List[String]()
        self.unknown = UnknownFieldSet()

    def encoded_len(self) -> Int:
        var n = 0
        for i in range(len(self.items)):
            n += tag_len_len(1, self.items[i].byte_length())
        n += self.unknown.encoded_len()
        return n

    def encode_to(self, mut enc: WireWriter):
        for i in range(len(self.items)):
            enc.write_len_header(1, self.items[i].byte_length())
            enc.write_bytes(self.items[i].as_bytes())
        self.unknown.encode_to(enc)

    def merge_from[origin: ImmOrigin](mut self, mut dec: WireReader[origin]) raises DecodeError:
        while dec.remaining() > 0:
            var tag = dec.read_tag()
            var field = tag[0]
            var wire = tag[1]
            if field == 1 and wire == WireType.LEN:
                self.items.append(dec.read_string())
            else:
                self.unknown.add(field, wire, dec)

    def encode(self) -> List[Byte]:
        return pb_encode(self)

    @staticmethod
    def decode[origin: ImmOrigin](buf: Span[Byte, origin]) raises DecodeError -> Self:
        return pb_decode[Self, origin](buf)

    def __eq__(self, other: Self) -> Bool:
        if len(self.items) != len(other.items):
            return False
        for i in range(len(self.items)):
            if self.items[i] != other.items[i]:
                return False
        if self.unknown != other.unknown:
            return False
        return True

    def write_to[W: Writer](self, mut writer: W):
        writer.write("Strings()")

struct BatchStrings(
    Copyable, Movable, Defaultable, Deinitable, Writable, Equatable, ProtoMessage
):
    var items: List[Strings]
    var unknown: UnknownFieldSet

    def __init__(out self):
        self.items = List[Strings]()
        self.unknown = UnknownFieldSet()

    def encoded_len(self) -> Int:
        var n = 0
        for i in range(len(self.items)):
            n += tag_len_len(1, self.items[i].encoded_len())
        n += self.unknown.encoded_len()
        return n

    def encode_to(self, mut enc: WireWriter):
        for i in range(len(self.items)):
            enc.write_len_header(1, self.items[i].encoded_len())
            self.items[i].encode_to(enc)
        self.unknown.encode_to(enc)

    def merge_from[origin: ImmOrigin](mut self, mut dec: WireReader[origin]) raises DecodeError:
        while dec.remaining() > 0:
            var tag = dec.read_tag()
            var field = tag[0]
            var wire = tag[1]
            if field == 1 and wire == WireType.LEN:
                var inner = dec.subreader(dec.read_len_span())
                var item = Strings()
                item.merge_from(inner)
                self.items.append(item^)
            else:
                self.unknown.add(field, wire, dec)

    def encode(self) -> List[Byte]:
        return pb_encode(self)

    @staticmethod
    def decode[origin: ImmOrigin](buf: Span[Byte, origin]) raises DecodeError -> Self:
        return pb_decode[Self, origin](buf)

    def __eq__(self, other: Self) -> Bool:
        if len(self.items) != len(other.items):
            return False
        for i in range(len(self.items)):
            if self.items[i] != other.items[i]:
                return False
        if self.unknown != other.unknown:
            return False
        return True

    def write_to[W: Writer](self, mut writer: W):
        writer.write("BatchStrings()")

struct EventAttr(
    Copyable, Movable, Defaultable, Deinitable, Writable, Equatable, ProtoMessage
):
    var key: String
    var value: String
    var unknown: UnknownFieldSet

    def __init__(out self):
        self.key = String()
        self.value = String()
        self.unknown = UnknownFieldSet()

    def encoded_len(self) -> Int:
        var n = 0
        if self.key.byte_length() != 0:
            n += tag_len_len(1, self.key.byte_length())
        if self.value.byte_length() != 0:
            n += tag_len_len(2, self.value.byte_length())
        n += self.unknown.encoded_len()
        return n

    def encode_to(self, mut enc: WireWriter):
        if self.key.byte_length() != 0:
            enc.write_len_header(1, self.key.byte_length())
            enc.write_bytes(self.key.as_bytes())
        if self.value.byte_length() != 0:
            enc.write_len_header(2, self.value.byte_length())
            enc.write_bytes(self.value.as_bytes())
        self.unknown.encode_to(enc)

    def merge_from[origin: ImmOrigin](mut self, mut dec: WireReader[origin]) raises DecodeError:
        while dec.remaining() > 0:
            var tag = dec.read_tag()
            var field = tag[0]
            var wire = tag[1]
            if field == 1 and wire == WireType.LEN:
                self.key = dec.read_string()
            elif field == 2 and wire == WireType.LEN:
                self.value = dec.read_string()
            else:
                self.unknown.add(field, wire, dec)

    def encode(self) -> List[Byte]:
        return pb_encode(self)

    @staticmethod
    def decode[origin: ImmOrigin](buf: Span[Byte, origin]) raises DecodeError -> Self:
        return pb_decode[Self, origin](buf)

    def __eq__(self, other: Self) -> Bool:
        if self.key != other.key:
            return False
        if self.value != other.value:
            return False
        if self.unknown != other.unknown:
            return False
        return True

    def write_to[W: Writer](self, mut writer: W):
        writer.write("EventAttr()")

struct Event(
    Copyable, Movable, Defaultable, Deinitable, Writable, Equatable, ProtoMessage
):
    var event_id: String
    var event_type: String
    var occurred_at: Int64
    var producer: String
    var attrs: List[EventAttr]
    var unknown: UnknownFieldSet

    def __init__(out self):
        self.event_id = String()
        self.event_type = String()
        self.occurred_at = Int64(0)
        self.producer = String()
        self.attrs = List[EventAttr]()
        self.unknown = UnknownFieldSet()

    def encoded_len(self) -> Int:
        var n = 0
        if self.event_id.byte_length() != 0:
            n += tag_len_len(1, self.event_id.byte_length())
        if self.event_type.byte_length() != 0:
            n += tag_len_len(2, self.event_type.byte_length())
        if self.occurred_at != 0:
            n += tag_varint_len(3, i64_to_u64(self.occurred_at))
        if self.producer.byte_length() != 0:
            n += tag_len_len(4, self.producer.byte_length())
        for i in range(len(self.attrs)):
            n += tag_len_len(5, self.attrs[i].encoded_len())
        n += self.unknown.encoded_len()
        return n

    def encode_to(self, mut enc: WireWriter):
        if self.event_id.byte_length() != 0:
            enc.write_len_header(1, self.event_id.byte_length())
            enc.write_bytes(self.event_id.as_bytes())
        if self.event_type.byte_length() != 0:
            enc.write_len_header(2, self.event_type.byte_length())
            enc.write_bytes(self.event_type.as_bytes())
        if self.occurred_at != 0:
            enc.write_tag(3, WireType.VARINT)
            enc.write_varint(i64_to_u64(self.occurred_at))
        if self.producer.byte_length() != 0:
            enc.write_len_header(4, self.producer.byte_length())
            enc.write_bytes(self.producer.as_bytes())
        for i in range(len(self.attrs)):
            enc.write_len_header(5, self.attrs[i].encoded_len())
            self.attrs[i].encode_to(enc)
        self.unknown.encode_to(enc)

    def merge_from[origin: ImmOrigin](mut self, mut dec: WireReader[origin]) raises DecodeError:
        while dec.remaining() > 0:
            var tag = dec.read_tag()
            var field = tag[0]
            var wire = tag[1]
            if field == 1 and wire == WireType.LEN:
                self.event_id = dec.read_string()
            elif field == 2 and wire == WireType.LEN:
                self.event_type = dec.read_string()
            elif field == 3 and wire == WireType.VARINT:
                self.occurred_at = u64_to_i64(dec.read_varint())
            elif field == 4 and wire == WireType.LEN:
                self.producer = dec.read_string()
            elif field == 5 and wire == WireType.LEN:
                var inner = dec.subreader(dec.read_len_span())
                var item = EventAttr()
                item.merge_from(inner)
                self.attrs.append(item^)
            else:
                self.unknown.add(field, wire, dec)

    def encode(self) -> List[Byte]:
        return pb_encode(self)

    @staticmethod
    def decode[origin: ImmOrigin](buf: Span[Byte, origin]) raises DecodeError -> Self:
        return pb_decode[Self, origin](buf)

    def __eq__(self, other: Self) -> Bool:
        if self.event_id != other.event_id:
            return False
        if self.event_type != other.event_type:
            return False
        if self.occurred_at != other.occurred_at:
            return False
        if self.producer != other.producer:
            return False
        if len(self.attrs) != len(other.attrs):
            return False
        for i in range(len(self.attrs)):
            if self.attrs[i] != other.attrs[i]:
                return False
        if self.unknown != other.unknown:
            return False
        return True

    def write_to[W: Writer](self, mut writer: W):
        writer.write("Event()")

struct BatchEvent(
    Copyable, Movable, Defaultable, Deinitable, Writable, Equatable, ProtoMessage
):
    var items: List[Event]
    var unknown: UnknownFieldSet

    def __init__(out self):
        self.items = List[Event]()
        self.unknown = UnknownFieldSet()

    def encoded_len(self) -> Int:
        var n = 0
        for i in range(len(self.items)):
            n += tag_len_len(1, self.items[i].encoded_len())
        n += self.unknown.encoded_len()
        return n

    def encode_to(self, mut enc: WireWriter):
        for i in range(len(self.items)):
            enc.write_len_header(1, self.items[i].encoded_len())
            self.items[i].encode_to(enc)
        self.unknown.encode_to(enc)

    def merge_from[origin: ImmOrigin](mut self, mut dec: WireReader[origin]) raises DecodeError:
        while dec.remaining() > 0:
            var tag = dec.read_tag()
            var field = tag[0]
            var wire = tag[1]
            if field == 1 and wire == WireType.LEN:
                var inner = dec.subreader(dec.read_len_span())
                var item = Event()
                item.merge_from(inner)
                self.items.append(item^)
            else:
                self.unknown.add(field, wire, dec)

    def encode(self) -> List[Byte]:
        return pb_encode(self)

    @staticmethod
    def decode[origin: ImmOrigin](buf: Span[Byte, origin]) raises DecodeError -> Self:
        return pb_decode[Self, origin](buf)

    def __eq__(self, other: Self) -> Bool:
        if len(self.items) != len(other.items):
            return False
        for i in range(len(self.items)):
            if self.items[i] != other.items[i]:
                return False
        if self.unknown != other.unknown:
            return False
        return True

    def write_to[W: Writer](self, mut writer: W):
        writer.write("BatchEvent()")

