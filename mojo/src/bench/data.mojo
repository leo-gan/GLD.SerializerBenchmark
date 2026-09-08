"""Data Model v2 fixtures, PRNG, and fidelity.

Generators are deterministic within Mojo. They are not bit-identical across
languages. RNG is xorshift64* with the same golden-ratio mix as Python.
"""

from std.collections import List
from cbor import (
    CborDatum,
    DecodeError as CborDecodeError,
    EncodeOptions,
    WireReader as CborReader,
    WireWriter as CborWriter,
)
from avro import AvroDatum, DecodeError as AvroDecodeError, WireReader as AvroReader, WireWriter as AvroWriter

comptime BASE_TS_MS: Int64 = 1_704_067_200_000
comptime GOLDEN: UInt64 = 0x9E3779B97F4A7C15
comptime FNV: UInt64 = 0x100000001B3


struct Rng(Copyable, Movable):
    var state: UInt64

    def __init__(out self, seed: UInt64):
        var s = seed
        if s == UInt64(0):
            s = GOLDEN
        self.state = s

    def next_u64(mut self) -> UInt64:
        var x = self.state
        x ^= (x << UInt64(13))
        x ^= x >> UInt64(7)
        x ^= (x << UInt64(17))
        self.state = x
        return x

    def next_int(mut self, lo: Int, hi: Int) -> Int:
        if hi <= lo:
            return lo
        var span = hi - lo + 1
        return lo + Int(self.next_u64() % UInt64(span))

    def next_bool(mut self) -> Bool:
        return (self.next_u64() & UInt64(1)) == UInt64(1)

    def next_f64(mut self) -> Float64:
        return Float64(self.next_u64() >> UInt64(11)) * (1.0 / Float64(UInt64(1) << UInt64(53)))

    def word(mut self, min_len: Int, max_len: Int) -> String:
        var n = self.next_int(min_len, max_len)
        var out = String()
        var i = 0
        while i < n:
            var idx = Int(self.next_u64() % UInt64(26))
            out += String(chr(ord("a") + idx))
            i += 1
        return out^


def mix_seed(seed: UInt64, type_id: String, idx: Int) -> UInt64:
    var h = seed
    var b = type_id.as_bytes()
    var i = 0
    while i < len(b):
        h = (h ^ UInt64(Int(b[i]))) * FNV
        i += 1
    h ^= UInt64(idx) * GOLDEN
    if h == UInt64(0):
        return UInt64(1)
    return h


@fieldwise_init
struct Message(Copyable, Movable, Defaultable, CborDatum, AvroDatum):
    var f_bool: Bool
    var f_int32: Int32
    var f_int64: Int64
    var f_float64: Float64
    var f_string: String
    var f_bool_2: Bool
    var f_int32_2: Int32
    var f_string_2: String

    def __init__(out self):
        self.f_bool = False
        self.f_int32 = 0
        self.f_int64 = 0
        self.f_float64 = 0.0
        self.f_string = ""
        self.f_bool_2 = False
        self.f_int32_2 = 0
        self.f_string_2 = ""

    def schema_json(self) -> String:
        return "{\"type\":\"record\",\"name\":\"Message\"}"

    def encoded_len(self, options: EncodeOptions) -> Int:
        return 256 + self.f_string.byte_length() + self.f_string_2.byte_length()

    def encode_to(self, mut w: CborWriter, options: EncodeOptions):
        w.write_map_len(8)
        w.write_tstr("f_bool")
        w.write_bool(self.f_bool)
        w.write_tstr("f_int32")
        w.write_int(Int64(self.f_int32))
        w.write_tstr("f_int64")
        w.write_int(self.f_int64)
        w.write_tstr("f_float64")
        w.write_float_preferred(self.f_float64)
        w.write_tstr("f_string")
        w.write_tstr(self.f_string)
        w.write_tstr("f_bool_2")
        w.write_bool(self.f_bool_2)
        w.write_tstr("f_int32_2")
        w.write_int(Int64(self.f_int32_2))
        w.write_tstr("f_string_2")
        w.write_tstr(self.f_string_2)

    def decode_from[origin: ImmOrigin](mut self, mut r: CborReader[origin]) raises CborDecodeError:
        var n = r.read_map_len()
        var i = 0
        while i < n:
            var key = r.read_tstr()
            if key == "f_bool":
                self.f_bool = r.read_bool()
            elif key == "f_int32":
                self.f_int32 = Int32(r.read_int64())
            elif key == "f_int64":
                self.f_int64 = r.read_int64()
            elif key == "f_float64":
                self.f_float64 = r.read_float64()
            elif key == "f_string":
                self.f_string = r.read_tstr()
            elif key == "f_bool_2":
                self.f_bool_2 = r.read_bool()
            elif key == "f_int32_2":
                self.f_int32_2 = Int32(r.read_int64())
            elif key == "f_string_2":
                self.f_string_2 = r.read_tstr()
            else:
                _ = r.read_int64()
            i += 1

    def encoded_len(self) -> Int:
        return 64 + self.f_string.byte_length() + self.f_string_2.byte_length()

    def encode_to(self, mut enc: AvroWriter):
        enc.write_bool(self.f_bool)
        enc.write_int(self.f_int32)
        enc.write_long(self.f_int64)
        enc.write_double(self.f_float64)
        enc.write_string(self.f_string)
        enc.write_bool(self.f_bool_2)
        enc.write_int(self.f_int32_2)
        enc.write_string(self.f_string_2)

    def decode_from[origin: ImmOrigin](mut self, mut dec: AvroReader[origin]) raises AvroDecodeError:
        self.f_bool = dec.read_bool()
        self.f_int32 = dec.read_int()
        self.f_int64 = dec.read_long()
        self.f_float64 = dec.read_double()
        self.f_string = dec.read_string()
        self.f_bool_2 = dec.read_bool()
        self.f_int32_2 = dec.read_int()
        self.f_string_2 = dec.read_string()


