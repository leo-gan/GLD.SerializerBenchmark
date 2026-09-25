import Foundation

public enum EventFrozenPackedGraph {
    public struct EventAttrValues {
        public var key: String? = nil
        public var value: String? = nil
    }

    public struct EventValues {
        public var event_id: String? = nil
        public var event_type: String? = nil
        public var occurred_at: Int64? = nil
        public var producer: String? = nil
        public var attrs: [UInt64] = []
    }

    public protocol EventAttrArena: AnyObject {
        static var eventAttrTypeId: Int { get }
        var arenaOfEventAttr: [EventAttrValues] { get set }
    }

    public protocol EventArena: AnyObject {
        static var eventTypeId: Int { get }
        var arenaOfEvent: [EventValues] { get set }
    }

    public typealias EventFrozenPackedGraphGraph = EventArena & EventAttrArena
    public typealias EventAttrGraph = EventAttrArena
    public typealias EventGraph = EventArena & EventAttrArena

    public struct EventAttr<Arena: EventAttrGraph> {
        let __packed: UInt64
        unowned let __graph: Arena

        var __index: Int { Int(__packed & 0x0000_00FF_FFFF_FFFF) }
        var _generation: UInt32 { UInt32(__packed >> 40) }
        var _index: Int { __index }
        var _arenaId: ObjectIdentifier { ObjectIdentifier(__graph) }

        public var key: String? {
            get { __graph.arenaOfEventAttr[__index].key }
            nonmutating set { __graph.arenaOfEventAttr[__index].key = newValue }
        }
        public var value: String? {
            get { __graph.arenaOfEventAttr[__index].value }
            nonmutating set { __graph.arenaOfEventAttr[__index].value = newValue }
        }
    }

    public struct Event<Arena: EventGraph> {
        let __packed: UInt64
        unowned let __graph: Arena

        var __index: Int { Int(__packed & 0x0000_00FF_FFFF_FFFF) }
        var _generation: UInt32 { UInt32(__packed >> 40) }
        var _index: Int { __index }
        var _arenaId: ObjectIdentifier { ObjectIdentifier(__graph) }

        public var event_id: String? {
            get { __graph.arenaOfEvent[__index].event_id }
            nonmutating set { __graph.arenaOfEvent[__index].event_id = newValue }
        }
        public var event_type: String? {
            get { __graph.arenaOfEvent[__index].event_type }
            nonmutating set { __graph.arenaOfEvent[__index].event_type = newValue }
        }
        public var occurred_at: Int64? {
            get { __graph.arenaOfEvent[__index].occurred_at }
            nonmutating set { __graph.arenaOfEvent[__index].occurred_at = newValue }
        }
        public var producer: String? {
            get { __graph.arenaOfEvent[__index].producer }
            nonmutating set { __graph.arenaOfEvent[__index].producer = newValue }
        }
        public var attrs: [EventAttr<Arena>] {
            get {
                return __graph.arenaOfEvent[__index].attrs.map { EventAttr(__packed: $0, __graph: __graph) }
            }
            nonmutating set { __graph.arenaOfEvent[__index].attrs = newValue.map { $0.__packed } }
        }
    }

    // ── Arena<Brand> ─────────────────────────────────────────────────────────────────
    //
    // Brand is a phantom type — declare an empty enum per arena scope:
    //
    //   enum MyBrand {}
    //   let arena = EventFrozenPackedGraph.Arena<MyBrand>()
    //
    public class Arena<Brand>: EventAttrArena, EventArena {
        public static var eventAttrTypeId: Int { 0 }
        public var arenaOfEventAttr: [EventAttrValues] = []
        public static var eventTypeId: Int { 1 }
        public var arenaOfEvent: [EventValues] = []
        public init() {}

        private var _root: UInt64? = nil
        public var root: Event<Arena<Brand>>? {
            get { _root.map { Event(__packed: $0, __graph: self) } }
            set { _root = newValue?.__packed }
        }
    }


}

