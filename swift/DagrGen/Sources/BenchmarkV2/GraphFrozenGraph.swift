import Foundation

public enum GraphFrozenGraph {
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

    public typealias GraphFrozenGraphGraph = BookArena & OrderArena & PersonArena & RegionArena
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
    //   let arena = GraphFrozenGraph.Arena<MyBrand>()
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

extension GraphFrozenGraph.Arena {
    public func newRegion(code: String? = nil, note: String? = nil, version: Int32? = nil) -> GraphFrozenGraph.Region<GraphFrozenGraph.Arena<Brand>> {
        let _idx: Int
        _idx = arenaOfRegion.count
        arenaOfRegion.append(GraphFrozenGraph.RegionValues(code: code, note: note, version: version))
        let _packed = UInt64(_idx)
        return GraphFrozenGraph.Region(__packed: _packed, __graph: self)
    }
}

extension GraphFrozenGraph.Arena {
    public func newOrder(sku: String? = nil, qty: Int32? = nil, region: GraphFrozenGraph.Region<GraphFrozenGraph.Arena<Brand>>? = nil) -> GraphFrozenGraph.Order<GraphFrozenGraph.Arena<Brand>> {
        let _idx: Int
        _idx = arenaOfOrder.count
        arenaOfOrder.append(GraphFrozenGraph.OrderValues(sku: sku, qty: qty, region: region?.__packed))
        let _packed = UInt64(_idx)
        return GraphFrozenGraph.Order(__packed: _packed, __graph: self)
    }
}

extension GraphFrozenGraph.Arena {
    public func newPerson(name: String? = nil, next: GraphFrozenGraph.Person<GraphFrozenGraph.Arena<Brand>>? = nil) -> GraphFrozenGraph.Person<GraphFrozenGraph.Arena<Brand>> {
        let _idx: Int
        _idx = arenaOfPerson.count
        arenaOfPerson.append(GraphFrozenGraph.PersonValues(name: name, next: next?.__packed))
        let _packed = UInt64(_idx)
        return GraphFrozenGraph.Person(__packed: _packed, __graph: self)
    }
}

extension GraphFrozenGraph.Arena {
    public func newBook(orders: [GraphFrozenGraph.Order<GraphFrozenGraph.Arena<Brand>>] = [], people: [GraphFrozenGraph.Person<GraphFrozenGraph.Arena<Brand>>] = []) -> GraphFrozenGraph.Book<GraphFrozenGraph.Arena<Brand>> {
        let _idx: Int
        _idx = arenaOfBook.count
        arenaOfBook.append(GraphFrozenGraph.BookValues(orders: orders.map { $0.__packed }, people: people.map { $0.__packed }))
        let _packed = UInt64(_idx)
        return GraphFrozenGraph.Book(__packed: _packed, __graph: self)
    }
}

extension GraphFrozenGraph.Arena {
    public func adopt<S: GraphFrozenGraph.RegionGraph>(_ src: GraphFrozenGraph.Region<S>) throws -> GraphFrozenGraph.Region<GraphFrozenGraph.Arena<Brand>> {
        var _seen = Set<UInt64>()
        return try _adopt(src, &_seen)
    }
    func _adopt<S: GraphFrozenGraph.RegionGraph>(_ src: GraphFrozenGraph.Region<S>, _ _seen: inout Set<UInt64>) throws -> GraphFrozenGraph.Region<GraphFrozenGraph.Arena<Brand>> {
        guard _seen.insert((UInt64(0) << 48) | UInt64(src._index)).inserted else { throw DagrError.cyclicAdopt }
        defer { _seen.remove((UInt64(0) << 48) | UInt64(src._index)) }
        return newRegion(code: src.code, note: src.note, version: src.version)
    }
}

extension GraphFrozenGraph.Arena {
    public func adopt<S: GraphFrozenGraph.OrderGraph>(_ src: GraphFrozenGraph.Order<S>) throws -> GraphFrozenGraph.Order<GraphFrozenGraph.Arena<Brand>> {
        var _seen = Set<UInt64>()
        return try _adopt(src, &_seen)
    }
    func _adopt<S: GraphFrozenGraph.OrderGraph>(_ src: GraphFrozenGraph.Order<S>, _ _seen: inout Set<UInt64>) throws -> GraphFrozenGraph.Order<GraphFrozenGraph.Arena<Brand>> {
        guard _seen.insert((UInt64(1) << 48) | UInt64(src._index)).inserted else { throw DagrError.cyclicAdopt }
        defer { _seen.remove((UInt64(1) << 48) | UInt64(src._index)) }
        return newOrder(sku: src.sku, qty: src.qty, region: try src.region.map { try _adopt($0, &_seen) })
    }
}

extension GraphFrozenGraph.Arena {
    public func adopt<S: GraphFrozenGraph.PersonGraph>(_ src: GraphFrozenGraph.Person<S>) throws -> GraphFrozenGraph.Person<GraphFrozenGraph.Arena<Brand>> {
        var _seen = Set<UInt64>()
        return try _adopt(src, &_seen)
    }
    func _adopt<S: GraphFrozenGraph.PersonGraph>(_ src: GraphFrozenGraph.Person<S>, _ _seen: inout Set<UInt64>) throws -> GraphFrozenGraph.Person<GraphFrozenGraph.Arena<Brand>> {
        guard _seen.insert((UInt64(2) << 48) | UInt64(src._index)).inserted else { throw DagrError.cyclicAdopt }
        defer { _seen.remove((UInt64(2) << 48) | UInt64(src._index)) }
        return newPerson(name: src.name, next: try src.next.map { try _adopt($0, &_seen) })
    }
}

extension GraphFrozenGraph.Arena {
    public func adopt<S: GraphFrozenGraph.BookGraph>(_ src: GraphFrozenGraph.Book<S>) throws -> GraphFrozenGraph.Book<GraphFrozenGraph.Arena<Brand>> {
        var _seen = Set<UInt64>()
        return try _adopt(src, &_seen)
    }
    func _adopt<S: GraphFrozenGraph.BookGraph>(_ src: GraphFrozenGraph.Book<S>, _ _seen: inout Set<UInt64>) throws -> GraphFrozenGraph.Book<GraphFrozenGraph.Arena<Brand>> {
        guard _seen.insert((UInt64(3) << 48) | UInt64(src._index)).inserted else { throw DagrError.cyclicAdopt }
        defer { _seen.remove((UInt64(3) << 48) | UInt64(src._index)) }
        return newBook(orders: try src.orders.map { try _adopt($0, &_seen) }, people: try src.people.map { try _adopt($0, &_seen) })
    }
}

extension GraphFrozenGraph.Region: CustomStringConvertible {
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

extension GraphFrozenGraph.Order: CustomStringConvertible {
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

extension GraphFrozenGraph.Person: CustomStringConvertible {
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

extension GraphFrozenGraph.Book: CustomStringConvertible {
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

extension GraphFrozenGraph.Region: Hashable {
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

extension GraphFrozenGraph.Order: Hashable {
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

extension GraphFrozenGraph.Person: Hashable {
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

extension GraphFrozenGraph.Book: Hashable {
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

extension GraphFrozenGraph.Region: Equatable {
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

extension GraphFrozenGraph.Region {
    public static func == <OtherArena: GraphFrozenGraph.RegionGraph>(lhs: Self, rhs: GraphFrozenGraph.Region<OtherArena>) -> Bool {
        var visited = Set<ArenaPair>()
        return lhs.cycleAwareEqualsAny(other: rhs, visited: &visited)
    }

