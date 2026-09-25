import Foundation

public enum DocumentFrozenPackedGraph {
    public struct DocumentMetaValues {
        public var region: String? = nil
        public var version: Int32? = nil
    }

    public struct DocumentItemValues {
        public var sku: String? = nil
        public var qty: Int32? = nil
        public var price_minor: Int64? = nil
    }

    public struct DocumentValues {
        public var id: String? = nil
        public var status: Int32? = nil
        public var meta: UInt64? = nil
        public var items: [UInt64] = []
    }

    public protocol DocumentMetaArena: AnyObject {
        static var documentMetaTypeId: Int { get }
        var arenaOfDocumentMeta: [DocumentMetaValues] { get set }
    }

    public protocol DocumentItemArena: AnyObject {
        static var documentItemTypeId: Int { get }
        var arenaOfDocumentItem: [DocumentItemValues] { get set }
    }

    public protocol DocumentArena: AnyObject {
        static var documentTypeId: Int { get }
        var arenaOfDocument: [DocumentValues] { get set }
    }

    public typealias DocumentFrozenPackedGraphGraph = DocumentArena & DocumentItemArena & DocumentMetaArena
    public typealias DocumentMetaGraph = DocumentMetaArena
    public typealias DocumentItemGraph = DocumentItemArena
    public typealias DocumentGraph = DocumentArena & DocumentItemArena & DocumentMetaArena

    public struct DocumentMeta<Arena: DocumentMetaGraph> {
        let __packed: UInt64
        unowned let __graph: Arena

        var __index: Int { Int(__packed & 0x0000_00FF_FFFF_FFFF) }
        var _generation: UInt32 { UInt32(__packed >> 40) }
        var _index: Int { __index }
        var _arenaId: ObjectIdentifier { ObjectIdentifier(__graph) }

        public var region: String? {
            get { __graph.arenaOfDocumentMeta[__index].region }
            nonmutating set { __graph.arenaOfDocumentMeta[__index].region = newValue }
        }
        public var version: Int32? {
            get { __graph.arenaOfDocumentMeta[__index].version }
            nonmutating set { __graph.arenaOfDocumentMeta[__index].version = newValue }
        }
    }

    public struct DocumentItem<Arena: DocumentItemGraph> {
        let __packed: UInt64
        unowned let __graph: Arena

        var __index: Int { Int(__packed & 0x0000_00FF_FFFF_FFFF) }
        var _generation: UInt32 { UInt32(__packed >> 40) }
        var _index: Int { __index }
        var _arenaId: ObjectIdentifier { ObjectIdentifier(__graph) }

        public var sku: String? {
            get { __graph.arenaOfDocumentItem[__index].sku }
            nonmutating set { __graph.arenaOfDocumentItem[__index].sku = newValue }
        }
        public var qty: Int32? {
            get { __graph.arenaOfDocumentItem[__index].qty }
            nonmutating set { __graph.arenaOfDocumentItem[__index].qty = newValue }
        }
        public var price_minor: Int64? {
            get { __graph.arenaOfDocumentItem[__index].price_minor }
            nonmutating set { __graph.arenaOfDocumentItem[__index].price_minor = newValue }
        }
    }

    public struct Document<Arena: DocumentGraph> {
        let __packed: UInt64
        unowned let __graph: Arena

        var __index: Int { Int(__packed & 0x0000_00FF_FFFF_FFFF) }
        var _generation: UInt32 { UInt32(__packed >> 40) }
        var _index: Int { __index }
        var _arenaId: ObjectIdentifier { ObjectIdentifier(__graph) }

        public var id: String? {
            get { __graph.arenaOfDocument[__index].id }
            nonmutating set { __graph.arenaOfDocument[__index].id = newValue }
        }
        public var status: Int32? {
            get { __graph.arenaOfDocument[__index].status }
            nonmutating set { __graph.arenaOfDocument[__index].status = newValue }
        }
        public var meta: DocumentMeta<Arena>? {
            get {
                guard let _stored = __graph.arenaOfDocument[__index].meta else { return nil }
                return DocumentMeta(__packed: _stored, __graph: __graph)
            }
            nonmutating set { __graph.arenaOfDocument[__index].meta = newValue?.__packed }
        }
        public var items: [DocumentItem<Arena>] {
            get {
                return __graph.arenaOfDocument[__index].items.map { DocumentItem(__packed: $0, __graph: __graph) }
            }
            nonmutating set { __graph.arenaOfDocument[__index].items = newValue.map { $0.__packed } }
        }
    }