extension EventFrozenPackedGraph.Arena {
    public func newEventAttr(key: String? = nil, value: String? = nil) -> EventFrozenPackedGraph.EventAttr<EventFrozenPackedGraph.Arena<Brand>> {
        let _idx: Int
        _idx = arenaOfEventAttr.count
        arenaOfEventAttr.append(EventFrozenPackedGraph.EventAttrValues(key: key, value: value))
        let _packed = UInt64(_idx)
        return EventFrozenPackedGraph.EventAttr(__packed: _packed, __graph: self)
    }
}

extension EventFrozenPackedGraph.Arena {
    public func newEvent(event_id: String? = nil, event_type: String? = nil, occurred_at: Int64? = nil, producer: String? = nil, attrs: [EventFrozenPackedGraph.EventAttr<EventFrozenPackedGraph.Arena<Brand>>] = []) -> EventFrozenPackedGraph.Event<EventFrozenPackedGraph.Arena<Brand>> {
        let _idx: Int
        _idx = arenaOfEvent.count
        arenaOfEvent.append(EventFrozenPackedGraph.EventValues(event_id: event_id, event_type: event_type, occurred_at: occurred_at, producer: producer, attrs: attrs.map { $0.__packed }))
        let _packed = UInt64(_idx)
        return EventFrozenPackedGraph.Event(__packed: _packed, __graph: self)
    }
}

extension EventFrozenPackedGraph.Arena {
    public func adopt<S: EventFrozenPackedGraph.EventAttrGraph>(_ src: EventFrozenPackedGraph.EventAttr<S>) throws -> EventFrozenPackedGraph.EventAttr<EventFrozenPackedGraph.Arena<Brand>> {
        var _seen = Set<UInt64>()
        return try _adopt(src, &_seen)
    }
    func _adopt<S: EventFrozenPackedGraph.EventAttrGraph>(_ src: EventFrozenPackedGraph.EventAttr<S>, _ _seen: inout Set<UInt64>) throws -> EventFrozenPackedGraph.EventAttr<EventFrozenPackedGraph.Arena<Brand>> {
        guard _seen.insert((UInt64(0) << 48) | UInt64(src._index)).inserted else { throw DagrError.cyclicAdopt }
        defer { _seen.remove((UInt64(0) << 48) | UInt64(src._index)) }
        return newEventAttr(key: src.key, value: src.value)
    }
}

extension EventFrozenPackedGraph.Arena {
    public func adopt<S: EventFrozenPackedGraph.EventGraph>(_ src: EventFrozenPackedGraph.Event<S>) throws -> EventFrozenPackedGraph.Event<EventFrozenPackedGraph.Arena<Brand>> {
        var _seen = Set<UInt64>()
        return try _adopt(src, &_seen)
    }
    func _adopt<S: EventFrozenPackedGraph.EventGraph>(_ src: EventFrozenPackedGraph.Event<S>, _ _seen: inout Set<UInt64>) throws -> EventFrozenPackedGraph.Event<EventFrozenPackedGraph.Arena<Brand>> {
        guard _seen.insert((UInt64(1) << 48) | UInt64(src._index)).inserted else { throw DagrError.cyclicAdopt }
        defer { _seen.remove((UInt64(1) << 48) | UInt64(src._index)) }
        return newEvent(event_id: src.event_id, event_type: src.event_type, occurred_at: src.occurred_at, producer: src.producer, attrs: try src.attrs.map { try _adopt($0, &_seen) })
    }
}

extension EventFrozenPackedGraph.EventAttr: CustomStringConvertible {
    public var description: String {
        var visited = Set<NodeKey>()
        return buildDescription(visited: &visited)
    }

    func buildDescription(visited: inout Set<NodeKey>) -> String {
        let __nodeKey = NodeKey(arena: _arenaId, typeId: Arena.eventAttrTypeId, index: __index)
        guard !visited.contains(__nodeKey) else { return "EventAttr@\(__index)" }
        visited.insert(__nodeKey)
        let keyStr = key.map { "\"\($0)\"" } ?? "nil"
        let valueStr = value.map { "\"\($0)\"" } ?? "nil"
        return "EventAttr@\(__index) { key: \(keyStr), value: \(valueStr) }"
    }
}

