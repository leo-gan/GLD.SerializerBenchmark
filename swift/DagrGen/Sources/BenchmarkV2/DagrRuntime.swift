import Foundation

// ── ZigZag encoding ───────────────────────────────────────────────────────────

extension Int64 {
    var toZigZag: UInt64 { self >= 0 ? UInt64(self) << 1 : UInt64(~self) << 1 | 1 }
}
extension UInt64 {
    var fromZigZag: Int64 {
        self & 1 == 0 ? Int64(self >> 1) : ~Int64(self >> 1)
    }
    var toNegativZigZag: UInt64 { self == 0 ? 0 : (self - 1) << 1 | 1 }
}

// ── ByteWidth ─────────────────────────────────────────────────────────────────

public enum ByteWidth {
    case eighth, quarter, half, one, two, four, eight

    func bitSet(forArraySize count: Int) -> [UInt8] {
        switch self {
        case .eighth:  return [UInt8](repeating: 0, count: (count >> 3) + (count & 7 > 0 ? 1 : 0))
        case .quarter: return [UInt8](repeating: 0, count: (count >> 2) + (count & 3 > 0 ? 1 : 0))
        case .half:    return [UInt8](repeating: 0, count: (count >> 1) + (count & 1 > 0 ? 1 : 0))
        default:       return []
        }
    }

    func storeZero(with builder: any ArenaBuilder) throws {
        switch self {
        case .eighth, .quarter, .half, .one: _ = try builder.store(number: UInt8(0))
        case .two:   _ = try builder.store(number: UInt16(0))
        case .four:  _ = try builder.store(number: UInt32(0))
        case .eight: _ = try builder.store(number: UInt64(0))
        }
    }

    @discardableResult
    func storeNumber(value: UInt64, with builder: any ArenaBuilder) throws -> BufferOffset {
        switch self {
        case .eighth, .quarter, .half, .one: return try builder.store(number: UInt8(value))
        case .two:   return try builder.store(number: UInt16(value))
        case .four:  return try builder.store(number: UInt32(value))
        case .eight: return try builder.store(number: UInt64(value))
        }
    }
}

// ── Bool array bitSet helper ──────────────────────────────────────────────────

extension Array where Element == Bool {
    var bitSet: [UInt8] {
        var result = [UInt8](repeating: 0, count: (count >> 3) + (count & 7 > 0 ? 1 : 0))
        for (i, b) in enumerated() where b { result[i >> 3] |= 1 << (i & 7) }
        return result
    }
}

// ── ArenaCycleIdntifier (used for cycle-safe store/storePacked) ───────────────

public struct ArenaCycleIdntifier: Hashable {
    let nodeTypeId: Int
    let nodeIndex: Int
    public init(nodeTypeId: Int, nodeIndex: Int) {
        self.nodeTypeId = nodeTypeId
        self.nodeIndex  = nodeIndex
    }
}

// ── DagrError ─────────────────────────────────────────────────────────────────

public enum DagrError: Error, Equatable {
    case staleReference
    // A cross-arena `adopt` traversal revisited a node still on its own call stack —
    // the source subgraph contains a reference cycle. `adopt` deep-copies acyclic
    // (DAG-ok) subtrees; for cyclic whole-graph transfer use `toData()` + `restore`.
    case cyclicAdopt
}

// ── Arena protocols ───────────────────────────────────────────────────────────

public protocol ArenaEnum: ArenaGraphStorable {
    var value: UInt64 { get }
    var byteWidth: ByteWidth { get }
}

extension ArenaEnum {
    public func storePacked(with builder: any ArenaBuilder) throws -> PackedStoreResult {
        switch byteWidth {
        case .eighth, .quarter, .half, .one:
            _ = try builder.store(number: UInt8(value)); return .raw(1)
        case .two:
            if lebLength(value) < 2 { _ = try builder.storeAsLEB(value: value); return .encoded }
            _ = try builder.store(number: UInt16(value)); return .raw(2)
        case .four:
            if lebLength(value) < 4 { _ = try builder.storeAsLEB(value: value); return .encoded }
            _ = try builder.store(number: UInt32(value)); return .raw(4)
        case .eight:
            if lebLength(value) < 8 { _ = try builder.storeAsLEB(value: value); return .encoded }
            _ = try builder.store(number: value); return .raw(8)
        }
    }
    public func store(with builder: any ArenaBuilder) throws -> BufferOffset {
        switch byteWidth {
        case .eighth, .quarter, .half, .one: return try builder.store(number: UInt8(value))
        case .two:   return try builder.store(number: UInt16(value))
        case .four:  return try builder.store(number: UInt32(value))
        case .eight: return try builder.store(number: UInt64(value))
        }
    }
}

public protocol OptionalType {
    associatedtype Wrapped
    var optional: Wrapped? { get }
}
extension Optional: OptionalType {
    public var optional: Self { self }
}

// Marker protocol so Array.store(with:) can detect [ArenaEnum?] via type system.
public protocol ArenaOptEnum {}
extension Optional: ArenaOptEnum where Wrapped: ArenaEnum {}

public enum ArenaAppliedUnionType {
    case value(value: UInt64, id: UInt64, width: ByteWidth)
    case pointer(value: BufferOffset, id: UInt64)
    case bidirPointer(value: BufferOffset, id: UInt64)
}

// ── ArenaBuilder ──────────────────────────────────────────────────────────────

public enum PackedStoreResult: Equatable {
    case encoded         // LEB integer or union combined header → even tag, union code 0
    case floatEncoded    // float compression tag+payload → even tag, union code 5
    case raw(Int)        // raw bytes: 0=variable-size, 1/2/4/8=fixed-size → odd tag
    public func store(index: UInt64, with builder: any ArenaBuilder) throws {
        switch self {
        case .encoded, .floatEncoded:
            _ = try builder.storeAsLEB(value: index << 1)         // even tag
        case .raw:
            _ = try builder.storeAsLEB(value: (index << 1) | 1)  // odd tag
        }
    }
    public var isRaw: Bool { if case .raw = self { return true }; return false }
    public var unionCode: Int {
        switch self {
        case .encoded:      return 0
        case .floatEncoded: return 5
        case .raw(let n):
            switch n { case 1: return 1; case 2: return 2; case 4: return 3; case 8: return 4; default: return 6 }
        }
    }
}

public enum BufferOffset {
    case offset(UInt64), inProgress(ArenaCycleIdntifier)
    public var value: UInt64 {
        switch self {
        case .offset(let v): return v
        case .inProgress:    return 0
        }
    }
    public func storeForwardPointer(with builder: any ArenaBuilder) throws -> BufferOffset {
        switch self {
        case .offset:      return try builder.storeForwardPointer(value: self)
        case .inProgress:  throw ArenaStoreError.cantStoreForwardPointer
        }
    }
    public func storeBidirectionalPointer(with builder: any ArenaBuilder) throws -> BufferOffset {
        return try builder.storeBidirectionalPointer(value: self)
    }
}

public enum ArenaStoreError: Swift.Error, Equatable {
    case unexpectedTypeInArray(String)
    case cantStoreForwardPointer
    case encounteredCycleWhilePackedStoring
    case cantStoreValueAsV62(UInt64)
    case vTableEntryOverflow(UInt64)   // field slot > UInt16.max bytes before the node header ("05" §VTable)
}

public enum BuilderError: Error {
    case wentOverMaxSize
}

public protocol ArenaGraphStorable {
    func store(with builder: any ArenaBuilder) throws -> BufferOffset
    func storePacked(with builder: any ArenaBuilder) throws -> PackedStoreResult
}

// Marker for generated node handles. Reference-element arrays branch on it: node-ref
// elements can be shared/cyclic (offsets may be negative) so their slot table is ZigZag,
// while value elements (utf8/data/nested arrays) are always stored inline just before the
// table (strictly positive forward offsets) and use a plain unsigned slot table. (Spec §4.5)
public protocol ArenaNodeHandle {}
public protocol OptionalNodeHandle {}
extension Optional: OptionalNodeHandle where Wrapped: ArenaNodeHandle {}

public protocol ArenaUnion: ArenaGraphStorable {
    func apply(builder: any ArenaBuilder) throws -> ArenaAppliedUnionType
    func applyPacked(builder: any ArenaBuilder) throws -> PackedStoreResult
    var typeId: UInt64 { get }
    var byteWidth: ByteWidth { get }
}

fileprivate func _unionByteCountToWC(_ n: Int) -> Int {
    switch n { case 1: return 0; case 2: return 1; case 4: return 2; default: return 3 }
}

// Write the field slot ([TAG_LEB][1<<wc bytes]) for a frozen-node union field.
// Phase 1 (content) was already stored via apply(); this writes only the ptr/value + tag.
@discardableResult
func _storeUnionSlot(_ applied: ArenaAppliedUnionType, with builder: any ArenaBuilder) throws -> BufferOffset {
    let typeId: UInt64
    let beforePointer = builder.cursor
    switch applied {
    case .value(let value, let id, let width):
        _ = try width.storeNumber(value: value, with: builder)
        typeId = id
    case .pointer(let pointer, let id):
        _ = try pointer.storeForwardPointer(with: builder)
        typeId = id
    case .bidirPointer(let pointer, let id):
        _ = try pointer.storeBidirectionalPointer(with: builder)
        typeId = id
    }
    let widthCode = _unionByteCountToWC(Int(builder.cursor.value - beforePointer.value))
    return try builder.storeAsLEB(value: (typeId << 2) | UInt64(widthCode))
}

extension ArenaUnion {
    public func storePacked(with builder: any ArenaBuilder) throws -> PackedStoreResult {
        let valueResult = try applyPacked(builder: builder)
        _ = try builder.storeAsLEB(value: (typeId << 3) | UInt64(valueResult.unionCode))
        return .encoded
    }
    public func store(with builder: any ArenaBuilder) throws -> BufferOffset {
        // Nested-union value form (spec "spec/05-union-types.md" §nested): [value][LEB(inner_tid << 2)].
        // The low 2 bits (a width code) are NOT emitted here — the reader recovers each
        // variant's width from the schema (scalars) or self-describing pointers (utf8/data/
        // node/array variants), so a width code would be redundant. Keeping it at zero makes
        // the byte identical to Rust/TS, which never carried it. See _storeUnionSlot for the
        // *outer* field slot, which DOES carry a width code.
        let typeId: UInt64
        let applied = try self.apply(builder: builder)
        switch applied {
        case .value(let value, let id, let width):
            _ = try width.storeNumber(value: value, with: builder)
            typeId = id
        case .pointer(let pointer, let id):
            _ = try pointer.storeForwardPointer(with: builder)
            typeId = id
        case .bidirPointer(let pointer, let id):
            _ = try pointer.storeBidirectionalPointer(with: builder)
            typeId = id
        }
        return try builder.storeAsLEB(value: (typeId << 2))
    }
}

public protocol ArenaBuilder {
    var cursor: BufferOffset { get }
    var maxSize: UInt64 { get }
    var reserveFieldPointerSize: Int { get }
    // Write-side default elision ("spec/14-defaults-and-prefabs.md" §4). True for normal serialization;
    // set false while building prototype/prefab default blobs so they materialize every field.
    var elideDefaults: Bool { get }
    func setElideDefaults(_ v: Bool)
    func store(rawPointer: UnsafeRawPointer, size: Int) throws -> BufferOffset
    func store<T: Numeric>(number: T) throws -> BufferOffset
    func storeAsLEB(value: UInt64) throws -> BufferOffset
    func storeForwardPointer(value: BufferOffset) throws -> BufferOffset
    func storeBidirectionalPointer(value: BufferOffset) throws -> BufferOffset
    func store(vTable: [BufferOffset?]) throws -> BufferOffset
    func store(inline: [UInt8]) throws
    func setNodeForLateBinding(structNodeId: ArenaCycleIdntifier, offset: BufferOffset?)
    func get(string: String) -> BufferOffset?
    func set(string: String, cursor: BufferOffset)
    func beginStoring(nodeId: ArenaCycleIdntifier) throws -> BufferOffset?
    func finishStoring(nodeId: ArenaCycleIdntifier, offset: BufferOffset) throws
    func beginPackedStoring(nodeId: ArenaCycleIdntifier) throws -> BufferOffset
    func finishPackedStoring(nodeId: ArenaCycleIdntifier) -> PackedStoreResult
}

// ── DataArenaBuilder ──────────────────────────────────────────────────────────

fileprivate func _nextPow2(_ x: Int) -> Int {
    var v = x - 1
    v |= v >> 1; v |= v >> 2; v |= v >> 4; v |= v >> 8; v |= v >> 16
    return v + 1
}

public final class DataArenaBuilder: ArenaBuilder {
    public let maxSize: UInt64
    public let reserveFieldPointerSize: Int
    public private(set) var elideDefaults: Bool = true
    public func setElideDefaults(_ v: Bool) { elideDefaults = v }
    private var capacity: UInt64
    private var _data: UnsafeMutableRawPointer
    public var cursor: BufferOffset { .offset(_cursor) }
    private var _cursor: UInt64 = 0
    private var leftCursor: UInt64 { capacity - _cursor }

    private var stringLookup  = [String: BufferOffset]()
    private var vTableLookup  = [[UInt64]: BufferOffset]()
    private var structLookup  = [ArenaCycleIdntifier: BufferOffset]()
    private var inProgress    = Set<ArenaCycleIdntifier>()
    private var packedInProgress = Set<ArenaCycleIdntifier>()
    private var lateBindings  = [ArenaCycleIdntifier: [(BufferOffset, BufferOffset?)]]()
    private var nodeRefBindings = [ArenaCycleIdntifier: [(BufferOffset, UInt64, Int)]]()

    public init(maxSize: UInt64 = UInt64(1024 * 1024 * 2)) {
        self.maxSize = maxSize
        let bits = 64 - maxSize.leadingZeroBitCount + 3
        self.reserveFieldPointerSize = _nextPow2((bits >> 3) + (bits & 7 == 0 ? 0 : 1))
        self.capacity = min(1024, maxSize)
        _data = UnsafeMutableRawPointer.allocate(byteCount: Int(capacity), alignment: 1)
    }
    deinit { _data.deallocate() }

    public var makeData: Data {
        Data(bytes: _data.advanced(by: Int(leftCursor)), count: Int(_cursor))
    }

    /// The stored record as a VIEW (no copy) — valid until the next store / `reset()`.
    public var recordBytes: UnsafeRawBufferPointer {
        UnsafeRawBufferPointer(start: _data.advanced(by: Int(leftCursor)), count: Int(_cursor))
    }

    public func storeFinishAlignmentPadding(rootOffset: BufferOffset, maxN: Int, headerSpan: Int = 0) throws {
        guard maxN > 1 else { return }
        // The leading framing word encodes (storedOffset << 2 | discriminator bits); its
        // LEB length — not the bare distance — plus the header span (if any) precede the
        // body, so total length = framingLen + headerSpan + afterPad must be ≡ 0 mod maxN.
        for p in 0..<maxN {
            let afterPad = Int(_cursor) + p
            let storedOffset = (UInt64(afterPad) - rootOffset.value) + UInt64(headerSpan)
            let framingLen   = lebLength(storedOffset << 2)
            if (afterPad + framingLen + headerSpan) % maxN == 0 {
                for _ in 0..<p { _ = try store(number: UInt8(0)) }
                return
            }
        }
    }

    public func store(rawPointer: UnsafeRawPointer, size: Int) throws -> BufferOffset {
        try reserveCap(size)
        _data.advanced(by: Int(leftCursor) - size).copyMemory(from: rawPointer, byteCount: size)
        _cursor += UInt64(size)
        return cursor
    }
    public func store<T: Numeric>(number: T) throws -> BufferOffset {
        var n = number
        return try withUnsafeBytes(of: &n) { try store(rawPointer: $0.baseAddress!, size: $0.count) }
    }
    // Dispatch UInt64 value via explicit switch to avoid existential boxing.
    fileprivate func _storeUInt(_ v: UInt64, widthCode: Int) throws -> BufferOffset {
        switch widthCode {
        case 0: return try store(number: UInt8(v))
        case 1: return try store(number: UInt16(v))
        case 2: return try store(number: UInt32(v))
        default: return try store(number: v)
        }
    }
    // Store a signed value as two's-complement in `1<<widthCode` bytes (node-ref array slots, §4.5).
    fileprivate func _storeInt(_ d: Int64, widthCode: Int) throws -> BufferOffset {
        let u = UInt64(bitPattern: d)
        switch widthCode {
        case 0: return try store(number: UInt8(truncatingIfNeeded: u))
        case 1: return try store(number: UInt16(truncatingIfNeeded: u))
        case 2: return try store(number: UInt32(truncatingIfNeeded: u))
        default: return try store(number: u)
        }
    }
    public func store(inline bytes: [UInt8]) throws {
        var stored = false
        try bytes.withContiguousStorageIfAvailable { bp in
            guard let p = bp.baseAddress else { return }
            _ = try store(rawPointer: p, size: bp.count); stored = true
        }
        if !stored { for b in bytes.reversed() { _ = try store(number: b) } }
    }
    public func storeAsLEB(value: UInt64) throws -> BufferOffset { try _storeAsLEB(value, at: nil) }
    public func storeForwardPointer(value: BufferOffset) throws -> BufferOffset {
        try _storeV62(_cursor - value.value, at: nil)
    }
    public func storeBidirectionalPointer(value: BufferOffset) throws -> BufferOffset {
        switch value {
        case .offset(let off): return try _storeV62((Int64(_cursor) - Int64(off)).toZigZag, at: nil)
        case .inProgress(let id):
            _ = try store(inline: [UInt8](repeating: 0, count: reserveFieldPointerSize))
            setNodeForLateBinding(structNodeId: id, offset: nil)
            return cursor
        }
    }
    public func store(vTable: [BufferOffset?]) throws -> BufferOffset {
        var norm = [UInt64](repeating: 0, count: vTable.count)
        var is16 = false
        for i in 0..<vTable.count {
            if let v = vTable[i]?.value { norm[i] = _cursor - v + 1 }
            // The wire format caps entries at UInt16 ("05" §VTable is16Bit) — fail
            // loudly rather than trap/truncate if a slot drifted too far from the node.
            guard norm[i] <= UInt16.max else { throw ArenaStoreError.vTableEntryOverflow(norm[i]) }
            is16 = is16 || norm[i] > UInt8.max
        }
        if let p = vTableLookup[norm]?.value {
            return try _storeAsLEB((_cursor - p) << 1, at: nil)
        }
        let result: BufferOffset
        if is16 {
            let cnt = (vTable.count << 1) | 1
            let nb  = 64 - cnt.leadingZeroBitCount
            let sz  = (nb/7) + (nb%7 == 0 ? 0:1) + vTable.count * 2
            result  = try _storeAsLEB(UInt64(sz).toNegativZigZag, at: nil)
            for v in norm.reversed() { _ = try store(number: UInt16(v)) }
            vTableLookup[norm] = try _storeAsLEB(UInt64(cnt), at: nil)
        } else {
            let cnt = vTable.count << 1
            let nb  = 64 - cnt.leadingZeroBitCount
            let sz  = cnt == 0 ? 0 : (nb/7) + (nb%7 == 0 ? 0:1) + vTable.count
            result  = try _storeAsLEB(sz == 0 ? 0 : UInt64(sz).toNegativZigZag, at: nil)
            for v in norm.reversed() { _ = try store(number: UInt8(v)) }
            vTableLookup[norm] = try _storeAsLEB(UInt64(cnt), at: nil)
        }
        return result
    }
    public func setNodeForLateBinding(structNodeId: ArenaCycleIdntifier, offset: BufferOffset?) {
        lateBindings[structNodeId, default: []].append((cursor, offset))
    }
    func setNodeRefBinding(_ nodeId: ArenaCycleIdntifier, pos: BufferOffset, arrayCur: UInt64, widthCode: Int) {
        nodeRefBindings[nodeId, default: []].append((pos, arrayCur, widthCode))
    }
    public func get(string: String) -> BufferOffset? { stringLookup[string] }
    public func set(string: String, cursor: BufferOffset) { stringLookup[string] = cursor }
    public func beginStoring(nodeId: ArenaCycleIdntifier) throws -> BufferOffset? {
        if inProgress.contains(nodeId) { return .inProgress(nodeId) }
        if let off = structLookup[nodeId] { return off }
        inProgress.insert(nodeId)
        return nil
    }
    public func finishStoring(nodeId: ArenaCycleIdntifier, offset: BufferOffset) throws {
        inProgress.remove(nodeId)
        if let bindings = lateBindings[nodeId] {
            for (pos, arrayEnd) in bindings {
                let encoded: UInt64
                if let ae = arrayEnd {
                    encoded = (Int64(ae.value) - Int64(offset.value)).toZigZag
                } else {
                    // pos.value is cursor AFTER the placeholder; subtract its size so the
                    // encoded distance is measured from the pointer's END (matching the read side).
                    encoded = (Int64(pos.value) - Int64(reserveFieldPointerSize) - Int64(offset.value)).toZigZag
                }
                _ = try _storeV62(encoded, at: pos, mask: maskV64)
            }
            lateBindings.removeValue(forKey: nodeId)
        }
        if let bindings = nodeRefBindings[nodeId] {
            for (pos, arrayCur, widthCode) in bindings {
                // Node-ref array slot: two's-complement of the signed distance, low `1<<widthCode` bytes (§4.5).
                let rel = UInt64(bitPattern: Int64(arrayCur) - Int64(offset.value) + 1)
                switch widthCode {
                case 0: _storeAt(UInt8(rel & 0xFF), at: pos)
                case 1: _storeAt(UInt16(rel & 0xFFFF), at: pos)
                case 2: _storeAt(UInt32(rel & 0xFFFFFFFF), at: pos)
                default: _storeAt(rel, at: pos)
                }
            }
            nodeRefBindings.removeValue(forKey: nodeId)
        }
        structLookup[nodeId] = offset
    }
    var maskV64: Int { reserveFieldPointerSize.trailingZeroBitCount }
    public func beginPackedStoring(nodeId: ArenaCycleIdntifier) throws -> BufferOffset {
        guard !packedInProgress.contains(nodeId) else { throw ArenaStoreError.encounteredCycleWhilePackedStoring }
        packedInProgress.insert(nodeId)
        return cursor
    }
    public func finishPackedStoring(nodeId: ArenaCycleIdntifier) -> PackedStoreResult {
        packedInProgress.remove(nodeId)
        return .raw(0)  // packed node is always .raw variable-size
    }

    public func reset() {
        _cursor = 0
        stringLookup.removeAll(keepingCapacity: true)
        vTableLookup.removeAll(keepingCapacity: true)
        structLookup.removeAll(keepingCapacity: true)
        inProgress.removeAll(keepingCapacity: true)
        packedInProgress.removeAll(keepingCapacity: true)
        lateBindings.removeAll(keepingCapacity: true)
        nodeRefBindings.removeAll(keepingCapacity: true)
    }