    public static func != <OtherArena: GraphFrozenGraph.RegionGraph>(lhs: Self, rhs: GraphFrozenGraph.Region<OtherArena>) -> Bool {
        return !(lhs == rhs)
    }

    func cycleAwareEqualsAny<OtherArena: GraphFrozenGraph.RegionGraph>(
        other: GraphFrozenGraph.Region<OtherArena>,
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

extension GraphFrozenGraph.Order: Equatable {
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

extension GraphFrozenGraph.Order {
    public static func == <OtherArena: GraphFrozenGraph.OrderGraph>(lhs: Self, rhs: GraphFrozenGraph.Order<OtherArena>) -> Bool {
        var visited = Set<ArenaPair>()
        return lhs.cycleAwareEqualsAny(other: rhs, visited: &visited)
    }

    public static func != <OtherArena: GraphFrozenGraph.OrderGraph>(lhs: Self, rhs: GraphFrozenGraph.Order<OtherArena>) -> Bool {
        return !(lhs == rhs)
    }

    func cycleAwareEqualsAny<OtherArena: GraphFrozenGraph.OrderGraph>(
        other: GraphFrozenGraph.Order<OtherArena>,
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

extension GraphFrozenGraph.Person: Equatable {
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

extension GraphFrozenGraph.Person {
    public static func == <OtherArena: GraphFrozenGraph.PersonGraph>(lhs: Self, rhs: GraphFrozenGraph.Person<OtherArena>) -> Bool {
        var visited = Set<ArenaPair>()
        return lhs.cycleAwareEqualsAny(other: rhs, visited: &visited)
    }

    public static func != <OtherArena: GraphFrozenGraph.PersonGraph>(lhs: Self, rhs: GraphFrozenGraph.Person<OtherArena>) -> Bool {
        return !(lhs == rhs)
    }

    func cycleAwareEqualsAny<OtherArena: GraphFrozenGraph.PersonGraph>(
        other: GraphFrozenGraph.Person<OtherArena>,
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

extension GraphFrozenGraph.Book: Equatable {
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

extension GraphFrozenGraph.Book {
    public static func == <OtherArena: GraphFrozenGraph.BookGraph>(lhs: Self, rhs: GraphFrozenGraph.Book<OtherArena>) -> Bool {
        var visited = Set<ArenaPair>()
        return lhs.cycleAwareEqualsAny(other: rhs, visited: &visited)
    }

    public static func != <OtherArena: GraphFrozenGraph.BookGraph>(lhs: Self, rhs: GraphFrozenGraph.Book<OtherArena>) -> Bool {
        return !(lhs == rhs)
    }

    func cycleAwareEqualsAny<OtherArena: GraphFrozenGraph.BookGraph>(
        other: GraphFrozenGraph.Book<OtherArena>,
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

extension GraphFrozenGraph.Region: ArenaNodeHandle {}
extension GraphFrozenGraph.Region: ArenaGraphStorable {
    var cycleIdentifier: ArenaCycleIdntifier {
        .init(nodeTypeId: Arena.regionTypeId, nodeIndex: __index)
    }

    public func store(with builder: any ArenaBuilder) throws -> BufferOffset {
        if let offset = try builder.beginStoring(nodeId: cycleIdentifier) {
            return offset
        }
        let _noteValueOffset = try self.note?.store(with: builder)
        let _codeValueOffset = try self.code?.store(with: builder)
        _ = try self.version?.store(with: builder)
        _ = try _noteValueOffset?.storeForwardPointer(with: builder)
        _ = try _codeValueOffset?.storeForwardPointer(with: builder)
        var _nilByte: UInt8 = 0
        if self.code != nil { _nilByte |= 1 }
        if self.note != nil { _nilByte |= 2 }
        if self.version != nil { _nilByte |= 4 }
        _ = try builder.store(number: _nilByte)
        let offset = builder.cursor
        try builder.finishStoring(nodeId: cycleIdentifier, offset: offset)
        return offset
    }

    public func storePacked(with builder: any ArenaBuilder) throws -> PackedStoreResult {
        let before = try builder.beginPackedStoring(nodeId: cycleIdentifier)
        let _versionPackedResult = try self.version?.storePacked(with: builder)
        _ = try self.note?.storePacked(with: builder)
        _ = try self.code?.storePacked(with: builder)
        var _encByte: UInt8 = 0
        if _versionPackedResult?.isRaw ?? false { _encByte |= 1 }
        _ = try builder.store(number: _encByte)
        var _nilByte: UInt8 = 0
        if self.code != nil { _nilByte |= 1 }
        if self.note != nil { _nilByte |= 2 }
        if self.version != nil { _nilByte |= 4 }
        _ = try builder.store(number: _nilByte)
        _ = try builder.storeAsLEB(value: builder.cursor.value - before.value)
        return builder.finishPackedStoring(nodeId: cycleIdentifier)
    }
}

extension GraphFrozenGraph.Order: ArenaNodeHandle {}
extension GraphFrozenGraph.Order: ArenaGraphStorable {
    var cycleIdentifier: ArenaCycleIdntifier {
        .init(nodeTypeId: Arena.orderTypeId, nodeIndex: __index)
    }

    public func store(with builder: any ArenaBuilder) throws -> BufferOffset {
        if let offset = try builder.beginStoring(nodeId: cycleIdentifier) {
            return offset
        }
        let _regionValueOffset = try self.region?.store(with: builder)
        let _skuValueOffset = try self.sku?.store(with: builder)
        _ = try _regionValueOffset?.storeBidirectionalPointer(with: builder)
        _ = try self.qty?.store(with: builder)
        _ = try _skuValueOffset?.storeForwardPointer(with: builder)
        var _nilByte: UInt8 = 0
        if self.sku != nil { _nilByte |= 1 }
        if self.qty != nil { _nilByte |= 2 }
        if self.region != nil { _nilByte |= 4 }
        _ = try builder.store(number: _nilByte)
        let offset = builder.cursor
        try builder.finishStoring(nodeId: cycleIdentifier, offset: offset)
        return offset
    }

    public func storePacked(with builder: any ArenaBuilder) throws -> PackedStoreResult {
        let before = try builder.beginPackedStoring(nodeId: cycleIdentifier)
        _ = try self.region?.storePacked(with: builder)
        let _qtyPackedResult = try self.qty?.storePacked(with: builder)
        _ = try self.sku?.storePacked(with: builder)
        var _encByte: UInt8 = 0
        if _qtyPackedResult?.isRaw ?? false { _encByte |= 1 }
        _ = try builder.store(number: _encByte)
        var _nilByte: UInt8 = 0
        if self.sku != nil { _nilByte |= 1 }
        if self.qty != nil { _nilByte |= 2 }
        if self.region != nil { _nilByte |= 4 }
        _ = try builder.store(number: _nilByte)
        _ = try builder.storeAsLEB(value: builder.cursor.value - before.value)
        return builder.finishPackedStoring(nodeId: cycleIdentifier)
    }
}

extension GraphFrozenGraph.Person: ArenaNodeHandle {}
extension GraphFrozenGraph.Person: ArenaGraphStorable {
    var cycleIdentifier: ArenaCycleIdntifier {
        .init(nodeTypeId: Arena.personTypeId, nodeIndex: __index)
    }

    public func store(with builder: any ArenaBuilder) throws -> BufferOffset {
        if let offset = try builder.beginStoring(nodeId: cycleIdentifier) {
            return offset
        }
        let _nextValueOffset = try self.next?.store(with: builder)
        let _nameValueOffset = try self.name?.store(with: builder)
        _ = try _nextValueOffset?.storeBidirectionalPointer(with: builder)
        _ = try _nameValueOffset?.storeForwardPointer(with: builder)
        var _nilByte: UInt8 = 0
        if self.name != nil { _nilByte |= 1 }
        if self.next != nil { _nilByte |= 2 }
        _ = try builder.store(number: _nilByte)
        let offset = builder.cursor
        try builder.finishStoring(nodeId: cycleIdentifier, offset: offset)
        return offset
    }

    public func storePacked(with builder: any ArenaBuilder) throws -> PackedStoreResult {
        let before = try builder.beginPackedStoring(nodeId: cycleIdentifier)
        _ = try self.next?.storePacked(with: builder)
        _ = try self.name?.storePacked(with: builder)
        var _nilByte: UInt8 = 0
        if self.name != nil { _nilByte |= 1 }
        if self.next != nil { _nilByte |= 2 }
        _ = try builder.store(number: _nilByte)
        _ = try builder.storeAsLEB(value: builder.cursor.value - before.value)
        return builder.finishPackedStoring(nodeId: cycleIdentifier)
    }
}

extension GraphFrozenGraph.Book: ArenaNodeHandle {}
extension GraphFrozenGraph.Book: ArenaGraphStorable {
    var cycleIdentifier: ArenaCycleIdntifier {
        .init(nodeTypeId: Arena.bookTypeId, nodeIndex: __index)
    }

    public func store(with builder: any ArenaBuilder) throws -> BufferOffset {
        if let offset = try builder.beginStoring(nodeId: cycleIdentifier) {
            return offset
        }
        let _peopleValueOffset = try self.people.store(with: builder)
        let _ordersValueOffset = try self.orders.store(with: builder)
        _ = try _peopleValueOffset.storeForwardPointer(with: builder)
        _ = try _ordersValueOffset.storeForwardPointer(with: builder)
        var _nilByte: UInt8 = 0
        if !self.orders.isEmpty { _nilByte |= 1 }
        if !self.people.isEmpty { _nilByte |= 2 }
        _ = try builder.store(number: _nilByte)
        let offset = builder.cursor
        try builder.finishStoring(nodeId: cycleIdentifier, offset: offset)
        return offset
    }

    public func storePacked(with builder: any ArenaBuilder) throws -> PackedStoreResult {
        let before = try builder.beginPackedStoring(nodeId: cycleIdentifier)
        _ = try self.people.storePacked(with: builder)
        _ = try self.orders.storePacked(with: builder)
        var _nilByte: UInt8 = 0
        if !self.orders.isEmpty { _nilByte |= 1 }
        if !self.people.isEmpty { _nilByte |= 2 }
        _ = try builder.store(number: _nilByte)
        _ = try builder.storeAsLEB(value: builder.cursor.value - before.value)
        return builder.finishPackedStoring(nodeId: cycleIdentifier)
    }
}

extension GraphFrozenGraph.Arena {
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

    public static func restore(from data: Foundation.Data) throws -> GraphFrozenGraph.Arena<Brand> {
        guard !data.isEmpty else { return GraphFrozenGraph.Arena<Brand>() }
        let arena = GraphFrozenGraph.Arena<Brand>()
        let (framing, lebLen) = try restoreLEB(from: data, at: 0)
        guard (framing & 1) == 0 else { throw ArenaRestoreError.missingHeader }
        guard ((framing >> 1) & 1) == 0 else { throw ArenaRestoreError.invalidFraming }
        let rootStart = lebLen + Int(framing >> 2)
        var cache = [Int: Int]()
        arena.root = try arena._restoreBook(from: data, at: rootStart, cache: &cache)
        return arena
    }

    private func _restoreRegion(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> GraphFrozenGraph.Region<GraphFrozenGraph.Arena<Brand>> {
        if let idx = cache[start] { return GraphFrozenGraph.Region(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfRegion.count
        cache[start] = idx
        arenaOfRegion.append(GraphFrozenGraph.RegionValues())
        var values = GraphFrozenGraph.RegionValues()
        let _obs0 = start + 0 < data.count ? data[start + 0] : UInt8(0)
        var _cur = start + 1
        if _obs0 & 1 != 0 {
            let (_fwd_code, _fwdB_code) = try readV62(from: data, at: _cur)
            _cur += _fwdB_code
            values.code = try String.restore(from: data, at: _cur + Int(_fwd_code))
        }
        if _obs0 & 2 != 0 {
            let (_fwd_note, _fwdB_note) = try readV62(from: data, at: _cur)
            _cur += _fwdB_note
            values.note = try String.restore(from: data, at: _cur + Int(_fwd_note))
        }
        if _obs0 & 4 != 0 {
            values.version = try Int32.restore(from: data, at: _cur)
            _cur += 4
        }
        arenaOfRegion[idx] = values
        return GraphFrozenGraph.Region(__packed: UInt64(idx), __graph: self)
    }

    private func _restoreRegionFrozenPacked(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> GraphFrozenGraph.Region<GraphFrozenGraph.Arena<Brand>> {
        if let idx = cache[start] { return GraphFrozenGraph.Region(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfRegion.count
        cache[start] = idx
        arenaOfRegion.append(GraphFrozenGraph.RegionValues())
        var values = GraphFrozenGraph.RegionValues()
        let (_, _blB) = try restoreLEB(from: data, at: start)
        var _cur = start + _blB
        let _obs0 = _cur + 0 < data.count ? data[_cur + 0] : UInt8(0)
        _cur += 1
        let _ebs0 = _cur + 0 < data.count ? data[_cur + 0] : UInt8(0)
        _cur += 1
        if _obs0 & 1 != 0 {
            let (_sv_code, _sb_code) = try restoreLEB(from: data, at: _cur); _cur += _sb_code
            values.code = _dagrUTF8(data[_cur..<(_cur + Int(_sv_code))])
            _cur += Int(_sv_code)
        }
        if _obs0 & 2 != 0 {
            let (_sv_note, _sb_note) = try restoreLEB(from: data, at: _cur); _cur += _sb_note
            values.note = _dagrUTF8(data[_cur..<(_cur + Int(_sv_note))])
            _cur += Int(_sv_note)
        }
        if _obs0 & 4 != 0 {
            if _ebs0 & 1 != 0 {
                values.version = try Int32.restore(from: data, at: _cur); _cur += 4
            } else {
                let (_lv_version, _lb_version) = try restoreLEB(from: data, at: _cur)
                values.version = Int32(_lv_version.fromZigZag); _cur += _lb_version
            }
        }
        arenaOfRegion[idx] = values
        return GraphFrozenGraph.Region(__packed: UInt64(idx), __graph: self)
    }

    private func _restoreOrder(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> GraphFrozenGraph.Order<GraphFrozenGraph.Arena<Brand>> {
        if let idx = cache[start] { return GraphFrozenGraph.Order(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfOrder.count
        cache[start] = idx
        arenaOfOrder.append(GraphFrozenGraph.OrderValues())
        var values = GraphFrozenGraph.OrderValues()
        let _obs0 = start + 0 < data.count ? data[start + 0] : UInt8(0)
        var _cur = start + 1
        if _obs0 & 1 != 0 {
            let (_fwd_sku, _fwdB_sku) = try readV62(from: data, at: _cur)
            _cur += _fwdB_sku
            values.sku = try String.restore(from: data, at: _cur + Int(_fwd_sku))
        }
        if _obs0 & 2 != 0 {
            values.qty = try Int32.restore(from: data, at: _cur)
            _cur += 4
        }
        if _obs0 & 4 != 0 {
            let (_bd_region, _bdb_region) = try readZigZagV62(from: data, at: _cur)
            _cur += _bdb_region
            values.region = try _restoreRegion(from: data, at: _cur + _bd_region, cache: &cache).__packed
        }
        arenaOfOrder[idx] = values
        return GraphFrozenGraph.Order(__packed: UInt64(idx), __graph: self)
    }

    private func _restoreOrderFrozenPacked(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> GraphFrozenGraph.Order<GraphFrozenGraph.Arena<Brand>> {
        if let idx = cache[start] { return GraphFrozenGraph.Order(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfOrder.count
        cache[start] = idx
        arenaOfOrder.append(GraphFrozenGraph.OrderValues())
        var values = GraphFrozenGraph.OrderValues()
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
            let (_bl_region, _blB_region) = try restoreLEB(from: data, at: _cur)
            values.region = try _restoreRegionFrozenPacked(from: data, at: _cur, cache: &cache).__packed
            _cur += _blB_region + Int(_bl_region)
        }
        arenaOfOrder[idx] = values
        return GraphFrozenGraph.Order(__packed: UInt64(idx), __graph: self)
    }

    private func _restorePerson(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> GraphFrozenGraph.Person<GraphFrozenGraph.Arena<Brand>> {
        if let idx = cache[start] { return GraphFrozenGraph.Person(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfPerson.count
        cache[start] = idx
        arenaOfPerson.append(GraphFrozenGraph.PersonValues())
        var values = GraphFrozenGraph.PersonValues()
        let _obs0 = start + 0 < data.count ? data[start + 0] : UInt8(0)
        var _cur = start + 1
        if _obs0 & 1 != 0 {
            let (_fwd_name, _fwdB_name) = try readV62(from: data, at: _cur)
            _cur += _fwdB_name
            values.name = try String.restore(from: data, at: _cur + Int(_fwd_name))
        }
        if _obs0 & 2 != 0 {
            let (_bd_next, _bdb_next) = try readZigZagV62(from: data, at: _cur)
            _cur += _bdb_next
            values.next = try _restorePerson(from: data, at: _cur + _bd_next, cache: &cache).__packed
        }
        arenaOfPerson[idx] = values
        return GraphFrozenGraph.Person(__packed: UInt64(idx), __graph: self)
    }

    private func _restorePersonFrozenPacked(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> GraphFrozenGraph.Person<GraphFrozenGraph.Arena<Brand>> {
        if let idx = cache[start] { return GraphFrozenGraph.Person(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfPerson.count
        cache[start] = idx
        arenaOfPerson.append(GraphFrozenGraph.PersonValues())
        var values = GraphFrozenGraph.PersonValues()
        let (_, _blB) = try restoreLEB(from: data, at: start)
        var _cur = start + _blB
        let _obs0 = _cur + 0 < data.count ? data[_cur + 0] : UInt8(0)
        _cur += 1
        if _obs0 & 1 != 0 {
            let (_sv_name, _sb_name) = try restoreLEB(from: data, at: _cur); _cur += _sb_name
            values.name = _dagrUTF8(data[_cur..<(_cur + Int(_sv_name))])
            _cur += Int(_sv_name)
        }
        if _obs0 & 2 != 0 {
            let (_bl_next, _blB_next) = try restoreLEB(from: data, at: _cur)
            values.next = try _restorePersonFrozenPacked(from: data, at: _cur, cache: &cache).__packed
            _cur += _blB_next + Int(_bl_next)
        }
        arenaOfPerson[idx] = values
        return GraphFrozenGraph.Person(__packed: UInt64(idx), __graph: self)
    }

    private func _restoreBook(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> GraphFrozenGraph.Book<GraphFrozenGraph.Arena<Brand>> {
        if let idx = cache[start] { return GraphFrozenGraph.Book(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfBook.count
        cache[start] = idx
        arenaOfBook.append(GraphFrozenGraph.BookValues())
        var values = GraphFrozenGraph.BookValues()
        var _cur = start + 1
        let (_fwd_orders, _fwdB_orders) = try readV62(from: data, at: _cur)
        _cur += _fwdB_orders
        let (_h_orders, _hl_orders) = try restoreLEB(from: data, at: _cur + Int(_fwd_orders))
        let _cnt_orders = Int(_h_orders >> 2); let _wc_orders = Int(_h_orders & 3)
        let _es_orders = [1,2,4,8][_wc_orders]
        let _base_orders = _cur + Int(_fwd_orders) + _hl_orders + _cnt_orders * _es_orders
        var _arr_orders = [UInt64]()
        for _k_orders in 0..<_cnt_orders {
            let _ep_orders = _cur + Int(_fwd_orders) + _hl_orders + _k_orders * _es_orders
            let _ro_orders = try readSignedRelOffset(from: data, at: _ep_orders, size: _es_orders)
            if _ro_orders != 0 {
                _arr_orders.append(try _restoreOrder(from: data, at: _base_orders + Int(_ro_orders) - 1, cache: &cache).__packed)
            }
        }
        values.orders = _arr_orders
        let (_fwd_people, _fwdB_people) = try readV62(from: data, at: _cur)
        _cur += _fwdB_people
        let (_h_people, _hl_people) = try restoreLEB(from: data, at: _cur + Int(_fwd_people))
        let _cnt_people = Int(_h_people >> 2); let _wc_people = Int(_h_people & 3)
        let _es_people = [1,2,4,8][_wc_people]
        let _base_people = _cur + Int(_fwd_people) + _hl_people + _cnt_people * _es_people
        var _arr_people = [UInt64]()
        for _k_people in 0..<_cnt_people {
            let _ep_people = _cur + Int(_fwd_people) + _hl_people + _k_people * _es_people
            let _ro_people = try readSignedRelOffset(from: data, at: _ep_people, size: _es_people)
            if _ro_people != 0 {
                _arr_people.append(try _restorePerson(from: data, at: _base_people + Int(_ro_people) - 1, cache: &cache).__packed)
            }
        }
        values.people = _arr_people
        arenaOfBook[idx] = values
        return GraphFrozenGraph.Book(__packed: UInt64(idx), __graph: self)
    }

    private func _restoreBookFrozenPacked(from data: Foundation.Data, at start: Int, cache: inout [Int: Int]) throws -> GraphFrozenGraph.Book<GraphFrozenGraph.Arena<Brand>> {
        if let idx = cache[start] { return GraphFrozenGraph.Book(__packed: UInt64(idx), __graph: self) }
        let idx = arenaOfBook.count
        cache[start] = idx
        arenaOfBook.append(GraphFrozenGraph.BookValues())
        var values = GraphFrozenGraph.BookValues()
        let (_, _blB) = try restoreLEB(from: data, at: start)
        var _cur = start + _blB
        _cur += 1
        let (_bbl_orders, _bblB_orders) = try restoreLEB(from: data, at: _cur)
        let _bend_orders = _cur + _bblB_orders + Int(_bbl_orders)
        _cur += _bblB_orders
        let (_cnt_orders, _cntB_orders) = try restoreLEB(from: data, at: _cur)
        _cur += _cntB_orders
        var _arr_orders = [UInt64]()
        for _ in 0..<Int(_cnt_orders) {
            let (_el_bl_orders, _el_blB_orders) = try restoreLEB(from: data, at: _cur)
            _arr_orders.append(try _restoreOrderFrozenPacked(from: data, at: _cur, cache: &cache).__packed)
            _cur += _el_blB_orders + Int(_el_bl_orders)
        }
        values.orders = _arr_orders
        _cur = _bend_orders
        let (_bbl_people, _bblB_people) = try restoreLEB(from: data, at: _cur)
        let _bend_people = _cur + _bblB_people + Int(_bbl_people)
        _cur += _bblB_people
        let (_cnt_people, _cntB_people) = try restoreLEB(from: data, at: _cur)
        _cur += _cntB_people
        var _arr_people = [UInt64]()
        for _ in 0..<Int(_cnt_people) {
            let (_el_bl_people, _el_blB_people) = try restoreLEB(from: data, at: _cur)
            _arr_people.append(try _restorePersonFrozenPacked(from: data, at: _cur, cache: &cache).__packed)
            _cur += _el_blB_people + Int(_el_bl_people)
        }
        values.people = _arr_people
        _cur = _bend_people
        arenaOfBook[idx] = values
        return GraphFrozenGraph.Book(__packed: UInt64(idx), __graph: self)
    }

}
