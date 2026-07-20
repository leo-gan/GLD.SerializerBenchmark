import Foundation
import CapnpBridge

// MARK: - Cap'n Proto (C++ runtime via CapnpBridge)
// Docs: https://capnproto.org/ — messageToFlatArray / FlatArrayMessageReader.
// Timed path includes field materialize into suite domain (fair vs other langs' full roundtrip).

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
        _ = try CapnpBridgeSwift.encode(fixture)
    }

    public func serializeBytes(_ fixture: Fixture) throws -> Data {
        try CapnpBridgeSwift.encode(fixture)
    }

    public func deserializeBytes(_ data: Data) throws -> Any {
        guard let prepared else { throw BenchError.prepareRequired }
        return try CapnpBridgeSwift.decode(data, fixture: prepared)
    }
}
