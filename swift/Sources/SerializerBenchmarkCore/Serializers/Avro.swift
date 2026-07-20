import Foundation
import SwiftAvroCore

// MARK: - Apache Avro (SwiftAvroCore)
// Optimal: Avro().encodeFrom / decodeFrom with schema prepared outside the timed loop.
// Schemas match suite field names (f_bool, …). Wrappers select schema by fixture.name only.
// https://github.com/lynixliu/SwiftAvroCore

public final class SwiftAvroSerializer: BenchSerializer {
    public let name = "SwiftAvroCore"
    public let version: String
    public let streamMode: StreamMode = .adapted
    public let nativeKind: NativeKind = .schema

    private let avro = Avro()
    private var prepared: Fixture?
    private var schema: AvroSchema?
    /// Bound in prepare so timed path has no multi-way fixture switch (issue #59).
    private var encodeFn: ((Fixture) throws -> Data)?
    private var decodeFn: ((Data) throws -> Any)?

    public init() {
        self.version = PackageVersions.version(for: "swiftavrocore", fallback: "2.x")
    }

    public func supports(testDataName: String) -> Bool { true }

    public func prepare(_ fixture: Fixture) throws {
        prepared = fixture
        let schemaJSON = AvroSchemas.json(for: fixture)
        guard let sch = avro.decodeSchema(schema: schemaJSON) else {
            throw BenchError.unsupported("avro schema parse failed for \(fixture.name)")
        }
        schema = sch
        // Monomorphic encode/decode bound outside the timer (issue #59).
        encodeFn = AvroSchemas.bindEncode(avro: avro, schema: sch, fixture: fixture)
        decodeFn = AvroSchemas.bindDecode(avro: avro, schema: sch, fixture: fixture)
        // warm
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

/// Avro JSON schemas + encode/decode helpers (domain-aware, not in timed wrapper surface).
enum AvroSchemas {
    static func json(for fixture: Fixture) -> String {
        if fixture.instanceCount > 1 {
            return arraySchema(item: recordSchema(typeId: fixture.name))
        }
        return recordSchema(typeId: fixture.name)
    }

    private static func arraySchema(item: String) -> String {
        """
        {"type":"array","items":\(item)}
        """
    }

    private static func recordSchema(typeId: String) -> String {
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
              {"name":"f_string_2","type":"string"}
            ]}
            """
        case "document":
            return """
            {"type":"record","name":"Document","fields":[
              {"name":"id","type":"string"},
              {"name":"status","type":"int"},
              {"name":"meta","type":{"type":"record","name":"DocumentMeta","fields":[
                {"name":"region","type":"string"},{"name":"version","type":"int"}
              ]}},
              {"name":"items","type":{"type":"array","items":{"type":"record","name":"DocumentItem","fields":[
                {"name":"sku","type":"string"},{"name":"qty","type":"int"},{"name":"price_minor","type":"long"}
              ]}}}
            ]}
            """
        case "telemetry":
            return """
            {"type":"record","name":"Telemetry","fields":[
              {"name":"source","type":"string"},
              {"name":"ts","type":"long"},
              {"name":"tags","type":{"type":"array","items":"string"}},
              {"name":"values","type":{"type":"array","items":"double"}}
            ]}
            """
        case "strings":
            return """
            {"type":"record","name":"Strings","fields":[
              {"name":"items","type":{"type":"array","items":"string"}}
            ]}
            """
        case "event":
            return """
            {"type":"record","name":"Event","fields":[
              {"name":"event_id","type":"string"},
              {"name":"event_type","type":"string"},
              {"name":"occurred_at","type":"long"},
              {"name":"producer","type":"string"},
              {"name":"attrs","type":{"type":"array","items":{"type":"record","name":"EventAttr","fields":[
                {"name":"key","type":"string"},{"name":"value","type":"string"}
              ]}}}
            ]}
            """
        default:
            return """
            {"type":"record","name":"Unknown","fields":[]}
            """
        }
    }

    /// Select monomorphic encode once in prepare (no timed multi-way switch).
    static func bindEncode(avro: Avro, schema: AvroSchema, fixture: Fixture) -> (Fixture) throws -> Data {
        let batch = fixture.instanceCount > 1
        switch fixture.name {
        case "message":
            return batch
                ? { fx in try avro.encodeFrom(fx.value as! [Message], schema: schema) }
                : { fx in try avro.encodeFrom(fx.value as! Message, schema: schema) }
        case "document":
            return batch
                ? { fx in try avro.encodeFrom(fx.value as! [Document], schema: schema) }
                : { fx in try avro.encodeFrom(fx.value as! Document, schema: schema) }
        case "telemetry":
            return batch
                ? { fx in try avro.encodeFrom(fx.value as! [Telemetry], schema: schema) }
                : { fx in try avro.encodeFrom(fx.value as! Telemetry, schema: schema) }
        case "strings":
            return batch
                ? { fx in try avro.encodeFrom(fx.value as! [Strings], schema: schema) }
                : { fx in try avro.encodeFrom(fx.value as! Strings, schema: schema) }
        case "event":
            return batch
                ? { fx in try avro.encodeFrom(fx.value as! [Event], schema: schema) }
                : { fx in try avro.encodeFrom(fx.value as! Event, schema: schema) }
        default:
            let name = fixture.name
            return { _ in throw BenchError.unknownType(name) }
        }
    }

    static func bindDecode(avro: Avro, schema: AvroSchema, fixture: Fixture) -> (Data) throws -> Any {
        let batch = fixture.instanceCount > 1
        switch fixture.name {
        case "message":
            return batch
                ? { data in try avro.decodeFrom(from: data, schema: schema) as [Message] }
                : { data in try avro.decodeFrom(from: data, schema: schema) as Message }
        case "document":
            return batch
                ? { data in try avro.decodeFrom(from: data, schema: schema) as [Document] }
                : { data in try avro.decodeFrom(from: data, schema: schema) as Document }
        case "telemetry":
            return batch
                ? { data in try avro.decodeFrom(from: data, schema: schema) as [Telemetry] }
                : { data in try avro.decodeFrom(from: data, schema: schema) as Telemetry }
        case "strings":
            return batch
                ? { data in try avro.decodeFrom(from: data, schema: schema) as [Strings] }
                : { data in try avro.decodeFrom(from: data, schema: schema) as Strings }
        case "event":
            return batch
                ? { data in try avro.decodeFrom(from: data, schema: schema) as [Event] }
                : { data in try avro.decodeFrom(from: data, schema: schema) as Event }
        default:
            let name = fixture.name
            return { _ in throw BenchError.unknownType(name) }
        }
    }
}