    // ── Arena<Brand> ─────────────────────────────────────────────────────────────────
    //
    // Brand is a phantom type — declare an empty enum per arena scope:
    //
    //   enum MyBrand {}
    //   let arena = DocumentFrozenPackedGraph.Arena<MyBrand>()
    //
    public class Arena<Brand>: DocumentMetaArena, DocumentItemArena, DocumentArena {
        public static var documentMetaTypeId: Int { 0 }
        public var arenaOfDocumentMeta: [DocumentMetaValues] = []
        public static var documentItemTypeId: Int { 1 }
        public var arenaOfDocumentItem: [DocumentItemValues] = []
        public static var documentTypeId: Int { 2 }
        public var arenaOfDocument: [DocumentValues] = []
        public init() {}

        private var _root: UInt64? = nil
        public var root: Document<Arena<Brand>>? {
            get { _root.map { Document(__packed: $0, __graph: self) } }
            set { _root = newValue?.__packed }
        }
    }


}

extension DocumentFrozenPackedGraph.Arena {
    public func newDocumentMeta(region: String? = nil, version: Int32? = nil) -> DocumentFrozenPackedGraph.DocumentMeta<DocumentFrozenPackedGraph.Arena<Brand>> {
        let _idx: Int
        _idx = arenaOfDocumentMeta.count
        arenaOfDocumentMeta.append(DocumentFrozenPackedGraph.DocumentMetaValues(region: region, version: version))
        let _packed = UInt64(_idx)
        return DocumentFrozenPackedGraph.DocumentMeta(__packed: _packed, __graph: self)
    }
}

extension DocumentFrozenPackedGraph.Arena {
    public func newDocumentItem(sku: String? = nil, qty: Int32? = nil, price_minor: Int64? = nil) -> DocumentFrozenPackedGraph.DocumentItem<DocumentFrozenPackedGraph.Arena<Brand>> {
        let _idx: Int
        _idx = arenaOfDocumentItem.count
        arenaOfDocumentItem.append(DocumentFrozenPackedGraph.DocumentItemValues(sku: sku, qty: qty, price_minor: price_minor))
        let _packed = UInt64(_idx)
        return DocumentFrozenPackedGraph.DocumentItem(__packed: _packed, __graph: self)
    }
}

extension DocumentFrozenPackedGraph.Arena {
    public func newDocument(id: String? = nil, status: Int32? = nil, meta: DocumentFrozenPackedGraph.DocumentMeta<DocumentFrozenPackedGraph.Arena<Brand>>? = nil, items: [DocumentFrozenPackedGraph.DocumentItem<DocumentFrozenPackedGraph.Arena<Brand>>] = []) -> DocumentFrozenPackedGraph.Document<DocumentFrozenPackedGraph.Arena<Brand>> {
        let _idx: Int
        _idx = arenaOfDocument.count
        arenaOfDocument.append(DocumentFrozenPackedGraph.DocumentValues(id: id, status: status, meta: meta?.__packed, items: items.map { $0.__packed }))
        let _packed = UInt64(_idx)
        return DocumentFrozenPackedGraph.Document(__packed: _packed, __graph: self)
    }
}

extension DocumentFrozenPackedGraph.Arena {
    public func adopt<S: DocumentFrozenPackedGraph.DocumentMetaGraph>(_ src: DocumentFrozenPackedGraph.DocumentMeta<S>) throws -> DocumentFrozenPackedGraph.DocumentMeta<DocumentFrozenPackedGraph.Arena<Brand>> {
        var _seen = Set<UInt64>()
        return try _adopt(src, &_seen)
    }
    func _adopt<S: DocumentFrozenPackedGraph.DocumentMetaGraph>(_ src: DocumentFrozenPackedGraph.DocumentMeta<S>, _ _seen: inout Set<UInt64>) throws -> DocumentFrozenPackedGraph.DocumentMeta<DocumentFrozenPackedGraph.Arena<Brand>> {
        guard _seen.insert((UInt64(0) << 48) | UInt64(src._index)).inserted else { throw DagrError.cyclicAdopt }
        defer { _seen.remove((UInt64(0) << 48) | UInt64(src._index)) }
        return newDocumentMeta(region: src.region, version: src.version)
    }
}

extension DocumentFrozenPackedGraph.Arena {
    public func adopt<S: DocumentFrozenPackedGraph.DocumentItemGraph>(_ src: DocumentFrozenPackedGraph.DocumentItem<S>) throws -> DocumentFrozenPackedGraph.DocumentItem<DocumentFrozenPackedGraph.Arena<Brand>> {
        var _seen = Set<UInt64>()
        return try _adopt(src, &_seen)
    }
    func _adopt<S: DocumentFrozenPackedGraph.DocumentItemGraph>(_ src: DocumentFrozenPackedGraph.DocumentItem<S>, _ _seen: inout Set<UInt64>) throws -> DocumentFrozenPackedGraph.DocumentItem<DocumentFrozenPackedGraph.Arena<Brand>> {
        guard _seen.insert((UInt64(1) << 48) | UInt64(src._index)).inserted else { throw DagrError.cyclicAdopt }
        defer { _seen.remove((UInt64(1) << 48) | UInt64(src._index)) }
        return newDocumentItem(sku: src.sku, qty: src.qty, price_minor: src.price_minor)
    }
}

