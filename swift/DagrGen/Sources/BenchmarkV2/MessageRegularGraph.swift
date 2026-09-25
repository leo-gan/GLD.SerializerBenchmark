import Foundation

public enum MessageRegularGraph {
    public struct MessageValues {
        public var f_bool: Bool? = nil
        public var f_int32: Int32? = nil
        public var f_int64: Int64? = nil
        public var f_float64: Double? = nil
        public var f_string: String? = nil
        public var f_bool_2: Bool? = nil
        public var f_int32_2: Int32? = nil
        public var f_string_2: String? = nil
    }

    public protocol MessageArena: AnyObject {
        static var messageTypeId: Int { get }
        var arenaOfMessage: [MessageValues] { get set }
    }

    public typealias MessageRegularGraphGraph = MessageArena
    public typealias MessageGraph = MessageArena

    public struct Message<Arena: MessageGraph> {
        let __packed: UInt64
        unowned let __graph: Arena

        var __index: Int { Int(__packed & 0x0000_00FF_FFFF_FFFF) }
        var _generation: UInt32 { UInt32(__packed >> 40) }
        var _index: Int { __index }
        var _arenaId: ObjectIdentifier { ObjectIdentifier(__graph) }

        public var f_bool: Bool? {
            get { __graph.arenaOfMessage[__index].f_bool }
            nonmutating set { __graph.arenaOfMessage[__index].f_bool = newValue }
        }
        public var f_int32: Int32? {
            get { __graph.arenaOfMessage[__index].f_int32 }
            nonmutating set { __graph.arenaOfMessage[__index].f_int32 = newValue }
        }
        public var f_int64: Int64? {
            get { __graph.arenaOfMessage[__index].f_int64 }
            nonmutating set { __graph.arenaOfMessage[__index].f_int64 = newValue }
        }
        public var f_float64: Double? {
            get { __graph.arenaOfMessage[__index].f_float64 }
            nonmutating set { __graph.arenaOfMessage[__index].f_float64 = newValue }
        }
        public var f_string: String? {
            get { __graph.arenaOfMessage[__index].f_string }
            nonmutating set { __graph.arenaOfMessage[__index].f_string = newValue }
        }
        public var f_bool_2: Bool? {
            get { __graph.arenaOfMessage[__index].f_bool_2 }
            nonmutating set { __graph.arenaOfMessage[__index].f_bool_2 = newValue }
        }
        public var f_int32_2: Int32? {
            get { __graph.arenaOfMessage[__index].f_int32_2 }
            nonmutating set { __graph.arenaOfMessage[__index].f_int32_2 = newValue }
        }
        public var f_string_2: String? {
            get { __graph.arenaOfMessage[__index].f_string_2 }
            nonmutating set { __graph.arenaOfMessage[__index].f_string_2 = newValue }
        }
    }

    // ── Arena<Brand> ─────────────────────────────────────────────────────────────────
    //
    // Brand is a phantom type — declare an empty enum per arena scope:
    //
    //   enum MyBrand {}
    //   let arena = MessageRegularGraph.Arena<MyBrand>()
    //
    public class Arena<Brand>: MessageArena {
        public static var messageTypeId: Int { 0 }
        public var arenaOfMessage: [MessageValues] = []
        public init() {}

        private var _root: UInt64? = nil
        public var root: Message<Arena<Brand>>? {
            get { _root.map { Message(__packed: $0, __graph: self) } }
            set { _root = newValue?.__packed }
        }
    }


}

extension MessageRegularGraph.Arena {
    public func newMessage(f_bool: Bool? = nil, f_int32: Int32? = nil, f_int64: Int64? = nil, f_float64: Double? = nil, f_string: String? = nil, f_bool_2: Bool? = nil, f_int32_2: Int32? = nil, f_string_2: String? = nil) -> MessageRegularGraph.Message<MessageRegularGraph.Arena<Brand>> {
        let _idx: Int
        _idx = arenaOfMessage.count
        arenaOfMessage.append(MessageRegularGraph.MessageValues(f_bool: f_bool, f_int32: f_int32, f_int64: f_int64, f_float64: f_float64, f_string: f_string, f_bool_2: f_bool_2, f_int32_2: f_int32_2, f_string_2: f_string_2))
        let _packed = UInt64(_idx)
        return MessageRegularGraph.Message(__packed: _packed, __graph: self)
    }
}

