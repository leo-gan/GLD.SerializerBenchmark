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
    /// Bound in prepare — timed path has no multi-way fixture switch (issue #59).
    private var encodeFn: ((Fixture) throws -> Data)?
    private var decodeFn: ((Data) throws -> Any)?

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
        encodeFn = try CapnpBridgeSwift.bindEncode(for: fixture)
        decodeFn = try CapnpBridgeSwift.bindDecode(for: fixture)
        _ = try encodeFn!(fixture)
    }

    public func serializeBytes(_ fixture: Fixture) throws -> Data {
        guard let encodeFn else { throw BenchError.prepareRequired }
        return try encodeFn(fixture)
    }

    public func deserializeBytes(_ data: Data) throws -> Any {
        guard let decodeFn else { throw BenchError.prepareRequired }
        return try decodeFn(data)
    }
}
