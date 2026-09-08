from std.collections import List
from gen.pb_v2 import (
    BatchDocument as PbBatchDocument,
    BatchEvent as PbBatchEvent,
    BatchMessage as PbBatchMessage,
    BatchStrings as PbBatchStrings,
    BatchTelemetry as PbBatchTelemetry,
    Document as PbDocument,
    DocumentItem as PbDocumentItem,
    DocumentMeta as PbDocumentMeta,
    Event as PbEvent,
    EventAttr as PbEventAttr,
    Message as PbMessage,
    Strings as PbStrings,
    Telemetry as PbTelemetry,
)
from bench.data import (
    Document,
    DocumentItem,
    DocumentMeta,
    Event,
    EventAttr,
    Fixture,
    Message,
    Strings,
    Telemetry,
    fidelity,
)


def _to_pb_message(m: Message) -> PbMessage:
    var p = PbMessage()
    p.f_bool = m.f_bool
    p.f_int32 = m.f_int32
    p.f_int64 = m.f_int64
    p.f_float64 = m.f_float64
    p.f_string = m.f_string
    p.f_bool_2 = m.f_bool_2
    p.f_int32_2 = m.f_int32_2
    p.f_string_2 = m.f_string_2
    return p^


def _from_pb_message(p: PbMessage) -> Message:
    return Message(
        p.f_bool,
        p.f_int32,
        p.f_int64,
        p.f_float64,
        p.f_string,
        p.f_bool_2,
        p.f_int32_2,
        p.f_string_2,
    )


def _to_pb_document(d: Document) -> PbDocument:
    var p = PbDocument()
    p.id = d.id
    p.status = d.status
    var meta = PbDocumentMeta()
    meta.region = d.meta.region
    meta.version = d.meta.version
    p.meta = meta^
    var i = 0
    while i < len(d.items):
        var it = PbDocumentItem()
        it.sku = d.items[i].sku
        it.qty = d.items[i].qty
        it.price_minor = d.items[i].price_minor
        p.items.append(it^)
        i += 1
    return p^


def _from_pb_document(p: PbDocument) -> Document:
    var items = List[DocumentItem]()
    var i = 0
    while i < len(p.items):
        items.append(DocumentItem(p.items[i].sku, p.items[i].qty, p.items[i].price_minor))
        i += 1
    return Document(
        p.id,
        p.status,
        DocumentMeta(p.meta.value().region, p.meta.value().version),
        items^,
    )


def _to_pb_telemetry(t: Telemetry) -> PbTelemetry:
    var p = PbTelemetry()
    p.source = t.source
    p.ts = t.ts
    var i = 0
    while i < len(t.tags):
        p.tags.append(t.tags[i])
        i += 1
    i = 0
    while i < len(t.values):
        p.values.append(t.values[i])
        i += 1
    return p^


def _from_pb_telemetry(p: PbTelemetry) -> Telemetry:
    var tags = List[String]()
    var values = List[Float64]()
    var i = 0
    while i < len(p.tags):
        tags.append(p.tags[i])
        i += 1
    i = 0
    while i < len(p.values):
        values.append(p.values[i])
        i += 1
    return Telemetry(p.source, p.ts, tags^, values^)


def _to_pb_strings(s: Strings) -> PbStrings:
    var p = PbStrings()
    var i = 0
    while i < len(s.items):
        p.items.append(s.items[i])
        i += 1
    return p^


def _from_pb_strings(p: PbStrings) -> Strings:
    var items = List[String]()
    var i = 0
    while i < len(p.items):
        items.append(p.items[i])
        i += 1
    return Strings(items^)


def _to_pb_event(e: Event) -> PbEvent:
    var p = PbEvent()
    p.event_id = e.event_id
    p.event_type = e.event_type
    p.occurred_at = e.occurred_at
    p.producer = e.producer
    var i = 0
    while i < len(e.attrs):
        var a = PbEventAttr()
        a.key = e.attrs[i].key
        a.value = e.attrs[i].value
        p.attrs.append(a^)
        i += 1
    return p^


