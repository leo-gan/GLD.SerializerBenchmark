import Foundation

public enum EventRegularGraph {
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

    public typealias EventRegularGraphGraph = EventArena & EventAttrArena
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
    //   let arena = EventRegularGraph.Arena<MyBrand>()
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

extension EventRegularGraph.Arena {
    public func newEventAttr(key: String? = nil, value: String? = nil) -> EventRegularGraph.EventAttr<EventRegularGraph.Arena<Brand>> {
        let _idx: Int
        _idx = arenaOfEventAttr.count
        arenaOfEventAttr.append(EventRegularGraph.EventAttrValues(key: key, value: value))
        let _packed = UInt64(_idx)
        return EventRegularGraph.EventAttr(__packed: _packed, __graph: self)
    }
}

extension EventRegularGraph.Arena {
    public func newEvent(event_id: String? = nil, event_type: String? = nil, occurred_at: Int64? = nil, producer: String? = nil, attrs: [EventRegularGraph.EventAttr<EventRegularGraph.Arena<Brand>>] = []) -> EventRegularGraph.Event<EventRegularGraph.Arena<Brand>> {
        let _idx: Int
        _idx = arenaOfEvent.count
        arenaOfEvent.append(EventRegularGraph.EventValues(event_id: event_id, event_type: event_type, occurred_at: occurred_at, producer: producer, attrs: attrs.map { $0.__packed }))
        let _packed = UInt64(_idx)
        return EventRegularGraph.Event(__packed: _packed, __graph: self)
    }
}

extension EventRegularGraph.Arena {
    public func adopt<S: EventRegularGraph.EventAttrGraph>(_ src: EventRegularGraph.EventAttr<S>) throws -> EventRegularGraph.EventAttr<EventRegularGraph.Arena<Brand>> {
        var _seen = Set<UInt64>()
        return try _adopt(src, &_seen)
    }
    func _adopt<S: EventRegularGraph.EventAttrGraph>(_ src: EventRegularGraph.EventAttr<S>, _ _seen: inout Set<UInt64>) throws -> EventRegularGraph.EventAttr<EventRegularGraph.Arena<Brand>> {
        guard _seen.insert((UInt64(0) << 48) | UInt64(src._index)).inserted else { throw DagrError.cyclicAdopt }
        defer { _seen.remove((UInt64(0) << 48) | UInt64(src._index)) }
        return newEventAttr(key: src.key, value: src.value)
    }
}

extension EventRegularGraph.Arena {
    public func adopt<S: EventRegularGraph.EventGraph>(_ src: EventRegularGraph.Event<S>) throws -> EventRegularGraph.Event<EventRegularGraph.Arena<Brand>> {
        var _seen = Set<UInt64>()
        return try _adopt(src, &_seen)
    }
    func _adopt<S: EventRegularGraph.EventGraph>(_ src: EventRegularGraph.Event<S>, _ _seen: inout Set<UInt64>) throws -> EventRegularGraph.Event<EventRegularGraph.Arena<Brand>> {
        guard _seen.insert((UInt64(1) << 48) | UInt64(src._index)).inserted else { throw DagrError.cyclicAdopt }
        defer { _seen.remove((UInt64(1) << 48) | UInt64(src._index)) }
        return newEvent(event_id: src.event_id, event_type: src.event_type, occurred_at: src.occurred_at, producer: src.producer, attrs: try src.attrs.map { try _adopt($0, &_seen) })
    }
}

extension EventRegularGraph.EventAttr: CustomStringConvertible {
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

extension EventRegularGraph.Event: CustomStringConvertible {
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

extension EventRegularGraph.EventAttr: Hashable {
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

extension EventRegularGraph.Event: Hashable {
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

extension EventRegularGraph.EventAttr: Equatable {
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

extension EventRegularGraph.EventAttr {
    public static func == <OtherArena: EventRegularGraph.EventAttrGraph>(lhs: Self, rhs: EventRegularGraph.EventAttr<OtherArena>) -> Bool {
        var visited = Set<ArenaPair>()
        return lhs.cycleAwareEqualsAny(other: rhs, visited: &visited)
    }

