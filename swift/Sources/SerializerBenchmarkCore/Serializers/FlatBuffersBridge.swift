import Foundation
import FlatBuffers

enum FlatBuffersBridge {
    static func encode(into fbb: inout FlatBufferBuilder, fixture: Fixture) throws -> Data {
        let root: Offset
        let kind: benchmark_v2_FixtureKind
        if fixture.instanceCount > 1 {
            switch fixture.name {
            case "message":
                let batch = encodeBatchMessage(&fbb, fixture.value as! [Message])
                kind = .batchmessage
                root = benchmark_v2_FixtureRoot.createFixtureRoot(&fbb, kind: kind, batchMessageOffset: batch)
            case "document":
                let batch = encodeBatchDocument(&fbb, fixture.value as! [Document])
                kind = .batchdocument
                root = benchmark_v2_FixtureRoot.createFixtureRoot(&fbb, kind: kind, batchDocumentOffset: batch)
            case "telemetry":
                let batch = encodeBatchTelemetry(&fbb, fixture.value as! [Telemetry])
                kind = .batchtelemetry
                root = benchmark_v2_FixtureRoot.createFixtureRoot(&fbb, kind: kind, batchTelemetryOffset: batch)
            case "strings":
                let batch = encodeBatchStrings(&fbb, fixture.value as! [Strings])
                kind = .batchstrings
                root = benchmark_v2_FixtureRoot.createFixtureRoot(&fbb, kind: kind, batchStringsOffset: batch)
            case "event":
                let batch = encodeBatchEvent(&fbb, fixture.value as! [Event])
                kind = .batchevent
                root = benchmark_v2_FixtureRoot.createFixtureRoot(&fbb, kind: kind, batchEventOffset: batch)
            default:
                throw BenchError.unknownType(fixture.name)
            }
        } else {
            switch fixture.name {
            case "message":
                let o = encodeMessage(&fbb, fixture.value as! Message)
                kind = .message
                root = benchmark_v2_FixtureRoot.createFixtureRoot(&fbb, kind: kind, messageOffset: o)
            case "document":
                let o = encodeDocument(&fbb, fixture.value as! Document)
                kind = .document
                root = benchmark_v2_FixtureRoot.createFixtureRoot(&fbb, kind: kind, documentOffset: o)
            case "telemetry":
                let o = encodeTelemetry(&fbb, fixture.value as! Telemetry)
                kind = .telemetry
                root = benchmark_v2_FixtureRoot.createFixtureRoot(&fbb, kind: kind, telemetryOffset: o)
            case "strings":
                let o = encodeStrings(&fbb, fixture.value as! Strings)
                kind = .strings
                root = benchmark_v2_FixtureRoot.createFixtureRoot(&fbb, kind: kind, stringsOffset: o)
            case "event":
                let o = encodeEvent(&fbb, fixture.value as! Event)
                kind = .event
                root = benchmark_v2_FixtureRoot.createFixtureRoot(&fbb, kind: kind, eventOffset: o)
            default:
                throw BenchError.unknownType(fixture.name)
            }
        }
        fbb.finish(offset: root)
        // sizedByteArray is the documented finished payload view.
        return Data(fbb.sizedByteArray)
    }

    static func encode(_ fixture: Fixture) throws -> Data {
        var fbb = FlatBufferBuilder(initialSize: 1024)
        return try encode(into: &fbb, fixture: fixture)
    }

