import Foundation

public enum DocumentGraph {
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
        public var _swept_items: UInt16 = 0
    }

    public protocol DocumentMetaArena: AnyObject {
        static var documentMetaTypeId: Int { get }
        var arenaOfDocumentMeta: [DocumentMetaValues] { get set }
        var generationOfDocumentMeta: [UInt32] { get set }
        var freeSlotsOfDocumentMeta: [Int] { get set }
    }

    public protocol DocumentItemArena: AnyObject {
        static var documentItemTypeId: Int { get }
        var arenaOfDocumentItem: [DocumentItemValues] { get set }
        var generationOfDocumentItem: [UInt32] { get set }
        var freeSlotsOfDocumentItem: [Int] { get set }
        var _delEpochOfDocumentItem: UInt16 { get set }
    }

    public protocol DocumentArena: AnyObject {
        static var documentTypeId: Int { get }
        var arenaOfDocument: [DocumentValues] { get set }
        var generationOfDocument: [UInt32] { get set }
        var freeSlotsOfDocument: [Int] { get set }
    }

    public typealias DocumentGraphGraph = DocumentArena & DocumentItemArena & DocumentMetaArena
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
        public func delete() {
            let _idx = __index
            guard _generation == __graph.generationOfDocumentMeta[_idx] else { return }
            __graph.arenaOfDocumentMeta[_idx] = DocumentMetaValues()
            __graph.generationOfDocumentMeta[_idx] &+= 1
            __graph.freeSlotsOfDocumentMeta.append(_idx)
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
        public func delete() {
            let _idx = __index
            guard _generation == __graph.generationOfDocumentItem[_idx] else { return }
            __graph.arenaOfDocumentItem[_idx] = DocumentItemValues()
            __graph.generationOfDocumentItem[_idx] &+= 1
            __graph.freeSlotsOfDocumentItem.append(_idx)
            __graph._delEpochOfDocumentItem &+= 1
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
                let _idx = Int(_stored & 0x0000_00FF_FFFF_FFFF)
                guard __graph.generationOfDocumentMeta[_idx] == UInt32(_stored >> 40) else { return nil }
                return DocumentMeta(__packed: _stored, __graph: __graph)
            }
            nonmutating set { __graph.arenaOfDocument[__index].meta = newValue?.__packed }
        }
        public var items: [DocumentItem<Arena>] {
            get {
                let _ep = __graph._delEpochOfDocumentItem
                if __graph.arenaOfDocument[__index]._swept_items == _ep {
                    return __graph.arenaOfDocument[__index].items.map { DocumentItem(__packed: $0, __graph: __graph) }
                }
                let _live = __graph.arenaOfDocument[__index].items.filter { _stored in __graph.generationOfDocumentItem[Int(_stored & 0x0000_00FF_FFFF_FFFF)] == UInt32(_stored >> 40) }
                __graph.arenaOfDocument[__index].items = _live
                __graph.arenaOfDocument[__index]._swept_items = _ep
                return _live.map { DocumentItem(__packed: $0, __graph: __graph) }
            }
            nonmutating set { __graph.arenaOfDocument[__index].items = newValue.map { $0.__packed }; __graph.arenaOfDocument[__index]._swept_items = __graph._delEpochOfDocumentItem &- 1 }
        }
        public func delete() {
            let _idx = __index
            guard _generation == __graph.generationOfDocument[_idx] else { return }
            __graph.arenaOfDocument[_idx] = DocumentValues()
            __graph.generationOfDocument[_idx] &+= 1
            __graph.freeSlotsOfDocument.append(_idx)
        }
    }

    // ── Arena<Brand> ─────────────────────────────────────────────────────────────────
    //
    // Brand is a phantom type — declare an empty enum per arena scope:
    //
    //   enum MyBrand {}
    //   let arena = DocumentGraph.Arena<MyBrand>()
    //
    public class Arena<Brand>: DocumentMetaArena, DocumentItemArena, DocumentArena {
        public static var documentMetaTypeId: Int { 0 }
        public var arenaOfDocumentMeta: [DocumentMetaValues] = []
        public var generationOfDocumentMeta: [UInt32] = []
        public var freeSlotsOfDocumentMeta: [Int] = []
        public static var documentItemTypeId: Int { 1 }
        public var arenaOfDocumentItem: [DocumentItemValues] = []
        public var generationOfDocumentItem: [UInt32] = []
        public var freeSlotsOfDocumentItem: [Int] = []
        public var _delEpochOfDocumentItem: UInt16 = 0
        public static var documentTypeId: Int { 2 }
        public var arenaOfDocument: [DocumentValues] = []
        public var generationOfDocument: [UInt32] = []
        public var freeSlotsOfDocument: [Int] = []
        public init() {}

        private var _root: UInt64? = nil
        public var root: Document<Arena<Brand>>? {
            get { _root.map { Document(__packed: $0, __graph: self) } }
            set { _root = newValue?.__packed }
        }
    }


}

