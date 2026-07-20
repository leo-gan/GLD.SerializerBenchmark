import Foundation
import TOML

// MARK: - TOML (mattt/swift-toml, toml++)
// Optimal: TOMLEncoder.encode / TOMLDecoder.decode (Data).
// TOML root is a table — batch cells use Fixture.mapRootValue (ItemsWrap).
// https://github.com/mattt/swift-toml

private final class TOMLDecoderBox: Fixture.GenericDecoder {
    let decoder = TOMLDecoder()
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder.decode(type, from: data)
    }
}

public final class TOMLSerializer: BenchSerializer {
    public let name = "TOML"
    public let version: String
    public let streamMode: StreamMode = .adapted
    public let nativeKind: NativeKind = .codable

    private let encoder = TOMLEncoder()
    private let decoderBox = TOMLDecoderBox()
    private var prepared: Fixture?

    public init() {
        self.version = PackageVersions.version(for: "swift-toml", fallback: "2.x")
    }

    public func supports(testDataName: String) -> Bool { true }

    public func prepare(_ fixture: Fixture) throws {
        prepared = fixture
    }

    public func serializeBytes(_ fixture: Fixture) throws -> Data {
        // Batches need a table root (items wrap); singles encode as records.
        let root = fixture.needsMapRoot ? fixture.mapRootValue : fixture.value
        return try encodeOpened(root) { try encoder.encode($0) }
    }

    public func deserializeBytes(_ data: Data) throws -> Any {
        guard let prepared else { throw BenchError.prepareRequired }
        if prepared.needsMapRoot {
            return try prepared.decodeMapRoot(from: data, using: decoderBox)
        }
        return try prepared.decode(from: data, using: decoderBox)
    }
}
