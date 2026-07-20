import Foundation

public enum StreamMode: String, Sendable {
    case native
    case adapted
}

public enum NativeKind: String, Sendable {
    case codable
    case message
    case document
    case schema
    case archive
}

/// Prepare/timed call-path contract (aligned with Go/Python/Rust).
public protocol BenchSerializer: AnyObject {
    var name: String { get }
    var version: String { get }
    var streamMode: StreamMode { get }
    var nativeKind: NativeKind { get }

    func supports(testDataName: String) -> Bool
    /// Untimed: encoder config, scratch buffers — no payload type knowledge required.
    func prepare(_ fixture: Fixture) throws
    func serializeBytes(_ fixture: Fixture) throws -> Data
    func deserializeBytes(_ data: Data) throws -> Any
    func serializeStream(_ fixture: Fixture) throws -> (Data, Int)
    func deserializeStream(_ data: Data) throws -> Any
}

public extension BenchSerializer {
    var streamMode: StreamMode { .adapted }
    var nativeKind: NativeKind { .codable }
    func supports(testDataName: String) -> Bool { true }

    /// Default stream path: bytes + buffer (honest `adapted` mode).
    func serializeStream(_ fixture: Fixture) throws -> (Data, Int) {
        let d = try serializeBytes(fixture)
        return (d, d.count)
    }
    func deserializeStream(_ data: Data) throws -> Any {
        try deserializeBytes(data)
    }
}

/// Shared helper: wrap a Foundation/Codable encoder+decoder as GenericDecoder + encode.
open class CodableBenchSerializer: BenchSerializer {
    public let name: String
    public let version: String
    public let streamMode: StreamMode
    public let nativeKind: NativeKind

    private let encodeFn: (any Encodable) throws -> Data
    private let decoder: any Fixture.GenericDecoder
    private var prepared: Fixture?

    public init(
        name: String,
        version: String,
        streamMode: StreamMode = .adapted,
        nativeKind: NativeKind = .codable,
        encode: @escaping (any Encodable) throws -> Data,
        decoder: any Fixture.GenericDecoder
    ) {
        self.name = name
        self.version = version
        self.streamMode = streamMode
        self.nativeKind = nativeKind
        self.encodeFn = encode
        self.decoder = decoder
    }

    public func supports(testDataName: String) -> Bool { true }

    public func prepare(_ fixture: Fixture) throws {
        prepared = fixture
    }

    public func serializeBytes(_ fixture: Fixture) throws -> Data {
        try encodeFn(fixture.value)
    }

    public func deserializeBytes(_ data: Data) throws -> Any {
        guard let prepared else { throw BenchError.prepareRequired }
        return try prepared.decode(from: data, using: decoder)
    }
}

/// Object wrapper so non-class library decoders can satisfy GenericDecoder.
public final class ClosureDecoder: Fixture.GenericDecoder {
    private let body: (any Decodable.Type, Data) throws -> any Decodable

    public init(_ body: @escaping (any Decodable.Type, Data) throws -> any Decodable) {
        self.body = body
    }

    public func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let any = try body(type, data)
        guard let t = any as? T else {
            throw BenchError.unsupported("decoder returned unexpected type")
        }
        return t
    }
}

/// Package version best-effort from resolved module resource path (Package.resolved preferred in runner).
public enum PackageVersions {
    public static var resolved: [String: String] = [:]

    public static func version(for package: String, fallback: String = "") -> String {
        if let v = resolved[package] { return v }
        return fallback
    }

    public static func loadResolved(from packageDir: URL) {
        let url = packageDir.appendingPathComponent("Package.resolved")
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }
        // pins format v2/v3
        if let pins = json["pins"] as? [[String: Any]] {
            for pin in pins {
                let identity = pin["identity"] as? String
                    ?? (pin["package"] as? String)
                    ?? ""
                var ver = ""
                if let state = pin["state"] as? [String: Any] {
                    ver = state["version"] as? String ?? ""
                }
                if !identity.isEmpty, !ver.isEmpty {
                    resolved[identity.lowercased()] = ver
                }
            }
        }
    }
}
