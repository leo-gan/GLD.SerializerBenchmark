import Foundation
import Ion

// MARK: - gld-ion (leo-gan/gld-ion-swift)
// prepare binds the document shape (monomorphic writer, Ion 1.0 binary options).
// Timed encode builds an IonDoc and calls encode(_:options:cat:).
// Timed decode is decodeBinary — the binary arm of decodeAny — then field reads.
// Catalog, EncodeOptions, and the byte buffers are reused. IonDoc has no public
// reset, so each encode allocates its own arena.
// https://github.com/leo-gan/gld-ion-swift

public final class GldIonSerializer: BenchSerializer {
    public let name = "gld-ion"
    public let version = ionVersion
    public let streamMode: StreamMode = .adapted
    public let nativeKind: NativeKind = .message

    /// Ion 1.0 binary. version 10 is the 1.0 marker (E0 01 00 EA), not Ion 1.1.
    private let options = EncodeOptions(binary: true, pretty: false, version: 10)
    private let catalog = Catalog()
    private let buffers = ReusedByteScratch()
    /// Bound in prepare — timed path has no multi-way fixture switch (issue #59).
    private var encodeFn: ((Fixture) throws -> Data)?
    private var decodeFn: ((Data) throws -> Any)?

    public init() {}

    public func supports(testDataName: String) -> Bool { testDataName != "graph" }

    public func prepare(_ fixture: Fixture) throws {
        let batch = fixture.instanceCount > 1
        let buffers = self.buffers
        let options = self.options
        let catalog = self.catalog
        switch fixture.name {
        case "message":
            encodeFn = GldIonBridge.bindEncode(
                typeName: fixture.name, batch: batch, buffers: buffers,
                options: options, catalog: catalog, write: GldIonBridge.writeMessage
            )
            decodeFn = GldIonBridge.bindDecode(
                batch: batch, buffers: buffers, catalog: catalog, read: GldIonBridge.readMessage
            )
        case "document":
            encodeFn = GldIonBridge.bindEncode(
                typeName: fixture.name, batch: batch, buffers: buffers,
                options: options, catalog: catalog, write: GldIonBridge.writeDocument
            )
            decodeFn = GldIonBridge.bindDecode(
                batch: batch, buffers: buffers, catalog: catalog, read: GldIonBridge.readDocument
            )
        case "telemetry":
            encodeFn = GldIonBridge.bindEncode(
                typeName: fixture.name, batch: batch, buffers: buffers,
                options: options, catalog: catalog, write: GldIonBridge.writeTelemetry
            )
            decodeFn = GldIonBridge.bindDecode(
                batch: batch, buffers: buffers, catalog: catalog, read: GldIonBridge.readTelemetry
            )
        case "strings":
            encodeFn = GldIonBridge.bindEncode(
                typeName: fixture.name, batch: batch, buffers: buffers,
                options: options, catalog: catalog, write: GldIonBridge.writeStrings
            )
            decodeFn = GldIonBridge.bindDecode(
                batch: batch, buffers: buffers, catalog: catalog, read: GldIonBridge.readStrings
            )
        case "event":
            encodeFn = GldIonBridge.bindEncode(
                typeName: fixture.name, batch: batch, buffers: buffers,
                options: options, catalog: catalog, write: GldIonBridge.writeEvent
            )
            decodeFn = GldIonBridge.bindDecode(
                batch: batch, buffers: buffers, catalog: catalog, read: GldIonBridge.readEvent
            )
        default:
            throw BenchError.unknownType(fixture.name)
        }
        _ = try serializeBytes(fixture)
    }

    public func serializeBytes(_ fixture: Fixture) throws -> Data {
        guard let encodeFn else { throw BenchError.prepareRequired }
        return try encodeFn(fixture)
    }

    public func deserializeBytes(_ data: Data) throws -> Any {
        guard let decodeFn else { throw BenchError.prepareRequired }
        return try decodeFn(data)
    }
}

enum GldIonBridge {
    static func bindEncode<T>(
        typeName: String,
        batch: Bool,
        buffers: ReusedByteScratch,
        options: EncodeOptions,
        catalog: Catalog,
        write: @escaping (IonDoc, T) -> Int
    ) -> (Fixture) throws -> Data {
        if batch {
            return { fx in
                guard let rows = fx.value as? [T] else {
                    throw BenchError.unsupported("gld-ion batch \(typeName)")
                }
                let doc = IonDoc()
                doc.reserve(max(32, rows.count * 8))
                let list = doc.startContainer(kList)
                for row in rows {
                    doc.addChild(list, write(doc, row), -1)
                }
                doc.addTop(list)
                return buffers.store(try encode(doc, options, catalog))
            }
        }
        return { fx in
            guard let row = fx.value as? T else {
                throw BenchError.unsupported("gld-ion \(typeName)")
            }
            let doc = IonDoc()
            doc.reserve(48)
            doc.addTop(write(doc, row))
            return buffers.store(try encode(doc, options, catalog))
        }
    }