extension DocumentGraph.Arena {
    public func newDocumentMeta(region: String? = nil, version: Int32? = nil) -> DocumentGraph.DocumentMeta<DocumentGraph.Arena<Brand>> {
        let _idx: Int
        if let _free = freeSlotsOfDocumentMeta.popLast() {
            _idx = _free
            arenaOfDocumentMeta[_idx] = DocumentGraph.DocumentMetaValues(region: region, version: version)
        } else {
            _idx = arenaOfDocumentMeta.count
            arenaOfDocumentMeta.append(DocumentGraph.DocumentMetaValues(region: region, version: version))
            generationOfDocumentMeta.append(0)
        }
        let _packed = UInt64(generationOfDocumentMeta[_idx]) << 40 | UInt64(_idx)
        return DocumentGraph.DocumentMeta(__packed: _packed, __graph: self)
    }
}

extension DocumentGraph.Arena {
    public func newDocumentItem(sku: String? = nil, qty: Int32? = nil, price_minor: Int64? = nil) -> DocumentGraph.DocumentItem<DocumentGraph.Arena<Brand>> {
        let _idx: Int
        if let _free = freeSlotsOfDocumentItem.popLast() {
            _idx = _free
            arenaOfDocumentItem[_idx] = DocumentGraph.DocumentItemValues(sku: sku, qty: qty, price_minor: price_minor)
        } else {
            _idx = arenaOfDocumentItem.count
            arenaOfDocumentItem.append(DocumentGraph.DocumentItemValues(sku: sku, qty: qty, price_minor: price_minor))
            generationOfDocumentItem.append(0)
        }
        let _packed = UInt64(generationOfDocumentItem[_idx]) << 40 | UInt64(_idx)
        return DocumentGraph.DocumentItem(__packed: _packed, __graph: self)
    }
}

extension DocumentGraph.Arena {
    public func newDocument(id: String? = nil, status: Int32? = nil, meta: DocumentGraph.DocumentMeta<DocumentGraph.Arena<Brand>>? = nil, items: [DocumentGraph.DocumentItem<DocumentGraph.Arena<Brand>>] = []) -> DocumentGraph.Document<DocumentGraph.Arena<Brand>> {
        let _idx: Int
        if let _free = freeSlotsOfDocument.popLast() {
            _idx = _free
            arenaOfDocument[_idx] = DocumentGraph.DocumentValues(id: id, status: status, meta: meta?.__packed, items: items.map { $0.__packed })
        } else {
            _idx = arenaOfDocument.count
            arenaOfDocument.append(DocumentGraph.DocumentValues(id: id, status: status, meta: meta?.__packed, items: items.map { $0.__packed }))
            generationOfDocument.append(0)
        }
        let _packed = UInt64(generationOfDocument[_idx]) << 40 | UInt64(_idx)
        return DocumentGraph.Document(__packed: _packed, __graph: self)
    }
}