    private func reserveCap(_ size: Int) throws {
        guard leftCursor <= UInt64(size) else { return }
        let old = leftCursor
        while leftCursor <= UInt64(size) { capacity <<= 1 }
        guard capacity <= maxSize else { throw BuilderError.wentOverMaxSize }
        let nd = UnsafeMutableRawPointer.allocate(byteCount: Int(capacity), alignment: 1)
        nd.advanced(by: Int(leftCursor)).copyMemory(from: _data.advanced(by: Int(old)), byteCount: Int(_cursor))
        _data.deallocate(); _data = nd
    }
    private func _storeV62(_ value: UInt64, at pos: BufferOffset?, mask: Int? = nil) throws -> BufferOffset {
        func enc<T: FixedWidthInteger>(_ v: T, _ m: T) -> T { v << 2 | m }
        let minCode = mask ?? 0
        if value < (1 << 6), minCode == 0 {
            let v = enc(UInt8(value), UInt8(0))
            if let p = pos { _storeAt(v, at: p); return cursor }
            return try store(number: v)
        } else if value < (1 << 14), minCode <= 1 {
            let v = enc(UInt16(value), UInt16(max(1, minCode)))
            if let p = pos { _storeAt(v, at: p); return cursor }
            return try store(number: v)
        } else if value < (1 << 30), minCode <= 2 {
            let v = enc(UInt32(value), UInt32(max(2, minCode)))
            if let p = pos { _storeAt(v, at: p); return cursor }
            return try store(number: v)
        } else if value < (1 << 62) {
            let v = enc(UInt64(value), UInt64(max(3, minCode)))
            if let p = pos { _storeAt(v, at: p); return cursor }
            return try store(number: v)
        }
        throw ArenaStoreError.cantStoreValueAsV62(value)
    }
    private func _storeAsLEB(_ value: UInt64, at pos: BufferOffset?) throws -> BufferOffset {
        guard value > 0 else {
            if let p = pos { _storeAt(UInt8(0), at: p); return cursor }
            return try store(number: UInt8(0))
        }
        let nb = (64 - value.leadingZeroBitCount)
        let bytes = (nb / 7) + (nb % 7 == 0 ? 0 : 1)
        try reserveCap(bytes)
        let base: Int
        if let p = pos { base = Int(capacity - p.value) }
        else           { base = Int(leftCursor) - bytes }
        var rest = value; var i = 0
        while rest > 0 {
            let b = UInt8(rest & 0x7F) | 0x80
            _data.storeBytes(of: b, toByteOffset: base + i, as: UInt8.self)
            i += 1; rest >>= 7
        }
        let last = _data.load(fromByteOffset: base + bytes - 1, as: UInt8.self) & 0x7F
        _data.storeBytes(of: last, toByteOffset: base + bytes - 1, as: UInt8.self)
        if pos == nil { _cursor += UInt64(bytes) }
        return cursor
    }
    private func _storeAt<T: Numeric>(_ value: T, at pos: BufferOffset) {
        var v = value
        withUnsafeBytes(of: &v) { _data.advanced(by: Int(capacity - pos.value)).copyMemory(from: $0.baseAddress!, byteCount: $0.count) }
    }
}

// ── ArenaGraphStorable on primitives ─────────────────────────────────────────

extension String: ArenaGraphStorable {
    public func storePacked(with builder: any ArenaBuilder) throws -> PackedStoreResult {
        var done = false
        try utf8.withContiguousStorageIfAvailable { bp in
            _ = try builder.store(rawPointer: bp.baseAddress!, size: bp.count)
            _ = try builder.storeAsLEB(value: UInt64(bp.count))
            done = true
        }
        if !done {
            for c in utf8.lazy.reversed() { _ = try builder.store(number: c) }
            _ = try builder.storeAsLEB(value: UInt64(utf8.count))
        }
        return .raw(0)
    }
    public func store(with builder: any ArenaBuilder) throws -> BufferOffset {
        if let r = builder.get(string: self) { return r }
        var done = false
        try utf8.withContiguousStorageIfAvailable { bp in
            _ = try builder.store(rawPointer: bp.baseAddress!, size: bp.count)
            _ = try builder.storeAsLEB(value: UInt64(bp.count))
            done = true
        }
        if !done {
            for c in utf8.lazy.reversed() { _ = try builder.store(number: c) }
            _ = try builder.storeAsLEB(value: UInt64(utf8.count))
        }
        builder.set(string: self, cursor: builder.cursor)
        return builder.cursor
    }
}

extension Data: ArenaGraphStorable {
    public func storePacked(with builder: any ArenaBuilder) throws -> PackedStoreResult {
        var done = false
        try withContiguousStorageIfAvailable { bp in
            _ = try builder.store(rawPointer: bp.baseAddress!, size: bp.count)
            _ = try builder.storeAsLEB(value: UInt64(bp.count))
            done = true
        }
        if !done {
            for b in self.lazy.reversed() { _ = try builder.store(number: b) }
            _ = try builder.storeAsLEB(value: UInt64(count))
        }
        return .raw(0)
    }
    public func store(with builder: any ArenaBuilder) throws -> BufferOffset {
        var done = false
        try withContiguousStorageIfAvailable { bp in
            _ = try builder.store(rawPointer: bp.baseAddress!, size: bp.count)
            _ = try builder.storeAsLEB(value: UInt64(bp.count))
            done = true
        }
        if !done {
            for b in self.lazy.reversed() { _ = try builder.store(number: b) }
            _ = try builder.storeAsLEB(value: UInt64(count))
        }
        return builder.cursor
    }
}

extension Bool: ArenaGraphStorable {
    public func storePacked(with builder: any ArenaBuilder) throws -> PackedStoreResult {
        _ = try store(with: builder); return .raw(1)
    }
    public func store(with builder: any ArenaBuilder) throws -> BufferOffset {
        try builder.store(number: self ? UInt8(1) : UInt8(0))
    }
}
extension UInt8: ArenaGraphStorable {
    public func storePacked(with b: any ArenaBuilder) throws -> PackedStoreResult { _ = try b.store(number: self); return .raw(1) }
    public func store(with b: any ArenaBuilder) throws -> BufferOffset { try b.store(number: self) }
}
extension Int8: ArenaGraphStorable {
    public func storePacked(with b: any ArenaBuilder) throws -> PackedStoreResult { _ = try b.store(number: self); return .raw(1) }
    public func store(with b: any ArenaBuilder) throws -> BufferOffset { try b.store(number: self) }
}
extension UInt16: ArenaGraphStorable {
    public func storePacked(with b: any ArenaBuilder) throws -> PackedStoreResult {
        if lebLength(UInt64(self)) < 2 { _ = try b.storeAsLEB(value: UInt64(self)); return .encoded }
        _ = try b.store(number: self); return .raw(2)
    }
    public func store(with b: any ArenaBuilder) throws -> BufferOffset { try b.store(number: self) }
}
extension Int16: ArenaGraphStorable {
    public func storePacked(with b: any ArenaBuilder) throws -> PackedStoreResult {
        let zz = Int64(self).toZigZag
        if lebLength(zz) < 2 { _ = try b.storeAsLEB(value: zz); return .encoded }
        _ = try b.store(number: self); return .raw(2)
    }
    public func store(with b: any ArenaBuilder) throws -> BufferOffset { try b.store(number: self) }
}
extension UInt32: ArenaGraphStorable {
    public func storePacked(with b: any ArenaBuilder) throws -> PackedStoreResult {
        if lebLength(UInt64(self)) < 4 { _ = try b.storeAsLEB(value: UInt64(self)); return .encoded }
        _ = try b.store(number: self); return .raw(4)
    }
    public func store(with b: any ArenaBuilder) throws -> BufferOffset { try b.store(number: self) }
}
extension Int32: ArenaGraphStorable {
    public func storePacked(with b: any ArenaBuilder) throws -> PackedStoreResult {
        let zz = Int64(self).toZigZag
        if lebLength(zz) < 4 { _ = try b.storeAsLEB(value: zz); return .encoded }
        _ = try b.store(number: self); return .raw(4)
    }
    public func store(with b: any ArenaBuilder) throws -> BufferOffset { try b.store(number: self) }
}
extension UInt64: ArenaGraphStorable {
    public func storePacked(with b: any ArenaBuilder) throws -> PackedStoreResult {
        if lebLength(self) < 8 { _ = try b.storeAsLEB(value: self); return .encoded }
        _ = try b.store(number: self); return .raw(8)
    }
    public func store(with b: any ArenaBuilder) throws -> BufferOffset { try b.store(number: self) }
}
extension Int64: ArenaGraphStorable {
    public func storePacked(with b: any ArenaBuilder) throws -> PackedStoreResult {
        let zz = self.toZigZag
        if lebLength(zz) < 8 { _ = try b.storeAsLEB(value: zz); return .encoded }
        _ = try b.store(number: self); return .raw(8)
    }
    public func store(with b: any ArenaBuilder) throws -> BufferOffset { try b.store(number: self) }
}
extension Float: ArenaGraphStorable {
    public func storePacked(with b: any ArenaBuilder) throws -> PackedStoreResult {
        // Special values → tag only, no payload
        if isZero    { _ = try b.store(number: sign == .minus ? UInt8(0x01) : UInt8(0x00)); return .floatEncoded }
        if isNaN     { _ = try b.store(number: UInt8(0x04)); return .floatEncoded }
        if isInfinite{ _ = try b.store(number: sign == .minus ? UInt8(0x03) : UInt8(0x02)); return .floatEncoded }
        // Exact signed integer in (-2²¹, 2²¹) with LEB ≤ 3 bytes (tag 0x05)
        if let i = Int32(exactly: self), abs(i) < (1 << 21) {
            let zz = Int64(i).toZigZag
            if lebLength(zz) <= 3 { _ = try b.storeAsLEB(value: zz); _ = try b.store(number: UInt8(0x05)); return .floatEncoded }
        }
        // Float16 exact (tag 0x06, 2 payload bytes)
        if let bits16 = _f32ToF16Bits(self) {
            var b16 = bits16; _ = try withUnsafeBytes(of: &b16) { try b.store(rawPointer: $0.baseAddress!, size: 2) }
            _ = try b.store(number: UInt8(0x06)); return .floatEncoded
        }
        // Fallback: 4 raw IEEE-754 bytes — raw is smaller than packed (4 < 5)
        _ = try b.store(number: self); return .raw(4)
    }
    public func store(with b: any ArenaBuilder) throws -> BufferOffset { try b.store(number: self) }
}
extension Double: ArenaGraphStorable {
    public func storePacked(with b: any ArenaBuilder) throws -> PackedStoreResult {
        // Special values → tag only, no payload
        if isZero    { _ = try b.store(number: sign == .minus ? UInt8(0x01) : UInt8(0x00)); return .floatEncoded }
        if isNaN     { _ = try b.store(number: UInt8(0x04)); return .floatEncoded }
        if isInfinite{ _ = try b.store(number: sign == .minus ? UInt8(0x03) : UInt8(0x02)); return .floatEncoded }
        // Exact signed integer in (-2⁴⁸, 2⁴⁸) with LEB ≤ 7 bytes (tag 0x05)
        if let i = Int64(exactly: self), abs(i) < (1 << 48) {
            let zz = i.toZigZag
            if lebLength(zz) <= 7 { _ = try b.storeAsLEB(value: zz); _ = try b.store(number: UInt8(0x05)); return .floatEncoded }
        }
        // Float32 exact → try Float16 first (more compact), then Float32
        let f32 = Float(self)
        if Double(f32) == self {
            if let bits16 = _f32ToF16Bits(f32) {
                var b16 = bits16; _ = try withUnsafeBytes(of: &b16) { try b.store(rawPointer: $0.baseAddress!, size: 2) }
                _ = try b.store(number: UInt8(0x06)); return .floatEncoded
            }
            _ = try b.store(number: f32); _ = try b.store(number: UInt8(0x07)); return .floatEncoded
        }
        // Fallback: 8 raw IEEE-754 bytes — raw is smaller than packed (8 < 9)
        _ = try b.store(number: self); return .raw(8)
    }
    public func store(with b: any ArenaBuilder) throws -> BufferOffset { try b.store(number: self) }
}

// [String] / [Data]: the generic `Array.storePacked` below reaches these through per-call
// `Element.self` probes and a per-element `as? any ArenaGraphStorable` cast. These concrete
// overloads (chosen statically wherever the element type is known, e.g. every generated
// packed store) write the same bytes: elements back-to-front, plain count, block length.
extension Array where Element == String {
    public func storePacked(with builder: any ArenaBuilder) throws -> PackedStoreResult {
        let before = builder.cursor
        for s in reversed() { _ = try s.storePacked(with: builder) }
        _ = try builder.storeAsLEB(value: UInt64(count))
        _ = try builder.storeAsLEB(value: builder.cursor.value - before.value)
        return .raw(0)
    }
}
extension Array where Element == Foundation.Data {
    public func storePacked(with builder: any ArenaBuilder) throws -> PackedStoreResult {
        let before = builder.cursor
        for d in reversed() { _ = try d.storePacked(with: builder) }
        _ = try builder.storeAsLEB(value: UInt64(count))
        _ = try builder.storeAsLEB(value: builder.cursor.value - before.value)
        return .raw(0)
    }
}

