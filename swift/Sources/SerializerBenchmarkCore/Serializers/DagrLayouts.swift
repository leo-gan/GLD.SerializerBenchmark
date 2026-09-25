import Foundation
import BenchmarkV2

// MARK: - Dagr non-default layouts (dagr-regular, dagr-frozen, dagr-frozen-packed)
// Same harness as `dagr` (Dagr.swift: framing, builder reuse, timing policy); only the
// per-type bridges differ. schemas/v2/dagr/schema.py emits every suite type in each layout
// (`deletable=False`): `<T>RegularGraph`, `<T>FrozenGraph`, `<T>FrozenPackedGraph`.
//
// Serialize (timed, conversion inside the timer like SwiftProtobuf's toProtobuf):
//   - frozen-packed: generated `<Graph>.Direct.*` value structs → reused DataArenaBuilder.
//   - regular / frozen: no direct builder is generated for these layouts, so the suite value
//     is built into a fresh generated arena (`<Graph>.Arena`) and its root node stored into
//     the reused DataArenaBuilder (what `Arena.toData()` does, minus its per-call builder).
// Deserialize (timed): generated lazy accessors (`lazyRoot(from:at:)`) → owned suite value.
// regular / frozen accessor getters are `get throws` (vtable / frozen offsets resolved on
// access); frozen-packed accessors decode on construction like packed.

/// Phantom brand for the per-call generated arenas.
enum DagrArenaBrand {}

extension DagrSerializer {

    func prepareRegular(_ fixture: Fixture) throws {
        switch fixture.name {
        case "message":
            bind(fixture, DagrLayoutBridge.encodeMessageRegular, DagrLayoutBridge.decodeMessageRegular)
        case "document":
            bind(fixture, DagrLayoutBridge.encodeDocumentRegular, DagrLayoutBridge.decodeDocumentRegular)
        case "telemetry":
            bind(fixture, DagrLayoutBridge.encodeTelemetryRegular, DagrLayoutBridge.decodeTelemetryRegular)
        case "strings":
            bind(fixture, DagrLayoutBridge.encodeStringsRegular, DagrLayoutBridge.decodeStringsRegular)
        case "event":
            bind(fixture, DagrLayoutBridge.encodeEventRegular, DagrLayoutBridge.decodeEventRegular)
        default:
            throw BenchError.unknownType(fixture.name)
        }
    }

    func prepareFrozen(_ fixture: Fixture) throws {
        switch fixture.name {
        case "message":
            bind(fixture, DagrLayoutBridge.encodeMessageFrozen, DagrLayoutBridge.decodeMessageFrozen)
        case "document":
            bind(fixture, DagrLayoutBridge.encodeDocumentFrozen, DagrLayoutBridge.decodeDocumentFrozen)
        case "telemetry":
            bind(fixture, DagrLayoutBridge.encodeTelemetryFrozen, DagrLayoutBridge.decodeTelemetryFrozen)
        case "strings":
            bind(fixture, DagrLayoutBridge.encodeStringsFrozen, DagrLayoutBridge.decodeStringsFrozen)
        case "event":
            bind(fixture, DagrLayoutBridge.encodeEventFrozen, DagrLayoutBridge.decodeEventFrozen)
        default:
            throw BenchError.unknownType(fixture.name)
        }
    }

    func prepareFrozenPacked(_ fixture: Fixture) throws {
        switch fixture.name {
        case "message":
            bind(fixture, DagrLayoutBridge.encodeMessageFrozenPacked, DagrLayoutBridge.decodeMessageFrozenPacked)
        case "document":
            bind(fixture, DagrLayoutBridge.encodeDocumentFrozenPacked, DagrLayoutBridge.decodeDocumentFrozenPacked)
        case "telemetry":
            bind(fixture, DagrLayoutBridge.encodeTelemetryFrozenPacked, DagrLayoutBridge.decodeTelemetryFrozenPacked)
        case "strings":
            bind(fixture, DagrLayoutBridge.encodeStringsFrozenPacked, DagrLayoutBridge.decodeStringsFrozenPacked)
        case "event":
            bind(fixture, DagrLayoutBridge.encodeEventFrozenPacked, DagrLayoutBridge.decodeEventFrozenPacked)
        default:
            throw BenchError.unknownType(fixture.name)
        }
    }
}

enum DagrLayoutBridge {
    // ── Regular: arena → reused builder ─────────────────────────────────────────

