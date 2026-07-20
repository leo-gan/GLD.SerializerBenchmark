import Foundation
import CapnpBridge

/// Domain ↔ Cap'n Proto C bridge. Conversion is type-aware (schema codecs require it).
enum CapnpBridgeSwift {
    private static func dataFromPtr(_ ptr: UnsafeMutableRawPointer?, len: Int, name: String) throws -> Data {
        guard let ptr else { throw BenchError.unsupported("capnp encode failed for \(name)") }
        defer { capnp_free(ptr) }
        return Data(bytes: ptr, count: len)
    }

    /// Bind monomorphic encode once in prepare (issue #59).
    static func bindEncode(for fixture: Fixture) throws -> (Fixture) throws -> Data {
        let batch = fixture.instanceCount > 1
        let name = fixture.name
        switch name {
        case "message":
            return batch
                ? { fx in
                    var len = 0
                    let ptr = encodeMessages(fx.value as! [Message], &len)
                    return try dataFromPtr(ptr, len: len, name: name)
                }
                : { fx in
                    var len = 0
                    let ptr = encodeOneMessage(fx.value as! Message, &len)
                    return try dataFromPtr(ptr, len: len, name: name)
                }
        case "document":
            return batch
                ? { fx in
                    var len = 0
                    let ptr = encodeDocuments(fx.value as! [Document], &len)
                    return try dataFromPtr(ptr, len: len, name: name)
                }
                : { fx in
                    var len = 0
                    let ptr = encodeOneDocument(fx.value as! Document, &len)
                    return try dataFromPtr(ptr, len: len, name: name)
                }
        case "telemetry":
            return batch
                ? { fx in
                    var len = 0
                    let ptr = encodeTelemetries(fx.value as! [Telemetry], &len)
                    return try dataFromPtr(ptr, len: len, name: name)
                }
                : { fx in
                    var len = 0
                    let ptr = encodeOneTelemetry(fx.value as! Telemetry, &len)
                    return try dataFromPtr(ptr, len: len, name: name)
                }
        case "strings":
            return batch
                ? { fx in
                    var len = 0
                    let ptr = encodeStringsList(fx.value as! [Strings], &len)
                    return try dataFromPtr(ptr, len: len, name: name)
                }
                : { fx in
                    var len = 0
                    let ptr = encodeOneStrings(fx.value as! Strings, &len)
                    return try dataFromPtr(ptr, len: len, name: name)
                }
        case "event":
            return batch
                ? { fx in
                    var len = 0
                    let ptr = encodeEvents(fx.value as! [Event], &len)
                    return try dataFromPtr(ptr, len: len, name: name)
                }
                : { fx in
                    var len = 0
                    let ptr = encodeOneEvent(fx.value as! Event, &len)
                    return try dataFromPtr(ptr, len: len, name: name)
                }
        default:
            throw BenchError.unknownType(name)
        }
    }

