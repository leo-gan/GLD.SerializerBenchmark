import XCTest
@testable import SerializerBenchmarkCore

final class RoundtripTests: XCTestCase {
    private func roundtrip(_ ser: any BenchSerializer, _ fx: Fixture) throws {
        try ser.prepare(fx)
        let data = try ser.serializeBytes(fx)
        XCTAssertFalse(data.isEmpty, "\(ser.name) empty for \(fx.name)")
        var out = try ser.deserializeBytes(data)
        if let conv = ser as? DomainConverter {
            out = try conv.toDomain(out)
        }
        XCTAssertTrue(fx.fidelity(against: out), "\(ser.name) fidelity for \(fx.name)")
    }

    func testCompressSizesGzipHello() {
        let c = compressSizes(Data("hello".utf8))
        XCTAssertGreaterThanOrEqual(c.gzip, 20)
        XCTAssertLessThanOrEqual(c.gzip, 40)
        XCTAssertEqual(compressSizes(Data()).gzip, 0)
    }

    func testAllSerializersRoundtripAllTypes() throws {
        for typeId in ["message", "document", "telemetry", "strings", "event"] {
            let fx = try fixtureFromCell(
                typeId: typeId,
                typeConfig: [:],
                typeConfigHash: "",
                instanceCount: 1,
                seed: 42
            )
            for ser in allSerializers() {
                try roundtrip(ser, fx)
            }
        }
    }

    func testBatchRoundtrip() throws {
        let fx = try fixtureFromCell(
            typeId: "message",
            typeConfig: [:],
            typeConfigHash: "",
            instanceCount: 8,
            seed: 7
        )
        XCTAssertEqual(fx.instanceCount, 8)
        XCTAssertTrue(fx.needsMapRoot)
        for ser in allSerializers() {
            try roundtrip(ser, fx)
        }
    }

    /// Dagr frames N>1 itself (u32 count + (u32 len + buffer)×N) — cover every type.
    /// Covers all four layouts (dagr-packed, dagr-regular, dagr-frozen, dagr-frozen-packed), N=1 and N>1.
    func testDagrBatchRoundtripAllTypes() throws {
        for layout in DagrLayout.allCases {
            let ser = DagrSerializer(layout: layout)
            XCTAssertEqual(ser.name, layout.rawValue)
            XCTAssertNotEqual(ser.version, "unknown")
            for typeId in ["message", "document", "telemetry", "strings", "event"] {
                for n in [1, 5] {
                    let fx = try fixtureFromCell(
                        typeId: typeId, typeConfig: [:], typeConfigHash: "", instanceCount: n, seed: 11
                    )
                    try roundtrip(ser, fx)
                    XCTAssertTrue(
                        fx.fidelity(against: try ser.deserializeStream(ser.serializeStream(fx).0)),
                        "\(layout.rawValue) \(typeId) n=\(n)"
                    )
                }
            }
        }
    }

    func testWrappersStayTypeAgnostic() throws {
        let msg = Message(
            f_bool: true, f_int32: 1, f_int64: 2, f_float64: 3.0, f_string: "a",
            f_bool_2: false, f_int32_2: 4, f_string_2: "b"
        )
        let fx = Fixture(name: "message", value: msg)
        let ser = FoundationJSONSerializer()
        try roundtrip(ser, fx)
    }

    func testAdaptedStreamDoesRealIO() throws {
        let fx = try fixtureFromCell(
            typeId: "message", typeConfig: [:], typeConfigHash: "", instanceCount: 1, seed: 1
        )
        let ser = FoundationJSONSerializer()
        try ser.prepare(fx)
        let (streamData, n) = try ser.serializeStream(fx)
        XCTAssertEqual(n, streamData.count)
        XCTAssertFalse(streamData.isEmpty)
        var out = try ser.deserializeStream(streamData)
        if let conv = ser as? DomainConverter { out = try conv.toDomain(out) }
        XCTAssertTrue(fx.fidelity(against: out))
    }

