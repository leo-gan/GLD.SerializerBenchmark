import Foundation

public enum TelemetryRegularGraph {
    public struct TelemetryValues {
        public var source: String? = nil
        public var ts: Int64? = nil
        public var tags: [String] = []
        public var values: [Double] = []
    }

    public protocol TelemetryArena: AnyObject {
        static var telemetryTypeId: Int { get }
        var arenaOfTelemetry: [TelemetryValues] { get set }
    }

    public typealias TelemetryRegularGraphGraph = TelemetryArena
    public typealias TelemetryGraph = TelemetryArena

    public struct Telemetry<Arena: TelemetryGraph> {
        let __packed: UInt64
        unowned let __graph: Arena

        var __index: Int { Int(__packed & 0x0000_00FF_FFFF_FFFF) }
        var _generation: UInt32 { UInt32(__packed >> 40) }
        var _index: Int { __index }
        var _arenaId: ObjectIdentifier { ObjectIdentifier(__graph) }

        public var source: String? {
            get { __graph.arenaOfTelemetry[__index].source }
            nonmutating set { __graph.arenaOfTelemetry[__index].source = newValue }
        }
        public var ts: Int64? {
            get { __graph.arenaOfTelemetry[__index].ts }
            nonmutating set { __graph.arenaOfTelemetry[__index].ts = newValue }
        }
        public var tags: [String] {
            get { __graph.arenaOfTelemetry[__index].tags }
            nonmutating set { __graph.arenaOfTelemetry[__index].tags = newValue }
        }
        public var values: [Double] {
            get { __graph.arenaOfTelemetry[__index].values }
            nonmutating set { __graph.arenaOfTelemetry[__index].values = newValue }
        }
    }

    // ── Arena<Brand> ─────────────────────────────────────────────────────────────────
    //
    // Brand is a phantom type — declare an empty enum per arena scope:
    //
    //   enum MyBrand {}
    //   let arena = TelemetryRegularGraph.Arena<MyBrand>()
    //
    public class Arena<Brand>: TelemetryArena {
        public static var telemetryTypeId: Int { 0 }
        public var arenaOfTelemetry: [TelemetryValues] = []
        public init() {}

        private var _root: UInt64? = nil
        public var root: Telemetry<Arena<Brand>>? {
            get { _root.map { Telemetry(__packed: $0, __graph: self) } }
            set { _root = newValue?.__packed }
        }
    }


}

extension TelemetryRegularGraph.Arena {
    public func newTelemetry(source: String? = nil, ts: Int64? = nil, tags: [String] = [], values: [Double] = []) -> TelemetryRegularGraph.Telemetry<TelemetryRegularGraph.Arena<Brand>> {
        let _idx: Int
        _idx = arenaOfTelemetry.count
        arenaOfTelemetry.append(TelemetryRegularGraph.TelemetryValues(source: source, ts: ts, tags: tags, values: values))
        let _packed = UInt64(_idx)
        return TelemetryRegularGraph.Telemetry(__packed: _packed, __graph: self)
    }
}

extension TelemetryRegularGraph.Arena {
    public func adopt<S: TelemetryRegularGraph.TelemetryGraph>(_ src: TelemetryRegularGraph.Telemetry<S>) throws -> TelemetryRegularGraph.Telemetry<TelemetryRegularGraph.Arena<Brand>> {
        var _seen = Set<UInt64>()
        return try _adopt(src, &_seen)
    }
    func _adopt<S: TelemetryRegularGraph.TelemetryGraph>(_ src: TelemetryRegularGraph.Telemetry<S>, _ _seen: inout Set<UInt64>) throws -> TelemetryRegularGraph.Telemetry<TelemetryRegularGraph.Arena<Brand>> {
        guard _seen.insert((UInt64(0) << 48) | UInt64(src._index)).inserted else { throw DagrError.cyclicAdopt }
        defer { _seen.remove((UInt64(0) << 48) | UInt64(src._index)) }
        return newTelemetry(source: src.source, ts: src.ts, tags: src.tags, values: src.values)
    }
}