extension DocumentFrozenPackedGraph.Arena {
    public func adopt<S: DocumentFrozenPackedGraph.DocumentGraph>(_ src: DocumentFrozenPackedGraph.Document<S>) throws -> DocumentFrozenPackedGraph.Document<DocumentFrozenPackedGraph.Arena<Brand>> {
        var _seen = Set<UInt64>()
        return try _adopt(src, &_seen)
    }
    func _adopt<S: DocumentFrozenPackedGraph.DocumentGraph>(_ src: DocumentFrozenPackedGraph.Document<S>, _ _seen: inout Set<UInt64>) throws -> DocumentFrozenPackedGraph.Document<DocumentFrozenPackedGraph.Arena<Brand>> {
        guard _seen.insert((UInt64(2) << 48) | UInt64(src._index)).inserted else { throw DagrError.cyclicAdopt }
        defer { _seen.remove((UInt64(2) << 48) | UInt64(src._index)) }
        return newDocument(id: src.id, status: src.status, meta: try src.meta.map { try _adopt($0, &_seen) }, items: try src.items.map { try _adopt($0, &_seen) })
    }
}

extension DocumentFrozenPackedGraph.DocumentMeta: CustomStringConvertible {
    public var description: String {
        var visited = Set<NodeKey>()
        return buildDescription(visited: &visited)
    }

    func buildDescription(visited: inout Set<NodeKey>) -> String {
        let __nodeKey = NodeKey(arena: _arenaId, typeId: Arena.documentMetaTypeId, index: __index)
        guard !visited.contains(__nodeKey) else { return "DocumentMeta@\(__index)" }
        visited.insert(__nodeKey)
        let regionStr = region.map { "\"\($0)\"" } ?? "nil"
        let versionStr = String(describing: version)
        return "DocumentMeta@\(__index) { region: \(regionStr), version: \(versionStr) }"
    }
}

extension DocumentFrozenPackedGraph.DocumentItem: CustomStringConvertible {
    public var description: String {
        var visited = Set<NodeKey>()
        return buildDescription(visited: &visited)
    }

    func buildDescription(visited: inout Set<NodeKey>) -> String {
        let __nodeKey = NodeKey(arena: _arenaId, typeId: Arena.documentItemTypeId, index: __index)
        guard !visited.contains(__nodeKey) else { return "DocumentItem@\(__index)" }
        visited.insert(__nodeKey)
        let skuStr = sku.map { "\"\($0)\"" } ?? "nil"
        let qtyStr = String(describing: qty)
        let price_minorStr = String(describing: price_minor)
        return "DocumentItem@\(__index) { sku: \(skuStr), qty: \(qtyStr), price_minor: \(price_minorStr) }"
    }
}

extension DocumentFrozenPackedGraph.Document: CustomStringConvertible {
    public var description: String {
        var visited = Set<NodeKey>()
        return buildDescription(visited: &visited)
    }

    func buildDescription(visited: inout Set<NodeKey>) -> String {
        let __nodeKey = NodeKey(arena: _arenaId, typeId: Arena.documentTypeId, index: __index)
        guard !visited.contains(__nodeKey) else { return "Document@\(__index)" }
        visited.insert(__nodeKey)
        let idStr = id.map { "\"\($0)\"" } ?? "nil"
        let statusStr = String(describing: status)
        let metaStr = meta.map { $0.buildDescription(visited: &visited) } ?? "nil"
        let itemsStr = "[" + items.map { $0.buildDescription(visited: &visited) }.joined(separator: ", ") + "]"
        return "Document@\(__index) { id: \(idStr), status: \(statusStr), meta: \(metaStr), items: \(itemsStr) }"
    }
}

extension DocumentFrozenPackedGraph.DocumentMeta: Hashable {
    public func hash(into hasher: inout Hasher) {
        var visited = Set<NodeKey>()
        hashInto(hasher: &hasher, visited: &visited)
    }

    func hashInto(hasher: inout Hasher, visited: inout Set<NodeKey>) {
        let __nodeKey = NodeKey(arena: _arenaId, typeId: Arena.documentMetaTypeId, index: __index)
        guard !visited.contains(__nodeKey) else { return }
        visited.insert(__nodeKey)
        hasher.combine(region)
        hasher.combine(version)
    }
}

extension DocumentFrozenPackedGraph.DocumentItem: Hashable {
    public func hash(into hasher: inout Hasher) {
        var visited = Set<NodeKey>()
        hashInto(hasher: &hasher, visited: &visited)
    }