extension MessageRegularGraph.Arena {
    public func adopt<S: MessageRegularGraph.MessageGraph>(_ src: MessageRegularGraph.Message<S>) throws -> MessageRegularGraph.Message<MessageRegularGraph.Arena<Brand>> {
        var _seen = Set<UInt64>()
        return try _adopt(src, &_seen)
    }
    func _adopt<S: MessageRegularGraph.MessageGraph>(_ src: MessageRegularGraph.Message<S>, _ _seen: inout Set<UInt64>) throws -> MessageRegularGraph.Message<MessageRegularGraph.Arena<Brand>> {
        guard _seen.insert((UInt64(0) << 48) | UInt64(src._index)).inserted else { throw DagrError.cyclicAdopt }
        defer { _seen.remove((UInt64(0) << 48) | UInt64(src._index)) }
        return newMessage(f_bool: src.f_bool, f_int32: src.f_int32, f_int64: src.f_int64, f_float64: src.f_float64, f_string: src.f_string, f_bool_2: src.f_bool_2, f_int32_2: src.f_int32_2, f_string_2: src.f_string_2)
    }
}

extension MessageRegularGraph.Message: CustomStringConvertible {
    public var description: String {
        var visited = Set<NodeKey>()
        return buildDescription(visited: &visited)
    }

    func buildDescription(visited: inout Set<NodeKey>) -> String {
        let __nodeKey = NodeKey(arena: _arenaId, typeId: Arena.messageTypeId, index: __index)
        guard !visited.contains(__nodeKey) else { return "Message@\(__index)" }
        visited.insert(__nodeKey)
        let f_boolStr = String(describing: f_bool)
        let f_int32Str = String(describing: f_int32)
        let f_int64Str = String(describing: f_int64)
        let f_float64Str = String(describing: f_float64)
        let f_stringStr = f_string.map { "\"\($0)\"" } ?? "nil"
        let f_bool_2Str = String(describing: f_bool_2)
        let f_int32_2Str = String(describing: f_int32_2)
        let f_string_2Str = f_string_2.map { "\"\($0)\"" } ?? "nil"
        return "Message@\(__index) { f_bool: \(f_boolStr), f_int32: \(f_int32Str), f_int64: \(f_int64Str), f_float64: \(f_float64Str), f_string: \(f_stringStr), f_bool_2: \(f_bool_2Str), f_int32_2: \(f_int32_2Str), f_string_2: \(f_string_2Str) }"
    }
}

extension MessageRegularGraph.Message: Hashable {
    public func hash(into hasher: inout Hasher) {
        var visited = Set<NodeKey>()
        hashInto(hasher: &hasher, visited: &visited)
    }

    func hashInto(hasher: inout Hasher, visited: inout Set<NodeKey>) {
        let __nodeKey = NodeKey(arena: _arenaId, typeId: Arena.messageTypeId, index: __index)
        guard !visited.contains(__nodeKey) else { return }
        visited.insert(__nodeKey)
        hasher.combine(f_bool)
        hasher.combine(f_int32)
        hasher.combine(f_int64)
        hasher.combine(f_float64)
        hasher.combine(f_string)
        hasher.combine(f_bool_2)
        hasher.combine(f_int32_2)
        hasher.combine(f_string_2)
    }
}