    static func bindDecode<T>(
        batch: Bool,
        buffers: ReusedByteScratch,
        catalog: Catalog,
        read: @escaping (IonDoc, Int) throws -> T
    ) -> (Data) throws -> Any {
        if batch {
            return { data in
                let doc = try decodeBinary(buffers.copyIn(data), catalog)
                let ids = try elements(doc, try top(doc))
                var rows: [T] = []
                rows.reserveCapacity(ids.count)
                for id in ids {
                    rows.append(try read(doc, id))
                }
                return rows
            }
        }
        return { data in
            let doc = try decodeBinary(buffers.copyIn(data), catalog)
            return try read(doc, try top(doc))
        }
    }

    static func writeMessage(_ doc: IonDoc, _ m: Message) -> Int {
        let obj = doc.startContainer(kStruct)
        put(doc, obj, "f_bool", doc.addBool(m.f_bool))
        put(doc, obj, "f_int32", doc.addI64(Int64(m.f_int32)))
        put(doc, obj, "f_int64", doc.addI64(m.f_int64))
        put(doc, obj, "f_float64", doc.addFloat(8, m.f_float64.bitPattern))
        put(doc, obj, "f_string", doc.addString(m.f_string))
        put(doc, obj, "f_bool_2", doc.addBool(m.f_bool_2))
        put(doc, obj, "f_int32_2", doc.addI64(Int64(m.f_int32_2)))
        put(doc, obj, "f_string_2", doc.addString(m.f_string_2))
        return obj
    }

    static func readMessage(_ doc: IonDoc, _ id: Int) throws -> Message {
        Message(
            f_bool: try asBool(doc, try field(doc, id, "f_bool")),
            f_int32: try i32(doc, try field(doc, id, "f_int32")),
            f_int64: try asI64(doc, try field(doc, id, "f_int64")),
            f_float64: try asF64(doc, try field(doc, id, "f_float64")),
            f_string: try asString(doc, try field(doc, id, "f_string")),
            f_bool_2: try asBool(doc, try field(doc, id, "f_bool_2")),
            f_int32_2: try i32(doc, try field(doc, id, "f_int32_2")),
            f_string_2: try asString(doc, try field(doc, id, "f_string_2"))
        )
    }

    static func writeDocument(_ doc: IonDoc, _ d: Document) -> Int {
        let obj = doc.startContainer(kStruct)
        put(doc, obj, "id", doc.addString(d.id))
        put(doc, obj, "status", doc.addI64(Int64(d.status)))
        let meta = doc.startContainer(kStruct)
        put(doc, meta, "region", doc.addString(d.meta.region))
        put(doc, meta, "version", doc.addI64(Int64(d.meta.version)))
        put(doc, obj, "meta", meta)
        let items = doc.startContainer(kList)
        for item in d.items {
            doc.addChild(items, writeItem(doc, item), -1)
        }
        put(doc, obj, "items", items)
        return obj
    }

    static func readDocument(_ doc: IonDoc, _ id: Int) throws -> Document {
        let meta = try field(doc, id, "meta")
        let itemIds = try elements(doc, try field(doc, id, "items"))
        var items: [DocumentItem] = []
        items.reserveCapacity(itemIds.count)
        for item in itemIds {
            items.append(try readItem(doc, item))
        }
        return Document(
            id: try asString(doc, try field(doc, id, "id")),
            status: try i32(doc, try field(doc, id, "status")),
            meta: DocumentMeta(
                region: try asString(doc, try field(doc, meta, "region")),
                version: try i32(doc, try field(doc, meta, "version"))
            ),
            items: items
        )
    }

    static func writeTelemetry(_ doc: IonDoc, _ t: Telemetry) -> Int {
        let obj = doc.startContainer(kStruct)
        put(doc, obj, "source", doc.addString(t.source))
        put(doc, obj, "ts", doc.addI64(t.ts))
        let tags = doc.startContainer(kList)
        for tag in t.tags {
            doc.addChild(tags, doc.addString(tag), -1)
        }
        put(doc, obj, "tags", tags)
        let values = doc.startContainer(kList)
        for value in t.values {
            doc.addChild(values, doc.addFloat(8, value.bitPattern), -1)
        }
        put(doc, obj, "values", values)
        return obj
    }

    static func readTelemetry(_ doc: IonDoc, _ id: Int) throws -> Telemetry {
        let tagIds = try elements(doc, try field(doc, id, "tags"))
        var tags: [String] = []
        tags.reserveCapacity(tagIds.count)
        for tag in tagIds {
            tags.append(try asString(doc, tag))
        }
        let valueIds = try elements(doc, try field(doc, id, "values"))
        var values: [Double] = []
        values.reserveCapacity(valueIds.count)
        for value in valueIds {
            values.append(try asF64(doc, value))
        }
        return Telemetry(
            source: try asString(doc, try field(doc, id, "source")),
            ts: try asI64(doc, try field(doc, id, "ts")),
            tags: tags,
            values: values
        )
    }

