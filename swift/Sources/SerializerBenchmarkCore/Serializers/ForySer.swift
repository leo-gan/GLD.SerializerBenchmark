import Foundation
import Fory

public final class ForySerializer: BenchSerializer {
    public let name = "fory"
    public var version: String { PackageVersions.version(for: "fory", fallback: "1.7.4") }
    public var nativeKind: NativeKind { .message }
    private let fory = Fory()
    private var encode: (() throws -> Data)?
    private var decode: ((Data) throws -> Any)?
    private var registered = false

    public init() {}

    public func prepare(_ fixture: Fixture) throws {
        if !registered {
            try Fixture.registerForyTypes(fory)
            registered = true
        }
        (encode, decode) = try fixture.foryCodec(fory)
        _ = try deserializeBytes(serializeBytes(fixture))
    }

    public func serializeBytes(_ fixture: Fixture) throws -> Data {
        guard let encode else { throw BenchError.prepareRequired }
        return try encode()
    }

    public func deserializeBytes(_ data: Data) throws -> Any {
        guard let decode else { throw BenchError.prepareRequired }
        return try decode(data)
    }
}