extension MessageRegularGraph.Message: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        var visited = Set<ArenaPair>()
        return lhs.cycleAwareEquals(other: rhs, visited: &visited)
    }

    func cycleAwareEquals(other: Self, visited: inout Set<ArenaPair>) -> Bool {
        let pair = ArenaPair(
            leftArena: _arenaId, leftTypeId: Arena.messageTypeId, leftIndex: __index,
            rightArena: other._arenaId, rightTypeId: Arena.messageTypeId, rightIndex: other.__index
        )
        guard !visited.contains(pair) else { return true }
        visited.insert(pair)
        guard self.f_bool == other.f_bool else { return false }
        guard self.f_int32 == other.f_int32 else { return false }
        guard self.f_int64 == other.f_int64 else { return false }
        guard self.f_float64 == other.f_float64 else { return false }
        guard self.f_string == other.f_string else { return false }
        guard self.f_bool_2 == other.f_bool_2 else { return false }
        guard self.f_int32_2 == other.f_int32_2 else { return false }
        guard self.f_string_2 == other.f_string_2 else { return false }
        return true
    }
}

extension MessageRegularGraph.Message {
    public static func == <OtherArena: MessageRegularGraph.MessageGraph>(lhs: Self, rhs: MessageRegularGraph.Message<OtherArena>) -> Bool {
        var visited = Set<ArenaPair>()
        return lhs.cycleAwareEqualsAny(other: rhs, visited: &visited)
    }

    public static func != <OtherArena: MessageRegularGraph.MessageGraph>(lhs: Self, rhs: MessageRegularGraph.Message<OtherArena>) -> Bool {
        return !(lhs == rhs)
    }

    func cycleAwareEqualsAny<OtherArena: MessageRegularGraph.MessageGraph>(
        other: MessageRegularGraph.Message<OtherArena>,
        visited: inout Set<ArenaPair>
    ) -> Bool {
        let pair = ArenaPair(
            leftArena: _arenaId, leftTypeId: Arena.messageTypeId, leftIndex: __index,
            rightArena: other._arenaId, rightTypeId: OtherArena.messageTypeId, rightIndex: other.__index
        )
        guard !visited.contains(pair) else { return true }
        visited.insert(pair)
        guard self.f_bool == other.f_bool else { return false }
        guard self.f_int32 == other.f_int32 else { return false }
        guard self.f_int64 == other.f_int64 else { return false }
        guard self.f_float64 == other.f_float64 else { return false }
        guard self.f_string == other.f_string else { return false }
        guard self.f_bool_2 == other.f_bool_2 else { return false }
        guard self.f_int32_2 == other.f_int32_2 else { return false }
        guard self.f_string_2 == other.f_string_2 else { return false }
        return true
    }
}

extension MessageRegularGraph.Message: ArenaNodeHandle {}
extension MessageRegularGraph.Message: ArenaGraphStorable {
    var cycleIdentifier: ArenaCycleIdntifier {
        .init(nodeTypeId: Arena.messageTypeId, nodeIndex: __index)
    }

    public func store(with builder: any ArenaBuilder) throws -> BufferOffset {
        if let offset = try builder.beginStoring(nodeId: cycleIdentifier) {
            return offset
        }
        let _f_string_2ValueOffset = try self.f_string_2?.store(with: builder)
        let _f_stringValueOffset = try self.f_string?.store(with: builder)
        let _f_string_2Offset: BufferOffset? = try _f_string_2ValueOffset?.storeForwardPointer(with: builder)
        let _f_int32_2Offset: BufferOffset? = try self.f_int32_2?.store(with: builder)
        let _f_bool_2Offset: BufferOffset? = try self.f_bool_2?.store(with: builder)
        let _f_stringOffset: BufferOffset? = try _f_stringValueOffset?.storeForwardPointer(with: builder)
        let _f_float64Offset: BufferOffset? = try self.f_float64?.store(with: builder)
        let _f_int64Offset: BufferOffset? = try self.f_int64?.store(with: builder)
        let _f_int32Offset: BufferOffset? = try self.f_int32?.store(with: builder)
        let _f_boolOffset: BufferOffset? = try self.f_bool?.store(with: builder)
        let offset = try builder.store(vTable: [_f_boolOffset, _f_int32Offset, _f_int64Offset, _f_float64Offset, _f_stringOffset, _f_bool_2Offset, _f_int32_2Offset, _f_string_2Offset])
        try builder.finishStoring(nodeId: cycleIdentifier, offset: offset)
        return offset
    }