@fieldwise_init
struct DocumentMeta(Copyable, Movable, Defaultable, CborDatum, AvroDatum):
    var region: String
    var version: Int32

    def __init__(out self):
        self.region = ""
        self.version = 0

    def schema_json(self) -> String:
        return "{\"type\":\"record\",\"name\":\"DocumentMeta\"}"

    def encoded_len(self, options: EncodeOptions) -> Int:
        return 64 + self.region.byte_length()

    def encode_to(self, mut w: CborWriter, options: EncodeOptions):
        w.write_map_len(2)
        w.write_tstr("region")
        w.write_tstr(self.region)
        w.write_tstr("version")
        w.write_int(Int64(self.version))

    def decode_from[origin: ImmOrigin](mut self, mut r: CborReader[origin]) raises CborDecodeError:
        var n = r.read_map_len()
        var i = 0
        while i < n:
            var key = r.read_tstr()
            if key == "region":
                self.region = r.read_tstr()
            elif key == "version":
                self.version = Int32(r.read_int64())
            else:
                _ = r.read_int64()
            i += 1

    def encoded_len(self) -> Int:
        return 16 + self.region.byte_length()

    def encode_to(self, mut enc: AvroWriter):
        enc.write_string(self.region)
        enc.write_int(self.version)

    def decode_from[origin: ImmOrigin](mut self, mut dec: AvroReader[origin]) raises AvroDecodeError:
        self.region = dec.read_string()
        self.version = dec.read_int()


@fieldwise_init
struct DocumentItem(Copyable, Movable, Defaultable, CborDatum, AvroDatum):
    var sku: String
    var qty: Int32
    var price_minor: Int64

    def __init__(out self):
        self.sku = ""
        self.qty = 0
        self.price_minor = 0

    def schema_json(self) -> String:
        return "{\"type\":\"record\",\"name\":\"DocumentItem\"}"

    def encoded_len(self, options: EncodeOptions) -> Int:
        return 64 + self.sku.byte_length()

    def encode_to(self, mut w: CborWriter, options: EncodeOptions):
        w.write_map_len(3)
        w.write_tstr("sku")
        w.write_tstr(self.sku)
        w.write_tstr("qty")
        w.write_int(Int64(self.qty))
        w.write_tstr("price_minor")
        w.write_int(self.price_minor)

    def decode_from[origin: ImmOrigin](mut self, mut r: CborReader[origin]) raises CborDecodeError:
        var n = r.read_map_len()
        var i = 0
        while i < n:
            var key = r.read_tstr()
            if key == "sku":
                self.sku = r.read_tstr()
            elif key == "qty":
                self.qty = Int32(r.read_int64())
            elif key == "price_minor":
                self.price_minor = r.read_int64()
            else:
                _ = r.read_int64()
            i += 1

    def encoded_len(self) -> Int:
        return 24 + self.sku.byte_length()

    def encode_to(self, mut enc: AvroWriter):
        enc.write_string(self.sku)
        enc.write_int(self.qty)
        enc.write_long(self.price_minor)

    def decode_from[origin: ImmOrigin](mut self, mut dec: AvroReader[origin]) raises AvroDecodeError:
        self.sku = dec.read_string()
        self.qty = dec.read_int()
        self.price_minor = dec.read_long()