extension EventFrozenPackedGraph.Event: CustomStringConvertible {
    public var description: String {
        var visited = Set<NodeKey>()
        return buildDescription(visited: &visited)
    }

    func buildDescription(visited: inout Set<NodeKey>) -> String {
        let __nodeKey = NodeKey(arena: _arenaId, typeId: Arena.eventTypeId, index: __index)
        guard !visited.contains(__nodeKey) else { return "Event@\(__index)" }
        visited.insert(__nodeKey)
        let event_idStr = event_id.map { "\"\($0)\"" } ?? "nil"
        let event_typeStr = event_type.map { "\"\($0)\"" } ?? "nil"
        let occurred_atStr = String(describing: occurred_at)
        let producerStr = producer.map { "\"\($0)\"" } ?? "nil"
        let attrsStr = "[" + attrs.map { $0.buildDescription(visited: &visited) }.joined(separator: ", ") + "]"
        return "Event@\(__index) { event_id: \(event_idStr), event_type: \(event_typeStr), occurred_at: \(occurred_atStr), producer: \(producerStr), attrs: \(attrsStr) }"
    }
}

extension EventFrozenPackedGraph.EventAttr: Hashable {
    public func hash(into hasher: inout Hasher) {
        var visited = Set<NodeKey>()
        hashInto(hasher: &hasher, visited: &visited)
    }

    func hashInto(hasher: inout Hasher, visited: inout Set<NodeKey>) {
        let __nodeKey = NodeKey(arena: _arenaId, typeId: Arena.eventAttrTypeId, index: __index)
        guard !visited.contains(__nodeKey) else { return }
        visited.insert(__nodeKey)
        hasher.combine(key)
        hasher.combine(value)
    }
}

extension EventFrozenPackedGraph.Event: Hashable {
    public func hash(into hasher: inout Hasher) {
        var visited = Set<NodeKey>()
        hashInto(hasher: &hasher, visited: &visited)
    }

    func hashInto(hasher: inout Hasher, visited: inout Set<NodeKey>) {
        let __nodeKey = NodeKey(arena: _arenaId, typeId: Arena.eventTypeId, index: __index)
        guard !visited.contains(__nodeKey) else { return }
        visited.insert(__nodeKey)
        hasher.combine(event_id)
        hasher.combine(event_type)
        hasher.combine(occurred_at)
        hasher.combine(producer)
        for item in attrs { item.hashInto(hasher: &hasher, visited: &visited) }
    }
}

extension EventFrozenPackedGraph.EventAttr: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        var visited = Set<ArenaPair>()
        return lhs.cycleAwareEquals(other: rhs, visited: &visited)
    }

    func cycleAwareEquals(other: Self, visited: inout Set<ArenaPair>) -> Bool {
        let pair = ArenaPair(
            leftArena: _arenaId, leftTypeId: Arena.eventAttrTypeId, leftIndex: __index,
            rightArena: other._arenaId, rightTypeId: Arena.eventAttrTypeId, rightIndex: other.__index
        )
        guard !visited.contains(pair) else { return true }
        visited.insert(pair)
        guard self.key == other.key else { return false }
        guard self.value == other.value else { return false }
        return true
    }
}

extension EventFrozenPackedGraph.EventAttr {
    public static func == <OtherArena: EventFrozenPackedGraph.EventAttrGraph>(lhs: Self, rhs: EventFrozenPackedGraph.EventAttr<OtherArena>) -> Bool {
        var visited = Set<ArenaPair>()
        return lhs.cycleAwareEqualsAny(other: rhs, visited: &visited)
    }

    public static func != <OtherArena: EventFrozenPackedGraph.EventAttrGraph>(lhs: Self, rhs: EventFrozenPackedGraph.EventAttr<OtherArena>) -> Bool {
        return !(lhs == rhs)
    }

