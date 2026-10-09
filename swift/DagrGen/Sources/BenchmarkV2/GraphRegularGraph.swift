import Foundation

public enum GraphRegularGraph {
    public struct RegionValues {
        public var code: String? = nil
        public var note: String? = nil
        public var version: Int32? = nil
    }

    public struct OrderValues {
        public var sku: String? = nil
        public var qty: Int32? = nil
        public var region: UInt64? = nil
    }

    public struct PersonValues {
        public var name: String? = nil
        public var next: UInt64? = nil
    }

    public struct BookValues {
        public var orders: [UInt64] = []
        public var people: [UInt64] = []
    }

    public protocol RegionArena: AnyObject {
        static var regionTypeId: Int { get }
        var arenaOfRegion: [RegionValues] { get set }
    }

    public protocol OrderArena: AnyObject {
        static var orderTypeId: Int { get }
        var arenaOfOrder: [OrderValues] { get set }
    }

    public protocol PersonArena: AnyObject {
        static var personTypeId: Int { get }
        var arenaOfPerson: [PersonValues] { get set }
    }

    public protocol BookArena: AnyObject {
        static var bookTypeId: Int { get }
        var arenaOfBook: [BookValues] { get set }
    }

    public typealias GraphRegularGraphGraph = BookArena & OrderArena & PersonArena & RegionArena
    public typealias RegionGraph = RegionArena
    public typealias OrderGraph = OrderArena & RegionArena
    public typealias PersonGraph = PersonArena
    public typealias BookGraph = BookArena & OrderArena & PersonArena & RegionArena

    public struct Region<Arena: RegionGraph> {
        let __packed: UInt64
        unowned let __graph: Arena

        var __index: Int { Int(__packed & 0x0000_00FF_FFFF_FFFF) }
        var _generation: UInt32 { UInt32(__packed >> 40) }
        var _index: Int { __index }
        var _arenaId: ObjectIdentifier { ObjectIdentifier(__graph) }

        public var code: String? {
            get { __graph.arenaOfRegion[__index].code }
            nonmutating set { __graph.arenaOfRegion[__index].code = newValue }
        }
        public var note: String? {
            get { __graph.arenaOfRegion[__index].note }
            nonmutating set { __graph.arenaOfRegion[__index].note = newValue }
        }
        public var version: Int32? {
            get { __graph.arenaOfRegion[__index].version }
            nonmutating set { __graph.arenaOfRegion[__index].version = newValue }
        }
    }

    public struct Order<Arena: OrderGraph> {
        let __packed: UInt64
        unowned let __graph: Arena

        var __index: Int { Int(__packed & 0x0000_00FF_FFFF_FFFF) }
        var _generation: UInt32 { UInt32(__packed >> 40) }
        var _index: Int { __index }
        var _arenaId: ObjectIdentifier { ObjectIdentifier(__graph) }

        public var sku: String? {
            get { __graph.arenaOfOrder[__index].sku }
            nonmutating set { __graph.arenaOfOrder[__index].sku = newValue }
        }
        public var qty: Int32? {
            get { __graph.arenaOfOrder[__index].qty }
            nonmutating set { __graph.arenaOfOrder[__index].qty = newValue }
        }
        public var region: Region<Arena>? {
            get {
                guard let _stored = __graph.arenaOfOrder[__index].region else { return nil }
                return Region(__packed: _stored, __graph: __graph)
            }
            nonmutating set { __graph.arenaOfOrder[__index].region = newValue?.__packed }
        }
    }

    public struct Person<Arena: PersonGraph> {
        let __packed: UInt64
        unowned let __graph: Arena

        var __index: Int { Int(__packed & 0x0000_00FF_FFFF_FFFF) }
        var _generation: UInt32 { UInt32(__packed >> 40) }
        var _index: Int { __index }
        var _arenaId: ObjectIdentifier { ObjectIdentifier(__graph) }

        public var name: String? {
            get { __graph.arenaOfPerson[__index].name }
            nonmutating set { __graph.arenaOfPerson[__index].name = newValue }
        }
        public var next: Person<Arena>? {
            get {
                guard let _stored = __graph.arenaOfPerson[__index].next else { return nil }
                return Person(__packed: _stored, __graph: __graph)
            }
            nonmutating set { __graph.arenaOfPerson[__index].next = newValue?.__packed }
        }
    }

    public struct Book<Arena: BookGraph> {
        let __packed: UInt64
        unowned let __graph: Arena

        var __index: Int { Int(__packed & 0x0000_00FF_FFFF_FFFF) }
        var _generation: UInt32 { UInt32(__packed >> 40) }
        var _index: Int { __index }
        var _arenaId: ObjectIdentifier { ObjectIdentifier(__graph) }

        public var orders: [Order<Arena>] {
            get {
                return __graph.arenaOfBook[__index].orders.map { Order(__packed: $0, __graph: __graph) }
            }
            nonmutating set { __graph.arenaOfBook[__index].orders = newValue.map { $0.__packed } }
        }
        public var people: [Person<Arena>] {
            get {
                return __graph.arenaOfBook[__index].people.map { Person(__packed: $0, __graph: __graph) }
            }
            nonmutating set { __graph.arenaOfBook[__index].people = newValue.map { $0.__packed } }
        }
    }

    // ── Arena<Brand> ─────────────────────────────────────────────────────────────────
    //
    // Brand is a phantom type — declare an empty enum per arena scope:
    //
    //   enum MyBrand {}
    //   let arena = GraphRegularGraph.Arena<MyBrand>()
    //
    public class Arena<Brand>: RegionArena, OrderArena, PersonArena, BookArena {
        public static var regionTypeId: Int { 0 }
        public var arenaOfRegion: [RegionValues] = []
        public static var orderTypeId: Int { 1 }
        public var arenaOfOrder: [OrderValues] = []
        public static var personTypeId: Int { 2 }
        public var arenaOfPerson: [PersonValues] = []
        public static var bookTypeId: Int { 3 }
        public var arenaOfBook: [BookValues] = []
        public init() {}