    static func decode(_ data: Data, fixture: Fixture) throws -> Any {
        var bytes = ByteBuffer(data: data)
        let root: benchmark_v2_FixtureRoot = getRoot(byteBuffer: &bytes)
        if fixture.instanceCount > 1 {
            switch fixture.name {
            case "message":
                guard let b = root.batchMessage else { throw BenchError.fidelity }
                return (0..<b.itemsCount).compactMap { i -> Message? in
                    guard let m = b.items(at: i) else { return nil }
                    return messageDomain(m)
                }
            case "document":
                guard let b = root.batchDocument else { throw BenchError.fidelity }
                return (0..<b.itemsCount).compactMap { i -> Document? in
                    guard let d = b.items(at: i) else { return nil }
                    return documentDomain(d)
                }
            case "telemetry":
                guard let b = root.batchTelemetry else { throw BenchError.fidelity }
                return (0..<b.itemsCount).compactMap { i -> Telemetry? in
                    guard let t = b.items(at: i) else { return nil }
                    return telemetryDomain(t)
                }
            case "strings":
                guard let b = root.batchStrings else { throw BenchError.fidelity }
                return (0..<b.itemsCount).compactMap { i -> Strings? in
                    guard let s = b.items(at: i) else { return nil }
                    return stringsDomain(s)
                }
            case "event":
                guard let b = root.batchEvent else { throw BenchError.fidelity }
                return (0..<b.itemsCount).compactMap { i -> Event? in
                    guard let e = b.items(at: i) else { return nil }
                    return eventDomain(e)
                }
            default:
                throw BenchError.unknownType(fixture.name)
            }
        }
        switch fixture.name {
        case "message":
            guard let m = root.message else { throw BenchError.fidelity }
            return messageDomain(m)
        case "document":
            guard let d = root.document else { throw BenchError.fidelity }
            return documentDomain(d)
        case "telemetry":
            guard let t = root.telemetry else { throw BenchError.fidelity }
            return telemetryDomain(t)
        case "strings":
            guard let s = root.strings else { throw BenchError.fidelity }
            return stringsDomain(s)
        case "event":
            guard let e = root.event else { throw BenchError.fidelity }
            return eventDomain(e)
        default:
            throw BenchError.unknownType(fixture.name)
        }
    }

    private static func encodeMessage(_ fbb: inout FlatBufferBuilder, _ m: Message) -> Offset {
        let s1 = fbb.create(string: m.f_string)
        let s2 = fbb.create(string: m.f_string_2)
        return benchmark_v2_Message.createMessage(
            &fbb, fBool: m.f_bool, fInt32: m.f_int32, fInt64: m.f_int64, fFloat64: m.f_float64,
            fStringOffset: s1, fBool2: m.f_bool_2, fInt322: m.f_int32_2, fString2Offset: s2
        )
    }
    private static func messageDomain(_ m: benchmark_v2_Message) -> Message {
        Message(
            f_bool: m.fBool, f_int32: m.fInt32, f_int64: m.fInt64, f_float64: m.fFloat64,
            f_string: m.fString ?? "", f_bool_2: m.fBool2, f_int32_2: m.fInt322, f_string_2: m.fString2 ?? ""
        )
    }

    private static func encodeDocument(_ fbb: inout FlatBufferBuilder, _ d: Document) -> Offset {
        let id = fbb.create(string: d.id)
        let region = fbb.create(string: d.meta.region)
        let meta = benchmark_v2_DocumentMeta.createDocumentMeta(&fbb, regionOffset: region, version: d.meta.version)
        var itemOffs: [Offset] = []
        itemOffs.reserveCapacity(d.items.count)
        for it in d.items {
            let sku = fbb.create(string: it.sku)
            itemOffs.append(benchmark_v2_DocumentItem.createDocumentItem(&fbb, skuOffset: sku, qty: it.qty, priceMinor: it.price_minor))
        }
        let items = fbb.createVector(ofOffsets: itemOffs)
        return benchmark_v2_Document.createDocument(&fbb, idOffset: id, status: d.status, metaOffset: meta, itemsVectorOffset: items)
    }
    private static func documentDomain(_ d: benchmark_v2_Document) -> Document {
        var items: [DocumentItem] = []
        for i in 0..<d.itemsCount {
            if let it = d.items(at: i) {
                items.append(DocumentItem(sku: it.sku ?? "", qty: it.qty, price_minor: it.priceMinor))
            }
        }
        return Document(
            id: d.id ?? "", status: d.status,
            meta: DocumentMeta(region: d.meta?.region ?? "", version: d.meta?.version ?? 0),
            items: items
        )
    }

