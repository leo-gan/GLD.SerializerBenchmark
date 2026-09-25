import Foundation

public enum MessageFrozenGraph {
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

    public typealias MessageFrozenGraphGraph = MessageArena
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
    //   let arena = MessageFrozenGraph.Arena<MyBrand>()
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

extension MessageFrozenGraph.Arena {
    public func newMessage(f_bool: Bool? = nil, f_int32: Int32? = nil, f_int64: Int64? = nil, f_float64: Double? = nil, f_string: String? = nil, f_bool_2: Bool? = nil, f_int32_2: Int32? = nil, f_string_2: String? = nil) -> MessageFrozenGraph.Message<MessageFrozenGraph.Arena<Brand>> {
        let _idx: Int
        _idx = arenaOfMessage.count
        arenaOfMessage.append(MessageFrozenGraph.MessageValues(f_bool: f_bool, f_int32: f_int32, f_int64: f_int64, f_float64: f_float64, f_string: f_string, f_bool_2: f_bool_2, f_int32_2: f_int32_2, f_string_2: f_string_2))
        let _packed = UInt64(_idx)
        return MessageFrozenGraph.Message(__packed: _packed, __graph: self)
    }
}

extension MessageFrozenGraph.Arena {
    public func adopt<S: MessageFrozenGraph.MessageGraph>(_ src: MessageFrozenGraph.Message<S>) throws -> MessageFrozenGraph.Message<MessageFrozenGraph.Arena<Brand>> {
        var _seen = Set<UInt64>()
        return try _adopt(src, &_seen)
    }
    func _adopt<S: MessageFrozenGraph.MessageGraph>(_ src: MessageFrozenGraph.Message<S>, _ _seen: inout Set<UInt64>) throws -> MessageFrozenGraph.Message<MessageFrozenGraph.Arena<Brand>> {
        guard _seen.insert((UInt64(0) << 48) | UInt64(src._index)).inserted else { throw DagrError.cyclicAdopt }
        defer { _seen.remove((UInt64(0) << 48) | UInt64(src._index)) }
        return newMessage(f_bool: src.f_bool, f_int32: src.f_int32, f_int64: src.f_int64, f_float64: src.f_float64, f_string: src.f_string, f_bool_2: src.f_bool_2, f_int32_2: src.f_int32_2, f_string_2: src.f_string_2)
    }
}

extension MessageFrozenGraph.Message: CustomStringConvertible {
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

extension MessageFrozenGraph.Message: Hashable {
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

extension MessageFrozenGraph.Message: Equatable {
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

extension MessageFrozenGraph.Message {
    public static func == <OtherArena: MessageFrozenGraph.MessageGraph>(lhs: Self, rhs: MessageFrozenGraph.Message<OtherArena>) -> Bool {
        var visited = Set<ArenaPair>()
        return lhs.cycleAwareEqualsAny(other: rhs, visited: &visited)
    }

    public static func != <OtherArena: MessageFrozenGraph.MessageGraph>(lhs: Self, rhs: MessageFrozenGraph.Message<OtherArena>) -> Bool {
        return !(lhs == rhs)
    }