    func hashInto(hasher: inout Hasher, visited: inout Set<NodeKey>) {
        let __nodeKey = NodeKey(arena: _arenaId, typeId: Arena.documentItemTypeId, index: __index)
        guard !visited.contains(__nodeKey) else { return }
        visited.insert(__nodeKey)
        hasher.combine(sku)
        hasher.combine(qty)
        hasher.combine(price_minor)
    }
}

extension DocumentFrozenPackedGraph.Document: Hashable {
    public func hash(into hasher: inout Hasher) {
        var visited = Set<NodeKey>()
        hashInto(hasher: &hasher, visited: &visited)
    }

    func hashInto(hasher: inout Hasher, visited: inout Set<NodeKey>) {
        let __nodeKey = NodeKey(arena: _arenaId, typeId: Arena.documentTypeId, index: __index)
        guard !visited.contains(__nodeKey) else { return }
        visited.insert(__nodeKey)
        hasher.combine(id)
        hasher.combine(status)
        meta?.hashInto(hasher: &hasher, visited: &visited)
        for item in items { item.hashInto(hasher: &hasher, visited: &visited) }
    }
}

extension DocumentFrozenPackedGraph.DocumentMeta: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        var visited = Set<ArenaPair>()
        return lhs.cycleAwareEquals(other: rhs, visited: &visited)
    }

    func cycleAwareEquals(other: Self, visited: inout Set<ArenaPair>) -> Bool {
        let pair = ArenaPair(
            leftArena: _arenaId, leftTypeId: Arena.documentMetaTypeId, leftIndex: __index,
            rightArena: other._arenaId, rightTypeId: Arena.documentMetaTypeId, rightIndex: other.__index
        )
        guard !visited.contains(pair) else { return true }
        visited.insert(pair)
        guard self.region == other.region else { return false }
        guard self.version == other.version else { return false }
        return true
    }
}

extension DocumentFrozenPackedGraph.DocumentMeta {
    public static func == <OtherArena: DocumentFrozenPackedGraph.DocumentMetaGraph>(lhs: Self, rhs: DocumentFrozenPackedGraph.DocumentMeta<OtherArena>) -> Bool {
        var visited = Set<ArenaPair>()
        return lhs.cycleAwareEqualsAny(other: rhs, visited: &visited)
    }

    public static func != <OtherArena: DocumentFrozenPackedGraph.DocumentMetaGraph>(lhs: Self, rhs: DocumentFrozenPackedGraph.DocumentMeta<OtherArena>) -> Bool {
        return !(lhs == rhs)
    }

    func cycleAwareEqualsAny<OtherArena: DocumentFrozenPackedGraph.DocumentMetaGraph>(
        other: DocumentFrozenPackedGraph.DocumentMeta<OtherArena>,
        visited: inout Set<ArenaPair>
    ) -> Bool {
        let pair = ArenaPair(
            leftArena: _arenaId, leftTypeId: Arena.documentMetaTypeId, leftIndex: __index,
            rightArena: other._arenaId, rightTypeId: OtherArena.documentMetaTypeId, rightIndex: other.__index
        )
        guard !visited.contains(pair) else { return true }
        visited.insert(pair)
        guard self.region == other.region else { return false }
        guard self.version == other.version else { return false }
        return true
    }
}

extension DocumentFrozenPackedGraph.DocumentItem: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        var visited = Set<ArenaPair>()
        return lhs.cycleAwareEquals(other: rhs, visited: &visited)
    }

    func cycleAwareEquals(other: Self, visited: inout Set<ArenaPair>) -> Bool {
        let pair = ArenaPair(
            leftArena: _arenaId, leftTypeId: Arena.documentItemTypeId, leftIndex: __index,
            rightArena: other._arenaId, rightTypeId: Arena.documentItemTypeId, rightIndex: other.__index
        )
        guard !visited.contains(pair) else { return true }
        visited.insert(pair)
        guard self.sku == other.sku else { return false }
        guard self.qty == other.qty else { return false }
        guard self.price_minor == other.price_minor else { return false }
        return true
    }
}

extension DocumentFrozenPackedGraph.DocumentItem {
    public static func == <OtherArena: DocumentFrozenPackedGraph.DocumentItemGraph>(lhs: Self, rhs: DocumentFrozenPackedGraph.DocumentItem<OtherArena>) -> Bool {
        var visited = Set<ArenaPair>()
        return lhs.cycleAwareEqualsAny(other: rhs, visited: &visited)
    }

    public static func != <OtherArena: DocumentFrozenPackedGraph.DocumentItemGraph>(lhs: Self, rhs: DocumentFrozenPackedGraph.DocumentItem<OtherArena>) -> Bool {
        return !(lhs == rhs)
    }