extension TelemetryRegularGraph.Telemetry: CustomStringConvertible {
    public var description: String {
        var visited = Set<NodeKey>()
        return buildDescription(visited: &visited)
    }

    func buildDescription(visited: inout Set<NodeKey>) -> String {
        let __nodeKey = NodeKey(arena: _arenaId, typeId: Arena.telemetryTypeId, index: __index)
        guard !visited.contains(__nodeKey) else { return "Telemetry@\(__index)" }
        visited.insert(__nodeKey)
        let sourceStr = source.map { "\"\($0)\"" } ?? "nil"
        let tsStr = String(describing: ts)
        let tagsStr = String(describing: tags)
        let valuesStr = String(describing: values)
        return "Telemetry@\(__index) { source: \(sourceStr), ts: \(tsStr), tags: \(tagsStr), values: \(valuesStr) }"
    }
}

extension TelemetryRegularGraph.Telemetry: Hashable {
    public func hash(into hasher: inout Hasher) {
        var visited = Set<NodeKey>()
        hashInto(hasher: &hasher, visited: &visited)
    }

    func hashInto(hasher: inout Hasher, visited: inout Set<NodeKey>) {
        let __nodeKey = NodeKey(arena: _arenaId, typeId: Arena.telemetryTypeId, index: __index)
        guard !visited.contains(__nodeKey) else { return }
        visited.insert(__nodeKey)
        hasher.combine(source)
        hasher.combine(ts)
        hasher.combine(tags)
        hasher.combine(values)
    }
}

extension TelemetryRegularGraph.Telemetry: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        var visited = Set<ArenaPair>()
        return lhs.cycleAwareEquals(other: rhs, visited: &visited)
    }

    func cycleAwareEquals(other: Self, visited: inout Set<ArenaPair>) -> Bool {
        let pair = ArenaPair(
            leftArena: _arenaId, leftTypeId: Arena.telemetryTypeId, leftIndex: __index,
            rightArena: other._arenaId, rightTypeId: Arena.telemetryTypeId, rightIndex: other.__index
        )
        guard !visited.contains(pair) else { return true }
        visited.insert(pair)
        guard self.source == other.source else { return false }
        guard self.ts == other.ts else { return false }
        guard self.tags == other.tags else { return false }
        guard self.values == other.values else { return false }
        return true
    }
}

extension TelemetryRegularGraph.Telemetry {
    public static func == <OtherArena: TelemetryRegularGraph.TelemetryGraph>(lhs: Self, rhs: TelemetryRegularGraph.Telemetry<OtherArena>) -> Bool {
        var visited = Set<ArenaPair>()
        return lhs.cycleAwareEqualsAny(other: rhs, visited: &visited)
    }

    public static func != <OtherArena: TelemetryRegularGraph.TelemetryGraph>(lhs: Self, rhs: TelemetryRegularGraph.Telemetry<OtherArena>) -> Bool {
        return !(lhs == rhs)
    }

    func cycleAwareEqualsAny<OtherArena: TelemetryRegularGraph.TelemetryGraph>(
        other: TelemetryRegularGraph.Telemetry<OtherArena>,
        visited: inout Set<ArenaPair>
    ) -> Bool {
        let pair = ArenaPair(
            leftArena: _arenaId, leftTypeId: Arena.telemetryTypeId, leftIndex: __index,
            rightArena: other._arenaId, rightTypeId: OtherArena.telemetryTypeId, rightIndex: other.__index
        )
        guard !visited.contains(pair) else { return true }
        visited.insert(pair)
        guard self.source == other.source else { return false }
        guard self.ts == other.ts else { return false }
        guard self.tags == other.tags else { return false }
        guard self.values == other.values else { return false }
        return true
    }
}

extension TelemetryRegularGraph.Telemetry: ArenaNodeHandle {}
extension TelemetryRegularGraph.Telemetry: ArenaGraphStorable {
    var cycleIdentifier: ArenaCycleIdntifier {
        .init(nodeTypeId: Arena.telemetryTypeId, nodeIndex: __index)
    }