    func cycleAwareEqualsAny<OtherArena: MessageFrozenGraph.MessageGraph>(
        other: MessageFrozenGraph.Message<OtherArena>,
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

extension MessageFrozenGraph.Message: ArenaNodeHandle {}
extension MessageFrozenGraph.Message: ArenaGraphStorable {
    var cycleIdentifier: ArenaCycleIdntifier {
        .init(nodeTypeId: Arena.messageTypeId, nodeIndex: __index)
    }

    public func store(with builder: any ArenaBuilder) throws -> BufferOffset {
        if let offset = try builder.beginStoring(nodeId: cycleIdentifier) {
            return offset
        }
        let _f_string_2ValueOffset = try self.f_string_2?.store(with: builder)
        let _f_stringValueOffset = try self.f_string?.store(with: builder)
        _ = try _f_string_2ValueOffset?.storeForwardPointer(with: builder)
        _ = try self.f_int32_2?.store(with: builder)
        _ = try self.f_bool_2?.store(with: builder)
        _ = try _f_stringValueOffset?.storeForwardPointer(with: builder)
        _ = try self.f_float64?.store(with: builder)
        _ = try self.f_int64?.store(with: builder)
        _ = try self.f_int32?.store(with: builder)
        _ = try self.f_bool?.store(with: builder)
        var _nilByte: UInt8 = 0
        if self.f_bool != nil { _nilByte |= 1 }
        if self.f_int32 != nil { _nilByte |= 2 }
        if self.f_int64 != nil { _nilByte |= 4 }
        if self.f_float64 != nil { _nilByte |= 8 }
        if self.f_string != nil { _nilByte |= 16 }
        if self.f_bool_2 != nil { _nilByte |= 32 }
        if self.f_int32_2 != nil { _nilByte |= 64 }
        if self.f_string_2 != nil { _nilByte |= 128 }
        _ = try builder.store(number: _nilByte)
        let offset = builder.cursor
        try builder.finishStoring(nodeId: cycleIdentifier, offset: offset)
        return offset
    }

    public func storePacked(with builder: any ArenaBuilder) throws -> PackedStoreResult {
        let before = try builder.beginPackedStoring(nodeId: cycleIdentifier)
        _ = try self.f_string_2?.storePacked(with: builder)
        let _f_int32_2PackedResult = try self.f_int32_2?.storePacked(with: builder)
        _ = try self.f_bool_2?.storePacked(with: builder)
        _ = try self.f_string?.storePacked(with: builder)
        if let _rv_f_float64 = self.f_float64 { _ = try builder.store(number: _rv_f_float64) }
        let _f_int64PackedResult = try self.f_int64?.storePacked(with: builder)
        let _f_int32PackedResult = try self.f_int32?.storePacked(with: builder)
        _ = try self.f_bool?.storePacked(with: builder)
        var _encByte: UInt8 = 0
        if _f_int32PackedResult?.isRaw ?? false { _encByte |= 1 }
        if _f_int64PackedResult?.isRaw ?? false { _encByte |= 2 }
        if (self.f_float64 != nil) { _encByte |= 4 }
        if _f_int32_2PackedResult?.isRaw ?? false { _encByte |= 8 }
        _ = try builder.store(number: _encByte)
        var _nilByte: UInt8 = 0
        if self.f_bool != nil { _nilByte |= 1 }
        if self.f_int32 != nil { _nilByte |= 2 }
        if self.f_int64 != nil { _nilByte |= 4 }
        if self.f_float64 != nil { _nilByte |= 8 }
        if self.f_string != nil { _nilByte |= 16 }
        if self.f_bool_2 != nil { _nilByte |= 32 }
        if self.f_int32_2 != nil { _nilByte |= 64 }
        if self.f_string_2 != nil { _nilByte |= 128 }
        _ = try builder.store(number: _nilByte)
        _ = try builder.storeAsLEB(value: builder.cursor.value - before.value)
        return builder.finishPackedStoring(nodeId: cycleIdentifier)
    }
}

extension MessageFrozenGraph.Arena {
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

    public static func restore(from data: Foundation.Data) throws -> MessageFrozenGraph.Arena<Brand> {
        guard !data.isEmpty else { return MessageFrozenGraph.Arena<Brand>() }
        let arena = MessageFrozenGraph.Arena<Brand>()
        let (framing, lebLen) = try restoreLEB(from: data, at: 0)
        guard (framing & 1) == 0 else { throw ArenaRestoreError.missingHeader }
        guard ((framing >> 1) & 1) == 0 else { throw ArenaRestoreError.invalidFraming }
        let rootStart = lebLen + Int(framing >> 2)
        var cache = [Int: Int]()
        arena.root = try arena._restoreMessage(from: data, at: rootStart, cache: &cache)
        return arena
    }

    private func _restoreMessage(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> MessageFrozenGraph.Message<MessageFrozenGraph.Arena<Brand>> {
        if let idx = cache[start] { return MessageFrozenGraph.Message(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfMessage.count
        cache[start] = idx
        arenaOfMessage.append(MessageFrozenGraph.MessageValues())
        var values = MessageFrozenGraph.MessageValues()
        let _obs0 = start + 0 < data.count ? data[start + 0] : UInt8(0)
        var _cur = start + 1
        if _obs0 & 1 != 0 {
            guard _cur >= 0, _cur < data.count else { throw ArenaRestoreError.outsideOfBuffer }
            values.f_bool = data[_cur] != 0
            _cur += 1
        }
        if _obs0 & 2 != 0 {
            values.f_int32 = try Int32.restore(from: data, at: _cur)
            _cur += 4
        }
        if _obs0 & 4 != 0 {
            values.f_int64 = try Int64.restore(from: data, at: _cur)
            _cur += 8
        }
        if _obs0 & 8 != 0 {
            values.f_float64 = try Double.restore(from: data, at: _cur)
            _cur += 8
        }
        if _obs0 & 16 != 0 {
            let (_fwd_f_string, _fwdB_f_string) = try readV62(from: data, at: _cur)
            _cur += _fwdB_f_string
            values.f_string = try String.restore(from: data, at: _cur + Int(_fwd_f_string))
        }
        if _obs0 & 32 != 0 {
            guard _cur >= 0, _cur < data.count else { throw ArenaRestoreError.outsideOfBuffer }
            values.f_bool_2 = data[_cur] != 0
            _cur += 1
        }
        if _obs0 & 64 != 0 {
            values.f_int32_2 = try Int32.restore(from: data, at: _cur)
            _cur += 4
        }
        if _obs0 & 128 != 0 {
            let (_fwd_f_string_2, _fwdB_f_string_2) = try readV62(from: data, at: _cur)
            _cur += _fwdB_f_string_2
            values.f_string_2 = try String.restore(from: data, at: _cur + Int(_fwd_f_string_2))
        }
        arenaOfMessage[idx] = values
        return MessageFrozenGraph.Message(__packed: UInt64(idx), __graph: self)
    }

    private func _restoreMessageFrozenPacked(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> MessageFrozenGraph.Message<MessageFrozenGraph.Arena<Brand>> {
        if let idx = cache[start] { return MessageFrozenGraph.Message(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfMessage.count
        cache[start] = idx
        arenaOfMessage.append(MessageFrozenGraph.MessageValues())
        var values = MessageFrozenGraph.MessageValues()
        let (_, _blB) = try restoreLEB(from: data, at: start)
        var _cur = start + _blB
        let _obs0 = _cur + 0 < data.count ? data[_cur + 0] : UInt8(0)
        _cur += 1
        let _ebs0 = _cur + 0 < data.count ? data[_cur + 0] : UInt8(0)
        _cur += 1
        if _obs0 & 1 != 0 {
            guard _cur >= 0, _cur < data.count else { throw ArenaRestoreError.outsideOfBuffer }
            values.f_bool = data[_cur] != 0; _cur += 1
        }
        if _obs0 & 2 != 0 {
            if _ebs0 & 1 != 0 {
                values.f_int32 = try Int32.restore(from: data, at: _cur); _cur += 4
            } else {
                let (_lv_f_int32, _lb_f_int32) = try restoreLEB(from: data, at: _cur)
                values.f_int32 = Int32(_lv_f_int32.fromZigZag); _cur += _lb_f_int32
            }
        }
        if _obs0 & 4 != 0 {
            if _ebs0 & 2 != 0 {
                values.f_int64 = try Int64.restore(from: data, at: _cur); _cur += 8
            } else {
                let (_lv_f_int64, _lb_f_int64) = try restoreLEB(from: data, at: _cur)
                values.f_int64 = Int64(_lv_f_int64.fromZigZag); _cur += _lb_f_int64
            }
        }
        if _obs0 & 8 != 0 {
            if _ebs0 & 4 != 0 {
                values.f_float64 = try Double.restore(from: data, at: _cur); _cur += 8
            } else {
                let (_fv_f_float64, _fa_f_float64) = try _decodePackedFloat64(from: data, at: _cur)
                values.f_float64 = _fv_f_float64; _cur += _fa_f_float64
            }
        }
        if _obs0 & 16 != 0 {
            let (_sv_f_string, _sb_f_string) = try restoreLEB(from: data, at: _cur); _cur += _sb_f_string
            values.f_string = _dagrUTF8(data[_cur..<(_cur + Int(_sv_f_string))])
            _cur += Int(_sv_f_string)
        }
        if _obs0 & 32 != 0 {
            guard _cur >= 0, _cur < data.count else { throw ArenaRestoreError.outsideOfBuffer }
            values.f_bool_2 = data[_cur] != 0; _cur += 1
        }
        if _obs0 & 64 != 0 {
            if _ebs0 & 8 != 0 {
                values.f_int32_2 = try Int32.restore(from: data, at: _cur); _cur += 4
            } else {
                let (_lv_f_int32_2, _lb_f_int32_2) = try restoreLEB(from: data, at: _cur)
                values.f_int32_2 = Int32(_lv_f_int32_2.fromZigZag); _cur += _lb_f_int32_2
            }
        }
        if _obs0 & 128 != 0 {
            let (_sv_f_string_2, _sb_f_string_2) = try restoreLEB(from: data, at: _cur); _cur += _sb_f_string_2
            values.f_string_2 = _dagrUTF8(data[_cur..<(_cur + Int(_sv_f_string_2))])
            _cur += Int(_sv_f_string_2)
        }
        arenaOfMessage[idx] = values
        return MessageFrozenGraph.Message(__packed: UInt64(idx), __graph: self)
    }

}
