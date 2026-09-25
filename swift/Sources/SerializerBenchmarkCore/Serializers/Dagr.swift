import Foundation
import BenchmarkV2

// MARK: - Dagr
// Docs: https://codeberg.org/mzaks/dagr (spec/33-direct-graph-builder.md)
// schemas/v2/dagr/schema.py → `dagr build` → swift/DagrGen (SwiftPM module `BenchmarkV2`).
// One DataGraph per suite type, all nodes `packed`, rooted at the suite type.
//
// Serialize (timed): suite value → generated **direct builder** value structs
// (`<Graph>.Direct.*`, no arena) → one `DataArenaBuilder` reused across calls (`reset()`).
// Deserialize (timed): generated **lazy reader** (`<Graph>.<T>Accessor`) → owned suite value
// (same end object as SwiftProtobuf / FlatBuffers). prepare binds the per-type closures.
//
// N>1: the schema has no batch root, so the harness frames the cell like the Rust / C
// runners: u32 LE count + (u32 LE len + one Dagr buffer)×N. Dagr writes back-to-front, so
// the batch is built in ONE builder by storing items in reverse and prepending each item's
// length; decode reads each item in place (no per-item copy).
//
// The same class serves the four node layouts (`DagrLayout`, spec/16-choosing-a-node-layout):
// `dagr-packed`, `dagr-regular`, `dagr-frozen`, `dagr-frozen-packed`. The schema emits each
// suite type once per layout (`<T>Graph`, `<T>RegularGraph`, `<T>FrozenGraph`,
// `<T>FrozenPackedGraph`); the per-layout bridges are in `DagrLayouts.swift`.

/// Node layout of a Dagr row. Raw value = row name.
public enum DagrLayout: String, CaseIterable, Sendable {
    case packed = "dagr-packed"
    case regular = "dagr-regular"
    case frozen = "dagr-frozen"
    case frozenPacked = "dagr-frozen-packed"

    /// regular / frozen nodes go through the builder's dedup tables (strings, vtables, node
    /// ids), which only `reset()` clears — so a batch encodes each item on its own (see bind).
    var dedups: Bool { self == .regular || self == .frozen }
}

public final class DagrSerializer: BenchSerializer {
    public let name: String
    public let layout: DagrLayout
    public let version: String
    public let streamMode: StreamMode = .adapted
    public let nativeKind: NativeKind = .schema

    /// Reused across calls (`reset()` per record). Packed trees never touch its dedup tables.
    private let builder = DataArenaBuilder(maxSize: UInt64(1) << 32)
    private var encodeFn: ((DataArenaBuilder, Fixture) throws -> Data)?
    private var decodeFn: ((Data) throws -> Any)?

    public init(layout: DagrLayout = .packed) {
        self.layout = layout
        self.name = layout.rawValue
        self.version = DagrSerializer.receiptVersion()
    }

    public func supports(testDataName: String) -> Bool {
        ["message", "document", "telemetry", "strings", "event"].contains(testDataName)
    }

    public func prepare(_ fixture: Fixture) throws {
        switch layout {
        case .packed: try preparePacked(fixture)
        case .regular: try prepareRegular(fixture)
        case .frozen: try prepareFrozen(fixture)
        case .frozenPacked: try prepareFrozenPacked(fixture)
        }
    }

    func preparePacked(_ fixture: Fixture) throws {
        switch fixture.name {
        case "message":
            bind(fixture, DagrBridge.encodeMessage, DagrBridge.decodeMessage)
        case "document":
            bind(fixture, DagrBridge.encodeDocument, DagrBridge.decodeDocument)
        case "telemetry":
            bind(fixture, DagrBridge.encodeTelemetry, DagrBridge.decodeTelemetry)
        case "strings":
            bind(fixture, DagrBridge.encodeStrings, DagrBridge.decodeStrings)
        case "event":
            bind(fixture, DagrBridge.encodeEvent, DagrBridge.decodeEvent)
        default:
            throw BenchError.unknownType(fixture.name)
        }
    }

    public func serializeBytes(_ fixture: Fixture) throws -> Data {
        guard let encodeFn else { throw BenchError.prepareRequired }
        return try encodeFn(builder, fixture)
    }

    public func deserializeBytes(_ data: Data) throws -> Any {
        guard let decodeFn else { throw BenchError.prepareRequired }
        // Generated readers index `Data` from 0; the harness always hands a 0-based buffer.
        return try decodeFn(data.startIndex == 0 ? data : Data(data))
    }