        private var _root: UInt64? = nil
        public var root: Book<Arena<Brand>>? {
            get { _root.map { Book(__packed: $0, __graph: self) } }
            set { _root = newValue?.__packed }
        }
    }


}

extension GraphRegularGraph.Arena {
    public func newRegion(code: String? = nil, note: String? = nil, version: Int32? = nil) -> GraphRegularGraph.Region<GraphRegularGraph.Arena<Brand>> {
        let _idx: Int
        _idx = arenaOfRegion.count
        arenaOfRegion.append(GraphRegularGraph.RegionValues(code: code, note: note, version: version))
        let _packed = UInt64(_idx)
        return GraphRegularGraph.Region(__packed: _packed, __graph: self)
    }
}

extension GraphRegularGraph.Arena {
    public func newOrder(sku: String? = nil, qty: Int32? = nil, region: GraphRegularGraph.Region<GraphRegularGraph.Arena<Brand>>? = nil) -> GraphRegularGraph.Order<GraphRegularGraph.Arena<Brand>> {
        let _idx: Int
        _idx = arenaOfOrder.count
        arenaOfOrder.append(GraphRegularGraph.OrderValues(sku: sku, qty: qty, region: region?.__packed))
        let _packed = UInt64(_idx)
        return GraphRegularGraph.Order(__packed: _packed, __graph: self)
    }
}

extension GraphRegularGraph.Arena {
    public func newPerson(name: String? = nil, next: GraphRegularGraph.Person<GraphRegularGraph.Arena<Brand>>? = nil) -> GraphRegularGraph.Person<GraphRegularGraph.Arena<Brand>> {
        let _idx: Int
        _idx = arenaOfPerson.count
        arenaOfPerson.append(GraphRegularGraph.PersonValues(name: name, next: next?.__packed))
        let _packed = UInt64(_idx)
        return GraphRegularGraph.Person(__packed: _packed, __graph: self)
    }
}

extension GraphRegularGraph.Arena {
    public func newBook(orders: [GraphRegularGraph.Order<GraphRegularGraph.Arena<Brand>>] = [], people: [GraphRegularGraph.Person<GraphRegularGraph.Arena<Brand>>] = []) -> GraphRegularGraph.Book<GraphRegularGraph.Arena<Brand>> {
        let _idx: Int
        _idx = arenaOfBook.count
        arenaOfBook.append(GraphRegularGraph.BookValues(orders: orders.map { $0.__packed }, people: people.map { $0.__packed }))
        let _packed = UInt64(_idx)
        return GraphRegularGraph.Book(__packed: _packed, __graph: self)
    }
}

extension GraphRegularGraph.Arena {
    public func adopt<S: GraphRegularGraph.RegionGraph>(_ src: GraphRegularGraph.Region<S>) throws -> GraphRegularGraph.Region<GraphRegularGraph.Arena<Brand>> {
        var _seen = Set<UInt64>()
        return try _adopt(src, &_seen)
    }
    func _adopt<S: GraphRegularGraph.RegionGraph>(_ src: GraphRegularGraph.Region<S>, _ _seen: inout Set<UInt64>) throws -> GraphRegularGraph.Region<GraphRegularGraph.Arena<Brand>> {
        guard _seen.insert((UInt64(0) << 48) | UInt64(src._index)).inserted else { throw DagrError.cyclicAdopt }
        defer { _seen.remove((UInt64(0) << 48) | UInt64(src._index)) }
        return newRegion(code: src.code, note: src.note, version: src.version)
    }
}

extension GraphRegularGraph.Arena {
    public func adopt<S: GraphRegularGraph.OrderGraph>(_ src: GraphRegularGraph.Order<S>) throws -> GraphRegularGraph.Order<GraphRegularGraph.Arena<Brand>> {
        var _seen = Set<UInt64>()
        return try _adopt(src, &_seen)
    }
    func _adopt<S: GraphRegularGraph.OrderGraph>(_ src: GraphRegularGraph.Order<S>, _ _seen: inout Set<UInt64>) throws -> GraphRegularGraph.Order<GraphRegularGraph.Arena<Brand>> {
        guard _seen.insert((UInt64(1) << 48) | UInt64(src._index)).inserted else { throw DagrError.cyclicAdopt }
        defer { _seen.remove((UInt64(1) << 48) | UInt64(src._index)) }
        return newOrder(sku: src.sku, qty: src.qty, region: try src.region.map { try _adopt($0, &_seen) })
    }
}

extension GraphRegularGraph.Arena {
    public func adopt<S: GraphRegularGraph.PersonGraph>(_ src: GraphRegularGraph.Person<S>) throws -> GraphRegularGraph.Person<GraphRegularGraph.Arena<Brand>> {
        var _seen = Set<UInt64>()
        return try _adopt(src, &_seen)
    }
    func _adopt<S: GraphRegularGraph.PersonGraph>(_ src: GraphRegularGraph.Person<S>, _ _seen: inout Set<UInt64>) throws -> GraphRegularGraph.Person<GraphRegularGraph.Arena<Brand>> {
        guard _seen.insert((UInt64(2) << 48) | UInt64(src._index)).inserted else { throw DagrError.cyclicAdopt }
        defer { _seen.remove((UInt64(2) << 48) | UInt64(src._index)) }
        return newPerson(name: src.name, next: try src.next.map { try _adopt($0, &_seen) })
    }
}

extension GraphRegularGraph.Arena {
    public func adopt<S: GraphRegularGraph.BookGraph>(_ src: GraphRegularGraph.Book<S>) throws -> GraphRegularGraph.Book<GraphRegularGraph.Arena<Brand>> {
        var _seen = Set<UInt64>()
        return try _adopt(src, &_seen)
    }
    func _adopt<S: GraphRegularGraph.BookGraph>(_ src: GraphRegularGraph.Book<S>, _ _seen: inout Set<UInt64>) throws -> GraphRegularGraph.Book<GraphRegularGraph.Arena<Brand>> {
        guard _seen.insert((UInt64(3) << 48) | UInt64(src._index)).inserted else { throw DagrError.cyclicAdopt }
        defer { _seen.remove((UInt64(3) << 48) | UInt64(src._index)) }
        return newBook(orders: try src.orders.map { try _adopt($0, &_seen) }, people: try src.people.map { try _adopt($0, &_seen) })
    }
}

