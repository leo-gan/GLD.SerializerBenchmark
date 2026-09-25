import Foundation

public enum StringsGraph {
    public struct StringsValues {
        public var items: [String] = []
    }

    public protocol StringsArena: AnyObject {
        static var stringsTypeId: Int { get }
        var arenaOfStrings: [StringsValues] { get set }
        var generationOfStrings: [UInt32] { get set }
        var freeSlotsOfStrings: [Int] { get set }
    }

    public typealias StringsGraphGraph = StringsArena
    public typealias StringsGraph = StringsArena

    public struct Strings<Arena: StringsGraph> {
        let __packed: UInt64
        unowned let __graph: Arena

        var __index: Int { Int(__packed & 0x0000_00FF_FFFF_FFFF) }
        var _generation: UInt32 { UInt32(__packed >> 40) }
        var _index: Int { __index }
        var _arenaId: ObjectIdentifier { ObjectIdentifier(__graph) }

        public var items: [String] {
            get { __graph.arenaOfStrings[__index].items }
            nonmutating set { __graph.arenaOfStrings[__index].items = newValue }
        }
        public func delete() {
            let _idx = __index
            guard _generation == __graph.generationOfStrings[_idx] else { return }
            __graph.arenaOfStrings[_idx] = StringsValues()
            __graph.generationOfStrings[_idx] &+= 1
            __graph.freeSlotsOfStrings.append(_idx)
        }
    }

    // ── Arena<Brand> ─────────────────────────────────────────────────────────────────
    //
    // Brand is a phantom type — declare an empty enum per arena scope:
    //
    //   enum MyBrand {}
    //   let arena = StringsGraph.Arena<MyBrand>()
    //
    public class Arena<Brand>: StringsArena {
        public static var stringsTypeId: Int { 0 }
        public var arenaOfStrings: [StringsValues] = []
        public var generationOfStrings: [UInt32] = []
        public var freeSlotsOfStrings: [Int] = []
        public init() {}

        private var _root: UInt64? = nil
        public var root: Strings<Arena<Brand>>? {
            get { _root.map { Strings(__packed: $0, __graph: self) } }
            set { _root = newValue?.__packed }
        }
    }


}

extension StringsGraph.Arena {
    public func newStrings(items: [String] = []) -> StringsGraph.Strings<StringsGraph.Arena<Brand>> {
        let _idx: Int
        if let _free = freeSlotsOfStrings.popLast() {
            _idx = _free
            arenaOfStrings[_idx] = StringsGraph.StringsValues(items: items)
        } else {
            _idx = arenaOfStrings.count
            arenaOfStrings.append(StringsGraph.StringsValues(items: items))
            generationOfStrings.append(0)
        }
        let _packed = UInt64(generationOfStrings[_idx]) << 40 | UInt64(_idx)
        return StringsGraph.Strings(__packed: _packed, __graph: self)
    }
}

extension StringsGraph.Arena {
    public func adopt<S: StringsGraph.StringsGraph>(_ src: StringsGraph.Strings<S>) throws -> StringsGraph.Strings<StringsGraph.Arena<Brand>> {
        var _seen = Set<UInt64>()
        return try _adopt(src, &_seen)
    }
    func _adopt<S: StringsGraph.StringsGraph>(_ src: StringsGraph.Strings<S>, _ _seen: inout Set<UInt64>) throws -> StringsGraph.Strings<StringsGraph.Arena<Brand>> {
        guard _seen.insert((UInt64(0) << 48) | UInt64(src._index)).inserted else { throw DagrError.cyclicAdopt }
        defer { _seen.remove((UInt64(0) << 48) | UInt64(src._index)) }
        return newStrings(items: src.items)
    }
}

extension StringsGraph.Arena {
    public func deleteStrings(_ node: StringsGraph.Strings<StringsGraph.Arena<Brand>>) {
        let _idx = node._index
        guard node._generation == generationOfStrings[_idx] else { return }
        arenaOfStrings[_idx] = StringsGraph.StringsValues()
        generationOfStrings[_idx] &+= 1
        freeSlotsOfStrings.append(_idx)
    }
}

extension StringsGraph.Strings: CustomStringConvertible {
    public var description: String {
        var visited = Set<NodeKey>()
        return buildDescription(visited: &visited)
    }

    func buildDescription(visited: inout Set<NodeKey>) -> String {
        let __nodeKey = NodeKey(arena: _arenaId, typeId: Arena.stringsTypeId, index: __index)
        guard !visited.contains(__nodeKey) else { return "Strings@\(__index)" }
        visited.insert(__nodeKey)
        let itemsStr = String(describing: items)
        return "Strings@\(__index) { items: \(itemsStr) }"
    }
}

extension StringsGraph.Strings: Hashable {
    public func hash(into hasher: inout Hasher) {
        var visited = Set<NodeKey>()
        hashInto(hasher: &hasher, visited: &visited)
    }

    func hashInto(hasher: inout Hasher, visited: inout Set<NodeKey>) {
        let __nodeKey = NodeKey(arena: _arenaId, typeId: Arena.stringsTypeId, index: __index)
        guard !visited.contains(__nodeKey) else { return }
        visited.insert(__nodeKey)
        hasher.combine(items)
    }
}

