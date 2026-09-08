from std.collections import List
from emberjson import deserialize, serialize
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


struct EmberJsonSer:
    var version: String

    def __init__(out self):
        self.version = "0.3.4"

    def name(self) -> String:
        return "EmberJson"

    def serialize_bytes(self, fx: Fixture) raises -> String:
        if fx.type_id == "message":
            if fx.n == 1:
                return serialize(fx.messages[0])
            return serialize(BatchMessage(fx.messages.copy()))
        if fx.type_id == "document":
            if fx.n == 1:
                return serialize(fx.documents[0])
            return serialize(BatchDocument(fx.documents.copy()))
        if fx.type_id == "telemetry":
            if fx.n == 1:
                return serialize(fx.telemetries[0])
            return serialize(BatchTelemetry(fx.telemetries.copy()))
        if fx.type_id == "strings":
            if fx.n == 1:
                return serialize(fx.strings[0])
            return serialize(BatchStrings(fx.strings.copy()))
        if fx.n == 1:
            return serialize(fx.events[0])
        return serialize(BatchEvent(fx.events.copy()))

    def deserialize_bytes(self, fx: Fixture, data: String) raises -> Fixture:
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
                out.messages.append(deserialize[Message](data))
            else:
                out.messages = deserialize[BatchMessage](data).items.copy()
        elif fx.type_id == "document":
            if fx.n == 1:
                out.documents = List[Document]()
                out.documents.append(deserialize[Document](data))
            else:
                out.documents = deserialize[BatchDocument](data).items.copy()
        elif fx.type_id == "telemetry":
            if fx.n == 1:
                out.telemetries = List[Telemetry]()
                out.telemetries.append(deserialize[Telemetry](data))
            else:
                out.telemetries = deserialize[BatchTelemetry](data).items.copy()
        elif fx.type_id == "strings":
            if fx.n == 1:
                out.strings = List[Strings]()
                out.strings.append(deserialize[Strings](data))
            else:
                out.strings = deserialize[BatchStrings](data).items.copy()
        else:
            if fx.n == 1:
                out.events = List[Event]()
                out.events.append(deserialize[Event](data))
            else:
                out.events = deserialize[BatchEvent](data).items.copy()
        return out^

    def check(self, fx: Fixture, data: String) raises -> Bool:
        return fidelity(fx, self.deserialize_bytes(fx, data))