    static func encodeMessageRegular(_ b: DataArenaBuilder, _ m: Message) throws {
        let a = MessageRegularGraph.Arena<DagrArenaBrand>()
        let root = a.newMessage(
            f_bool: m.f_bool, f_int32: m.f_int32, f_int64: m.f_int64, f_float64: m.f_float64,
            f_string: m.f_string, f_bool_2: m.f_bool_2, f_int32_2: m.f_int32_2,
            f_string_2: m.f_string_2
        )
        try withExtendedLifetime(a) { try DagrBridge.storeRoot(b, root) }
    }

    static func decodeMessageRegular(_ data: Data, _ start: Int) throws -> Message {
        let m = try MessageRegularGraph.lazyRoot(from: data, at: start)
        return Message(
            f_bool: try m.f_bool ?? false, f_int32: try m.f_int32 ?? 0, f_int64: try m.f_int64 ?? 0,
            f_float64: try m.f_float64 ?? 0, f_string: try m.f_string ?? "",
            f_bool_2: try m.f_bool_2 ?? false, f_int32_2: try m.f_int32_2 ?? 0,
            f_string_2: try m.f_string_2 ?? ""
        )
    }

    static func encodeDocumentRegular(_ b: DataArenaBuilder, _ d: Document) throws {
        let a = DocumentRegularGraph.Arena<DagrArenaBrand>()
        let root = a.newDocument(
            id: d.id,
            status: d.status,
            meta: a.newDocumentMeta(region: d.meta.region, version: d.meta.version),
            items: d.items.map { a.newDocumentItem(sku: $0.sku, qty: $0.qty, price_minor: $0.price_minor) }
        )
        try withExtendedLifetime(a) { try DagrBridge.storeRoot(b, root) }
    }

    static func decodeDocumentRegular(_ data: Data, _ start: Int) throws -> Document {
        let d = try DocumentRegularGraph.lazyRoot(from: data, at: start)
        let meta = try d.meta
        return Document(
            id: try d.id ?? "",
            status: try d.status ?? 0,
            meta: DocumentMeta(region: try meta?.region ?? "", version: try meta?.version ?? 0),
            items: try d.items.throwingMap {
                DocumentItem(sku: try $0.sku ?? "", qty: try $0.qty ?? 0, price_minor: try $0.price_minor ?? 0)
            }
        )
    }

    static func encodeTelemetryRegular(_ b: DataArenaBuilder, _ t: Telemetry) throws {
        let a = TelemetryRegularGraph.Arena<DagrArenaBrand>()
        let root = a.newTelemetry(source: t.source, ts: t.ts, tags: t.tags, values: t.values)
        try withExtendedLifetime(a) { try DagrBridge.storeRoot(b, root) }
    }

    static func decodeTelemetryRegular(_ data: Data, _ start: Int) throws -> Telemetry {
        let t = try TelemetryRegularGraph.lazyRoot(from: data, at: start)
        let tags = try t.tags, values = try t.values
        // Vtable array accessors are not Sequences (unlike the packed ones): index them.
        return Telemetry(
            source: try t.source ?? "", ts: try t.ts ?? 0,
            tags: (0..<tags.count).map { tags[$0] }, values: (0..<values.count).map { values[$0] }
        )
    }

    static func encodeStringsRegular(_ b: DataArenaBuilder, _ s: Strings) throws {
        let a = StringsRegularGraph.Arena<DagrArenaBrand>()
        let root = a.newStrings(items: s.items)
        try withExtendedLifetime(a) { try DagrBridge.storeRoot(b, root) }
    }

    static func decodeStringsRegular(_ data: Data, _ start: Int) throws -> Strings {
        let items = try StringsRegularGraph.lazyRoot(from: data, at: start).items
        return Strings(items: (0..<items.count).map { items[$0] })
    }

    static func encodeEventRegular(_ b: DataArenaBuilder, _ e: Event) throws {
        let a = EventRegularGraph.Arena<DagrArenaBrand>()
        let root = a.newEvent(
            event_id: e.event_id, event_type: e.event_type, occurred_at: e.occurred_at,
            producer: e.producer,
            attrs: e.attrs.map { a.newEventAttr(key: $0.key, value: $0.value) }
        )
        try withExtendedLifetime(a) { try DagrBridge.storeRoot(b, root) }
    }

    static func decodeEventRegular(_ data: Data, _ start: Int) throws -> Event {
        let e = try EventRegularGraph.lazyRoot(from: data, at: start)
        return Event(
            event_id: try e.event_id ?? "", event_type: try e.event_type ?? "",
            occurred_at: try e.occurred_at ?? 0, producer: try e.producer ?? "",
            attrs: try e.attrs.throwingMap { EventAttr(key: try $0.key ?? "", value: try $0.value ?? "") }
        )
    }