extension Array: ArenaGraphStorable {
    public func storePacked(with builder: any ArenaBuilder) throws -> PackedStoreResult {
        let before = builder.cursor
        // Packed-int arrays fold a 2-bit encoding tag into the count (§5.1): nil = plain count,
        // otherwise LEB((count << 2) | tag), tag 0 = all-LEB, 1 = all-raw, 2 = mixed.
        var _intArrTag: Int? = nil
        // Float arrays fold a 2-bit mode into the count (§5.2): 0 = packed (self-describing), 1 = raw.
        // This generic runtime path only ever writes packed; raw float arrays are emitted inline by codegen.
        var _floatArrMode: Int? = nil
        if Element.self is (any OptionalType.Type) {
            if Element.self == Optional<Bool>.self {
                let bools = self as! [Bool?]
                let n = bools.count
                var bitSetNil = [UInt8](repeating: 0, count: (n + 7) >> 3)
                var nilCount = 0
                for (i, b) in bools.enumerated() {
                    if b == nil { bitSetNil[i >> 3] |= 1 << (i & 7); nilCount += 1 }
                }
                let m = n - nilCount
                var bitSetValues = [UInt8](repeating: 0, count: (m + 7) >> 3)
                var ci = 0
                for b in bools {
                    if let b = b {
                        if b { bitSetValues[ci >> 3] |= 1 << (ci & 7) }
                        ci += 1
                    }
                }
                if !bitSetValues.isEmpty { try builder.store(inline: bitSetValues) }
                try builder.store(inline: bitSetNil)
                _ = try builder.storeAsLEB(value: UInt64(count))
                _ = try builder.storeAsLEB(value: builder.cursor.value - before.value)
                return .raw(0)
            }
            var bitSetNil = [UInt8](repeating: 0, count: (count >> 3) + ((count & 7) > 0 ? 1 : 0))
            if Element.self is (any ArenaOptEnum.Type) {
                let _firstE = self.lazy.compactMap({ ($0 as? any OptionalType)?.optional as? any ArenaEnum }).first
                let _bw = _firstE?.byteWidth ?? .one
                switch _bw {
                case .eighth, .quarter, .half:
                    let _bpe: Int = _bw == .eighth ? 1 : (_bw == .quarter ? 2 : 4)
                    let n = count
                    var _bsNil = [UInt8](repeating: 0, count: (n + 7) >> 3)
                    var _nilCnt = 0
                    for (i, el) in enumerated() {
                        let _opt = (el as? any OptionalType)?.optional as? any ArenaEnum
                        if _opt == nil { _bsNil[i >> 3] |= 1 << (i & 7); _nilCnt += 1 }
                    }
                    let m = n - _nilCnt
                    let _bsvLen = (m * _bpe + 7) >> 3
                    var _bsVal = [UInt8](repeating: 0, count: _bsvLen)
                    var _ci = 0
                    for el in self {
                        guard let _e = (el as? any OptionalType)?.optional as? any ArenaEnum else { continue }
                        let v = _e.value
                        switch _bw {
                        case .eighth:  _bsVal[_ci >> 3] |= (UInt8(v) & 1)  << UInt8(_ci & 7)
                        case .quarter: _bsVal[_ci >> 2] |= (UInt8(v) & 3)  << UInt8((_ci & 3) << 1)
                        case .half:    _bsVal[_ci >> 1] |= (UInt8(v) & 15) << UInt8((_ci & 1) << 2)
                        default: break
                        }
                        _ci += 1
                    }
                    if !_bsVal.isEmpty { try builder.store(inline: _bsVal) }
                    try builder.store(inline: _bsNil)
                default:
                    for (index, element) in enumerated().reversed() {
                        if let _e = (element as? any OptionalType)?.optional as? any ArenaGraphStorable {
                            _ = try _e.storePacked(with: builder)
                        } else {
                            bitSetNil[index >> 3] |= 1 << (index & 7)
                        }
                    }
                    try builder.store(inline: bitSetNil)
                }
            } else if let _ = self.first(where: { $0 is any ArenaUnion }) {
                // Two-section layout: payloads first, then hdr_sect_size LEB, then headers, then bitSetNil
                var _codes = [Int]()
                var _tids = [UInt64]()
                for (index, element) in enumerated().reversed() {
                    if let u = element as? any ArenaUnion {
                        let _r = try u.applyPacked(builder: builder)
                        _codes.append(_r.unionCode)
                        _tids.append(u.typeId)
                    } else {
                        bitSetNil[index >> 3] |= 1 << (index & 7)
                    }
                }
                let _hdrBefore = builder.cursor.value
                for _i in 0..<_tids.count {
                    _ = try builder.storeAsLEB(value: (_tids[_i] << 3) | UInt64(_codes[_i]))
                }
                _ = try builder.storeAsLEB(value: builder.cursor.value - _hdrBefore)
                try builder.store(inline: bitSetNil)
            } else if let _ = self.first(where: { $0 is any ArenaGraphStorable }) {
                let _needsEnc = Element.self == UInt16?.self || Element.self == Int16?.self ||
                                Element.self == UInt32?.self || Element.self == Int32?.self ||
                                Element.self == UInt64?.self || Element.self == Int64?.self
                if _needsEnc {
                    var _encBits = [UInt8](repeating: 0, count: (count + 7) >> 3)
                    var _rawCount = 0, _presentCount = 0
                    for (_ei, _el) in enumerated().reversed() {
                        if let _elem = _el as? any ArenaGraphStorable {
                            let _r = try _elem.storePacked(with: builder)
                            _presentCount += 1
                            if case .raw(_) = _r { _encBits[_ei >> 3] |= 1 << (_ei & 7); _rawCount += 1 }
                        } else {
                            bitSetNil[_ei >> 3] |= 1 << (_ei & 7)
                        }
                    }
                    // Uniform encoding → drop the enc bitset and record the tag; mixed keeps it.
                    if _rawCount == 0 { _intArrTag = 0 }
                    else if _rawCount == _presentCount { _intArrTag = 1 }
                    else { _intArrTag = 2; try builder.store(inline: _encBits) }
                    try builder.store(inline: bitSetNil)
                } else {
                    for (index, element) in enumerated().reversed() {
                        if let element = element as? any ArenaGraphStorable {
                            _ = try element.storePacked(with: builder)
                        } else {
                            bitSetNil[index >> 3] |= 1 << (index & 7)
                        }
                    }
                    try builder.store(inline: bitSetNil)
                }
            }
        } else if Element.self is (any ArenaUnion.Type) {
            // Two-section layout: Phase 1 payloads (reversed), Phase 2 headers (forward through collected)
            var _codes = [Int](repeating: 0, count: count)
            var _tids = [UInt64](repeating: 0, count: count)
            for (i, element) in enumerated().reversed() {
                let u = element as! any ArenaUnion
                let _r = try u.applyPacked(builder: builder)
                _codes[i] = _r.unionCode
                _tids[i] = u.typeId
            }
            for i in stride(from: count - 1, through: 0, by: -1) {
                _ = try builder.storeAsLEB(value: (_tids[i] << 3) | UInt64(_codes[i]))
            }
        } else if Element.self == Bool.self {
            let bools = self as! [Bool]
            let byteCount = (bools.count + 7) >> 3
            var bitset = [UInt8](repeating: 0, count: byteCount)
            for (i, b) in bools.enumerated() {
                if b { bitset[i >> 3] |= 1 << (i & 7) }
            }
            try builder.store(inline: bitset)
        } else if Element.self is (any ArenaEnum.Type) {
            let _bw = (first as? any ArenaEnum)?.byteWidth ?? .one
            switch _bw {
            case .eighth, .quarter, .half:
                var _bs = _bw.bitSet(forArraySize: count)
                for (idx, el) in enumerated() {
                    let v = (el as? any ArenaEnum)?.value ?? 0
                    switch _bw {
                    case .eighth:  _bs[idx >> 3] |= (UInt8(v) & 1)  << (idx & 7)
                    case .quarter: _bs[idx >> 2] |= (UInt8(v) & 3)  << ((idx & 3) << 1)
                    case .half:    _bs[idx >> 1] |= (UInt8(v) & 15) << ((idx & 1) << 2)
                    default: break
                    }
                }
                try builder.store(inline: _bs)
            default:
                for element in reversed() {
                    if let s = element as? any ArenaGraphStorable { _ = try s.storePacked(with: builder) }
                }
            }
        } else {
            let _needsEnc = Element.self == UInt16.self || Element.self == Int16.self ||
                            Element.self == UInt32.self || Element.self == Int32.self ||
                            Element.self == UInt64.self || Element.self == Int64.self
            if _needsEnc {
                var _encBits = [UInt8](repeating: 0, count: (count + 7) >> 3)
                var _rawCount = 0
                for (_ei, _el) in enumerated().reversed() {
                    if let _s = _el as? any ArenaGraphStorable {
                        let _r = try _s.storePacked(with: builder)
                        if case .raw(_) = _r { _encBits[_ei >> 3] |= 1 << (_ei & 7); _rawCount += 1 }
                    }
                }
                // Uniform encoding → drop the enc bitset and record the tag; mixed keeps it.
                if _rawCount == 0 { _intArrTag = 0 }
                else if _rawCount == count { _intArrTag = 1 }
                else { _intArrTag = 2; try builder.store(inline: _encBits) }
            } else if Element.self == Float.self {
                // Self-describing per element (matches _decodePackedFloat32): emit the 0x07
                // raw tag for the non-compressible fallback so no encBits are needed.
                for element in reversed() {
                    let _r = try (element as! Float).storePacked(with: builder)
                    if case .raw = _r { _ = try builder.store(number: UInt8(0x07)) }
                }
                _floatArrMode = 0
            } else if Element.self == Double.self {
                for element in reversed() {
                    let _r = try (element as! Double).storePacked(with: builder)
                    if case .raw = _r { _ = try builder.store(number: UInt8(0x08)) }
                }
                _floatArrMode = 0
            } else {
                for element in reversed() {
                    if let s = element as? any ArenaGraphStorable {
                        _ = try s.storePacked(with: builder)
                    }
                }
            }
        }
        if let _t = _intArrTag {
            _ = try builder.storeAsLEB(value: (UInt64(count) << 2) | UInt64(_t))
        } else if let _m = _floatArrMode {
            _ = try builder.storeAsLEB(value: (UInt64(count) << 2) | UInt64(_m))
        } else {
            _ = try builder.storeAsLEB(value: UInt64(count))
        }
        _ = try builder.storeAsLEB(value: builder.cursor.value - before.value)
        return .raw(0)
    }
    public func store(with builder: any ArenaBuilder) throws -> BufferOffset {
        if Element.self is (any OptionalType.Type) {
            if Element.self == Optional<Bool>.self {
                return try _storeBoolOptArray(with: builder)
            }
            if Element.self is (any ArenaOptEnum.Type) {
                return try _storeOptionalEnumArray(with: builder)
            }
            if let _ = self.first(where: { $0 is any ArenaUnion }) {
                return try _storeOptionalUnionArray(with: builder)
            }
            return try _storeOptionalGraphStorable(with: builder)
        }
        if Element.self == Bool.self {
            return try _storeBoolArray(with: builder)
        }
        if Element.self is (any ArenaUnion.Type) {
            return try _storeUnionArray(with: builder)
        }
        if Element.self is (any ArenaEnum.Type) {
            return try _storeEnumArray(with: builder)
        }
        // Fixed-width numeric types: inline format [LEB(count)] [elem[0]..elem[N-1]] (LE raw bytes)
        if Element.self == UInt8.self  || Element.self == Int8.self  ||
           Element.self == UInt16.self || Element.self == Int16.self ||
           Element.self == UInt32.self || Element.self == Int32.self ||
           Element.self == UInt64.self || Element.self == Int64.self ||
           Element.self == Float.self  || Element.self == Double.self {
            for element in reversed() {
                if let s = element as? any ArenaGraphStorable { _ = try s.store(with: builder) }
            }
            return try builder.storeAsLEB(value: UInt64(count))
        }
        // Reference-element array: node refs → ZigZag slot table (may be negative/cyclic);
        // value refs (utf8/data/nested arrays) → plain unsigned slot table. (Spec §4.5)
        let _isNodeRef = Element.self is (any ArenaNodeHandle.Type)
        var widthCode = 0
        let offsets: [BufferOffset?] = try reversed().map { el -> BufferOffset? in
            guard let s = el as? any ArenaGraphStorable else { return nil }
            let off = try s.store(with: builder)
            // In-progress (cyclic back-edge) slot: patched in-place once the target's final
            // makeData position is known, so reserve the maxSize-derived worst-case width now
            // (§05 "Cycle serialization — dummy references"). Matching the single-ref reserve
            // (reserveFieldPointerSize) keeps this byte-identical to Rust/Python/TS/Mojo and
            // avoids a >32 KB buffer overflowing a too-narrow slot on patch.
            if _isNodeRef, case .inProgress = off { widthCode = Swift.max(widthCode, builder.reserveFieldPointerSize.trailingZeroBitCount) }
            return off
        }
        let cur = builder.cursor
        let db = builder as! DataArenaBuilder
        // Size widthCode from the actual encoded slot: unsigned distance (value refs), or the
        // signed two's-complement distance (node refs, may be negative/cyclic). (Spec §4.5)
        for off in offsets {
            if case .some(.offset(let v)) = off {
                let d = Int64(cur.value) - Int64(v) + 1
                widthCode = Swift.max(widthCode, _isNodeRef ? _signedWidthCode(d) : _offsetWidthCode(UInt64(d)))
            }
        }
        for off in offsets {
            switch off {
            case .some(.offset(let v)):
                let d = Int64(cur.value) - Int64(v) + 1
                if _isNodeRef { _ = try db._storeInt(d, widthCode: widthCode) }
                else          { _ = try db._storeUInt(UInt64(d), widthCode: widthCode) }
            case .some(.inProgress(let nodeId)):
                _ = try db._storeUInt(0, widthCode: widthCode)
                let entryPos = builder.cursor  // cursor AFTER placeholder, matching _storeAt convention
                db.setNodeRefBinding(nodeId, pos: entryPos, arrayCur: cur.value, widthCode: widthCode)
            case .none:
                _ = try db._storeUInt(0, widthCode: widthCode)
            }
        }
        return try builder.storeAsLEB(value: UInt64(count << 2) | UInt64(widthCode))
    }
    private func _storeBoolArray(with builder: any ArenaBuilder) throws -> BufferOffset {
        let bools = self as! [Bool]
        let n = bools.count
        var bitset = [UInt8](repeating: 0, count: (n + 7) >> 3)
        for (i, b) in bools.enumerated() {
            if b { bitset[i >> 3] |= 1 << (i & 7) }
        }
        try builder.store(inline: bitset)
        return try builder.storeAsLEB(value: UInt64(n))
    }
    private func _storeBoolOptArray(with builder: any ArenaBuilder) throws -> BufferOffset {
        // Regular (non-packed) [Bool?]: [LEB(N)][bitSetNil ⌈N/8⌉][bitSetValues ⌈N/8⌉].
        // Both bitsets use original (non-compacted) element indices, so element i is O(1)
        // random-accessible. The value bit for a nil position stays 0 and is never read
        // (the nil bit takes precedence). Matches spec §4.7. The compacted layout is
        // reserved for the packed path (storePacked, §5.7).
        let bools = self as! [Bool?]
        let n = bools.count
        var bitSetNil = [UInt8](repeating: 0, count: (n + 7) >> 3)
        var bitSetValues = [UInt8](repeating: 0, count: (n + 7) >> 3)
        for (i, b) in bools.enumerated() {
            if let b = b {
                if b { bitSetValues[i >> 3] |= 1 << (i & 7) }
            } else {
                bitSetNil[i >> 3] |= 1 << (i & 7)
            }
        }
        try builder.store(inline: bitSetValues)
        try builder.store(inline: bitSetNil)
        return try builder.storeAsLEB(value: UInt64(n))
    }
    private func _storeEnumArray(with builder: any ArenaBuilder) throws -> BufferOffset {
        guard let firstEnum = first as? any ArenaEnum else {
            return try builder.storeAsLEB(value: 0)
        }
        let bw = firstEnum.byteWidth
        switch bw {
        case .eighth, .quarter, .half:
            var bitset = bw.bitSet(forArraySize: count)
            for (idx, el) in enumerated() {
                let v = (el as? any ArenaEnum)?.value ?? 0
                switch bw {
                case .eighth:  bitset[idx >> 3] |= (UInt8(v) & 1)  << (idx & 7)
                case .quarter: bitset[idx >> 2] |= (UInt8(v) & 3)  << ((idx & 3) << 1)
                case .half:    bitset[idx >> 1] |= (UInt8(v) & 15) << ((idx & 1) << 2)
                default: break
                }
            }
            try builder.store(inline: bitset)
            return try builder.storeAsLEB(value: UInt64(count))
        default:
            for element in reversed() {
                if let s = element as? any ArenaGraphStorable { _ = try s.store(with: builder) }
            }
            return try builder.storeAsLEB(value: UInt64(count))
        }
    }
    private func _storeOptionalEnumArray(with builder: any ArenaBuilder) throws -> BufferOffset {
        let n = count
        let firstEnum = self.lazy.compactMap({ ($0 as? any OptionalType)?.optional as? any ArenaEnum }).first
        let bw: ByteWidth = firstEnum?.byteWidth ?? .one
        let bsnLen = (n + 7) >> 3
        var bitSetNil = [UInt8](repeating: 0, count: bsnLen)
        switch bw {
        case .eighth, .quarter, .half:
            let bitsPerElem: Int = bw == .eighth ? 1 : (bw == .quarter ? 2 : 4)
            let bsvLen = (n * bitsPerElem + 7) >> 3
            var bitSetVal = [UInt8](repeating: 0, count: bsvLen)
            for (i, el) in enumerated() {
                let opt = (el as? any OptionalType)?.optional as? any ArenaEnum
                if opt == nil { bitSetNil[i >> 3] |= 1 << (i & 7) }
                else {
                    let v = opt!.value
                    switch bw {
                    case .eighth:  bitSetVal[i >> 3] |= (UInt8(v) & 1)  << (i & 7)
                    case .quarter: bitSetVal[i >> 2] |= (UInt8(v) & 3)  << ((i & 3) << 1)
                    case .half:    bitSetVal[i >> 1] |= (UInt8(v) & 15) << ((i & 1) << 2)
                    default: break
                    }
                }
            }
            try builder.store(inline: bitSetVal)
            try builder.store(inline: bitSetNil)
            return try builder.storeAsLEB(value: UInt64(n))
        default:
            for el in reversed() {
                let opt = (el as? any OptionalType)?.optional as? any ArenaEnum
                if let e = opt { _ = try e.store(with: builder) }
                else {
                    let rawSz = { () -> Int in switch bw { case .two: return 2; case .four: return 4; case .eight: return 8; default: return 1 } }()
                    try builder.store(inline: [UInt8](repeating: 0, count: rawSz))
                }
            }
            for (i, el) in enumerated() {
                let opt = (el as? any OptionalType)?.optional as? any ArenaEnum
                if opt == nil { bitSetNil[i >> 3] |= 1 << (i & 7) }
            }
            try builder.store(inline: bitSetNil)
            return try builder.storeAsLEB(value: UInt64(n))
        }
    }
    private func _storeOptionalGraphStorable(with builder: any ArenaBuilder) throws -> BufferOffset {
        // Optional fixed-width numeric: LEB(N) + bitSetNil (⌈N/8⌉ B) + N slots (LE raw, zeros for nil)
        let _W: Int
        if      Element.self == Optional<UInt8>.self  || Element.self == Optional<Int8>.self  { _W = 1 }
        else if Element.self == Optional<UInt16>.self || Element.self == Optional<Int16>.self { _W = 2 }
        else if Element.self == Optional<UInt32>.self || Element.self == Optional<Int32>.self ||
                Element.self == Optional<Float>.self                                           { _W = 4 }
        else if Element.self == Optional<UInt64>.self || Element.self == Optional<Int64>.self ||
                Element.self == Optional<Double>.self                                          { _W = 8 }
        else    { _W = 0 }
        if _W > 0 {
            for element in reversed() {
                if let s = element as? any ArenaGraphStorable {
                    _ = try s.store(with: builder)
                } else {
                    try builder.store(inline: [UInt8](repeating: 0, count: _W))
                }
            }
            var _bsNil = [UInt8](repeating: 0, count: (count + 7) >> 3)
            for (_i, _e) in enumerated() { if (_e as? any ArenaGraphStorable) == nil { _bsNil[_i >> 3] |= 1 << (_i & 7) } }
            try builder.store(inline: _bsNil)
            return try builder.storeAsLEB(value: UInt64(count))
        }
        // Optional reference array: node refs → signed two's-complement; value refs → plain unsigned. (Spec §4.10)
        let _isNodeRef = Element.self is (any OptionalNodeHandle.Type)
        var widthCode = 0
        let offsets: [BufferOffset?] = try reversed().map { el -> BufferOffset? in
            guard let s = el as? any ArenaGraphStorable else { return nil }
            let off = try s.store(with: builder)
            // In-progress (cyclic back-edge) slot: patched in-place once the target's final
            // makeData position is known, so reserve the maxSize-derived worst-case width now
            // (§05 "Cycle serialization — dummy references"). Matching the single-ref reserve
            // (reserveFieldPointerSize) keeps this byte-identical to Rust/Python/TS/Mojo and
            // avoids a >32 KB buffer overflowing a too-narrow slot on patch.
            if _isNodeRef, case .inProgress = off { widthCode = Swift.max(widthCode, builder.reserveFieldPointerSize.trailingZeroBitCount) }
            return off
        }
        let cur = builder.cursor
        let db = builder as! DataArenaBuilder
        for off in offsets {
            if case .some(.offset(let v)) = off {
                let d = Int64(cur.value) - Int64(v) + 1
                widthCode = Swift.max(widthCode, _isNodeRef ? _signedWidthCode(d) : _offsetWidthCode(UInt64(d)))
            }
        }
        for off in offsets {
            switch off {
            case .some(.offset(let v)):
                let d = Int64(cur.value) - Int64(v) + 1
                if _isNodeRef { _ = try db._storeInt(d, widthCode: widthCode) }
                else          { _ = try db._storeUInt(UInt64(d), widthCode: widthCode) }
            case .some(.inProgress(let nodeId)):
                _ = try db._storeUInt(0, widthCode: widthCode)
                let entryPos = builder.cursor  // cursor AFTER placeholder, matching _storeAt convention
                db.setNodeRefBinding(nodeId, pos: entryPos, arrayCur: cur.value, widthCode: widthCode)
            case .none:
                _ = try db._storeUInt(0, widthCode: widthCode)
            }
        }
        return try builder.storeAsLEB(value: UInt64(count << 2) | UInt64(widthCode))
    }
    private func _storeOptionalUnionArray(with builder: any ArenaBuilder) throws -> BufferOffset {
        var widthCode = 0
        var byteWidth: ByteWidth = .one
        var bitSetNil = [UInt8](repeating: 0, count: (count >> 3) + ((count & 7) > 0 ? 1 : 0))
        let rawApplied: [ArenaAppliedUnionType?] = try reversed().map { el -> ArenaAppliedUnionType? in
            guard let u = el as? any ArenaUnion else { return nil }
            byteWidth = u.byteWidth
            return try u.apply(builder: builder)
        }
        let contentEnd = builder.cursor
        let applied: [UInt64] = rawApplied.map { result -> UInt64 in
            guard let result = result else { return 0 }
            switch result {
            case .value(let v, _, _):
                widthCode = Swift.max(widthCode, _offsetWidthCode(v)); return v
            case .pointer(let p, _):
                let v = contentEnd.value - p.value
                widthCode = Swift.max(widthCode, _offsetWidthCode(v)); return v
            case .bidirPointer(let p, _):
                let v = (contentEnd.value - p.value) << 1
                widthCode = Swift.max(widthCode, _offsetWidthCode(v)); return v
            }
        }
        for v in applied { _ = try (builder as! DataArenaBuilder)._storeUInt(v, widthCode: widthCode) }
        var bitSet = byteWidth.bitSet(forArraySize: count)
        // Full-byte (.one+) typeIds are DEFERRED (not stored in the loop) so the typeId section
        // lands after bitSetNil on the backward buffer — i.e. BEFORE bitSetNil in the output, per
        // §4.9. Storing them inline here would misorder to [bitSetNil][typeIds] (>16-variant bug).
        var fullByteTids = [UInt64]()  // collected in loop (reversed) order
        for (idx, el) in enumerated().reversed() {
            let tid: UInt64 = (el as? any ArenaUnion)?.typeId ?? 0
            if !(el is any ArenaUnion) { bitSetNil[idx >> 3] |= 1 << (idx & 7) }
            switch byteWidth {
            case .eighth:  bitSet[idx >> 3] |= (UInt8(tid) & 1) << (idx & 7)
            case .quarter: bitSet[idx >> 2] |= (UInt8(tid) & 3) << ((idx & 3) << 1)
            case .half:    bitSet[idx >> 1] |= (UInt8(tid) & 15) << ((idx & 1) << 2)
            default:       fullByteTids.append(tid)
            }
        }
        try builder.store(inline: bitSetNil)
        // typeId section (either the sub-byte bitset or the deferred full-byte tids) — always after bitSetNil.
        for tid in fullByteTids { _ = try byteWidth.storeNumber(value: tid, with: builder) }
        if !bitSet.isEmpty { try builder.store(inline: bitSet) }
        return try builder.storeAsLEB(value: UInt64(count << 2) | UInt64(widthCode))
    }
    private func _storeUnionArray(with builder: any ArenaBuilder) throws -> BufferOffset {
        var widthCode = 0
        var byteWidth: ByteWidth = .one
        let rawApplied: [ArenaAppliedUnionType?] = try reversed().map { el -> ArenaAppliedUnionType? in
            guard let u = el as? any ArenaUnion else { return nil }
            byteWidth = u.byteWidth
            return try u.apply(builder: builder)
        }
        let contentEnd = builder.cursor
        let applied: [UInt64] = rawApplied.map { result -> UInt64 in
            guard let result = result else { return 0 }
            switch result {
            case .value(let v, _, _):
                widthCode = Swift.max(widthCode, _offsetWidthCode(v)); return v
            case .pointer(let p, _):
                let v = contentEnd.value - p.value
                widthCode = Swift.max(widthCode, _offsetWidthCode(v)); return v
            case .bidirPointer(let p, _):
                let v = (contentEnd.value - p.value) << 1
                widthCode = Swift.max(widthCode, _offsetWidthCode(v)); return v
            }
        }
        for v in applied { _ = try (builder as! DataArenaBuilder)._storeUInt(v, widthCode: widthCode) }
        var bitSet = byteWidth.bitSet(forArraySize: count)
        for (idx, el) in enumerated().reversed() {
            guard let u = el as? any ArenaUnion else { continue }
            let tid = u.typeId
            switch byteWidth {
            case .eighth:  bitSet[idx >> 3] |= (UInt8(tid) & 1) << (idx & 7)
            case .quarter: bitSet[idx >> 2] |= (UInt8(tid) & 3) << ((idx & 3) << 1)
            case .half:    bitSet[idx >> 1] |= (UInt8(tid) & 15) << ((idx & 1) << 2)
            default:       _ = try byteWidth.storeNumber(value: tid, with: builder)
            }
        }
        if !bitSet.isEmpty { try builder.store(inline: bitSet) }
        return try builder.storeAsLEB(value: UInt64(count << 2) | UInt64(widthCode))
    }
    private func _offsetWidthCode(_ v: UInt64) -> Int {
        if v <= UInt8.max  { return 0 }
        if v <= UInt16.max { return 1 }
        if v <= UInt32.max { return 2 }
        return 3
    }
    // Minimum width whose signed range holds `d` (node-ref array slots, two's-complement §4.5).
    private func _signedWidthCode(_ d: Int64) -> Int {
        if d >= -128 && d <= 127 { return 0 }
        if d >= -32768 && d <= 32767 { return 1 }
        if d >= -2147483648 && d <= 2147483647 { return 2 }
        return 3
    }
}

// ── ArenaGraphRestorable ──────────────────────────────────────────────────────

public enum ArenaRestoreError: Error { case outsideOfBuffer; case invalidEnumValue; case invalidFraming; case missingHeader }

public protocol ArenaGraphRestorable {
    static func restore(from data: Data, at: Int) throws -> Self
    static func restorePacked(from data: Data, at: Int) throws -> Self
    static func packedByteCount(in data: Data, at pos: Int) throws -> Int
}
extension ArenaGraphRestorable {
    public static func packedByteCount(in data: Data, at pos: Int) throws -> Int {
        throw ArenaRestoreError.outsideOfBuffer
    }
}

func restoreLEB(from data: Data, at: Int) throws -> (UInt64, Int) {
    guard at >= 0 else { throw ArenaRestoreError.outsideOfBuffer }
    var pos = at; var result: UInt64 = 0
    while true {
        guard data.count > pos else { throw ArenaRestoreError.outsideOfBuffer }
        let b = data[pos]
        result |= UInt64(b & 0x7F) << ((pos - at) * 7)
        pos += 1
        if b >> 7 == 0 { break }
    }
    return (result, pos - at)
}