    /// Binds monomorphic encode/decode for one suite type (no fixture switch on the timed path).
    /// `encode` stores ONE record (root + framing LEB) into the builder; `decode` reads one
    /// record starting at the given offset.
    func bind<T>(
        _ fixture: Fixture,
        _ encode: @escaping (DataArenaBuilder, T) throws -> Void,
        _ decode: @escaping (Data, Int) throws -> T
    ) {
        if fixture.instanceCount > 1 && layout.dedups {
            // regular / frozen: string/vtable/node-id dedup would reach across items (and the
            // arenas' node ids collide — every item's root is index 0), so each item is its own
            // self-contained record: reset, store, append. Same frame layout as below.
            encodeFn = { b, fx in
                let items = fx.value as! [T]
                var out = Data()
                DagrBridge.appendU32(&out, UInt32(items.count))
                for item in items {
                    b.reset()
                    try encode(b, item)
                    DagrBridge.appendU32(&out, UInt32(b.cursor.value))
                    out.append(b.makeData)
                }
                return out
            }
            decodeFn = DagrSerializer.batchDecode(decode)
        } else if fixture.instanceCount > 1 {
            encodeFn = { b, fx in
                let items = fx.value as! [T]
                b.reset()
                for item in items.reversed() {
                    let before = b.cursor.value
                    try encode(b, item)
                    _ = try b.store(number: UInt32(b.cursor.value - before).littleEndian)
                }
                _ = try b.store(number: UInt32(items.count).littleEndian)
                return b.makeData
            }
            decodeFn = DagrSerializer.batchDecode(decode)
        } else {
            encodeFn = { b, fx in
                b.reset()
                try encode(b, fx.value as! T)
                return b.makeData
            }
            decodeFn = { data in
                try decode(data, 0)
            }
        }
    }

    private static func batchDecode<T>(_ decode: @escaping (Data, Int) throws -> T) -> (Data) throws -> Any {
        return { data in
            var o = 0
            let n = Int(try DagrBridge.u32(data, &o))
            var out: [T] = []
            out.reserveCapacity(n)
            for _ in 0..<n {
                let len = Int(try DagrBridge.u32(data, &o))
                guard o + len <= data.count else { throw BenchError.unsupported("dagr: truncated batch") }
                out.append(try decode(data, o))
                o += len
            }
            return out
        }
    }

    /// Generator version from the committed receipt
    /// (`provenance.tool_version: "dagr 2026.9.0"` → `2026.9.0`).
    static func receiptVersion() -> String {
        let rel = "schemas/v2/dagr/dagr.lock.json"
        let candidates = [
            RunConfig.repoRoot().appendingPathComponent(rel),
            // swift/Sources/SerializerBenchmarkCore/Serializers/Dagr.swift → repo root
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent().appendingPathComponent(rel),
        ]
        for url in candidates {
            guard let data = try? Data(contentsOf: url),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let provenance = json["provenance"] as? [String: Any],
                  let tool = provenance["tool_version"] as? String
            else { continue }
            return tool.hasPrefix("dagr ") ? String(tool.dropFirst(5)) : tool
        }
        return "unknown"
    }
}

/// Suite value ↔ generated Dagr types. Encode builds the direct-builder value structs
/// (timed, like SwiftProtobuf's toProtobuf); decode walks the lazy accessors.
enum DagrBridge {
    // ── framing helpers ────────────────────────────────────────────────────

    static func u32(_ data: Data, _ o: inout Int) throws -> UInt32 {
        guard o + 4 <= data.count else { throw BenchError.unsupported("dagr: truncated batch frame") }
        let v = UInt32(data[o]) | UInt32(data[o + 1]) << 8 | UInt32(data[o + 2]) << 16 | UInt32(data[o + 3]) << 24
        o += 4
        return v
    }

    static func appendU32(_ out: inout Data, _ v: UInt32) {
        withUnsafeBytes(of: v.littleEndian) { out.append(contentsOf: $0) }
    }

    /// Mirrors the generated `Direct.toData` / `Arena.toData`, into a caller-owned builder.
    /// Works for direct value structs and arena node handles alike.
    @inline(__always)
    static func storeRoot<R: ArenaGraphStorable>(_ b: DataArenaBuilder, _ root: R) throws {
        let rootOffset = try root.store(with: b)
        _ = try b.storeAsLEB(value: (b.cursor.value - rootOffset.value) << 2)
    }

