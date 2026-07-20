import Foundation

/// Deterministic xorshift64* (within-language only).
/// Zero seed uses floor(2^64/φ)=0x9E3779B97F4A7C15 (golden ratio; nothing-up-my-sleeve).
final class Rng {
    private var state: UInt64
    init(seed: UInt64) {
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }
    func nextU64() -> UInt64 {
        var x = state
        x ^= x << 13
        x ^= x >> 7
        x ^= x << 17
        state = x
        return x
    }
    func nextInt(_ lo: Int, _ hi: Int) -> Int {
        if hi <= lo { return lo }
        return lo + Int(nextU64() % UInt64(hi - lo + 1))
    }
    func nextBool() -> Bool { (nextU64() & 1) == 1 }
    func nextF64() -> Double {
        Double(nextU64() >> 11) / Double(UInt64(1) << 53)
    }
    func word(minL: Int, maxL: Int) -> String {
        let n = nextInt(minL, maxL)
        let alpha = Array("abcdefghijklmnopqrstuvwxyz")
        var s = ""
        s.reserveCapacity(n)
        for _ in 0..<n {
            s.append(alpha[Int(nextU64() % 26)])
        }
        return s
    }
}

func mixSeed(_ seed: UInt64, typeId: String, idx: Int) -> UInt64 {
    var h = seed
    for u in typeId.utf8 {
        h = (h ^ UInt64(u)) &* 0x100000001B3
    }
    h ^= UInt64(idx) &* 0x9E3779B97F4A7C15
    return h == 0 ? 1 : h
}

public func makeOne(
    typeId: String,
    typeConfig: [String: Any] = [:],
    seed: UInt64 = 42,
    instanceIndex: Int = 0
) throws -> any Codable {
    let r = Rng(seed: mixSeed(seed, typeId: typeId, idx: instanceIndex))
    switch typeId {
    case "message":
        return Message(
            f_bool: r.nextBool(),
            f_int32: Int32(r.nextInt(0, 1_000_000)),
            f_int64: Int64(r.nextInt(0, 1_000_000)),
            f_float64: r.nextF64() * 1000,
            f_string: r.word(minL: 3, maxL: 16),
            f_bool_2: r.nextBool(),
            f_int32_2: Int32(r.nextInt(0, 1_000_000)),
            f_string_2: r.word(minL: 3, maxL: 16)
        )
    case "document":
        let n = cfgInt(typeConfig, "children", 8)
        let items = (0..<n).map { _ in
            DocumentItem(
                sku: r.word(minL: 3, maxL: 12),
                qty: Int32(r.nextInt(1, 100)),
                price_minor: Int64(r.nextInt(0, 100_000))
            )
        }
        return Document(
            id: r.word(minL: 8, maxL: 12),
            status: Int32(r.nextInt(0, 5)),
            meta: DocumentMeta(region: r.word(minL: 2, maxL: 4), version: Int32(r.nextInt(1, 10))),
            items: items
        )
    case "telemetry":
        let pts = cfgInt(typeConfig, "points", 32)
        let tagsN = cfgInt(typeConfig, "tag_count", 2)
        let tags = (0..<tagsN).map { _ in r.word(minL: 3, maxL: 10) }
        let values = (0..<pts).map { _ in r.nextF64() * 100 }
        return Telemetry(
            source: r.word(minL: 3, maxL: 10),
            ts: baseTSMS + Int64(r.nextInt(0, 86_400_000)),
            tags: tags,
            values: values
        )
    case "strings":
        let n = cfgInt(typeConfig, "count", 32)
        return Strings(items: (0..<n).map { _ in r.word(minL: 3, maxL: 16) })
    case "event":
        let n = cfgInt(typeConfig, "attr_count", 4)
        let attrs = (0..<n).map { _ in
            EventAttr(key: r.word(minL: 3, maxL: 12), value: r.word(minL: 3, maxL: 12))
        }
        return Event(
            event_id: r.word(minL: 8, maxL: 12),
            event_type: r.word(minL: 3, maxL: 12),
            occurred_at: baseTSMS + Int64(r.nextInt(0, 86_400_000)),
            producer: r.word(minL: 3, maxL: 12),
            attrs: attrs
        )
    default:
        throw BenchError.unknownType(typeId)
    }
}