extension GraphRegularGraph.Region: CustomStringConvertible {
    public var description: String {
        var visited = Set<NodeKey>()
        return buildDescription(visited: &visited)
    }

    func buildDescription(visited: inout Set<NodeKey>) -> String {
        let __nodeKey = NodeKey(arena: _arenaId, typeId: Arena.regionTypeId, index: __index)
        guard !visited.contains(__nodeKey) else { return "Region@\(__index)" }
        visited.insert(__nodeKey)
        let codeStr = code.map { "\"\($0)\"" } ?? "nil"
        let noteStr = note.map { "\"\($0)\"" } ?? "nil"
        let versionStr = String(describing: version)
        return "Region@\(__index) { code: \(codeStr), note: \(noteStr), version: \(versionStr) }"
    }
}

extension GraphRegularGraph.Order: CustomStringConvertible {
    public var description: String {
        var visited = Set<NodeKey>()
        return buildDescription(visited: &visited)
    }

    func buildDescription(visited: inout Set<NodeKey>) -> String {
        let __nodeKey = NodeKey(arena: _arenaId, typeId: Arena.orderTypeId, index: __index)
        guard !visited.contains(__nodeKey) else { return "Order@\(__index)" }
        visited.insert(__nodeKey)
        let skuStr = sku.map { "\"\($0)\"" } ?? "nil"
        let qtyStr = String(describing: qty)
        let regionStr = region.map { $0.buildDescription(visited: &visited) } ?? "nil"
        return "Order@\(__index) { sku: \(skuStr), qty: \(qtyStr), region: \(regionStr) }"
    }
}

extension GraphRegularGraph.Person: CustomStringConvertible {
    public var description: String {
        var visited = Set<NodeKey>()
        return buildDescription(visited: &visited)
    }

    func buildDescription(visited: inout Set<NodeKey>) -> String {
        let __nodeKey = NodeKey(arena: _arenaId, typeId: Arena.personTypeId, index: __index)
        guard !visited.contains(__nodeKey) else { return "Person@\(__index)" }
        visited.insert(__nodeKey)
        let nameStr = name.map { "\"\($0)\"" } ?? "nil"
        let nextStr = next.map { $0.buildDescription(visited: &visited) } ?? "nil"
        return "Person@\(__index) { name: \(nameStr), next: \(nextStr) }"
    }
}

extension GraphRegularGraph.Book: CustomStringConvertible {
    public var description: String {
        var visited = Set<NodeKey>()
        return buildDescription(visited: &visited)
    }

    func buildDescription(visited: inout Set<NodeKey>) -> String {
        let __nodeKey = NodeKey(arena: _arenaId, typeId: Arena.bookTypeId, index: __index)
        guard !visited.contains(__nodeKey) else { return "Book@\(__index)" }
        visited.insert(__nodeKey)
        let ordersStr = "[" + orders.map { $0.buildDescription(visited: &visited) }.joined(separator: ", ") + "]"
        let peopleStr = "[" + people.map { $0.buildDescription(visited: &visited) }.joined(separator: ", ") + "]"
        return "Book@\(__index) { orders: \(ordersStr), people: \(peopleStr) }"
    }
}

extension GraphRegularGraph.Region: Hashable {
    public func hash(into hasher: inout Hasher) {
        var visited = Set<NodeKey>()
        hashInto(hasher: &hasher, visited: &visited)
    }

    func hashInto(hasher: inout Hasher, visited: inout Set<NodeKey>) {
        let __nodeKey = NodeKey(arena: _arenaId, typeId: Arena.regionTypeId, index: __index)
        guard !visited.contains(__nodeKey) else { return }
        visited.insert(__nodeKey)
        hasher.combine(code)
        hasher.combine(note)
        hasher.combine(version)
    }
}

extension GraphRegularGraph.Order: Hashable {
    public func hash(into hasher: inout Hasher) {
        var visited = Set<NodeKey>()
        hashInto(hasher: &hasher, visited: &visited)
    }

    func hashInto(hasher: inout Hasher, visited: inout Set<NodeKey>) {
        let __nodeKey = NodeKey(arena: _arenaId, typeId: Arena.orderTypeId, index: __index)
        guard !visited.contains(__nodeKey) else { return }
        visited.insert(__nodeKey)
        hasher.combine(sku)
        hasher.combine(qty)
        region?.hashInto(hasher: &hasher, visited: &visited)
    }
}

extension GraphRegularGraph.Person: Hashable {
    public func hash(into hasher: inout Hasher) {
        var visited = Set<NodeKey>()
        hashInto(hasher: &hasher, visited: &visited)
    }

    func hashInto(hasher: inout Hasher, visited: inout Set<NodeKey>) {
        let __nodeKey = NodeKey(arena: _arenaId, typeId: Arena.personTypeId, index: __index)
        guard !visited.contains(__nodeKey) else { return }
        visited.insert(__nodeKey)
        hasher.combine(name)
        next?.hashInto(hasher: &hasher, visited: &visited)
    }
}

extension GraphRegularGraph.Book: Hashable {
    public func hash(into hasher: inout Hasher) {
        var visited = Set<NodeKey>()
        hashInto(hasher: &hasher, visited: &visited)
    }

    func hashInto(hasher: inout Hasher, visited: inout Set<NodeKey>) {
        let __nodeKey = NodeKey(arena: _arenaId, typeId: Arena.bookTypeId, index: __index)
        guard !visited.contains(__nodeKey) else { return }
        visited.insert(__nodeKey)
        for item in orders { item.hashInto(hasher: &hasher, visited: &visited) }
        for item in people { item.hashInto(hasher: &hasher, visited: &visited) }
    }
}