def _from_pb_event(p: PbEvent) -> Event:
    var attrs = List[EventAttr]()
    var i = 0
    while i < len(p.attrs):
        attrs.append(EventAttr(p.attrs[i].key, p.attrs[i].value))
        i += 1
    return Event(p.event_id, p.event_type, p.occurred_at, p.producer, attrs^)


struct ProtobufSer:
    var version: String

    def __init__(out self):
        self.version = "0.6.0"

    def name(self) -> String:
        return "mojo-protobuf"

    def serialize_bytes(self, fx: Fixture) raises -> List[Byte]:
        if fx.type_id == "message":
            if fx.n == 1:
                return _to_pb_message(fx.messages[0]).encode()
            var batch = PbBatchMessage()
            var i = 0
            while i < len(fx.messages):
                batch.items.append(_to_pb_message(fx.messages[i]))
                i += 1
            return batch.encode()
        if fx.type_id == "document":
            if fx.n == 1:
                return _to_pb_document(fx.documents[0]).encode()
            var batch = PbBatchDocument()
            var i = 0
            while i < len(fx.documents):
                batch.items.append(_to_pb_document(fx.documents[i]))
                i += 1
            return batch.encode()
        if fx.type_id == "telemetry":
            if fx.n == 1:
                return _to_pb_telemetry(fx.telemetries[0]).encode()
            var batch = PbBatchTelemetry()
            var i = 0
            while i < len(fx.telemetries):
                batch.items.append(_to_pb_telemetry(fx.telemetries[i]))
                i += 1
            return batch.encode()
        if fx.type_id == "strings":
            if fx.n == 1:
                return _to_pb_strings(fx.strings[0]).encode()
            var batch = PbBatchStrings()
            var i = 0
            while i < len(fx.strings):
                batch.items.append(_to_pb_strings(fx.strings[i]))
                i += 1
            return batch.encode()
        if fx.n == 1:
            return _to_pb_event(fx.events[0]).encode()
        var batch = PbBatchEvent()
        var i = 0
        while i < len(fx.events):
            batch.items.append(_to_pb_event(fx.events[i]))
            i += 1
        return batch.encode()

    def deserialize_bytes(self, fx: Fixture, data: List[Byte]) raises -> Fixture:
        var out = Fixture(
            fx.type_id,
            fx.n,
            fx.hash,
            List[Message](),
            List[Document](),
            List[Telemetry](),
            List[Strings](),
            List[Event](),
        )
        if fx.type_id == "message":
            if fx.n == 1:
                out.messages.append(_from_pb_message(PbMessage.decode(data)))
            else:
                var batch = PbBatchMessage.decode(data)
                var i = 0
                while i < len(batch.items):
                    out.messages.append(_from_pb_message(batch.items[i]))
                    i += 1
        elif fx.type_id == "document":
            if fx.n == 1:
                out.documents.append(_from_pb_document(PbDocument.decode(data)))
            else:
                var batch = PbBatchDocument.decode(data)
                var i = 0
                while i < len(batch.items):
                    out.documents.append(_from_pb_document(batch.items[i]))
                    i += 1
        elif fx.type_id == "telemetry":
            if fx.n == 1:
                out.telemetries.append(_from_pb_telemetry(PbTelemetry.decode(data)))
            else:
                var batch = PbBatchTelemetry.decode(data)
                var i = 0
                while i < len(batch.items):
                    out.telemetries.append(_from_pb_telemetry(batch.items[i]))
                    i += 1
        elif fx.type_id == "strings":
            if fx.n == 1:
                out.strings.append(_from_pb_strings(PbStrings.decode(data)))
            else:
                var batch = PbBatchStrings.decode(data)
                var i = 0
                while i < len(batch.items):
                    out.strings.append(_from_pb_strings(batch.items[i]))
                    i += 1
        else:
            if fx.n == 1:
                out.events.append(_from_pb_event(PbEvent.decode(data)))
            else:
                var batch = PbBatchEvent.decode(data)
                var i = 0
                while i < len(batch.items):
                    out.events.append(_from_pb_event(batch.items[i]))
                    i += 1
        return out^

    def check(self, fx: Fixture, data: List[Byte]) raises -> Bool:
        return fidelity(fx, self.deserialize_bytes(fx, data))