extension UInt8: ArenaGraphRestorable {
    public static func restore(from d: Data, at i: Int) throws -> Self {
        guard i >= 0, d.count > i else { throw ArenaRestoreError.outsideOfBuffer }; return d[i]
    }
    public static func restorePacked(from d: Data, at i: Int) throws -> Self { try restore(from: d, at: i) }
    public static func packedByteCount(in d: Data, at i: Int) throws -> Int { 1 }
}
extension UInt16: ArenaGraphRestorable {
    public static func restore(from d: Data, at i: Int) throws -> Self {
        guard i >= 0, d.count > i + 1 else { throw ArenaRestoreError.outsideOfBuffer }
        return d.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: i, as: Self.self) }
    }
    public static func restorePacked(from d: Data, at i: Int) throws -> Self { try UInt16(restoreLEB(from: d, at: i).0) }
    public static func packedByteCount(in d: Data, at i: Int) throws -> Int { try restoreLEB(from: d, at: i).1 }
}
extension UInt32: ArenaGraphRestorable {
    public static func restore(from d: Data, at i: Int) throws -> Self {
        guard i >= 0, d.count > i + 3 else { throw ArenaRestoreError.outsideOfBuffer }
        return d.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: i, as: Self.self) }
    }
    public static func restorePacked(from d: Data, at i: Int) throws -> Self { try UInt32(restoreLEB(from: d, at: i).0) }
    public static func packedByteCount(in d: Data, at i: Int) throws -> Int { try restoreLEB(from: d, at: i).1 }
}
extension UInt64: ArenaGraphRestorable {
    public static func restore(from d: Data, at i: Int) throws -> Self {
        guard i >= 0, d.count > i + 7 else { throw ArenaRestoreError.outsideOfBuffer }
        return d.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: i, as: Self.self) }
    }
    public static func restorePacked(from d: Data, at i: Int) throws -> Self { try restoreLEB(from: d, at: i).0 }
    public static func packedByteCount(in d: Data, at i: Int) throws -> Int { try restoreLEB(from: d, at: i).1 }
}
extension Int8: ArenaGraphRestorable {
    public static func restore(from d: Data, at i: Int) throws -> Self {
        guard i >= 0, d.count > i else { throw ArenaRestoreError.outsideOfBuffer }
        return d.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: i, as: Self.self) }
    }
    public static func restorePacked(from d: Data, at i: Int) throws -> Self { try restore(from: d, at: i) }
    public static func packedByteCount(in d: Data, at i: Int) throws -> Int { 1 }
}
extension Int16: ArenaGraphRestorable {
    public static func restore(from d: Data, at i: Int) throws -> Self {
        guard i >= 0, d.count > i + 1 else { throw ArenaRestoreError.outsideOfBuffer }
        return d.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: i, as: Self.self) }
    }
    public static func restorePacked(from d: Data, at i: Int) throws -> Self { try Int16(restoreLEB(from: d, at: i).0.fromZigZag) }
    public static func packedByteCount(in d: Data, at i: Int) throws -> Int { try restoreLEB(from: d, at: i).1 }
}
extension Int32: ArenaGraphRestorable {
    public static func restore(from d: Data, at i: Int) throws -> Self {
        guard i >= 0, d.count > i + 3 else { throw ArenaRestoreError.outsideOfBuffer }
        return d.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: i, as: Self.self) }
    }
    public static func restorePacked(from d: Data, at i: Int) throws -> Self { try Int32(restoreLEB(from: d, at: i).0.fromZigZag) }
    public static func packedByteCount(in d: Data, at i: Int) throws -> Int { try restoreLEB(from: d, at: i).1 }
}
extension Int64: ArenaGraphRestorable {
    public static func restore(from d: Data, at i: Int) throws -> Self {
        guard i >= 0, d.count > i + 7 else { throw ArenaRestoreError.outsideOfBuffer }
        return d.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: i, as: Self.self) }
    }
    public static func restorePacked(from d: Data, at i: Int) throws -> Self { try restoreLEB(from: d, at: i).0.fromZigZag }
    public static func packedByteCount(in d: Data, at i: Int) throws -> Int { try restoreLEB(from: d, at: i).1 }
}
extension Float: ArenaGraphRestorable {
    public static func restore(from d: Data, at i: Int) throws -> Self {
        guard i >= 0, d.count > i + 3 else { throw ArenaRestoreError.outsideOfBuffer }
        return d.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: i, as: Self.self) }
    }
    // restorePacked decodes the float compression tag+payload written by storePacked.
    // Returns the decoded value; caller must advance cursor by the bytes consumed.
    // Use _decodePackedFloat32(tag:from:at:) for cursor-aware decoding.
    public static func restorePacked(from d: Data, at i: Int) throws -> Self {
        guard i >= 0, d.count > i else { throw ArenaRestoreError.outsideOfBuffer }
        let (v, _) = try _decodePackedFloat32(from: d, at: i)
        return v
    }
    public static func packedByteCount(in d: Data, at i: Int) throws -> Int { try _decodePackedFloat32(from: d, at: i).1 }
}
extension Double: ArenaGraphRestorable {
    public static func restore(from d: Data, at i: Int) throws -> Self {
        guard i >= 0, d.count > i + 7 else { throw ArenaRestoreError.outsideOfBuffer }
        return d.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: i, as: Self.self) }
    }
    public static func restorePacked(from d: Data, at i: Int) throws -> Self {
        guard i >= 0, d.count > i else { throw ArenaRestoreError.outsideOfBuffer }
        let (v, _) = try _decodePackedFloat64(from: d, at: i)
        return v
    }
    public static func packedByteCount(in d: Data, at i: Int) throws -> Int { try _decodePackedFloat64(from: d, at: i).1 }
}
extension Bool: ArenaGraphRestorable {
    public static func restore(from d: Data, at i: Int) throws -> Bool {
        guard i >= 0, d.count > i else { throw ArenaRestoreError.outsideOfBuffer }; return d[i] != 0
    }
    public static func restorePacked(from d: Data, at i: Int) throws -> Bool { try restore(from: d, at: i) }
    public static func packedByteCount(in d: Data, at i: Int) throws -> Int { 1 }
}
extension String: ArenaGraphRestorable {
    public static func restore(from d: Data, at i: Int) throws -> Self {
        let (count, bytes) = try restoreLEB(from: d, at: i)
        guard d.count >= i + bytes + Int(count) else { throw ArenaRestoreError.outsideOfBuffer }
        return _dagrUTF8(d[(i + bytes)..<(i + bytes + Int(count))])
    }
    public static func restorePacked(from d: Data, at i: Int) throws -> Self { try restore(from: d, at: i) }
    public static func packedByteCount(in d: Data, at i: Int) throws -> Int {
        let (n, nB) = try restoreLEB(from: d, at: i); return nB + Int(n)
    }
}
extension Data: ArenaGraphRestorable {
    public static func restore(from d: Data, at i: Int) throws -> Self {
        let (count, bytes) = try restoreLEB(from: d, at: i)
        guard d.count >= i + bytes + Int(count) else { throw ArenaRestoreError.outsideOfBuffer }
        return d[(i + bytes)..<(i + bytes + Int(count))]
    }
    public static func restorePacked(from d: Data, at i: Int) throws -> Self { try restore(from: d, at: i) }
    public static func packedByteCount(in d: Data, at i: Int) throws -> Int {
        let (n, nB) = try restoreLEB(from: d, at: i); return nB + Int(n)
    }
}
extension Optional: ArenaGraphRestorable where Wrapped: ArenaGraphRestorable {
    public static func restore(from data: Data, at pos: Int) throws -> Self {
        .some(try Wrapped.restore(from: data, at: pos))
    }
    public static func restorePacked(from data: Data, at pos: Int) throws -> Self {
        .some(try Wrapped.restorePacked(from: data, at: pos))
    }
    public static func packedByteCount(in data: Data, at pos: Int) throws -> Int {
        try Wrapped.packedByteCount(in: data, at: pos)
    }
}
extension Array: ArenaGraphRestorable where Element: ArenaGraphRestorable {
    // Restore from the appropriate format depending on element type.
    // Fixed-width numeric types use inline format: [LEB(count)] [elem[0]..elem[N-1]] (LE raw bytes).
    // Optional fixed-width numeric: [LEB(N)] [bitSetNil] [N slots, zeros for nil].
    // Everything else uses the pointer-table format: [LEB((N<<2)|wc)] [ptr table] [elem data].
    public static func restore(from data: Data, at pos: Int) throws -> Self {
        // Required fixed-width numerics → inline
        if Element.self == UInt8.self  || Element.self == Int8.self  ||
           Element.self == UInt16.self || Element.self == Int16.self ||
           Element.self == UInt32.self || Element.self == Int32.self ||
           Element.self == UInt64.self || Element.self == Int64.self ||
           Element.self == Float.self  || Element.self == Double.self {
            let (countU64, cLen) = try restoreLEB(from: data, at: pos)
            let count = Int(countU64); let W = MemoryLayout<Element>.size
            let base = pos + cLen
            var result = [Element](); result.reserveCapacity(count)
            for i in 0..<count { result.append(try Element.restore(from: data, at: base + i * W)) }
            return result
        }
        // Optional fixed-width numerics → inline with nil bitset
        let _W2: Int
        if      Element.self == Optional<UInt8>.self  || Element.self == Optional<Int8>.self  { _W2 = 1 }
        else if Element.self == Optional<UInt16>.self || Element.self == Optional<Int16>.self { _W2 = 2 }
        else if Element.self == Optional<UInt32>.self || Element.self == Optional<Int32>.self ||
                Element.self == Optional<Float>.self                                           { _W2 = 4 }
        else if Element.self == Optional<UInt64>.self || Element.self == Optional<Int64>.self ||
                Element.self == Optional<Double>.self                                          { _W2 = 8 }
        else    { _W2 = 0 }
        if _W2 > 0 {
            let (countU64, cLen) = try restoreLEB(from: data, at: pos)
            let count = Int(countU64)
            let bsStart = pos + cLen; let bsLen = (count + 7) >> 3
            let base = bsStart + bsLen
            let nilEl = (Element.self as? any ExpressibleByNilLiteral.Type)?.init(nilLiteral: ()) as? Element
            var result = [Element](); result.reserveCapacity(count)
            for i in 0..<count {
                let isNil = bsStart + (i >> 3) < data.count && (data[bsStart + (i >> 3)] >> UInt8(i & 7)) & 1 != 0
                if isNil { if let n = nilEl { result.append(n) } }
                else { result.append(try Element.restore(from: data, at: base + i * _W2)) }
            }
            return result
        }
        // Pointer-table format: [LEB((N<<2)|wc)] [ptr table] [elem data]
        // ptr[i] == 0 signals a nil element (optional arrays only).
        let (hdr, hLen) = try restoreLEB(from: data, at: pos)
        let count = Int(hdr >> 2); let wc = Int(hdr & 3)
        let es = [1, 2, 4, 8][wc]
        let tableBase = pos + hLen
        let base = tableBase + count * es
        var result = [Element](); result.reserveCapacity(count)
        for i in 0..<count {
            let ro = try readRelOffset(from: data, at: tableBase + i * es, size: es)
            if ro > 0 {
                result.append(try Element.restore(from: data, at: base + Int(ro) - 1))
            } else if let nilEl = (Element.self as? any ExpressibleByNilLiteral.Type)?.init(nilLiteral: ()) as? Element {
                result.append(nilEl)
            }
        }
        return result
    }
    // Restore from packed format:
    //   Non-optional (§5.6): [LEB(totalSize)] [LEB(count)] [elem[0]] ... [elem[N-1]]
    //   Optional     (§5.7): [LEB(totalSize)] [LEB(count)] [bitSetNil] [non-nil elems in order]
    public static func restorePacked(from data: Data, at pos: Int) throws -> Self {
        let (_, tsLen) = try restoreLEB(from: data, at: pos)
        let (countU64, cLen) = try restoreLEB(from: data, at: pos + tsLen)
        let count = Int(countU64)
        var result = [Element](); result.reserveCapacity(count)
        if Element.self is (any OptionalType.Type) {
            let bsCount = (count + 7) >> 3
            let bsBase = pos + tsLen + cLen
            var cursor = bsBase + bsCount
            for i in 0..<count {
                if bsBase + (i >> 3) < data.count, (data[bsBase + (i >> 3)] >> UInt8(i & 7)) & 1 != 0 {
                    if let nilEl = (Element.self as? any ExpressibleByNilLiteral.Type)?.init(nilLiteral: ()) as? Element {
                        result.append(nilEl)
                    }
                } else {
                    result.append(try Element.restorePacked(from: data, at: cursor))
                    cursor += try Element.packedByteCount(in: data, at: cursor)
                }
            }
        } else {
            var cursor = pos + tsLen + cLen
            for _ in 0..<count {
                result.append(try Element.restorePacked(from: data, at: cursor))
                cursor += try Element.packedByteCount(in: data, at: cursor)
            }
        }
        return result
    }
    public static func packedByteCount(in data: Data, at pos: Int) throws -> Int {
        let (n, nB) = try restoreLEB(from: data, at: pos); return nB + Int(n)
    }
}

// ── V62 / relative-offset read helpers ───────────────────────────────────────

func readV62(from data: Data, at pos: Int) throws -> (UInt64, Int) {
    guard pos >= 0, data.count > pos else { throw ArenaRestoreError.outsideOfBuffer }
    let code = data[pos] & 3
    switch code {
    case 0: return (UInt64(data[pos]) >> 2, 1)
    case 1:
        let v = try UInt16.restore(from: data, at: pos)
        return (UInt64(v) >> 2, 2)
    case 2:
        let v = try UInt32.restore(from: data, at: pos)
        return (UInt64(v) >> 2, 4)
    default:
        let v = try UInt64.restore(from: data, at: pos)
        return (v >> 2, 8)
    }
}

func readZigZagV62(from data: Data, at pos: Int) throws -> (Int, Int) {
    let (raw, bytes) = try readV62(from: data, at: pos)
    return (Int(raw.fromZigZag), bytes)
}

func readRelOffset(from data: Data, at pos: Int, size: Int) throws -> UInt64 {
    switch size {
    case 1: return UInt64(try UInt8.restore(from: data, at: pos))
    case 2: return UInt64(try UInt16.restore(from: data, at: pos))
    case 4: return UInt64(try UInt32.restore(from: data, at: pos))
    default: return try UInt64.restore(from: data, at: pos)
    }
}

// Node-ref array slot: native signed (two's-complement) load, no ZigZag decode (§4.5). 0 = nil.
func readSignedRelOffset(from data: Data, at pos: Int, size: Int) throws -> Int64 {
    switch size {
    case 1: return Int64(try Int8.restore(from: data, at: pos))
    case 2: return Int64(try Int16.restore(from: data, at: pos))
    case 4: return Int64(try Int32.restore(from: data, at: pos))
    default: return try Int64.restore(from: data, at: pos)
    }
}

func lebLength(_ value: UInt64) -> Int {
    if value == 0 { return 1 }
    let bits = 64 - value.leadingZeroBitCount
    return (bits / 7) + (bits % 7 == 0 ? 0 : 1)
}

// ── Float16 helpers ───────────────────────────────────────────────────────────

func _f16BitsToF32(_ bits16: UInt16) -> Float {
#if canImport(Darwin) && !DAGR_FORCE_MANUAL_F16
    if #available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *) {
        return Float(Float16(bitPattern: bits16))   // native (Apple, OS new enough)
    }
#endif
    // Manual half → single (Float16 unavailable: Linux, or older Apple OS). Bit-identical.
    let sign: UInt32 = UInt32(bits16 >> 15) << 31
    let exp16 = Int((bits16 >> 10) & 0x1F)
    let mant16 = UInt32(bits16 & 0x3FF)
    let bits32: UInt32
    if exp16 == 0 {
        if mant16 == 0 { bits32 = sign }
        else { // subnormal float16 → normalised float32
            var m = mant16; var e = -14 + 127
            while m & 0x400 == 0 { m <<= 1; e -= 1 }
            bits32 = sign | (UInt32(e) << 23) | ((m & 0x3FF) << 13)
        }
    } else if exp16 == 31 { bits32 = sign | 0x7F800000 | (mant16 << 13)
    } else                 { bits32 = sign | (UInt32(exp16 + 112) << 23) | (mant16 << 13) }
    return Float(bitPattern: bits32)
}

func _f32ToF16Bits(_ v: Float) -> UInt16? {
    let bits = v.bitPattern
    let sign = bits >> 31; let exp32 = Int((bits >> 23) & 0xFF); let mant32 = bits & 0x7FFFFF
    if exp32 == 0xFF { return nil }   // nan/inf handled separately
    if exp32 == 0 { return mant32 == 0 ? UInt16(sign << 15) : nil }  // ±zero or subnormal
    let exp16 = exp32 - 112
    guard exp16 >= 1 && exp16 <= 30 else { return nil }  // out of float16 range
    guard mant32 & 0x1FFF == 0 else { return nil }        // precision loss
    return UInt16(sign << 15) | UInt16(exp16 << 10) | UInt16(mant32 >> 13)
}

// ── BFloat16 helpers ──────────────────────────────────────────────────────────

func _bf16BitsToF32(_ bits: UInt16) -> Float {
    Float(bitPattern: UInt32(bits) << 16)
}

func _f32ToBf16Bits(_ v: Float) -> UInt16 {
    let bits = v.bitPattern
    let lsb: UInt32 = (bits >> 16) & 1
    return UInt16((bits + 0x7FFF + lsb) >> 16)
}

// Proper IEEE-754 round-to-nearest-even (subnormals + mantissa carry), used for
// `>> raw` f16 storage. Native Float16 on Apple; a bit-identical manual conversion
// elsewhere (Linux). NaN is normalised to 0x7E00 up front so both paths agree.
func _f32ToF16BitsLossy(_ v: Float) -> UInt16 {
    if v.isNaN { return 0x7E00 }
#if canImport(Darwin) && !DAGR_FORCE_MANUAL_F16
    if #available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *) {
        return Float16(v).bitPattern            // native (Apple, OS new enough)
    }
#endif
    // Manual (Linux, or older Apple OS) — bit-identical to native.
    let bits = v.bitPattern
    let sign = UInt16(truncatingIfNeeded: (bits >> 16) & 0x8000)
    let exp32 = Int32((bits >> 23) & 0xFF)
    let mant32 = bits & 0x7FFFFF
    if exp32 == 0xFF { return sign | 0x7C00 }                        // infinity
    if (bits & 0x7FFFFFFF) == 0 { return sign }                      // +/-0
    let exp16 = exp32 - 127 + 15
    if exp16 >= 0x1F { return sign | 0x7C00 }
    if exp16 <= 0 {
        if exp16 < -10 { return sign }
        let m = mant32 | 0x800000
        let shift = UInt32(14 - exp16)
        let low = m & ((UInt32(1) << shift) - 1)
        let half = UInt32(1) << (shift - 1)
        var r = m >> shift
        if low > half || (low == half && (r & 1) == 1) { r += 1 }
        return sign | UInt16(truncatingIfNeeded: r)
    }
    var half16 = (UInt32(exp16) << 10) | (mant32 >> 13)
    let round = (mant32 >> 12) & 1
    let sticky = (mant32 & 0xFFF) != 0
    if round == 1 && (sticky || (half16 & 1) == 1) { half16 += 1 }
    return sign | UInt16(truncatingIfNeeded: half16)
}

// ── Raw f16/bf16 store helpers (2-byte wire format for frozen/vtable nodes) ────

func _storeRawBf16(_ v: Float, with b: any ArenaBuilder) throws -> BufferOffset {
    var bits = _f32ToBf16Bits(v)
    return try withUnsafeBytes(of: &bits) { try b.store(rawPointer: $0.baseAddress!, size: 2) }
}

func _storeRawF16(_ v: Float, with b: any ArenaBuilder) throws -> BufferOffset {
    var bits = _f32ToF16BitsLossy(v)
    return try withUnsafeBytes(of: &bits) { try b.store(rawPointer: $0.baseAddress!, size: 2) }
}

// ── Packed f16/bf16 store helpers ─────────────────────────────────────────────

func _storePackedF16(_ v: Float, with b: any ArenaBuilder) throws -> PackedStoreResult {
    if v.isZero     { _ = try b.store(number: v.sign == .minus ? UInt8(0x01) : UInt8(0x00)); return .floatEncoded }
    if v.isNaN      { _ = try b.store(number: UInt8(0x04)); return .floatEncoded }
    if v.isInfinite { _ = try b.store(number: v.sign == .minus ? UInt8(0x03) : UInt8(0x02)); return .floatEncoded }
    var bits = _f32ToF16BitsLossy(v)
    _ = try withUnsafeBytes(of: &bits) { try b.store(rawPointer: $0.baseAddress!, size: 2) }
    return .raw(2)
}

func _storePackedBf16(_ v: Float, with b: any ArenaBuilder) throws -> PackedStoreResult {
    if v.isZero     { _ = try b.store(number: v.sign == .minus ? UInt8(0x01) : UInt8(0x00)); return .floatEncoded }
    if v.isNaN      { _ = try b.store(number: UInt8(0x04)); return .floatEncoded }
    if v.isInfinite { _ = try b.store(number: v.sign == .minus ? UInt8(0x03) : UInt8(0x02)); return .floatEncoded }
    var bits = _f32ToBf16Bits(v)
    _ = try withUnsafeBytes(of: &bits) { try b.store(rawPointer: $0.baseAddress!, size: 2) }
    return .raw(2)
}

// ── Packed f16/bf16 decode helpers ────────────────────────────────────────────
// Only called for the encoded (even-tag / bitset-0) path — special values only.

func _decodePackedF16(from data: Data, at cursor: Int) throws -> (Float, Int) {
    guard cursor >= 0, cursor < data.count else { throw ArenaRestoreError.outsideOfBuffer }
    switch data[cursor] {
    case 0x00: return ( 0.0,            1)
    case 0x01: return (-0.0,            1)
    case 0x02: return ( Float.infinity, 1)
    case 0x03: return (-Float.infinity, 1)
    case 0x04: return ( Float.nan,      1)
    default:   return ( 0.0,            1)
    }
}

// ── Packed float decode ───────────────────────────────────────────────────────

func _decodePackedFloat32(from data: Data, at cursor: Int) throws -> (Float, Int) {
    guard cursor >= 0, cursor < data.count else { throw ArenaRestoreError.outsideOfBuffer }
    let tag = data[cursor]
    switch tag {
    case 0x00: return ( 0.0,                                        1)
    case 0x01: return (-0.0,                                        1)
    case 0x02: return ( Float.infinity,                             1)
    case 0x03: return (-Float.infinity,                             1)
    case 0x04: return ( Float.nan,                                  1)
    case 0x05:
        let (zz, lebB) = try restoreLEB(from: data, at: cursor + 1)
        return (Float(zz.fromZigZag), 1 + lebB)
    case 0x06:
        let bits16 = try UInt16.restore(from: data, at: cursor + 1)
        return (_f16BitsToF32(bits16), 3)
    case 0x07:
        return (try Float.restore(from: data, at: cursor + 1), 5)
    default: return (0.0, 1)
    }
}

func _decodePackedFloat32(tag: UInt8, from data: Data, at payloadStart: Int) throws -> Float {
    switch tag {
    case 0x00: return  0.0
    case 0x01: return -0.0
    case 0x02: return  Float.infinity
    case 0x03: return -Float.infinity
    case 0x04: return  Float.nan
    case 0x05: let (zz, _) = try restoreLEB(from: data, at: payloadStart); return Float(zz.fromZigZag)
    case 0x06: return _f16BitsToF32(try UInt16.restore(from: data, at: payloadStart))
    case 0x07: return try Float.restore(from: data, at: payloadStart)
    default:   return 0.0
    }
}

func _decodePackedFloat64(from data: Data, at cursor: Int) throws -> (Double, Int) {
    guard cursor >= 0, cursor < data.count else { throw ArenaRestoreError.outsideOfBuffer }
    let tag = data[cursor]
    switch tag {
    case 0x00: return ( 0.0,                                        1)
    case 0x01: return (-0.0,                                        1)
    case 0x02: return ( Double.infinity,                            1)
    case 0x03: return (-Double.infinity,                            1)
    case 0x04: return ( Double.nan,                                 1)
    case 0x05:
        let (zz, lebB) = try restoreLEB(from: data, at: cursor + 1)
        return (Double(zz.fromZigZag), 1 + lebB)
    case 0x06:
        let bits16 = try UInt16.restore(from: data, at: cursor + 1)
        return (Double(_f16BitsToF32(bits16)), 3)
    case 0x07:
        let f32 = try Float.restore(from: data, at: cursor + 1)
        return (Double(f32), 5)
    case 0x08:
        return (try Double.restore(from: data, at: cursor + 1), 9)
    default: return (0.0, 1)
    }
}

func _decodePackedFloat64(tag: UInt8, from data: Data, at payloadStart: Int) throws -> Double {
    switch tag {
    case 0x00: return  0.0
    case 0x01: return -0.0
    case 0x02: return  Double.infinity
    case 0x03: return -Double.infinity
    case 0x04: return  Double.nan
    case 0x05: let (zz, _) = try restoreLEB(from: data, at: payloadStart); return Double(zz.fromZigZag)
    case 0x06: return Double(_f16BitsToF32(try UInt16.restore(from: data, at: payloadStart)))
    case 0x07: return Double(try Float.restore(from: data, at: payloadStart))
    case 0x08: return try Double.restore(from: data, at: payloadStart)
    default:   return 0.0
    }
}

// ── Numeric array restore helpers (inline format) ────────────────────────────
// Format: [LEB(count)] [elem[0]..elem[N-1]] (LE raw bytes, W = MemoryLayout<T>.size each).

func _restoreNumericArray<T: ArenaGraphRestorable>(type: T.Type, from data: Data, at pos: Int) throws -> [T] {
    let (countU64, cLen) = try restoreLEB(from: data, at: pos)
    let count = Int(countU64); let W = MemoryLayout<T>.size
    let base = pos + cLen
    var arr = [T](); arr.reserveCapacity(count)
    for i in 0..<count { arr.append(try T.restore(from: data, at: base + i * W)) }
    return arr
}

// Optional inline format: [LEB(N)] [bitSetNil (⌈N/8⌉ B)] [N slots (LE raw, zeros for nil)].
func _restoreNumericArrayOpt<T: ArenaGraphRestorable>(type: T.Type, from data: Data, at pos: Int) throws -> [T?] {
    let (countU64, cLen) = try restoreLEB(from: data, at: pos)
    let count = Int(countU64); let W = MemoryLayout<T>.size
    let bsStart = pos + cLen; let bsLen = (count + 7) >> 3
    let base = bsStart + bsLen
    var arr = [T?](); arr.reserveCapacity(count)
    for i in 0..<count {
        let isNil = bsStart + (i >> 3) < data.count && (data[bsStart + (i >> 3)] >> UInt8(i & 7)) & 1 != 0
        if isNil { arr.append(nil) } else { arr.append(try T.restore(from: data, at: base + i * W)) }
    }
    return arr
}

// ── Primitive-array restore helper (pointer-table format, used for enum arrays) ──