@fieldwise_init
struct Document(Copyable, Movable, Defaultable, CborDatum, AvroDatum):
    var id: String
    var status: Int32
    var meta: DocumentMeta
    var items: List[DocumentItem]

    def __init__(out self):
        self.id = ""
        self.status = 0
        self.meta = DocumentMeta()
        self.items = List[DocumentItem]()

    def schema_json(self) -> String:
        return "{\"type\":\"record\",\"name\":\"Document\"}"

    def encoded_len(self, options: EncodeOptions) -> Int:
        var n = 128 + self.id.byte_length() + self.meta.encoded_len(options)
        var i = 0
        while i < len(self.items):
            n += self.items[i].encoded_len(options)
            i += 1
        return n

    def encode_to(self, mut w: CborWriter, options: EncodeOptions):
        w.write_map_len(4)
        w.write_tstr("id")
        w.write_tstr(self.id)
        w.write_tstr("status")
        w.write_int(Int64(self.status))
        w.write_tstr("meta")
        self.meta.encode_to(w, options)
        w.write_tstr("items")
        w.write_array_len(len(self.items))
        var i = 0
        while i < len(self.items):
            self.items[i].encode_to(w, options)
            i += 1

    def decode_from[origin: ImmOrigin](mut self, mut r: CborReader[origin]) raises CborDecodeError:
        var n = r.read_map_len()
        var i = 0
        while i < n:
            var key = r.read_tstr()
            if key == "id":
                self.id = r.read_tstr()
            elif key == "status":
                self.status = Int32(r.read_int64())
            elif key == "meta":
                self.meta.decode_from(r)
            elif key == "items":
                var count = r.read_array_len()
                self.items = List[DocumentItem]()
                var j = 0
                while j < count:
                    var it = DocumentItem()
                    it.decode_from(r)
                    self.items.append(it^)
                    j += 1
            else:
                _ = r.read_int64()
            i += 1

    def encoded_len(self) -> Int:
        var n = 32 + self.id.byte_length() + self.meta.encoded_len()
        var i = 0
        while i < len(self.items):
            n += self.items[i].encoded_len()
            i += 1
        return n + 16

    def encode_to(self, mut enc: AvroWriter):
        enc.write_string(self.id)
        enc.write_int(self.status)
        self.meta.encode_to(enc)
        enc.write_block_start(Int64(len(self.items)))
        var i = 0
        while i < len(self.items):
            self.items[i].encode_to(enc)
            i += 1
        enc.write_block_end()

    def decode_from[origin: ImmOrigin](mut self, mut dec: AvroReader[origin]) raises AvroDecodeError:
        self.id = dec.read_string()
        self.status = dec.read_int()
        self.meta.decode_from(dec)
        self.items = List[DocumentItem]()
        while True:
            var count = Int(dec.read_long())
            if count == 0:
                break
            if count < 0:
                count = -count
                _ = dec.read_long()
            var j = 0
            while j < count:
                var it = DocumentItem()
                it.decode_from(dec)
                self.items.append(it^)
                j += 1


@fieldwise_init
struct Telemetry(Copyable, Movable, Defaultable, CborDatum, AvroDatum):
    var source: String
    var ts: Int64
    var tags: List[String]
    var values: List[Float64]

    def __init__(out self):
        self.source = ""
        self.ts = 0
        self.tags = List[String]()
        self.values = List[Float64]()

    def schema_json(self) -> String:
        return "{\"type\":\"record\",\"name\":\"Telemetry\"}"

    def encoded_len(self, options: EncodeOptions) -> Int:
        var n = 64 + self.source.byte_length()
        var i = 0
        while i < len(self.tags):
            n += 8 + self.tags[i].byte_length()
            i += 1
        n += 16 * len(self.values)
        return n

    def encode_to(self, mut w: CborWriter, options: EncodeOptions):
        w.write_map_len(4)
        w.write_tstr("source")
        w.write_tstr(self.source)
        w.write_tstr("ts")
        w.write_int(self.ts)
        w.write_tstr("tags")
        w.write_array_len(len(self.tags))
        var i = 0
        while i < len(self.tags):
            w.write_tstr(self.tags[i])
            i += 1
        w.write_tstr("values")
        w.write_array_len(len(self.values))
        i = 0
        while i < len(self.values):
            w.write_float_preferred(self.values[i])
            i += 1

    def decode_from[origin: ImmOrigin](mut self, mut r: CborReader[origin]) raises CborDecodeError:
        var n = r.read_map_len()
        var i = 0
        while i < n:
            var key = r.read_tstr()
            if key == "source":
                self.source = r.read_tstr()
            elif key == "ts":
                self.ts = r.read_int64()
            elif key == "tags":
                var count = r.read_array_len()
                self.tags = List[String]()
                var j = 0
                while j < count:
                    self.tags.append(r.read_tstr())
                    j += 1
            elif key == "values":
                var count = r.read_array_len()
                self.values = List[Float64]()
                var j = 0
                while j < count:
                    self.values.append(r.read_float64())
                    j += 1
            else:
                _ = r.read_int64()
            i += 1

    def encoded_len(self) -> Int:
        var n = 32 + self.source.byte_length()
        var i = 0
        while i < len(self.tags):
            n += 8 + self.tags[i].byte_length()
            i += 1
        return n + 12 * len(self.values)

    def encode_to(self, mut enc: AvroWriter):
        enc.write_string(self.source)
        enc.write_long(self.ts)
        enc.write_block_start(Int64(len(self.tags)))
        var i = 0
        while i < len(self.tags):
            enc.write_string(self.tags[i])
            i += 1
        enc.write_block_end()
        enc.write_block_start(Int64(len(self.values)))
        i = 0
        while i < len(self.values):
            enc.write_double(self.values[i])
            i += 1
        enc.write_block_end()

    def decode_from[origin: ImmOrigin](mut self, mut dec: AvroReader[origin]) raises AvroDecodeError:
        self.source = dec.read_string()
        self.ts = dec.read_long()
        self.tags = List[String]()
        while True:
            var count = Int(dec.read_long())
            if count == 0:
                break
            if count < 0:
                count = -count
                _ = dec.read_long()
            var j = 0
            while j < count:
                self.tags.append(dec.read_string())
                j += 1
        self.values = List[Float64]()
        while True:
            var count = Int(dec.read_long())
            if count == 0:
                break
            if count < 0:
                count = -count
                _ = dec.read_long()
            var j = 0
            while j < count:
                self.values.append(dec.read_double())
                j += 1