    func cycleAwareEqualsAny<OtherArena: DocumentFrozenPackedGraph.DocumentItemGraph>(
        other: DocumentFrozenPackedGraph.DocumentItem<OtherArena>,
        visited: inout Set<ArenaPair>
    ) -> Bool {
        let pair = ArenaPair(
            leftArena: _arenaId, leftTypeId: Arena.documentItemTypeId, leftIndex: __index,
            rightArena: other._arenaId, rightTypeId: OtherArena.documentItemTypeId, rightIndex: other.__index
        )
        guard !visited.contains(pair) else { return true }
        visited.insert(pair)
        guard self.sku == other.sku else { return false }
        guard self.qty == other.qty else { return false }
        guard self.price_minor == other.price_minor else { return false }
        return true
    }
}

extension DocumentFrozenPackedGraph.Document: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        var visited = Set<ArenaPair>()
        return lhs.cycleAwareEquals(other: rhs, visited: &visited)
    }

    func cycleAwareEquals(other: Self, visited: inout Set<ArenaPair>) -> Bool {
        let pair = ArenaPair(
            leftArena: _arenaId, leftTypeId: Arena.documentTypeId, leftIndex: __index,
            rightArena: other._arenaId, rightTypeId: Arena.documentTypeId, rightIndex: other.__index
        )
        guard !visited.contains(pair) else { return true }
        visited.insert(pair)
        guard self.id == other.id else { return false }
        guard self.status == other.status else { return false }
        switch (self.meta, other.meta) {
        case (.none, .none): break
        case (.some(let a), .some(let b)):
            guard a.cycleAwareEquals(other: b, visited: &visited) else { return false }
        default: return false
        }
        let _aitems = self.items, _bitems = other.items
        guard _aitems.count == _bitems.count else { return false }
        guard zip(_aitems, _bitems).allSatisfy({ a, b in a.cycleAwareEquals(other: b, visited: &visited) }) else { return false }
        return true
    }
}

extension DocumentFrozenPackedGraph.Document {
    public static func == <OtherArena: DocumentFrozenPackedGraph.DocumentGraph>(lhs: Self, rhs: DocumentFrozenPackedGraph.Document<OtherArena>) -> Bool {
        var visited = Set<ArenaPair>()
        return lhs.cycleAwareEqualsAny(other: rhs, visited: &visited)
    }

    public static func != <OtherArena: DocumentFrozenPackedGraph.DocumentGraph>(lhs: Self, rhs: DocumentFrozenPackedGraph.Document<OtherArena>) -> Bool {
        return !(lhs == rhs)
    }

    func cycleAwareEqualsAny<OtherArena: DocumentFrozenPackedGraph.DocumentGraph>(
        other: DocumentFrozenPackedGraph.Document<OtherArena>,
        visited: inout Set<ArenaPair>
    ) -> Bool {
        let pair = ArenaPair(
            leftArena: _arenaId, leftTypeId: Arena.documentTypeId, leftIndex: __index,
            rightArena: other._arenaId, rightTypeId: OtherArena.documentTypeId, rightIndex: other.__index
        )
        guard !visited.contains(pair) else { return true }
        visited.insert(pair)
        guard self.id == other.id else { return false }
        guard self.status == other.status else { return false }
        switch (self.meta, other.meta) {
        case (.none, .none): break
        case (.some(let a), .some(let b)):
            guard a.cycleAwareEqualsAny(other: b, visited: &visited) else { return false }
        default: return false
        }
        let _aitems = self.items, _bitems = other.items
        guard _aitems.count == _bitems.count else { return false }
        guard zip(_aitems, _bitems).allSatisfy({ a, b in a.cycleAwareEqualsAny(other: b, visited: &visited) }) else { return false }
        return true
    }
}

extension DocumentFrozenPackedGraph.DocumentMeta: ArenaNodeHandle {}
extension DocumentFrozenPackedGraph.DocumentMeta: ArenaGraphStorable {
    var cycleIdentifier: ArenaCycleIdntifier {
        .init(nodeTypeId: Arena.documentMetaTypeId, nodeIndex: __index)
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
        let _versionPackedResult = try self.version?.storePacked(with: builder)
        _ = try self.region?.storePacked(with: builder)
        var _encByte: UInt8 = 0
        if _versionPackedResult?.isRaw ?? false { _encByte |= 1 }
        _ = try builder.store(number: _encByte)
        var _nilByte: UInt8 = 0
        if self.region != nil { _nilByte |= 1 }
        if self.version != nil { _nilByte |= 2 }
        _ = try builder.store(number: _nilByte)
        _ = try builder.storeAsLEB(value: builder.cursor.value - before.value)
        return builder.finishPackedStoring(nodeId: cycleIdentifier)
    }
}