func _restorePrimArray<T: ArenaGraphRestorable>(type: T.Type, from data: Data, at pos: Int) throws -> [T] {
    let (hdr, hLen) = try restoreLEB(from: data, at: pos)
    let count = Int(hdr >> 2); let wc = Int(hdr & 3)
    let es = [1,2,4,8][wc]
    let base = pos + hLen + count * es
    var arr = [T]()
    for i in 0..<count {
        let ep = pos + hLen + i * es
        let ro = try readRelOffset(from: data, at: ep, size: es)
        if ro > 0 { arr.append(try T.restore(from: data, at: base + Int(ro) - 1)) }
    }
    return arr
}

func _restorePrimArrayOpt<T: ArenaGraphRestorable>(type: T.Type, from data: Data, at pos: Int) throws -> [T?] {
    let (hdr, hLen) = try restoreLEB(from: data, at: pos)
    let count = Int(hdr >> 2); let wc = Int(hdr & 3)
    let es = [1,2,4,8][wc]
    let base = pos + hLen + count * es
    var arr = [T?]()
    for i in 0..<count {
        let ep = pos + hLen + i * es
        let ro = try readRelOffset(from: data, at: ep, size: es)
        if ro == 0 { arr.append(nil) } else { arr.append(try T.restore(from: data, at: base + Int(ro) - 1)) }
    }
    return arr
}

func _restoreBoolArray(from data: Data, at pos: Int) throws -> [Bool] {
    let (count, cB) = try restoreLEB(from: data, at: pos)
    let n = Int(count)
    var result = [Bool]()
    result.reserveCapacity(n)
    for i in 0..<n {
        let off = pos + cB + (i >> 3)
        result.append(off < data.count && (data[off] >> (i & 7)) & 1 != 0)
    }
    return result
}
func _restoreBoolArrayOpt(from data: Data, at pos: Int) throws -> [Bool?] {
    let (count, cB) = try restoreLEB(from: data, at: pos)
    let n = Int(count)
    let bsNilStart = pos + cB
    let bsNilByteCount = (n + 7) >> 3
    let bsValStart = bsNilStart + bsNilByteCount
    var result = [Bool?]()
    result.reserveCapacity(n)
    for i in 0..<n {
        let nilOff = bsNilStart + (i >> 3)
        if nilOff < data.count && (data[nilOff] >> (i & 7)) & 1 != 0 {
            result.append(nil)
        } else {
            let valOff = bsValStart + (i >> 3)
            result.append(valOff < data.count && (data[valOff] >> (i & 7)) & 1 != 0)
        }
    }
    return result
}

// ── Sub-byte enum array restore helpers ──────────────────────────────────────

func _restoreEnumBitsetArray(from data: Data, at pos: Int, bitsPerElem: Int) throws -> [UInt8] {
    let (countU64, cLen) = try restoreLEB(from: data, at: pos)
    let count = Int(countU64)
    let bsStart = pos + cLen
    var result = [UInt8](); result.reserveCapacity(count)
    switch bitsPerElem {
    case 1:
        for i in 0..<count {
            let off = bsStart + (i >> 3)
            result.append(off < data.count ? (data[off] >> (i & 7)) & 1 : 0)
        }
    case 2:
        for i in 0..<count {
            let off = bsStart + (i >> 2)
            result.append(off < data.count ? (data[off] >> ((i & 3) << 1)) & 3 : 0)
        }
    case 4:
        for i in 0..<count {
            let off = bsStart + (i >> 1)
            result.append(off < data.count ? (data[off] >> ((i & 1) << 2)) & 15 : 0)
        }
    default:
        throw ArenaRestoreError.invalidEnumValue
    }
    return result
}

func _restoreEnumBitsetArrayOpt(from data: Data, at pos: Int, bitsPerElem: Int) throws -> [UInt8?] {
    let (countU64, cLen) = try restoreLEB(from: data, at: pos)
    let count = Int(countU64)
    let bsnStart = pos + cLen; let bsnLen = (count + 7) >> 3
    let bsvStart = bsnStart + bsnLen
    var result = [UInt8?](); result.reserveCapacity(count)
    for i in 0..<count {
        let isNil = bsnStart + (i >> 3) < data.count && (data[bsnStart + (i >> 3)] >> UInt8(i & 7)) & 1 != 0
        if isNil { result.append(nil); continue }
        let v: UInt8
        switch bitsPerElem {
        case 1: let off = bsvStart + (i >> 3); v = off < data.count ? (data[off] >> UInt8(i & 7)) & 1 : 0
        case 2: let off = bsvStart + (i >> 2); v = off < data.count ? (data[off] >> UInt8((i & 3) << 1)) & 3 : 0
        case 4: let off = bsvStart + (i >> 1); v = off < data.count ? (data[off] >> UInt8((i & 1) << 2)) & 15 : 0
        default: throw ArenaRestoreError.invalidEnumValue
        }
        result.append(v)
    }
    return result
}

func _restoreEnumBitsetArrayOptCompacted(from data: Data, at pos: Int, bitsPerElem: Int) throws -> [UInt8?] {
    let (countU64, cLen) = try restoreLEB(from: data, at: pos)
    let count = Int(countU64)
    let bsnStart = pos + cLen; let bsnLen = (count + 7) >> 3
    let bsvStart = bsnStart + bsnLen
    var result = [UInt8?](); result.reserveCapacity(count)
    var ci = 0
    for i in 0..<count {
        let isNil = bsnStart + (i >> 3) < data.count && (data[bsnStart + (i >> 3)] >> UInt8(i & 7)) & 1 != 0
        if isNil { result.append(nil); continue }
        let v: UInt8
        switch bitsPerElem {
        case 1: let off = bsvStart + (ci >> 3); v = off < data.count ? (data[off] >> UInt8(ci & 7)) & 1 : 0
        case 2: let off = bsvStart + (ci >> 2); v = off < data.count ? (data[off] >> UInt8((ci & 3) << 1)) & 3 : 0
        case 4: let off = bsvStart + (ci >> 1); v = off < data.count ? (data[off] >> UInt8((ci & 1) << 2)) & 15 : 0
        default: throw ArenaRestoreError.invalidEnumValue
        }
        result.append(v)
        ci += 1
    }
    return result
}

// ── VTable restore helpers ────────────────────────────────────────────────────

func restoreRTypeVTable(from data: Data, start: Int) throws -> [UInt16?] {
    let (offsetValue, b1) = try restoreLEB(from: data, at: start)
    // Even offset = dedup forward-ref (off-by-one: add b1); odd = fresh vtable.
    let adj = offsetValue & 1 == 0 ? b1 : 0
    let vtStart = start + Int(offsetValue.fromZigZag) + adj
    let (vtSize, b2) = try restoreLEB(from: data, at: vtStart)
    let count = vtSize >> 1
    var cursor = vtStart + b2
    var result = [UInt16?]()
    if vtSize & 1 == 0 {
        for _ in 0..<count {
            let v = try UInt8.restore(from: data, at: cursor)
            result.append(v == 0 ? nil : UInt16(v) - 1 + UInt16(b1))
            cursor += 1
        }
    } else {
        for _ in 0..<count {
            let v = try UInt16.restore(from: data, at: cursor)
            result.append(v == 0 ? nil : v - 1 + UInt16(b1))
            cursor += 2
        }
    }
    return result
}

// ── NodeKey for cycle-aware description ──────────────────────────────────

struct NodeKey: Hashable {
    let arena: ObjectIdentifier
    let typeId: Int
    let index: Int
}

// ── ArenaPair for cycle-aware equality ───────────────────────────────────

struct ArenaPair: Hashable {
    let leftArena: ObjectIdentifier
    let leftTypeId: Int
    let leftIndex: Int
    let rightArena: ObjectIdentifier
    let rightTypeId: Int
    let rightIndex: Int
}

// ── Packed-format array accessors (zero-allocation lazy access) ──────────────
// Each struct stores the buffer + a start position (past the count LEB).
// count is read once on init; subscript scans to the requested index.
// Pass pos = -1 to create an empty/absent accessor.

public struct PackedBoolArrayAccessor {
    private let _data: Foundation.Data
    private let _start: Int  // past count LEB; -1 = absent
    public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) { count = Int(c); _start = pos + cB }
        else { count = 0; _start = -1 }
    }
    public subscript(_ idx: Int) -> Bool {
        guard _start >= 0, idx >= 0, idx < count else { return false }
        let off = _start + (idx >> 3)
        guard off < _data.count else { return false }
        return (_data[off] >> (idx & 7)) & 1 != 0
    }
}

public struct PackedU8ArrayAccessor {
    private let _data: Foundation.Data
    private let _start: Int
    public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) { count = Int(c); _start = pos + cB }
        else { count = 0; _start = -1 }
    }
    public subscript(_ idx: Int) -> UInt8 {
        guard _start >= 0, idx >= 0, idx < count else { return 0 }
        return _data[_start + idx]
    }
}

public struct PackedI8ArrayAccessor {
    private let _data: Foundation.Data
    private let _start: Int
    public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) { count = Int(c); _start = pos + cB }
        else { count = 0; _start = -1 }
    }
    public subscript(_ idx: Int) -> Int8 {
        guard _start >= 0, idx >= 0, idx < count else { return 0 }
        return Int8(bitPattern: _data[_start + idx])
    }
}

// Float arrays fold a 2-bit mode into the count (§5.2): count = hdr >> 2, mode = hdr & 3
// (0 = packed self-describing, 1 = raw native-LE). Raw ⇒ O(1) random access.
public struct PackedF32ArrayAccessor {
    private let _data: Foundation.Data
    private let _start: Int
    private let _mode: Int
    public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) { count = Int(c) >> 2; _mode = Int(c) & 3; _start = pos + cB }
        else { count = 0; _mode = 0; _start = -1 }
    }
    public subscript(_ idx: Int) -> Float {
        guard _start >= 0, idx >= 0, idx < count else { return 0 }
        if _mode == 1 {  // raw: native LE 4 bytes → O(1)
            return Float(bitPattern: UInt32(truncatingIfNeeded: _readRawLE(from: _data, at: _start + idx * 4, width: 4) ?? 0))
        }
        var p = _start
        for i in 0..<count {
            guard let (v, vB) = try? _decodePackedFloat32(from: _data, at: p) else { return 0 }
            if i == idx { return v }
            p += vB
        }
        return 0
    }
}

public struct PackedF64ArrayAccessor {
    private let _data: Foundation.Data
    private let _start: Int
    private let _mode: Int
    public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) { count = Int(c) >> 2; _mode = Int(c) & 3; _start = pos + cB }
        else { count = 0; _mode = 0; _start = -1 }
    }
    public subscript(_ idx: Int) -> Double {
        guard _start >= 0, idx >= 0, idx < count else { return 0 }
        if _mode == 1 {  // raw: native LE 8 bytes → O(1)
            return Double(bitPattern: _readRawLE(from: _data, at: _start + idx * 8, width: 8) ?? 0)
        }
        var p = _start
        for i in 0..<count {
            guard let (v, vB) = try? _decodePackedFloat64(from: _data, at: p) else { return 0 }
            if i == idx { return v }
            p += vB
        }
        return 0
    }
}

public struct PackedF16ArrayAccessor {
    private let _data: Foundation.Data
    private let _start: Int
    public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) {
            count = Int(c); _start = pos + cB
        } else { count = 0; _start = -1 }
    }
    public subscript(_ idx: Int) -> Float {
        guard _start >= 0, idx >= 0, idx < count else { return 0 }
        let encBytes = (count + 7) / 8
        var p = _start + encBytes
        for i in 0..<count {
            let isRaw = _start + i/8 < _data.count && (_data[_start + i/8] >> (i%8)) & 1 != 0
            if i == idx {
                if isRaw {
                    guard p + 1 < _data.count else { return 0 }
                    let bits = UInt16(_data[p]) | (UInt16(_data[p+1]) << 8)
                    return _f16BitsToF32(bits)
                } else {
                    return (try? _decodePackedF16(from: _data, at: p))?.0 ?? 0
                }
            }
            p += isRaw ? 2 : 1
        }
        return 0
    }
}

public struct PackedBf16ArrayAccessor {
    private let _data: Foundation.Data
    private let _start: Int
    public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) {
            count = Int(c); _start = pos + cB
        } else { count = 0; _start = -1 }
    }
    public subscript(_ idx: Int) -> Float {
        guard _start >= 0, idx >= 0, idx < count else { return 0 }
        let encBytes = (count + 7) / 8
        var p = _start + encBytes
        for i in 0..<count {
            let isRaw = _start + i/8 < _data.count && (_data[_start + i/8] >> (i%8)) & 1 != 0
            if i == idx {
                if isRaw {
                    guard p + 1 < _data.count else { return 0 }
                    let bits = UInt16(_data[p]) | (UInt16(_data[p+1]) << 8)
                    return _bf16BitsToF32(bits)
                } else {
                    return (try? _decodePackedF16(from: _data, at: p))?.0 ?? 0
                }
            }
            p += isRaw ? 2 : 1
        }
        return 0
    }
}

public struct PackedUtf8ArrayAccessor {
    private let _data: Foundation.Data
    private let _start: Int
    public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) { count = Int(c); _start = pos + cB }
        else { count = 0; _start = -1 }
    }
    // Plain (required-element) array: elements are always present → non-optional String.
    // Out-of-range / malformed returns "" (mirrors the numeric packed accessors returning 0);
    // the Sequence iterator only visits valid 0..<count indices.
    public subscript(_ idx: Int) -> String {
        guard _start >= 0, idx >= 0, idx < count else { return "" }
        var p = _start
        for i in 0..<count {
            guard let (len, lenB) = try? restoreLEB(from: _data, at: p) else { return "" }
            if i == idx { return _dagrUTF8(_data[(p + lenB)..<(p + lenB + Int(len))]) }
            p += lenB + Int(len)
        }
        return ""
    }
}

public struct PackedDataArrayAccessor {
    private let _data: Foundation.Data
    private let _start: Int
    public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) { count = Int(c); _start = pos + cB }
        else { count = 0; _start = -1 }
    }
    // Plain (required-element) array: elements are always present → non-optional Data.
    public subscript(_ idx: Int) -> Foundation.Data {
        guard _start >= 0, idx >= 0, idx < count else { return Foundation.Data() }
        var p = _start
        for i in 0..<count {
            guard let (len, lenB) = try? restoreLEB(from: _data, at: p) else { return Foundation.Data() }
            if i == idx { return Foundation.Data(_data[(p + lenB)..<(p + lenB + Int(len))]) }
            p += lenB + Int(len)
        }
        return Foundation.Data()
    }
}

// Packed integer arrays (u16/i16/u32/i32/u64/i64). The header + encoding-bitset layout and the
// element walk are centralized in the helpers below so every accessor (and the eager restore) shares
// one implementation. `headerAt` is the position of the count LEB. rawWidth = element byte width.
// The 2-bit encoding-tag optimization (§5.1) plugs into exactly these helpers.

// Element count of a packed integer array.
// Packed-int arrays fold a 2-bit encoding tag into the count header: LEB((count << 2) | tag),
// tag 0 = all-LEB, 1 = all-raw, 2 = mixed (§5.1). The enc bitset is present only when tag == 2.
func _packedIntCount(from data: Foundation.Data, at pos: Int) -> Int {
    guard pos >= 0, let (c, _) = try? restoreLEB(from: data, at: pos) else { return 0 }
    return Int(c) >> 2
}
// Locate element `idx`: returns (payload position, isRaw) or nil (out of range / malformed).
func _packedEncSeek(from data: Foundation.Data, headerAt pos: Int, index idx: Int, rawWidth: Int) -> (Int, Bool)? {
    guard pos >= 0, idx >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) else { return nil }
    let count = Int(c) >> 2; let tag = Int(c) & 3; guard idx < count else { return nil }
    let encStart = pos + cB
    // tag 1 (all-raw): every element is `rawWidth` fixed bytes with no enc bitset, so element `idx`
    // sits at a known offset — O(1) random access instead of walking from element 0 (§5.1).
    if tag == 1 { return (encStart + idx * rawWidth, true) }
    var p = encStart + (tag == 2 ? (count + 7) / 8 : 0)
    for i in 0..<count {
        let isRaw = tag == 1 || (tag == 2 && (encStart + i / 8 < data.count) && ((data[encStart + i / 8] >> (i % 8)) & 1) != 0)
        if i == idx { return (p, isRaw) }
        if isRaw { p += rawWidth }
        else { guard let (_, vB) = try? restoreLEB(from: data, at: p) else { return nil }; p += vB }
    }
    return nil
}
// Optional variant: [count][nil bitset][enc bitset][present elements]. Returns nil for nil/absent.
func _packedEncOptSeek(from data: Foundation.Data, headerAt pos: Int, index idx: Int, rawWidth: Int) -> (Int, Bool)? {
    guard pos >= 0, idx >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) else { return nil }
    let count = Int(c) >> 2; let tag = Int(c) & 3; guard idx < count else { return nil }
    let nilStart = pos + cB
    let bsCnt = (count + 7) / 8
    let encStart = nilStart + bsCnt
    var p = encStart + (tag == 2 ? bsCnt : 0)
    for i in 0..<count {
        let present = (nilStart + i / 8 < data.count) && ((data[nilStart + i / 8] >> (i % 8)) & 1) == 0
        let isRaw = tag == 1 || (tag == 2 && (encStart + i / 8 < data.count) && ((data[encStart + i / 8] >> (i % 8)) & 1) != 0)
        if i == idx { return present ? (p, isRaw) : nil }
        if present { if isRaw { p += rawWidth } else { guard let (_, vB) = try? restoreLEB(from: data, at: p) else { return nil }; p += vB } }
    }
    return nil
}
// Read `width` little-endian bytes at p into a UInt64, or nil if out of bounds.
// UTF-8 bytes → String through the contiguous-buffer fast path. `String(decoding: data[r])`
// on a Data slice walks it through the generic Collection path, byte by byte (~10× slower).
@usableFromInline func _dagrUTF8(_ bytes: Foundation.Data) -> String {
    bytes.withUnsafeBytes { String(decoding: $0, as: UTF8.self) }
}

// One unaligned load per value (not `width` Data subscripts). `p` is a buffer index like
// every reader's `data[p]`, so the raw-buffer offset is taken relative to `startIndex`.
func _readRawLE(from data: Foundation.Data, at p: Int, width: Int) -> UInt64? {
    guard p >= 0, p + width <= data.count else { return nil }
    return data.withUnsafeBytes { (b: UnsafeRawBufferPointer) -> UInt64? in
        let o = p - data.startIndex
        guard o >= 0, o + width <= b.count else { return nil }
        switch width {
        case 8: return UInt64(littleEndian: b.loadUnaligned(fromByteOffset: o, as: UInt64.self))
        case 4: return UInt64(UInt32(littleEndian: b.loadUnaligned(fromByteOffset: o, as: UInt32.self)))
        case 2: return UInt64(UInt16(littleEndian: b.loadUnaligned(fromByteOffset: o, as: UInt16.self)))
        default:
            var v: UInt64 = 0
            for j in 0..<width { v |= UInt64(b[o + j]) << (UInt64(j) * 8) }
            return v
        }
    }
}
// Eager materialization of a packed integer array. `countPos` = position of the count LEB.
// `rawDecode`/`lebDecode` map the raw-LE / LEB u64 to the element type. Shares the header + enc-bitset
// walk with the lazy accessors (the enc-tag §5.1 plugs in here).
func _restorePackedIntArray<T>(from data: Foundation.Data, at countPos: Int, rawWidth: Int,
                               _ rawDecode: (UInt64) -> T, _ lebDecode: (UInt64) -> T) throws -> [T] {
    guard countPos >= 0, let (c, cB) = try? restoreLEB(from: data, at: countPos) else { return [] }
    let count = Int(c) >> 2; let tag = Int(c) & 3
    let encStart = countPos + cB
    var result = [T](); result.reserveCapacity(count)
    var p = encStart + (tag == 2 ? (count + 7) / 8 : 0)
    for i in 0..<count {
        let isRaw = tag == 1 || (tag == 2 && (encStart + i / 8 < data.count) && ((data[encStart + i / 8] >> (i % 8)) & 1) != 0)
        if isRaw { result.append(rawDecode(_readRawLE(from: data, at: p, width: rawWidth) ?? 0)); p += rawWidth }
        else { let (v, vB) = try restoreLEB(from: data, at: p); result.append(lebDecode(v)); p += vB }
    }
    return result
}
func _restorePackedIntOptArray<T>(from data: Foundation.Data, at countPos: Int, rawWidth: Int,
                                  _ rawDecode: (UInt64) -> T, _ lebDecode: (UInt64) -> T) throws -> [T?] {
    guard countPos >= 0, let (c, cB) = try? restoreLEB(from: data, at: countPos) else { return [] }
    let count = Int(c) >> 2; let tag = Int(c) & 3
    let nilStart = countPos + cB
    let bsCnt = (count + 7) / 8
    let encStart = nilStart + bsCnt
    var result = [T?](); result.reserveCapacity(count)
    var p = encStart + (tag == 2 ? bsCnt : 0)
    for i in 0..<count {
        let present = (nilStart + i / 8 < data.count) && ((data[nilStart + i / 8] >> (i % 8)) & 1) == 0
        if !present { result.append(nil); continue }
        let isRaw = tag == 1 || (tag == 2 && (encStart + i / 8 < data.count) && ((data[encStart + i / 8] >> (i % 8)) & 1) != 0)
        if isRaw { result.append(rawDecode(_readRawLE(from: data, at: p, width: rawWidth) ?? 0)); p += rawWidth }
        else { let (v, vB) = try restoreLEB(from: data, at: p); result.append(lebDecode(v)); p += vB }
    }
    return result
}
// Eager materialization of a packed complex array (self-delimiting elements: LEB length + bytes).
// `countPos` = position of the count LEB. `make` builds the element from a byte slice.
func _restorePackedComplexArray<T>(from data: Foundation.Data, at countPos: Int, _ make: (Foundation.Data) -> T) throws -> [T] {
    guard countPos >= 0, let (c, cB) = try? restoreLEB(from: data, at: countPos) else { return [] }
    let count = Int(c)
    var result = [T](); result.reserveCapacity(count)
    var p = countPos + cB
    for _ in 0..<count {
        let (sv, sb) = try restoreLEB(from: data, at: p); p += sb
        guard p + Int(sv) <= data.count else { throw ArenaRestoreError.outsideOfBuffer }
        result.append(make(data[p..<(p + Int(sv))])); p += Int(sv)
    }
    return result
}
func _restorePackedComplexOptArray<T>(from data: Foundation.Data, at countPos: Int, _ make: (Foundation.Data) -> T) throws -> [T?] {
    guard countPos >= 0, let (c, cB) = try? restoreLEB(from: data, at: countPos) else { return [] }
    let count = Int(c)
    let nilStart = countPos + cB
    let bsCnt = (count + 7) / 8
    var result = [T?](); result.reserveCapacity(count)
    var p = nilStart + bsCnt
    for i in 0..<count {
        let isNil = (nilStart + i / 8 < data.count) && ((data[nilStart + i / 8] >> (i % 8)) & 1) != 0
        if isNil { result.append(nil); continue }
        let (sv, sb) = try restoreLEB(from: data, at: p); p += sb
        guard p + Int(sv) <= data.count else { throw ArenaRestoreError.outsideOfBuffer }
        result.append(make(data[p..<(p + Int(sv))])); p += Int(sv)
    }
    return result
}
// Eager materialization of a packed float array (self-describing tag+payload per element).
// `dec(data, pos)` decodes one element and returns (value, bytesConsumed).
// The float count folds a 2-bit mode (§5.2): count = raw >> 2. `dec` is the packed (self-describing)
// or raw (native-LE fixed width) decoder — codegen picks the one matching the field's schema mode.
func _restorePackedFloatArray<T>(from data: Foundation.Data, at countPos: Int,
                                 _ dec: (Foundation.Data, Int) throws -> (T, Int)) throws -> [T] {
    guard countPos >= 0, let (c, cB) = try? restoreLEB(from: data, at: countPos) else { return [] }
    let count = Int(c) >> 2
    var result = [T](); result.reserveCapacity(count)
    var p = countPos + cB
    for _ in 0..<count { let (v, b) = try dec(data, p); result.append(v); p += b }
    return result
}
func _restorePackedFloatOptArray<T>(from data: Foundation.Data, at countPos: Int,
                                    _ dec: (Foundation.Data, Int) throws -> (T, Int)) throws -> [T?] {
    guard countPos >= 0, let (c, cB) = try? restoreLEB(from: data, at: countPos) else { return [] }
    let count = Int(c) >> 2
    let nilStart = countPos + cB
    let bsCnt = (count + 7) / 8
    var result = [T?](); result.reserveCapacity(count)
    var p = nilStart + bsCnt
    for i in 0..<count {
        let isNil = (nilStart + i / 8 < data.count) && ((data[nilStart + i / 8] >> (i % 8)) & 1) != 0
        if isNil { result.append(nil); continue }
        let (v, b) = try dec(data, p); result.append(v); p += b
    }
    return result
}
// Eager materialization of a packed optional bool array: [count][bitSetNil][compacted value bitset].
// (Distinct from the regular/vtable [Bool?] which is uncompacted — see spec §5.7 vs §4.7.)
func _restorePackedBoolOptArray(from data: Foundation.Data, at countPos: Int) throws -> [Bool?] {
    guard countPos >= 0, let (c, cB) = try? restoreLEB(from: data, at: countPos) else { return [] }
    let count = Int(c)
    let nilStart = countPos + cB
    let valStart = nilStart + (count + 7) / 8
    var result = [Bool?](); result.reserveCapacity(count)
    var ci = 0
    for i in 0..<count {
        let nilB = (nilStart + i / 8 < data.count) ? data[nilStart + i / 8] : 0
        if nilB & UInt8(1 << (i % 8)) != 0 { result.append(nil) }
        else {
            let valB = (valStart + ci / 8 < data.count) ? data[valStart + ci / 8] : 0
            result.append(valB & UInt8(1 << (ci % 8)) != 0); ci += 1
        }
    }
    return result
}
// Eager materialization of a packed f16/bf16 array. Non-opt: enc bitset (bit=1 → raw 2 bytes via `conv`,
// bit=0 → special-value tag via _decodePackedF16). `conv` = _f16BitsToF32 / _bf16BitsToF32.
func _restorePackedF16Array(from data: Foundation.Data, at countPos: Int, _ conv: (UInt16) -> Float) throws -> [Float] {
    guard countPos >= 0, let (c, cB) = try? restoreLEB(from: data, at: countPos) else { return [] }
    let count = Int(c)
    let encStart = countPos + cB
    var result = [Float](); result.reserveCapacity(count)
    var p = encStart + (count + 7) / 8
    for i in 0..<count {
        let isRaw = (encStart + i / 8 < data.count) && ((data[encStart + i / 8] >> (i % 8)) & 1) != 0
        if isRaw { result.append(conv(try UInt16.restore(from: data, at: p))); p += 2 }
        else { let (v, b) = try _decodePackedF16(from: data, at: p); result.append(v); p += b }
    }
    return result
}
// Optional f16/bf16: [count][bitSetNil][M raw 2-byte present elements] (no enc bitset — spec §5.7).
func _restorePackedF16OptArray(from data: Foundation.Data, at countPos: Int, _ conv: (UInt16) -> Float) throws -> [Float?] {
    guard countPos >= 0, let (c, cB) = try? restoreLEB(from: data, at: countPos) else { return [] }
    let count = Int(c)
    let nilStart = countPos + cB
    var result = [Float?](); result.reserveCapacity(count)
    var p = nilStart + (count + 7) / 8
    for i in 0..<count {
        let isNil = (nilStart + i / 8 < data.count) && ((data[nilStart + i / 8] >> (i % 8)) & 1) != 0
        if isNil { result.append(nil); continue }
        result.append(conv(try UInt16.restore(from: data, at: p))); p += 2
    }
    return result
}