extension GraphRegularGraph.Region: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        var visited = Set<ArenaPair>()
        return lhs.cycleAwareEquals(other: rhs, visited: &visited)
    }

    func cycleAwareEquals(other: Self, visited: inout Set<ArenaPair>) -> Bool {
        let pair = ArenaPair(
            leftArena: _arenaId, leftTypeId: Arena.regionTypeId, leftIndex: __index,
            rightArena: other._arenaId, rightTypeId: Arena.regionTypeId, rightIndex: other.__index
        )
        guard !visited.contains(pair) else { return true }
        visited.insert(pair)
        guard self.code == other.code else { return false }
        guard self.note == other.note else { return false }
        guard self.version == other.version else { return false }
        return true
    }
}

extension GraphRegularGraph.Region {
    public static func == <OtherArena: GraphRegularGraph.RegionGraph>(lhs: Self, rhs: GraphRegularGraph.Region<OtherArena>) -> Bool {
        var visited = Set<ArenaPair>()
        return lhs.cycleAwareEqualsAny(other: rhs, visited: &visited)
    }

    public static func != <OtherArena: GraphRegularGraph.RegionGraph>(lhs: Self, rhs: GraphRegularGraph.Region<OtherArena>) -> Bool {
        return !(lhs == rhs)
    }

    func cycleAwareEqualsAny<OtherArena: GraphRegularGraph.RegionGraph>(
        other: GraphRegularGraph.Region<OtherArena>,
        visited: inout Set<ArenaPair>
    ) -> Bool {
        let pair = ArenaPair(
            leftArena: _arenaId, leftTypeId: Arena.regionTypeId, leftIndex: __index,
            rightArena: other._arenaId, rightTypeId: OtherArena.regionTypeId, rightIndex: other.__index
        )
        guard !visited.contains(pair) else { return true }
        visited.insert(pair)
        guard self.code == other.code else { return false }
        guard self.note == other.note else { return false }
        guard self.version == other.version else { return false }
        return true
    }
}

extension GraphRegularGraph.Order: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        var visited = Set<ArenaPair>()
        return lhs.cycleAwareEquals(other: rhs, visited: &visited)
    }

    func cycleAwareEquals(other: Self, visited: inout Set<ArenaPair>) -> Bool {
        let pair = ArenaPair(
            leftArena: _arenaId, leftTypeId: Arena.orderTypeId, leftIndex: __index,
            rightArena: other._arenaId, rightTypeId: Arena.orderTypeId, rightIndex: other.__index
        )
        guard !visited.contains(pair) else { return true }
        visited.insert(pair)
        guard self.sku == other.sku else { return false }
        guard self.qty == other.qty else { return false }
        switch (self.region, other.region) {
        case (.none, .none): break
        case (.some(let a), .some(let b)):
            guard a.cycleAwareEquals(other: b, visited: &visited) else { return false }
        default: return false
        }
        return true
    }
}

extension GraphRegularGraph.Order {
    public static func == <OtherArena: GraphRegularGraph.OrderGraph>(lhs: Self, rhs: GraphRegularGraph.Order<OtherArena>) -> Bool {
        var visited = Set<ArenaPair>()
        return lhs.cycleAwareEqualsAny(other: rhs, visited: &visited)
    }

    public static func != <OtherArena: GraphRegularGraph.OrderGraph>(lhs: Self, rhs: GraphRegularGraph.Order<OtherArena>) -> Bool {
        return !(lhs == rhs)
    }

    func cycleAwareEqualsAny<OtherArena: GraphRegularGraph.OrderGraph>(
        other: GraphRegularGraph.Order<OtherArena>,
        visited: inout Set<ArenaPair>
    ) -> Bool {
        let pair = ArenaPair(
            leftArena: _arenaId, leftTypeId: Arena.orderTypeId, leftIndex: __index,
            rightArena: other._arenaId, rightTypeId: OtherArena.orderTypeId, rightIndex: other.__index
        )
        guard !visited.contains(pair) else { return true }
        visited.insert(pair)
        guard self.sku == other.sku else { return false }
        guard self.qty == other.qty else { return false }
        switch (self.region, other.region) {
        case (.none, .none): break
        case (.some(let a), .some(let b)):
            guard a.cycleAwareEqualsAny(other: b, visited: &visited) else { return false }
        default: return false
        }
        return true
    }
}

extension GraphRegularGraph.Person: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        var visited = Set<ArenaPair>()
        return lhs.cycleAwareEquals(other: rhs, visited: &visited)
    }

    func cycleAwareEquals(other: Self, visited: inout Set<ArenaPair>) -> Bool {
        let pair = ArenaPair(
            leftArena: _arenaId, leftTypeId: Arena.personTypeId, leftIndex: __index,
            rightArena: other._arenaId, rightTypeId: Arena.personTypeId, rightIndex: other.__index
        )
        guard !visited.contains(pair) else { return true }
        visited.insert(pair)
        guard self.name == other.name else { return false }
        switch (self.next, other.next) {
        case (.none, .none): break
        case (.some(let a), .some(let b)):
            guard a.cycleAwareEquals(other: b, visited: &visited) else { return false }
        default: return false
        }
        return true
    }
}

extension GraphRegularGraph.Person {
    public static func == <OtherArena: GraphRegularGraph.PersonGraph>(lhs: Self, rhs: GraphRegularGraph.Person<OtherArena>) -> Bool {
        var visited = Set<ArenaPair>()
        return lhs.cycleAwareEqualsAny(other: rhs, visited: &visited)
    }

    public static func != <OtherArena: GraphRegularGraph.PersonGraph>(lhs: Self, rhs: GraphRegularGraph.Person<OtherArena>) -> Bool {
        return !(lhs == rhs)
    }

    func cycleAwareEqualsAny<OtherArena: GraphRegularGraph.PersonGraph>(
        other: GraphRegularGraph.Person<OtherArena>,
        visited: inout Set<ArenaPair>
    ) -> Bool {
        let pair = ArenaPair(
            leftArena: _arenaId, leftTypeId: Arena.personTypeId, leftIndex: __index,
            rightArena: other._arenaId, rightTypeId: OtherArena.personTypeId, rightIndex: other.__index
        )
        guard !visited.contains(pair) else { return true }
        visited.insert(pair)
        guard self.name == other.name else { return false }
        switch (self.next, other.next) {
        case (.none, .none): break
        case (.some(let a), .some(let b)):
            guard a.cycleAwareEqualsAny(other: b, visited: &visited) else { return false }
        default: return false
        }
        return true
    }
}

