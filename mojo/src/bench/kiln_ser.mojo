"""Kiln Frozen encode/decode on the five suite record types."""

from std.collections import List, Span

from bench.data import (
    Document,
    Event,
    Fixture,
    Message,
    _same_f32,
    PromptValue,
    RequestValue,
    ShardValue,
    Strings,
    Telemetry,
    TensorValue,
)
from kiln import decode, encode
from kiln.wire import Reader, Writer


struct KilnSer:
    var version: String
    var buf: Writer

    def __init__(out self):
        self.version = "0.2.0"
        self.buf = Writer(4096)

    def name(self) -> String:
        return "gld-kiln"

    def supports(self, type_id: String) -> Bool:
        if type_id == "message" or type_id == "document" or type_id == "telemetry":
            return True
        if type_id == "strings" or type_id == "event":
            return True
        if type_id == "tensor" or type_id == "tensor_view" or type_id == "prompt":
            return True
        if type_id == "shard" or type_id == "request":
            return True
        return False

    def serialize_bytes(mut self, fx: Fixture) raises -> List[UInt8]:
        # A batch struct is one list field, so the list bytes are the batch
        # bytes. Encoding the fixture list avoids copying every record first.
        if fx.type_id == "message":
            if fx.n == 1:
                encode(fx.messages[0], self.buf)
            else:
                encode(fx.messages, self.buf)
        elif fx.type_id == "document":
            if fx.n == 1:
                encode(fx.documents[0], self.buf)
            else:
                encode(fx.documents, self.buf)
        elif fx.type_id == "telemetry":
            if fx.n == 1:
                encode(fx.telemetries[0], self.buf)
            else:
                encode(fx.telemetries, self.buf)
        elif fx.type_id == "strings":
            if fx.n == 1:
                encode(fx.strings[0], self.buf)
            else:
                encode(fx.strings, self.buf)
        elif fx.type_id == "tensor" or fx.type_id == "tensor_view":
            encode(fx.tensors[0], self.buf)
        elif fx.type_id == "prompt":
            encode(fx.prompts[0], self.buf)
        elif fx.type_id == "shard":
            encode(fx.shards[0], self.buf)
        elif fx.type_id == "request":
            encode(fx.requests[0], self.buf)
        else:
            if fx.n == 1:
                encode(fx.events[0], self.buf)
            else:
                encode(fx.events, self.buf)
        return self.buf.copy_bytes()

    def deserialize_bytes(self, fx: Fixture, data: List[UInt8]) raises -> Fixture:
        var out = Fixture.empty(fx.type_id, fx.n, fx.hash)
        var raw = Span(data)
        if fx.type_id == "tensor_view":
            out.view_ok = _tensor_view_ok(fx, raw)
            return out^
        if fx.type_id == "tensor":
            var one = List[TensorValue]()
            one.append(decode[TensorValue](raw))
            out.tensors = one^
            return out^
        if fx.type_id == "prompt":
            var one = List[PromptValue]()
            one.append(decode[PromptValue](raw))
            out.prompts = one^
            return out^
        if fx.type_id == "shard":
            var one = List[ShardValue]()
            one.append(decode[ShardValue](raw))
            out.shards = one^
            return out^
        if fx.type_id == "request":
            var one = List[RequestValue]()
            one.append(decode[RequestValue](raw))
            out.requests = one^
            return out^
        if fx.type_id == "message":
            if fx.n == 1:
                var one = List[Message]()
                one.append(decode[Message](raw))
                out.messages = one^
            else:
                out.messages = decode[List[Message]](raw)
        elif fx.type_id == "document":
            if fx.n == 1:
                var one = List[Document]()
                one.append(decode[Document](raw))
                out.documents = one^
            else:
                out.documents = decode[List[Document]](raw)
        elif fx.type_id == "telemetry":
            if fx.n == 1:
                var one = List[Telemetry]()
                one.append(decode[Telemetry](raw))
                out.telemetries = one^
            else:
                out.telemetries = decode[List[Telemetry]](raw)
        elif fx.type_id == "strings":
            if fx.n == 1:
                var one = List[Strings]()
                one.append(decode[Strings](raw))
                out.strings = one^
            else:
                out.strings = decode[List[Strings]](raw)
        else:
            if fx.n == 1:
                var one = List[Event]()
                one.append(decode[Event](raw))
                out.events = one^
            else:
                out.events = decode[List[Event]](raw)
        return out^


def _tensor_view_ok[o: ImmOrigin](fx: Fixture, data: Span[UInt8, o]) raises -> Bool:
    """Borrowed read. Reader.take returns a span of the encoded payload."""
    var reader = Reader(data)
    var rows = reader.i32()
    var cols = reader.i32()
    var n = reader.count()
    var payload = reader.take(n * 4)
    if len(fx.tensors) != 1:
        return False
    if rows != fx.tensors[0].rows or cols != fx.tensors[0].cols or n != len(fx.tensors[0].values):
        return False
    if len(payload) != n * 4:
        return False
    var i = 0
    while i < n:
        var bits = (
            UInt32(payload[i * 4])
            | (UInt32(payload[i * 4 + 1]) << 8)
            | (UInt32(payload[i * 4 + 2]) << 16)
            | (UInt32(payload[i * 4 + 3]) << 24)
        )
        var got = Float32(from_bits=bits)
        if not _same_f32(got, fx.tensors[0].values[i]):
            return False
        i += 1
    return True