// Packed full-byte enum array: [count][LEB(rawValue) per element]. Returns raw values;
// the caller maps them to the concrete enum type.
func _restorePackedEnumRawArray(from data: Foundation.Data, at countPos: Int) throws -> [UInt64] {
    guard countPos >= 0, let (c, cB) = try? restoreLEB(from: data, at: countPos) else { return [] }
    let count = Int(c)
    var result = [UInt64](); result.reserveCapacity(count)
    var p = countPos + cB
    for _ in 0..<count { let (v, b) = try restoreLEB(from: data, at: p); result.append(v); p += b }
    return result
}

// Optional variant: [count][bitSetNil][M LEB(rawValue)] (nil elements skipped in the payload).
func _restorePackedEnumRawOptArray(from data: Foundation.Data, at countPos: Int) throws -> [UInt64?] {
    guard countPos >= 0, let (c, cB) = try? restoreLEB(from: data, at: countPos) else { return [] }
    let count = Int(c)
    let nilStart = countPos + cB
    var result = [UInt64?](); result.reserveCapacity(count)
    var p = nilStart + (count + 7) / 8
    for i in 0..<count {
        let isNil = (nilStart + i / 8 < data.count) && ((data[nilStart + i / 8] >> (i % 8)) & 1) != 0
        if isNil { result.append(nil); continue }
        let (v, b) = try restoreLEB(from: data, at: p); result.append(v); p += b
    }
    return result
}

public struct PackedU16ArrayAccessor {
    private let _data: Foundation.Data
    private let _pos: Int
    public init(_ data: Foundation.Data, at pos: Int) { _data = data; _pos = pos }
    public var count: Int { _packedIntCount(from: _data, at: _pos) }
    public subscript(_ idx: Int) -> UInt16 {
        guard let (p, isRaw) = _packedEncSeek(from: _data, headerAt: _pos, index: idx, rawWidth: 2) else { return 0 }
        if isRaw { guard let _raw = _readRawLE(from: _data, at: p, width: 2) else { return 0 }; return UInt16(truncatingIfNeeded: _raw) }
        guard let (v, _) = try? restoreLEB(from: _data, at: p) else { return 0 }
        return UInt16(truncatingIfNeeded: v)
    }
}

public struct PackedI16ArrayAccessor {
    private let _data: Foundation.Data
    private let _pos: Int
    public init(_ data: Foundation.Data, at pos: Int) { _data = data; _pos = pos }
    public var count: Int { _packedIntCount(from: _data, at: _pos) }
    public subscript(_ idx: Int) -> Int16 {
        guard let (p, isRaw) = _packedEncSeek(from: _data, headerAt: _pos, index: idx, rawWidth: 2) else { return 0 }
        if isRaw { guard let _raw = _readRawLE(from: _data, at: p, width: 2) else { return 0 }; return Int16(bitPattern: UInt16(truncatingIfNeeded: _raw)) }
        guard let (v, _) = try? restoreLEB(from: _data, at: p) else { return 0 }
        return Int16(truncatingIfNeeded: v.fromZigZag)
    }
}

public struct PackedU32ArrayAccessor {
    private let _data: Foundation.Data
    private let _pos: Int
    public init(_ data: Foundation.Data, at pos: Int) { _data = data; _pos = pos }
    public var count: Int { _packedIntCount(from: _data, at: _pos) }
    public subscript(_ idx: Int) -> UInt32 {
        guard let (p, isRaw) = _packedEncSeek(from: _data, headerAt: _pos, index: idx, rawWidth: 4) else { return 0 }
        if isRaw { guard let _raw = _readRawLE(from: _data, at: p, width: 4) else { return 0 }; return UInt32(truncatingIfNeeded: _raw) }
        guard let (v, _) = try? restoreLEB(from: _data, at: p) else { return 0 }
        return UInt32(truncatingIfNeeded: v)
    }
}

public struct PackedI32ArrayAccessor {
    private let _data: Foundation.Data
    private let _pos: Int
    public init(_ data: Foundation.Data, at pos: Int) { _data = data; _pos = pos }
    public var count: Int { _packedIntCount(from: _data, at: _pos) }
    public subscript(_ idx: Int) -> Int32 {
        guard let (p, isRaw) = _packedEncSeek(from: _data, headerAt: _pos, index: idx, rawWidth: 4) else { return 0 }
        if isRaw { guard let _raw = _readRawLE(from: _data, at: p, width: 4) else { return 0 }; return Int32(bitPattern: UInt32(truncatingIfNeeded: _raw)) }
        guard let (v, _) = try? restoreLEB(from: _data, at: p) else { return 0 }
        return Int32(truncatingIfNeeded: v.fromZigZag)
    }
}

public struct PackedU64ArrayAccessor {
    private let _data: Foundation.Data
    private let _pos: Int
    public init(_ data: Foundation.Data, at pos: Int) { _data = data; _pos = pos }
    public var count: Int { _packedIntCount(from: _data, at: _pos) }
    public subscript(_ idx: Int) -> UInt64 {
        guard let (p, isRaw) = _packedEncSeek(from: _data, headerAt: _pos, index: idx, rawWidth: 8) else { return 0 }
        if isRaw { guard let _raw = _readRawLE(from: _data, at: p, width: 8) else { return 0 }; return UInt64(truncatingIfNeeded: _raw) }
        guard let (v, _) = try? restoreLEB(from: _data, at: p) else { return 0 }
        return UInt64(truncatingIfNeeded: v)
    }
}

public struct PackedI64ArrayAccessor {
    private let _data: Foundation.Data
    private let _pos: Int
    public init(_ data: Foundation.Data, at pos: Int) { _data = data; _pos = pos }
    public var count: Int { _packedIntCount(from: _data, at: _pos) }
    public subscript(_ idx: Int) -> Int64 {
        guard let (p, isRaw) = _packedEncSeek(from: _data, headerAt: _pos, index: idx, rawWidth: 8) else { return 0 }
        if isRaw { guard let _raw = _readRawLE(from: _data, at: p, width: 8) else { return 0 }; return Int64(bitPattern: UInt64(truncatingIfNeeded: _raw)) }
        guard let (v, _) = try? restoreLEB(from: _data, at: p) else { return 0 }
        return Int64(truncatingIfNeeded: v.fromZigZag)
    }
}

// ── Optional packed array accessors ───────────────────────────────────────────
// Format: count LEB + presence bitset ceil(count/8) bytes (bit=1 means present)
// For u16..i64: also encoding bitset ceil(count/8) bytes after presence bitset.
// subscript returns T? — nil when element is absent.

public struct PackedBoolOptArrayAccessor {
    private let _data: Foundation.Data
    private let _bsNilStart: Int
    private let _bsValStart: Int
    public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) {
            count = Int(c)
            _bsNilStart = pos + cB
            _bsValStart = pos + cB + (Int(c) + 7) >> 3
        } else { count = 0; _bsNilStart = -1; _bsValStart = -1 }
    }
    public subscript(_ idx: Int) -> Bool? {
        guard _bsNilStart >= 0, idx >= 0, idx < count else { return nil }
        let nilOff = _bsNilStart + (idx >> 3)
        if nilOff < _data.count && (_data[nilOff] >> (idx & 7)) & 1 != 0 { return nil }
        var ci = 0
        for i in 0..<idx {
            let off = _bsNilStart + (i >> 3)
            if off >= _data.count || (_data[off] >> (i & 7)) & 1 == 0 { ci += 1 }
        }
        let valOff = _bsValStart + (ci >> 3)
        guard valOff < _data.count else { return false }
        return (_data[valOff] >> (ci & 7)) & 1 != 0
    }
}

public struct PackedU8OptArrayAccessor {
    private let _data: Foundation.Data
    private let _start: Int
    public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) { count = Int(c); _start = pos + cB }
        else { count = 0; _start = -1 }
    }
    public subscript(_ idx: Int) -> UInt8? {
        guard _start >= 0, idx >= 0, idx < count else { return nil }
        var p = _start + (count + 7) / 8
        for i in 0..<count {
            let present = _start + i/8 < _data.count && (_data[_start + i/8] >> (i%8)) & 1 == 0
            if i == idx { return present && p < _data.count ? _data[p] : nil }
            if present { p += 1 }
        }
        return nil
    }
}

public struct PackedI8OptArrayAccessor {
    private let _data: Foundation.Data
    private let _start: Int
    public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) { count = Int(c); _start = pos + cB }
        else { count = 0; _start = -1 }
    }
    public subscript(_ idx: Int) -> Int8? {
        guard _start >= 0, idx >= 0, idx < count else { return nil }
        var p = _start + (count + 7) / 8
        for i in 0..<count {
            let present = _start + i/8 < _data.count && (_data[_start + i/8] >> (i%8)) & 1 == 0
            if i == idx { return present && p < _data.count ? Int8(bitPattern: _data[p]) : nil }
            if present { p += 1 }
        }
        return nil
    }
}

public struct PackedF32OptArrayAccessor {
    private let _data: Foundation.Data
    private let _start: Int
    private let _mode: Int
    public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) { count = Int(c) >> 2; _mode = Int(c) & 3; _start = pos + cB }
        else { count = 0; _mode = 0; _start = -1 }
    }
    public subscript(_ idx: Int) -> Float? {
        guard _start >= 0, idx >= 0, idx < count else { return nil }
        var p = _start + (count + 7) / 8
        for i in 0..<count {
            let present = _start + i/8 < _data.count && (_data[_start + i/8] >> (i%8)) & 1 == 0
            if i == idx {
                guard present else { return nil }
                if _mode == 1 { return Float(bitPattern: UInt32(truncatingIfNeeded: _readRawLE(from: _data, at: p, width: 4) ?? 0)) }
                guard let (fv, _) = try? _decodePackedFloat32(from: _data, at: p) else { return nil }
                return fv
            }
            if present {
                if _mode == 1 { p += 4 }
                else { guard let (_, fB) = try? _decodePackedFloat32(from: _data, at: p) else { return nil }; p += fB }
            }
        }
        return nil
    }
}

public struct PackedF64OptArrayAccessor {
    private let _data: Foundation.Data
    private let _start: Int
    private let _mode: Int
    public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) { count = Int(c) >> 2; _mode = Int(c) & 3; _start = pos + cB }
        else { count = 0; _mode = 0; _start = -1 }
    }
    public subscript(_ idx: Int) -> Double? {
        guard _start >= 0, idx >= 0, idx < count else { return nil }
        var p = _start + (count + 7) / 8
        for i in 0..<count {
            let present = _start + i/8 < _data.count && (_data[_start + i/8] >> (i%8)) & 1 == 0
            if i == idx {
                guard present else { return nil }
                if _mode == 1 { return Double(bitPattern: _readRawLE(from: _data, at: p, width: 8) ?? 0) }
                guard let (fv, _) = try? _decodePackedFloat64(from: _data, at: p) else { return nil }
                return fv
            }
            if present {
                if _mode == 1 { p += 8 }
                else { guard let (_, fB) = try? _decodePackedFloat64(from: _data, at: p) else { return nil }; p += fB }
            }
        }
        return nil
    }
}

public struct PackedF16OptArrayAccessor {
    private let _data: Foundation.Data
    private let _start: Int
    public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) {
            count = Int(c); _start = pos + cB
        } else { count = 0; _start = -1 }
    }
    public subscript(_ idx: Int) -> Float? {
        guard _start >= 0, idx >= 0, idx < count else { return nil }
        let bsBytes = (count + 7) / 8
        var p = _start + bsBytes
        for i in 0..<count {
            let present = _start + i/8 < _data.count && (_data[_start + i/8] >> (i%8)) & 1 == 0
            if i == idx {
                guard present else { return nil }
                guard p + 1 < _data.count else { return nil }
                let bits = UInt16(_data[p]) | (UInt16(_data[p+1]) << 8)
                return _f16BitsToF32(bits)
            }
            if present { p += 2 }
        }
        return nil
    }
}

public struct PackedBf16OptArrayAccessor {
    private let _data: Foundation.Data
    private let _start: Int
    public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) {
            count = Int(c); _start = pos + cB
        } else { count = 0; _start = -1 }
    }
    public subscript(_ idx: Int) -> Float? {
        guard _start >= 0, idx >= 0, idx < count else { return nil }
        let bsBytes = (count + 7) / 8
        var p = _start + bsBytes
        for i in 0..<count {
            let present = _start + i/8 < _data.count && (_data[_start + i/8] >> (i%8)) & 1 == 0
            if i == idx {
                guard present else { return nil }
                guard p + 1 < _data.count else { return nil }
                let bits = UInt16(_data[p]) | (UInt16(_data[p+1]) << 8)
                return _bf16BitsToF32(bits)
            }
            if present { p += 2 }
        }
        return nil
    }
}

public struct PackedUtf8OptArrayAccessor {
    private let _data: Foundation.Data
    private let _start: Int
    public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) { count = Int(c); _start = pos + cB }
        else { count = 0; _start = -1 }
    }
    public subscript(_ idx: Int) -> String? {
        guard _start >= 0, idx >= 0, idx < count else { return nil }
        var p = _start + (count + 7) / 8
        for i in 0..<count {
            let present = _start + i/8 < _data.count && (_data[_start + i/8] >> (i%8)) & 1 == 0
            if i == idx {
                guard present else { return nil }
                guard let (len, lB) = try? restoreLEB(from: _data, at: p) else { return nil }
                let s = p + lB; let e = s + Int(len)
                guard e <= _data.count else { return nil }
                return _dagrUTF8(_data[s..<e])
            }
            if present {
                guard let (len, lB) = try? restoreLEB(from: _data, at: p) else { return nil }
                p += lB + Int(len)
            }
        }
        return nil
    }
}

public struct PackedDataOptArrayAccessor {
    private let _data: Foundation.Data
    private let _start: Int
    public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) { count = Int(c); _start = pos + cB }
        else { count = 0; _start = -1 }
    }
    public subscript(_ idx: Int) -> Foundation.Data? {
        guard _start >= 0, idx >= 0, idx < count else { return nil }
        var p = _start + (count + 7) / 8
        for i in 0..<count {
            let present = _start + i/8 < _data.count && (_data[_start + i/8] >> (i%8)) & 1 == 0
            if i == idx {
                guard present else { return nil }
                guard let (len, lB) = try? restoreLEB(from: _data, at: p) else { return nil }
                let s = p + lB; let e = s + Int(len)
                guard e <= _data.count else { return nil }
                return Foundation.Data(_data[s..<e])
            }
            if present {
                guard let (len, lB) = try? restoreLEB(from: _data, at: p) else { return nil }
                p += lB + Int(len)
            }
        }
        return nil
    }
}

public struct PackedU16OptArrayAccessor {
    private let _data: Foundation.Data
    private let _pos: Int
    public init(_ data: Foundation.Data, at pos: Int) { _data = data; _pos = pos }
    public var count: Int { _packedIntCount(from: _data, at: _pos) }
    public subscript(_ idx: Int) -> UInt16? {
        guard let (p, isRaw) = _packedEncOptSeek(from: _data, headerAt: _pos, index: idx, rawWidth: 2) else { return nil }
        if isRaw { guard let _raw = _readRawLE(from: _data, at: p, width: 2) else { return nil }; return UInt16(truncatingIfNeeded: _raw) }
        guard let (v, _) = try? restoreLEB(from: _data, at: p) else { return nil }
        return UInt16(truncatingIfNeeded: v)
    }
}

public struct PackedI16OptArrayAccessor {
    private let _data: Foundation.Data
    private let _pos: Int
    public init(_ data: Foundation.Data, at pos: Int) { _data = data; _pos = pos }
    public var count: Int { _packedIntCount(from: _data, at: _pos) }
    public subscript(_ idx: Int) -> Int16? {
        guard let (p, isRaw) = _packedEncOptSeek(from: _data, headerAt: _pos, index: idx, rawWidth: 2) else { return nil }
        if isRaw { guard let _raw = _readRawLE(from: _data, at: p, width: 2) else { return nil }; return Int16(bitPattern: UInt16(truncatingIfNeeded: _raw)) }
        guard let (v, _) = try? restoreLEB(from: _data, at: p) else { return nil }
        return Int16(truncatingIfNeeded: v.fromZigZag)
    }
}

public struct PackedU32OptArrayAccessor {
    private let _data: Foundation.Data
    private let _pos: Int
    public init(_ data: Foundation.Data, at pos: Int) { _data = data; _pos = pos }
    public var count: Int { _packedIntCount(from: _data, at: _pos) }
    public subscript(_ idx: Int) -> UInt32? {
        guard let (p, isRaw) = _packedEncOptSeek(from: _data, headerAt: _pos, index: idx, rawWidth: 4) else { return nil }
        if isRaw { guard let _raw = _readRawLE(from: _data, at: p, width: 4) else { return nil }; return UInt32(truncatingIfNeeded: _raw) }
        guard let (v, _) = try? restoreLEB(from: _data, at: p) else { return nil }
        return UInt32(truncatingIfNeeded: v)
    }
}

public struct PackedI32OptArrayAccessor {
    private let _data: Foundation.Data
    private let _pos: Int
    public init(_ data: Foundation.Data, at pos: Int) { _data = data; _pos = pos }
    public var count: Int { _packedIntCount(from: _data, at: _pos) }
    public subscript(_ idx: Int) -> Int32? {
        guard let (p, isRaw) = _packedEncOptSeek(from: _data, headerAt: _pos, index: idx, rawWidth: 4) else { return nil }
        if isRaw { guard let _raw = _readRawLE(from: _data, at: p, width: 4) else { return nil }; return Int32(bitPattern: UInt32(truncatingIfNeeded: _raw)) }
        guard let (v, _) = try? restoreLEB(from: _data, at: p) else { return nil }
        return Int32(truncatingIfNeeded: v.fromZigZag)
    }
}

public struct PackedU64OptArrayAccessor {
    private let _data: Foundation.Data
    private let _pos: Int
    public init(_ data: Foundation.Data, at pos: Int) { _data = data; _pos = pos }
    public var count: Int { _packedIntCount(from: _data, at: _pos) }
    public subscript(_ idx: Int) -> UInt64? {
        guard let (p, isRaw) = _packedEncOptSeek(from: _data, headerAt: _pos, index: idx, rawWidth: 8) else { return nil }
        if isRaw { guard let _raw = _readRawLE(from: _data, at: p, width: 8) else { return nil }; return UInt64(truncatingIfNeeded: _raw) }
        guard let (v, _) = try? restoreLEB(from: _data, at: p) else { return nil }
        return UInt64(truncatingIfNeeded: v)
    }
}