    public func store(with builder: any ArenaBuilder) throws -> BufferOffset {
        if let offset = try builder.beginStoring(nodeId: cycleIdentifier) {
            return offset
        }
        let _valuesValueOffset = try self.values.store(with: builder)
        let _tagsValueOffset = try self.tags.store(with: builder)
        let _sourceValueOffset = try self.source?.store(with: builder)
        let _valuesOffset: BufferOffset? = try _valuesValueOffset.storeForwardPointer(with: builder)
        let _tagsOffset: BufferOffset? = try _tagsValueOffset.storeForwardPointer(with: builder)
        let _tsOffset: BufferOffset? = try self.ts?.store(with: builder)
        let _sourceOffset: BufferOffset? = try _sourceValueOffset?.storeForwardPointer(with: builder)
        let offset = try builder.store(vTable: [_sourceOffset, _tsOffset, _tagsOffset, _valuesOffset])
        try builder.finishStoring(nodeId: cycleIdentifier, offset: offset)
        return offset
    }

    public func storePacked(with builder: any ArenaBuilder) throws -> PackedStoreResult {
        let before = try builder.beginPackedStoring(nodeId: cycleIdentifier)
        do {
            let _bef_values = builder.cursor
            try _dagrStoreRawArray(self.values, with: builder)
            _ = try builder.storeAsLEB(value: (UInt64(self.values.count) << 2) | 1)
            _ = try builder.storeAsLEB(value: builder.cursor.value - _bef_values.value)
            _ = try PackedStoreResult.raw(0).store(index: 3, with: builder)
        }
        _ = try self.tags.storePacked(with: builder).store(index: 2, with: builder)
        _ = try self.ts?.storePacked(with: builder).store(index: 1, with: builder)
        _ = try self.source?.storePacked(with: builder).store(index: 0, with: builder)
        _ = try builder.storeAsLEB(value: builder.cursor.value - before.value)
        return builder.finishPackedStoring(nodeId: cycleIdentifier)
    }
}

extension TelemetryRegularGraph.Arena {
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

    public static func restore(from data: Foundation.Data) throws -> TelemetryRegularGraph.Arena<Brand> {
        guard !data.isEmpty else { return TelemetryRegularGraph.Arena<Brand>() }
        let arena = TelemetryRegularGraph.Arena<Brand>()
        let (framing, lebLen) = try restoreLEB(from: data, at: 0)
        guard (framing & 1) == 0 else { throw ArenaRestoreError.missingHeader }
        guard ((framing >> 1) & 1) == 0 else { throw ArenaRestoreError.invalidFraming }
        let rootStart = lebLen + Int(framing >> 2)
        var cache = [Int: Int]()
        arena.root = try arena._restoreTelemetry(from: data, at: rootStart, cache: &cache)
        return arena
    }