@fieldwise_init
struct Strings(Copyable, Movable, Defaultable, CborDatum, AvroDatum):
    var items: List[String]

    def __init__(out self):
        self.items = List[String]()

    def schema_json(self) -> String:
        return "{\"type\":\"record\",\"name\":\"Strings\"}"

    def encoded_len(self, options: EncodeOptions) -> Int:
        var n = 16
        var i = 0
        while i < len(self.items):
            n += 8 + self.items[i].byte_length()
            i += 1
        return n

    def encode_to(self, mut w: CborWriter, options: EncodeOptions):
        w.write_map_len(1)
        w.write_tstr("items")
        w.write_array_len(len(self.items))
        var i = 0
        while i < len(self.items):
            w.write_tstr(self.items[i])
            i += 1

    def decode_from[origin: ImmOrigin](mut self, mut r: CborReader[origin]) raises CborDecodeError:
        var n = r.read_map_len()
        var i = 0
        while i < n:
            var key = r.read_tstr()
            if key == "items":
                var count = r.read_array_len()
                self.items = List[String]()
                var j = 0
                while j < count:
                    self.items.append(r.read_tstr())
                    j += 1
            else:
                _ = r.read_int64()
            i += 1

    def encoded_len(self) -> Int:
        var n = 16
        var i = 0
        while i < len(self.items):
            n += 8 + self.items[i].byte_length()
            i += 1
        return n

    def encode_to(self, mut enc: AvroWriter):
        enc.write_block_start(Int64(len(self.items)))
        var i = 0
        while i < len(self.items):
            enc.write_string(self.items[i])
            i += 1
        enc.write_block_end()

    def decode_from[origin: ImmOrigin](mut self, mut dec: AvroReader[origin]) raises AvroDecodeError:
        self.items = List[String]()
        while True:
            var count = Int(dec.read_long())
            if count == 0:
                break
            if count < 0:
                count = -count
                _ = dec.read_long()
            var j = 0
            while j < count:
                self.items.append(dec.read_string())
                j += 1


@fieldwise_init
struct EventAttr(Copyable, Movable, Defaultable, CborDatum, AvroDatum):
    var key: String
    var value: String

    def __init__(out self):
        self.key = ""
        self.value = ""

    def schema_json(self) -> String:
        return "{\"type\":\"record\",\"name\":\"EventAttr\"}"

    def encoded_len(self, options: EncodeOptions) -> Int:
        return 32 + self.key.byte_length() + self.value.byte_length()

    def encode_to(self, mut w: CborWriter, options: EncodeOptions):
        w.write_map_len(2)
        w.write_tstr("key")
        w.write_tstr(self.key)
        w.write_tstr("value")
        w.write_tstr(self.value)

    def decode_from[origin: ImmOrigin](mut self, mut r: CborReader[origin]) raises CborDecodeError:
        var n = r.read_map_len()
        var i = 0
        while i < n:
            var k = r.read_tstr()
            if k == "key":
                self.key = r.read_tstr()
            elif k == "value":
                self.value = r.read_tstr()
            else:
                _ = r.read_tstr()
            i += 1

    def encoded_len(self) -> Int:
        return 16 + self.key.byte_length() + self.value.byte_length()

    def encode_to(self, mut enc: AvroWriter):
        enc.write_string(self.key)
        enc.write_string(self.value)

    def decode_from[origin: ImmOrigin](mut self, mut dec: AvroReader[origin]) raises AvroDecodeError:
        self.key = dec.read_string()
        self.value = dec.read_string()