    static func writeStrings(_ doc: IonDoc, _ s: Strings) -> Int {
        let obj = doc.startContainer(kStruct)
        let items = doc.startContainer(kList)
        for item in s.items {
            doc.addChild(items, doc.addString(item), -1)
        }
        put(doc, obj, "items", items)
        return obj
    }

    static func readStrings(_ doc: IonDoc, _ id: Int) throws -> Strings {
        let ids = try elements(doc, try field(doc, id, "items"))
        var items: [String] = []
        items.reserveCapacity(ids.count)
        for item in ids {
            items.append(try asString(doc, item))
        }
        return Strings(items: items)
    }

    static func writeEvent(_ doc: IonDoc, _ event: Event) -> Int {
        let obj = doc.startContainer(kStruct)
        put(doc, obj, "event_id", doc.addString(event.event_id))
        put(doc, obj, "event_type", doc.addString(event.event_type))
        put(doc, obj, "occurred_at", doc.addI64(event.occurred_at))
        put(doc, obj, "producer", doc.addString(event.producer))
        let attrs = doc.startContainer(kList)
        for attr in event.attrs {
            doc.addChild(attrs, writeAttr(doc, attr), -1)
        }
        put(doc, obj, "attrs", attrs)
        return obj
    }

    static func readEvent(_ doc: IonDoc, _ id: Int) throws -> Event {
        let attrIds = try elements(doc, try field(doc, id, "attrs"))
        var attrs: [EventAttr] = []
        attrs.reserveCapacity(attrIds.count)
        for attr in attrIds {
            attrs.append(EventAttr(
                key: try asString(doc, try field(doc, attr, "key")),
                value: try asString(doc, try field(doc, attr, "value"))
            ))
        }
        return Event(
            event_id: try asString(doc, try field(doc, id, "event_id")),
            event_type: try asString(doc, try field(doc, id, "event_type")),
            occurred_at: try asI64(doc, try field(doc, id, "occurred_at")),
            producer: try asString(doc, try field(doc, id, "producer")),
            attrs: attrs
        )
    }

    private static func writeItem(_ doc: IonDoc, _ item: DocumentItem) -> Int {
        let obj = doc.startContainer(kStruct)
        put(doc, obj, "sku", doc.addString(item.sku))
        put(doc, obj, "qty", doc.addI64(Int64(item.qty)))
        put(doc, obj, "price_minor", doc.addI64(item.price_minor))
        return obj
    }

    private static func readItem(_ doc: IonDoc, _ id: Int) throws -> DocumentItem {
        DocumentItem(
            sku: try asString(doc, try field(doc, id, "sku")),
            qty: try i32(doc, try field(doc, id, "qty")),
            price_minor: try asI64(doc, try field(doc, id, "price_minor"))
        )
    }

    private static func writeAttr(_ doc: IonDoc, _ attr: EventAttr) -> Int {
        let obj = doc.startContainer(kStruct)
        put(doc, obj, "key", doc.addString(attr.key))
        put(doc, obj, "value", doc.addString(attr.value))
        return obj
    }

    private static func put(_ doc: IonDoc, _ parent: Int, _ name: String, _ child: Int) {
        let sym = doc.addSymbolText(name)
        doc.addChild(parent, child, doc.nodes[sym].a)
    }

    private static func top(_ doc: IonDoc) throws -> Int {
        guard let id = doc.top.first else {
            throw BenchError.unsupported("gld-ion empty")
        }
        return id
    }

    private static func field(_ doc: IonDoc, _ parent: Int, _ name: String) throws -> Int {
        let node = doc.nodes[parent]
        if node.kind != kStruct {
            throw BenchError.unsupported("gld-ion struct")
        }
        var edge = node.child
        var i = 0
        while i < node.nchild {
            let sym = doc.edges[edge].field
            if sym >= 0 && doc.symText(sym) == name {
                return doc.edges[edge].child
            }
            edge = doc.edges[edge].next
            i += 1
        }
        throw BenchError.unsupported("gld-ion field \(name)")
    }

    private static func elements(_ doc: IonDoc, _ id: Int) throws -> [Int] {
        let node = doc.nodes[id]
        if node.kind != kList {
            throw BenchError.unsupported("gld-ion list")
        }
        var out: [Int] = []
        out.reserveCapacity(node.nchild)
        var edge = node.child
        var i = 0
        while i < node.nchild {
            out.append(doc.edges[edge].child)
            edge = doc.edges[edge].next
            i += 1
        }
        return out
    }

    private static func i32(_ doc: IonDoc, _ id: Int) throws -> Int32 {
        let value = try asI64(doc, id)
        guard let n = Int32(exactly: value) else {
            throw BenchError.unsupported("gld-ion int32")
        }
        return n
    }
}
