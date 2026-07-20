import Foundation
import BinaryCodable

// MARK: - BinaryCodable (pure Swift binary Codable)
// Optimal: BinaryEncoder.encode / BinaryDecoder.decode (no pretty-print, reuse encoder if needed).
// https://github.com/christophhagen/BinaryCodable
// Docs: https://docs.christophhagen.de/documentation/binarycodable

private final class BinaryCodableDecoderBox: Fixture.GenericDecoder {
    let decoder = BinaryDecoder()
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder.decode(type, from: data)
    }
}

public final class BinaryCodableSerializer: CodableBenchSerializer {
    public init() {
        let encoder = BinaryEncoder()
        let box = BinaryCodableDecoderBox()
        let ver = PackageVersions.version(for: "binarycodable", fallback: "4.x")
        super.init(
            name: "BinaryCodable",
            version: ver,
            streamMode: .adapted,
            nativeKind: .codable,
            encode: { value in try encodeOpened(value) { try encoder.encode($0) } },
            decoder: box
        )
    }
}