@fieldwise_init
struct Event(Copyable, Movable, Defaultable, CborDatum, AvroDatum):
    var event_id: String
    var event_type: String
    var occurred_at: Int64
    var producer: String
    var attrs: List[EventAttr]

    def __init__(out self):
        self.event_id = ""
        self.event_type = ""
        self.occurred_at = 0
        self.producer = ""
        self.attrs = List[EventAttr]()

    def schema_json(self) -> String:
        return "{\"type\":\"record\",\"name\":\"Event\"}"

    def encoded_len(self, options: EncodeOptions) -> Int:
        var n = 64 + self.event_id.byte_length() + self.event_type.byte_length() + self.producer.byte_length()
        var i = 0
        while i < len(self.attrs):
            n += self.attrs[i].encoded_len(options)
            i += 1
        return n

    def encode_to(self, mut w: CborWriter, options: EncodeOptions):
        w.write_map_len(5)
        w.write_tstr("event_id")
        w.write_tstr(self.event_id)
        w.write_tstr("event_type")
        w.write_tstr(self.event_type)
        w.write_tstr("occurred_at")
        w.write_int(self.occurred_at)
        w.write_tstr("producer")
        w.write_tstr(self.producer)
        w.write_tstr("attrs")
        w.write_array_len(len(self.attrs))
        var i = 0
        while i < len(self.attrs):
            self.attrs[i].encode_to(w, options)
            i += 1

    def decode_from[origin: ImmOrigin](mut self, mut r: CborReader[origin]) raises CborDecodeError:
        var n = r.read_map_len()
        var i = 0
        while i < n:
            var key = r.read_tstr()
            if key == "event_id":
                self.event_id = r.read_tstr()
            elif key == "event_type":
                self.event_type = r.read_tstr()
            elif key == "occurred_at":
                self.occurred_at = r.read_int64()
            elif key == "producer":
                self.producer = r.read_tstr()
            elif key == "attrs":
                var count = r.read_array_len()
                self.attrs = List[EventAttr]()
                var j = 0
                while j < count:
                    var a = EventAttr()
                    a.decode_from(r)
                    self.attrs.append(a^)
                    j += 1
            else:
                _ = r.read_int64()
            i += 1

    def encoded_len(self) -> Int:
        var n = 32 + self.event_id.byte_length() + self.event_type.byte_length() + self.producer.byte_length()
        var i = 0
        while i < len(self.attrs):
            n += self.attrs[i].encoded_len()
            i += 1
        return n

    def encode_to(self, mut enc: AvroWriter):
        enc.write_string(self.event_id)
        enc.write_string(self.event_type)
        enc.write_long(self.occurred_at)
        enc.write_string(self.producer)
        enc.write_block_start(Int64(len(self.attrs)))
        var i = 0
        while i < len(self.attrs):
            self.attrs[i].encode_to(enc)
            i += 1
        enc.write_block_end()

    def decode_from[origin: ImmOrigin](mut self, mut dec: AvroReader[origin]) raises AvroDecodeError:
        self.event_id = dec.read_string()
        self.event_type = dec.read_string()
        self.occurred_at = dec.read_long()
        self.producer = dec.read_string()
        self.attrs = List[EventAttr]()
        while True:
            var count = Int(dec.read_long())
            if count == 0:
                break
            if count < 0:
                count = -count
                _ = dec.read_long()
            var j = 0
            while j < count:
                var a = EventAttr()
                a.decode_from(dec)
                self.attrs.append(a^)
                j += 1


@fieldwise_init
struct BatchMessage(Copyable, Movable, Defaultable, CborDatum, AvroDatum):
    var items: List[Message]

    def __init__(out self):
        self.items = List[Message]()

    def schema_json(self) -> String:
        return "{\"type\":\"record\",\"name\":\"BatchMessage\"}"

    def encoded_len(self, options: EncodeOptions) -> Int:
        var n = 16
        var i = 0
        while i < len(self.items):
            n += self.items[i].encoded_len(options)
            i += 1
        return n

    def encode_to(self, mut w: CborWriter, options: EncodeOptions):
        w.write_map_len(1)
        w.write_tstr("items")
        w.write_array_len(len(self.items))
        var i = 0
        while i < len(self.items):
            self.items[i].encode_to(w, options)
            i += 1

    def decode_from[origin: ImmOrigin](mut self, mut r: CborReader[origin]) raises CborDecodeError:
        var n = r.read_map_len()
        var i = 0
        while i < n:
            var key = r.read_tstr()
            if key == "items":
                var count = r.read_array_len()
                self.items = List[Message]()
                var j = 0
                while j < count:
                    var m = Message()
                    m.decode_from(r)
                    self.items.append(m^)
                    j += 1
            else:
                _ = r.read_int64()
            i += 1

    def encoded_len(self) -> Int:
        var n = 16
        var i = 0
        while i < len(self.items):
            n += self.items[i].encoded_len()
            i += 1
        return n

    def encode_to(self, mut enc: AvroWriter):
        enc.write_block_start(Int64(len(self.items)))
        var i = 0
        while i < len(self.items):
            self.items[i].encode_to(enc)
            i += 1
        enc.write_block_end()

    def decode_from[origin: ImmOrigin](mut self, mut dec: AvroReader[origin]) raises AvroDecodeError:
        self.items = List[Message]()
        while True:
            var count = Int(dec.read_long())
            if count == 0:
                break
            if count < 0:
                count = -count
                _ = dec.read_long()
            var j = 0
            while j < count:
                var m = Message()
                m.decode_from(dec)
                self.items.append(m^)
                j += 1


@fieldwise_init
struct BatchDocument(Copyable, Movable, Defaultable, CborDatum, AvroDatum):
    var items: List[Document]

    def __init__(out self):
        self.items = List[Document]()

    def schema_json(self) -> String:
        return "{\"type\":\"record\",\"name\":\"BatchDocument\"}"

    def encoded_len(self, options: EncodeOptions) -> Int:
        var n = 16
        var i = 0
        while i < len(self.items):
            n += self.items[i].encoded_len(options)
            i += 1
        return n

    def encode_to(self, mut w: CborWriter, options: EncodeOptions):
        w.write_map_len(1)
        w.write_tstr("items")
        w.write_array_len(len(self.items))
        var i = 0
        while i < len(self.items):
            self.items[i].encode_to(w, options)
            i += 1

    def decode_from[origin: ImmOrigin](mut self, mut r: CborReader[origin]) raises CborDecodeError:
        var n = r.read_map_len()
        var i = 0
        while i < n:
            var key = r.read_tstr()
            if key == "items":
                var count = r.read_array_len()
                self.items = List[Document]()
                var j = 0
                while j < count:
                    var d = Document()
                    d.decode_from(r)
                    self.items.append(d^)
                    j += 1
            else:
                _ = r.read_int64()
            i += 1

    def encoded_len(self) -> Int:
        var n = 16
        var i = 0
        while i < len(self.items):
            n += self.items[i].encoded_len()
            i += 1
        return n

    def encode_to(self, mut enc: AvroWriter):
        enc.write_block_start(Int64(len(self.items)))
        var i = 0
        while i < len(self.items):
            self.items[i].encode_to(enc)
            i += 1
        enc.write_block_end()

    def decode_from[origin: ImmOrigin](mut self, mut dec: AvroReader[origin]) raises AvroDecodeError:
        self.items = List[Document]()
        while True:
            var count = Int(dec.read_long())
            if count == 0:
                break
            if count < 0:
                count = -count
                _ = dec.read_long()
            var j = 0
            while j < count:
                var d = Document()
                d.decode_from(dec)
                self.items.append(d^)
                j += 1