extension DocumentGraph.Arena {
    public func adopt<S: DocumentGraph.DocumentMetaGraph>(_ src: DocumentGraph.DocumentMeta<S>) throws -> DocumentGraph.DocumentMeta<DocumentGraph.Arena<Brand>> {
        var _seen = Set<UInt64>()
        return try _adopt(src, &_seen)
    }
    func _adopt<S: DocumentGraph.DocumentMetaGraph>(_ src: DocumentGraph.DocumentMeta<S>, _ _seen: inout Set<UInt64>) throws -> DocumentGraph.DocumentMeta<DocumentGraph.Arena<Brand>> {
        guard _seen.insert((UInt64(0) << 48) | UInt64(src._index)).inserted else { throw DagrError.cyclicAdopt }
        defer { _seen.remove((UInt64(0) << 48) | UInt64(src._index)) }
        return newDocumentMeta(region: src.region, version: src.version)
    }
}

extension DocumentGraph.Arena {
    public func adopt<S: DocumentGraph.DocumentItemGraph>(_ src: DocumentGraph.DocumentItem<S>) throws -> DocumentGraph.DocumentItem<DocumentGraph.Arena<Brand>> {
        var _seen = Set<UInt64>()
        return try _adopt(src, &_seen)
    }
    func _adopt<S: DocumentGraph.DocumentItemGraph>(_ src: DocumentGraph.DocumentItem<S>, _ _seen: inout Set<UInt64>) throws -> DocumentGraph.DocumentItem<DocumentGraph.Arena<Brand>> {
        guard _seen.insert((UInt64(1) << 48) | UInt64(src._index)).inserted else { throw DagrError.cyclicAdopt }
        defer { _seen.remove((UInt64(1) << 48) | UInt64(src._index)) }
        return newDocumentItem(sku: src.sku, qty: src.qty, price_minor: src.price_minor)
    }
}

extension DocumentGraph.Arena {
    public func adopt<S: DocumentGraph.DocumentGraph>(_ src: DocumentGraph.Document<S>) throws -> DocumentGraph.Document<DocumentGraph.Arena<Brand>> {
        var _seen = Set<UInt64>()
        return try _adopt(src, &_seen)
    }
    func _adopt<S: DocumentGraph.DocumentGraph>(_ src: DocumentGraph.Document<S>, _ _seen: inout Set<UInt64>) throws -> DocumentGraph.Document<DocumentGraph.Arena<Brand>> {
        guard _seen.insert((UInt64(2) << 48) | UInt64(src._index)).inserted else { throw DagrError.cyclicAdopt }
        defer { _seen.remove((UInt64(2) << 48) | UInt64(src._index)) }
        return newDocument(id: src.id, status: src.status, meta: try src.meta.map { try _adopt($0, &_seen) }, items: try src.items.map { try _adopt($0, &_seen) })
    }
}

extension DocumentGraph.Arena {
    public func deleteDocumentMeta(_ node: DocumentGraph.DocumentMeta<DocumentGraph.Arena<Brand>>) {
        let _idx = node._index
        guard node._generation == generationOfDocumentMeta[_idx] else { return }
        arenaOfDocumentMeta[_idx] = DocumentGraph.DocumentMetaValues()
        generationOfDocumentMeta[_idx] &+= 1
        freeSlotsOfDocumentMeta.append(_idx)
    }
}

extension DocumentGraph.Arena {
    public func deleteDocumentItem(_ node: DocumentGraph.DocumentItem<DocumentGraph.Arena<Brand>>) {
        let _idx = node._index
        guard node._generation == generationOfDocumentItem[_idx] else { return }
        arenaOfDocumentItem[_idx] = DocumentGraph.DocumentItemValues()
        generationOfDocumentItem[_idx] &+= 1
        freeSlotsOfDocumentItem.append(_idx)
        _delEpochOfDocumentItem &+= 1
    }
}

extension DocumentGraph.Arena {
    public func deleteDocument(_ node: DocumentGraph.Document<DocumentGraph.Arena<Brand>>) {
        let _idx = node._index
        guard node._generation == generationOfDocument[_idx] else { return }
        arenaOfDocument[_idx] = DocumentGraph.DocumentValues()
        generationOfDocument[_idx] &+= 1
        freeSlotsOfDocument.append(_idx)
    }
}