    static func bindDecode(for fixture: Fixture) throws -> (Data) throws -> Any {
        let batch = fixture.instanceCount > 1
        let name = fixture.name
        switch name {
        case "message":
            return batch
                ? { data in
                    try data.withUnsafeBytes { raw -> Any in
                        let base = raw.baseAddress!
                        var out: UnsafeMutablePointer<CapnpCMessage>?
                        var count = 0
                        guard capnp_decode_batch_message(base, data.count, &out, &count) == 0, let out else {
                            throw BenchError.fidelity
                        }
                        defer { capnp_free_batch_message(out, count) }
                        return (0..<count).map { messageFrom(out[$0]) }
                    }
                }
                : { data in
                    try data.withUnsafeBytes { raw -> Any in
                        var o = CapnpCMessage()
                        guard capnp_decode_message(raw.baseAddress!, data.count, &o) == 0 else {
                            throw BenchError.fidelity
                        }
                        defer { capnp_free_message(&o) }
                        return messageFrom(o)
                    }
                }
        case "document":
            return batch
                ? { data in
                    try data.withUnsafeBytes { raw -> Any in
                        var out: UnsafeMutablePointer<CapnpCDocument>?
                        var count = 0
                        guard capnp_decode_batch_document(raw.baseAddress!, data.count, &out, &count) == 0,
                              let out else { throw BenchError.fidelity }
                        defer { capnp_free_batch_document(out, count) }
                        return (0..<count).map { documentFrom(out[$0]) }
                    }
                }
                : { data in
                    try data.withUnsafeBytes { raw -> Any in
                        var o = CapnpCDocument()
                        guard capnp_decode_document(raw.baseAddress!, data.count, &o) == 0 else {
                            throw BenchError.fidelity
                        }
                        defer { capnp_free_document(&o) }
                        return documentFrom(o)
                    }
                }
        case "telemetry":
            return batch
                ? { data in
                    try data.withUnsafeBytes { raw -> Any in
                        var out: UnsafeMutablePointer<CapnpCTelemetry>?
                        var count = 0
                        guard capnp_decode_batch_telemetry(raw.baseAddress!, data.count, &out, &count) == 0,
                              let out else { throw BenchError.fidelity }
                        defer { capnp_free_batch_telemetry(out, count) }
                        return (0..<count).map { telemetryFrom(out[$0]) }
                    }
                }
                : { data in
                    try data.withUnsafeBytes { raw -> Any in
                        var o = CapnpCTelemetry()
                        guard capnp_decode_telemetry(raw.baseAddress!, data.count, &o) == 0 else {
                            throw BenchError.fidelity
                        }
                        defer { capnp_free_telemetry(&o) }
                        return telemetryFrom(o)
                    }
                }
        case "strings":
            return batch
                ? { data in
                    try data.withUnsafeBytes { raw -> Any in
                        var out: UnsafeMutablePointer<CapnpCStrings>?
                        var count = 0
                        guard capnp_decode_batch_strings(raw.baseAddress!, data.count, &out, &count) == 0,
                              let out else { throw BenchError.fidelity }
                        defer { capnp_free_batch_strings(out, count) }
                        return (0..<count).map { stringsFrom(out[$0]) }
                    }
                }
                : { data in
                    try data.withUnsafeBytes { raw -> Any in
                        var o = CapnpCStrings()
                        guard capnp_decode_strings(raw.baseAddress!, data.count, &o) == 0 else {
                            throw BenchError.fidelity
                        }
                        defer { capnp_free_strings(&o) }
                        return stringsFrom(o)
                    }
                }
        case "event":
            return batch
                ? { data in
                    try data.withUnsafeBytes { raw -> Any in
                        var out: UnsafeMutablePointer<CapnpCEvent>?
                        var count = 0
                        guard capnp_decode_batch_event(raw.baseAddress!, data.count, &out, &count) == 0,
                              let out else { throw BenchError.fidelity }
                        defer { capnp_free_batch_event(out, count) }
                        return (0..<count).map { eventFrom(out[$0]) }
                    }
                }
                : { data in
                    try data.withUnsafeBytes { raw -> Any in
                        var o = CapnpCEvent()
                        guard capnp_decode_event(raw.baseAddress!, data.count, &o) == 0 else {
                            throw BenchError.fidelity
                        }
                        defer { capnp_free_event(&o) }
                        return eventFrom(o)
                    }
                }
        default:
            throw BenchError.unknownType(name)
        }
    }

    // Legacy wrappers kept for any remaining call sites.
    static func encode(_ fixture: Fixture) throws -> Data {
        try bindEncode(for: fixture)(fixture)
    }

    static func decode(_ data: Data, fixture: Fixture) throws -> Any {
        try bindDecode(for: fixture)(data)
    }

    // MARK: encode helpers (strdup held for call duration)

    private static func encodeOneMessage(_ m: Message, _ len: inout Int) -> UnsafeMutableRawPointer? {
        m.f_string.withCString { s1 in
            m.f_string_2.withCString { s2 in
                var c = CapnpCMessage(
                    f_bool: m.f_bool, f_int32: m.f_int32, f_int64: m.f_int64, f_float64: m.f_float64,
                    f_string: s1, f_bool_2: m.f_bool_2, f_int32_2: m.f_int32_2, f_string_2: s2
                )
                return capnp_encode_message(&c, &len)
            }
        }
    }