    private static func encodeTelemetry(_ fbb: inout FlatBufferBuilder, _ t: Telemetry) -> Offset {
        let source = fbb.create(string: t.source)
        let tagOffs = t.tags.map { fbb.create(string: $0) }
        let tags = fbb.createVector(ofOffsets: tagOffs)
        let values = fbb.createVector(t.values)
        return benchmark_v2_Telemetry.createTelemetry(&fbb, sourceOffset: source, ts: t.ts, tagsVectorOffset: tags, valuesVectorOffset: values)
    }
    private static func telemetryDomain(_ t: benchmark_v2_Telemetry) -> Telemetry {
        var tags: [String] = []
        for i in 0..<t.tagsCount { tags.append(t.tags(at: i) ?? "") }
        var values: [Double] = []
        for i in 0..<t.valuesCount { values.append(t.values(at: i)) }
        return Telemetry(source: t.source ?? "", ts: t.ts, tags: tags, values: values)
    }

    private static func encodeStrings(_ fbb: inout FlatBufferBuilder, _ s: Strings) -> Offset {
        let offs = s.items.map { fbb.create(string: $0) }
        let v = fbb.createVector(ofOffsets: offs)
        return benchmark_v2_Strings.createStrings(&fbb, itemsVectorOffset: v)
    }
    private static func stringsDomain(_ s: benchmark_v2_Strings) -> Strings {
        var items: [String] = []
        for i in 0..<s.itemsCount { items.append(s.items(at: i) ?? "") }
        return Strings(items: items)
    }

    private static func encodeEvent(_ fbb: inout FlatBufferBuilder, _ e: Event) -> Offset {
        let eid = fbb.create(string: e.event_id)
        let et = fbb.create(string: e.event_type)
        let prod = fbb.create(string: e.producer)
        var attrOffs: [Offset] = []
        for a in e.attrs {
            let k = fbb.create(string: a.key)
            let v = fbb.create(string: a.value)
            attrOffs.append(benchmark_v2_EventAttr.createEventAttr(&fbb, keyOffset: k, valueOffset: v))
        }
        let attrs = fbb.createVector(ofOffsets: attrOffs)
        return benchmark_v2_Event.createEvent(&fbb, eventIdOffset: eid, eventTypeOffset: et, occurredAt: e.occurred_at, producerOffset: prod, attrsVectorOffset: attrs)
    }
    private static func eventDomain(_ e: benchmark_v2_Event) -> Event {
        var attrs: [EventAttr] = []
        for i in 0..<e.attrsCount {
            if let a = e.attrs(at: i) {
                attrs.append(EventAttr(key: a.key ?? "", value: a.value ?? ""))
            }
        }
        return Event(
            event_id: e.eventId ?? "", event_type: e.eventType ?? "",
            occurred_at: e.occurredAt, producer: e.producer ?? "", attrs: attrs
        )
    }

    private static func encodeBatchMessage(_ fbb: inout FlatBufferBuilder, _ items: [Message]) -> Offset {
        let offs = items.map { encodeMessage(&fbb, $0) }
        let v = fbb.createVector(ofOffsets: offs)
        return benchmark_v2_BatchMessage.createBatchMessage(&fbb, itemsVectorOffset: v)
    }
    private static func encodeBatchDocument(_ fbb: inout FlatBufferBuilder, _ items: [Document]) -> Offset {
        let offs = items.map { encodeDocument(&fbb, $0) }
        let v = fbb.createVector(ofOffsets: offs)
        return benchmark_v2_BatchDocument.createBatchDocument(&fbb, itemsVectorOffset: v)
    }
    private static func encodeBatchTelemetry(_ fbb: inout FlatBufferBuilder, _ items: [Telemetry]) -> Offset {
        let offs = items.map { encodeTelemetry(&fbb, $0) }
        let v = fbb.createVector(ofOffsets: offs)
        return benchmark_v2_BatchTelemetry.createBatchTelemetry(&fbb, itemsVectorOffset: v)
    }
    private static func encodeBatchStrings(_ fbb: inout FlatBufferBuilder, _ items: [Strings]) -> Offset {
        let offs = items.map { encodeStrings(&fbb, $0) }
        let v = fbb.createVector(ofOffsets: offs)
        return benchmark_v2_BatchStrings.createBatchStrings(&fbb, itemsVectorOffset: v)
    }
    private static func encodeBatchEvent(_ fbb: inout FlatBufferBuilder, _ items: [Event]) -> Offset {
        let offs = items.map { encodeEvent(&fbb, $0) }
        let v = fbb.createVector(ofOffsets: offs)
        return benchmark_v2_BatchEvent.createBatchEvent(&fbb, itemsVectorOffset: v)
    }
}