extension DocumentFrozenPackedGraph.DocumentItem: ArenaNodeHandle {}
extension DocumentFrozenPackedGraph.DocumentItem: ArenaGraphStorable {
    var cycleIdentifier: ArenaCycleIdntifier {
        .init(nodeTypeId: Arena.documentItemTypeId, nodeIndex: __index)
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
        let _price_minorPackedResult = try self.price_minor?.storePacked(with: builder)
        let _qtyPackedResult = try self.qty?.storePacked(with: builder)
        _ = try self.sku?.storePacked(with: builder)
        var _encByte: UInt8 = 0
        if _qtyPackedResult?.isRaw ?? false { _encByte |= 1 }
        if _price_minorPackedResult?.isRaw ?? false { _encByte |= 2 }
        _ = try builder.store(number: _encByte)
        var _nilByte: UInt8 = 0
        if self.sku != nil { _nilByte |= 1 }
        if self.qty != nil { _nilByte |= 2 }
        if self.price_minor != nil { _nilByte |= 4 }
        _ = try builder.store(number: _nilByte)
        _ = try builder.storeAsLEB(value: builder.cursor.value - before.value)
        return builder.finishPackedStoring(nodeId: cycleIdentifier)
    }
}

extension DocumentFrozenPackedGraph.Document: ArenaNodeHandle {}
extension DocumentFrozenPackedGraph.Document: ArenaGraphStorable {
    var cycleIdentifier: ArenaCycleIdntifier {
        .init(nodeTypeId: Arena.documentTypeId, nodeIndex: __index)
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
        _ = try self.items.storePacked(with: builder)
        _ = try self.meta?.storePacked(with: builder)
        let _statusPackedResult = try self.status?.storePacked(with: builder)
        _ = try self.id?.storePacked(with: builder)
        var _encByte: UInt8 = 0
        if _statusPackedResult?.isRaw ?? false { _encByte |= 1 }
        _ = try builder.store(number: _encByte)
        var _nilByte: UInt8 = 0
        if self.id != nil { _nilByte |= 1 }
        if self.status != nil { _nilByte |= 2 }
        if self.meta != nil { _nilByte |= 4 }
        if !self.items.isEmpty { _nilByte |= 8 }
        _ = try builder.store(number: _nilByte)
        _ = try builder.storeAsLEB(value: builder.cursor.value - before.value)
        return builder.finishPackedStoring(nodeId: cycleIdentifier)
    }
}

extension DocumentFrozenPackedGraph.Arena {
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

    public static func restore(from data: Foundation.Data) throws -> DocumentFrozenPackedGraph.Arena<Brand> {
        guard !data.isEmpty else { return DocumentFrozenPackedGraph.Arena<Brand>() }
        let arena = DocumentFrozenPackedGraph.Arena<Brand>()
        let (framing, lebLen) = try restoreLEB(from: data, at: 0)
        guard (framing & 1) == 0 else { throw ArenaRestoreError.missingHeader }
        guard ((framing >> 1) & 1) == 0 else { throw ArenaRestoreError.invalidFraming }
        let rootStart = lebLen + Int(framing >> 2)
        var cache = [Int: Int]()
        arena.root = try arena._restoreDocument(from: data, at: rootStart, cache: &cache)
        return arena
    }