    private static func encodeMessages(_ items: [Message], _ len: inout Int) -> UnsafeMutableRawPointer? {
        // strdup so C strings outlive CapnpCMessage construction until encode returns.
        var heap1: [UnsafeMutablePointer<CChar>] = items.map { strdup($0.f_string)! }
        var heap2: [UnsafeMutablePointer<CChar>] = items.map { strdup($0.f_string_2)! }
        defer { heap1.forEach { free($0) }; heap2.forEach { free($0) } }
        var citems = [CapnpCMessage](repeating: CapnpCMessage(), count: items.count)
        for i in items.indices {
            citems[i] = CapnpCMessage(
                f_bool: items[i].f_bool, f_int32: items[i].f_int32, f_int64: items[i].f_int64,
                f_float64: items[i].f_float64, f_string: heap1[i],
                f_bool_2: items[i].f_bool_2, f_int32_2: items[i].f_int32_2, f_string_2: heap2[i]
            )
        }
        return citems.withUnsafeBufferPointer { capnp_encode_batch_message($0.baseAddress, $0.count, &len) }
    }

    private static func encodeOneDocument(_ d: Document, _ len: inout Int) -> UnsafeMutableRawPointer? {
        var items = d.items.map { CapnpCDocumentItem(sku: nil, qty: $0.qty, price_minor: $0.price_minor) }
        var skuHeap: [UnsafeMutablePointer<CChar>] = d.items.map { strdup($0.sku)! }
        defer { skuHeap.forEach { free($0) } }
        for i in items.indices { items[i].sku = UnsafePointer(skuHeap[i]) }
        return d.id.withCString { idp in
            d.meta.region.withCString { reg in
                items.withUnsafeBufferPointer { ib in
                    var c = CapnpCDocument(
                        id: idp, status: d.status,
                        meta: CapnpCDocumentMeta(region: reg, version: d.meta.version),
                        items: ib.baseAddress, items_count: ib.count
                    )
                    return capnp_encode_document(&c, &len)
                }
            }
        }
    }

    private static func encodeDocuments(_ docs: [Document], _ len: inout Int) -> UnsafeMutableRawPointer? {
        var skuHeap: [UnsafeMutablePointer<CChar>] = []
        var idHeap: [UnsafeMutablePointer<CChar>] = []
        var regionHeap: [UnsafeMutablePointer<CChar>] = []
        defer {
            skuHeap.forEach { free($0) }; idHeap.forEach { free($0) }; regionHeap.forEach { free($0) }
        }
        var itemStorage: [CapnpCDocumentItem] = []
        var ranges: [(Int, Int)] = []
        for d in docs {
            idHeap.append(strdup(d.id)!)
            regionHeap.append(strdup(d.meta.region)!)
            let start = itemStorage.count
            for it in d.items {
                let p = strdup(it.sku)!
                skuHeap.append(p)
                itemStorage.append(CapnpCDocumentItem(sku: p, qty: it.qty, price_minor: it.price_minor))
            }
            ranges.append((start, d.items.count))
        }
        return itemStorage.withUnsafeBufferPointer { ib in
            var cdocs: [CapnpCDocument] = []
            for (i, d) in docs.enumerated() {
                let (start, count) = ranges[i]
                let base = count > 0 ? ib.baseAddress!.advanced(by: start) : nil
                cdocs.append(CapnpCDocument(
                    id: idHeap[i], status: d.status,
                    meta: CapnpCDocumentMeta(region: regionHeap[i], version: d.meta.version),
                    items: base, items_count: count
                ))
            }
            return cdocs.withUnsafeBufferPointer { capnp_encode_batch_document($0.baseAddress, $0.count, &len) }
        }
    }

    private static func encodeOneTelemetry(_ t: Telemetry, _ len: inout Int) -> UnsafeMutableRawPointer? {
        var tagHeap = t.tags.map { strdup($0)! }
        defer { tagHeap.forEach { free($0) } }
        var tagPtrs: [UnsafePointer<CChar>?] = tagHeap.map { UnsafePointer($0) }
        return t.values.withUnsafeBufferPointer { vbuf in
            tagPtrs.withUnsafeBufferPointer { tbuf in
                t.source.withCString { src in
                    var c = CapnpCTelemetry(
                        source: src, ts: t.ts,
                        tags: tbuf.baseAddress, tags_count: tbuf.count,
                        values: vbuf.baseAddress, values_count: vbuf.count
                    )
                    return capnp_encode_telemetry(&c, &len)
                }
            }
        }
    }

