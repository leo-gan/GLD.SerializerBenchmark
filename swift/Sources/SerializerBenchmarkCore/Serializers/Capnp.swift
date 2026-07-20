import Foundation
import CapnpBridge

// MARK: - Cap'n Proto (C++ runtime via CapnpBridge)
// Optimal: messageToFlatArray / FlatArrayMessageReader on prepared builders.
// No first-class Swift codegen; suite uses C ABI bridge over official C++ library.
// Schema: swift/schemas/benchmark.capnp (same as cpp/schemas/benchmark.capnp)
// https://capnproto.org/

public final class CapnProtoSerializer: BenchSerializer {
    public let name = "CapnProto"
    public let version: String
    public let streamMode: StreamMode = .adapted
    public let nativeKind: NativeKind = .message

    private var prepared: Fixture?

    public init() {
        if let cstr = capnp_bridge_version() {
            self.version = String(cString: cstr)
        } else {
            self.version = "capnproto"
        }
    }

    public func supports(testDataName: String) -> Bool { true }

    public func prepare(_ fixture: Fixture) throws {
        prepared = fixture
        // Warm encode path
        _ = try serializeBytes(fixture)
    }

    public func serializeBytes(_ fixture: Fixture) throws -> Data {
        try CapnpBridgeSwift.encode(fixture)
    }

    public func deserializeBytes(_ data: Data) throws -> Any {
        guard let prepared else { throw BenchError.prepareRequired }
        return try CapnpBridgeSwift.decode(data, fixture: prepared)
    }
}
