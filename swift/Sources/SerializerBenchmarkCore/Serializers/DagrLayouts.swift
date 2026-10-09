import Foundation
import BenchmarkV2

// MARK: - Dagr non-default layouts (dagr-regular, dagr-frozen, dagr-frozen-packed)
// Same harness as `dagr-packed` (Dagr.swift: framing, builder reuse, timing policy); only the
// per-type bridges differ. schemas/v2/dagr/schema.py emits every suite type in each layout
// (`deletable=False`): `<T>RegularGraph`, `<T>FrozenGraph`, `<T>FrozenPackedGraph`.
// `graph` is regular and frozen only. Packed inlines a reference, so Person.next cannot
// be a ring. The arena reuses one region node per shared Region and wires the person ring.
// Decode fully materializes suite classes (same timed path as the other suite types).
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
        case "graph":
            bind(fixture, DagrLayoutBridge.encodeBookRegular, DagrLayoutBridge.decodeBookRegular)
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
        case "graph":
            bind(fixture, DagrLayoutBridge.encodeBookFrozen, DagrLayoutBridge.decodeBookFrozen)
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
        case "graph":
            throw BenchError.unsupported("dagr-frozen-packed cannot represent graph")
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
            tags: (0..<tags.count).map { tags[$0] }, values: values.toArray()  // one block copy (Dagr spec/43)
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
            tags: (0..<tags.count).map { tags[$0] }, values: values.toArray()  // one block copy (Dagr spec/43)
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

    // ── FrozenPacked: direct builder → reused builder (as `dagr-packed`) ───────────

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
            tags: Array(t.tags), values: t.values.toArray()  // one block copy (Dagr spec/43)
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

    // ── Graph (regular / frozen arenas only) ───────────────────────────────────

    static func encodeBookRegular(_ b: DataArenaBuilder, _ book: Book) throws {
        let a = GraphRegularGraph.Arena<DagrArenaBrand>()
        typealias G = GraphRegularGraph.Arena<DagrArenaBrand>
        let root: GraphRegularGraph.Book<G> = arenaGraph(
            book,
            newRegion: { (code: String, note: String, version: Int32) -> GraphRegularGraph.Region<G> in
                a.newRegion(code: code, note: note, version: version)
            },
            newOrder: { (sku: String, qty: Int32, region: GraphRegularGraph.Region<G>) -> GraphRegularGraph.Order<G> in
                a.newOrder(sku: sku, qty: qty, region: region)
            },
            newPerson: { (name: String) -> GraphRegularGraph.Person<G> in
                a.newPerson(name: name)
            },
            setNext: { (person: GraphRegularGraph.Person<G>, next: GraphRegularGraph.Person<G>) in
                person.next = next
            },
            newBook: { (orders: [GraphRegularGraph.Order<G>], people: [GraphRegularGraph.Person<G>]) -> GraphRegularGraph.Book<G> in
                a.newBook(orders: orders, people: people)
            }
        )
        try withExtendedLifetime(a) { try DagrBridge.storeRoot(b, root) }
    }

    static func decodeBookRegular(_ data: Data, _ start: Int) throws -> Book {
        let root = try GraphRegularGraph.lazyRoot(from: data, at: start)
        let orders = try root.orders
        let people = try root.people
        return try suiteBook(
            orderCount: orders.count,
            orderAt: { try orders[$0] },
            sku: { try $0.sku },
            qty: { try $0.qty },
            regionOf: { try $0.region },
            code: { try $0.code },
            note: { try $0.note },
            version: { try $0.version },
            personCount: people.count,
            personAt: { try people[$0] },
            name: { try $0.name },
            nextOf: { try $0.next }
        )
    }

    static func encodeBookFrozen(_ b: DataArenaBuilder, _ book: Book) throws {
        let a = GraphFrozenGraph.Arena<DagrArenaBrand>()
        typealias G = GraphFrozenGraph.Arena<DagrArenaBrand>
        let root: GraphFrozenGraph.Book<G> = arenaGraph(
            book,
            newRegion: { (code: String, note: String, version: Int32) -> GraphFrozenGraph.Region<G> in
                a.newRegion(code: code, note: note, version: version)
            },
            newOrder: { (sku: String, qty: Int32, region: GraphFrozenGraph.Region<G>) -> GraphFrozenGraph.Order<G> in
                a.newOrder(sku: sku, qty: qty, region: region)
            },
            newPerson: { (name: String) -> GraphFrozenGraph.Person<G> in
                a.newPerson(name: name)
            },
            setNext: { (person: GraphFrozenGraph.Person<G>, next: GraphFrozenGraph.Person<G>) in
                person.next = next
            },
            newBook: { (orders: [GraphFrozenGraph.Order<G>], people: [GraphFrozenGraph.Person<G>]) -> GraphFrozenGraph.Book<G> in
                a.newBook(orders: orders, people: people)
            }
        )
        try withExtendedLifetime(a) { try DagrBridge.storeRoot(b, root) }
    }

    static func decodeBookFrozen(_ data: Data, _ start: Int) throws -> Book {
        let root = try GraphFrozenGraph.lazyRoot(from: data, at: start)
        let orders = try root.orders
        let people = try root.people
        return try suiteBook(
            orderCount: orders.count,
            orderAt: { try orders[$0] },
            sku: { try $0.sku },
            qty: { try $0.qty },
            regionOf: { try $0.region },
            code: { try $0.code },
            note: { try $0.note },
            version: { try $0.version },
            personCount: people.count,
            personAt: { try people[$0] },
            name: { try $0.name },
            nextOf: { try $0.next }
        )
    }
}