extension GraphRegularGraph.Book: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        var visited = Set<ArenaPair>()
        return lhs.cycleAwareEquals(other: rhs, visited: &visited)
    }

    func cycleAwareEquals(other: Self, visited: inout Set<ArenaPair>) -> Bool {
        let pair = ArenaPair(
            leftArena: _arenaId, leftTypeId: Arena.bookTypeId, leftIndex: __index,
            rightArena: other._arenaId, rightTypeId: Arena.bookTypeId, rightIndex: other.__index
        )
        guard !visited.contains(pair) else { return true }
        visited.insert(pair)
        let _aorders = self.orders, _borders = other.orders
        guard _aorders.count == _borders.count else { return false }
        guard zip(_aorders, _borders).allSatisfy({ a, b in a.cycleAwareEquals(other: b, visited: &visited) }) else { return false }
        let _apeople = self.people, _bpeople = other.people
        guard _apeople.count == _bpeople.count else { return false }
        guard zip(_apeople, _bpeople).allSatisfy({ a, b in a.cycleAwareEquals(other: b, visited: &visited) }) else { return false }
        return true
    }
}

extension GraphRegularGraph.Book {
    public static func == <OtherArena: GraphRegularGraph.BookGraph>(lhs: Self, rhs: GraphRegularGraph.Book<OtherArena>) -> Bool {
        var visited = Set<ArenaPair>()
        return lhs.cycleAwareEqualsAny(other: rhs, visited: &visited)
    }

    public static func != <OtherArena: GraphRegularGraph.BookGraph>(lhs: Self, rhs: GraphRegularGraph.Book<OtherArena>) -> Bool {
        return !(lhs == rhs)
    }

    func cycleAwareEqualsAny<OtherArena: GraphRegularGraph.BookGraph>(
        other: GraphRegularGraph.Book<OtherArena>,
        visited: inout Set<ArenaPair>
    ) -> Bool {
        let pair = ArenaPair(
            leftArena: _arenaId, leftTypeId: Arena.bookTypeId, leftIndex: __index,
            rightArena: other._arenaId, rightTypeId: OtherArena.bookTypeId, rightIndex: other.__index
        )
        guard !visited.contains(pair) else { return true }
        visited.insert(pair)
        let _aorders = self.orders, _borders = other.orders
        guard _aorders.count == _borders.count else { return false }
        guard zip(_aorders, _borders).allSatisfy({ a, b in a.cycleAwareEqualsAny(other: b, visited: &visited) }) else { return false }
        let _apeople = self.people, _bpeople = other.people
        guard _apeople.count == _bpeople.count else { return false }
        guard zip(_apeople, _bpeople).allSatisfy({ a, b in a.cycleAwareEqualsAny(other: b, visited: &visited) }) else { return false }
        return true
    }
}

extension GraphRegularGraph.Region: ArenaNodeHandle {}
extension GraphRegularGraph.Region: ArenaGraphStorable {
    var cycleIdentifier: ArenaCycleIdntifier {
        .init(nodeTypeId: Arena.regionTypeId, nodeIndex: __index)
    }

    public func store(with builder: any ArenaBuilder) throws -> BufferOffset {
        if let offset = try builder.beginStoring(nodeId: cycleIdentifier) {
            return offset
        }
        let _noteValueOffset = try self.note?.store(with: builder)
        let _codeValueOffset = try self.code?.store(with: builder)
        let _versionOffset: BufferOffset? = try self.version?.store(with: builder)
        let _noteOffset: BufferOffset? = try _noteValueOffset?.storeForwardPointer(with: builder)
        let _codeOffset: BufferOffset? = try _codeValueOffset?.storeForwardPointer(with: builder)
        let offset = try builder.store(vTable: [_codeOffset, _noteOffset, _versionOffset])
        try builder.finishStoring(nodeId: cycleIdentifier, offset: offset)
        return offset
    }

    public func storePacked(with builder: any ArenaBuilder) throws -> PackedStoreResult {
        let before = try builder.beginPackedStoring(nodeId: cycleIdentifier)
        _ = try self.version?.storePacked(with: builder).store(index: 2, with: builder)
        _ = try self.note?.storePacked(with: builder).store(index: 1, with: builder)
        _ = try self.code?.storePacked(with: builder).store(index: 0, with: builder)
        _ = try builder.storeAsLEB(value: builder.cursor.value - before.value)
        return builder.finishPackedStoring(nodeId: cycleIdentifier)
    }
}

extension GraphRegularGraph.Order: ArenaNodeHandle {}
extension GraphRegularGraph.Order: ArenaGraphStorable {
    var cycleIdentifier: ArenaCycleIdntifier {
        .init(nodeTypeId: Arena.orderTypeId, nodeIndex: __index)
    }

    public func store(with builder: any ArenaBuilder) throws -> BufferOffset {
        if let offset = try builder.beginStoring(nodeId: cycleIdentifier) {
            return offset
        }
        let _regionValueOffset = try self.region?.store(with: builder)
        let _skuValueOffset = try self.sku?.store(with: builder)
        let _regionOffset: BufferOffset? = try _regionValueOffset?.storeBidirectionalPointer(with: builder)
        let _qtyOffset: BufferOffset? = try self.qty?.store(with: builder)
        let _skuOffset: BufferOffset? = try _skuValueOffset?.storeForwardPointer(with: builder)
        let offset = try builder.store(vTable: [_skuOffset, _qtyOffset, _regionOffset])
        try builder.finishStoring(nodeId: cycleIdentifier, offset: offset)
        return offset
    }

    public func storePacked(with builder: any ArenaBuilder) throws -> PackedStoreResult {
        let before = try builder.beginPackedStoring(nodeId: cycleIdentifier)
        _ = try self.region?.storePacked(with: builder).store(index: 2, with: builder)
        _ = try self.qty?.storePacked(with: builder).store(index: 1, with: builder)
        _ = try self.sku?.storePacked(with: builder).store(index: 0, with: builder)
        _ = try builder.storeAsLEB(value: builder.cursor.value - before.value)
        return builder.finishPackedStoring(nodeId: cycleIdentifier)
    }
}