@fieldwise_init
struct BatchTelemetry(Copyable, Movable, Defaultable, CborDatum, AvroDatum):
    var items: List[Telemetry]

    def __init__(out self):
        self.items = List[Telemetry]()

    def schema_json(self) -> String:
        return "{\"type\":\"record\",\"name\":\"BatchTelemetry\"}"

    def encoded_len(self, options: EncodeOptions) -> Int:
        var n = 16
        var i = 0
        while i < len(self.items):
            n += self.items[i].encoded_len(options)
            i += 1
        return n

    def encode_to(self, mut w: CborWriter, options: EncodeOptions):
        w.write_map_len(1)
        w.write_tstr("items")
        w.write_array_len(len(self.items))
        var i = 0
        while i < len(self.items):
            self.items[i].encode_to(w, options)
            i += 1

    def decode_from[origin: ImmOrigin](mut self, mut r: CborReader[origin]) raises CborDecodeError:
        var n = r.read_map_len()
        var i = 0
        while i < n:
            var key = r.read_tstr()
            if key == "items":
                var count = r.read_array_len()
                self.items = List[Telemetry]()
                var j = 0
                while j < count:
                    var t = Telemetry()
                    t.decode_from(r)
                    self.items.append(t^)
                    j += 1
            else:
                _ = r.read_int64()
            i += 1

    def encoded_len(self) -> Int:
        var n = 16
        var i = 0
        while i < len(self.items):
            n += self.items[i].encoded_len()
            i += 1
        return n

    def encode_to(self, mut enc: AvroWriter):
        enc.write_block_start(Int64(len(self.items)))
        var i = 0
        while i < len(self.items):
            self.items[i].encode_to(enc)
            i += 1
        enc.write_block_end()

    def decode_from[origin: ImmOrigin](mut self, mut dec: AvroReader[origin]) raises AvroDecodeError:
        self.items = List[Telemetry]()
        while True:
            var count = Int(dec.read_long())
            if count == 0:
                break
            if count < 0:
                count = -count
                _ = dec.read_long()
            var j = 0
            while j < count:
                var t = Telemetry()
                t.decode_from(dec)
                self.items.append(t^)
                j += 1


@fieldwise_init
struct BatchStrings(Copyable, Movable, Defaultable, CborDatum, AvroDatum):
    var items: List[Strings]

    def __init__(out self):
        self.items = List[Strings]()

    def schema_json(self) -> String:
        return "{\"type\":\"record\",\"name\":\"BatchStrings\"}"

    def encoded_len(self, options: EncodeOptions) -> Int:
        var n = 16
        var i = 0
        while i < len(self.items):
            n += self.items[i].encoded_len(options)
            i += 1
        return n

    def encode_to(self, mut w: CborWriter, options: EncodeOptions):
        w.write_map_len(1)
        w.write_tstr("items")
        w.write_array_len(len(self.items))
        var i = 0
        while i < len(self.items):
            self.items[i].encode_to(w, options)
            i += 1

    def decode_from[origin: ImmOrigin](mut self, mut r: CborReader[origin]) raises CborDecodeError:
        var n = r.read_map_len()
        var i = 0
        while i < n:
            var key = r.read_tstr()
            if key == "items":
                var count = r.read_array_len()
                self.items = List[Strings]()
                var j = 0
                while j < count:
                    var s = Strings()
                    s.decode_from(r)
                    self.items.append(s^)
                    j += 1
            else:
                _ = r.read_int64()
            i += 1

    def encoded_len(self) -> Int:
        var n = 16
        var i = 0
        while i < len(self.items):
            n += self.items[i].encoded_len()
            i += 1
        return n

    def encode_to(self, mut enc: AvroWriter):
        enc.write_block_start(Int64(len(self.items)))
        var i = 0
        while i < len(self.items):
            self.items[i].encode_to(enc)
            i += 1
        enc.write_block_end()

    def decode_from[origin: ImmOrigin](mut self, mut dec: AvroReader[origin]) raises AvroDecodeError:
        self.items = List[Strings]()
        while True:
            var count = Int(dec.read_long())
            if count == 0:
                break
            if count < 0:
                count = -count
                _ = dec.read_long()
            var j = 0
            while j < count:
                var s = Strings()
                s.decode_from(dec)
                self.items.append(s^)
                j += 1