    private func _restoreTelemetry(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> TelemetryRegularGraph.Telemetry<TelemetryRegularGraph.Arena<Brand>> {
        if let idx = cache[start] { return TelemetryRegularGraph.Telemetry(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfTelemetry.count
        cache[start] = idx
        arenaOfTelemetry.append(TelemetryRegularGraph.TelemetryValues())
        var values = TelemetryRegularGraph.TelemetryValues()
        let vtable = try restoreRTypeVTable(from: data, start: start)
        if 0 < vtable.count, let _off0 = vtable[0] {
            let (_fwd0, _fwdb0) = try readV62(from: data, at: start + Int(_off0))
            values.source = try String.restore(from: data, at: start + Int(_off0) + _fwdb0 + Int(_fwd0))
        }
        if 1 < vtable.count, let _off1 = vtable[1] {
            values.ts = try Int64.restore(from: data, at: start + Int(_off1))
        }
        if 2 < vtable.count, let _off2 = vtable[2] {
            let (_fwd2, _fwdb2) = try readV62(from: data, at: start + Int(_off2))
            values.tags = try _restorePrimArray(type: String.self, from: data, at: start + Int(_off2) + _fwdb2 + Int(_fwd2))
        }
        if 3 < vtable.count, let _off3 = vtable[3] {
            let (_fwd3, _fwdb3) = try readV62(from: data, at: start + Int(_off3))
            values.values = try _restoreNumericArray(type: Double.self, from: data, at: start + Int(_off3) + _fwdb3 + Int(_fwd3))
        }
        arenaOfTelemetry[idx] = values
        return TelemetryRegularGraph.Telemetry(__packed: UInt64(idx), __graph: self)
    }

    private func _restoreTelemetryPacked(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> TelemetryRegularGraph.Telemetry<TelemetryRegularGraph.Arena<Brand>> {
        if let idx = cache[start] { return TelemetryRegularGraph.Telemetry(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfTelemetry.count
        cache[start] = idx
        arenaOfTelemetry.append(TelemetryRegularGraph.TelemetryValues())
        var values = TelemetryRegularGraph.TelemetryValues()
        let (_bl, _blB) = try restoreLEB(from: data, at: start)
        var _cursor = start + _blB
        let _end = _cursor + Int(_bl)
        if _cursor < _end {
            let (_tag, _tagB) = try restoreLEB(from: data, at: _cursor)
            if Int(_tag) >> 1 == 0 {
                _cursor += _tagB
                let (_sv_source, _sb_source) = try restoreLEB(from: data, at: _cursor); _cursor += _sb_source
                values.source = _dagrUTF8(data[_cursor..<(_cursor + Int(_sv_source))]); _cursor += Int(_sv_source)
            }
        }
        if _cursor < _end {
            let (_tag, _tagB) = try restoreLEB(from: data, at: _cursor)
            if Int(_tag) >> 1 == 1 {
                _cursor += _tagB
                if _tag & 1 == 0 {
                    let (_v, _b) = try restoreLEB(from: data, at: _cursor); values.ts = Int64(_v.fromZigZag); _cursor += _b
                } else {
                    values.ts = try Int64.restore(from: data, at: _cursor); _cursor += 8
                }
            }
        }
        if _cursor < _end {
            let (_tag, _tagB) = try restoreLEB(from: data, at: _cursor)
            if Int(_tag) >> 1 == 2 {
                _cursor += _tagB
                let (_abl_tags, _ablB_tags) = try restoreLEB(from: data, at: _cursor)
                let _s_tags = _cursor + _ablB_tags
                let (_cnt_tags, _cntB_tags) = try restoreLEB(from: data, at: _s_tags)
                var _arr_tags = [String]()
                var _pos_tags = _s_tags + _cntB_tags
                for _ in 0..<Int(_cnt_tags) {
                    let (_sv, _sb) = try restoreLEB(from: data, at: _pos_tags); _pos_tags += _sb
                    _arr_tags.append(_dagrUTF8(data[_pos_tags..<(_pos_tags + Int(_sv))]))
                    _pos_tags += Int(_sv)
                }
                values.tags = _arr_tags
                _cursor = _s_tags + Int(_abl_tags)
            }
        }
        if _cursor < _end {
            let (_tag, _tagB) = try restoreLEB(from: data, at: _cursor)
            if Int(_tag) >> 1 == 3 {
                _cursor += _tagB
                let (_abl_values, _ablB_values) = try restoreLEB(from: data, at: _cursor)
                let _s_values = _cursor + _ablB_values
                let (_cnt_values, _cntB_values) = try restoreLEB(from: data, at: _s_values)
                let _realCnt_values = Int(_cnt_values) >> 2; let _mode_values = Int(_cnt_values) & 3
                var _arr_values = [Double]()
                var _pos_values = _s_values + _cntB_values
                for _ in 0..<_realCnt_values {
                    if _mode_values == 1 { _arr_values.append(Double(bitPattern: _readRawLE(from: data, at: _pos_values, width: 8) ?? 0)); _pos_values += 8 }
                    else { let (_fv_values, _fb_values) = try _decodePackedFloat64(from: data, at: _pos_values); _arr_values.append(_fv_values); _pos_values += _fb_values }
                }
                values.values = _arr_values
                _cursor = _s_values + Int(_abl_values)
            }
        }
        arenaOfTelemetry[idx] = values
        return TelemetryRegularGraph.Telemetry(__packed: UInt64(idx), __graph: self)
    }

}
