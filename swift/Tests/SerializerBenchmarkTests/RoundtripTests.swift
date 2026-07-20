import XCTest
@testable import SerializerBenchmarkCore

final class RoundtripTests: XCTestCase {
    private func roundtrip(_ ser: any BenchSerializer, _ fx: Fixture) throws {
        try ser.prepare(fx)
        let data = try ser.serializeBytes(fx)
        XCTAssertFalse(data.isEmpty, "\(ser.name) empty for \(fx.name)")
        var out = try ser.deserializeBytes(data)
        if let conv = ser as? DomainConverter {
            out = try conv.toDomain(out)
        }
        XCTAssertTrue(fx.fidelity(against: out), "\(ser.name) fidelity for \(fx.name)")
    }

    func testAllSerializersRoundtripAllTypes() throws {
        for typeId in ["message", "document", "telemetry", "strings", "event"] {
            let fx = try fixtureFromCell(
                typeId: typeId,
                typeConfig: [:],
                typeConfigHash: "",
                instanceCount: 1,
                seed: 42
            )
            for ser in allSerializers() {
                try roundtrip(ser, fx)
            }
        }
    }

    func testBatchRoundtrip() throws {
        let fx = try fixtureFromCell(
            typeId: "message",
            typeConfig: [:],
            typeConfigHash: "",
            instanceCount: 8,
            seed: 7
        )
        XCTAssertEqual(fx.instanceCount, 8)
        XCTAssertTrue(fx.needsMapRoot)
        for ser in allSerializers() {
            try roundtrip(ser, fx)
        }
    }

    func testWrappersStayTypeAgnostic() throws {
        let msg = Message(
            f_bool: true, f_int32: 1, f_int64: 2, f_float64: 3.0, f_string: "a",
            f_bool_2: false, f_int32_2: 4, f_string_2: "b"
        )
        let fx = Fixture(name: "message", value: msg)
        let ser = FoundationJSONSerializer()
        try roundtrip(ser, fx)
    }

    func testAdaptedStreamDoesRealIO() throws {
        let fx = try fixtureFromCell(
            typeId: "message", typeConfig: [:], typeConfigHash: "", instanceCount: 1, seed: 1
        )
        let ser = FoundationJSONSerializer()
        try ser.prepare(fx)
        let (streamData, n) = try ser.serializeStream(fx)
        XCTAssertEqual(n, streamData.count)
        XCTAssertFalse(streamData.isEmpty)
        var out = try ser.deserializeStream(streamData)
        if let conv = ser as? DomainConverter { out = try conv.toDomain(out) }
        XCTAssertTrue(fx.fidelity(against: out))
    }
}