    func testScheduleGolden() {
        let seed = Schedule.deriveScheduleSeed(
            baseSeed: 42, typeId: "message", instanceCount: 1,
            typeConfigHash: "abc", mode: "bytes", rep: 0
        )
        XCTAssertEqual(seed, 15992650003647724414)
        XCTAssertEqual(Schedule.goldenPermutation(), ["C", "B", "A"])
        let a = Schedule.deriveScheduleSeed(
            baseSeed: 42, typeId: "message", instanceCount: 1,
            typeConfigHash: "abc", mode: "bytes", rep: 0
        )
        let b = Schedule.deriveScheduleSeed(
            baseSeed: 42, typeId: "message", instanceCount: 1,
            typeConfigHash: "abc", mode: "string", rep: 0
        )
        XCTAssertEqual(a, b)
    }

    func testGraphGeneratorShapeIdentityAndCallOrder() throws {
        let book = try makeOne(typeId: "graph", typeConfig: [:], seed: 42, instanceIndex: 0) as! Book
        let explicit: [String: Any] = [
            "order_count": 32,
            "region_count": 4,
            "ring_size": 8,
            "string_len": ["min": 8, "max": 16],
        ]
        let sameDefaults = try makeOne(
            typeId: "graph", typeConfig: explicit, seed: 42, instanceIndex: 0
        ) as! Book
        XCTAssertTrue(semanticEqual(book, sameDefaults))

        XCTAssertEqual(book.orders.count, 32)
        XCTAssertEqual(book.people.count, 8)
        var counts: [ObjectIdentifier: Int] = [:]
        for (i, order) in book.orders.enumerated() {
            XCTAssertTrue(order.region === book.orders[i % 4].region)
            XCTAssertGreaterThanOrEqual(order.sku.count, 8)
            XCTAssertLessThanOrEqual(order.sku.count, 16)
            XCTAssertGreaterThanOrEqual(order.qty, 1)
            XCTAssertLessThanOrEqual(order.qty, 100)
            XCTAssertEqual(order.region.note.count, 64)
            XCTAssertGreaterThanOrEqual(order.region.code.count, 8)
            XCTAssertLessThanOrEqual(order.region.code.count, 16)
            XCTAssertGreaterThanOrEqual(order.region.version, 1)
            XCTAssertLessThanOrEqual(order.region.version, 10)
            counts[ObjectIdentifier(order.region), default: 0] += 1
        }
        XCTAssertEqual(counts.count, 4)
        XCTAssertTrue(counts.values.allSatisfy { $0 == 8 })
        XCTAssertEqual(Set(book.orders.map(\.sku)).count, 32)
        for (i, person) in book.people.enumerated() {
            XCTAssertTrue(person.next === book.people[(i + 1) % 8])
            XCTAssertGreaterThanOrEqual(person.name.count, 8)
            XCTAssertLessThanOrEqual(person.name.count, 16)
        }
        var node: Person? = book.people[0]
        for _ in 0..<8 { node = node?.next }
        XCTAssertTrue(node === book.people[0])

        // Locks generator call order for this PRNG: regions, then orders, then names.
        XCTAssertEqual(book.orders[0].region.code, "aziohqapki")
        XCTAssertEqual(book.orders[0].region.version, 10)
        XCTAssertEqual(
            book.orders[0].region.note,
            "cdcqzthkbpeamczbaiiginztheqddazgojrieymjcgdyxortyhqrnowslfzgykbo"
        )
        XCTAssertEqual(book.orders[0].sku, "mizcgcjvijhsdnu")
        XCTAssertEqual(book.orders[0].qty, 60)
        XCTAssertEqual(book.orders[1].sku, "gxnwoxkiqyfad")
        XCTAssertEqual(book.orders[1].qty, 75)
        XCTAssertEqual(book.orders[1].region.code, "ehigtenjtxtiukc")
        XCTAssertEqual(book.people[0].name, "lrsykrmsdjdcmmit")
        XCTAssertEqual(book.people[1].name, "pccskypr")

        let again = try makeOne(typeId: "graph", typeConfig: [:], seed: 42, instanceIndex: 0) as! Book
        XCTAssertTrue(semanticEqual(book, again))
        XCTAssertFalse(book.orders[0].region === again.orders[0].region)
        let other = try makeOne(typeId: "graph", typeConfig: [:], seed: 42, instanceIndex: 1) as! Book
        XCTAssertFalse(semanticEqual(book, other))
        XCTAssertFalse(sharesGraphNodes(book, other))

        let batch = try fixtureFromCell(
            typeId: "graph", typeConfig: [:], typeConfigHash: "", instanceCount: 2, seed: 42
        )
        let books = batch.value as! [Book]
        XCTAssertEqual(books.count, 2)
        XCTAssertEqual(batch.instanceCount, 2)
        XCTAssertFalse(sharesGraphNodes(books[0], books[1]))
        XCTAssertTrue(semanticEqual(books, [book, other]))

        let one = try makeOne(
            typeId: "graph",
            typeConfig: ["ring_size": 1, "region_count": 1, "order_count": 2],
            seed: 3,
            instanceIndex: 0
        ) as! Book
        XCTAssertEqual(one.people.count, 1)
        XCTAssertTrue(one.people[0].next === one.people[0])
        XCTAssertTrue(one.orders[0].region === one.orders[1].region)
        XCTAssertEqual(one.orders[0].sku, "bqmqyklxj")
        XCTAssertEqual(one.orders[0].qty, 61)
        XCTAssertEqual(one.orders[0].region.code, "fdfiysahlhocx")
        XCTAssertEqual(one.orders[0].region.version, 2)
        XCTAssertEqual(one.orders[1].sku, "fasqwdfbfm")
        XCTAssertEqual(one.people[0].name, "fqpcwkskbis")
        XCTAssertTrue(semanticEqual(one, aliasGraph(one)))

        XCTAssertThrowsError(
            try makeOne(typeId: "graph", typeConfig: ["region_count": 0], seed: 1, instanceIndex: 0)
        )
        XCTAssertThrowsError(
            try makeOne(typeId: "graph", typeConfig: ["ring_size": 0], seed: 1, instanceIndex: 0)
        )
    }

