"""mojo-flatbuffers (gld-flatbuffers) on the suite tables.

Suite values are copied into the generated tables from `gen/fb_v2.mojo`.
One Builder is kept for the process. Serialize calls generated `pack`, then
`finish`. Decode calls generated `decode_*` and copies each field back into
the suite value. The untimed prepare call grows the block before the timed
repetitions.
"""

from std.collections import List
from fb_wire.builder import Builder
from gen.fb_v2 import (
    BatchDocument as FbBatchDocument,
    BatchEvent as FbBatchEvent,
    BatchMessage as FbBatchMessage,
    BatchStrings as FbBatchStrings,
    BatchTelemetry as FbBatchTelemetry,
    Document as FbDocument,
    DocumentItem as FbDocumentItem,
    DocumentMeta as FbDocumentMeta,
    Event as FbEvent,
    EventAttr as FbEventAttr,
    Message as FbMessage,
    Strings as FbStrings,
    Telemetry as FbTelemetry,
    decode_BatchDocument,
    decode_BatchEvent,
    decode_BatchMessage,
    decode_BatchStrings,
    decode_BatchTelemetry,
    decode_Document,
    decode_Event,
    decode_Message,
    decode_Strings,
    decode_Telemetry,
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


def _to_fb_message(m: Message) -> FbMessage:
    var p = FbMessage()
    p.f_bool = m.f_bool
    p.f_int32 = m.f_int32
    p.f_int64 = m.f_int64
    p.f_float64 = m.f_float64
    p.f_string = m.f_string
    p.f_bool_2 = m.f_bool_2
    p.f_int32_2 = m.f_int32_2
    p.f_string_2 = m.f_string_2
    return p^


def _from_fb_message(p: FbMessage) -> Message:
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


def _to_fb_document(d: Document) -> FbDocument:
    var p = FbDocument()
    p.id = d.id
    p.status = d.status
    var meta = FbDocumentMeta()
    meta.region = d.meta.region
    meta.version = d.meta.version
    p.has_meta = True
    p.meta = meta^
    var i = 0
    while i < len(d.items):
        var it = FbDocumentItem()
        it.sku = d.items[i].sku
        it.qty = d.items[i].qty
        it.price_minor = d.items[i].price_minor
        p.items.append(it^)
        i += 1
    return p^


def _from_fb_document(p: FbDocument) -> Document:
    var items = List[DocumentItem]()
    var i = 0
    while i < len(p.items):
        items.append(DocumentItem(p.items[i].sku, p.items[i].qty, p.items[i].price_minor))
        i += 1
    var region = String("")
    var version = Int32(0)
    if p.has_meta:
        region = p.meta.region
        version = p.meta.version
    return Document(p.id, p.status, DocumentMeta(region, version), items^)


def _to_fb_telemetry(t: Telemetry) -> FbTelemetry:
    var p = FbTelemetry()
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


def _from_fb_telemetry(p: FbTelemetry) -> Telemetry:
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


def _to_fb_strings(s: Strings) -> FbStrings:
    var p = FbStrings()
    var i = 0
    while i < len(s.items):
        p.items.append(s.items[i])
        i += 1
    return p^


def _from_fb_strings(p: FbStrings) -> Strings:
    var items = List[String]()
    var i = 0
    while i < len(p.items):
        items.append(p.items[i])
        i += 1
    return Strings(items^)


def _to_fb_event(e: Event) -> FbEvent:
    var p = FbEvent()
    p.event_id = e.event_id
    p.event_type = e.event_type
    p.occurred_at = e.occurred_at
    p.producer = e.producer
    var i = 0
    while i < len(e.attrs):
        var a = FbEventAttr()
        a.key = e.attrs[i].key
        a.value = e.attrs[i].value
        p.attrs.append(a^)
        i += 1
    return p^


def _from_fb_event(p: FbEvent) -> Event:
    var attrs = List[EventAttr]()
    var i = 0
    while i < len(p.attrs):
        attrs.append(EventAttr(p.attrs[i].key, p.attrs[i].value))
        i += 1
    return Event(p.event_id, p.event_type, p.occurred_at, p.producer, attrs^)


struct FlatBuffersSer:
    var version: String
    var builder: Builder

    def __init__(out self):
        self.version = "0.2.0"
        self.builder = Builder(65536)

    def name(self) -> String:
        return "mojo-flatbuffers"

    def _bytes(mut self, root: Int) raises -> List[Byte]:
        self.builder.finish(root)
        return self.builder.finished_list()

    def serialize_bytes(mut self, fx: Fixture) raises -> List[Byte]:
        self.builder.clear()
        if fx.type_id == "message":
            if fx.n == 1:
                return self._bytes(_to_fb_message(fx.messages[0]).pack(self.builder))
            var batch = FbBatchMessage()
            var i = 0
            while i < len(fx.messages):
                batch.items.append(_to_fb_message(fx.messages[i]))
                i += 1
            return self._bytes(batch.pack(self.builder))
        if fx.type_id == "document":
            if fx.n == 1:
                return self._bytes(_to_fb_document(fx.documents[0]).pack(self.builder))
            var batch = FbBatchDocument()
            var i = 0
            while i < len(fx.documents):
                batch.items.append(_to_fb_document(fx.documents[i]))
                i += 1
            return self._bytes(batch.pack(self.builder))
        if fx.type_id == "telemetry":
            if fx.n == 1:
                return self._bytes(_to_fb_telemetry(fx.telemetries[0]).pack(self.builder))
            var batch = FbBatchTelemetry()
            var i = 0
            while i < len(fx.telemetries):
                batch.items.append(_to_fb_telemetry(fx.telemetries[i]))
                i += 1
            return self._bytes(batch.pack(self.builder))
        if fx.type_id == "strings":
            if fx.n == 1:
                return self._bytes(_to_fb_strings(fx.strings[0]).pack(self.builder))
            var batch = FbBatchStrings()
            var i = 0
            while i < len(fx.strings):
                batch.items.append(_to_fb_strings(fx.strings[i]))
                i += 1
            return self._bytes(batch.pack(self.builder))
        if fx.n == 1:
            return self._bytes(_to_fb_event(fx.events[0]).pack(self.builder))
        var batch = FbBatchEvent()
        var i = 0
        while i < len(fx.events):
            batch.items.append(_to_fb_event(fx.events[i]))
            i += 1
        return self._bytes(batch.pack(self.builder))

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
                out.messages.append(_from_fb_message(decode_Message(data)))
            else:
                var batch = decode_BatchMessage(data)
                var i = 0
                while i < len(batch.items):
                    out.messages.append(_from_fb_message(batch.items[i]))
                    i += 1
        elif fx.type_id == "document":
            if fx.n == 1:
                out.documents.append(_from_fb_document(decode_Document(data)))
            else:
                var batch = decode_BatchDocument(data)
                var i = 0
                while i < len(batch.items):
                    out.documents.append(_from_fb_document(batch.items[i]))
                    i += 1
        elif fx.type_id == "telemetry":
            if fx.n == 1:
                out.telemetries.append(_from_fb_telemetry(decode_Telemetry(data)))
            else:
                var batch = decode_BatchTelemetry(data)
                var i = 0
                while i < len(batch.items):
                    out.telemetries.append(_from_fb_telemetry(batch.items[i]))
                    i += 1
        elif fx.type_id == "strings":
            if fx.n == 1:
                out.strings.append(_from_fb_strings(decode_Strings(data)))
            else:
                var batch = decode_BatchStrings(data)
                var i = 0
                while i < len(batch.items):
                    out.strings.append(_from_fb_strings(batch.items[i]))
                    i += 1
        else:
            if fx.n == 1:
                out.events.append(_from_fb_event(decode_Event(data)))
            else:
                var batch = decode_BatchEvent(data)
                var i = 0
                while i < len(batch.items):
                    out.events.append(_from_fb_event(batch.items[i]))
                    i += 1
        return out^

    def check(self, fx: Fixture, data: List[Byte]) raises -> Bool:
        return fidelity(fx, self.deserialize_bytes(fx, data))