/// One arena node per distinct Region. One person node per list slot, then Person.next.
private func arenaGraph<RegionNode, OrderNode, PersonNode, BookNode>(
    _ book: Book,
    newRegion: (String, String, Int32) -> RegionNode,
    newOrder: (String, Int32, RegionNode) -> OrderNode,
    newPerson: (String) -> PersonNode,
    setNext: (PersonNode, PersonNode) -> Void,
    newBook: ([OrderNode], [PersonNode]) -> BookNode
) -> BookNode {
    var regs: [ObjectIdentifier: RegionNode] = [:]
    var orders: [OrderNode] = []
    orders.reserveCapacity(book.orders.count)
    for order in book.orders {
        let id = ObjectIdentifier(order.region)
        let region: RegionNode
        if let found = regs[id] {
            region = found
        } else {
            let created = newRegion(order.region.code, order.region.note, order.region.version)
            regs[id] = created
            region = created
        }
        orders.append(newOrder(order.sku, order.qty, region))
    }
    var people: [PersonNode] = []
    people.reserveCapacity(book.people.count)
    var index: [ObjectIdentifier: PersonNode] = [:]
    for person in book.people {
        let node = newPerson(person.name)
        people.append(node)
        index[ObjectIdentifier(person)] = node
    }
    for (slot, person) in book.people.enumerated() {
        if let nxt = person.next, let target = index[ObjectIdentifier(nxt)] {
            setNext(people[slot], target)
        }
    }
    return newBook(orders, people)
}

/// Generated accessors keep the node byte offset in internal `_nodeStart`, the field
/// after `Data`. That offset is the identity key (Go's BufferPos).
private struct DagrAccessorPrefix {
    let data: Data
    let nodeStart: Int
}

private let dagrNodeStartOffset = MemoryLayout<DagrAccessorPrefix>.offset(of: \.nodeStart)!

private func dagrNodeStart<T>(_ accessor: T) -> Int {
    let start = withUnsafeBytes(of: accessor) { raw -> Int in
        precondition(
            raw.count >= dagrNodeStartOffset + MemoryLayout<Int>.size,
            "dagr graph: accessor shorter than node start"
        )
        return raw.loadUnaligned(fromByteOffset: dagrNodeStartOffset, as: Int.self)
    }
    #if DEBUG
    if let mirrored = dagrMirrorNodeStart(accessor), mirrored != start {
        preconditionFailure("dagr graph: _nodeStart \(mirrored) != offset read \(start)")
    }
    #endif
    return start
}

#if DEBUG
private func dagrMirrorNodeStart<T>(_ accessor: T) -> Int? {
    for child in Mirror(reflecting: accessor).children where child.label == "_nodeStart" {
        if let start = child.value as? Int { return start }
    }
    return nil
}
#endif

/// Full materialize. Regions and people are interned by buffer offset so shared
/// regions stay one object and the person ring is the same objects as the list.
private func suiteBook<OA, RA, PA>(
    orderCount: Int,
    orderAt: (Int) throws -> OA,
    sku: (OA) throws -> String?,
    qty: (OA) throws -> Int32?,
    regionOf: (OA) throws -> RA?,
    code: (RA) throws -> String?,
    note: (RA) throws -> String?,
    version: (RA) throws -> Int32?,
    personCount: Int,
    personAt: (Int) throws -> PA,
    name: (PA) throws -> String?,
    nextOf: (PA) throws -> PA?
) throws -> Book {
    var regs: [Int: Region] = [:]
    var peopleSeen: [Int: Person] = [:]

    func region(_ acc: RA) throws -> Region {
        let key = dagrNodeStart(acc)
        if let hit = regs[key] { return hit }
        let made = Region(
            code: try code(acc) ?? "",
            note: try note(acc) ?? "",
            version: try version(acc) ?? 0
        )
        regs[key] = made
        return made
    }

    func person(_ acc: PA) throws -> Person {
        let key = dagrNodeStart(acc)
        if let hit = peopleSeen[key] { return hit }
        let made = Person(name: try name(acc) ?? "")
        peopleSeen[key] = made
        if let nxt = try nextOf(acc) {
            made.next = try person(nxt)
        }
        return made
    }

    var orders: [Order] = []
    orders.reserveCapacity(orderCount)
    for i in 0..<orderCount {
        let entry = try orderAt(i)
        guard let reg = try regionOf(entry) else {
            throw BenchError.unsupported("dagr graph: order missing region")
        }
        orders.append(Order(sku: try sku(entry) ?? "", qty: try qty(entry) ?? 0, region: try region(reg)))
    }
    var people: [Person] = []
    people.reserveCapacity(personCount)
    for i in 0..<personCount {
        people.append(try person(try personAt(i)))
    }
    return Book(orders: orders, people: people)
}
