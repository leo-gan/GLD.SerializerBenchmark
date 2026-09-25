import Foundation

public enum TelemetryFrozenGraph {
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

    public typealias TelemetryFrozenGraphGraph = TelemetryArena
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
    //   let arena = TelemetryFrozenGraph.Arena<MyBrand>()
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

extension TelemetryFrozenGraph.Arena {
    public func newTelemetry(source: String? = nil, ts: Int64? = nil, tags: [String] = [], values: [Double] = []) -> TelemetryFrozenGraph.Telemetry<TelemetryFrozenGraph.Arena<Brand>> {
        let _idx: Int
        _idx = arenaOfTelemetry.count
        arenaOfTelemetry.append(TelemetryFrozenGraph.TelemetryValues(source: source, ts: ts, tags: tags, values: values))
        let _packed = UInt64(_idx)
        return TelemetryFrozenGraph.Telemetry(__packed: _packed, __graph: self)
    }
}

extension TelemetryFrozenGraph.Arena {
    public func adopt<S: TelemetryFrozenGraph.TelemetryGraph>(_ src: TelemetryFrozenGraph.Telemetry<S>) throws -> TelemetryFrozenGraph.Telemetry<TelemetryFrozenGraph.Arena<Brand>> {
        var _seen = Set<UInt64>()
        return try _adopt(src, &_seen)
    }
    func _adopt<S: TelemetryFrozenGraph.TelemetryGraph>(_ src: TelemetryFrozenGraph.Telemetry<S>, _ _seen: inout Set<UInt64>) throws -> TelemetryFrozenGraph.Telemetry<TelemetryFrozenGraph.Arena<Brand>> {
        guard _seen.insert((UInt64(0) << 48) | UInt64(src._index)).inserted else { throw DagrError.cyclicAdopt }
        defer { _seen.remove((UInt64(0) << 48) | UInt64(src._index)) }
        return newTelemetry(source: src.source, ts: src.ts, tags: src.tags, values: src.values)
    }
}

extension TelemetryFrozenGraph.Telemetry: CustomStringConvertible {
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

extension TelemetryFrozenGraph.Telemetry: Hashable {
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

extension TelemetryFrozenGraph.Telemetry: Equatable {
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

extension TelemetryFrozenGraph.Telemetry {
    public static func == <OtherArena: TelemetryFrozenGraph.TelemetryGraph>(lhs: Self, rhs: TelemetryFrozenGraph.Telemetry<OtherArena>) -> Bool {
        var visited = Set<ArenaPair>()
        return lhs.cycleAwareEqualsAny(other: rhs, visited: &visited)
    }

    public static func != <OtherArena: TelemetryFrozenGraph.TelemetryGraph>(lhs: Self, rhs: TelemetryFrozenGraph.Telemetry<OtherArena>) -> Bool {
        return !(lhs == rhs)
    }

    func cycleAwareEqualsAny<OtherArena: TelemetryFrozenGraph.TelemetryGraph>(
        other: TelemetryFrozenGraph.Telemetry<OtherArena>,
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

extension TelemetryFrozenGraph.Telemetry: ArenaNodeHandle {}
extension TelemetryFrozenGraph.Telemetry: ArenaGraphStorable {
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
        _ = try _valuesValueOffset.storeForwardPointer(with: builder)
        _ = try _tagsValueOffset.storeForwardPointer(with: builder)
        _ = try self.ts?.store(with: builder)
        _ = try _sourceValueOffset?.storeForwardPointer(with: builder)
        var _nilByte: UInt8 = 0
        if self.source != nil { _nilByte |= 1 }
        if self.ts != nil { _nilByte |= 2 }
        if !self.tags.isEmpty { _nilByte |= 4 }
        if !self.values.isEmpty { _nilByte |= 8 }
        _ = try builder.store(number: _nilByte)
        let offset = builder.cursor
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
        }
        _ = try self.tags.storePacked(with: builder)
        let _tsPackedResult = try self.ts?.storePacked(with: builder)
        _ = try self.source?.storePacked(with: builder)
        var _encByte: UInt8 = 0
        if _tsPackedResult?.isRaw ?? false { _encByte |= 1 }
        _ = try builder.store(number: _encByte)
        var _nilByte: UInt8 = 0
        if self.source != nil { _nilByte |= 1 }
        if self.ts != nil { _nilByte |= 2 }
        if !self.tags.isEmpty { _nilByte |= 4 }
        if !self.values.isEmpty { _nilByte |= 8 }
        _ = try builder.store(number: _nilByte)
        _ = try builder.storeAsLEB(value: builder.cursor.value - before.value)
        return builder.finishPackedStoring(nodeId: cycleIdentifier)
    }
}

extension TelemetryFrozenGraph.Arena {
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