    func testGraphFidelityRejectsDuplicatedRegionAndBrokenRing() throws {
        let book = try makeOne(typeId: "graph", typeConfig: [:], seed: 42, instanceIndex: 0) as! Book
        XCTAssertTrue(semanticEqual(book, aliasGraph(book)))
        XCTAssertFalse(semanticEqual(book, dupRegions(book)))
        let broken = aliasGraph(book)
        broken.people[0].next = Person(name: broken.people[1].name)
        XCTAssertFalse(semanticEqual(book, broken))
        var orders = book.orders
        orders[0] = Order(sku: orders[0].sku, qty: orders[0].qty + 1, region: orders[0].region)
        XCTAssertFalse(semanticEqual(book, Book(orders: orders, people: book.people)))

        let edited = aliasGraph(book)
        let src = ObjectIdentifier(edited.orders[0].region)
        var chars = Array(edited.orders[0].region.note)
        chars[0] = chars[0] == "a" ? "b" : "a"
        let replacement = Region(
            code: edited.orders[0].region.code,
            note: String(chars),
            version: edited.orders[0].region.version
        )
        let tweaked = edited.orders.map { order -> Order in
            if ObjectIdentifier(order.region) == src {
                return Order(sku: order.sku, qty: order.qty, region: replacement)
            }
            return order
        }
        XCTAssertFalse(semanticEqual(book, Book(orders: tweaked, people: edited.people)))
        XCTAssertTrue(tweaked[0].region === tweaked[4].region)
        XCTAssertFalse(tweaked[0].region === tweaked[1].region)
    }

    func testOnlyArenaDagrSupportsGraph() {
        for ser in allSerializers() {
            let want = ser.name == "dagr-regular" || ser.name == "dagr-frozen"
            XCTAssertEqual(ser.supports(testDataName: "graph"), want, ser.name)
        }
        XCTAssertFalse(DagrSerializer(layout: .packed).supports(testDataName: "graph"))
        XCTAssertFalse(DagrSerializer(layout: .frozenPacked).supports(testDataName: "graph"))
        XCTAssertTrue(DagrSerializer(layout: .regular).supports(testDataName: "message"))
        XCTAssertFalse(DagrSerializer(layout: .regular).supports(testDataName: "table"))
    }

