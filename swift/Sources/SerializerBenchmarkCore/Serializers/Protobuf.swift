import Foundation
import SwiftProtobuf

// MARK: - SwiftProtobuf
// Optimal: Message.serializedData() / Message(serializedBytes:) on prepared native messages.
// https://github.com/apple/swift-protobuf

public final class SwiftProtobufSerializer: BenchSerializer {
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
        decodeNative = { data in
            try type(of: msg).init(serializedBytes: [UInt8](data))
        }
    }

    public func serializeBytes(_ fixture: Fixture) throws -> Data {
        guard let native else { throw BenchError.prepareRequired }
        return try native.serializedData()
    }

    public func deserializeBytes(_ data: Data) throws -> Any {
        guard let prepared, let decodeNative else { throw BenchError.prepareRequired }
        let msg = try decodeNative(data)
        return try ProtobufBridge.toDomain(msg, fixture: prepared)
    }
}
