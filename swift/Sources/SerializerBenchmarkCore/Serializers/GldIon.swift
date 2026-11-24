import Foundation
import Ion

// MARK: - gld-ion (leo-gan/gld-ion-swift)
// prepare binds the record shape. Timed encode and decode use encodeTree and
// decodeTree, which write Ion 1.0 binary without an IonDoc.
// https://github.com/leo-gan/gld-ion-swift

public final class GldIonSerializer: BenchSerializer {
    public let name = "gld-ion"
    public let version = ionVersion
    public let streamMode: StreamMode = .adapted
    public let nativeKind: NativeKind = .message

    private let buffers = ReusedByteScratch()
    /// Bound in prepare — timed path has no multi-way fixture switch (issue #59).
    private var encodeFn: ((Fixture) throws -> Data)?
    private var decodeFn: ((Data) throws -> Any)?

    public init() {}

    public func supports(testDataName: String) -> Bool { testDataName != "graph" }

    public func prepare(_ fixture: Fixture) throws {
        let batch = fixture.instanceCount > 1
        let buffers = self.buffers
        switch fixture.name {
        case "message":
            encodeFn = GldIonBridge.bindEncode(
                typeName: fixture.name, batch: batch, buffers: buffers, tree: GldIonBridge.messageTree
            )
            decodeFn = GldIonBridge.bindDecode(batch: batch, buffers: buffers, read: GldIonBridge.readMessage)
        case "document":
            encodeFn = GldIonBridge.bindEncode(
                typeName: fixture.name, batch: batch, buffers: buffers, tree: GldIonBridge.documentTree
            )
            decodeFn = GldIonBridge.bindDecode(batch: batch, buffers: buffers, read: GldIonBridge.readDocument)
        case "telemetry":
            encodeFn = GldIonBridge.bindEncode(
                typeName: fixture.name, batch: batch, buffers: buffers, tree: GldIonBridge.telemetryTree
            )
            decodeFn = GldIonBridge.bindDecode(batch: batch, buffers: buffers, read: GldIonBridge.readTelemetry)
        case "strings":
            encodeFn = GldIonBridge.bindEncode(
                typeName: fixture.name, batch: batch, buffers: buffers, tree: GldIonBridge.stringsTree
            )
            decodeFn = GldIonBridge.bindDecode(batch: batch, buffers: buffers, read: GldIonBridge.readStrings)
        case "event":
            encodeFn = GldIonBridge.bindEncode(
                typeName: fixture.name, batch: batch, buffers: buffers, tree: GldIonBridge.eventTree
            )
            decodeFn = GldIonBridge.bindDecode(batch: batch, buffers: buffers, read: GldIonBridge.readEvent)
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
        tree: @escaping (T) -> IonTree
    ) -> (Fixture) throws -> Data {
        if batch {
            return { fx in
                guard let rows = fx.value as? [T] else {
                    throw BenchError.unsupported("gld-ion batch \(typeName)")
                }
                return buffers.store(encodeTree(.list(rows.map(tree))))
            }
        }
        return { fx in
            guard let row = fx.value as? T else {
                throw BenchError.unsupported("gld-ion \(typeName)")
            }
            return buffers.store(encodeTree(tree(row)))
        }
    }

    static func bindDecode<T>(
        batch: Bool,
        buffers: ReusedByteScratch,
        read: @escaping (IonTree) throws -> T
    ) -> (Data) throws -> Any {
        if batch {
            return { data in
                guard case .list(let items) = try decodeTree(buffers.copyIn(data)) else {
                    throw BenchError.unsupported("gld-ion batch")
                }
                return try items.map(read)
            }
        }
        return { data in
            try read(decodeTree(buffers.copyIn(data)))
        }
    }

    static func messageTree(_ m: Message) -> IonTree {
        .fields([
            ("f_bool", .bool(m.f_bool)),
            ("f_int32", .int(Int64(m.f_int32))),
            ("f_int64", .int(m.f_int64)),
            ("f_float64", .float(m.f_float64)),
            ("f_string", .string(m.f_string)),
            ("f_bool_2", .bool(m.f_bool_2)),
            ("f_int32_2", .int(Int64(m.f_int32_2))),
            ("f_string_2", .string(m.f_string_2)),
        ])
    }

    static func readMessage(_ tree: IonTree) throws -> Message {
        Message(
            f_bool: try bool(tree, "f_bool"),
            f_int32: try i32(tree, "f_int32"),
            f_int64: try i64(tree, "f_int64"),
            f_float64: try f64(tree, "f_float64"),
            f_string: try str(tree, "f_string"),
            f_bool_2: try bool(tree, "f_bool_2"),
            f_int32_2: try i32(tree, "f_int32_2"),
            f_string_2: try str(tree, "f_string_2")
        )
    }

    static func documentTree(_ d: Document) -> IonTree {
        .fields([
            ("id", .string(d.id)),
            ("status", .int(Int64(d.status))),
            ("meta", .fields([
                ("region", .string(d.meta.region)),
                ("version", .int(Int64(d.meta.version))),
            ])),
            ("items", .list(d.items.map { item in
                .fields([
                    ("sku", .string(item.sku)),
                    ("qty", .int(Int64(item.qty))),
                    ("price_minor", .int(item.price_minor)),
                ])
            })),
        ])
    }

    static func readDocument(_ tree: IonTree) throws -> Document {
        let meta = try field(tree, "meta")
        return Document(
            id: try str(tree, "id"),
            status: try i32(tree, "status"),
            meta: DocumentMeta(region: try str(meta, "region"), version: try i32(meta, "version")),
            items: try list(tree, "items").map { item in
                DocumentItem(sku: try str(item, "sku"), qty: try i32(item, "qty"), price_minor: try i64(item, "price_minor"))
            }
        )
    }

    static func telemetryTree(_ t: Telemetry) -> IonTree {
        .fields([
            ("source", .string(t.source)),
            ("ts", .int(t.ts)),
            ("tags", .list(t.tags.map { .string($0) })),
            ("values", .list(t.values.map { .float($0) })),
        ])
    }

    static func readTelemetry(_ tree: IonTree) throws -> Telemetry {
        Telemetry(
            source: try str(tree, "source"),
            ts: try i64(tree, "ts"),
            tags: try list(tree, "tags").map { try text($0) },
            values: try list(tree, "values").map { try number($0) }
        )
    }

    static func stringsTree(_ s: Strings) -> IonTree {
        .fields([("items", .list(s.items.map { .string($0) }))])
    }

    static func readStrings(_ tree: IonTree) throws -> Strings {
        Strings(items: try list(tree, "items").map { try text($0) })
    }

    static func eventTree(_ event: Event) -> IonTree {
        .fields([
            ("event_id", .string(event.event_id)),
            ("event_type", .string(event.event_type)),
            ("occurred_at", .int(event.occurred_at)),
            ("producer", .string(event.producer)),
            ("attrs", .list(event.attrs.map { attr in
                .fields([("key", .string(attr.key)), ("value", .string(attr.value))])
            })),
        ])
    }

    static func readEvent(_ tree: IonTree) throws -> Event {
        Event(
            event_id: try str(tree, "event_id"),
            event_type: try str(tree, "event_type"),
            occurred_at: try i64(tree, "occurred_at"),
            producer: try str(tree, "producer"),
            attrs: try list(tree, "attrs").map { attr in
                EventAttr(key: try str(attr, "key"), value: try str(attr, "value"))
            }
        )
    }

    private static func field(_ tree: IonTree, _ name: String) throws -> IonTree {
        guard case .fields(let pairs) = tree else { throw BenchError.unsupported("gld-ion struct") }
        for pair in pairs where pair.0 == name { return pair.1 }
        throw BenchError.unsupported("gld-ion field \(name)")
    }

    private static func list(_ tree: IonTree, _ name: String) throws -> [IonTree] {
        guard case .list(let items) = try field(tree, name) else { throw BenchError.unsupported("gld-ion list") }
        return items
    }

    private static func bool(_ tree: IonTree, _ name: String) throws -> Bool {
        guard case .bool(let v) = try field(tree, name) else { throw BenchError.unsupported("gld-ion bool") }
        return v
    }

    private static func i64(_ tree: IonTree, _ name: String) throws -> Int64 {
        guard case .int(let v) = try field(tree, name) else { throw BenchError.unsupported("gld-ion int") }
        return v
    }

    private static func i32(_ tree: IonTree, _ name: String) throws -> Int32 {
        guard let n = Int32(exactly: try i64(tree, name)) else { throw BenchError.unsupported("gld-ion int32") }
        return n
    }

    private static func f64(_ tree: IonTree, _ name: String) throws -> Double {
        try number(field(tree, name))
    }

    private static func str(_ tree: IonTree, _ name: String) throws -> String {
        try text(field(tree, name))
    }

    private static func text(_ tree: IonTree) throws -> String {
        guard case .string(let v) = tree else { throw BenchError.unsupported("gld-ion string") }
        return v
    }

    private static func number(_ tree: IonTree) throws -> Double {
        if case .float(let v) = tree { return v }
        if case .int(let v) = tree { return Double(v) }
        throw BenchError.unsupported("gld-ion float")
    }
}
