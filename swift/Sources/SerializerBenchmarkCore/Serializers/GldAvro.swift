import Foundation
import Avro

// MARK: - gld-avro (leo-gan/gld-avro-swift)
// prepare parses the schema once. Timed calls build an AvroValue and use
// encodeGeneric / decodeGeneric. Output Data and the decode byte buffer keep
// their capacity; encodeGeneric reuses the library encoder scratch.
// https://github.com/leo-gan/gld-avro-swift

public final class GldAvroSerializer: BenchSerializer {
    public let name = "gld-avro"
    public let version = avroLibraryVersion
    public let streamMode: StreamMode = .adapted
    public let nativeKind: NativeKind = .schema

    private let buffers = ReusedByteScratch()
    /// Bound in prepare — timed path has no multi-way fixture switch (issue #59).
    private var encodeFn: ((Fixture) throws -> Data)?
    private var decodeFn: ((Data) throws -> Any)?

    public init() {}

    public func supports(testDataName: String) -> Bool { testDataName != "graph" }

    public func prepare(_ fixture: Fixture) throws {
        let batch = fixture.instanceCount > 1
        let pool = try parseAvsc(try GldAvroBridge.json(for: fixture))
        let buffers = self.buffers
        switch fixture.name {
        case "message":
            encodeFn = GldAvroBridge.bindEncode(
                typeName: fixture.name, batch: batch, pool: pool, buffers: buffers,
                write: GldAvroBridge.messageValue
            )
            decodeFn = GldAvroBridge.bindDecode(
                batch: batch, pool: pool, buffers: buffers, read: GldAvroBridge.message
            )
        case "document":
            encodeFn = GldAvroBridge.bindEncode(
                typeName: fixture.name, batch: batch, pool: pool, buffers: buffers,
                write: GldAvroBridge.documentValue
            )
            decodeFn = GldAvroBridge.bindDecode(
                batch: batch, pool: pool, buffers: buffers, read: GldAvroBridge.document
            )
        case "telemetry":
            encodeFn = GldAvroBridge.bindEncode(
                typeName: fixture.name, batch: batch, pool: pool, buffers: buffers,
                write: GldAvroBridge.telemetryValue
            )
            decodeFn = GldAvroBridge.bindDecode(
                batch: batch, pool: pool, buffers: buffers, read: GldAvroBridge.telemetry
            )
        case "strings":
            encodeFn = GldAvroBridge.bindEncode(
                typeName: fixture.name, batch: batch, pool: pool, buffers: buffers,
                write: GldAvroBridge.stringsValue
            )
            decodeFn = GldAvroBridge.bindDecode(
                batch: batch, pool: pool, buffers: buffers, read: GldAvroBridge.strings
            )
        case "event":
            encodeFn = GldAvroBridge.bindEncode(
                typeName: fixture.name, batch: batch, pool: pool, buffers: buffers,
                write: GldAvroBridge.eventValue
            )
            decodeFn = GldAvroBridge.bindDecode(
                batch: batch, pool: pool, buffers: buffers, read: GldAvroBridge.event
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

/// Encode `Data` and decode `[UInt8]` keep capacity across repetitions.
final class ReusedByteScratch {
    private var encoded = Data()
    private var raw: [UInt8] = []

    func store(_ bytes: [UInt8]) -> Data {
        encoded.removeAll(keepingCapacity: true)
        encoded.reserveCapacity(bytes.count)
        encoded.append(contentsOf: bytes)
        return encoded
    }

    func copyIn(_ data: Data) -> [UInt8] {
        raw.removeAll(keepingCapacity: true)
        if raw.capacity < data.count {
            raw.reserveCapacity(data.count)
        }
        raw.append(contentsOf: data)
        return raw
    }
}

enum GldAvroBridge {
    static func json(for fixture: Fixture) throws -> String {
        let record = try recordSchema(fixture.name)
        if fixture.instanceCount > 1 {
            return "{\"type\":\"array\",\"items\":\(record)}"
        }
        return record
    }

    private static func recordSchema(_ typeId: String) throws -> String {
        switch typeId {
        case "message":
            return """
            {"type":"record","name":"Message","fields":[
            {"name":"f_bool","type":"boolean"},
            {"name":"f_int32","type":"int"},
            {"name":"f_int64","type":"long"},
            {"name":"f_float64","type":"double"},
            {"name":"f_string","type":"string"},
            {"name":"f_bool_2","type":"boolean"},
            {"name":"f_int32_2","type":"int"},
            {"name":"f_string_2","type":"string"}]}
            """
        case "document":
            return """
            {"type":"record","name":"Document","fields":[
            {"name":"id","type":"string"},
            {"name":"status","type":"int"},
            {"name":"meta","type":{"type":"record","name":"DocumentMeta","fields":[
            {"name":"region","type":"string"},{"name":"version","type":"int"}]}},
            {"name":"items","type":{"type":"array","items":{"type":"record","name":"DocumentItem","fields":[
            {"name":"sku","type":"string"},{"name":"qty","type":"int"},{"name":"price_minor","type":"long"}]}}}]}
            """
        case "telemetry":
            return """
            {"type":"record","name":"Telemetry","fields":[
            {"name":"source","type":"string"},
            {"name":"ts","type":"long"},
            {"name":"tags","type":{"type":"array","items":"string"}},
            {"name":"values","type":{"type":"array","items":"double"}}]}
            """
        case "strings":
            return """
            {"type":"record","name":"Strings","fields":[
            {"name":"items","type":{"type":"array","items":"string"}}]}
            """
        case "event":
            return """
            {"type":"record","name":"Event","fields":[
            {"name":"event_id","type":"string"},
            {"name":"event_type","type":"string"},
            {"name":"occurred_at","type":"long"},
            {"name":"producer","type":"string"},
            {"name":"attrs","type":{"type":"array","items":{"type":"record","name":"EventAttr","fields":[
            {"name":"key","type":"string"},{"name":"value","type":"string"}]}}}]}
            """
        default:
            throw BenchError.unknownType(typeId)
        }
    }

    static func bindEncode<T>(
        typeName: String,
        batch: Bool,
        pool: SchemaPool,
        buffers: ReusedByteScratch,
        write: @escaping (T) -> AvroValue
    ) -> (Fixture) throws -> Data {
        if batch {
            return { fx in
                guard let rows = fx.value as? [T] else {
                    throw BenchError.unsupported("gld-avro batch \(typeName)")
                }
                let value = AvroValue.array(rows.map(write))
                return buffers.store(try encodeGeneric(value, pool: pool))
            }
        }
        return { fx in
            guard let row = fx.value as? T else {
                throw BenchError.unsupported("gld-avro \(typeName)")
            }
            return buffers.store(try encodeGeneric(write(row), pool: pool))
        }
    }

    static func bindDecode<T>(
        batch: Bool,
        pool: SchemaPool,
        buffers: ReusedByteScratch,
        read: @escaping (AvroValue) throws -> T
    ) -> (Data) throws -> Any {
        if batch {
            return { data in
                let value = try decodeGeneric(buffers.copyIn(data), pool: pool)
                let items = try AvroResolved.array(value)
                var rows: [T] = []
                rows.reserveCapacity(items.count)
                for item in items {
                    rows.append(try read(item))
                }
                return rows
            }
        }
        return { data in
            let value = try decodeGeneric(buffers.copyIn(data), pool: pool)
            return try read(value)
        }
    }

    static func messageValue(_ m: Message) -> AvroValue {
        .record([
            .boolean(m.f_bool),
            .int(m.f_int32),
            .long(m.f_int64),
            .double(m.f_float64),
            .string(m.f_string),
            .boolean(m.f_bool_2),
            .int(m.f_int32_2),
            .string(m.f_string_2),
        ])
    }

    static func message(_ value: AvroValue) throws -> Message {
        let f = try AvroResolved.record(value, count: 8)
        return Message(
            f_bool: try AvroResolved.bool(f[0]),
            f_int32: try AvroResolved.int32(f[1]),
            f_int64: try AvroResolved.int64(f[2]),
            f_float64: try AvroResolved.float64(f[3]),
            f_string: try AvroResolved.string(f[4]),
            f_bool_2: try AvroResolved.bool(f[5]),
            f_int32_2: try AvroResolved.int32(f[6]),
            f_string_2: try AvroResolved.string(f[7])
        )
    }

    static func documentValue(_ d: Document) -> AvroValue {
        .record([
            .string(d.id),
            .int(d.status),
            .record([
                .string(d.meta.region),
                .int(d.meta.version),
            ]),
            .array(d.items.map { item in
                AvroValue.record([
                    .string(item.sku),
                    .int(item.qty),
                    .long(item.price_minor),
                ])
            }),
        ])
    }

    static func document(_ value: AvroValue) throws -> Document {
        let f = try AvroResolved.record(value, count: 4)
        let meta = try AvroResolved.record(f[2], count: 2)
        let rawItems = try AvroResolved.array(f[3])
        var items: [DocumentItem] = []
        items.reserveCapacity(rawItems.count)
        for raw in rawItems {
            let item = try AvroResolved.record(raw, count: 3)
            items.append(DocumentItem(
                sku: try AvroResolved.string(item[0]),
                qty: try AvroResolved.int32(item[1]),
                price_minor: try AvroResolved.int64(item[2])
            ))
        }
        return Document(
            id: try AvroResolved.string(f[0]),
            status: try AvroResolved.int32(f[1]),
            meta: DocumentMeta(
                region: try AvroResolved.string(meta[0]),
                version: try AvroResolved.int32(meta[1])
            ),
            items: items
        )
    }

    static func telemetryValue(_ t: Telemetry) -> AvroValue {
        .record([
            .string(t.source),
            .long(t.ts),
            .array(t.tags.map { AvroValue.string($0) }),
            .array(t.values.map { AvroValue.double($0) }),
        ])
    }

    static func telemetry(_ value: AvroValue) throws -> Telemetry {
        let f = try AvroResolved.record(value, count: 4)
        let rawTags = try AvroResolved.array(f[2])
        var tags: [String] = []
        tags.reserveCapacity(rawTags.count)
        for tag in rawTags {
            tags.append(try AvroResolved.string(tag))
        }
        let rawValues = try AvroResolved.array(f[3])
        var values: [Double] = []
        values.reserveCapacity(rawValues.count)
        for item in rawValues {
            values.append(try AvroResolved.float64(item))
        }
        return Telemetry(
            source: try AvroResolved.string(f[0]),
            ts: try AvroResolved.int64(f[1]),
            tags: tags,
            values: values
        )
    }

    static func stringsValue(_ s: Strings) -> AvroValue {
        .record([
            .array(s.items.map { AvroValue.string($0) }),
        ])
    }

    static func strings(_ value: AvroValue) throws -> Strings {
        let f = try AvroResolved.record(value, count: 1)
        let raw = try AvroResolved.array(f[0])
        var items: [String] = []
        items.reserveCapacity(raw.count)
        for item in raw {
            items.append(try AvroResolved.string(item))
        }
        return Strings(items: items)
    }

    static func eventValue(_ event: Event) -> AvroValue {
        .record([
            .string(event.event_id),
            .string(event.event_type),
            .long(event.occurred_at),
            .string(event.producer),
            .array(event.attrs.map { attr in
                AvroValue.record([
                    .string(attr.key),
                    .string(attr.value),
                ])
            }),
        ])
    }

    static func event(_ value: AvroValue) throws -> Event {
        let f = try AvroResolved.record(value, count: 5)
        let raw = try AvroResolved.array(f[4])
        var attrs: [EventAttr] = []
        attrs.reserveCapacity(raw.count)
        for item in raw {
            let attr = try AvroResolved.record(item, count: 2)
            attrs.append(EventAttr(
                key: try AvroResolved.string(attr[0]),
                value: try AvroResolved.string(attr[1])
            ))
        }
        return Event(
            event_id: try AvroResolved.string(f[0]),
            event_type: try AvroResolved.string(f[1]),
            occurred_at: try AvroResolved.int64(f[2]),
            producer: try AvroResolved.string(f[3]),
            attrs: attrs
        )
    }
}