    private func _restoreDocumentMeta(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> DocumentFrozenPackedGraph.DocumentMeta<DocumentFrozenPackedGraph.Arena<Brand>> {
        if let idx = cache[start] { return DocumentFrozenPackedGraph.DocumentMeta(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfDocumentMeta.count
        cache[start] = idx
        arenaOfDocumentMeta.append(DocumentFrozenPackedGraph.DocumentMetaValues())
        var values = DocumentFrozenPackedGraph.DocumentMetaValues()
        let (_, _blB) = try restoreLEB(from: data, at: start)
        var _cur = start + _blB
        let _obs0 = _cur + 0 < data.count ? data[_cur + 0] : UInt8(0)
        _cur += 1
        let _ebs0 = _cur + 0 < data.count ? data[_cur + 0] : UInt8(0)
        _cur += 1
        if _obs0 & 1 != 0 {
            let (_sv_region, _sb_region) = try restoreLEB(from: data, at: _cur); _cur += _sb_region
            values.region = _dagrUTF8(data[_cur..<(_cur + Int(_sv_region))])
            _cur += Int(_sv_region)
        }
        if _obs0 & 2 != 0 {
            if _ebs0 & 1 != 0 {
                values.version = try Int32.restore(from: data, at: _cur); _cur += 4
            } else {
                let (_lv_version, _lb_version) = try restoreLEB(from: data, at: _cur)
                values.version = Int32(_lv_version.fromZigZag); _cur += _lb_version
            }
        }
        arenaOfDocumentMeta[idx] = values
        return DocumentFrozenPackedGraph.DocumentMeta(__packed: UInt64(idx), __graph: self)
    }

    private func _restoreDocumentItem(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> DocumentFrozenPackedGraph.DocumentItem<DocumentFrozenPackedGraph.Arena<Brand>> {
        if let idx = cache[start] { return DocumentFrozenPackedGraph.DocumentItem(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfDocumentItem.count
        cache[start] = idx
        arenaOfDocumentItem.append(DocumentFrozenPackedGraph.DocumentItemValues())
        var values = DocumentFrozenPackedGraph.DocumentItemValues()
        let (_, _blB) = try restoreLEB(from: data, at: start)
        var _cur = start + _blB
        let _obs0 = _cur + 0 < data.count ? data[_cur + 0] : UInt8(0)
        _cur += 1
        let _ebs0 = _cur + 0 < data.count ? data[_cur + 0] : UInt8(0)
        _cur += 1
        if _obs0 & 1 != 0 {
            let (_sv_sku, _sb_sku) = try restoreLEB(from: data, at: _cur); _cur += _sb_sku
            values.sku = _dagrUTF8(data[_cur..<(_cur + Int(_sv_sku))])
            _cur += Int(_sv_sku)
        }
        if _obs0 & 2 != 0 {
            if _ebs0 & 1 != 0 {
                values.qty = try Int32.restore(from: data, at: _cur); _cur += 4
            } else {
                let (_lv_qty, _lb_qty) = try restoreLEB(from: data, at: _cur)
                values.qty = Int32(_lv_qty.fromZigZag); _cur += _lb_qty
            }
        }
        if _obs0 & 4 != 0 {
            if _ebs0 & 2 != 0 {
                values.price_minor = try Int64.restore(from: data, at: _cur); _cur += 8
            } else {
                let (_lv_price_minor, _lb_price_minor) = try restoreLEB(from: data, at: _cur)
                values.price_minor = Int64(_lv_price_minor.fromZigZag); _cur += _lb_price_minor
            }
        }
        arenaOfDocumentItem[idx] = values
        return DocumentFrozenPackedGraph.DocumentItem(__packed: UInt64(idx), __graph: self)
    }

    private func _restoreDocument(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> DocumentFrozenPackedGraph.Document<DocumentFrozenPackedGraph.Arena<Brand>> {
        if let idx = cache[start] { return DocumentFrozenPackedGraph.Document(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfDocument.count
        cache[start] = idx
        arenaOfDocument.append(DocumentFrozenPackedGraph.DocumentValues())
        var values = DocumentFrozenPackedGraph.DocumentValues()
        let (_, _blB) = try restoreLEB(from: data, at: start)
        var _cur = start + _blB
        let _obs0 = _cur + 0 < data.count ? data[_cur + 0] : UInt8(0)
        _cur += 1
        let _ebs0 = _cur + 0 < data.count ? data[_cur + 0] : UInt8(0)
        _cur += 1
        if _obs0 & 1 != 0 {
            let (_sv_id, _sb_id) = try restoreLEB(from: data, at: _cur); _cur += _sb_id
            values.id = _dagrUTF8(data[_cur..<(_cur + Int(_sv_id))])
            _cur += Int(_sv_id)
        }
        if _obs0 & 2 != 0 {
            if _ebs0 & 1 != 0 {
                values.status = try Int32.restore(from: data, at: _cur); _cur += 4
            } else {
                let (_lv_status, _lb_status) = try restoreLEB(from: data, at: _cur)
                values.status = Int32(_lv_status.fromZigZag); _cur += _lb_status
            }
        }
        if _obs0 & 4 != 0 {
            let (_bl_meta, _blB_meta) = try restoreLEB(from: data, at: _cur)
            values.meta = try _restoreDocumentMeta(from: data, at: _cur, cache: &cache).__packed
            _cur += _blB_meta + Int(_bl_meta)
        }
        let (_bbl_items, _bblB_items) = try restoreLEB(from: data, at: _cur)
        let _bend_items = _cur + _bblB_items + Int(_bbl_items)
        _cur += _bblB_items
        let (_cnt_items, _cntB_items) = try restoreLEB(from: data, at: _cur)
        _cur += _cntB_items
        var _arr_items = [UInt64]()
        for _ in 0..<Int(_cnt_items) {
            let (_el_bl_items, _el_blB_items) = try restoreLEB(from: data, at: _cur)
            _arr_items.append(try _restoreDocumentItem(from: data, at: _cur, cache: &cache).__packed)
            _cur += _el_blB_items + Int(_el_bl_items)
        }
        values.items = _arr_items
        _cur = _bend_items
        arenaOfDocument[idx] = values
        return DocumentFrozenPackedGraph.Document(__packed: UInt64(idx), __graph: self)
    }

}


// ── Direct Graph Builder ("spec/33-direct-graph-builder.md") ─────────────────────
// Arena-free construction for this packed-rooted tree: value structs in,
// byte-identical graph buffer out. `Direct.toData*(v) == Arena.toData*()`.
extension DocumentFrozenPackedGraph {
    public enum Direct {
        public struct DocumentMeta: ArenaGraphStorable {
            public var region: String?
            public var version: Int32?
            public init(region: String? = nil, version: Int32? = nil) {
                self.region = region
                self.version = version
            }
            public func store(with builder: any ArenaBuilder) throws -> BufferOffset {
                _ = try storePacked(with: builder)
                return builder.cursor
            }
            public func storePacked(with builder: any ArenaBuilder) throws -> PackedStoreResult {
                let before = builder.cursor
        let _versionPackedResult = try self.version?.storePacked(with: builder)
        _ = try self.region?.storePacked(with: builder)
        var _encByte: UInt8 = 0
        if _versionPackedResult?.isRaw ?? false { _encByte |= 1 }
        _ = try builder.store(number: _encByte)
        var _nilByte: UInt8 = 0
        if self.region != nil { _nilByte |= 1 }
        if self.version != nil { _nilByte |= 2 }
        _ = try builder.store(number: _nilByte)
                _ = try builder.storeAsLEB(value: builder.cursor.value - before.value)
                return .raw(0)
            }
        }

        public struct DocumentItem: ArenaGraphStorable {
            public var sku: String?
            public var qty: Int32?
            public var price_minor: Int64?
            public init(sku: String? = nil, qty: Int32? = nil, price_minor: Int64? = nil) {
                self.sku = sku
                self.qty = qty
                self.price_minor = price_minor
            }
            public func store(with builder: any ArenaBuilder) throws -> BufferOffset {
                _ = try storePacked(with: builder)
                return builder.cursor
            }
            public func storePacked(with builder: any ArenaBuilder) throws -> PackedStoreResult {
                let before = builder.cursor
        let _price_minorPackedResult = try self.price_minor?.storePacked(with: builder)
        let _qtyPackedResult = try self.qty?.storePacked(with: builder)
        _ = try self.sku?.storePacked(with: builder)
        var _encByte: UInt8 = 0
        if _qtyPackedResult?.isRaw ?? false { _encByte |= 1 }
        if _price_minorPackedResult?.isRaw ?? false { _encByte |= 2 }
        _ = try builder.store(number: _encByte)
        var _nilByte: UInt8 = 0
        if self.sku != nil { _nilByte |= 1 }
        if self.qty != nil { _nilByte |= 2 }
        if self.price_minor != nil { _nilByte |= 4 }
        _ = try builder.store(number: _nilByte)
                _ = try builder.storeAsLEB(value: builder.cursor.value - before.value)
                return .raw(0)
            }
        }

        public struct Document: ArenaGraphStorable {
            public var id: String?
            public var status: Int32?
            public var meta: DocumentMeta?
            public var items: [DocumentItem]
            public init(id: String? = nil, status: Int32? = nil, meta: DocumentMeta? = nil, items: [DocumentItem] = []) {
                self.id = id
                self.status = status
                self.meta = meta
                self.items = items
            }
            public func store(with builder: any ArenaBuilder) throws -> BufferOffset {
                _ = try storePacked(with: builder)
                return builder.cursor
            }
            public func storePacked(with builder: any ArenaBuilder) throws -> PackedStoreResult {
                let before = builder.cursor
        _ = try self.items.storePacked(with: builder)
        _ = try self.meta?.storePacked(with: builder)
        let _statusPackedResult = try self.status?.storePacked(with: builder)
        _ = try self.id?.storePacked(with: builder)
        var _encByte: UInt8 = 0
        if _statusPackedResult?.isRaw ?? false { _encByte |= 1 }
        _ = try builder.store(number: _encByte)
        var _nilByte: UInt8 = 0
        if self.id != nil { _nilByte |= 1 }
        if self.status != nil { _nilByte |= 2 }
        if self.meta != nil { _nilByte |= 4 }
        if !self.items.isEmpty { _nilByte |= 8 }
        _ = try builder.store(number: _nilByte)
                _ = try builder.storeAsLEB(value: builder.cursor.value - before.value)
                return .raw(0)
            }
        }

        public static func toData(_ root: Document) throws -> Foundation.Data {
            let builder = DataArenaBuilder()
            let rootOffset = try root.store(with: builder)
            _ = try builder.storeAsLEB(value: (builder.cursor.value - rootOffset.value) << 2)
            return builder.makeData
        }
    }
}
