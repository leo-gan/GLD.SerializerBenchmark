import Foundation
import SwiftProtobuf

// MARK: - SwiftProtobuf
// Docs: https://github.com/apple/swift-protobuf
// Optimal: prepare builds native Message; timed path is serializedData() /
// Message(serializedBytes:) only. Domain conversion via DomainConverter (untimed).

public final class SwiftProtobufSerializer: BenchSerializer, DomainConverter {
    public let name = "SwiftProtobuf"
    public let version: String
    public let streamMode: StreamMode = .adapted
    public let nativeKind: NativeKind = .message

    private var prepared: Fixture?
    private var native: (any SwiftProtobuf.Message)?
    private var decodeNative: ((Data) throws -> any SwiftProtobuf.Message)?

    public init() {
        self.version = PackageVersions.version(for: "swift-protobuf", fallback: "1.x")
    }

    public func supports(testDataName: String) -> Bool { true }

    public func prepare(_ fixture: Fixture) throws {
        prepared = fixture
        let msg = try ProtobufBridge.toProtobuf(fixture)
        native = msg
        // ContiguousBytes path (Data) — avoid [UInt8](data) copy on every deser.
        // https://github.com/apple/swift-protobuf — Message(serializedBytes:)
        decodeNative = { data in
            try type(of: msg).init(serializedBytes: data)
        }
    }

    public func serializeBytes(_ fixture: Fixture) throws -> Data {
        guard let native else { throw BenchError.prepareRequired }
        return try native.serializedData()
    }

    /// Timed: library-native Message only.
    public func deserializeBytes(_ data: Data) throws -> Any {
        guard let decodeNative else { throw BenchError.prepareRequired }
        return try decodeNative(data)
    }

    public func toDomain(_ decoded: Any) throws -> Any {
        guard let prepared else { throw BenchError.prepareRequired }
        guard let msg = decoded as? any SwiftProtobuf.Message else {
            return decoded
        }
        return try ProtobufBridge.toDomain(msg, fixture: prepared)
    }
}