    // ── Frozen: arena → reused builder ─────────────────────────────────────────

    static func encodeMessageFrozen(_ b: DataArenaBuilder, _ m: Message) throws {
        let a = MessageFrozenGraph.Arena<DagrArenaBrand>()
        let root = a.newMessage(
            f_bool: m.f_bool, f_int32: m.f_int32, f_int64: m.f_int64, f_float64: m.f_float64,
            f_string: m.f_string, f_bool_2: m.f_bool_2, f_int32_2: m.f_int32_2,
            f_string_2: m.f_string_2
        )
        try withExtendedLifetime(a) { try DagrBridge.storeRoot(b, root) }
    }

    static func decodeMessageFrozen(_ data: Data, _ start: Int) throws -> Message {
        let m = try MessageFrozenGraph.lazyRoot(from: data, at: start)
        return Message(
            f_bool: try m.f_bool ?? false, f_int32: try m.f_int32 ?? 0, f_int64: try m.f_int64 ?? 0,
            f_float64: try m.f_float64 ?? 0, f_string: try m.f_string ?? "",
            f_bool_2: try m.f_bool_2 ?? false, f_int32_2: try m.f_int32_2 ?? 0,
            f_string_2: try m.f_string_2 ?? ""
        )
    }

    static func encodeDocumentFrozen(_ b: DataArenaBuilder, _ d: Document) throws {
        let a = DocumentFrozenGraph.Arena<DagrArenaBrand>()
        let root = a.newDocument(
            id: d.id,
            status: d.status,
            meta: a.newDocumentMeta(region: d.meta.region, version: d.meta.version),
            items: d.items.map { a.newDocumentItem(sku: $0.sku, qty: $0.qty, price_minor: $0.price_minor) }
        )
        try withExtendedLifetime(a) { try DagrBridge.storeRoot(b, root) }
    }

    static func decodeDocumentFrozen(_ data: Data, _ start: Int) throws -> Document {
        let d = try DocumentFrozenGraph.lazyRoot(from: data, at: start)
        let meta = try d.meta
        return Document(
            id: try d.id ?? "",
            status: try d.status ?? 0,
            meta: DocumentMeta(region: try meta?.region ?? "", version: try meta?.version ?? 0),
            items: try d.items.throwingMap {
                DocumentItem(sku: try $0.sku ?? "", qty: try $0.qty ?? 0, price_minor: try $0.price_minor ?? 0)
            }
        )
    }

    static func encodeTelemetryFrozen(_ b: DataArenaBuilder, _ t: Telemetry) throws {
        let a = TelemetryFrozenGraph.Arena<DagrArenaBrand>()
        let root = a.newTelemetry(source: t.source, ts: t.ts, tags: t.tags, values: t.values)
        try withExtendedLifetime(a) { try DagrBridge.storeRoot(b, root) }
    }

    static func decodeTelemetryFrozen(_ data: Data, _ start: Int) throws -> Telemetry {
        let t = try TelemetryFrozenGraph.lazyRoot(from: data, at: start)
        let tags = try t.tags, values = try t.values
        // Vtable array accessors are not Sequences (unlike the packed ones): index them.
        return Telemetry(
            source: try t.source ?? "", ts: try t.ts ?? 0,
            tags: (0..<tags.count).map { tags[$0] }, values: (0..<values.count).map { values[$0] }
        )
    }

    static func encodeStringsFrozen(_ b: DataArenaBuilder, _ s: Strings) throws {
        let a = StringsFrozenGraph.Arena<DagrArenaBrand>()
        let root = a.newStrings(items: s.items)
        try withExtendedLifetime(a) { try DagrBridge.storeRoot(b, root) }
    }

    static func decodeStringsFrozen(_ data: Data, _ start: Int) throws -> Strings {
        let items = try StringsFrozenGraph.lazyRoot(from: data, at: start).items
        return Strings(items: (0..<items.count).map { items[$0] })
    }

    static func encodeEventFrozen(_ b: DataArenaBuilder, _ e: Event) throws {
        let a = EventFrozenGraph.Arena<DagrArenaBrand>()
        let root = a.newEvent(
            event_id: e.event_id, event_type: e.event_type, occurred_at: e.occurred_at,
            producer: e.producer,
            attrs: e.attrs.map { a.newEventAttr(key: $0.key, value: $0.value) }
        )
        try withExtendedLifetime(a) { try DagrBridge.storeRoot(b, root) }
    }