    // ── Message ────────────────────────────────────────────────────────────

    static func encodeMessage(_ b: DataArenaBuilder, _ m: Message) throws {
        try storeRoot(b, MessageGraph.Direct.Message(
            f_bool: m.f_bool, f_int32: m.f_int32, f_int64: m.f_int64, f_float64: m.f_float64,
            f_string: m.f_string, f_bool_2: m.f_bool_2, f_int32_2: m.f_int32_2,
            f_string_2: m.f_string_2
        ))
    }

    static func decodeMessage(_ data: Data, _ start: Int) throws -> Message {
        let m = try MessageGraph.lazyRoot(from: data, at: start)
        return Message(
            f_bool: m.f_bool ?? false, f_int32: m.f_int32 ?? 0, f_int64: m.f_int64 ?? 0,
            f_float64: m.f_float64 ?? 0, f_string: m.f_string ?? "",
            f_bool_2: m.f_bool_2 ?? false, f_int32_2: m.f_int32_2 ?? 0,
            f_string_2: m.f_string_2 ?? ""
        )
    }

    // ── Document ───────────────────────────────────────────────────────────

    static func encodeDocument(_ b: DataArenaBuilder, _ d: Document) throws {
        try storeRoot(b, DocumentGraph.Direct.Document(
            id: d.id,
            status: d.status,
            meta: DocumentGraph.Direct.DocumentMeta(region: d.meta.region, version: d.meta.version),
            items: d.items.map {
                DocumentGraph.Direct.DocumentItem(sku: $0.sku, qty: $0.qty, price_minor: $0.price_minor)
            }
        ))
    }

    static func decodeDocument(_ data: Data, _ start: Int) throws -> Document {
        let d = try DocumentGraph.lazyRoot(from: data, at: start)
        let meta = try d.meta
        return Document(
            id: d.id ?? "",
            status: d.status ?? 0,
            meta: DocumentMeta(region: meta?.region ?? "", version: meta?.version ?? 0),
            items: try d.items.throwingMap {
                DocumentItem(sku: $0.sku ?? "", qty: $0.qty ?? 0, price_minor: $0.price_minor ?? 0)
            }
        )
    }

    // ── Telemetry ──────────────────────────────────────────────────────────

    static func encodeTelemetry(_ b: DataArenaBuilder, _ t: Telemetry) throws {
        try storeRoot(b, TelemetryGraph.Direct.Telemetry(
            source: t.source, ts: t.ts, tags: t.tags, values: t.values
        ))
    }

    static func decodeTelemetry(_ data: Data, _ start: Int) throws -> Telemetry {
        let t = try TelemetryGraph.lazyRoot(from: data, at: start)
        return Telemetry(
            source: t.source ?? "", ts: t.ts ?? 0,
            tags: Array(t.tags), values: Array(t.values)
        )
    }

    // ── Strings ────────────────────────────────────────────────────────────

    static func encodeStrings(_ b: DataArenaBuilder, _ s: Strings) throws {
        try storeRoot(b, StringsGraph.Direct.Strings(items: s.items))
    }

    static func decodeStrings(_ data: Data, _ start: Int) throws -> Strings {
        let s = try StringsGraph.lazyRoot(from: data, at: start)
        return Strings(items: Array(s.items))
    }

    // ── Event ──────────────────────────────────────────────────────────────

    static func encodeEvent(_ b: DataArenaBuilder, _ e: Event) throws {
        try storeRoot(b, EventGraph.Direct.Event(
            event_id: e.event_id, event_type: e.event_type, occurred_at: e.occurred_at,
            producer: e.producer,
            attrs: e.attrs.map { EventGraph.Direct.EventAttr(key: $0.key, value: $0.value) }
        ))
    }

    static func decodeEvent(_ data: Data, _ start: Int) throws -> Event {
        let e = try EventGraph.lazyRoot(from: data, at: start)
        return Event(
            event_id: e.event_id ?? "", event_type: e.event_type ?? "",
            occurred_at: e.occurred_at ?? 0, producer: e.producer ?? "",
            attrs: try e.attrs.throwingMap { EventAttr(key: $0.key ?? "", value: $0.value ?? "") }
        )
    }
}
