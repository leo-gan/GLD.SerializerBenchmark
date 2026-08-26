import Foundation
import FlatBuffers

// MARK: - Google FlatBuffers (official Swift runtime)
// Docs: https://flatbuffers.dev/flatbuffers_guide_use_swift.html
// Optimal: reuse FlatBufferBuilder.clear(); finish + sizedByteArray; getRoot + field reads.
// 401 pair with SwiftProtobuf: both time suite value → bytes → suite value.
// Timed decode includes domain materialize (same end object as SwiftProtobuf).

public final class FlatBuffersSerializer: BenchSerializer {
    public let name = "FlatBuffers"
    public let version: String
    public let streamMode: StreamMode = .adapted
    public let nativeKind: NativeKind = .archive

    private var prepared: Fixture?
    private var builder = FlatBufferBuilder(initialSize: 1024)
    /// Bound in prepare — timed path has no multi-way fixture switch (issue #59).
    private var encodeFn: ((inout FlatBufferBuilder, Fixture) throws -> Data)?
    private var decodeFn: ((Data) throws -> Any)?

    public init() {
        self.version = PackageVersions.version(for: "flatbuffers", fallback: "24.3.25")
    }

    public func supports(testDataName: String) -> Bool { true }

    public func prepare(_ fixture: Fixture) throws {
        prepared = fixture
        encodeFn = try FlatBuffersBridge.bindEncode(for: fixture)
        decodeFn = try FlatBuffersBridge.bindDecode(for: fixture)
        builder.clear()
        _ = try encodeFn!(&builder, fixture)
    }

    public func serializeBytes(_ fixture: Fixture) throws -> Data {
        guard let encodeFn else { throw BenchError.prepareRequired }
        builder.clear()
        return try encodeFn(&builder, fixture)
    }

    public func deserializeBytes(_ data: Data) throws -> Any {
        guard let decodeFn else { throw BenchError.prepareRequired }
        return try decodeFn(data)
    }
}
