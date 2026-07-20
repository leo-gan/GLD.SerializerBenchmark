import Foundation
import FlatBuffers

enum FlatBuffersBridge {
    /// Bind monomorphic encode once in prepare (issue #59).
    static func bindEncode(for fixture: Fixture) throws -> (inout FlatBufferBuilder, Fixture) throws -> Data {
        let batch = fixture.instanceCount > 1
        switch fixture.name {
        case "message":
            return batch
                ? { fbb, fx in
                    let batchOff = encodeBatchMessage(&fbb, fx.value as! [Message])
                    let root = benchmark_v2_FixtureRoot.createFixtureRoot(
                        &fbb, kind: .batchmessage, batchMessageOffset: batchOff)
                    fbb.finish(offset: root)
                    return Data(fbb.sizedByteArray)
                }
                : { fbb, fx in
                    let o = encodeMessage(&fbb, fx.value as! Message)
                    let root = benchmark_v2_FixtureRoot.createFixtureRoot(
                        &fbb, kind: .message, messageOffset: o)
                    fbb.finish(offset: root)
                    return Data(fbb.sizedByteArray)
                }
        case "document":
            return batch
                ? { fbb, fx in
                    let batchOff = encodeBatchDocument(&fbb, fx.value as! [Document])
                    let root = benchmark_v2_FixtureRoot.createFixtureRoot(
                        &fbb, kind: .batchdocument, batchDocumentOffset: batchOff)
                    fbb.finish(offset: root)
                    return Data(fbb.sizedByteArray)
                }
                : { fbb, fx in
                    let o = encodeDocument(&fbb, fx.value as! Document)
                    let root = benchmark_v2_FixtureRoot.createFixtureRoot(
                        &fbb, kind: .document, documentOffset: o)
                    fbb.finish(offset: root)
                    return Data(fbb.sizedByteArray)
                }
        case "telemetry":
            return batch
                ? { fbb, fx in
                    let batchOff = encodeBatchTelemetry(&fbb, fx.value as! [Telemetry])
                    let root = benchmark_v2_FixtureRoot.createFixtureRoot(
                        &fbb, kind: .batchtelemetry, batchTelemetryOffset: batchOff)
                    fbb.finish(offset: root)
                    return Data(fbb.sizedByteArray)
                }
                : { fbb, fx in
                    let o = encodeTelemetry(&fbb, fx.value as! Telemetry)
                    let root = benchmark_v2_FixtureRoot.createFixtureRoot(
                        &fbb, kind: .telemetry, telemetryOffset: o)
                    fbb.finish(offset: root)
                    return Data(fbb.sizedByteArray)
                }
        case "strings":
            return batch
                ? { fbb, fx in
                    let batchOff = encodeBatchStrings(&fbb, fx.value as! [Strings])
                    let root = benchmark_v2_FixtureRoot.createFixtureRoot(
                        &fbb, kind: .batchstrings, batchStringsOffset: batchOff)
                    fbb.finish(offset: root)
                    return Data(fbb.sizedByteArray)
                }
                : { fbb, fx in
                    let o = encodeStrings(&fbb, fx.value as! Strings)
                    let root = benchmark_v2_FixtureRoot.createFixtureRoot(
                        &fbb, kind: .strings, stringsOffset: o)
                    fbb.finish(offset: root)
                    return Data(fbb.sizedByteArray)
                }
        case "event":
            return batch
                ? { fbb, fx in
                    let batchOff = encodeBatchEvent(&fbb, fx.value as! [Event])
                    let root = benchmark_v2_FixtureRoot.createFixtureRoot(
                        &fbb, kind: .batchevent, batchEventOffset: batchOff)
                    fbb.finish(offset: root)
                    return Data(fbb.sizedByteArray)
                }
                : { fbb, fx in
                    let o = encodeEvent(&fbb, fx.value as! Event)
                    let root = benchmark_v2_FixtureRoot.createFixtureRoot(
                        &fbb, kind: .event, eventOffset: o)
                    fbb.finish(offset: root)
                    return Data(fbb.sizedByteArray)
                }
        default:
            throw BenchError.unknownType(fixture.name)
        }
    }