    public static func restore(from data: Foundation.Data) throws -> TelemetryFrozenGraph.Arena<Brand> {
        guard !data.isEmpty else { return TelemetryFrozenGraph.Arena<Brand>() }
        let arena = TelemetryFrozenGraph.Arena<Brand>()
        let (framing, lebLen) = try restoreLEB(from: data, at: 0)
        guard (framing & 1) == 0 else { throw ArenaRestoreError.missingHeader }
        guard ((framing >> 1) & 1) == 0 else { throw ArenaRestoreError.invalidFraming }
        let rootStart = lebLen + Int(framing >> 2)
        var cache = [Int: Int]()
        arena.root = try arena._restoreTelemetry(from: data, at: rootStart, cache: &cache)
        return arena
    }

    private func _restoreTelemetry(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> TelemetryFrozenGraph.Telemetry<TelemetryFrozenGraph.Arena<Brand>> {
        if let idx = cache[start] { return TelemetryFrozenGraph.Telemetry(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfTelemetry.count
        cache[start] = idx
        arenaOfTelemetry.append(TelemetryFrozenGraph.TelemetryValues())
        var values = TelemetryFrozenGraph.TelemetryValues()
        let _obs0 = start + 0 < data.count ? data[start + 0] : UInt8(0)
        var _cur = start + 1
        if _obs0 & 1 != 0 {
            let (_fwd_source, _fwdB_source) = try readV62(from: data, at: _cur)
            _cur += _fwdB_source
            values.source = try String.restore(from: data, at: _cur + Int(_fwd_source))
        }
        if _obs0 & 2 != 0 {
            values.ts = try Int64.restore(from: data, at: _cur)
            _cur += 8
        }
        let (_fwd_tags, _fwdB_tags) = try readV62(from: data, at: _cur)
        _cur += _fwdB_tags
        values.tags = try _restorePrimArray(type: String.self, from: data, at: _cur + Int(_fwd_tags))
        let (_fwd_values, _fwdB_values) = try readV62(from: data, at: _cur)
        _cur += _fwdB_values
        values.values = try _restoreNumericArray(type: Double.self, from: data, at: _cur + Int(_fwd_values))
        arenaOfTelemetry[idx] = values
        return TelemetryFrozenGraph.Telemetry(__packed: UInt64(idx), __graph: self)
    }

    private func _restoreTelemetryFrozenPacked(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> TelemetryFrozenGraph.Telemetry<TelemetryFrozenGraph.Arena<Brand>> {
        if let idx = cache[start] { return TelemetryFrozenGraph.Telemetry(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfTelemetry.count
        cache[start] = idx
        arenaOfTelemetry.append(TelemetryFrozenGraph.TelemetryValues())
        var values = TelemetryFrozenGraph.TelemetryValues()
        let (_, _blB) = try restoreLEB(from: data, at: start)
        var _cur = start + _blB
        let _obs0 = _cur + 0 < data.count ? data[_cur + 0] : UInt8(0)
        _cur += 1
        let _ebs0 = _cur + 0 < data.count ? data[_cur + 0] : UInt8(0)
        _cur += 1
        if _obs0 & 1 != 0 {
            let (_sv_source, _sb_source) = try restoreLEB(from: data, at: _cur); _cur += _sb_source
            values.source = _dagrUTF8(data[_cur..<(_cur + Int(_sv_source))])
            _cur += Int(_sv_source)
        }
        if _obs0 & 2 != 0 {
            if _ebs0 & 1 != 0 {
                values.ts = try Int64.restore(from: data, at: _cur); _cur += 8
            } else {
                let (_lv_ts, _lb_ts) = try restoreLEB(from: data, at: _cur)
                values.ts = Int64(_lv_ts.fromZigZag); _cur += _lb_ts
            }
        }
        let (_bbl_tags, _bblB_tags) = try restoreLEB(from: data, at: _cur)
        let _bend_tags = _cur + _bblB_tags + Int(_bbl_tags)
        _cur += _bblB_tags
        values.tags = try _restorePackedComplexArray(from: data, at: _cur, { String(decoding: $0, as: UTF8.self) })
        _cur = _bend_tags
        let (_bbl_values, _bblB_values) = try restoreLEB(from: data, at: _cur)
        let _bend_values = _cur + _bblB_values + Int(_bbl_values)
        _cur += _bblB_values
        let (_fhdr_values, _) = try restoreLEB(from: data, at: _cur)
        if _fhdr_values & 3 == 1 {
            values.values = try _restorePackedFloatArray(from: data, at: _cur) { (Double(bitPattern: _readRawLE(from: $0, at: $1, width: 8) ?? 0), 8) }
        } else {
            values.values = try _restorePackedFloatArray(from: data, at: _cur) { try _decodePackedFloat64(from: $0, at: $1) }
        }
        _cur = _bend_values
        arenaOfTelemetry[idx] = values
        return TelemetryFrozenGraph.Telemetry(__packed: UInt64(idx), __graph: self)
    }

}
