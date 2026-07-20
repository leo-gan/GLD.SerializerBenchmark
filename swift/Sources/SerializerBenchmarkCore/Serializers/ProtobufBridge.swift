import Foundation
import SwiftProtobuf

/// Domain ↔ SwiftProtobuf conversion (type-aware). Used only in prepare / post-deser fidelity path.
enum ProtobufBridge {
    static func toProtobuf(_ fixture: Fixture) throws -> any SwiftProtobuf.Message {
        if fixture.instanceCount > 1 {
            return try toBatch(fixture)
        }
        switch fixture.name {
        case "message":
            return messagePB(fixture.value as! Message)
        case "document":
            return documentPB(fixture.value as! Document)
        case "telemetry":
            return telemetryPB(fixture.value as! Telemetry)
        case "strings":
            return stringsPB(fixture.value as! Strings)
        case "event":
            return eventPB(fixture.value as! Event)
        default:
            throw BenchError.unknownType(fixture.name)
        }
    }

    static func toDomain(_ msg: any SwiftProtobuf.Message, fixture: Fixture) throws -> Any {
        if fixture.instanceCount > 1 {
            return try fromBatch(msg, fixture: fixture)
        }
        switch fixture.name {
        case "message":
            return messageDomain(msg as! Benchmark_V2_Message)
        case "document":
            return documentDomain(msg as! Benchmark_V2_Document)
        case "telemetry":
            return telemetryDomain(msg as! Benchmark_V2_Telemetry)
        case "strings":
            return stringsDomain(msg as! Benchmark_V2_Strings)
        case "event":
            return eventDomain(msg as! Benchmark_V2_Event)
        default:
            throw BenchError.unknownType(fixture.name)
        }
    }

    private static func toBatch(_ fixture: Fixture) throws -> any SwiftProtobuf.Message {
        switch fixture.name {
        case "message":
            var b = Benchmark_V2_BatchMessage()
            b.items = (fixture.value as! [Message]).map(messagePB)
            return b
        case "document":
            var b = Benchmark_V2_BatchDocument()
            b.items = (fixture.value as! [Document]).map(documentPB)
            return b
        case "telemetry":
            var b = Benchmark_V2_BatchTelemetry()
            b.items = (fixture.value as! [Telemetry]).map(telemetryPB)
            return b
        case "strings":
            var b = Benchmark_V2_BatchStrings()
            b.items = (fixture.value as! [Strings]).map(stringsPB)
            return b
        case "event":
            var b = Benchmark_V2_BatchEvent()
            b.items = (fixture.value as! [Event]).map(eventPB)
            return b
        default:
            throw BenchError.unknownType(fixture.name)
        }
    }

    private static func fromBatch(_ msg: any SwiftProtobuf.Message, fixture: Fixture) throws -> Any {
        switch fixture.name {
        case "message":
            return (msg as! Benchmark_V2_BatchMessage).items.map(messageDomain)
        case "document":
            return (msg as! Benchmark_V2_BatchDocument).items.map(documentDomain)
        case "telemetry":
            return (msg as! Benchmark_V2_BatchTelemetry).items.map(telemetryDomain)
        case "strings":
            return (msg as! Benchmark_V2_BatchStrings).items.map(stringsDomain)
        case "event":
            return (msg as! Benchmark_V2_BatchEvent).items.map(eventDomain)
        default:
            throw BenchError.unknownType(fixture.name)
        }
    }

    static func messagePB(_ m: Message) -> Benchmark_V2_Message {
        var p = Benchmark_V2_Message()
        p.fBool = m.f_bool
        p.fInt32 = m.f_int32
        p.fInt64 = m.f_int64
        p.fFloat64 = m.f_float64
        p.fString = m.f_string
        p.fBool2 = m.f_bool_2
        p.fInt322 = m.f_int32_2
        p.fString2 = m.f_string_2
        return p
    }
    static func messageDomain(_ p: Benchmark_V2_Message) -> Message {
        Message(
            f_bool: p.fBool, f_int32: p.fInt32, f_int64: p.fInt64, f_float64: p.fFloat64,
            f_string: p.fString, f_bool_2: p.fBool2, f_int32_2: p.fInt322, f_string_2: p.fString2
        )
    }

    static func documentPB(_ d: Document) -> Benchmark_V2_Document {
        var p = Benchmark_V2_Document()
        p.id = d.id
        p.status = d.status
        var meta = Benchmark_V2_DocumentMeta()
        meta.region = d.meta.region
        meta.version = d.meta.version
        p.meta = meta
        p.items = d.items.map { it in
            var x = Benchmark_V2_DocumentItem()
            x.sku = it.sku; x.qty = it.qty; x.priceMinor = it.price_minor
            return x
        }
        return p
    }
    static func documentDomain(_ p: Benchmark_V2_Document) -> Document {
        Document(
            id: p.id, status: p.status,
            meta: DocumentMeta(region: p.meta.region, version: p.meta.version),
            items: p.items.map { DocumentItem(sku: $0.sku, qty: $0.qty, price_minor: $0.priceMinor) }
        )
    }

    static func telemetryPB(_ t: Telemetry) -> Benchmark_V2_Telemetry {
        var p = Benchmark_V2_Telemetry()
        p.source = t.source; p.ts = t.ts; p.tags = t.tags; p.values = t.values
        return p
    }
    static func telemetryDomain(_ p: Benchmark_V2_Telemetry) -> Telemetry {
        Telemetry(source: p.source, ts: p.ts, tags: p.tags, values: p.values)
    }

    static func stringsPB(_ s: Strings) -> Benchmark_V2_Strings {
        var p = Benchmark_V2_Strings(); p.items = s.items; return p
    }
    static func stringsDomain(_ p: Benchmark_V2_Strings) -> Strings {
        Strings(items: p.items)
    }

    static func eventPB(_ e: Event) -> Benchmark_V2_Event {
        var p = Benchmark_V2_Event()
        p.eventID = e.event_id
        p.eventType = e.event_type
        p.occurredAt = e.occurred_at
        p.producer = e.producer
        p.attrs = e.attrs.map { a in
            var x = Benchmark_V2_EventAttr(); x.key = a.key; x.value = a.value; return x
        }
        return p
    }
    static func eventDomain(_ p: Benchmark_V2_Event) -> Event {
        Event(
            event_id: p.eventID, event_type: p.eventType, occurred_at: p.occurredAt,
            producer: p.producer,
            attrs: p.attrs.map { EventAttr(key: $0.key, value: $0.value) }
        )
    }
}
