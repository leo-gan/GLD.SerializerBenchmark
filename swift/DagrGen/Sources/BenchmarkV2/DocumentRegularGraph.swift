import Foundation

public enum DocumentRegularGraph {
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

    public typealias DocumentRegularGraphGraph = DocumentArena & DocumentItemArena & DocumentMetaArena
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
    //   let arena = DocumentRegularGraph.Arena<MyBrand>()
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

extension DocumentRegularGraph.Arena {
    public func newDocumentMeta(region: String? = nil, version: Int32? = nil) -> DocumentRegularGraph.DocumentMeta<DocumentRegularGraph.Arena<Brand>> {
        let _idx: Int
        _idx = arenaOfDocumentMeta.count
        arenaOfDocumentMeta.append(DocumentRegularGraph.DocumentMetaValues(region: region, version: version))
        let _packed = UInt64(_idx)
        return DocumentRegularGraph.DocumentMeta(__packed: _packed, __graph: self)
    }
}

extension DocumentRegularGraph.Arena {
    public func newDocumentItem(sku: String? = nil, qty: Int32? = nil, price_minor: Int64? = nil) -> DocumentRegularGraph.DocumentItem<DocumentRegularGraph.Arena<Brand>> {
        let _idx: Int
        _idx = arenaOfDocumentItem.count
        arenaOfDocumentItem.append(DocumentRegularGraph.DocumentItemValues(sku: sku, qty: qty, price_minor: price_minor))
        let _packed = UInt64(_idx)
        return DocumentRegularGraph.DocumentItem(__packed: _packed, __graph: self)
    }
}

extension DocumentRegularGraph.Arena {
    public func newDocument(id: String? = nil, status: Int32? = nil, meta: DocumentRegularGraph.DocumentMeta<DocumentRegularGraph.Arena<Brand>>? = nil, items: [DocumentRegularGraph.DocumentItem<DocumentRegularGraph.Arena<Brand>>] = []) -> DocumentRegularGraph.Document<DocumentRegularGraph.Arena<Brand>> {
        let _idx: Int
        _idx = arenaOfDocument.count
        arenaOfDocument.append(DocumentRegularGraph.DocumentValues(id: id, status: status, meta: meta?.__packed, items: items.map { $0.__packed }))
        let _packed = UInt64(_idx)
        return DocumentRegularGraph.Document(__packed: _packed, __graph: self)
    }
}

extension DocumentRegularGraph.Arena {
    public func adopt<S: DocumentRegularGraph.DocumentMetaGraph>(_ src: DocumentRegularGraph.DocumentMeta<S>) throws -> DocumentRegularGraph.DocumentMeta<DocumentRegularGraph.Arena<Brand>> {
        var _seen = Set<UInt64>()
        return try _adopt(src, &_seen)
    }
    func _adopt<S: DocumentRegularGraph.DocumentMetaGraph>(_ src: DocumentRegularGraph.DocumentMeta<S>, _ _seen: inout Set<UInt64>) throws -> DocumentRegularGraph.DocumentMeta<DocumentRegularGraph.Arena<Brand>> {
        guard _seen.insert((UInt64(0) << 48) | UInt64(src._index)).inserted else { throw DagrError.cyclicAdopt }
        defer { _seen.remove((UInt64(0) << 48) | UInt64(src._index)) }
        return newDocumentMeta(region: src.region, version: src.version)
    }
}

extension DocumentRegularGraph.Arena {
    public func adopt<S: DocumentRegularGraph.DocumentItemGraph>(_ src: DocumentRegularGraph.DocumentItem<S>) throws -> DocumentRegularGraph.DocumentItem<DocumentRegularGraph.Arena<Brand>> {
        var _seen = Set<UInt64>()
        return try _adopt(src, &_seen)
    }
    func _adopt<S: DocumentRegularGraph.DocumentItemGraph>(_ src: DocumentRegularGraph.DocumentItem<S>, _ _seen: inout Set<UInt64>) throws -> DocumentRegularGraph.DocumentItem<DocumentRegularGraph.Arena<Brand>> {
        guard _seen.insert((UInt64(1) << 48) | UInt64(src._index)).inserted else { throw DagrError.cyclicAdopt }
        defer { _seen.remove((UInt64(1) << 48) | UInt64(src._index)) }
        return newDocumentItem(sku: src.sku, qty: src.qty, price_minor: src.price_minor)
    }
}

extension DocumentRegularGraph.Arena {
    public func adopt<S: DocumentRegularGraph.DocumentGraph>(_ src: DocumentRegularGraph.Document<S>) throws -> DocumentRegularGraph.Document<DocumentRegularGraph.Arena<Brand>> {
        var _seen = Set<UInt64>()
        return try _adopt(src, &_seen)
    }
    func _adopt<S: DocumentRegularGraph.DocumentGraph>(_ src: DocumentRegularGraph.Document<S>, _ _seen: inout Set<UInt64>) throws -> DocumentRegularGraph.Document<DocumentRegularGraph.Arena<Brand>> {
        guard _seen.insert((UInt64(2) << 48) | UInt64(src._index)).inserted else { throw DagrError.cyclicAdopt }
        defer { _seen.remove((UInt64(2) << 48) | UInt64(src._index)) }
        return newDocument(id: src.id, status: src.status, meta: try src.meta.map { try _adopt($0, &_seen) }, items: try src.items.map { try _adopt($0, &_seen) })
    }
}

extension DocumentRegularGraph.DocumentMeta: CustomStringConvertible {
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

extension DocumentRegularGraph.DocumentItem: CustomStringConvertible {
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

extension DocumentRegularGraph.Document: CustomStringConvertible {
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

extension DocumentRegularGraph.DocumentMeta: Hashable {
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

extension DocumentRegularGraph.DocumentItem: Hashable {
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

extension DocumentRegularGraph.Document: Hashable {
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

extension DocumentRegularGraph.DocumentMeta: Equatable {
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

extension DocumentRegularGraph.DocumentMeta {
    public static func == <OtherArena: DocumentRegularGraph.DocumentMetaGraph>(lhs: Self, rhs: DocumentRegularGraph.DocumentMeta<OtherArena>) -> Bool {
        var visited = Set<ArenaPair>()
        return lhs.cycleAwareEqualsAny(other: rhs, visited: &visited)
    }