extension GraphRegularGraph.Person: ArenaNodeHandle {}
extension GraphRegularGraph.Person: ArenaGraphStorable {
    var cycleIdentifier: ArenaCycleIdntifier {
        .init(nodeTypeId: Arena.personTypeId, nodeIndex: __index)
    }

    public func store(with builder: any ArenaBuilder) throws -> BufferOffset {
        if let offset = try builder.beginStoring(nodeId: cycleIdentifier) {
            return offset
        }
        let _nextValueOffset = try self.next?.store(with: builder)
        let _nameValueOffset = try self.name?.store(with: builder)
        let _nextOffset: BufferOffset? = try _nextValueOffset?.storeBidirectionalPointer(with: builder)
        let _nameOffset: BufferOffset? = try _nameValueOffset?.storeForwardPointer(with: builder)
        let offset = try builder.store(vTable: [_nameOffset, _nextOffset])
        try builder.finishStoring(nodeId: cycleIdentifier, offset: offset)
        return offset
    }

    public func storePacked(with builder: any ArenaBuilder) throws -> PackedStoreResult {
        let before = try builder.beginPackedStoring(nodeId: cycleIdentifier)
        _ = try self.next?.storePacked(with: builder).store(index: 1, with: builder)
        _ = try self.name?.storePacked(with: builder).store(index: 0, with: builder)
        _ = try builder.storeAsLEB(value: builder.cursor.value - before.value)
        return builder.finishPackedStoring(nodeId: cycleIdentifier)
    }
}

extension GraphRegularGraph.Book: ArenaNodeHandle {}
extension GraphRegularGraph.Book: ArenaGraphStorable {
    var cycleIdentifier: ArenaCycleIdntifier {
        .init(nodeTypeId: Arena.bookTypeId, nodeIndex: __index)
    }

    public func store(with builder: any ArenaBuilder) throws -> BufferOffset {
        if let offset = try builder.beginStoring(nodeId: cycleIdentifier) {
            return offset
        }
        let _peopleValueOffset = try self.people.store(with: builder)
        let _ordersValueOffset = try self.orders.store(with: builder)
        let _peopleOffset: BufferOffset? = try _peopleValueOffset.storeForwardPointer(with: builder)
        let _ordersOffset: BufferOffset? = try _ordersValueOffset.storeForwardPointer(with: builder)
        let offset = try builder.store(vTable: [_ordersOffset, _peopleOffset])
        try builder.finishStoring(nodeId: cycleIdentifier, offset: offset)
        return offset
    }

    public func storePacked(with builder: any ArenaBuilder) throws -> PackedStoreResult {
        let before = try builder.beginPackedStoring(nodeId: cycleIdentifier)
        _ = try self.people.storePacked(with: builder).store(index: 1, with: builder)
        _ = try self.orders.storePacked(with: builder).store(index: 0, with: builder)
        _ = try builder.storeAsLEB(value: builder.cursor.value - before.value)
        return builder.finishPackedStoring(nodeId: cycleIdentifier)
    }
}