    private static func encodeTelemetries(_ items: [Telemetry], _ len: inout Int) -> UnsafeMutableRawPointer? {
        var strHeap: [UnsafeMutablePointer<CChar>] = []
        defer { strHeap.forEach { free($0) } }
        var tagArrays: [UnsafeMutablePointer<UnsafePointer<CChar>?>] = []
        defer { tagArrays.forEach { $0.deallocate() } }
        var valueArrays: [UnsafeMutablePointer<Double>] = []
        defer { valueArrays.forEach { $0.deallocate() } }
        var citems = [CapnpCTelemetry](repeating: CapnpCTelemetry(), count: items.count)
        for (i, t) in items.enumerated() {
            let src = strdup(t.source)!
            strHeap.append(src)
            let tarr = UnsafeMutablePointer<UnsafePointer<CChar>?>.allocate(capacity: max(t.tags.count, 1))
            tagArrays.append(tarr)
            for (j, s) in t.tags.enumerated() {
                let p = strdup(s)!
                strHeap.append(p)
                tarr[j] = UnsafePointer(p)
            }
            let varr = UnsafeMutablePointer<Double>.allocate(capacity: max(t.values.count, 1))
            valueArrays.append(varr)
            for (j, v) in t.values.enumerated() { varr[j] = v }
            citems[i] = CapnpCTelemetry(
                source: UnsafePointer(src), ts: t.ts,
                tags: t.tags.isEmpty ? nil : UnsafePointer(tarr), tags_count: t.tags.count,
                values: t.values.isEmpty ? nil : UnsafePointer(varr), values_count: t.values.count
            )
        }
        return citems.withUnsafeBufferPointer { capnp_encode_batch_telemetry($0.baseAddress, $0.count, &len) }
    }

    private static func encodeOneStrings(_ s: Strings, _ len: inout Int) -> UnsafeMutableRawPointer? {
        var heap = s.items.map { strdup($0)! }
        defer { heap.forEach { free($0) } }
        var ptrs: [UnsafePointer<CChar>?] = heap.map { UnsafePointer($0) }
        return ptrs.withUnsafeBufferPointer { buf in
            var c = CapnpCStrings(items: buf.baseAddress, items_count: buf.count)
            return capnp_encode_strings(&c, &len)
        }
    }

    private static func encodeStringsList(_ items: [Strings], _ len: inout Int) -> UnsafeMutableRawPointer? {
        var heap: [UnsafeMutablePointer<CChar>] = []
        defer { heap.forEach { free($0) } }
        var arrays: [UnsafeMutablePointer<UnsafePointer<CChar>?>] = []
        defer { arrays.forEach { $0.deallocate() } }
        var citems = [CapnpCStrings](repeating: CapnpCStrings(), count: items.count)
        for (i, s) in items.enumerated() {
            let arr = UnsafeMutablePointer<UnsafePointer<CChar>?>.allocate(capacity: max(s.items.count, 1))
            arrays.append(arr)
            for (j, str) in s.items.enumerated() {
                let p = strdup(str)!
                heap.append(p)
                arr[j] = UnsafePointer(p)
            }
            citems[i] = CapnpCStrings(items: s.items.isEmpty ? nil : UnsafePointer(arr), items_count: s.items.count)
        }
        return citems.withUnsafeBufferPointer { capnp_encode_batch_strings($0.baseAddress, $0.count, &len) }
    }

    private static func encodeOneEvent(_ e: Event, _ len: inout Int) -> UnsafeMutableRawPointer? {
        var keyHeap = e.attrs.map { strdup($0.key)! }
        var valHeap = e.attrs.map { strdup($0.value)! }
        defer { keyHeap.forEach { free($0) }; valHeap.forEach { free($0) } }
        var attrs = e.attrs.indices.map { CapnpCEventAttr(key: keyHeap[$0], value: valHeap[$0]) }
        return e.event_id.withCString { eid in
            e.event_type.withCString { et in
                e.producer.withCString { prod in
                    attrs.withUnsafeBufferPointer { ab in
                        var c = CapnpCEvent(
                            event_id: eid, event_type: et, occurred_at: e.occurred_at,
                            producer: prod, attrs: ab.baseAddress, attrs_count: ab.count
                        )
                        return capnp_encode_event(&c, &len)
                    }
                }
            }
        }
    }