@fieldwise_init
struct BatchEvent(Copyable, Movable, Defaultable, CborDatum, AvroDatum):
    var items: List[Event]

    def __init__(out self):
        self.items = List[Event]()

    def schema_json(self) -> String:
        return "{\"type\":\"record\",\"name\":\"BatchEvent\"}"

    def encoded_len(self, options: EncodeOptions) -> Int:
        var n = 16
        var i = 0
        while i < len(self.items):
            n += self.items[i].encoded_len(options)
            i += 1
        return n

    def encode_to(self, mut w: CborWriter, options: EncodeOptions):
        w.write_map_len(1)
        w.write_tstr("items")
        w.write_array_len(len(self.items))
        var i = 0
        while i < len(self.items):
            self.items[i].encode_to(w, options)
            i += 1

    def decode_from[origin: ImmOrigin](mut self, mut r: CborReader[origin]) raises CborDecodeError:
        var n = r.read_map_len()
        var i = 0
        while i < n:
            var key = r.read_tstr()
            if key == "items":
                var count = r.read_array_len()
                self.items = List[Event]()
                var j = 0
                while j < count:
                    var e = Event()
                    e.decode_from(r)
                    self.items.append(e^)
                    j += 1
            else:
                _ = r.read_int64()
            i += 1

    def encoded_len(self) -> Int:
        var n = 16
        var i = 0
        while i < len(self.items):
            n += self.items[i].encoded_len()
            i += 1
        return n

    def encode_to(self, mut enc: AvroWriter):
        enc.write_block_start(Int64(len(self.items)))
        var i = 0
        while i < len(self.items):
            self.items[i].encode_to(enc)
            i += 1
        enc.write_block_end()

    def decode_from[origin: ImmOrigin](mut self, mut dec: AvroReader[origin]) raises AvroDecodeError:
        self.items = List[Event]()
        while True:
            var count = Int(dec.read_long())
            if count == 0:
                break
            if count < 0:
                count = -count
                _ = dec.read_long()
            var j = 0
            while j < count:
                var e = Event()
                e.decode_from(dec)
                self.items.append(e^)
                j += 1


@fieldwise_init
struct TypeConfig(Copyable, ImplicitlyCopyable, Movable):
    var children: Int
    var points: Int
    var count: Int
    var attr_count: Int
    var string_min: Int
    var string_max: Int
    var int_min: Int
    var int_max: Int

    def __init__(out self):
        self.children = 8
        self.points = 32
        self.count = 32
        self.attr_count = 4
        self.string_min = 3
        self.string_max = 16
        self.int_min = 0
        self.int_max = 1_000_000


@fieldwise_init
struct Cell(Copyable, Movable):
    var type_id: String
    var n: Int
    var hash: String
    var cfg: TypeConfig


@fieldwise_init
struct Fixture(Copyable, Movable):
    var type_id: String
    var n: Int
    var hash: String
    var messages: List[Message]
    var documents: List[Document]
    var telemetries: List[Telemetry]
    var strings: List[Strings]
    var events: List[Event]


def make_one(type_id: String, cfg: TypeConfig, seed: UInt64, idx: Int) raises -> Fixture:
    var rng = Rng(mix_seed(seed, type_id, idx))
    var fx = Fixture(
        type_id,
        1,
        "",
        List[Message](),
        List[Document](),
        List[Telemetry](),
        List[Strings](),
        List[Event](),
    )
    if type_id == "message":
        var hi32 = cfg.int_max
        if hi32 > 2_147_483_647:
            hi32 = 2_147_483_647
        fx.messages.append(
            Message(
                rng.next_bool(),
                Int32(rng.next_int(cfg.int_min, hi32)),
                Int64(rng.next_int(cfg.int_min, cfg.int_max)),
                rng.next_f64() * 1000.0,
                rng.word(cfg.string_min, cfg.string_max),
                rng.next_bool(),
                Int32(rng.next_int(cfg.int_min, hi32)),
                rng.word(cfg.string_min, cfg.string_max),
            )
        )
    elif type_id == "document":
        var items = List[DocumentItem]()
        var i = 0
        while i < cfg.children:
            items.append(
                DocumentItem(
                    rng.word(cfg.string_min, cfg.string_max),
                    Int32(rng.next_int(1, 100)),
                    Int64(rng.next_int(0, 100_000)),
                )
            )
            i += 1
        fx.documents.append(
            Document(
                rng.word(8, 12),
                Int32(rng.next_int(0, 5)),
                DocumentMeta(rng.word(2, 4), Int32(rng.next_int(1, 10))),
                items^,
            )
        )
    elif type_id == "telemetry":
        var tags = List[String]()
        tags.append(rng.word(cfg.string_min, cfg.string_max))
        tags.append(rng.word(cfg.string_min, cfg.string_max))
        var values = List[Float64]()
        var i = 0
        while i < cfg.points:
            values.append(rng.next_f64() * 100.0)
            i += 1
        fx.telemetries.append(
            Telemetry(
                rng.word(cfg.string_min, cfg.string_max),
                BASE_TS_MS + Int64(rng.next_int(0, 86_400_000)),
                tags^,
                values^,
            )
        )
    elif type_id == "strings":
        var items = List[String]()
        var i = 0
        while i < cfg.count:
            items.append(rng.word(cfg.string_min, cfg.string_max))
            i += 1
        fx.strings.append(Strings(items^))
    elif type_id == "event":
        var attrs = List[EventAttr]()
        var i = 0
        while i < cfg.attr_count:
            attrs.append(
                EventAttr(
                    rng.word(cfg.string_min, cfg.string_max),
                    rng.word(cfg.string_min, cfg.string_max),
                )
            )
            i += 1
        fx.events.append(
            Event(
                rng.word(8, 12),
                rng.word(cfg.string_min, cfg.string_max),
                BASE_TS_MS + Int64(rng.next_int(0, 86_400_000)),
                rng.word(cfg.string_min, cfg.string_max),
                attrs^,
            )
        )
    else:
        raise Error("unknown type_id: " + type_id)
    return fx^