extension StringsGraph.Strings: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        var visited = Set<ArenaPair>()
        return lhs.cycleAwareEquals(other: rhs, visited: &visited)
    }

    func cycleAwareEquals(other: Self, visited: inout Set<ArenaPair>) -> Bool {
        let pair = ArenaPair(
            leftArena: _arenaId, leftTypeId: Arena.stringsTypeId, leftIndex: __index,
            rightArena: other._arenaId, rightTypeId: Arena.stringsTypeId, rightIndex: other.__index
        )
        guard !visited.contains(pair) else { return true }
        visited.insert(pair)
        guard self.items == other.items else { return false }
        return true
    }
}

extension StringsGraph.Strings {
    public static func == <OtherArena: StringsGraph.StringsGraph>(lhs: Self, rhs: StringsGraph.Strings<OtherArena>) -> Bool {
        var visited = Set<ArenaPair>()
        return lhs.cycleAwareEqualsAny(other: rhs, visited: &visited)
    }

    public static func != <OtherArena: StringsGraph.StringsGraph>(lhs: Self, rhs: StringsGraph.Strings<OtherArena>) -> Bool {
        return !(lhs == rhs)
    }

    func cycleAwareEqualsAny<OtherArena: StringsGraph.StringsGraph>(
        other: StringsGraph.Strings<OtherArena>,
        visited: inout Set<ArenaPair>
    ) -> Bool {
        let pair = ArenaPair(
            leftArena: _arenaId, leftTypeId: Arena.stringsTypeId, leftIndex: __index,
            rightArena: other._arenaId, rightTypeId: OtherArena.stringsTypeId, rightIndex: other.__index
        )
        guard !visited.contains(pair) else { return true }
        visited.insert(pair)
        guard self.items == other.items else { return false }
        return true
    }
}

extension StringsGraph.Strings: ArenaNodeHandle {}
extension StringsGraph.Strings: ArenaGraphStorable {
    var cycleIdentifier: ArenaCycleIdntifier {
        .init(nodeTypeId: Arena.stringsTypeId, nodeIndex: __index)
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
        _ = try self.items.storePacked(with: builder).store(index: 0, with: builder)
        _ = try builder.storeAsLEB(value: builder.cursor.value - before.value)
        return builder.finishPackedStoring(nodeId: cycleIdentifier)
    }
}

extension StringsGraph.Arena {
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

    public static func restore(from data: Foundation.Data) throws -> StringsGraph.Arena<Brand> {
        guard !data.isEmpty else { return StringsGraph.Arena<Brand>() }
        let arena = StringsGraph.Arena<Brand>()
        let (framing, lebLen) = try restoreLEB(from: data, at: 0)
        guard (framing & 1) == 0 else { throw ArenaRestoreError.missingHeader }
        guard ((framing >> 1) & 1) == 0 else { throw ArenaRestoreError.invalidFraming }
        let rootStart = lebLen + Int(framing >> 2)
        var cache = [Int: Int]()
        arena.root = try arena._restoreStrings(from: data, at: rootStart, cache: &cache)
        return arena
    }

    private func _restoreStrings(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> StringsGraph.Strings<StringsGraph.Arena<Brand>> {
        if let idx = cache[start] { return StringsGraph.Strings(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfStrings.count
        cache[start] = idx
        arenaOfStrings.append(StringsGraph.StringsValues())
        generationOfStrings.append(0)
        var values = StringsGraph.StringsValues()
        let (_bl, _blB) = try restoreLEB(from: data, at: start)
        var _cursor = start + _blB
        let _end = _cursor + Int(_bl)
        if _cursor < _end {
            let (_tag, _tagB) = try restoreLEB(from: data, at: _cursor)
            if Int(_tag) >> 1 == 0 {
                _cursor += _tagB
                let (_abl_items, _ablB_items) = try restoreLEB(from: data, at: _cursor)
                let _s_items = _cursor + _ablB_items
                let (_cnt_items, _cntB_items) = try restoreLEB(from: data, at: _s_items)
                var _arr_items = [String]()
                var _pos_items = _s_items + _cntB_items
                for _ in 0..<Int(_cnt_items) {
                    let (_sv, _sb) = try restoreLEB(from: data, at: _pos_items); _pos_items += _sb
                    _arr_items.append(_dagrUTF8(data[_pos_items..<(_pos_items + Int(_sv))]))
                    _pos_items += Int(_sv)
                }
                values.items = _arr_items
                _cursor = _s_items + Int(_abl_items)
            }
        }
        arenaOfStrings[idx] = values
        return StringsGraph.Strings(__packed: UInt64(idx), __graph: self)
    }

}


// ── Direct Graph Builder ("spec/33-direct-graph-builder.md") ─────────────────────
// Arena-free construction for this packed-rooted tree: value structs in,
// byte-identical graph buffer out. `Direct.toData*(v) == Arena.toData*()`.
extension StringsGraph {
    public enum Direct {
        public struct Strings: ArenaGraphStorable {
            public var items: [String]
            public init(items: [String] = []) {
                self.items = items
            }
            public func store(with builder: any ArenaBuilder) throws -> BufferOffset {
                _ = try storePacked(with: builder)
                return builder.cursor
            }
            public func storePacked(with builder: any ArenaBuilder) throws -> PackedStoreResult {
                let before = builder.cursor
        _ = try self.items.storePacked(with: builder).store(index: 0, with: builder)
                _ = try builder.storeAsLEB(value: builder.cursor.value - before.value)
                return .raw(0)
            }
        }

        public static func toData(_ root: Strings) throws -> Foundation.Data {
            let builder = DataArenaBuilder()
            let rootOffset = try root.store(with: builder)
            _ = try builder.storeAsLEB(value: (builder.cursor.value - rootOffset.value) << 2)
            return builder.makeData
        }
    }
}
