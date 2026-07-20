import Foundation
import FlatBuffers

// MARK: - Google FlatBuffers (official Swift runtime)
// Docs: https://flatbuffers.dev/flatbuffers_guide_use_swift.html
// Optimal: reuse FlatBufferBuilder.clear(); finish + sizedByteArray; getRoot + field reads.
// Domain materialize is timed (zero-copy root alone is not a suite deserialize).

public final class FlatBuffersSerializer: BenchSerializer {
    public let name = "FlatBuffers"
    public let version: String
    public let streamMode: StreamMode = .adapted
    public let nativeKind: NativeKind = .archive

    private var prepared: Fixture?
    private var builder = FlatBufferBuilder(initialSize: 1024)

    public init() {
        self.version = PackageVersions.version(for: "flatbuffers", fallback: "24.3.25")
    }

    public func supports(testDataName: String) -> Bool { true }

    public func prepare(_ fixture: Fixture) throws {
        prepared = fixture
        builder.clear()
        _ = try FlatBuffersBridge.encode(into: &builder, fixture: fixture)
    }

    public func serializeBytes(_ fixture: Fixture) throws -> Data {
        builder.clear()
        return try FlatBuffersBridge.encode(into: &builder, fixture: fixture)
    }

    public func deserializeBytes(_ data: Data) throws -> Any {
        guard let prepared else { throw BenchError.prepareRequired }
        return try FlatBuffersBridge.decode(data, fixture: prepared)
    }
}