def make_cell(type_id: String, cfg: TypeConfig, seed: UInt64, n: Int, hash: String) raises -> Fixture:
    var fx = Fixture(
        type_id,
        n,
        hash,
        List[Message](),
        List[Document](),
        List[Telemetry](),
        List[Strings](),
        List[Event](),
    )
    var i = 0
    while i < n:
        var one = make_one(type_id, cfg, seed, i)
        if type_id == "message":
            fx.messages.append(one.messages[0].copy())
        elif type_id == "document":
            fx.documents.append(one.documents[0].copy())
        elif type_id == "telemetry":
            fx.telemetries.append(one.telemetries[0].copy())
        elif type_id == "strings":
            fx.strings.append(one.strings[0].copy())
        else:
            fx.events.append(one.events[0].copy())
        i += 1
    return fx^


def _close(a: Float64, b: Float64) -> Bool:
    var d = a - b
    if d < 0.0:
        d = -d
    return d < 1e-8


def fidelity_message(a: Message, b: Message) -> Bool:
    if a.f_bool != b.f_bool or a.f_bool_2 != b.f_bool_2:
        return False
    if a.f_int32 != b.f_int32 or a.f_int32_2 != b.f_int32_2:
        return False
    if a.f_int64 != b.f_int64:
        return False
    if not _close(a.f_float64, b.f_float64):
        return False
    return a.f_string == b.f_string and a.f_string_2 == b.f_string_2


def fidelity_document(a: Document, b: Document) -> Bool:
    if a.id != b.id or a.status != b.status:
        return False
    if a.meta.region != b.meta.region or a.meta.version != b.meta.version:
        return False
    if len(a.items) != len(b.items):
        return False
    var i = 0
    while i < len(a.items):
        if a.items[i].sku != b.items[i].sku:
            return False
        if a.items[i].qty != b.items[i].qty:
            return False
        if a.items[i].price_minor != b.items[i].price_minor:
            return False
        i += 1
    return True


def fidelity_telemetry(a: Telemetry, b: Telemetry) -> Bool:
    if a.source != b.source or a.ts != b.ts:
        return False
    if len(a.tags) != len(b.tags) or len(a.values) != len(b.values):
        return False
    var i = 0
    while i < len(a.tags):
        if a.tags[i] != b.tags[i]:
            return False
        i += 1
    i = 0
    while i < len(a.values):
        if not _close(a.values[i], b.values[i]):
            return False
        i += 1
    return True


def fidelity_strings(a: Strings, b: Strings) -> Bool:
    if len(a.items) != len(b.items):
        return False
    var i = 0
    while i < len(a.items):
        if a.items[i] != b.items[i]:
            return False
        i += 1
    return True


def fidelity_event(a: Event, b: Event) -> Bool:
    if a.event_id != b.event_id or a.event_type != b.event_type:
        return False
    if a.occurred_at != b.occurred_at or a.producer != b.producer:
        return False
    if len(a.attrs) != len(b.attrs):
        return False
    var i = 0
    while i < len(a.attrs):
        if a.attrs[i].key != b.attrs[i].key or a.attrs[i].value != b.attrs[i].value:
            return False
        i += 1
    return True


def fidelity(a: Fixture, b: Fixture) -> Bool:
    if a.type_id != b.type_id or a.n != b.n:
        return False
    if a.type_id == "message":
        if len(a.messages) != len(b.messages):
            return False
        var i = 0
        while i < len(a.messages):
            if not fidelity_message(a.messages[i], b.messages[i]):
                return False
            i += 1
        return True
    if a.type_id == "document":
        if len(a.documents) != len(b.documents):
            return False
        var i = 0
        while i < len(a.documents):
            if not fidelity_document(a.documents[i], b.documents[i]):
                return False
            i += 1
        return True
    if a.type_id == "telemetry":
        if len(a.telemetries) != len(b.telemetries):
            return False
        var i = 0
        while i < len(a.telemetries):
            if not fidelity_telemetry(a.telemetries[i], b.telemetries[i]):
                return False
            i += 1
        return True
    if a.type_id == "strings":
        if len(a.strings) != len(b.strings):
            return False
        var i = 0
        while i < len(a.strings):
            if not fidelity_strings(a.strings[i], b.strings[i]):
                return False
            i += 1
        return True
    if len(a.events) != len(b.events):
        return False
    var i = 0
    while i < len(a.events):
        if not fidelity_event(a.events[i], b.events[i]):
            return False
        i += 1
    return True