extension DocumentGraph.DocumentMeta: CustomStringConvertible {
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

extension DocumentGraph.DocumentItem: CustomStringConvertible {
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

extension DocumentGraph.Document: CustomStringConvertible {
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

extension DocumentGraph.DocumentMeta: Hashable {
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

extension DocumentGraph.DocumentItem: Hashable {
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

extension DocumentGraph.Document: Hashable {
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

extension DocumentGraph.DocumentMeta: Equatable {
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

extension DocumentGraph.DocumentMeta {
    public static func == <OtherArena: DocumentGraph.DocumentMetaGraph>(lhs: Self, rhs: DocumentGraph.DocumentMeta<OtherArena>) -> Bool {
        var visited = Set<ArenaPair>()
        return lhs.cycleAwareEqualsAny(other: rhs, visited: &visited)
    }

    public static func != <OtherArena: DocumentGraph.DocumentMetaGraph>(lhs: Self, rhs: DocumentGraph.DocumentMeta<OtherArena>) -> Bool {
        return !(lhs == rhs)
    }

    func cycleAwareEqualsAny<OtherArena: DocumentGraph.DocumentMetaGraph>(
        other: DocumentGraph.DocumentMeta<OtherArena>,
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

extension DocumentGraph.DocumentItem: Equatable {
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

extension DocumentGraph.DocumentItem {
    public static func == <OtherArena: DocumentGraph.DocumentItemGraph>(lhs: Self, rhs: DocumentGraph.DocumentItem<OtherArena>) -> Bool {
        var visited = Set<ArenaPair>()
        return lhs.cycleAwareEqualsAny(other: rhs, visited: &visited)
    }

    public static func != <OtherArena: DocumentGraph.DocumentItemGraph>(lhs: Self, rhs: DocumentGraph.DocumentItem<OtherArena>) -> Bool {
        return !(lhs == rhs)
    }

    func cycleAwareEqualsAny<OtherArena: DocumentGraph.DocumentItemGraph>(
        other: DocumentGraph.DocumentItem<OtherArena>,
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

extension DocumentGraph.Document: Equatable {
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

extension DocumentGraph.Document {
    public static func == <OtherArena: DocumentGraph.DocumentGraph>(lhs: Self, rhs: DocumentGraph.Document<OtherArena>) -> Bool {
        var visited = Set<ArenaPair>()
        return lhs.cycleAwareEqualsAny(other: rhs, visited: &visited)
    }

    public static func != <OtherArena: DocumentGraph.DocumentGraph>(lhs: Self, rhs: DocumentGraph.Document<OtherArena>) -> Bool {
        return !(lhs == rhs)
    }

    func cycleAwareEqualsAny<OtherArena: DocumentGraph.DocumentGraph>(
        other: DocumentGraph.Document<OtherArena>,
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

extension DocumentGraph.DocumentMeta: ArenaNodeHandle {}
extension DocumentGraph.DocumentMeta: ArenaGraphStorable {
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
        _ = try self.version?.storePacked(with: builder).store(index: 1, with: builder)
        _ = try self.region?.storePacked(with: builder).store(index: 0, with: builder)
        _ = try builder.storeAsLEB(value: builder.cursor.value - before.value)
        return builder.finishPackedStoring(nodeId: cycleIdentifier)
    }
}

extension DocumentGraph.DocumentItem: ArenaNodeHandle {}
extension DocumentGraph.DocumentItem: ArenaGraphStorable {
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
        _ = try self.price_minor?.storePacked(with: builder).store(index: 2, with: builder)
        _ = try self.qty?.storePacked(with: builder).store(index: 1, with: builder)
        _ = try self.sku?.storePacked(with: builder).store(index: 0, with: builder)
        _ = try builder.storeAsLEB(value: builder.cursor.value - before.value)
        return builder.finishPackedStoring(nodeId: cycleIdentifier)
    }
}

extension DocumentGraph.Document: ArenaNodeHandle {}
extension DocumentGraph.Document: ArenaGraphStorable {
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
        _ = try self.items.storePacked(with: builder).store(index: 3, with: builder)
        _ = try self.meta?.storePacked(with: builder).store(index: 2, with: builder)
        _ = try self.status?.storePacked(with: builder).store(index: 1, with: builder)
        _ = try self.id?.storePacked(with: builder).store(index: 0, with: builder)
        _ = try builder.storeAsLEB(value: builder.cursor.value - before.value)
        return builder.finishPackedStoring(nodeId: cycleIdentifier)
    }
}

extension DocumentGraph.Arena {
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

    public static func restore(from data: Foundation.Data) throws -> DocumentGraph.Arena<Brand> {
        guard !data.isEmpty else { return DocumentGraph.Arena<Brand>() }
        let arena = DocumentGraph.Arena<Brand>()
        let (framing, lebLen) = try restoreLEB(from: data, at: 0)
        guard (framing & 1) == 0 else { throw ArenaRestoreError.missingHeader }
        guard ((framing >> 1) & 1) == 0 else { throw ArenaRestoreError.invalidFraming }
        let rootStart = lebLen + Int(framing >> 2)
        var cache = [Int: Int]()
        arena.root = try arena._restoreDocument(from: data, at: rootStart, cache: &cache)
        return arena
    }

    private func _restoreDocumentMeta(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> DocumentGraph.DocumentMeta<DocumentGraph.Arena<Brand>> {
        if let idx = cache[start] { return DocumentGraph.DocumentMeta(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfDocumentMeta.count
        cache[start] = idx
        arenaOfDocumentMeta.append(DocumentGraph.DocumentMetaValues())
        generationOfDocumentMeta.append(0)
        var values = DocumentGraph.DocumentMetaValues()
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
        return DocumentGraph.DocumentMeta(__packed: UInt64(idx), __graph: self)
    }

    private func _restoreDocumentItem(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> DocumentGraph.DocumentItem<DocumentGraph.Arena<Brand>> {
        if let idx = cache[start] { return DocumentGraph.DocumentItem(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfDocumentItem.count
        cache[start] = idx
        arenaOfDocumentItem.append(DocumentGraph.DocumentItemValues())
        generationOfDocumentItem.append(0)
        var values = DocumentGraph.DocumentItemValues()
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
        return DocumentGraph.DocumentItem(__packed: UInt64(idx), __graph: self)
    }

    private func _restoreDocument(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> DocumentGraph.Document<DocumentGraph.Arena<Brand>> {
        if let idx = cache[start] { return DocumentGraph.Document(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfDocument.count
        cache[start] = idx
        arenaOfDocument.append(DocumentGraph.DocumentValues())
        generationOfDocument.append(0)
        var values = DocumentGraph.DocumentValues()
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
                values.meta = try _restoreDocumentMeta(from: data, at: _cursor, cache: &cache).__packed
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
                    let _nd_items = try _restoreDocumentItem(from: data, at: _pos_items, cache: &cache)
                    _arr_items.append(_nd_items.__packed)
                    _pos_items += _nbb_items + Int(_nb_items)
                }
                values.items = _arr_items
                _cursor = _s_items + Int(_abl_items)
            }
        }
        arenaOfDocument[idx] = values
        return DocumentGraph.Document(__packed: UInt64(idx), __graph: self)
    }

}


// ── Direct Graph Builder ("spec/33-direct-graph-builder.md") ─────────────────────
// Arena-free construction for this packed-rooted tree: value structs in,
// byte-identical graph buffer out. `Direct.toData*(v) == Arena.toData*()`.
extension DocumentGraph {
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
        _ = try self.version?.storePacked(with: builder).store(index: 1, with: builder)
        _ = try self.region?.storePacked(with: builder).store(index: 0, with: builder)
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
        _ = try self.price_minor?.storePacked(with: builder).store(index: 2, with: builder)
        _ = try self.qty?.storePacked(with: builder).store(index: 1, with: builder)
        _ = try self.sku?.storePacked(with: builder).store(index: 0, with: builder)
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
        _ = try self.items.storePacked(with: builder).store(index: 3, with: builder)
        _ = try self.meta?.storePacked(with: builder).store(index: 2, with: builder)
        _ = try self.status?.storePacked(with: builder).store(index: 1, with: builder)
        _ = try self.id?.storePacked(with: builder).store(index: 0, with: builder)
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