public struct PackedI64OptArrayAccessor {
    private let _data: Foundation.Data
    private let _pos: Int
    public init(_ data: Foundation.Data, at pos: Int) { _data = data; _pos = pos }
    public var count: Int { _packedIntCount(from: _data, at: _pos) }
    public subscript(_ idx: Int) -> Int64? {
        guard let (p, isRaw) = _packedEncOptSeek(from: _data, headerAt: _pos, index: idx, rawWidth: 8) else { return nil }
        if isRaw { guard let _raw = _readRawLE(from: _data, at: p, width: 8) else { return nil }; return Int64(bitPattern: UInt64(truncatingIfNeeded: _raw)) }
        guard let (v, _) = try? restoreLEB(from: _data, at: p) else { return nil }
        return Int64(truncatingIfNeeded: v.fromZigZag)
    }
}

// ── Vtable array accessors (zero-allocation lazy access) ──────────────────────
// Format: header LEB (count<<2 | widthCode) + count*es slot table (forward order)
//         + element data at relative offsets from slot table end.
// Slot i holds the ZigZag-encoded relative offset for element i (0 = nil/absent).
// Plain (`*ArrayAccessor`) = required elements → subscript returns non-optional T
// (0/false/""/empty on out-of-bounds); `*OptArrayAccessor` = arrayWithOptionals →
// subscript returns T? (nil when the element is absent or out of bounds).

public struct VtableBoolArrayAccessor {
    private let _data: Foundation.Data
    private let _bsStart: Int
    public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) {
            count = Int(c); _bsStart = pos + cB
        } else { count = 0; _bsStart = -1 }
    }
    public subscript(_ idx: Int) -> Bool {
        guard _bsStart >= 0, idx >= 0, idx < count else { return false }
        let off = _bsStart + (idx >> 3)
        guard off < _data.count else { return false }
        return (_data[off] >> (idx & 7)) & 1 != 0
    }
}

public struct VtableBoolOptArrayAccessor {
    private let _data: Foundation.Data
    private let _bsNilStart: Int
    private let _bsValStart: Int
    public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) {
            count = Int(c)
            _bsNilStart = pos + cB
            _bsValStart = pos + cB + (Int(c) + 7) >> 3
        } else { count = 0; _bsNilStart = -1; _bsValStart = -1 }
    }
    public subscript(_ idx: Int) -> Bool? {
        guard _bsNilStart >= 0, idx >= 0, idx < count else { return nil }
        let nilOff = _bsNilStart + (idx >> 3)
        if nilOff < _data.count && (_data[nilOff] >> (idx & 7)) & 1 != 0 { return nil }
        let valOff = _bsValStart + (idx >> 3)
        guard valOff < _data.count else { return false }
        return (_data[valOff] >> (idx & 7)) & 1 != 0
    }
}

// ── Numeric vtable array accessors — inline format ────────────────────────────
// Required:  [LEB(count)] [elem[0]..elem[N-1]] (W bytes each, LE raw).
// Optional:  [LEB(count)] [bitSetNil (⌈N/8⌉ B)] [elem[0]..elem[N-1]] (zeros for nil).
// Plain `*ArrayAccessor` subscript returns non-optional T (0 on out-of-bounds);
// `*OptArrayAccessor` subscript returns T? (nil when absent or out of bounds).

public struct VtableU8ArrayAccessor {
    private let _data: Foundation.Data; private let _elemStart: Int; public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) { count = Int(c); _elemStart = pos + cB }
        else { count = 0; _elemStart = -1 }
    }
    public subscript(_ idx: Int) -> UInt8 {
        guard _elemStart >= 0, idx >= 0, idx < count else { return 0 }
        return (try? UInt8.restore(from: _data, at: _elemStart + idx)) ?? 0
    }
}
public struct VtableU8OptArrayAccessor {
    private let _data: Foundation.Data; private let _bsStart: Int; private let _elemStart: Int; public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) {
            count = Int(c); _bsStart = pos + cB; _elemStart = pos + cB + ((Int(c) + 7) >> 3)
        } else { count = 0; _bsStart = -1; _elemStart = -1 }
    }
    public subscript(_ idx: Int) -> UInt8? {
        guard _bsStart >= 0, idx >= 0, idx < count else { return nil }
        let bOff = _bsStart + (idx >> 3)
        if bOff < _data.count && (_data[bOff] >> (idx & 7)) & 1 != 0 { return nil }
        return try? UInt8.restore(from: _data, at: _elemStart + idx)
    }
}

public struct VtableI8ArrayAccessor {
    private let _data: Foundation.Data; private let _elemStart: Int; public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) { count = Int(c); _elemStart = pos + cB }
        else { count = 0; _elemStart = -1 }
    }
    public subscript(_ idx: Int) -> Int8 {
        guard _elemStart >= 0, idx >= 0, idx < count else { return 0 }
        return (try? Int8.restore(from: _data, at: _elemStart + idx)) ?? 0
    }
}
public struct VtableI8OptArrayAccessor {
    private let _data: Foundation.Data; private let _bsStart: Int; private let _elemStart: Int; public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) {
            count = Int(c); _bsStart = pos + cB; _elemStart = pos + cB + ((Int(c) + 7) >> 3)
        } else { count = 0; _bsStart = -1; _elemStart = -1 }
    }
    public subscript(_ idx: Int) -> Int8? {
        guard _bsStart >= 0, idx >= 0, idx < count else { return nil }
        let bOff = _bsStart + (idx >> 3)
        if bOff < _data.count && (_data[bOff] >> (idx & 7)) & 1 != 0 { return nil }
        return try? Int8.restore(from: _data, at: _elemStart + idx)
    }
}

public struct VtableU16ArrayAccessor {
    private let _data: Foundation.Data; private let _elemStart: Int; public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) { count = Int(c); _elemStart = pos + cB }
        else { count = 0; _elemStart = -1 }
    }
    public subscript(_ idx: Int) -> UInt16 {
        guard _elemStart >= 0, idx >= 0, idx < count else { return 0 }
        return (try? UInt16.restore(from: _data, at: _elemStart + idx * 2)) ?? 0
    }
}
public struct VtableU16OptArrayAccessor {
    private let _data: Foundation.Data; private let _bsStart: Int; private let _elemStart: Int; public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) {
            count = Int(c); _bsStart = pos + cB; _elemStart = pos + cB + ((Int(c) + 7) >> 3)
        } else { count = 0; _bsStart = -1; _elemStart = -1 }
    }
    public subscript(_ idx: Int) -> UInt16? {
        guard _bsStart >= 0, idx >= 0, idx < count else { return nil }
        let bOff = _bsStart + (idx >> 3)
        if bOff < _data.count && (_data[bOff] >> (idx & 7)) & 1 != 0 { return nil }
        return try? UInt16.restore(from: _data, at: _elemStart + idx * 2)
    }
}

public struct VtableI16ArrayAccessor {
    private let _data: Foundation.Data; private let _elemStart: Int; public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) { count = Int(c); _elemStart = pos + cB }
        else { count = 0; _elemStart = -1 }
    }
    public subscript(_ idx: Int) -> Int16 {
        guard _elemStart >= 0, idx >= 0, idx < count else { return 0 }
        return (try? Int16.restore(from: _data, at: _elemStart + idx * 2)) ?? 0
    }
}
public struct VtableI16OptArrayAccessor {
    private let _data: Foundation.Data; private let _bsStart: Int; private let _elemStart: Int; public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) {
            count = Int(c); _bsStart = pos + cB; _elemStart = pos + cB + ((Int(c) + 7) >> 3)
        } else { count = 0; _bsStart = -1; _elemStart = -1 }
    }
    public subscript(_ idx: Int) -> Int16? {
        guard _bsStart >= 0, idx >= 0, idx < count else { return nil }
        let bOff = _bsStart + (idx >> 3)
        if bOff < _data.count && (_data[bOff] >> (idx & 7)) & 1 != 0 { return nil }
        return try? Int16.restore(from: _data, at: _elemStart + idx * 2)
    }
}

public struct VtableU32ArrayAccessor {
    private let _data: Foundation.Data; private let _elemStart: Int; public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) { count = Int(c); _elemStart = pos + cB }
        else { count = 0; _elemStart = -1 }
    }
    public subscript(_ idx: Int) -> UInt32 {
        guard _elemStart >= 0, idx >= 0, idx < count else { return 0 }
        return (try? UInt32.restore(from: _data, at: _elemStart + idx * 4)) ?? 0
    }
}
public struct VtableU32OptArrayAccessor {
    private let _data: Foundation.Data; private let _bsStart: Int; private let _elemStart: Int; public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) {
            count = Int(c); _bsStart = pos + cB; _elemStart = pos + cB + ((Int(c) + 7) >> 3)
        } else { count = 0; _bsStart = -1; _elemStart = -1 }
    }
    public subscript(_ idx: Int) -> UInt32? {
        guard _bsStart >= 0, idx >= 0, idx < count else { return nil }
        let bOff = _bsStart + (idx >> 3)
        if bOff < _data.count && (_data[bOff] >> (idx & 7)) & 1 != 0 { return nil }
        return try? UInt32.restore(from: _data, at: _elemStart + idx * 4)
    }
}

public struct VtableI32ArrayAccessor {
    private let _data: Foundation.Data; private let _elemStart: Int; public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) { count = Int(c); _elemStart = pos + cB }
        else { count = 0; _elemStart = -1 }
    }
    public subscript(_ idx: Int) -> Int32 {
        guard _elemStart >= 0, idx >= 0, idx < count else { return 0 }
        return (try? Int32.restore(from: _data, at: _elemStart + idx * 4)) ?? 0
    }
}
public struct VtableI32OptArrayAccessor {
    private let _data: Foundation.Data; private let _bsStart: Int; private let _elemStart: Int; public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) {
            count = Int(c); _bsStart = pos + cB; _elemStart = pos + cB + ((Int(c) + 7) >> 3)
        } else { count = 0; _bsStart = -1; _elemStart = -1 }
    }
    public subscript(_ idx: Int) -> Int32? {
        guard _bsStart >= 0, idx >= 0, idx < count else { return nil }
        let bOff = _bsStart + (idx >> 3)
        if bOff < _data.count && (_data[bOff] >> (idx & 7)) & 1 != 0 { return nil }
        return try? Int32.restore(from: _data, at: _elemStart + idx * 4)
    }
}

public struct VtableU64ArrayAccessor {
    private let _data: Foundation.Data; private let _elemStart: Int; public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) { count = Int(c); _elemStart = pos + cB }
        else { count = 0; _elemStart = -1 }
    }
    public subscript(_ idx: Int) -> UInt64 {
        guard _elemStart >= 0, idx >= 0, idx < count else { return 0 }
        return (try? UInt64.restore(from: _data, at: _elemStart + idx * 8)) ?? 0
    }
}
public struct VtableU64OptArrayAccessor {
    private let _data: Foundation.Data; private let _bsStart: Int; private let _elemStart: Int; public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) {
            count = Int(c); _bsStart = pos + cB; _elemStart = pos + cB + ((Int(c) + 7) >> 3)
        } else { count = 0; _bsStart = -1; _elemStart = -1 }
    }
    public subscript(_ idx: Int) -> UInt64? {
        guard _bsStart >= 0, idx >= 0, idx < count else { return nil }
        let bOff = _bsStart + (idx >> 3)
        if bOff < _data.count && (_data[bOff] >> (idx & 7)) & 1 != 0 { return nil }
        return try? UInt64.restore(from: _data, at: _elemStart + idx * 8)
    }
}

public struct VtableI64ArrayAccessor {
    private let _data: Foundation.Data; private let _elemStart: Int; public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) { count = Int(c); _elemStart = pos + cB }
        else { count = 0; _elemStart = -1 }
    }
    public subscript(_ idx: Int) -> Int64 {
        guard _elemStart >= 0, idx >= 0, idx < count else { return 0 }
        return (try? Int64.restore(from: _data, at: _elemStart + idx * 8)) ?? 0
    }
}
public struct VtableI64OptArrayAccessor {
    private let _data: Foundation.Data; private let _bsStart: Int; private let _elemStart: Int; public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) {
            count = Int(c); _bsStart = pos + cB; _elemStart = pos + cB + ((Int(c) + 7) >> 3)
        } else { count = 0; _bsStart = -1; _elemStart = -1 }
    }
    public subscript(_ idx: Int) -> Int64? {
        guard _bsStart >= 0, idx >= 0, idx < count else { return nil }
        let bOff = _bsStart + (idx >> 3)
        if bOff < _data.count && (_data[bOff] >> (idx & 7)) & 1 != 0 { return nil }
        return try? Int64.restore(from: _data, at: _elemStart + idx * 8)
    }
}

public struct VtableF32ArrayAccessor {
    private let _data: Foundation.Data; private let _elemStart: Int; public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) { count = Int(c); _elemStart = pos + cB }
        else { count = 0; _elemStart = -1 }
    }
    public subscript(_ idx: Int) -> Float {
        guard _elemStart >= 0, idx >= 0, idx < count else { return 0 }
        return (try? Float.restore(from: _data, at: _elemStart + idx * 4)) ?? 0
    }
}
public struct VtableF32OptArrayAccessor {
    private let _data: Foundation.Data; private let _bsStart: Int; private let _elemStart: Int; public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) {
            count = Int(c); _bsStart = pos + cB; _elemStart = pos + cB + ((Int(c) + 7) >> 3)
        } else { count = 0; _bsStart = -1; _elemStart = -1 }
    }
    public subscript(_ idx: Int) -> Float? {
        guard _bsStart >= 0, idx >= 0, idx < count else { return nil }
        let bOff = _bsStart + (idx >> 3)
        if bOff < _data.count && (_data[bOff] >> (idx & 7)) & 1 != 0 { return nil }
        return try? Float.restore(from: _data, at: _elemStart + idx * 4)
    }
}

public struct VtableF16ArrayAccessor {
    private let _data: Foundation.Data; private let _elemStart: Int; public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) { count = Int(c); _elemStart = pos + cB }
        else { count = 0; _elemStart = -1 }
    }
    public subscript(_ idx: Int) -> Float {
        guard _elemStart >= 0, idx >= 0, idx < count else { return 0 }
        guard let bits = try? UInt16.restore(from: _data, at: _elemStart + idx * 2) else { return 0 }
        return _f16BitsToF32(bits)
    }
}
public struct VtableF16OptArrayAccessor {
    private let _data: Foundation.Data; private let _bsStart: Int; private let _elemStart: Int; public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) {
            count = Int(c); _bsStart = pos + cB; _elemStart = pos + cB + ((Int(c) + 7) >> 3)
        } else { count = 0; _bsStart = -1; _elemStart = -1 }
    }
    public subscript(_ idx: Int) -> Float? {
        guard _bsStart >= 0, idx >= 0, idx < count else { return nil }
        let bOff = _bsStart + (idx >> 3)
        if bOff < _data.count && (_data[bOff] >> (idx & 7)) & 1 != 0 { return nil }
        guard let bits = try? UInt16.restore(from: _data, at: _elemStart + idx * 2) else { return nil }
        return _f16BitsToF32(bits)
    }
}

public struct VtableBf16ArrayAccessor {
    private let _data: Foundation.Data; private let _elemStart: Int; public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) { count = Int(c); _elemStart = pos + cB }
        else { count = 0; _elemStart = -1 }
    }
    public subscript(_ idx: Int) -> Float {
        guard _elemStart >= 0, idx >= 0, idx < count else { return 0 }
        guard let bits = try? UInt16.restore(from: _data, at: _elemStart + idx * 2) else { return 0 }
        return _bf16BitsToF32(bits)
    }
}
public struct VtableBf16OptArrayAccessor {
    private let _data: Foundation.Data; private let _bsStart: Int; private let _elemStart: Int; public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) {
            count = Int(c); _bsStart = pos + cB; _elemStart = pos + cB + ((Int(c) + 7) >> 3)
        } else { count = 0; _bsStart = -1; _elemStart = -1 }
    }
    public subscript(_ idx: Int) -> Float? {
        guard _bsStart >= 0, idx >= 0, idx < count else { return nil }
        let bOff = _bsStart + (idx >> 3)
        if bOff < _data.count && (_data[bOff] >> (idx & 7)) & 1 != 0 { return nil }
        guard let bits = try? UInt16.restore(from: _data, at: _elemStart + idx * 2) else { return nil }
        return _bf16BitsToF32(bits)
    }
}

public struct VtableF64ArrayAccessor {
    private let _data: Foundation.Data; private let _elemStart: Int; public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) { count = Int(c); _elemStart = pos + cB }
        else { count = 0; _elemStart = -1 }
    }
    public subscript(_ idx: Int) -> Double {
        guard _elemStart >= 0, idx >= 0, idx < count else { return 0 }
        return (try? Double.restore(from: _data, at: _elemStart + idx * 8)) ?? 0
    }
}
public struct VtableF64OptArrayAccessor {
    private let _data: Foundation.Data; private let _bsStart: Int; private let _elemStart: Int; public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) {
            count = Int(c); _bsStart = pos + cB; _elemStart = pos + cB + ((Int(c) + 7) >> 3)
        } else { count = 0; _bsStart = -1; _elemStart = -1 }
    }
    public subscript(_ idx: Int) -> Double? {
        guard _bsStart >= 0, idx >= 0, idx < count else { return nil }
        let bOff = _bsStart + (idx >> 3)
        if bOff < _data.count && (_data[bOff] >> (idx & 7)) & 1 != 0 { return nil }
        return try? Double.restore(from: _data, at: _elemStart + idx * 8)
    }
}

// Plain (required-element) utf8/data arrays: elements are always present → non-optional.
// A 0 slot (which cannot occur for a required array) or malformed data yields "" / empty Data.
public struct VtableUtf8ArrayAccessor {
    private let _data: Foundation.Data
    private let _slotStart: Int
    private let _es: Int
    private let _base: Int
    public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (hdr, hLen) = try? restoreLEB(from: data, at: pos) {
            count = Int(hdr >> 2); let es = [1,2,4,8][Int(hdr&3)]
            _slotStart = pos + hLen; _es = es; _base = pos + hLen + count * es
        } else { count = 0; _slotStart = -1; _es = 1; _base = 0 }
    }
    public subscript(_ idx: Int) -> String {
        guard _slotStart >= 0, idx >= 0, idx < count else { return "" }
        guard let ro = try? readRelOffset(from: _data, at: _slotStart + idx * _es, size: _es), ro != 0 else { return "" }
        return (try? String.restore(from: _data, at: _base + Int(ro) - 1)) ?? ""
    }
}

public struct VtableDataArrayAccessor {
    private let _data: Foundation.Data
    private let _slotStart: Int
    private let _es: Int
    private let _base: Int
    public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (hdr, hLen) = try? restoreLEB(from: data, at: pos) {
            count = Int(hdr >> 2); let es = [1,2,4,8][Int(hdr&3)]
            _slotStart = pos + hLen; _es = es; _base = pos + hLen + count * es
        } else { count = 0; _slotStart = -1; _es = 1; _base = 0 }
    }
    public subscript(_ idx: Int) -> Foundation.Data {
        guard _slotStart >= 0, idx >= 0, idx < count else { return Foundation.Data() }
        guard let ro = try? readRelOffset(from: _data, at: _slotStart + idx * _es, size: _es), ro != 0 else { return Foundation.Data() }
        return (try? Foundation.Data.restore(from: _data, at: _base + Int(ro) - 1)) ?? Foundation.Data()
    }
}

// arrayWithOptionals utf8/data: a 0 slot decodes to nil → optional element.
public struct VtableUtf8OptArrayAccessor {
    private let _data: Foundation.Data
    private let _slotStart: Int
    private let _es: Int
    private let _base: Int
    public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (hdr, hLen) = try? restoreLEB(from: data, at: pos) {
            count = Int(hdr >> 2); let es = [1,2,4,8][Int(hdr&3)]
            _slotStart = pos + hLen; _es = es; _base = pos + hLen + count * es
        } else { count = 0; _slotStart = -1; _es = 1; _base = 0 }
    }
    public subscript(_ idx: Int) -> String? {
        guard _slotStart >= 0, idx >= 0, idx < count else { return nil }
        guard let ro = try? readRelOffset(from: _data, at: _slotStart + idx * _es, size: _es), ro != 0 else { return nil }
        return try? String.restore(from: _data, at: _base + Int(ro) - 1)
    }
}

public struct VtableDataOptArrayAccessor {
    private let _data: Foundation.Data
    private let _slotStart: Int
    private let _es: Int
    private let _base: Int
    public let count: Int
    public init(_ data: Foundation.Data, at pos: Int) {
        _data = data
        if pos >= 0, let (hdr, hLen) = try? restoreLEB(from: data, at: pos) {
            count = Int(hdr >> 2); let es = [1,2,4,8][Int(hdr&3)]
            _slotStart = pos + hLen; _es = es; _base = pos + hLen + count * es
        } else { count = 0; _slotStart = -1; _es = 1; _base = 0 }
    }
    public subscript(_ idx: Int) -> Foundation.Data? {
        guard _slotStart >= 0, idx >= 0, idx < count else { return nil }
        guard let ro = try? readRelOffset(from: _data, at: _slotStart + idx * _es, size: _es), ro != 0 else { return nil }
        return try? Foundation.Data.restore(from: _data, at: _base + Int(ro) - 1)
    }
}

// ── Sequence conformance for the fixed-layout array accessors ──────────────────
// Every Packed*/Vtable* array accessor above exposes `count` + an integer `subscript`.
// This protocol lifts that pair into a `Sequence`, so the standard combinators
// (`map`, `filter`, `reduce`, `compactMap`, `forEach`, `for … in`, …) work directly
// on the lazy accessor without first materializing an array. `Element` is the
// accessor's own subscript type (non-optional for packed numeric arrays, optional for
// the AWO / vtable variants). Accessors whose subscript must seek from element 0 (packed
// utf8/data, self-describing floats, LEB/mixed ints, every packed optional-element array)
// also provide a forward walk (`_walkStart`/`_walkNext`), so a traversal is O(n) in total;
// the rest iterate by their O(1) subscript. Random access by subscript is unchanged.
public struct DagrWalk {
    public var p: Int   // byte position of the next element's payload; -1 once malformed
    public var a: Int   // accessor-specific (bitset base)
    public var b: Int   // accessor-specific (encoding tag / bitset length)
    @inlinable public init(_ p: Int, _ a: Int = 0, _ b: Int = 0) { self.p = p; self.a = a; self.b = b }
}
public protocol DagrArrayAccessorSequence: Sequence {
    associatedtype Value
    var count: Int { get }
    subscript(_ idx: Int) -> Value { get }
    /// Start of a forward walk, or nil when the subscript is already O(1).
    func _walkStart() -> DagrWalk?
    /// Decode element `idx` (the walk's next element) and advance the walk past it.
    func _walkNext(_ w: inout DagrWalk, _ idx: Int) -> Value
}
// @inlinable so the iterator is specialized in the CALLER's module (`Array(acc)`, `for … in`,
// `map`): across a module boundary an opaque generic `next()` costs ~4× the element decode.
public struct DagrArrayAccessorIterator<A: DagrArrayAccessorSequence>: IteratorProtocol {
    @usableFromInline let _acc: A
    @usableFromInline let _count: Int
    @usableFromInline var _walk: DagrWalk?
    @usableFromInline var _i = 0
    @inlinable init(_ acc: A) { _acc = acc; _count = acc.count; _walk = _count > 0 ? acc._walkStart() : nil }
    @inlinable public mutating func next() -> A.Value? {
        guard _i < _count else { return nil }
        defer { _i += 1 }
        if _walk != nil { return _acc._walkNext(&_walk!, _i) }
        return _acc[_i]
    }
}
public extension DagrArrayAccessorSequence {
    @inlinable func makeIterator() -> DagrArrayAccessorIterator<Self> { DagrArrayAccessorIterator(self) }
    @inlinable var underestimatedCount: Int { count }
    func _walkStart() -> DagrWalk? { nil }
    func _walkNext(_ w: inout DagrWalk, _ idx: Int) -> Value { self[idx] }
}