    public static func != <OtherArena: DocumentRegularGraph.DocumentMetaGraph>(lhs: Self, rhs: DocumentRegularGraph.DocumentMeta<OtherArena>) -> Bool {
        return !(lhs == rhs)
    }

    func cycleAwareEqualsAny<OtherArena: DocumentRegularGraph.DocumentMetaGraph>(
        other: DocumentRegularGraph.DocumentMeta<OtherArena>,
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

extension DocumentRegularGraph.DocumentItem: Equatable {
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

extension DocumentRegularGraph.DocumentItem {
    public static func == <OtherArena: DocumentRegularGraph.DocumentItemGraph>(lhs: Self, rhs: DocumentRegularGraph.DocumentItem<OtherArena>) -> Bool {
        var visited = Set<ArenaPair>()
        return lhs.cycleAwareEqualsAny(other: rhs, visited: &visited)
    }

    public static func != <OtherArena: DocumentRegularGraph.DocumentItemGraph>(lhs: Self, rhs: DocumentRegularGraph.DocumentItem<OtherArena>) -> Bool {
        return !(lhs == rhs)
    }

    func cycleAwareEqualsAny<OtherArena: DocumentRegularGraph.DocumentItemGraph>(
        other: DocumentRegularGraph.DocumentItem<OtherArena>,
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

extension DocumentRegularGraph.Document: Equatable {
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

extension DocumentRegularGraph.Document {
    public static func == <OtherArena: DocumentRegularGraph.DocumentGraph>(lhs: Self, rhs: DocumentRegularGraph.Document<OtherArena>) -> Bool {
        var visited = Set<ArenaPair>()
        return lhs.cycleAwareEqualsAny(other: rhs, visited: &visited)
    }

    public static func != <OtherArena: DocumentRegularGraph.DocumentGraph>(lhs: Self, rhs: DocumentRegularGraph.Document<OtherArena>) -> Bool {
        return !(lhs == rhs)
    }

    func cycleAwareEqualsAny<OtherArena: DocumentRegularGraph.DocumentGraph>(
        other: DocumentRegularGraph.Document<OtherArena>,
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

extension DocumentRegularGraph.DocumentMeta: ArenaNodeHandle {}
extension DocumentRegularGraph.DocumentMeta: ArenaGraphStorable {
    var cycleIdentifier: ArenaCycleIdntifier {
        .init(nodeTypeId: Arena.documentMetaTypeId, nodeIndex: __index)
    }

    public func store(with builder: any ArenaBuilder) throws -> BufferOffset {
        if let offset = try builder.beginStoring(nodeId: cycleIdentifier) {
            return offset
        }
        let _regionValueOffset = try self.region?.store(with: builder)
        let _versionOffset: BufferOffset? = try self.version?.store(with: builder)
        let _regionOffset: BufferOffset? = try _regionValueOffset?.storeForwardPointer(with: builder)
        let offset = try builder.store(vTable: [_regionOffset, _versionOffset])
        try builder.finishStoring(nodeId: cycleIdentifier, offset: offset)
        return offset
    }

    public func storePacked(with builder: any ArenaBuilder) throws -> PackedStoreResult {
        let before = try builder.beginPackedStoring(nodeId: cycleIdentifier)
        _ = try self.version?.storePacked(with: builder).store(index: 1, with: builder)
        _ = try self.region?.storePacked(with: builder).store(index: 0, with: builder)
        _ = try builder.storeAsLEB(value: builder.cursor.value - before.value)
        return builder.finishPackedStoring(nodeId: cycleIdentifier)
    }
}

extension DocumentRegularGraph.DocumentItem: ArenaNodeHandle {}
extension DocumentRegularGraph.DocumentItem: ArenaGraphStorable {
    var cycleIdentifier: ArenaCycleIdntifier {
        .init(nodeTypeId: Arena.documentItemTypeId, nodeIndex: __index)
    }

    public func store(with builder: any ArenaBuilder) throws -> BufferOffset {
        if let offset = try builder.beginStoring(nodeId: cycleIdentifier) {
            return offset
        }
        let _skuValueOffset = try self.sku?.store(with: builder)
        let _price_minorOffset: BufferOffset? = try self.price_minor?.store(with: builder)
        let _qtyOffset: BufferOffset? = try self.qty?.store(with: builder)
        let _skuOffset: BufferOffset? = try _skuValueOffset?.storeForwardPointer(with: builder)
        let offset = try builder.store(vTable: [_skuOffset, _qtyOffset, _price_minorOffset])
        try builder.finishStoring(nodeId: cycleIdentifier, offset: offset)
        return offset
    }

    public func storePacked(with builder: any ArenaBuilder) throws -> PackedStoreResult {
        let before = try builder.beginPackedStoring(nodeId: cycleIdentifier)
        _ = try self.price_minor?.storePacked(with: builder).store(index: 2, with: builder)
        _ = try self.qty?.storePacked(with: builder).store(index: 1, with: builder)
        _ = try self.sku?.storePacked(with: builder).store(index: 0, with: builder)
        _ = try builder.storeAsLEB(value: builder.cursor.value - before.value)
        return builder.finishPackedStoring(nodeId: cycleIdentifier)
    }
}

extension DocumentRegularGraph.Document: ArenaNodeHandle {}
extension DocumentRegularGraph.Document: ArenaGraphStorable {
    var cycleIdentifier: ArenaCycleIdntifier {
        .init(nodeTypeId: Arena.documentTypeId, nodeIndex: __index)
    }

    public func store(with builder: any ArenaBuilder) throws -> BufferOffset {
        if let offset = try builder.beginStoring(nodeId: cycleIdentifier) {
            return offset
        }
        let _itemsValueOffset = try self.items.store(with: builder)
        let _metaValueOffset = try self.meta?.store(with: builder)
        let _idValueOffset = try self.id?.store(with: builder)
        let _itemsOffset: BufferOffset? = try _itemsValueOffset.storeForwardPointer(with: builder)
        let _metaOffset: BufferOffset? = try _metaValueOffset?.storeBidirectionalPointer(with: builder)
        let _statusOffset: BufferOffset? = try self.status?.store(with: builder)
        let _idOffset: BufferOffset? = try _idValueOffset?.storeForwardPointer(with: builder)
        let offset = try builder.store(vTable: [_idOffset, _statusOffset, _metaOffset, _itemsOffset])
        try builder.finishStoring(nodeId: cycleIdentifier, offset: offset)
        return offset
    }

    public func storePacked(with builder: any ArenaBuilder) throws -> PackedStoreResult {
        let before = try builder.beginPackedStoring(nodeId: cycleIdentifier)
        _ = try self.items.storePacked(with: builder).store(index: 3, with: builder)
        _ = try self.meta?.storePacked(with: builder).store(index: 2, with: builder)
        _ = try self.status?.storePacked(with: builder).store(index: 1, with: builder)
        _ = try self.id?.storePacked(with: builder).store(index: 0, with: builder)
        _ = try builder.storeAsLEB(value: builder.cursor.value - before.value)
        return builder.finishPackedStoring(nodeId: cycleIdentifier)
    }
}

extension DocumentRegularGraph.Arena {
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

    public static func restore(from data: Foundation.Data) throws -> DocumentRegularGraph.Arena<Brand> {
        guard !data.isEmpty else { return DocumentRegularGraph.Arena<Brand>() }
        let arena = DocumentRegularGraph.Arena<Brand>()
        let (framing, lebLen) = try restoreLEB(from: data, at: 0)
        guard (framing & 1) == 0 else { throw ArenaRestoreError.missingHeader }
        guard ((framing >> 1) & 1) == 0 else { throw ArenaRestoreError.invalidFraming }
        let rootStart = lebLen + Int(framing >> 2)
        var cache = [Int: Int]()
        arena.root = try arena._restoreDocument(from: data, at: rootStart, cache: &cache)
        return arena
    }

    private func _restoreDocumentMeta(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> DocumentRegularGraph.DocumentMeta<DocumentRegularGraph.Arena<Brand>> {
        if let idx = cache[start] { return DocumentRegularGraph.DocumentMeta(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfDocumentMeta.count
        cache[start] = idx
        arenaOfDocumentMeta.append(DocumentRegularGraph.DocumentMetaValues())
        var values = DocumentRegularGraph.DocumentMetaValues()
        let vtable = try restoreRTypeVTable(from: data, start: start)
        if 0 < vtable.count, let _off0 = vtable[0] {
            let (_fwd0, _fwdb0) = try readV62(from: data, at: start + Int(_off0))
            values.region = try String.restore(from: data, at: start + Int(_off0) + _fwdb0 + Int(_fwd0))
        }
        if 1 < vtable.count, let _off1 = vtable[1] {
            values.version = try Int32.restore(from: data, at: start + Int(_off1))
        }
        arenaOfDocumentMeta[idx] = values
        return DocumentRegularGraph.DocumentMeta(__packed: UInt64(idx), __graph: self)
    }

    private func _restoreDocumentMetaPacked(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> DocumentRegularGraph.DocumentMeta<DocumentRegularGraph.Arena<Brand>> {
        if let idx = cache[start] { return DocumentRegularGraph.DocumentMeta(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfDocumentMeta.count
        cache[start] = idx
        arenaOfDocumentMeta.append(DocumentRegularGraph.DocumentMetaValues())
        var values = DocumentRegularGraph.DocumentMetaValues()
        let (_bl, _blB) = try restoreLEB(from: data, at: start)
        var _cursor = start + _blB
        let _end = _cursor + Int(_bl)
        if _cursor < _end {
            let (_tag, _tagB) = try restoreLEB(from: data, at: _cursor)
            if Int(_tag) >> 1 == 0 {
                _cursor += _tagB
                let (_sv_region, _sb_region) = try restoreLEB(from: data, at: _cursor); _cursor += _sb_region
                values.region = _dagrUTF8(data[_cursor..<(_cursor + Int(_sv_region))]); _cursor += Int(_sv_region)
            }
        }
        if _cursor < _end {
            let (_tag, _tagB) = try restoreLEB(from: data, at: _cursor)
            if Int(_tag) >> 1 == 1 {
                _cursor += _tagB
                if _tag & 1 == 0 {
                    let (_v, _b) = try restoreLEB(from: data, at: _cursor); values.version = Int32(_v.fromZigZag); _cursor += _b
                } else {
                    values.version = try Int32.restore(from: data, at: _cursor); _cursor += 4
                }
            }
        }
        arenaOfDocumentMeta[idx] = values
        return DocumentRegularGraph.DocumentMeta(__packed: UInt64(idx), __graph: self)
    }

    private func _restoreDocumentItem(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> DocumentRegularGraph.DocumentItem<DocumentRegularGraph.Arena<Brand>> {
        if let idx = cache[start] { return DocumentRegularGraph.DocumentItem(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfDocumentItem.count
        cache[start] = idx
        arenaOfDocumentItem.append(DocumentRegularGraph.DocumentItemValues())
        var values = DocumentRegularGraph.DocumentItemValues()
        let vtable = try restoreRTypeVTable(from: data, start: start)
        if 0 < vtable.count, let _off0 = vtable[0] {
            let (_fwd0, _fwdb0) = try readV62(from: data, at: start + Int(_off0))
            values.sku = try String.restore(from: data, at: start + Int(_off0) + _fwdb0 + Int(_fwd0))
        }
        if 1 < vtable.count, let _off1 = vtable[1] {
            values.qty = try Int32.restore(from: data, at: start + Int(_off1))
        }
        if 2 < vtable.count, let _off2 = vtable[2] {
            values.price_minor = try Int64.restore(from: data, at: start + Int(_off2))
        }
        arenaOfDocumentItem[idx] = values
        return DocumentRegularGraph.DocumentItem(__packed: UInt64(idx), __graph: self)
    }

    private func _restoreDocumentItemPacked(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> DocumentRegularGraph.DocumentItem<DocumentRegularGraph.Arena<Brand>> {
        if let idx = cache[start] { return DocumentRegularGraph.DocumentItem(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfDocumentItem.count
        cache[start] = idx
        arenaOfDocumentItem.append(DocumentRegularGraph.DocumentItemValues())
        var values = DocumentRegularGraph.DocumentItemValues()
        let (_bl, _blB) = try restoreLEB(from: data, at: start)
        var _cursor = start + _blB
        let _end = _cursor + Int(_bl)
        if _cursor < _end {
            let (_tag, _tagB) = try restoreLEB(from: data, at: _cursor)
            if Int(_tag) >> 1 == 0 {
                _cursor += _tagB
                let (_sv_sku, _sb_sku) = try restoreLEB(from: data, at: _cursor); _cursor += _sb_sku
                values.sku = _dagrUTF8(data[_cursor..<(_cursor + Int(_sv_sku))]); _cursor += Int(_sv_sku)
            }
        }
        if _cursor < _end {
            let (_tag, _tagB) = try restoreLEB(from: data, at: _cursor)
            if Int(_tag) >> 1 == 1 {
                _cursor += _tagB
                if _tag & 1 == 0 {
                    let (_v, _b) = try restoreLEB(from: data, at: _cursor); values.qty = Int32(_v.fromZigZag); _cursor += _b
                } else {
                    values.qty = try Int32.restore(from: data, at: _cursor); _cursor += 4
                }
            }
        }
        if _cursor < _end {
            let (_tag, _tagB) = try restoreLEB(from: data, at: _cursor)
            if Int(_tag) >> 1 == 2 {
                _cursor += _tagB
                if _tag & 1 == 0 {
                    let (_v, _b) = try restoreLEB(from: data, at: _cursor); values.price_minor = Int64(_v.fromZigZag); _cursor += _b
                } else {
                    values.price_minor = try Int64.restore(from: data, at: _cursor); _cursor += 8
                }
            }
        }
        arenaOfDocumentItem[idx] = values
        return DocumentRegularGraph.DocumentItem(__packed: UInt64(idx), __graph: self)
    }

    private func _restoreDocument(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> DocumentRegularGraph.Document<DocumentRegularGraph.Arena<Brand>> {
        if let idx = cache[start] { return DocumentRegularGraph.Document(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfDocument.count
        cache[start] = idx
        arenaOfDocument.append(DocumentRegularGraph.DocumentValues())
        var values = DocumentRegularGraph.DocumentValues()
        let vtable = try restoreRTypeVTable(from: data, start: start)
        if 0 < vtable.count, let _off0 = vtable[0] {
            let (_fwd0, _fwdb0) = try readV62(from: data, at: start + Int(_off0))
            values.id = try String.restore(from: data, at: start + Int(_off0) + _fwdb0 + Int(_fwd0))
        }
        if 1 < vtable.count, let _off1 = vtable[1] {
            values.status = try Int32.restore(from: data, at: start + Int(_off1))
        }
        if 2 < vtable.count, let _off2 = vtable[2] {
            let (_bd2, _bdb2) = try readZigZagV62(from: data, at: start + Int(_off2))
            values.meta = try _restoreDocumentMeta(from: data, at: start + Int(_off2) + _bdb2 + _bd2, cache: &cache).__packed
        }
        if 3 < vtable.count, let _off3 = vtable[3] {
            let (_fwd3, _fwdb3) = try readV62(from: data, at: start + Int(_off3))
            let (_h3, _hl3) = try restoreLEB(from: data, at: start + Int(_off3) + _fwdb3 + Int(_fwd3))
            let _cnt3 = Int(_h3 >> 2); let _wc3 = Int(_h3 & 3)
            let _es3 = [1,2,4,8][_wc3]
            let _base3 = start + Int(_off3) + _fwdb3 + Int(_fwd3) + _hl3 + _cnt3 * _es3
            var _arr3 = [UInt64]()
            for _k3 in 0..<_cnt3 {
                let _ep3 = start + Int(_off3) + _fwdb3 + Int(_fwd3) + _hl3 + _k3 * _es3
                let _ro3 = try readSignedRelOffset(from: data, at: _ep3, size: _es3)
                if _ro3 != 0 {
                    _arr3.append(try _restoreDocumentItem(from: data, at: _base3 + Int(_ro3) - 1, cache: &cache).__packed)
                }
            }
            values.items = _arr3
        }
        arenaOfDocument[idx] = values
        return DocumentRegularGraph.Document(__packed: UInt64(idx), __graph: self)
    }

    private func _restoreDocumentPacked(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> DocumentRegularGraph.Document<DocumentRegularGraph.Arena<Brand>> {
        if let idx = cache[start] { return DocumentRegularGraph.Document(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfDocument.count
        cache[start] = idx
        arenaOfDocument.append(DocumentRegularGraph.DocumentValues())
        var values = DocumentRegularGraph.DocumentValues()
        let (_bl, _blB) = try restoreLEB(from: data, at: start)
        var _cursor = start + _blB
        let _end = _cursor + Int(_bl)
        if _cursor < _end {
            let (_tag, _tagB) = try restoreLEB(from: data, at: _cursor)
            if Int(_tag) >> 1 == 0 {
                _cursor += _tagB
                let (_sv_id, _sb_id) = try restoreLEB(from: data, at: _cursor); _cursor += _sb_id
                values.id = _dagrUTF8(data[_cursor..<(_cursor + Int(_sv_id))]); _cursor += Int(_sv_id)
            }
        }
        if _cursor < _end {
            let (_tag, _tagB) = try restoreLEB(from: data, at: _cursor)
            if Int(_tag) >> 1 == 1 {
                _cursor += _tagB
                if _tag & 1 == 0 {
                    let (_v, _b) = try restoreLEB(from: data, at: _cursor); values.status = Int32(_v.fromZigZag); _cursor += _b
                } else {
                    values.status = try Int32.restore(from: data, at: _cursor); _cursor += 4
                }
            }
        }
        if _cursor < _end {
            let (_tag, _tagB) = try restoreLEB(from: data, at: _cursor)
            if Int(_tag) >> 1 == 2 {
                _cursor += _tagB
                let (_bbl_meta, _bblB_meta) = try restoreLEB(from: data, at: _cursor)
                values.meta = try _restoreDocumentMetaPacked(from: data, at: _cursor, cache: &cache).__packed
                _cursor += _bblB_meta + Int(_bbl_meta)
            }
        }
        if _cursor < _end {
            let (_tag, _tagB) = try restoreLEB(from: data, at: _cursor)
            if Int(_tag) >> 1 == 3 {
                _cursor += _tagB
                let (_abl_items, _ablB_items) = try restoreLEB(from: data, at: _cursor)
                let _s_items = _cursor + _ablB_items
                let (_cnt_items, _cntB_items) = try restoreLEB(from: data, at: _s_items)
                var _arr_items = [UInt64]()
                var _pos_items = _s_items + _cntB_items
                for _ in 0..<Int(_cnt_items) {
                    let (_nb_items, _nbb_items) = try restoreLEB(from: data, at: _pos_items)
                    let _nd_items = try _restoreDocumentItemPacked(from: data, at: _pos_items, cache: &cache)
                    _arr_items.append(_nd_items.__packed)
                    _pos_items += _nbb_items + Int(_nb_items)
                }
                values.items = _arr_items
                _cursor = _s_items + Int(_abl_items)
            }
        }
        arenaOfDocument[idx] = values
        return DocumentRegularGraph.Document(__packed: UInt64(idx), __graph: self)
    }

}