    public func storePacked(with builder: any ArenaBuilder) throws -> PackedStoreResult {
        let before = try builder.beginPackedStoring(nodeId: cycleIdentifier)
        _ = try self.f_string_2?.storePacked(with: builder).store(index: 7, with: builder)
        _ = try self.f_int32_2?.storePacked(with: builder).store(index: 6, with: builder)
        _ = try self.f_bool_2?.storePacked(with: builder).store(index: 5, with: builder)
        _ = try self.f_string?.storePacked(with: builder).store(index: 4, with: builder)
        if let _rv_f_float64 = self.f_float64 {
            _ = try builder.store(number: _rv_f_float64)
            _ = try PackedStoreResult.raw(8).store(index: 3, with: builder)
        }
        _ = try self.f_int64?.storePacked(with: builder).store(index: 2, with: builder)
        _ = try self.f_int32?.storePacked(with: builder).store(index: 1, with: builder)
        _ = try self.f_bool?.storePacked(with: builder).store(index: 0, with: builder)
        _ = try builder.storeAsLEB(value: builder.cursor.value - before.value)
        return builder.finishPackedStoring(nodeId: cycleIdentifier)
    }
}

extension MessageRegularGraph.Arena {
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

    public static func restore(from data: Foundation.Data) throws -> MessageRegularGraph.Arena<Brand> {
        guard !data.isEmpty else { return MessageRegularGraph.Arena<Brand>() }
        let arena = MessageRegularGraph.Arena<Brand>()
        let (framing, lebLen) = try restoreLEB(from: data, at: 0)
        guard (framing & 1) == 0 else { throw ArenaRestoreError.missingHeader }
        guard ((framing >> 1) & 1) == 0 else { throw ArenaRestoreError.invalidFraming }
        let rootStart = lebLen + Int(framing >> 2)
        var cache = [Int: Int]()
        arena.root = try arena._restoreMessage(from: data, at: rootStart, cache: &cache)
        return arena
    }