    static func decodeEventFrozen(_ data: Data, _ start: Int) throws -> Event {
        let e = try EventFrozenGraph.lazyRoot(from: data, at: start)
        return Event(
            event_id: try e.event_id ?? "", event_type: try e.event_type ?? "",
            occurred_at: try e.occurred_at ?? 0, producer: try e.producer ?? "",
            attrs: try e.attrs.throwingMap { EventAttr(key: try $0.key ?? "", value: try $0.value ?? "") }
        )
    }

    // ── FrozenPacked: direct builder → reused builder (as `dagr`) ───────────

    static func encodeMessageFrozenPacked(_ b: DataArenaBuilder, _ m: Message) throws {
        try DagrBridge.storeRoot(b, MessageFrozenPackedGraph.Direct.Message(
            f_bool: m.f_bool, f_int32: m.f_int32, f_int64: m.f_int64, f_float64: m.f_float64,
            f_string: m.f_string, f_bool_2: m.f_bool_2, f_int32_2: m.f_int32_2,
            f_string_2: m.f_string_2
        ))
    }

    static func decodeMessageFrozenPacked(_ data: Data, _ start: Int) throws -> Message {
        let m = try MessageFrozenPackedGraph.lazyRoot(from: data, at: start)
        return Message(
            f_bool: m.f_bool ?? false, f_int32: m.f_int32 ?? 0, f_int64: m.f_int64 ?? 0,
            f_float64: m.f_float64 ?? 0, f_string: m.f_string ?? "",
            f_bool_2: m.f_bool_2 ?? false, f_int32_2: m.f_int32_2 ?? 0,
            f_string_2: m.f_string_2 ?? ""
        )
    }

    static func encodeDocumentFrozenPacked(_ b: DataArenaBuilder, _ d: Document) throws {
        try DagrBridge.storeRoot(b, DocumentFrozenPackedGraph.Direct.Document(
            id: d.id,
            status: d.status,
            meta: DocumentFrozenPackedGraph.Direct.DocumentMeta(region: d.meta.region, version: d.meta.version),
            items: d.items.map {
                DocumentFrozenPackedGraph.Direct.DocumentItem(sku: $0.sku, qty: $0.qty, price_minor: $0.price_minor)
            }
        ))
    }

    static func decodeDocumentFrozenPacked(_ data: Data, _ start: Int) throws -> Document {
        let d = try DocumentFrozenPackedGraph.lazyRoot(from: data, at: start)
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

    static func encodeTelemetryFrozenPacked(_ b: DataArenaBuilder, _ t: Telemetry) throws {
        try DagrBridge.storeRoot(b, TelemetryFrozenPackedGraph.Direct.Telemetry(
            source: t.source, ts: t.ts, tags: t.tags, values: t.values
        ))
    }

    static func decodeTelemetryFrozenPacked(_ data: Data, _ start: Int) throws -> Telemetry {
        let t = try TelemetryFrozenPackedGraph.lazyRoot(from: data, at: start)
        return Telemetry(
            source: t.source ?? "", ts: t.ts ?? 0,
            tags: Array(t.tags), values: Array(t.values)
        )
    }

    static func encodeStringsFrozenPacked(_ b: DataArenaBuilder, _ s: Strings) throws {
        try DagrBridge.storeRoot(b, StringsFrozenPackedGraph.Direct.Strings(items: s.items))
    }

    static func decodeStringsFrozenPacked(_ data: Data, _ start: Int) throws -> Strings {
        let s = try StringsFrozenPackedGraph.lazyRoot(from: data, at: start)
        return Strings(items: Array(s.items))
    }

    static func encodeEventFrozenPacked(_ b: DataArenaBuilder, _ e: Event) throws {
        try DagrBridge.storeRoot(b, EventFrozenPackedGraph.Direct.Event(
            event_id: e.event_id, event_type: e.event_type, occurred_at: e.occurred_at,
            producer: e.producer,
            attrs: e.attrs.map { EventFrozenPackedGraph.Direct.EventAttr(key: $0.key, value: $0.value) }
        ))
    }

    static func decodeEventFrozenPacked(_ data: Data, _ start: Int) throws -> Event {
        let e = try EventFrozenPackedGraph.lazyRoot(from: data, at: start)
        return Event(
            event_id: e.event_id ?? "", event_type: e.event_type ?? "",
            occurred_at: e.occurred_at ?? 0, producer: e.producer ?? "",
            attrs: try e.attrs.throwingMap { EventAttr(key: $0.key ?? "", value: $0.value ?? "") }
        )
    }
}