// Forward-walk helpers shared by the packed accessors below.
@inline(__always) func _bitSet(_ data: Foundation.Data, _ base: Int, _ i: Int) -> Bool {
    base + i / 8 < data.count && (data[base + i / 8] >> (i % 8)) & 1 != 0
}
// Length-prefixed utf8/data element at the walk: returns its byte range and advances.
@inline(__always) func _walkBlob(_ data: Foundation.Data, _ w: inout DagrWalk) -> Range<Int>? {
    guard w.p >= 0, let (len, lB) = try? restoreLEB(from: data, at: w.p) else { w.p = -1; return nil }
    let s = w.p + lB, e = s + Int(len)
    guard e <= data.count else { w.p = -1; return nil }
    w.p = e
    return s..<e
}
// Packed int array header → walk (a = enc bitset base, b = tag); nil for tag 1 (all-raw: O(1) subscript).
func _packedIntWalkStart(_ data: Foundation.Data, _ pos: Int) -> DagrWalk? {
    guard pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) else { return nil }
    let count = Int(c) >> 2, tag = Int(c) & 3, enc = pos + cB
    if tag == 1 { return nil }
    return DagrWalk(enc + (tag == 2 ? (count + 7) / 8 : 0), enc, tag)
}
// Optional-element packed int header → walk (a = nil bitset base, b = tag | bitsetLen << 2).
func _packedIntOptWalkStart(_ data: Foundation.Data, _ pos: Int) -> DagrWalk? {
    guard pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) else { return nil }
    let count = Int(c) >> 2, tag = Int(c) & 3, nilStart = pos + cB, bs = (count + 7) / 8
    return DagrWalk(nilStart + bs + (tag == 2 ? bs : 0), nilStart, tag | (bs << 2))
}
// Next int element: (value bits, isRaw) or nil (absent / malformed).
@inline(__always) func _packedIntWalkNext(_ data: Foundation.Data, _ w: inout DagrWalk, _ idx: Int, rawWidth: Int, encBase: Int, tag: Int) -> (UInt64, Bool)? {
    guard w.p >= 0 else { return nil }
    if tag == 1 || (tag == 2 && _bitSet(data, encBase, idx)) {
        guard let r = _readRawLE(from: data, at: w.p, width: rawWidth) else { w.p = -1; return nil }
        w.p += rawWidth
        return (r, true)
    }
    guard let (v, vB) = try? restoreLEB(from: data, at: w.p) else { w.p = -1; return nil }
    w.p += vB
    return (v, false)
}

// Raw-mode array store (floats §5.2 mode 1, `raw` ints spec/39): the elements are native-LE
// and stored back-to-front, i.e. forward in the buffer — one contiguous store, byte-identical
// to storing each element in reverse.
@inline(__always) public func _dagrStoreRawArray<T>(_ a: [T], with builder: any ArenaBuilder) throws {
    try a.withUnsafeBytes { b in if b.count > 0 { _ = try builder.store(rawPointer: b.baseAddress!, size: b.count) } }
}

extension PackedBoolArrayAccessor: DagrArrayAccessorSequence {}
extension PackedU8ArrayAccessor: DagrArrayAccessorSequence {}
extension PackedI8ArrayAccessor: DagrArrayAccessorSequence {}
extension PackedU16ArrayAccessor: DagrArrayAccessorSequence {
    public func _walkStart() -> DagrWalk? { _packedIntWalkStart(_data, _pos) }
    public func _walkNext(_ w: inout DagrWalk, _ idx: Int) -> UInt16 {
        guard let (v, isRaw) = _packedIntWalkNext(_data, &w, idx, rawWidth: 2, encBase: w.a, tag: w.b) else { return 0 }
        if isRaw { let _raw = v; return UInt16(truncatingIfNeeded: _raw) }
        return UInt16(truncatingIfNeeded: v)
    }
}
extension PackedI16ArrayAccessor: DagrArrayAccessorSequence {
    public func _walkStart() -> DagrWalk? { _packedIntWalkStart(_data, _pos) }
    public func _walkNext(_ w: inout DagrWalk, _ idx: Int) -> Int16 {
        guard let (v, isRaw) = _packedIntWalkNext(_data, &w, idx, rawWidth: 2, encBase: w.a, tag: w.b) else { return 0 }
        if isRaw { let _raw = v; return Int16(bitPattern: UInt16(truncatingIfNeeded: _raw)) }
        return Int16(truncatingIfNeeded: v.fromZigZag)
    }
}
extension PackedU32ArrayAccessor: DagrArrayAccessorSequence {
    public func _walkStart() -> DagrWalk? { _packedIntWalkStart(_data, _pos) }
    public func _walkNext(_ w: inout DagrWalk, _ idx: Int) -> UInt32 {
        guard let (v, isRaw) = _packedIntWalkNext(_data, &w, idx, rawWidth: 4, encBase: w.a, tag: w.b) else { return 0 }
        if isRaw { let _raw = v; return UInt32(truncatingIfNeeded: _raw) }
        return UInt32(truncatingIfNeeded: v)
    }
}
extension PackedI32ArrayAccessor: DagrArrayAccessorSequence {
    public func _walkStart() -> DagrWalk? { _packedIntWalkStart(_data, _pos) }
    public func _walkNext(_ w: inout DagrWalk, _ idx: Int) -> Int32 {
        guard let (v, isRaw) = _packedIntWalkNext(_data, &w, idx, rawWidth: 4, encBase: w.a, tag: w.b) else { return 0 }
        if isRaw { let _raw = v; return Int32(bitPattern: UInt32(truncatingIfNeeded: _raw)) }
        return Int32(truncatingIfNeeded: v.fromZigZag)
    }
}
extension PackedU64ArrayAccessor: DagrArrayAccessorSequence {
    public func _walkStart() -> DagrWalk? { _packedIntWalkStart(_data, _pos) }
    public func _walkNext(_ w: inout DagrWalk, _ idx: Int) -> UInt64 {
        guard let (v, isRaw) = _packedIntWalkNext(_data, &w, idx, rawWidth: 8, encBase: w.a, tag: w.b) else { return 0 }
        if isRaw { let _raw = v; return UInt64(truncatingIfNeeded: _raw) }
        return UInt64(truncatingIfNeeded: v)
    }
}
extension PackedI64ArrayAccessor: DagrArrayAccessorSequence {
    public func _walkStart() -> DagrWalk? { _packedIntWalkStart(_data, _pos) }
    public func _walkNext(_ w: inout DagrWalk, _ idx: Int) -> Int64 {
        guard let (v, isRaw) = _packedIntWalkNext(_data, &w, idx, rawWidth: 8, encBase: w.a, tag: w.b) else { return 0 }
        if isRaw { let _raw = v; return Int64(bitPattern: UInt64(truncatingIfNeeded: _raw)) }
        return Int64(truncatingIfNeeded: v.fromZigZag)
    }
}
extension PackedF32ArrayAccessor: DagrArrayAccessorSequence {
    public func _walkStart() -> DagrWalk? { _mode == 1 ? nil : DagrWalk(_start) }
    public func _walkNext(_ w: inout DagrWalk, _ idx: Int) -> Float {
        guard w.p >= 0, let (v, vB) = try? _decodePackedFloat32(from: _data, at: w.p) else { w.p = -1; return 0 }
        w.p += vB
        return v
    }
}
extension PackedF64ArrayAccessor: DagrArrayAccessorSequence {
    public func _walkStart() -> DagrWalk? { _mode == 1 ? nil : DagrWalk(_start) }
    public func _walkNext(_ w: inout DagrWalk, _ idx: Int) -> Double {
        guard w.p >= 0, let (v, vB) = try? _decodePackedFloat64(from: _data, at: w.p) else { w.p = -1; return 0 }
        w.p += vB
        return v
    }
}
extension PackedF16ArrayAccessor: DagrArrayAccessorSequence {
    public func _walkStart() -> DagrWalk? { DagrWalk(_start + (count + 7) / 8, _start) }
    public func _walkNext(_ w: inout DagrWalk, _ idx: Int) -> Float {
        guard w.p >= 0 else { return 0 }
        if _bitSet(_data, w.a, idx) {
            guard w.p + 1 < _data.count else { w.p = -1; return 0 }
            let bits = UInt16(_data[w.p]) | (UInt16(_data[w.p + 1]) << 8)
            w.p += 2
            return _f16BitsToF32(bits)
        }
        let v = (try? _decodePackedF16(from: _data, at: w.p))?.0 ?? 0
        w.p += 1
        return v
    }
}
extension PackedBf16ArrayAccessor: DagrArrayAccessorSequence {
    public func _walkStart() -> DagrWalk? { DagrWalk(_start + (count + 7) / 8, _start) }
    public func _walkNext(_ w: inout DagrWalk, _ idx: Int) -> Float {
        guard w.p >= 0 else { return 0 }
        if _bitSet(_data, w.a, idx) {
            guard w.p + 1 < _data.count else { w.p = -1; return 0 }
            let bits = UInt16(_data[w.p]) | (UInt16(_data[w.p + 1]) << 8)
            w.p += 2
            return _bf16BitsToF32(bits)
        }
        let v = (try? _decodePackedF16(from: _data, at: w.p))?.0 ?? 0
        w.p += 1
        return v
    }
}
extension PackedUtf8ArrayAccessor: DagrArrayAccessorSequence {
    public func _walkStart() -> DagrWalk? { DagrWalk(_start) }
    public func _walkNext(_ w: inout DagrWalk, _ idx: Int) -> String {
        guard let r = _walkBlob(_data, &w) else { return "" }
        return _dagrUTF8(_data[r])
    }
}
extension PackedDataArrayAccessor: DagrArrayAccessorSequence {
    public func _walkStart() -> DagrWalk? { DagrWalk(_start) }
    public func _walkNext(_ w: inout DagrWalk, _ idx: Int) -> Foundation.Data {
        guard let r = _walkBlob(_data, &w) else { return Foundation.Data() }
        return Foundation.Data(_data[r])
    }
}
extension PackedBoolOptArrayAccessor: DagrArrayAccessorSequence {}
extension PackedU8OptArrayAccessor: DagrArrayAccessorSequence {}
extension PackedI8OptArrayAccessor: DagrArrayAccessorSequence {}
extension PackedU16OptArrayAccessor: DagrArrayAccessorSequence {
    public func _walkStart() -> DagrWalk? { _packedIntOptWalkStart(_data, _pos) }
    public func _walkNext(_ w: inout DagrWalk, _ idx: Int) -> UInt16? {
        guard !_bitSet(_data, w.a, idx) else { return nil }
        guard let (v, isRaw) = _packedIntWalkNext(_data, &w, idx, rawWidth: 2, encBase: w.a + (w.b >> 2), tag: w.b & 3) else { return nil }
        if isRaw { let _raw = v; return UInt16(truncatingIfNeeded: _raw) }
        return UInt16(truncatingIfNeeded: v)
    }
}
extension PackedI16OptArrayAccessor: DagrArrayAccessorSequence {
    public func _walkStart() -> DagrWalk? { _packedIntOptWalkStart(_data, _pos) }
    public func _walkNext(_ w: inout DagrWalk, _ idx: Int) -> Int16? {
        guard !_bitSet(_data, w.a, idx) else { return nil }
        guard let (v, isRaw) = _packedIntWalkNext(_data, &w, idx, rawWidth: 2, encBase: w.a + (w.b >> 2), tag: w.b & 3) else { return nil }
        if isRaw { let _raw = v; return Int16(bitPattern: UInt16(truncatingIfNeeded: _raw)) }
        return Int16(truncatingIfNeeded: v.fromZigZag)
    }
}
extension PackedU32OptArrayAccessor: DagrArrayAccessorSequence {
    public func _walkStart() -> DagrWalk? { _packedIntOptWalkStart(_data, _pos) }
    public func _walkNext(_ w: inout DagrWalk, _ idx: Int) -> UInt32? {
        guard !_bitSet(_data, w.a, idx) else { return nil }
        guard let (v, isRaw) = _packedIntWalkNext(_data, &w, idx, rawWidth: 4, encBase: w.a + (w.b >> 2), tag: w.b & 3) else { return nil }
        if isRaw { let _raw = v; return UInt32(truncatingIfNeeded: _raw) }
        return UInt32(truncatingIfNeeded: v)
    }
}
extension PackedI32OptArrayAccessor: DagrArrayAccessorSequence {
    public func _walkStart() -> DagrWalk? { _packedIntOptWalkStart(_data, _pos) }
    public func _walkNext(_ w: inout DagrWalk, _ idx: Int) -> Int32? {
        guard !_bitSet(_data, w.a, idx) else { return nil }
        guard let (v, isRaw) = _packedIntWalkNext(_data, &w, idx, rawWidth: 4, encBase: w.a + (w.b >> 2), tag: w.b & 3) else { return nil }
        if isRaw { let _raw = v; return Int32(bitPattern: UInt32(truncatingIfNeeded: _raw)) }
        return Int32(truncatingIfNeeded: v.fromZigZag)
    }
}
extension PackedU64OptArrayAccessor: DagrArrayAccessorSequence {
    public func _walkStart() -> DagrWalk? { _packedIntOptWalkStart(_data, _pos) }
    public func _walkNext(_ w: inout DagrWalk, _ idx: Int) -> UInt64? {
        guard !_bitSet(_data, w.a, idx) else { return nil }
        guard let (v, isRaw) = _packedIntWalkNext(_data, &w, idx, rawWidth: 8, encBase: w.a + (w.b >> 2), tag: w.b & 3) else { return nil }
        if isRaw { let _raw = v; return UInt64(truncatingIfNeeded: _raw) }
        return UInt64(truncatingIfNeeded: v)
    }
}
extension PackedI64OptArrayAccessor: DagrArrayAccessorSequence {
    public func _walkStart() -> DagrWalk? { _packedIntOptWalkStart(_data, _pos) }
    public func _walkNext(_ w: inout DagrWalk, _ idx: Int) -> Int64? {
        guard !_bitSet(_data, w.a, idx) else { return nil }
        guard let (v, isRaw) = _packedIntWalkNext(_data, &w, idx, rawWidth: 8, encBase: w.a + (w.b >> 2), tag: w.b & 3) else { return nil }
        if isRaw { let _raw = v; return Int64(bitPattern: UInt64(truncatingIfNeeded: _raw)) }
        return Int64(truncatingIfNeeded: v.fromZigZag)
    }
}
extension PackedF32OptArrayAccessor: DagrArrayAccessorSequence {
    public func _walkStart() -> DagrWalk? { DagrWalk(_start + (count + 7) / 8, _start) }
    public func _walkNext(_ w: inout DagrWalk, _ idx: Int) -> Float? {
        guard !_bitSet(_data, w.a, idx), w.p >= 0 else { return nil }
        if _mode == 1 {
            guard let r = _readRawLE(from: _data, at: w.p, width: 4) else { w.p = -1; return nil }
            w.p += 4
            return Float(bitPattern: UInt32(truncatingIfNeeded: r))
        }
        guard let (v, vB) = try? _decodePackedFloat32(from: _data, at: w.p) else { w.p = -1; return nil }
        w.p += vB
        return v
    }
}
extension PackedF64OptArrayAccessor: DagrArrayAccessorSequence {
    public func _walkStart() -> DagrWalk? { DagrWalk(_start + (count + 7) / 8, _start) }
    public func _walkNext(_ w: inout DagrWalk, _ idx: Int) -> Double? {
        guard !_bitSet(_data, w.a, idx), w.p >= 0 else { return nil }
        if _mode == 1 {
            guard let r = _readRawLE(from: _data, at: w.p, width: 8) else { w.p = -1; return nil }
            w.p += 8
            return Double(bitPattern: r)
        }
        guard let (v, vB) = try? _decodePackedFloat64(from: _data, at: w.p) else { w.p = -1; return nil }
        w.p += vB
        return v
    }
}
extension PackedF16OptArrayAccessor: DagrArrayAccessorSequence {
    public func _walkStart() -> DagrWalk? { DagrWalk(_start + (count + 7) / 8, _start) }
    public func _walkNext(_ w: inout DagrWalk, _ idx: Int) -> Float? {
        guard !_bitSet(_data, w.a, idx), w.p >= 0 else { return nil }
        guard w.p + 1 < _data.count else { w.p = -1; return nil }
        let bits = UInt16(_data[w.p]) | (UInt16(_data[w.p + 1]) << 8)
        w.p += 2
        return _f16BitsToF32(bits)
    }
}
extension PackedBf16OptArrayAccessor: DagrArrayAccessorSequence {
    public func _walkStart() -> DagrWalk? { DagrWalk(_start + (count + 7) / 8, _start) }
    public func _walkNext(_ w: inout DagrWalk, _ idx: Int) -> Float? {
        guard !_bitSet(_data, w.a, idx), w.p >= 0 else { return nil }
        guard w.p + 1 < _data.count else { w.p = -1; return nil }
        let bits = UInt16(_data[w.p]) | (UInt16(_data[w.p + 1]) << 8)
        w.p += 2
        return _bf16BitsToF32(bits)
    }
}
extension PackedUtf8OptArrayAccessor: DagrArrayAccessorSequence {
    public func _walkStart() -> DagrWalk? { DagrWalk(_start + (count + 7) / 8, _start) }
    public func _walkNext(_ w: inout DagrWalk, _ idx: Int) -> String? {
        guard !_bitSet(_data, w.a, idx), let r = _walkBlob(_data, &w) else { return nil }
        return _dagrUTF8(_data[r])
    }
}
extension PackedDataOptArrayAccessor: DagrArrayAccessorSequence {
    public func _walkStart() -> DagrWalk? { DagrWalk(_start + (count + 7) / 8, _start) }
    public func _walkNext(_ w: inout DagrWalk, _ idx: Int) -> Foundation.Data? {
        guard !_bitSet(_data, w.a, idx), let r = _walkBlob(_data, &w) else { return nil }
        return Foundation.Data(_data[r])
    }
}
extension VtableBoolArrayAccessor: DagrArrayAccessorSequence {}
extension VtableBoolOptArrayAccessor: DagrArrayAccessorSequence {}
extension VtableU8ArrayAccessor: DagrArrayAccessorSequence {}
extension VtableU8OptArrayAccessor: DagrArrayAccessorSequence {}
extension VtableI8ArrayAccessor: DagrArrayAccessorSequence {}
extension VtableI8OptArrayAccessor: DagrArrayAccessorSequence {}
extension VtableU16ArrayAccessor: DagrArrayAccessorSequence {}
extension VtableU16OptArrayAccessor: DagrArrayAccessorSequence {}
extension VtableI16ArrayAccessor: DagrArrayAccessorSequence {}
extension VtableI16OptArrayAccessor: DagrArrayAccessorSequence {}
extension VtableU32ArrayAccessor: DagrArrayAccessorSequence {}
extension VtableU32OptArrayAccessor: DagrArrayAccessorSequence {}
extension VtableI32ArrayAccessor: DagrArrayAccessorSequence {}
extension VtableI32OptArrayAccessor: DagrArrayAccessorSequence {}
extension VtableU64ArrayAccessor: DagrArrayAccessorSequence {}
extension VtableU64OptArrayAccessor: DagrArrayAccessorSequence {}
extension VtableI64ArrayAccessor: DagrArrayAccessorSequence {}
extension VtableI64OptArrayAccessor: DagrArrayAccessorSequence {}
extension VtableF32ArrayAccessor: DagrArrayAccessorSequence {}
extension VtableF32OptArrayAccessor: DagrArrayAccessorSequence {}
extension VtableF16ArrayAccessor: DagrArrayAccessorSequence {}
extension VtableF16OptArrayAccessor: DagrArrayAccessorSequence {}
extension VtableBf16ArrayAccessor: DagrArrayAccessorSequence {}
extension VtableBf16OptArrayAccessor: DagrArrayAccessorSequence {}
extension VtableF64ArrayAccessor: DagrArrayAccessorSequence {}
extension VtableF64OptArrayAccessor: DagrArrayAccessorSequence {}
extension VtableUtf8ArrayAccessor: DagrArrayAccessorSequence {}
extension VtableDataArrayAccessor: DagrArrayAccessorSequence {}
extension VtableUtf8OptArrayAccessor: DagrArrayAccessorSequence {}
extension VtableDataOptArrayAccessor: DagrArrayAccessorSequence {}

// ── DataSink runtime types ────────────────────────────────────────────────────

public protocol SinkDestination {
    mutating func write(_ bytes: Foundation.Data) throws
    mutating func flush() throws
}

public protocol AsyncSinkDestination: AnyObject, Sendable {
    func write(_ bytes: Foundation.Data) async throws
    func flush() async throws
}

public struct BufferDestination: SinkDestination, Sendable {
    public private(set) var buffer = Foundation.Data()
    public init() {}
    public mutating func write(_ bytes: Foundation.Data) throws { buffer.append(bytes) }
    public mutating func flush() throws {}
}

// ── DataSink stream introspection ("spec/34-meta-records-and-stream-introspection.md") ──

/// One appended / read sink record's byte range, RELATIVE to `recordsStart` (the byte
/// after the framing word and optional header). `end` is exclusive and includes the
/// trailing RLEB span on a doubly-linked sink, so consecutive ranges tile the record region.
public struct SinkRecordRange: Sendable, Hashable {
    public let typeId: Int
    public let start: Int
    public let end: Int
    public init(typeId: Int, start: Int, end: Int) { self.typeId = typeId; self.start = start; self.end = end }
    public var count: Int { end - start }
    /// 34 §4.2 — a meta record (about the stream, not in it).
    public var isMeta: Bool { isMetaTypeId(typeId) }
}

/// Reserved meta-record typeId band (34 §2.1): `meta_types[i]` ↔ `metaTypeIdBase + i`.
public let metaTypeIdBase = 16384
public let metaTypeIdEnd = 32767

/// 34 §4.2 — true iff `typeId` addresses a meta record.
@inline(__always) public func isMetaTypeId(_ typeId: Int) -> Bool { typeId >= metaTypeIdBase && typeId <= metaTypeIdEnd }

public func encodeLEB128(_ value: UInt64) -> Foundation.Data {
    if value == 0 { return Foundation.Data([0]) }
    var bytes: [UInt8] = []
    var v = value
    while v > 0 {
        var b = UInt8(v & 0x7F)
        v >>= 7
        if v > 0 { b |= 0x80 }
        bytes.append(b)
    }
    return Foundation.Data(bytes)
}

@inline(__always)
public func encodeLEB128(_ value: Int) -> Foundation.Data { encodeLEB128(UInt64(value)) }