    private func _restoreMessage(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> MessageRegularGraph.Message<MessageRegularGraph.Arena<Brand>> {
        if let idx = cache[start] { return MessageRegularGraph.Message(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfMessage.count
        cache[start] = idx
        arenaOfMessage.append(MessageRegularGraph.MessageValues())
        var values = MessageRegularGraph.MessageValues()
        let vtable = try restoreRTypeVTable(from: data, start: start)
        if 0 < vtable.count, let _off0 = vtable[0] {
            values.f_bool = try Bool.restore(from: data, at: start + Int(_off0))
        }
        if 1 < vtable.count, let _off1 = vtable[1] {
            values.f_int32 = try Int32.restore(from: data, at: start + Int(_off1))
        }
        if 2 < vtable.count, let _off2 = vtable[2] {
            values.f_int64 = try Int64.restore(from: data, at: start + Int(_off2))
        }
        if 3 < vtable.count, let _off3 = vtable[3] {
            values.f_float64 = try Double.restore(from: data, at: start + Int(_off3))
        }
        if 4 < vtable.count, let _off4 = vtable[4] {
            let (_fwd4, _fwdb4) = try readV62(from: data, at: start + Int(_off4))
            values.f_string = try String.restore(from: data, at: start + Int(_off4) + _fwdb4 + Int(_fwd4))
        }
        if 5 < vtable.count, let _off5 = vtable[5] {
            values.f_bool_2 = try Bool.restore(from: data, at: start + Int(_off5))
        }
        if 6 < vtable.count, let _off6 = vtable[6] {
            values.f_int32_2 = try Int32.restore(from: data, at: start + Int(_off6))
        }
        if 7 < vtable.count, let _off7 = vtable[7] {
            let (_fwd7, _fwdb7) = try readV62(from: data, at: start + Int(_off7))
            values.f_string_2 = try String.restore(from: data, at: start + Int(_off7) + _fwdb7 + Int(_fwd7))
        }
        arenaOfMessage[idx] = values
        return MessageRegularGraph.Message(__packed: UInt64(idx), __graph: self)
    }

    private func _restoreMessagePacked(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> MessageRegularGraph.Message<MessageRegularGraph.Arena<Brand>> {
        if let idx = cache[start] { return MessageRegularGraph.Message(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfMessage.count
        cache[start] = idx
        arenaOfMessage.append(MessageRegularGraph.MessageValues())
        var values = MessageRegularGraph.MessageValues()
        let (_bl, _blB) = try restoreLEB(from: data, at: start)
        var _cursor = start + _blB
        let _end = _cursor + Int(_bl)
        if _cursor < _end {
            let (_tag, _tagB) = try restoreLEB(from: data, at: _cursor)
            if Int(_tag) >> 1 == 0 {
                _cursor += _tagB
                values.f_bool = data[_cursor] != 0; _cursor += 1
            }
        }
        if _cursor < _end {
            let (_tag, _tagB) = try restoreLEB(from: data, at: _cursor)
            if Int(_tag) >> 1 == 1 {
                _cursor += _tagB
                if _tag & 1 == 0 {
                    let (_v, _b) = try restoreLEB(from: data, at: _cursor); values.f_int32 = Int32(_v.fromZigZag); _cursor += _b
                } else {
                    values.f_int32 = try Int32.restore(from: data, at: _cursor); _cursor += 4
                }
            }
        }
        if _cursor < _end {
            let (_tag, _tagB) = try restoreLEB(from: data, at: _cursor)
            if Int(_tag) >> 1 == 2 {
                _cursor += _tagB
                if _tag & 1 == 0 {
                    let (_v, _b) = try restoreLEB(from: data, at: _cursor); values.f_int64 = Int64(_v.fromZigZag); _cursor += _b
                } else {
                    values.f_int64 = try Int64.restore(from: data, at: _cursor); _cursor += 8
                }
            }
        }
        if _cursor < _end {
            let (_tag, _tagB) = try restoreLEB(from: data, at: _cursor)
            if Int(_tag) >> 1 == 3 {
                _cursor += _tagB
                if _tag & 1 == 0 {
                    let (_fv, _fb) = try _decodePackedFloat64(from: data, at: _cursor)
                    values.f_float64 = _fv; _cursor += _fb
                } else {
                    values.f_float64 = try Double.restore(from: data, at: _cursor); _cursor += 8
                }
            }
        }
        if _cursor < _end {
            let (_tag, _tagB) = try restoreLEB(from: data, at: _cursor)
            if Int(_tag) >> 1 == 4 {
                _cursor += _tagB
                let (_sv_f_string, _sb_f_string) = try restoreLEB(from: data, at: _cursor); _cursor += _sb_f_string
                values.f_string = _dagrUTF8(data[_cursor..<(_cursor + Int(_sv_f_string))]); _cursor += Int(_sv_f_string)
            }
        }
        if _cursor < _end {
            let (_tag, _tagB) = try restoreLEB(from: data, at: _cursor)
            if Int(_tag) >> 1 == 5 {
                _cursor += _tagB
                values.f_bool_2 = data[_cursor] != 0; _cursor += 1
            }
        }
        if _cursor < _end {
            let (_tag, _tagB) = try restoreLEB(from: data, at: _cursor)
            if Int(_tag) >> 1 == 6 {
                _cursor += _tagB
                if _tag & 1 == 0 {
                    let (_v, _b) = try restoreLEB(from: data, at: _cursor); values.f_int32_2 = Int32(_v.fromZigZag); _cursor += _b
                } else {
                    values.f_int32_2 = try Int32.restore(from: data, at: _cursor); _cursor += 4
                }
            }
        }
        if _cursor < _end {
            let (_tag, _tagB) = try restoreLEB(from: data, at: _cursor)
            if Int(_tag) >> 1 == 7 {
                _cursor += _tagB
                let (_sv_f_string_2, _sb_f_string_2) = try restoreLEB(from: data, at: _cursor); _cursor += _sb_f_string_2
                values.f_string_2 = _dagrUTF8(data[_cursor..<(_cursor + Int(_sv_f_string_2))]); _cursor += Int(_sv_f_string_2)
            }
        }
        arenaOfMessage[idx] = values
        return MessageRegularGraph.Message(__packed: UInt64(idx), __graph: self)
    }

}