    func cycleAwareEqualsAny<OtherArena: EventFrozenPackedGraph.EventAttrGraph>(
        other: EventFrozenPackedGraph.EventAttr<OtherArena>,
        visited: inout Set<ArenaPair>
    ) -> Bool {
        let pair = ArenaPair(
            leftArena: _arenaId, leftTypeId: Arena.eventAttrTypeId, leftIndex: __index,
            rightArena: other._arenaId, rightTypeId: OtherArena.eventAttrTypeId, rightIndex: other.__index
        )
        guard !visited.contains(pair) else { return true }
        visited.insert(pair)
        guard self.key == other.key else { return false }
        guard self.value == other.value else { return false }
        return true
    }
}

extension EventFrozenPackedGraph.Event: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        var visited = Set<ArenaPair>()
        return lhs.cycleAwareEquals(other: rhs, visited: &visited)
    }

    func cycleAwareEquals(other: Self, visited: inout Set<ArenaPair>) -> Bool {
        let pair = ArenaPair(
            leftArena: _arenaId, leftTypeId: Arena.eventTypeId, leftIndex: __index,
            rightArena: other._arenaId, rightTypeId: Arena.eventTypeId, rightIndex: other.__index
        )
        guard !visited.contains(pair) else { return true }
        visited.insert(pair)
        guard self.event_id == other.event_id else { return false }
        guard self.event_type == other.event_type else { return false }
        guard self.occurred_at == other.occurred_at else { return false }
        guard self.producer == other.producer else { return false }
        let _aattrs = self.attrs, _battrs = other.attrs
        guard _aattrs.count == _battrs.count else { return false }
        guard zip(_aattrs, _battrs).allSatisfy({ a, b in a.cycleAwareEquals(other: b, visited: &visited) }) else { return false }
        return true
    }
}

extension EventFrozenPackedGraph.Event {
    public static func == <OtherArena: EventFrozenPackedGraph.EventGraph>(lhs: Self, rhs: EventFrozenPackedGraph.Event<OtherArena>) -> Bool {
        var visited = Set<ArenaPair>()
        return lhs.cycleAwareEqualsAny(other: rhs, visited: &visited)
    }

    public static func != <OtherArena: EventFrozenPackedGraph.EventGraph>(lhs: Self, rhs: EventFrozenPackedGraph.Event<OtherArena>) -> Bool {
        return !(lhs == rhs)
    }

    func cycleAwareEqualsAny<OtherArena: EventFrozenPackedGraph.EventGraph>(
        other: EventFrozenPackedGraph.Event<OtherArena>,
        visited: inout Set<ArenaPair>
    ) -> Bool {
        let pair = ArenaPair(
            leftArena: _arenaId, leftTypeId: Arena.eventTypeId, leftIndex: __index,
            rightArena: other._arenaId, rightTypeId: OtherArena.eventTypeId, rightIndex: other.__index
        )
        guard !visited.contains(pair) else { return true }
        visited.insert(pair)
        guard self.event_id == other.event_id else { return false }
        guard self.event_type == other.event_type else { return false }
        guard self.occurred_at == other.occurred_at else { return false }
        guard self.producer == other.producer else { return false }
        let _aattrs = self.attrs, _battrs = other.attrs
        guard _aattrs.count == _battrs.count else { return false }
        guard zip(_aattrs, _battrs).allSatisfy({ a, b in a.cycleAwareEqualsAny(other: b, visited: &visited) }) else { return false }
        return true
    }
}

extension EventFrozenPackedGraph.EventAttr: ArenaNodeHandle {}
extension EventFrozenPackedGraph.EventAttr: ArenaGraphStorable {
    var cycleIdentifier: ArenaCycleIdntifier {
        .init(nodeTypeId: Arena.eventAttrTypeId, nodeIndex: __index)
    }

    public func store(with builder: any ArenaBuilder) throws -> BufferOffset {
        if let offset = try builder.beginStoring(nodeId: cycleIdentifier) {
            return offset
        }
        _ = try storePacked(with: builder)
        let offset = builder.cursor
        try builder.finishStoring(nodeId: cycleIdentifier, offset: offset)
        return offset
    }