    public static func != <OtherArena: EventRegularGraph.EventAttrGraph>(lhs: Self, rhs: EventRegularGraph.EventAttr<OtherArena>) -> Bool {
        return !(lhs == rhs)
    }

    func cycleAwareEqualsAny<OtherArena: EventRegularGraph.EventAttrGraph>(
        other: EventRegularGraph.EventAttr<OtherArena>,
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

extension EventRegularGraph.Event: Equatable {
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

extension EventRegularGraph.Event {
    public static func == <OtherArena: EventRegularGraph.EventGraph>(lhs: Self, rhs: EventRegularGraph.Event<OtherArena>) -> Bool {
        var visited = Set<ArenaPair>()
        return lhs.cycleAwareEqualsAny(other: rhs, visited: &visited)
    }

    public static func != <OtherArena: EventRegularGraph.EventGraph>(lhs: Self, rhs: EventRegularGraph.Event<OtherArena>) -> Bool {
        return !(lhs == rhs)
    }

    func cycleAwareEqualsAny<OtherArena: EventRegularGraph.EventGraph>(
        other: EventRegularGraph.Event<OtherArena>,
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

extension EventRegularGraph.EventAttr: ArenaNodeHandle {}
extension EventRegularGraph.EventAttr: ArenaGraphStorable {
    var cycleIdentifier: ArenaCycleIdntifier {
        .init(nodeTypeId: Arena.eventAttrTypeId, nodeIndex: __index)
    }

    public func store(with builder: any ArenaBuilder) throws -> BufferOffset {
        if let offset = try builder.beginStoring(nodeId: cycleIdentifier) {
            return offset
        }
        let _valueValueOffset = try self.value?.store(with: builder)
        let _keyValueOffset = try self.key?.store(with: builder)
        let _valueOffset: BufferOffset? = try _valueValueOffset?.storeForwardPointer(with: builder)
        let _keyOffset: BufferOffset? = try _keyValueOffset?.storeForwardPointer(with: builder)
        let offset = try builder.store(vTable: [_keyOffset, _valueOffset])
        try builder.finishStoring(nodeId: cycleIdentifier, offset: offset)
        return offset
    }

    public func storePacked(with builder: any ArenaBuilder) throws -> PackedStoreResult {
        let before = try builder.beginPackedStoring(nodeId: cycleIdentifier)
        _ = try self.value?.storePacked(with: builder).store(index: 1, with: builder)
        _ = try self.key?.storePacked(with: builder).store(index: 0, with: builder)
        _ = try builder.storeAsLEB(value: builder.cursor.value - before.value)
        return builder.finishPackedStoring(nodeId: cycleIdentifier)
    }
}

extension EventRegularGraph.Event: ArenaNodeHandle {}
extension EventRegularGraph.Event: ArenaGraphStorable {
    var cycleIdentifier: ArenaCycleIdntifier {
        .init(nodeTypeId: Arena.eventTypeId, nodeIndex: __index)
    }

    public func store(with builder: any ArenaBuilder) throws -> BufferOffset {
        if let offset = try builder.beginStoring(nodeId: cycleIdentifier) {
            return offset
        }
        let _attrsValueOffset = try self.attrs.store(with: builder)
        let _producerValueOffset = try self.producer?.store(with: builder)
        let _event_typeValueOffset = try self.event_type?.store(with: builder)
        let _event_idValueOffset = try self.event_id?.store(with: builder)
        let _attrsOffset: BufferOffset? = try _attrsValueOffset.storeForwardPointer(with: builder)
        let _producerOffset: BufferOffset? = try _producerValueOffset?.storeForwardPointer(with: builder)
        let _occurred_atOffset: BufferOffset? = try self.occurred_at?.store(with: builder)
        let _event_typeOffset: BufferOffset? = try _event_typeValueOffset?.storeForwardPointer(with: builder)
        let _event_idOffset: BufferOffset? = try _event_idValueOffset?.storeForwardPointer(with: builder)
        let offset = try builder.store(vTable: [_event_idOffset, _event_typeOffset, _occurred_atOffset, _producerOffset, _attrsOffset])
        try builder.finishStoring(nodeId: cycleIdentifier, offset: offset)
        return offset
    }

    public func storePacked(with builder: any ArenaBuilder) throws -> PackedStoreResult {
        let before = try builder.beginPackedStoring(nodeId: cycleIdentifier)
        _ = try self.attrs.storePacked(with: builder).store(index: 4, with: builder)
        _ = try self.producer?.storePacked(with: builder).store(index: 3, with: builder)
        _ = try self.occurred_at?.storePacked(with: builder).store(index: 2, with: builder)
        _ = try self.event_type?.storePacked(with: builder).store(index: 1, with: builder)
        _ = try self.event_id?.storePacked(with: builder).store(index: 0, with: builder)
        _ = try builder.storeAsLEB(value: builder.cursor.value - before.value)
        return builder.finishPackedStoring(nodeId: cycleIdentifier)
    }
}

extension EventRegularGraph.Arena {
    public func toData() throws -> Foundation.Data {
        guard let root = root else { return Foundation.Data() }
        let builder = DataArenaBuilder()
        let rootOffset = try root.store(with: builder)
        _ = try builder.storeAsLEB(value: (builder.cursor.value - rootOffset.value) << 2)
        return builder.makeData
    }

    /// Build the finished buffer (body, alignment, framing) into a caller-owned builder, so an
    /// encode loop reuses one buffer and its dedup tables. Start from a fresh or `reset()`
    /// builder; returns the buffer length, the bytes are `builder.recordBytes` (a view) or
    /// `builder.makeData` (a copy). An empty arena writes nothing.
    @discardableResult
    public func write(into builder: DataArenaBuilder) throws -> Int {
        guard let root = root else { return 0 }
        let rootOffset = try root.store(with: builder)
        _ = try builder.storeAsLEB(value: (builder.cursor.value - rootOffset.value) << 2)
        return Int(builder.cursor.value)
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

    public static func restore(from data: Foundation.Data) throws -> EventRegularGraph.Arena<Brand> {
        guard !data.isEmpty else { return EventRegularGraph.Arena<Brand>() }
        let arena = EventRegularGraph.Arena<Brand>()
        let (framing, lebLen) = try restoreLEB(from: data, at: 0)
        guard (framing & 1) == 0 else { throw ArenaRestoreError.missingHeader }
        guard ((framing >> 1) & 1) == 0 else { throw ArenaRestoreError.invalidFraming }
        let rootStart = lebLen + Int(framing >> 2)
        var cache = [Int: Int]()
        arena.root = try arena._restoreEvent(from: data, at: rootStart, cache: &cache)
        return arena
    }

    private func _restoreEventAttr(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> EventRegularGraph.EventAttr<EventRegularGraph.Arena<Brand>> {
        if let idx = cache[start] { return EventRegularGraph.EventAttr(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfEventAttr.count
        cache[start] = idx
        arenaOfEventAttr.append(EventRegularGraph.EventAttrValues())
        var values = EventRegularGraph.EventAttrValues()
        let vtable = try restoreRTypeVTable(from: data, start: start)
        if 0 < vtable.count, let _off0 = vtable[0] {
            let (_fwd0, _fwdb0) = try readV62(from: data, at: start + Int(_off0))
            values.key = try String.restore(from: data, at: start + Int(_off0) + _fwdb0 + Int(_fwd0))
        }
        if 1 < vtable.count, let _off1 = vtable[1] {
            let (_fwd1, _fwdb1) = try readV62(from: data, at: start + Int(_off1))
            values.value = try String.restore(from: data, at: start + Int(_off1) + _fwdb1 + Int(_fwd1))
        }
        arenaOfEventAttr[idx] = values
        return EventRegularGraph.EventAttr(__packed: UInt64(idx), __graph: self)
    }

    private func _restoreEventAttrPacked(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> EventRegularGraph.EventAttr<EventRegularGraph.Arena<Brand>> {
        if let idx = cache[start] { return EventRegularGraph.EventAttr(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfEventAttr.count
        cache[start] = idx
        arenaOfEventAttr.append(EventRegularGraph.EventAttrValues())
        var values = EventRegularGraph.EventAttrValues()
        let (_bl, _blB) = try restoreLEB(from: data, at: start)
        var _cursor = start + _blB
        let _end = _cursor + Int(_bl)
        if _cursor < _end {
            let (_tag, _tagB) = try restoreLEB(from: data, at: _cursor)
            if Int(_tag) >> 1 == 0 {
                _cursor += _tagB
                let (_sv_key, _sb_key) = try restoreLEB(from: data, at: _cursor); _cursor += _sb_key
                values.key = _dagrUTF8(data[_cursor..<(_cursor + Int(_sv_key))]); _cursor += Int(_sv_key)
            }
        }
        if _cursor < _end {
            let (_tag, _tagB) = try restoreLEB(from: data, at: _cursor)
            if Int(_tag) >> 1 == 1 {
                _cursor += _tagB
                let (_sv_value, _sb_value) = try restoreLEB(from: data, at: _cursor); _cursor += _sb_value
                values.value = _dagrUTF8(data[_cursor..<(_cursor + Int(_sv_value))]); _cursor += Int(_sv_value)
            }
        }
        arenaOfEventAttr[idx] = values
        return EventRegularGraph.EventAttr(__packed: UInt64(idx), __graph: self)
    }

    private func _restoreEvent(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> EventRegularGraph.Event<EventRegularGraph.Arena<Brand>> {
        if let idx = cache[start] { return EventRegularGraph.Event(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfEvent.count
        cache[start] = idx
        arenaOfEvent.append(EventRegularGraph.EventValues())
        var values = EventRegularGraph.EventValues()
        let vtable = try restoreRTypeVTable(from: data, start: start)
        if 0 < vtable.count, let _off0 = vtable[0] {
            let (_fwd0, _fwdb0) = try readV62(from: data, at: start + Int(_off0))
            values.event_id = try String.restore(from: data, at: start + Int(_off0) + _fwdb0 + Int(_fwd0))
        }
        if 1 < vtable.count, let _off1 = vtable[1] {
            let (_fwd1, _fwdb1) = try readV62(from: data, at: start + Int(_off1))
            values.event_type = try String.restore(from: data, at: start + Int(_off1) + _fwdb1 + Int(_fwd1))
        }
        if 2 < vtable.count, let _off2 = vtable[2] {
            values.occurred_at = try Int64.restore(from: data, at: start + Int(_off2))
        }
        if 3 < vtable.count, let _off3 = vtable[3] {
            let (_fwd3, _fwdb3) = try readV62(from: data, at: start + Int(_off3))
            values.producer = try String.restore(from: data, at: start + Int(_off3) + _fwdb3 + Int(_fwd3))
        }
        if 4 < vtable.count, let _off4 = vtable[4] {
            let (_fwd4, _fwdb4) = try readV62(from: data, at: start + Int(_off4))
            let (_h4, _hl4) = try restoreLEB(from: data, at: start + Int(_off4) + _fwdb4 + Int(_fwd4))
            let _cnt4 = Int(_h4 >> 2); let _wc4 = Int(_h4 & 3)
            let _es4 = [1,2,4,8][_wc4]
            let _base4 = start + Int(_off4) + _fwdb4 + Int(_fwd4) + _hl4 + _cnt4 * _es4
            var _arr4 = [UInt64]()
            for _k4 in 0..<_cnt4 {
                let _ep4 = start + Int(_off4) + _fwdb4 + Int(_fwd4) + _hl4 + _k4 * _es4
                let _ro4 = try readSignedRelOffset(from: data, at: _ep4, size: _es4)
                if _ro4 != 0 {
                    _arr4.append(try _restoreEventAttr(from: data, at: _base4 + Int(_ro4) - 1, cache: &cache).__packed)
                }
            }
            values.attrs = _arr4
        }
        arenaOfEvent[idx] = values
        return EventRegularGraph.Event(__packed: UInt64(idx), __graph: self)
    }

    private func _restoreEventPacked(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> EventRegularGraph.Event<EventRegularGraph.Arena<Brand>> {
        if let idx = cache[start] { return EventRegularGraph.Event(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfEvent.count
        cache[start] = idx
        arenaOfEvent.append(EventRegularGraph.EventValues())
        var values = EventRegularGraph.EventValues()
        let (_bl, _blB) = try restoreLEB(from: data, at: start)
        var _cursor = start + _blB
        let _end = _cursor + Int(_bl)
        if _cursor < _end {
            let (_tag, _tagB) = try restoreLEB(from: data, at: _cursor)
            if Int(_tag) >> 1 == 0 {
                _cursor += _tagB
                let (_sv_event_id, _sb_event_id) = try restoreLEB(from: data, at: _cursor); _cursor += _sb_event_id
                values.event_id = _dagrUTF8(data[_cursor..<(_cursor + Int(_sv_event_id))]); _cursor += Int(_sv_event_id)
            }
        }
        if _cursor < _end {
            let (_tag, _tagB) = try restoreLEB(from: data, at: _cursor)
            if Int(_tag) >> 1 == 1 {
                _cursor += _tagB
                let (_sv_event_type, _sb_event_type) = try restoreLEB(from: data, at: _cursor); _cursor += _sb_event_type
                values.event_type = _dagrUTF8(data[_cursor..<(_cursor + Int(_sv_event_type))]); _cursor += Int(_sv_event_type)
            }
        }
        if _cursor < _end {
            let (_tag, _tagB) = try restoreLEB(from: data, at: _cursor)
            if Int(_tag) >> 1 == 2 {
                _cursor += _tagB
                if _tag & 1 == 0 {
                    let (_v, _b) = try restoreLEB(from: data, at: _cursor); values.occurred_at = Int64(_v.fromZigZag); _cursor += _b
                } else {
                    values.occurred_at = try Int64.restore(from: data, at: _cursor); _cursor += 8
                }
            }
        }
        if _cursor < _end {
            let (_tag, _tagB) = try restoreLEB(from: data, at: _cursor)
            if Int(_tag) >> 1 == 3 {
                _cursor += _tagB
                let (_sv_producer, _sb_producer) = try restoreLEB(from: data, at: _cursor); _cursor += _sb_producer
                values.producer = _dagrUTF8(data[_cursor..<(_cursor + Int(_sv_producer))]); _cursor += Int(_sv_producer)
            }
        }
        if _cursor < _end {
            let (_tag, _tagB) = try restoreLEB(from: data, at: _cursor)
            if Int(_tag) >> 1 == 4 {
                _cursor += _tagB
                let (_abl_attrs, _ablB_attrs) = try restoreLEB(from: data, at: _cursor)
                let _s_attrs = _cursor + _ablB_attrs
                let (_cnt_attrs, _cntB_attrs) = try restoreLEB(from: data, at: _s_attrs)
                var _arr_attrs = [UInt64]()
                var _pos_attrs = _s_attrs + _cntB_attrs
                for _ in 0..<Int(_cnt_attrs) {
                    let (_nb_attrs, _nbb_attrs) = try restoreLEB(from: data, at: _pos_attrs)
                    let _nd_attrs = try _restoreEventAttrPacked(from: data, at: _pos_attrs, cache: &cache)
                    _arr_attrs.append(_nd_attrs.__packed)
                    _pos_attrs += _nbb_attrs + Int(_nb_attrs)
                }
                values.attrs = _arr_attrs
                _cursor = _s_attrs + Int(_abl_attrs)
            }
        }
        arenaOfEvent[idx] = values
        return EventRegularGraph.Event(__packed: UInt64(idx), __graph: self)
    }

}
