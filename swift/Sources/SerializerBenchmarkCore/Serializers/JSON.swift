import Foundation
import IkigaJSON

// MARK: - Foundation JSON (stdlib baseline)
// Optimal: JSONEncoder/JSONDecoder without pretty-print.
// https://developer.apple.com/documentation/foundation/jsonencoder

private final class FoundationJSONDecoderBox: Fixture.GenericDecoder {
    let decoder = JSONDecoder()
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder.decode(type, from: data)
    }
}

public final class FoundationJSONSerializer: CodableBenchSerializer {
    public init() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = []
        let box = FoundationJSONDecoderBox()
        super.init(
            name: "Foundation.JSONEncoder",
            version: "Foundation",
            streamMode: .adapted,
            encode: { value in try encodeOpened(value) { try encoder.encode($0) } },
            decoder: box
        )
    }
}

// MARK: - IkigaJSON
// Optimal: IkigaJSONEncoder.encode / IkigaJSONDecoder.decode (Codable path).
// https://github.com/orlandos-nl/IkigaJSON

private final class IkigaDecoderBox: Fixture.GenericDecoder {
    let decoder = IkigaJSONDecoder()
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder.decode(type, from: data)
    }
}

public final class IkigaJSONSerializer: CodableBenchSerializer {
    public init() {
        let encoder = IkigaJSONEncoder()
        let box = IkigaDecoderBox()
        let ver = PackageVersions.version(for: "ikigajson", fallback: "2.x")
        super.init(
            name: "IkigaJSON",
            version: ver,
            streamMode: .adapted,
            encode: { value in try encodeOpened(value) { try encoder.encode($0) } },
            decoder: box
        )
    }
}

// MARK: - Foundation PropertyList (binary)
// Optimal: PropertyListEncoder with .binary format.
// https://developer.apple.com/documentation/foundation/propertylistencoder

private final class PlistDecoderBox: Fixture.GenericDecoder {
    let decoder = PropertyListDecoder()
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder.decode(type, from: data)
    }
}

public final class PropertyListBinarySerializer: CodableBenchSerializer {
    public init() {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let box = PlistDecoderBox()
        super.init(
            name: "Foundation.PropertyListEncoder",
            version: "Foundation",
            streamMode: .adapted,
            encode: { value in try encodeOpened(value) { try encoder.encode($0) } },
            decoder: box
        )
    }
}

/// Open `any Encodable` so generic `encode<E: Encodable>` receives a concrete type.
func encodeOpened(_ value: any Encodable, _ body: (any Encodable) throws -> Data) rethrows -> Data {
    try body(value)
}