    public func storePacked(with builder: any ArenaBuilder) throws -> PackedStoreResult {
        let before = try builder.beginPackedStoring(nodeId: cycleIdentifier)
        _ = try self.value?.storePacked(with: builder)
        _ = try self.key?.storePacked(with: builder)
        var _nilByte: UInt8 = 0
        if self.key != nil { _nilByte |= 1 }
        if self.value != nil { _nilByte |= 2 }
        _ = try builder.store(number: _nilByte)
        _ = try builder.storeAsLEB(value: builder.cursor.value - before.value)
        return builder.finishPackedStoring(nodeId: cycleIdentifier)
    }
}

extension EventFrozenPackedGraph.Event: ArenaNodeHandle {}
extension EventFrozenPackedGraph.Event: ArenaGraphStorable {
    var cycleIdentifier: ArenaCycleIdntifier {
        .init(nodeTypeId: Arena.eventTypeId, nodeIndex: __index)
    }

    public func store(with builder: any ArenaBuilder) throws -> BufferOffset {
        if let offset = try builder.beginStoring(nodeId: cycleIdentifier) {
            return offset
        }
        _ = try storePacked(with: builder)
        let offset = builder.cursor
        try builder.finishStoring(nodeId: cycleIdentifier, offset: offset)
        return offset
    }

    public func storePacked(with builder: any ArenaBuilder) throws -> PackedStoreResult {
        let before = try builder.beginPackedStoring(nodeId: cycleIdentifier)
        _ = try self.attrs.storePacked(with: builder)
        _ = try self.producer?.storePacked(with: builder)
        let _occurred_atPackedResult = try self.occurred_at?.storePacked(with: builder)
        _ = try self.event_type?.storePacked(with: builder)
        _ = try self.event_id?.storePacked(with: builder)
        var _encByte: UInt8 = 0
        if _occurred_atPackedResult?.isRaw ?? false { _encByte |= 1 }
        _ = try builder.store(number: _encByte)
        var _nilByte: UInt8 = 0
        if self.event_id != nil { _nilByte |= 1 }
        if self.event_type != nil { _nilByte |= 2 }
        if self.occurred_at != nil { _nilByte |= 4 }
        if self.producer != nil { _nilByte |= 8 }
        if !self.attrs.isEmpty { _nilByte |= 16 }
        _ = try builder.store(number: _nilByte)
        _ = try builder.storeAsLEB(value: builder.cursor.value - before.value)
        return builder.finishPackedStoring(nodeId: cycleIdentifier)
    }
}

extension EventFrozenPackedGraph.Arena {
    public func toData() throws -> Foundation.Data {
        guard let root = root else { return Foundation.Data() }
        let builder = DataArenaBuilder()
        let rootOffset = try root.store(with: builder)
        _ = try builder.storeAsLEB(value: (builder.cursor.value - rootOffset.value) << 2)
        return builder.makeData
    }

    /// Like `toData()`, but with an explicit `maxSize` that sets the back-reference
    /// placeholder width (2 MiB -> 4 B, 1024 -> 2 B). Must match across producers.
    public func toData(maxSize: UInt64) throws -> Foundation.Data {
        guard let root = root else { return Foundation.Data() }
        let builder = DataArenaBuilder(maxSize: maxSize)
        let rootOffset = try root.store(with: builder)
        _ = try builder.storeAsLEB(value: (builder.cursor.value - rootOffset.value) << 2)
        return builder.makeData
    }

    public static func restore(from data: Foundation.Data) throws -> EventFrozenPackedGraph.Arena<Brand> {
        guard !data.isEmpty else { return EventFrozenPackedGraph.Arena<Brand>() }
        let arena = EventFrozenPackedGraph.Arena<Brand>()
        let (framing, lebLen) = try restoreLEB(from: data, at: 0)
        guard (framing & 1) == 0 else { throw ArenaRestoreError.missingHeader }
        guard ((framing >> 1) & 1) == 0 else { throw ArenaRestoreError.invalidFraming }
        let rootStart = lebLen + Int(framing >> 2)
        var cache = [Int: Int]()
        arena.root = try arena._restoreEvent(from: data, at: rootStart, cache: &cache)
        return arena
    }

