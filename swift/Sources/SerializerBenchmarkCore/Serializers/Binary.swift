import Foundation
import SwiftMsgpack
import SwiftCbor

// MARK: - MessagePack (nnabeyang/swift-msgpack)
// Optimal: MsgPackEncoder.encode / MsgPackDecoder.decode (Codable).
// https://github.com/nnabeyang/swift-msgpack

private final class MsgPackDecoderBox: Fixture.GenericDecoder {
    let decoder = MsgPackDecoder()
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder.decode(type, from: data)
    }
}

public final class MsgPackSerializer: CodableBenchSerializer {
    public init() {
        let encoder = MsgPackEncoder()
        let box = MsgPackDecoderBox()
        let ver = PackageVersions.version(for: "swift-msgpack", fallback: "1.x")
        super.init(
            name: "SwiftMsgpack",
            version: ver,
            streamMode: .adapted,
            encode: { value in try encodeOpened(value) { try encoder.encode($0) } },
            decoder: box
        )
    }
}

// MARK: - CBOR (nnabeyang/swift-cbor)
// Optimal: CborEncoder.encode / CborDecoder.decode (Codable).
// https://github.com/nnabeyang/swift-cbor

private final class CborDecoderBox: Fixture.GenericDecoder {
    let decoder = CborDecoder()
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder.decode(type, from: data)
    }
}

public final class CborSerializer: CodableBenchSerializer {
    public init() {
        let encoder = CborEncoder()
        let box = CborDecoderBox()
        let ver = PackageVersions.version(for: "swift-cbor", fallback: "0.x")
        super.init(
            name: "SwiftCbor",
            version: ver,
            streamMode: .adapted,
            encode: { value in try encodeOpened(value) { try encoder.encode($0) } },
            decoder: box
        )
    }
}