    static func bindDecode(for fixture: Fixture) throws -> (Data) throws -> Any {
        let batch = fixture.instanceCount > 1
        switch fixture.name {
        case "message":
            return batch
                ? { data in
                    var bytes = ByteBuffer(data: data)
                    let root: benchmark_v2_FixtureRoot = getRoot(byteBuffer: &bytes)
                    guard let b = root.batchMessage else { throw BenchError.fidelity }
                    return (0..<b.itemsCount).compactMap { i -> Message? in
                        guard let m = b.items(at: i) else { return nil }
                        return messageDomain(m)
                    }
                }
                : { data in
                    var bytes = ByteBuffer(data: data)
                    let root: benchmark_v2_FixtureRoot = getRoot(byteBuffer: &bytes)
                    guard let m = root.message else { throw BenchError.fidelity }
                    return messageDomain(m)
                }
        case "document":
            return batch
                ? { data in
                    var bytes = ByteBuffer(data: data)
                    let root: benchmark_v2_FixtureRoot = getRoot(byteBuffer: &bytes)
                    guard let b = root.batchDocument else { throw BenchError.fidelity }
                    return (0..<b.itemsCount).compactMap { i -> Document? in
                        guard let d = b.items(at: i) else { return nil }
                        return documentDomain(d)
                    }
                }
                : { data in
                    var bytes = ByteBuffer(data: data)
                    let root: benchmark_v2_FixtureRoot = getRoot(byteBuffer: &bytes)
                    guard let d = root.document else { throw BenchError.fidelity }
                    return documentDomain(d)
                }
        case "telemetry":
            return batch
                ? { data in
                    var bytes = ByteBuffer(data: data)
                    let root: benchmark_v2_FixtureRoot = getRoot(byteBuffer: &bytes)
                    guard let b = root.batchTelemetry else { throw BenchError.fidelity }
                    return (0..<b.itemsCount).compactMap { i -> Telemetry? in
                        guard let t = b.items(at: i) else { return nil }
                        return telemetryDomain(t)
                    }
                }
                : { data in
                    var bytes = ByteBuffer(data: data)
                    let root: benchmark_v2_FixtureRoot = getRoot(byteBuffer: &bytes)
                    guard let t = root.telemetry else { throw BenchError.fidelity }
                    return telemetryDomain(t)
                }
        case "strings":
            return batch
                ? { data in
                    var bytes = ByteBuffer(data: data)
                    let root: benchmark_v2_FixtureRoot = getRoot(byteBuffer: &bytes)
                    guard let b = root.batchStrings else { throw BenchError.fidelity }
                    return (0..<b.itemsCount).compactMap { i -> Strings? in
                        guard let s = b.items(at: i) else { return nil }
                        return stringsDomain(s)
                    }
                }
                : { data in
                    var bytes = ByteBuffer(data: data)
                    let root: benchmark_v2_FixtureRoot = getRoot(byteBuffer: &bytes)
                    guard let s = root.strings else { throw BenchError.fidelity }
                    return stringsDomain(s)
                }
        case "event":
            return batch
                ? { data in
                    var bytes = ByteBuffer(data: data)
                    let root: benchmark_v2_FixtureRoot = getRoot(byteBuffer: &bytes)
                    guard let b = root.batchEvent else { throw BenchError.fidelity }
                    return (0..<b.itemsCount).compactMap { i -> Event? in
                        guard let e = b.items(at: i) else { return nil }
                        return eventDomain(e)
                    }
                }
                : { data in
                    var bytes = ByteBuffer(data: data)
                    let root: benchmark_v2_FixtureRoot = getRoot(byteBuffer: &bytes)
                    guard let e = root.event else { throw BenchError.fidelity }
                    return eventDomain(e)
                }
        default:
            throw BenchError.unknownType(fixture.name)
        }
    }

    static func encode(into fbb: inout FlatBufferBuilder, fixture: Fixture) throws -> Data {
        try bindEncode(for: fixture)(&fbb, fixture)
    }

    static func encode(_ fixture: Fixture) throws -> Data {
        var fbb = FlatBufferBuilder(initialSize: 1024)
        return try encode(into: &fbb, fixture: fixture)
    }

    static func decode(_ data: Data, fixture: Fixture) throws -> Any {
        try bindDecode(for: fixture)(data)
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