    func testGraphDagrRoundTrip() throws {
        let book = try makeOne(typeId: "graph", typeConfig: [:], seed: 42, instanceIndex: 0) as! Book
        let other = try makeOne(typeId: "graph", typeConfig: [:], seed: 42, instanceIndex: 1) as! Book
        let ring1 = try makeOne(
            typeId: "graph",
            typeConfig: ["ring_size": 1, "region_count": 1, "order_count": 4],
            seed: 7,
            instanceIndex: 0
        ) as! Book
        let cases: [Fixture] = [
            try fixtureFromCell(
                typeId: "graph", typeConfig: [:], typeConfigHash: "", instanceCount: 1, seed: 42
            ),
            try fixtureFromCell(
                typeId: "graph", typeConfig: [:], typeConfigHash: "", instanceCount: 2, seed: 42
            ),
            Fixture(name: "graph", value: ring1),
        ]
        XCTAssertTrue(cases[0].fidelity(against: book))
        XCTAssertTrue(cases[1].fidelity(against: [book, other]))
        for layout in [DagrLayout.regular, DagrLayout.frozen] {
            let ser = DagrSerializer(layout: layout)
            for fx in cases {
                try ser.prepare(fx)
                let data = try ser.serializeBytes(fx)
                XCTAssertFalse(data.isEmpty, layout.rawValue)
                let out = try ser.deserializeBytes(data)
                XCTAssertTrue(fx.fidelity(against: out), layout.rawValue)
                assertDecodedGraph(out)
                let (streamData, n) = try ser.serializeStream(fx)
                XCTAssertEqual(n, streamData.count)
                let streamed = try ser.deserializeStream(streamData)
                XCTAssertTrue(fx.fidelity(against: streamed), "\(layout.rawValue) stream")
                assertDecodedGraph(streamed)
            }
        }
    }

    private func sharesGraphNodes(_ a: Book, _ b: Book) -> Bool {
        var regs = Set<ObjectIdentifier>()
        var people = Set<ObjectIdentifier>()
        for order in a.orders { regs.insert(ObjectIdentifier(order.region)) }
        for person in a.people { people.insert(ObjectIdentifier(person)) }
        for order in b.orders where regs.contains(ObjectIdentifier(order.region)) { return true }
        for person in b.people where people.contains(ObjectIdentifier(person)) { return true }
        return false
    }

    private func aliasGraph(_ book: Book) -> Book {
        var regs: [ObjectIdentifier: Region] = [:]
        let orders = book.orders.map { order -> Order in
            let id = ObjectIdentifier(order.region)
            let region: Region
            if let found = regs[id] {
                region = found
            } else {
                region = Region(code: order.region.code, note: order.region.note, version: order.region.version)
                regs[id] = region
            }
            return Order(sku: order.sku, qty: order.qty, region: region)
        }
        let people = book.people.map { Person(name: $0.name) }
        var back: [ObjectIdentifier: Person] = [:]
        for (orig, copy) in zip(book.people, people) {
            back[ObjectIdentifier(orig)] = copy
        }
        for (orig, copy) in zip(book.people, people) {
            if let nxt = orig.next {
                copy.next = back[ObjectIdentifier(nxt)]
            }
        }
        return Book(orders: orders, people: people)
    }

    private func dupRegions(_ book: Book) -> Book {
        let copy = aliasGraph(book)
        let orders = copy.orders.map { order in
            Order(
                sku: order.sku,
                qty: order.qty,
                region: Region(code: order.region.code, note: order.region.note, version: order.region.version)
            )
        }
        return Book(orders: orders, people: copy.people)
    }

    private func assertDecodedGraph(_ value: Any, file: StaticString = #filePath, line: UInt = #line) {
        if let book = value as? Book {
            assertBookIdentity(book, file: file, line: line)
        } else if let books = value as? [Book] {
            XCTAssertGreaterThanOrEqual(books.count, 2, file: file, line: line)
            for book in books { assertBookIdentity(book, file: file, line: line) }
            XCTAssertFalse(sharesGraphNodes(books[0], books[1]), file: file, line: line)
        } else {
            XCTFail("decoded \(type(of: value))", file: file, line: line)
        }
    }

    private func assertBookIdentity(_ book: Book, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(book.orders.isEmpty, file: file, line: line)
        XCTAssertFalse(book.people.isEmpty, file: file, line: line)
        var regs: [ObjectIdentifier: Int] = [:]
        for order in book.orders {
            XCTAssertEqual(order.region.note.count, 64, file: file, line: line)
            regs[ObjectIdentifier(order.region), default: 0] += 1
        }
        if book.orders.count > regs.count {
            XCTAssertTrue(regs.values.allSatisfy { $0 >= 2 }, "shared region was copied", file: file, line: line)
        }
        let n = book.people.count
        for (i, person) in book.people.enumerated() {
            XCTAssertTrue(person.next === book.people[(i + 1) % n], file: file, line: line)
        }
    }

}
