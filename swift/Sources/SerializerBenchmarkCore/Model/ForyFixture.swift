import Foundation
import Fory

// The model owns concrete type registration and the scalar/batch dispatch.
extension Fixture {
    static func registerForyTypes(_ fory: Fory) throws {
        try fory.register(Message.self, id: 1)
        try fory.register(DocumentMeta.self, id: 2)
        try fory.register(DocumentItem.self, id: 3)
        try fory.register(Document.self, id: 4)
        try fory.register(Telemetry.self, id: 5)
        try fory.register(Strings.self, id: 6)
        try fory.register(EventAttr.self, id: 7)
        try fory.register(Event.self, id: 8)
    }

    func foryCodec(_ fory: Fory) throws -> (() throws -> Data, (Data) throws -> Any) {
        func bind<T: Serializer>(_ type: T.Type) throws -> (() throws -> Data, (Data) throws -> Any)
        where T.Target == T {
            if instanceCount > 1 {
                guard let typed = value as? [T] else { throw BenchError.unsupported("Fory batch type") }
                return ({ try fory.serialize(typed) }, { try fory.deserialize($0, as: [T].self) })
            }
            guard let typed = value as? T else { throw BenchError.unsupported("Fory fixture type") }
            return ({ try fory.serialize(typed) }, { try fory.deserialize($0, as: T.self) })
        }
        switch name {
        case "message": return try bind(Message.self)
        case "document": return try bind(Document.self)
        case "telemetry": return try bind(Telemetry.self)
        case "strings": return try bind(Strings.self)
        case "event": return try bind(Event.self)
        default: throw BenchError.unsupported("Fory fixture: \(name)")
        }
    }
}
