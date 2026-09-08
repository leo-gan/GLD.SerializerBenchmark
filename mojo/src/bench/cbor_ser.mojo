from std.collections import List
from cbor import decode, encode
from bench.data import (
    BatchDocument,
    BatchEvent,
    BatchMessage,
    BatchStrings,
    BatchTelemetry,
    Document,
    Event,
    Fixture,
    Message,
    Strings,
    Telemetry,
    fidelity,
)


struct CborSer:
    var version: String

    def __init__(out self):
        self.version = "0.6.0"

    def name(self) -> String:
        return "mojo-cbor"

    def serialize_bytes(self, fx: Fixture) raises -> List[Byte]:
        if fx.type_id == "message":
            if fx.n == 1:
                return encode(fx.messages[0])
            return encode(BatchMessage(fx.messages.copy()))
        if fx.type_id == "document":
            if fx.n == 1:
                return encode(fx.documents[0])
            return encode(BatchDocument(fx.documents.copy()))
        if fx.type_id == "telemetry":
            if fx.n == 1:
                return encode(fx.telemetries[0])
            return encode(BatchTelemetry(fx.telemetries.copy()))
        if fx.type_id == "strings":
            if fx.n == 1:
                return encode(fx.strings[0])
            return encode(BatchStrings(fx.strings.copy()))
        if fx.n == 1:
            return encode(fx.events[0])
        return encode(BatchEvent(fx.events.copy()))

    def deserialize_bytes(self, fx: Fixture, data: List[Byte]) raises -> Fixture:
        var out = Fixture(
            fx.type_id,
            fx.n,
            fx.hash,
            fx.messages.copy(),
            fx.documents.copy(),
            fx.telemetries.copy(),
            fx.strings.copy(),
            fx.events.copy(),
        )
        if fx.type_id == "message":
            if fx.n == 1:
                out.messages = List[Message]()
                out.messages.append(decode[Message](data))
            else:
                out.messages = decode[BatchMessage](data).items.copy()
        elif fx.type_id == "document":
            if fx.n == 1:
                out.documents = List[Document]()
                out.documents.append(decode[Document](data))
            else:
                out.documents = decode[BatchDocument](data).items.copy()
        elif fx.type_id == "telemetry":
            if fx.n == 1:
                out.telemetries = List[Telemetry]()
                out.telemetries.append(decode[Telemetry](data))
            else:
                out.telemetries = decode[BatchTelemetry](data).items.copy()
        elif fx.type_id == "strings":
            if fx.n == 1:
                out.strings = List[Strings]()
                out.strings.append(decode[Strings](data))
            else:
                out.strings = decode[BatchStrings](data).items.copy()
        else:
            if fx.n == 1:
                out.events = List[Event]()
                out.events.append(decode[Event](data))
            else:
                out.events = decode[BatchEvent](data).items.copy()
        return out^

    def check(self, fx: Fixture, data: List[Byte]) raises -> Bool:
        return fidelity(fx, self.deserialize_bytes(fx, data))
