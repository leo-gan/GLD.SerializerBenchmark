import Foundation
import SwiftProtobuf

// MARK: - SwiftProtobuf
// Docs: https://github.com/apple/swift-protobuf
// 401 pair with FlatBuffers: both time suite value → bytes → suite value.
// prepare only binds the native decode type. Timed serialize is toProtobuf +
// serializedData(); timed deserialize is parse + toDomain. DomainConverter is identity.

public final class SwiftProtobufSerializer: BenchSerializer, DomainConverter {
    public let name = "SwiftProtobuf"
    public let version: String
    public let streamMode: StreamMode = .adapted
    public let nativeKind: NativeKind = .message

    private var prepared: Fixture?
    private var decodeNative: ((Data) throws -> any SwiftProtobuf.Message)?

    public init() {
        self.version = PackageVersions.version(for: "swift-protobuf", fallback: "1.x")
    }

    public func supports(testDataName: String) -> Bool { true }

    public func prepare(_ fixture: Fixture) throws {
        prepared = fixture
        let msg = try ProtobufBridge.toProtobuf(fixture)
        // ContiguousBytes path (Data) — avoid [UInt8](data) copy on every deser.
        // https://github.com/apple/swift-protobuf — Message(serializedBytes:)
        decodeNative = { data in
            try type(of: msg).init(serializedBytes: data)
        }
    }

    public func serializeBytes(_ fixture: Fixture) throws -> Data {
        let msg = try ProtobufBridge.toProtobuf(fixture)
        return try msg.serializedData()
    }

    /// Timed: parse plus suite-value copy (same end object as FlatBuffers).
    public func deserializeBytes(_ data: Data) throws -> Any {
        guard let decodeNative, let prepared else { throw BenchError.prepareRequired }
        let msg = try decodeNative(data)
        return try ProtobufBridge.toDomain(msg, fixture: prepared)
    }

    public func toDomain(_ decoded: Any) throws -> Any {
        decoded
    }
}