func cfgInt(_ m: [String: Any], _ key: String, _ def: Int) -> Int {
    guard let v = m[key] else { return def }
    if let i = v as? Int { return i }
    if let i = v as? Int64 { return Int(i) }
    if let d = v as? Double { return Int(d) }
    if let n = v as? NSNumber { return n.intValue }
    return def
}

public enum BenchError: Error, CustomStringConvertible {
    case unknownType(String)
    case resolveFailed(String)
    case prepareRequired
    case fidelity
    case unsupported(String)

    public var description: String {
        switch self {
        case .unknownType(let t): return "unknown type_id: \(t)"
        case .resolveFailed(let s): return "resolve_run_config: \(s)"
        case .prepareRequired: return "prepare() required before deserialize"
        case .fidelity: return "roundtrip fidelity failed"
        case .unsupported(let s): return s
        }
    }
}

/// Build a type-erased Fixture for one resolved cell.
public func fixtureFromCell(
    typeId: String,
    typeConfig: [String: Any],
    typeConfigHash: String,
    instanceCount: Int,
    seed: UInt64
) throws -> Fixture {
    let n = max(1, instanceCount)
    if n == 1 {
        let one = try makeOne(typeId: typeId, typeConfig: typeConfig, seed: seed, instanceIndex: 0)
        return try boxFixture(name: typeId, value: one, instanceCount: 1, hash: typeConfigHash)
    }
    switch typeId {
    case "message":
        let items: [Message] = try (0..<n).map {
            try makeOne(typeId: typeId, typeConfig: typeConfig, seed: seed, instanceIndex: $0) as! Message
        }
        return Fixture(name: typeId, batch: items, typeConfigHash: typeConfigHash)
    case "document":
        let items: [Document] = try (0..<n).map {
            try makeOne(typeId: typeId, typeConfig: typeConfig, seed: seed, instanceIndex: $0) as! Document
        }
        return Fixture(name: typeId, batch: items, typeConfigHash: typeConfigHash)
    case "telemetry":
        let items: [Telemetry] = try (0..<n).map {
            try makeOne(typeId: typeId, typeConfig: typeConfig, seed: seed, instanceIndex: $0) as! Telemetry
        }
        return Fixture(name: typeId, batch: items, typeConfigHash: typeConfigHash)
    case "strings":
        let items: [Strings] = try (0..<n).map {
            try makeOne(typeId: typeId, typeConfig: typeConfig, seed: seed, instanceIndex: $0) as! Strings
        }
        return Fixture(name: typeId, batch: items, typeConfigHash: typeConfigHash)
    case "event":
        let items: [Event] = try (0..<n).map {
            try makeOne(typeId: typeId, typeConfig: typeConfig, seed: seed, instanceIndex: $0) as! Event
        }
        return Fixture(name: typeId, batch: items, typeConfigHash: typeConfigHash)
    default:
        throw BenchError.unknownType(typeId)
    }
}

private func boxFixture(name: String, value: any Codable, instanceCount: Int, hash: String) throws -> Fixture {
    switch value {
    case let v as Message:
        return Fixture(name: name, value: v, instanceCount: instanceCount, typeConfigHash: hash)
    case let v as Document:
        return Fixture(name: name, value: v, instanceCount: instanceCount, typeConfigHash: hash)
    case let v as Telemetry:
        return Fixture(name: name, value: v, instanceCount: instanceCount, typeConfigHash: hash)
    case let v as Strings:
        return Fixture(name: name, value: v, instanceCount: instanceCount, typeConfigHash: hash)
    case let v as Event:
        return Fixture(name: name, value: v, instanceCount: instanceCount, typeConfigHash: hash)
    default:
        throw BenchError.unknownType(name)
    }
}