extension GraphRegularGraph.Arena {
    /// `alignmentOffset`: the number of bytes that will precede this buffer in whatever
    /// carries it (spec 12 §14) — its aligned arrays then land on their boundary in the
    /// envelope's frame. 0 is a buffer that stands on its own.
    public func toData(alignmentOffset: Int = 0) throws -> Foundation.Data {
        guard let root = root else { return Foundation.Data() }
        let builder = DataArenaBuilder()
        builder.alignmentOffset = alignmentOffset
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
    public func toData(maxSize: UInt64, alignmentOffset: Int = 0) throws -> Foundation.Data {
        guard let root = root else { return Foundation.Data() }
        let builder = DataArenaBuilder(maxSize: maxSize)
        builder.alignmentOffset = alignmentOffset
        let rootOffset = try root.store(with: builder)
        _ = try builder.storeAsLEB(value: (builder.cursor.value - rootOffset.value) << 2)
        return builder.makeData
    }

    public static func restore(from data: Foundation.Data) throws -> GraphRegularGraph.Arena<Brand> {
        guard !data.isEmpty else { return GraphRegularGraph.Arena<Brand>() }
        let arena = GraphRegularGraph.Arena<Brand>()
        let (framing, lebLen) = try restoreLEB(from: data, at: 0)
        guard (framing & 1) == 0 else { throw ArenaRestoreError.missingHeader }
        guard ((framing >> 1) & 1) == 0 else { throw ArenaRestoreError.invalidFraming }
        let rootStart = lebLen + Int(framing >> 2)
        var cache = [Int: Int]()
        arena.root = try arena._restoreBook(from: data, at: rootStart, cache: &cache)
        return arena
    }

    private func _restoreRegion(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> GraphRegularGraph.Region<GraphRegularGraph.Arena<Brand>> {
        if let idx = cache[start] { return GraphRegularGraph.Region(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfRegion.count
        cache[start] = idx
        arenaOfRegion.append(GraphRegularGraph.RegionValues())
        var values = GraphRegularGraph.RegionValues()
        let vtable = try restoreRTypeVTable(from: data, start: start)
        if 0 < vtable.count, let _off0 = vtable[0] {
            let (_fwd0, _fwdb0) = try readV62(from: data, at: start + Int(_off0))
            values.code = try String.restore(from: data, at: start + Int(_off0) + _fwdb0 + Int(_fwd0))
        }
        if 1 < vtable.count, let _off1 = vtable[1] {
            let (_fwd1, _fwdb1) = try readV62(from: data, at: start + Int(_off1))
            values.note = try String.restore(from: data, at: start + Int(_off1) + _fwdb1 + Int(_fwd1))
        }
        if 2 < vtable.count, let _off2 = vtable[2] {
            values.version = try Int32.restore(from: data, at: start + Int(_off2))
        }
        arenaOfRegion[idx] = values
        return GraphRegularGraph.Region(__packed: UInt64(idx), __graph: self)
    }

    private func _restoreRegionPacked(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> GraphRegularGraph.Region<GraphRegularGraph.Arena<Brand>> {
        if let idx = cache[start] { return GraphRegularGraph.Region(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfRegion.count
        cache[start] = idx
        arenaOfRegion.append(GraphRegularGraph.RegionValues())
        var values = GraphRegularGraph.RegionValues()
        let (_bl, _blB) = try restoreLEB(from: data, at: start)
        var _cursor = start + _blB
        let _end = _cursor + Int(_bl)
        if _cursor < _end {
            let (_tag, _tagB) = try restoreLEB(from: data, at: _cursor)
            if Int(_tag) >> 1 == 0 {
                _cursor += _tagB
                let (_sv_code, _sb_code) = try restoreLEB(from: data, at: _cursor); _cursor += _sb_code
                values.code = _dagrUTF8(data[_cursor..<(_cursor + Int(_sv_code))]); _cursor += Int(_sv_code)
            }
        }
        if _cursor < _end {
            let (_tag, _tagB) = try restoreLEB(from: data, at: _cursor)
            if Int(_tag) >> 1 == 1 {
                _cursor += _tagB
                let (_sv_note, _sb_note) = try restoreLEB(from: data, at: _cursor); _cursor += _sb_note
                values.note = _dagrUTF8(data[_cursor..<(_cursor + Int(_sv_note))]); _cursor += Int(_sv_note)
            }
        }
        if _cursor < _end {
            let (_tag, _tagB) = try restoreLEB(from: data, at: _cursor)
            if Int(_tag) >> 1 == 2 {
                _cursor += _tagB
                if _tag & 1 == 0 {
                    let (_v, _b) = try restoreLEB(from: data, at: _cursor); values.version = Int32(_v.fromZigZag); _cursor += _b
                } else {
                    values.version = try Int32.restore(from: data, at: _cursor); _cursor += 4
                }
            }
        }
        arenaOfRegion[idx] = values
        return GraphRegularGraph.Region(__packed: UInt64(idx), __graph: self)
    }

    private func _restoreOrder(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> GraphRegularGraph.Order<GraphRegularGraph.Arena<Brand>> {
        if let idx = cache[start] { return GraphRegularGraph.Order(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfOrder.count
        cache[start] = idx
        arenaOfOrder.append(GraphRegularGraph.OrderValues())
        var values = GraphRegularGraph.OrderValues()
        let vtable = try restoreRTypeVTable(from: data, start: start)
        if 0 < vtable.count, let _off0 = vtable[0] {
            let (_fwd0, _fwdb0) = try readV62(from: data, at: start + Int(_off0))
            values.sku = try String.restore(from: data, at: start + Int(_off0) + _fwdb0 + Int(_fwd0))
        }
        if 1 < vtable.count, let _off1 = vtable[1] {
            values.qty = try Int32.restore(from: data, at: start + Int(_off1))
        }
        if 2 < vtable.count, let _off2 = vtable[2] {
            let (_bd2, _bdb2) = try readZigZagV62(from: data, at: start + Int(_off2))
            values.region = try _restoreRegion(from: data, at: start + Int(_off2) + _bdb2 + _bd2, cache: &cache).__packed
        }
        arenaOfOrder[idx] = values
        return GraphRegularGraph.Order(__packed: UInt64(idx), __graph: self)
    }

    private func _restoreOrderPacked(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> GraphRegularGraph.Order<GraphRegularGraph.Arena<Brand>> {
        if let idx = cache[start] { return GraphRegularGraph.Order(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfOrder.count
        cache[start] = idx
        arenaOfOrder.append(GraphRegularGraph.OrderValues())
        var values = GraphRegularGraph.OrderValues()
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
                let (_bbl_region, _bblB_region) = try restoreLEB(from: data, at: _cursor)
                values.region = try _restoreRegionPacked(from: data, at: _cursor, cache: &cache).__packed
                _cursor += _bblB_region + Int(_bbl_region)
            }
        }
        arenaOfOrder[idx] = values
        return GraphRegularGraph.Order(__packed: UInt64(idx), __graph: self)
    }

    private func _restorePerson(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> GraphRegularGraph.Person<GraphRegularGraph.Arena<Brand>> {
        if let idx = cache[start] { return GraphRegularGraph.Person(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfPerson.count
        cache[start] = idx
        arenaOfPerson.append(GraphRegularGraph.PersonValues())
        var values = GraphRegularGraph.PersonValues()
        let vtable = try restoreRTypeVTable(from: data, start: start)
        if 0 < vtable.count, let _off0 = vtable[0] {
            let (_fwd0, _fwdb0) = try readV62(from: data, at: start + Int(_off0))
            values.name = try String.restore(from: data, at: start + Int(_off0) + _fwdb0 + Int(_fwd0))
        }
        if 1 < vtable.count, let _off1 = vtable[1] {
            let (_bd1, _bdb1) = try readZigZagV62(from: data, at: start + Int(_off1))
            values.next = try _restorePerson(from: data, at: start + Int(_off1) + _bdb1 + _bd1, cache: &cache).__packed
        }
        arenaOfPerson[idx] = values
        return GraphRegularGraph.Person(__packed: UInt64(idx), __graph: self)
    }

    private func _restorePersonPacked(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> GraphRegularGraph.Person<GraphRegularGraph.Arena<Brand>> {
        if let idx = cache[start] { return GraphRegularGraph.Person(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfPerson.count
        cache[start] = idx
        arenaOfPerson.append(GraphRegularGraph.PersonValues())
        var values = GraphRegularGraph.PersonValues()
        let (_bl, _blB) = try restoreLEB(from: data, at: start)
        var _cursor = start + _blB
        let _end = _cursor + Int(_bl)
        if _cursor < _end {
            let (_tag, _tagB) = try restoreLEB(from: data, at: _cursor)
            if Int(_tag) >> 1 == 0 {
                _cursor += _tagB
                let (_sv_name, _sb_name) = try restoreLEB(from: data, at: _cursor); _cursor += _sb_name
                values.name = _dagrUTF8(data[_cursor..<(_cursor + Int(_sv_name))]); _cursor += Int(_sv_name)
            }
        }
        if _cursor < _end {
            let (_tag, _tagB) = try restoreLEB(from: data, at: _cursor)
            if Int(_tag) >> 1 == 1 {
                _cursor += _tagB
                let (_bbl_next, _bblB_next) = try restoreLEB(from: data, at: _cursor)
                values.next = try _restorePersonPacked(from: data, at: _cursor, cache: &cache).__packed
                _cursor += _bblB_next + Int(_bbl_next)
            }
        }
        arenaOfPerson[idx] = values
        return GraphRegularGraph.Person(__packed: UInt64(idx), __graph: self)
    }

    private func _restoreBook(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> GraphRegularGraph.Book<GraphRegularGraph.Arena<Brand>> {
        if let idx = cache[start] { return GraphRegularGraph.Book(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfBook.count
        cache[start] = idx
        arenaOfBook.append(GraphRegularGraph.BookValues())
        var values = GraphRegularGraph.BookValues()
        let vtable = try restoreRTypeVTable(from: data, start: start)
        if 0 < vtable.count, let _off0 = vtable[0] {
            let (_fwd0, _fwdb0) = try readV62(from: data, at: start + Int(_off0))
            let (_h0, _hl0) = try restoreLEB(from: data, at: start + Int(_off0) + _fwdb0 + Int(_fwd0))
            let _cnt0 = Int(_h0 >> 2); let _wc0 = Int(_h0 & 3)
            let _es0 = [1,2,4,8][_wc0]
            let _base0 = start + Int(_off0) + _fwdb0 + Int(_fwd0) + _hl0 + _cnt0 * _es0
            var _arr0 = [UInt64]()
            for _k0 in 0..<_cnt0 {
                let _ep0 = start + Int(_off0) + _fwdb0 + Int(_fwd0) + _hl0 + _k0 * _es0
                let _ro0 = try readSignedRelOffset(from: data, at: _ep0, size: _es0)
                if _ro0 != 0 {
                    _arr0.append(try _restoreOrder(from: data, at: _base0 + Int(_ro0) - 1, cache: &cache).__packed)
                }
            }
            values.orders = _arr0
        }
        if 1 < vtable.count, let _off1 = vtable[1] {
            let (_fwd1, _fwdb1) = try readV62(from: data, at: start + Int(_off1))
            let (_h1, _hl1) = try restoreLEB(from: data, at: start + Int(_off1) + _fwdb1 + Int(_fwd1))
            let _cnt1 = Int(_h1 >> 2); let _wc1 = Int(_h1 & 3)
            let _es1 = [1,2,4,8][_wc1]
            let _base1 = start + Int(_off1) + _fwdb1 + Int(_fwd1) + _hl1 + _cnt1 * _es1
            var _arr1 = [UInt64]()
            for _k1 in 0..<_cnt1 {
                let _ep1 = start + Int(_off1) + _fwdb1 + Int(_fwd1) + _hl1 + _k1 * _es1
                let _ro1 = try readSignedRelOffset(from: data, at: _ep1, size: _es1)
                if _ro1 != 0 {
                    _arr1.append(try _restorePerson(from: data, at: _base1 + Int(_ro1) - 1, cache: &cache).__packed)
                }
            }
            values.people = _arr1
        }
        arenaOfBook[idx] = values
        return GraphRegularGraph.Book(__packed: UInt64(idx), __graph: self)
    }

    private func _restoreBookPacked(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> GraphRegularGraph.Book<GraphRegularGraph.Arena<Brand>> {
        if let idx = cache[start] { return GraphRegularGraph.Book(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfBook.count
        cache[start] = idx
        arenaOfBook.append(GraphRegularGraph.BookValues())
        var values = GraphRegularGraph.BookValues()
        let (_bl, _blB) = try restoreLEB(from: data, at: start)
        var _cursor = start + _blB
        let _end = _cursor + Int(_bl)
        if _cursor < _end {
            let (_tag, _tagB) = try restoreLEB(from: data, at: _cursor)
            if Int(_tag) >> 1 == 0 {
                _cursor += _tagB
                let (_abl_orders, _ablB_orders) = try restoreLEB(from: data, at: _cursor)
                let _s_orders = _cursor + _ablB_orders
                let (_cnt_orders, _cntB_orders) = try restoreLEB(from: data, at: _s_orders)
                var _arr_orders = [UInt64]()
                var _pos_orders = _s_orders + _cntB_orders
                for _ in 0..<Int(_cnt_orders) {
                    let (_nb_orders, _nbb_orders) = try restoreLEB(from: data, at: _pos_orders)
                    let _nd_orders = try _restoreOrderPacked(from: data, at: _pos_orders, cache: &cache)
                    _arr_orders.append(_nd_orders.__packed)
                    _pos_orders += _nbb_orders + Int(_nb_orders)
                }
                values.orders = _arr_orders
                _cursor = _s_orders + Int(_abl_orders)
            }
        }
        if _cursor < _end {
            let (_tag, _tagB) = try restoreLEB(from: data, at: _cursor)
            if Int(_tag) >> 1 == 1 {
                _cursor += _tagB
                let (_abl_people, _ablB_people) = try restoreLEB(from: data, at: _cursor)
                let _s_people = _cursor + _ablB_people
                let (_cnt_people, _cntB_people) = try restoreLEB(from: data, at: _s_people)
                var _arr_people = [UInt64]()
                var _pos_people = _s_people + _cntB_people
                for _ in 0..<Int(_cnt_people) {
                    let (_nb_people, _nbb_people) = try restoreLEB(from: data, at: _pos_people)
                    let _nd_people = try _restorePersonPacked(from: data, at: _pos_people, cache: &cache)
                    _arr_people.append(_nd_people.__packed)
                    _pos_people += _nbb_people + Int(_nb_people)
                }
                values.people = _arr_people
                _cursor = _s_people + Int(_abl_people)
            }
        }
        arenaOfBook[idx] = values
        return GraphRegularGraph.Book(__packed: UInt64(idx), __graph: self)
    }

}
