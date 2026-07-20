import Foundation
import FlatBuffers

// MARK: - Google FlatBuffers (official Swift runtime)
// Optimal: FlatBufferBuilder + finish; getRoot as table. Conversion in prepare-style builders.
// Schema: swift/schemas/benchmark.fbs (same as cpp/schemas/benchmark.fbs)
// https://flatbuffers.dev/flatbuffers_guide_use_swift.html

public final class FlatBuffersSerializer: BenchSerializer {
    public let name = "FlatBuffers"
    public let version: String
    public let streamMode: StreamMode = .adapted
    public let nativeKind: NativeKind = .message

    private var prepared: Fixture?
    private var preparedBytes: Data = Data()

    public init() {
        self.version = PackageVersions.version(for: "flatbuffers", fallback: "24.3.25")
    }

    public func supports(testDataName: String) -> Bool { true }

    public func prepare(_ fixture: Fixture) throws {
        prepared = fixture
        preparedBytes = try FlatBuffersBridge.encode(fixture)
    }

    public func serializeBytes(_ fixture: Fixture) throws -> Data {
        // Rebuild each call (builder is not reusable across finishes without reset).
        // prepare caches one sample for size; timed path encodes freshly.
        return try FlatBuffersBridge.encode(fixture)
    }

    public func deserializeBytes(_ data: Data) throws -> Any {
        guard let prepared else { throw BenchError.prepareRequired }
        return try FlatBuffersBridge.decode(data, fixture: prepared)
    }
}
