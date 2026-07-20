import Foundation
import Yams
import XMLCoder

// MARK: - Yams (YAML)
// Optimal: YAMLEncoder.encode → String → utf8 Data; YAMLDecoder.decode from Data/String.
// https://github.com/jpsim/Yams

private final class YamsDecoderBox: Fixture.GenericDecoder {
    let decoder = YAMLDecoder()
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder.decode(type, from: data)
    }
}

public final class YamsSerializer: CodableBenchSerializer {
    public init() {
        let encoder = YAMLEncoder()
        let box = YamsDecoderBox()
        let ver = PackageVersions.version(for: "yams", fallback: "5.x")
        super.init(
            name: "Yams",
            version: ver,
            streamMode: .adapted,
            encode: { value in
                try encodeOpened(value) { v in
                    let s = try encoder.encode(v)
                    return Data(s.utf8)
                }
            },
            decoder: box
        )
    }
}

// MARK: - XMLCoder
// Optimal: XMLEncoder.encode(_:withRootKey:) / XMLDecoder.decode.
// Root key is a format requirement (XML document element), not suite type knowledge.
// https://github.com/CoreOffice/XMLCoder

private final class XMLDecoderBox: Fixture.GenericDecoder {
    let decoder = XMLDecoder()
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder.decode(type, from: data)
    }
}

public final class XMLCoderSerializer: CodableBenchSerializer {
    public init() {
        let encoder = XMLEncoder()
        encoder.outputFormatting = []
        let box = XMLDecoderBox()
        let ver = PackageVersions.version(for: "xmlcoder", fallback: "0.x")
        super.init(
            name: "XMLCoder",
            version: ver,
            streamMode: .adapted,
            encode: { value in
                // Fixed root element name — not derived from suite type ids.
                try encodeOpened(value) { try encoder.encode($0, withRootKey: "payload") }
            },
            decoder: box
        )
    }
}