    private static func encodeEvents(_ items: [Event], _ len: inout Int) -> UnsafeMutableRawPointer? {
        var heap: [UnsafeMutablePointer<CChar>] = []
        defer { heap.forEach { free($0) } }
        var attrStorage: [CapnpCEventAttr] = []
        var ranges: [(Int, Int)] = []
        for e in items {
            let start = attrStorage.count
            for a in e.attrs {
                let k = strdup(a.key)!; let v = strdup(a.value)!
                heap.append(k); heap.append(v)
                attrStorage.append(CapnpCEventAttr(key: k, value: v))
            }
            ranges.append((start, e.attrs.count))
        }
        var idHeap = items.map { strdup($0.event_id)! }
        var typeHeap = items.map { strdup($0.event_type)! }
        var prodHeap = items.map { strdup($0.producer)! }
        heap.append(contentsOf: idHeap); heap.append(contentsOf: typeHeap); heap.append(contentsOf: prodHeap)
        return attrStorage.withUnsafeBufferPointer { ab in
            var citems: [CapnpCEvent] = []
            for (i, e) in items.enumerated() {
                let (start, count) = ranges[i]
                let base = count > 0 ? ab.baseAddress!.advanced(by: start) : nil
                citems.append(CapnpCEvent(
                    event_id: idHeap[i], event_type: typeHeap[i], occurred_at: e.occurred_at,
                    producer: prodHeap[i], attrs: base, attrs_count: count
                ))
            }
            return citems.withUnsafeBufferPointer { capnp_encode_batch_event($0.baseAddress, $0.count, &len) }
        }
    }

    // MARK: domain

    private static func messageFrom(_ c: CapnpCMessage) -> Message {
        Message(
            f_bool: c.f_bool, f_int32: c.f_int32, f_int64: c.f_int64, f_float64: c.f_float64,
            f_string: String(cString: c.f_string!), f_bool_2: c.f_bool_2, f_int32_2: c.f_int32_2,
            f_string_2: String(cString: c.f_string_2!)
        )
    }
    private static func documentFrom(_ c: CapnpCDocument) -> Document {
        var items: [DocumentItem] = []
        if let p = c.items {
            for i in 0..<c.items_count {
                items.append(DocumentItem(sku: String(cString: p[i].sku!), qty: p[i].qty, price_minor: p[i].price_minor))
            }
        }
        return Document(
            id: String(cString: c.id!), status: c.status,
            meta: DocumentMeta(region: String(cString: c.meta.region!), version: c.meta.version),
            items: items
        )
    }
    private static func telemetryFrom(_ c: CapnpCTelemetry) -> Telemetry {
        var tags: [String] = []
        if let p = c.tags { for i in 0..<c.tags_count { tags.append(String(cString: p[i]!)) } }
        var values: [Double] = []
        if let p = c.values { for i in 0..<c.values_count { values.append(p[i]) } }
        return Telemetry(source: String(cString: c.source!), ts: c.ts, tags: tags, values: values)
    }
    private static func stringsFrom(_ c: CapnpCStrings) -> Strings {
        var items: [String] = []
        if let p = c.items { for i in 0..<c.items_count { items.append(String(cString: p[i]!)) } }
        return Strings(items: items)
    }
    private static func eventFrom(_ c: CapnpCEvent) -> Event {
        var attrs: [EventAttr] = []
        if let p = c.attrs {
            for i in 0..<c.attrs_count {
                attrs.append(EventAttr(key: String(cString: p[i].key!), value: String(cString: p[i].value!)))
            }
        }
        return Event(
            event_id: String(cString: c.event_id!), event_type: String(cString: c.event_type!),
            occurred_at: c.occurred_at, producer: String(cString: c.producer!), attrs: attrs
        )
    }
}
