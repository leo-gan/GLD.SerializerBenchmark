"""Kiln Frozen encode/decode on the five suite record types."""

from std.collections import List, Span

from bench.data import (
    Document,
    Event,
    Fixture,
    Message,
    Strings,
    Telemetry,
)
from kiln import decode, encode
from kiln.wire import Writer


struct KilnSer:
    var version: String
    var buf: Writer

    def __init__(out self):
        self.version = "0.2.0"
        self.buf = Writer(4096)

    def name(self) -> String:
        return "kiln"

    def supports(self, type_id: String) -> Bool:
        if type_id == "message" or type_id == "document" or type_id == "telemetry":
            return True
        if type_id == "strings" or type_id == "event":
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
        else:
            if fx.n == 1:
                encode(fx.events[0], self.buf)
            else:
                encode(fx.events, self.buf)
        return self.buf.copy_bytes()

    def deserialize_bytes(self, fx: Fixture, data: List[UInt8]) raises -> Fixture:
        var out = Fixture.empty(fx.type_id, fx.n, fx.hash)
        var raw = Span(data)
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
