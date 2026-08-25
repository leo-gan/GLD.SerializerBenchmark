import Foundation
import SwiftBSON

// MARK: - MongoDB SwiftBSON
// Optimal: BSONEncoder.encode → BSONDocument → toData(); BSONDecoder.decode from document.
// Top-level arrays are not valid BSON documents — use Fixture.mapRootValue (ItemsWrap)
// for N>1 (same idea as Go mongo-bson batch wrap). Type names stay out of this file.
// https://github.com/mongodb/swift-bson

private final class BSONDecoderBox: Fixture.GenericDecoder {
    let decoder = BSONDecoder()
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let doc = try BSONDocument(fromBSON: data)
        return try decoder.decode(type, from: doc)
    }
}

public final class SwiftBSONSerializer: BenchSerializer {
    public let name = "SwiftBSON"
    public let version: String
    public let streamMode: StreamMode = .adapted
    public let nativeKind: NativeKind = .document

    private let encoder = BSONEncoder()
    private let decoderBox = BSONDecoderBox()
    private var prepared: Fixture?

    public init() {
        self.version = PackageVersions.version(for: "swift-bson", fallback: "3.x")
    }

    public func supports(testDataName: String) -> Bool { true }

    public func prepare(_ fixture: Fixture) throws {
        prepared = fixture
    }

    public func serializeBytes(_ fixture: Fixture) throws -> Data {
        let root = fixture.needsMapRoot ? fixture.mapRootValue : fixture.value
        return try encodeOpened(root) { v in
            let doc = try encoder.encode(v)
            return doc.toData()
        }
    }

    public func deserializeBytes(_ data: Data) throws -> Any {
        guard let prepared else { throw BenchError.prepareRequired }
        if prepared.needsMapRoot {
            return try prepared.decodeMapRoot(from: data, using: decoderBox)
        }
        return try prepared.decode(from: data, using: decoderBox)
    }
}