    private func _restoreEventAttr(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> EventFrozenPackedGraph.EventAttr<EventFrozenPackedGraph.Arena<Brand>> {
        if let idx = cache[start] { return EventFrozenPackedGraph.EventAttr(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfEventAttr.count
        cache[start] = idx
        arenaOfEventAttr.append(EventFrozenPackedGraph.EventAttrValues())
        var values = EventFrozenPackedGraph.EventAttrValues()
        let (_, _blB) = try restoreLEB(from: data, at: start)
        var _cur = start + _blB
        let _obs0 = _cur + 0 < data.count ? data[_cur + 0] : UInt8(0)
        _cur += 1
        if _obs0 & 1 != 0 {
            let (_sv_key, _sb_key) = try restoreLEB(from: data, at: _cur); _cur += _sb_key
            values.key = _dagrUTF8(data[_cur..<(_cur + Int(_sv_key))])
            _cur += Int(_sv_key)
        }
        if _obs0 & 2 != 0 {
            let (_sv_value, _sb_value) = try restoreLEB(from: data, at: _cur); _cur += _sb_value
            values.value = _dagrUTF8(data[_cur..<(_cur + Int(_sv_value))])
            _cur += Int(_sv_value)
        }
        arenaOfEventAttr[idx] = values
        return EventFrozenPackedGraph.EventAttr(__packed: UInt64(idx), __graph: self)
    }

    private func _restoreEvent(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> EventFrozenPackedGraph.Event<EventFrozenPackedGraph.Arena<Brand>> {
        if let idx = cache[start] { return EventFrozenPackedGraph.Event(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfEvent.count
        cache[start] = idx
        arenaOfEvent.append(EventFrozenPackedGraph.EventValues())
        var values = EventFrozenPackedGraph.EventValues()
        let (_, _blB) = try restoreLEB(from: data, at: start)
        var _cur = start + _blB
        let _obs0 = _cur + 0 < data.count ? data[_cur + 0] : UInt8(0)
        _cur += 1
        let _ebs0 = _cur + 0 < data.count ? data[_cur + 0] : UInt8(0)
        _cur += 1
        if _obs0 & 1 != 0 {
            let (_sv_event_id, _sb_event_id) = try restoreLEB(from: data, at: _cur); _cur += _sb_event_id
            values.event_id = _dagrUTF8(data[_cur..<(_cur + Int(_sv_event_id))])
            _cur += Int(_sv_event_id)
        }
        if _obs0 & 2 != 0 {
            let (_sv_event_type, _sb_event_type) = try restoreLEB(from: data, at: _cur); _cur += _sb_event_type
            values.event_type = _dagrUTF8(data[_cur..<(_cur + Int(_sv_event_type))])
            _cur += Int(_sv_event_type)
        }
        if _obs0 & 4 != 0 {
            if _ebs0 & 1 != 0 {
                values.occurred_at = try Int64.restore(from: data, at: _cur); _cur += 8
            } else {
                let (_lv_occurred_at, _lb_occurred_at) = try restoreLEB(from: data, at: _cur)
                values.occurred_at = Int64(_lv_occurred_at.fromZigZag); _cur += _lb_occurred_at
            }
        }
        if _obs0 & 8 != 0 {
            let (_sv_producer, _sb_producer) = try restoreLEB(from: data, at: _cur); _cur += _sb_producer
            values.producer = _dagrUTF8(data[_cur..<(_cur + Int(_sv_producer))])
            _cur += Int(_sv_producer)
        }
        let (_bbl_attrs, _bblB_attrs) = try restoreLEB(from: data, at: _cur)
        let _bend_attrs = _cur + _bblB_attrs + Int(_bbl_attrs)
        _cur += _bblB_attrs
        let (_cnt_attrs, _cntB_attrs) = try restoreLEB(from: data, at: _cur)
        _cur += _cntB_attrs
        var _arr_attrs = [UInt64]()
        for _ in 0..<Int(_cnt_attrs) {
            let (_el_bl_attrs, _el_blB_attrs) = try restoreLEB(from: data, at: _cur)
            _arr_attrs.append(try _restoreEventAttr(from: data, at: _cur, cache: &cache).__packed)
            _cur += _el_blB_attrs + Int(_el_bl_attrs)
        }
        values.attrs = _arr_attrs
        _cur = _bend_attrs
        arenaOfEvent[idx] = values
        return EventFrozenPackedGraph.Event(__packed: UInt64(idx), __graph: self)
    }

}


// ── Direct Graph Builder ("spec/33-direct-graph-builder.md") ─────────────────────
// Arena-free construction for this packed-rooted tree: value structs in,
// byte-identical graph buffer out. `Direct.toData*(v) == Arena.toData*()`.
extension EventFrozenPackedGraph {
    public enum Direct {
        public struct EventAttr: ArenaGraphStorable {
            public var key: String?
            public var value: String?
            public init(key: String? = nil, value: String? = nil) {
                self.key = key
                self.value = value
            }
            public func store(with builder: any ArenaBuilder) throws -> BufferOffset {
                _ = try storePacked(with: builder)
                return builder.cursor
            }
            public func storePacked(with builder: any ArenaBuilder) throws -> PackedStoreResult {
                let before = builder.cursor
        _ = try self.value?.storePacked(with: builder)
        _ = try self.key?.storePacked(with: builder)
        var _nilByte: UInt8 = 0
        if self.key != nil { _nilByte |= 1 }
        if self.value != nil { _nilByte |= 2 }
        _ = try builder.store(number: _nilByte)
                _ = try builder.storeAsLEB(value: builder.cursor.value - before.value)
                return .raw(0)
            }
        }

        public struct Event: ArenaGraphStorable {
            public var event_id: String?
            public var event_type: String?
            public var occurred_at: Int64?
            public var producer: String?
            public var attrs: [EventAttr]
            public init(event_id: String? = nil, event_type: String? = nil, occurred_at: Int64? = nil, producer: String? = nil, attrs: [EventAttr] = []) {
                self.event_id = event_id
                self.event_type = event_type
                self.occurred_at = occurred_at
                self.producer = producer
                self.attrs = attrs
            }
            public func store(with builder: any ArenaBuilder) throws -> BufferOffset {
                _ = try storePacked(with: builder)
                return builder.cursor
            }
            public func storePacked(with builder: any ArenaBuilder) throws -> PackedStoreResult {
                let before = builder.cursor
        _ = try self.attrs.storePacked(with: builder)
        _ = try self.producer?.storePacked(with: builder)
        let _occurred_atPackedResult = try self.occurred_at?.storePacked(with: builder)
        _ = try self.event_type?.storePacked(with: builder)
        _ = try self.event_id?.storePacked(with: builder)
        var _encByte: UInt8 = 0
        if _occurred_atPackedResult?.isRaw ?? false { _encByte |= 1 }
        _ = try builder.store(number: _encByte)
        var _nilByte: UInt8 = 0
        if self.event_id != nil { _nilByte |= 1 }
        if self.event_type != nil { _nilByte |= 2 }
        if self.occurred_at != nil { _nilByte |= 4 }
        if self.producer != nil { _nilByte |= 8 }
        if !self.attrs.isEmpty { _nilByte |= 16 }
        _ = try builder.store(number: _nilByte)
                _ = try builder.storeAsLEB(value: builder.cursor.value - before.value)
                return .raw(0)
            }
        }

        public static func toData(_ root: Event) throws -> Foundation.Data {
            let builder = DataArenaBuilder()
            let rootOffset = try root.store(with: builder)
            _ = try builder.storeAsLEB(value: (builder.cursor.value - rootOffset.value) << 2)
            return builder.makeData
        }
    }
}
