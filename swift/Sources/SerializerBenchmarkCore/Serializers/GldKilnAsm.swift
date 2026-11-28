import Foundation
import KilnAsmC

// MARK: - gld-kiln-asm (Tier 1 zero-cost C ABI via shared libkiln_asm_bench.a)
//
// Covers `suite` (`message`, `document`, `telemetry`, `strings`, `event`, N=1 & N>1)
// and `tensor` (`tensor`, `tensor_view`, `prompt`, `shard`, `request`).
// Full RFC 3629 UTF-8 validation is always active (no KILN_OPT_TRUSTED).

private let kilnDtypeF32: UInt16 = 2
private let kilnDtypeI64: UInt16 = 14

private struct StrSpan {
    var off: Int
    var len: Int
}

public final class GldKilnAsmSerializer: BenchSerializer {
    public let name = "gld-kiln-asm"
    public let version: String
    public let streamMode: StreamMode = .adapted
    public let nativeKind: NativeKind = .schema

    private var arenaBuf = [UInt8](repeating: 0, count: 131_072)
    private var strPool = [UInt8]()
    private var wireCap = 4096
    private var encodeFn: ((Fixture) throws -> Data)?
    private var decodeFn: ((Data) throws -> Any)?

    private var encMsg = [bench_message_t]()
    private var encDoc = [bench_document_t]()
    private var encDocItems = [bench_document_document_item_t]()
    private var encTel = [bench_telemetry_t]()
    private var encStrItems = [kiln_str_t]()
    private var encStrs = [bench_strings_t]()
    private var encEv = [bench_event_t]()
    private var encEvAttrs = [bench_event_event_attr_t]()

    public init() {
        if let p = kiln_asm_version() {
            self.version = String(cString: p)
        } else {
            self.version = "0.2.0"
        }
        self.strPool.reserveCapacity(8192)
    }

    public func supports(testDataName: String) -> Bool {
        switch testDataName {
        case "message", "document", "telemetry", "strings", "event",
             "tensor", "tensor_view", "prompt", "shard", "request":
            return true
        default:
            return false
        }
    }

    private func pushStr(_ s: String) -> StrSpan {
        let off = strPool.count
        strPool.append(contentsOf: s.utf8)
        return StrSpan(off: off, len: strPool.count - off)
    }

    @inline(__always)
    private static func kstr(_ pool: UnsafePointer<UInt8>?, _ sp: StrSpan) -> kiln_str_t {
        if sp.len == 0 {
            return kiln_str_t(ptr: nil, len: 0)
        }
        return kiln_str_t(ptr: pool?.advanced(by: sp.off), len: UInt64(sp.len))
    }

    @inline(__always)
    private static func fromKstr(_ s: kiln_str_t) -> String {
        let n = Int(s.len)
        guard n > 0, let p = s.ptr else { return "" }
        return String(decoding: UnsafeBufferPointer(start: p, count: n), as: UTF8.self)
    }

    private static func errMsg(_ op: String, _ err: kiln_err_t) -> BenchError {
        let name = kiln_asm_err_name(err).map { String(cString: $0) } ?? "UNKNOWN"
        return BenchError.unsupported("gld-kiln-asm \(op): \(name) (\(err.rawValue))")
    }

    private func ensureArena(_ need: Int) {
        if arenaBuf.count < need {
            arenaBuf = [UInt8](repeating: 0, count: need)
        }
    }

    private static func largeOpts() -> kiln_read_opts_t {
        kiln_read_opts_t(max_count: 1 << 28, max_bytes: 1 << 28, max_depth: 0, flags: 0)
    }

    private static func setTensor1D(_ dtype: UInt16, _ d0: UInt64, _ ptr: UnsafePointer<UInt8>?, _ nbytes: Int) -> kiln_tensor_t {
        var t = kiln_tensor_t()
        kiln_tensor_init(&t)
        t.dtype = dtype
        t.rank = 1
        t.shape.0 = d0
        t.data = nbytes > 0 ? ptr : nil
        t.data_len = UInt64(nbytes)
        t.elem_count = d0
        return t
    }

    private static func setTensor2D(_ dtype: UInt16, _ d0: UInt64, _ d1: UInt64, _ ptr: UnsafePointer<UInt8>?, _ nbytes: Int) -> kiln_tensor_t {
        var t = kiln_tensor_t()
        kiln_tensor_init(&t)
        t.dtype = dtype
        t.rank = 2
        t.shape.0 = d0
        t.shape.1 = d1
        t.data = nbytes > 0 ? ptr : nil
        t.data_len = UInt64(nbytes)
        t.elem_count = d0 * d1
        return t
    }

    private static func copyF64(_ raw: UnsafeRawPointer?, _ count: Int) -> [Double] {
        guard count > 0, let raw else { return [] }
        return [Double](unsafeUninitializedCapacity: count) { buf, initCount in
            memcpy(buf.baseAddress!, raw, count * 8)
            initCount = count
        }
    }

    private static func copyI64(_ raw: UnsafeRawPointer?, _ count: Int) -> [Int64] {
        guard count > 0, let raw else { return [] }
        return [Int64](unsafeUninitializedCapacity: count) { buf, initCount in
            memcpy(buf.baseAddress!, raw, count * 8)
            initCount = count
        }
    }

    private static func copyF32(_ raw: UnsafeRawPointer?, _ count: Int) -> [Float] {
        guard count > 0, let raw else { return [] }
        return [Float](unsafeUninitializedCapacity: count) { buf, initCount in
            memcpy(buf.baseAddress!, raw, count * 4)
            initCount = count
        }
    }

    private static func readMsg(_ m: bench_message_t) -> Message {
        Message(
            f_bool: m.f_bool != 0,
            f_int32: m.f_int32,
            f_int64: m.f_int64,
            f_float64: m.f_float64,
            f_string: fromKstr(m.f_string),
            f_bool_2: m.f_bool_2 != 0,
            f_int32_2: m.f_int32_2,
            f_string_2: fromKstr(m.f_string_2)
        )
    }

    private static func readDoc(_ d: bench_document_t) -> Document {
        let n = Int(d.items.count)
        var items = [DocumentItem]()
        items.reserveCapacity(n)
        if n > 0, let p = d.items.items {
            for i in 0..<n {
                let it = p[i]
                items.append(DocumentItem(sku: fromKstr(it.sku), qty: it.qty, price_minor: it.price_minor))
            }
        }
        return Document(
            id: fromKstr(d.id),
            status: d.status,
            meta: DocumentMeta(region: fromKstr(d.meta.region), version: d.meta.version),
            items: items
        )
    }

    private static func readTel(_ t: bench_telemetry_t) -> Telemetry {
        let nt = Int(t.tags.count)
        var tags = [String]()
        tags.reserveCapacity(nt)
        if nt > 0, let p = t.tags.items {
            for i in 0..<nt { tags.append(fromKstr(p[i])) }
        }
        let nv = Int(t.values.count)
        let values = copyF64(t.values.items, nv)
        return Telemetry(source: fromKstr(t.source), ts: t.ts, tags: tags, values: values)
    }

    private static func readStrs(_ s: bench_strings_t) -> Strings {
        let n = Int(s.items.count)
        var items = [String]()
        items.reserveCapacity(n)
        if n > 0, let p = s.items.items {
            for i in 0..<n { items.append(fromKstr(p[i])) }
        }
        return Strings(items: items)
    }

    private static func readEv(_ e: bench_event_t) -> Event {
        let n = Int(e.attrs.count)
        var attrs = [EventAttr]()
        attrs.reserveCapacity(n)
        if n > 0, let p = e.attrs.items {
            for i in 0..<n {
                let a = p[i]
                attrs.append(EventAttr(key: fromKstr(a.key), value: fromKstr(a.value)))
            }
        }
        return Event(
            event_id: fromKstr(e.event_id),
            event_type: fromKstr(e.event_type),
            occurred_at: e.occurred_at,
            producer: fromKstr(e.producer),
            attrs: attrs
        )
    }

    private static func readPromptDir(_ dir: kiln_tensor_dir_t) throws -> Prompt {
        guard dir.count == 3, let p = dir.items else {
            throw BenchError.unsupported("gld-kiln-asm: invalid prompt tensor dir")
        }
        let t0 = p[0], t1 = p[1], t2 = p[2]
        guard t0.dtype == kilnDtypeI64, t0.rank == 2 else {
            throw BenchError.unsupported("gld-kiln-asm: invalid prompt tensor meta")
        }
        let n = Int(t0.elem_count)
        return Prompt(
            batch: Int32(t0.shape.0),
            seq: Int32(t0.shape.1),
            input_ids: copyI64(t0.data, n),
            attention_mask: copyI64(t1.data, n),
            position_ids: copyI64(t2.data, n)
        )
    }

    private func allocOut(_ cap: Int, _ body: (UnsafeMutablePointer<UInt8>, Int, UnsafeMutablePointer<kiln_result_t>) -> kiln_err_t) throws -> Data {
        var out = Data(count: cap)
        var res = kiln_result_t(bytes: 0, hash: 0)
        let err: kiln_err_t = out.withUnsafeMutableBytes { raw in
            body(raw.bindMemory(to: UInt8.self).baseAddress!, cap, &res)
        }
        if err != KILN_OK { throw Self.errMsg("encode", err) }
        out.count = Int(res.bytes)
        return out
    }

    public func prepare(_ fixture: Fixture) throws {
        let batch = fixture.instanceCount > 1
        let n = fixture.instanceCount
        switch fixture.name {
        case "message":
            wireCap = n * 256 + 1024
            ensureArena(n * 128 + 4096)
            encodeFn = { [self] fx in try self.encodeMessages(fx, batch: batch) }
            decodeFn = { [self] data in try self.decodeMessages(data, batch: batch) }
        case "document":
            wireCap = n * 1024 + 4096
            ensureArena(n * 1024 + 8192)
            encodeFn = { [self] fx in try self.encodeDocuments(fx, batch: batch) }
            decodeFn = { [self] data in try self.decodeDocuments(data, batch: batch) }
        case "telemetry":
            wireCap = n * 1024 + 4096
            ensureArena(n * 512 + 8192)
            encodeFn = { [self] fx in try self.encodeTelemetries(fx, batch: batch) }
            decodeFn = { [self] data in try self.decodeTelemetries(data, batch: batch) }
        case "strings":
            wireCap = n * 2048 + 4096
            ensureArena(n * 1024 + 8192)
            encodeFn = { [self] fx in try self.encodeStrings(fx, batch: batch) }
            decodeFn = { [self] data in try self.decodeStrings(data, batch: batch) }
        case "event":
            wireCap = n * 1024 + 4096
            ensureArena(n * 512 + 8192)
            encodeFn = { [self] fx in try self.encodeEvents(fx, batch: batch) }
            decodeFn = { [self] data in try self.decodeEvents(data, batch: batch) }
        case "tensor", "tensor_view":
            let isView = fixture.name == "tensor_view"
            if let tm = fixture.value as? TensorMatrix {
                wireCap = tm.values.count * 4 + 1024
            } else {
                wireCap = 4_195_328
            }
            ensureArena(65_536)
            encodeFn = { [self] fx in try self.encodeTensor(fx) }
            decodeFn = { [self] data in try self.decodeTensor(data, asView: isView) }
        case "prompt":
            if let p = fixture.value as? Prompt {
                wireCap = p.input_ids.count * 24 + 2048
            } else {
                wireCap = 65_536
            }
            ensureArena(65_536)
            encodeFn = { [self] fx in try self.encodePrompt(fx) }
            decodeFn = { [self] data in try self.decodePrompt(data) }
        case "shard":
            if let s = fixture.value as? Shard {
                wireCap = (s.tok_emb.count + s.attn.count + s.ffn_weight.count + s.norm.count) * 4 + 2048
            } else {
                wireCap = 40_000_000
            }
            ensureArena(65_536)
            encodeFn = { [self] fx in try self.encodeShard(fx) }
            decodeFn = { [self] data in try self.decodeShard(data) }
        case "request":
            if let q = fixture.value as? Request {
                wireCap = q.inputs.input_ids.count * 24 + q.model.utf8.count + 2048
            } else {
                wireCap = 65_536
            }
            ensureArena(65_536)
            encodeFn = { [self] fx in try self.encodeRequest(fx) }
            decodeFn = { [self] data in try self.decodeRequest(data) }
        default:
            throw BenchError.unknownType(fixture.name)
        }
        _ = try serializeBytes(fixture)
    }

    public func serializeBytes(_ fixture: Fixture) throws -> Data {
        guard let encodeFn else { throw BenchError.prepareRequired }
        return try encodeFn(fixture)
    }

    public func deserializeBytes(_ data: Data) throws -> Any {
        guard let decodeFn else { throw BenchError.prepareRequired }
        return try decodeFn(data)
    }

    // MARK: - Suite encode/decode

    private func encodeMessages(_ fx: Fixture, batch: Bool) throws -> Data {
        strPool.removeAll(keepingCapacity: true)
        if !batch {
            guard let m = fx.value as? Message else { throw BenchError.unknownType("message") }
            let s1 = pushStr(m.f_string)
            let s2 = pushStr(m.f_string_2)
            let cap = max(wireCap, strPool.count + 256)
            return try strPool.withUnsafeBufferPointer { pool in
                var bm = bench_message_t(
                    f_bool: m.f_bool ? 1 : 0,
                    f_int32: m.f_int32,
                    f_int64: m.f_int64,
                    f_float64: m.f_float64,
                    f_string: Self.kstr(pool.baseAddress, s1),
                    f_bool_2: m.f_bool_2 ? 1 : 0,
                    f_int32_2: m.f_int32_2,
                    f_string_2: Self.kstr(pool.baseAddress, s2)
                )
                return try allocOut(cap) { dst, c, res in
                    kiln_asm_encode_bench_message(&bm, dst, c, nil, res)
                }
            }
        }
        guard let ms = fx.value as? [Message] else { throw BenchError.unknownType("[Message]") }
        var spans = [(StrSpan, StrSpan)]()
        spans.reserveCapacity(ms.count)
        for m in ms {
            spans.append((pushStr(m.f_string), pushStr(m.f_string_2)))
        }
        let cap = max(wireCap, strPool.count + ms.count * 64 + 1024)
        return try strPool.withUnsafeBufferPointer { pool in
            encMsg.removeAll(keepingCapacity: true)
            for (i, m) in ms.enumerated() {
                encMsg.append(bench_message_t(
                    f_bool: m.f_bool ? 1 : 0,
                    f_int32: m.f_int32,
                    f_int64: m.f_int64,
                    f_float64: m.f_float64,
                    f_string: Self.kstr(pool.baseAddress, spans[i].0),
                    f_bool_2: m.f_bool_2 ? 1 : 0,
                    f_int32_2: m.f_int32_2,
                    f_string_2: Self.kstr(pool.baseAddress, spans[i].1)
                ))
            }
            return try encMsg.withUnsafeBufferPointer { buf in
                try allocOut(cap) { dst, c, res in
                    kiln_asm_encode_bench_message_batch(buf.baseAddress, buf.count, dst, c, nil, res)
                }
            }
        }
    }

    private func decodeMessages(_ data: Data, batch: Bool) throws -> Any {
        try data.withUnsafeBytes { raw in
            let src = raw.bindMemory(to: UInt8.self).baseAddress
            return try arenaBuf.withUnsafeMutableBytes { abuf in
                var arena = kiln_arena_t()
                kiln_arena_init(&arena, abuf.bindMemory(to: UInt8.self).baseAddress!, abuf.count)
                var res = kiln_result_t()
                if !batch {
                    var m = bench_message_t()
                    let err = kiln_asm_decode_bench_message(src, data.count, &m, &arena, nil, &res)
                    if err != KILN_OK { throw Self.errMsg("decode message", err) }
                    return Self.readMsg(m)
                }
                var ptr: UnsafeMutablePointer<bench_message_t>?
                var cnt: Int = 0
                let err = kiln_asm_decode_bench_message_batch(src, data.count, &ptr, &cnt, &arena, nil, &res)
                if err != KILN_OK { throw Self.errMsg("decode message batch", err) }
                var out = [Message]()
                out.reserveCapacity(cnt)
                if cnt > 0, let ptr {
                    for i in 0..<cnt { out.append(Self.readMsg(ptr[i])) }
                }
                return out
            }
        }
    }

    private func encodeDocuments(_ fx: Fixture, batch: Bool) throws -> Data {
        let docs: [Document]
        if batch {
            guard let ds = fx.value as? [Document] else { throw BenchError.unknownType("[Document]") }
            docs = ds
        } else {
            guard let d = fx.value as? Document else { throw BenchError.unknownType("Document") }
            docs = [d]
        }
        strPool.removeAll(keepingCapacity: true)
        var docSpans = [(StrSpan, StrSpan, Int)]()
        docSpans.reserveCapacity(docs.count)
        var itemSpans = [(StrSpan, Int32, Int64)]()
        for d in docs {
            let sid = pushStr(d.id)
            let sreg = pushStr(d.meta.region)
            for it in d.items {
                itemSpans.append((pushStr(it.sku), it.qty, it.price_minor))
            }
            docSpans.append((sid, sreg, d.items.count))
        }
        let cap = max(wireCap, strPool.count + docs.count * 64 + itemSpans.count * 32 + 1024)
        return try strPool.withUnsafeBufferPointer { pool in
            encDocItems.removeAll(keepingCapacity: true)
            for sp in itemSpans {
                encDocItems.append(bench_document_document_item_t(
                    sku: Self.kstr(pool.baseAddress, sp.0), qty: sp.1, price_minor: sp.2
                ))
            }
            return try encDocItems.withUnsafeMutableBufferPointer { ibuf in
                encDoc.removeAll(keepingCapacity: true)
                var off = 0
                for (i, d) in docs.enumerated() {
                    let cnt = docSpans[i].2
                    let ptr = cnt > 0 ? ibuf.baseAddress?.advanced(by: off) : nil
                    off += cnt
                    encDoc.append(bench_document_t(
                        id: Self.kstr(pool.baseAddress, docSpans[i].0),
                        status: d.status,
                        meta: bench_document_document_meta_t(
                            region: Self.kstr(pool.baseAddress, docSpans[i].1),
                            version: d.meta.version
                        ),
                        items: bench_document_list_document_item_t(items: ptr, count: UInt64(cnt))
                    ))
                }
                return try encDoc.withUnsafeBufferPointer { dbuf in
                    try allocOut(cap) { dst, c, res in
                        if batch {
                            return kiln_asm_encode_bench_document_batch(dbuf.baseAddress, dbuf.count, dst, c, nil, res)
                        }
                        return kiln_asm_encode_bench_document(dbuf.baseAddress, dst, c, nil, res)
                    }
                }
            }
        }
    }

    private func decodeDocuments(_ data: Data, batch: Bool) throws -> Any {
        try data.withUnsafeBytes { raw in
            let src = raw.bindMemory(to: UInt8.self).baseAddress
            return try arenaBuf.withUnsafeMutableBytes { abuf in
                var arena = kiln_arena_t()
                kiln_arena_init(&arena, abuf.bindMemory(to: UInt8.self).baseAddress!, abuf.count)
                var res = kiln_result_t()
                if !batch {
                    var d = bench_document_t()
                    let err = kiln_asm_decode_bench_document(src, data.count, &d, &arena, nil, &res)
                    if err != KILN_OK { throw Self.errMsg("decode document", err) }
                    return Self.readDoc(d)
                }
                var ptr: UnsafeMutablePointer<bench_document_t>?
                var cnt: Int = 0
                let err = kiln_asm_decode_bench_document_batch(src, data.count, &ptr, &cnt, &arena, nil, &res)
                if err != KILN_OK { throw Self.errMsg("decode document batch", err) }
                var out = [Document]()
                out.reserveCapacity(cnt)
                if cnt > 0, let ptr {
                    for i in 0..<cnt { out.append(Self.readDoc(ptr[i])) }
                }
                return out
            }
        }
    }

    private func encodeTelemetries(_ fx: Fixture, batch: Bool) throws -> Data {
        let tels: [Telemetry]
        if batch {
            guard let ts = fx.value as? [Telemetry] else { throw BenchError.unknownType("[Telemetry]") }
            tels = ts
        } else {
            guard let t = fx.value as? Telemetry else { throw BenchError.unknownType("Telemetry") }
            tels = [t]
        }
        strPool.removeAll(keepingCapacity: true)
        var srcSpans = [StrSpan]()
        srcSpans.reserveCapacity(tels.count)
        var tagSpans = [StrSpan]()
        var flatVals = [Double]()
        for t in tels {
            srcSpans.append(pushStr(t.source))
            for tag in t.tags { tagSpans.append(pushStr(tag)) }
            flatVals.append(contentsOf: t.values)
        }
        let cap = max(wireCap, strPool.count + flatVals.count * 8 + tels.count * 64 + tagSpans.count * 8 + 1024)
        return try strPool.withUnsafeBufferPointer { pool in
            encStrItems.removeAll(keepingCapacity: true)
            for sp in tagSpans { encStrItems.append(Self.kstr(pool.baseAddress, sp)) }
            return try encStrItems.withUnsafeMutableBufferPointer { tbuf in
                try flatVals.withUnsafeMutableBufferPointer { vbuf in
                    encTel.removeAll(keepingCapacity: true)
                    var toff = 0
                    var voff = 0
                    for (i, t) in tels.enumerated() {
                        let nt = t.tags.count
                        let nv = t.values.count
                        let tp = nt > 0 ? tbuf.baseAddress?.advanced(by: toff) : nil
                        let vp = nv > 0 ? vbuf.baseAddress?.advanced(by: voff) : nil
                        toff += nt
                        voff += nv
                        encTel.append(bench_telemetry_t(
                            source: Self.kstr(pool.baseAddress, srcSpans[i]),
                            ts: t.ts,
                            tags: bench_telemetry_list_str_t(items: tp, count: UInt64(nt)),
                            values: bench_telemetry_list_f64_t(items: vp, count: UInt64(nv))
                        ))
                    }
                    return try encTel.withUnsafeBufferPointer { bbuf in
                        try allocOut(cap) { dst, c, res in
                            if batch {
                                return kiln_asm_encode_bench_telemetry_batch(bbuf.baseAddress, bbuf.count, dst, c, nil, res)
                            }
                            return kiln_asm_encode_bench_telemetry(bbuf.baseAddress, dst, c, nil, res)
                        }
                    }
                }
            }
        }
    }

    private func decodeTelemetries(_ data: Data, batch: Bool) throws -> Any {
        try data.withUnsafeBytes { raw in
            let src = raw.bindMemory(to: UInt8.self).baseAddress
            return try arenaBuf.withUnsafeMutableBytes { abuf in
                var arena = kiln_arena_t()
                kiln_arena_init(&arena, abuf.bindMemory(to: UInt8.self).baseAddress!, abuf.count)
                var res = kiln_result_t()
                if !batch {
                    var t = bench_telemetry_t()
                    let err = kiln_asm_decode_bench_telemetry(src, data.count, &t, &arena, nil, &res)
                    if err != KILN_OK { throw Self.errMsg("decode telemetry", err) }
                    return Self.readTel(t)
                }
                var ptr: UnsafeMutablePointer<bench_telemetry_t>?
                var cnt: Int = 0
                let err = kiln_asm_decode_bench_telemetry_batch(src, data.count, &ptr, &cnt, &arena, nil, &res)
                if err != KILN_OK { throw Self.errMsg("decode telemetry batch", err) }
                var out = [Telemetry]()
                out.reserveCapacity(cnt)
                if cnt > 0, let ptr {
                    for i in 0..<cnt { out.append(Self.readTel(ptr[i])) }
                }
                return out
            }
        }
    }

    private func encodeStrings(_ fx: Fixture, batch: Bool) throws -> Data {
        let list: [Strings]
        if batch {
            guard let ss = fx.value as? [Strings] else { throw BenchError.unknownType("[Strings]") }
            list = ss
        } else {
            guard let s = fx.value as? Strings else { throw BenchError.unknownType("Strings") }
            list = [s]
        }
        strPool.removeAll(keepingCapacity: true)
        var itemSpans = [StrSpan]()
        for s in list {
            for it in s.items { itemSpans.append(pushStr(it)) }
        }
        let cap = max(wireCap, strPool.count + itemSpans.count * 8 + list.count * 16 + 1024)
        return try strPool.withUnsafeBufferPointer { pool in
            encStrItems.removeAll(keepingCapacity: true)
            for sp in itemSpans { encStrItems.append(Self.kstr(pool.baseAddress, sp)) }
            return try encStrItems.withUnsafeMutableBufferPointer { ibuf in
                encStrs.removeAll(keepingCapacity: true)
                var off = 0
                for s in list {
                    let cnt = s.items.count
                    let p = cnt > 0 ? ibuf.baseAddress?.advanced(by: off) : nil
                    off += cnt
                    encStrs.append(bench_strings_t(items: bench_strings_list_str_t(items: p, count: UInt64(cnt))))
                }
                return try encStrs.withUnsafeBufferPointer { sbuf in
                    try allocOut(cap) { dst, c, res in
                        if batch {
                            return kiln_asm_encode_bench_strings_batch(sbuf.baseAddress, sbuf.count, dst, c, nil, res)
                        }
                        return kiln_asm_encode_bench_strings(sbuf.baseAddress, dst, c, nil, res)
                    }
                }
            }
        }
    }

    private func decodeStrings(_ data: Data, batch: Bool) throws -> Any {
        try data.withUnsafeBytes { raw in
            let src = raw.bindMemory(to: UInt8.self).baseAddress
            return try arenaBuf.withUnsafeMutableBytes { abuf in
                var arena = kiln_arena_t()
                kiln_arena_init(&arena, abuf.bindMemory(to: UInt8.self).baseAddress!, abuf.count)
                var res = kiln_result_t()
                if !batch {
                    var s = bench_strings_t()
                    let err = kiln_asm_decode_bench_strings(src, data.count, &s, &arena, nil, &res)
                    if err != KILN_OK { throw Self.errMsg("decode strings", err) }
                    return Self.readStrs(s)
                }
                var ptr: UnsafeMutablePointer<bench_strings_t>?
                var cnt: Int = 0
                let err = kiln_asm_decode_bench_strings_batch(src, data.count, &ptr, &cnt, &arena, nil, &res)
                if err != KILN_OK { throw Self.errMsg("decode strings batch", err) }
                var out = [Strings]()
                out.reserveCapacity(cnt)
                if cnt > 0, let ptr {
                    for i in 0..<cnt { out.append(Self.readStrs(ptr[i])) }
                }
                return out
            }
        }
    }

    private func encodeEvents(_ fx: Fixture, batch: Bool) throws -> Data {
        let evs: [Event]
        if batch {
            guard let es = fx.value as? [Event] else { throw BenchError.unknownType("[Event]") }
            evs = es
        } else {
            guard let e = fx.value as? Event else { throw BenchError.unknownType("Event") }
            evs = [e]
        }
        strPool.removeAll(keepingCapacity: true)
        var evSpans = [(StrSpan, StrSpan, StrSpan, Int)]()
        evSpans.reserveCapacity(evs.count)
        var attrSpans = [(StrSpan, StrSpan)]()
        for e in evs {
            let s1 = pushStr(e.event_id)
            let s2 = pushStr(e.event_type)
            let s3 = pushStr(e.producer)
            for a in e.attrs { attrSpans.append((pushStr(a.key), pushStr(a.value))) }
            evSpans.append((s1, s2, s3, e.attrs.count))
        }
        let cap = max(wireCap, strPool.count + evs.count * 64 + attrSpans.count * 16 + 1024)
        return try strPool.withUnsafeBufferPointer { pool in
            encEvAttrs.removeAll(keepingCapacity: true)
            for sp in attrSpans {
                encEvAttrs.append(bench_event_event_attr_t(
                    key: Self.kstr(pool.baseAddress, sp.0),
                    value: Self.kstr(pool.baseAddress, sp.1)
                ))
            }
            return try encEvAttrs.withUnsafeMutableBufferPointer { abuf in
                encEv.removeAll(keepingCapacity: true)
                var off = 0
                for (i, e) in evs.enumerated() {
                    let cnt = evSpans[i].3
                    let p = cnt > 0 ? abuf.baseAddress?.advanced(by: off) : nil
                    off += cnt
                    encEv.append(bench_event_t(
                        event_id: Self.kstr(pool.baseAddress, evSpans[i].0),
                        event_type: Self.kstr(pool.baseAddress, evSpans[i].1),
                        occurred_at: e.occurred_at,
                        producer: Self.kstr(pool.baseAddress, evSpans[i].2),
                        attrs: bench_event_list_event_attr_t(items: p, count: UInt64(cnt))
                    ))
                }
                return try encEv.withUnsafeBufferPointer { ebuf in
                    try allocOut(cap) { dst, c, res in
                        if batch {
                            return kiln_asm_encode_bench_event_batch(ebuf.baseAddress, ebuf.count, dst, c, nil, res)
                        }
                        return kiln_asm_encode_bench_event(ebuf.baseAddress, dst, c, nil, res)
                    }
                }
            }
        }
    }

    private func decodeEvents(_ data: Data, batch: Bool) throws -> Any {
        try data.withUnsafeBytes { raw in
            let src = raw.bindMemory(to: UInt8.self).baseAddress
            return try arenaBuf.withUnsafeMutableBytes { abuf in
                var arena = kiln_arena_t()
                kiln_arena_init(&arena, abuf.bindMemory(to: UInt8.self).baseAddress!, abuf.count)
                var res = kiln_result_t()
                if !batch {
                    var e = bench_event_t()
                    let err = kiln_asm_decode_bench_event(src, data.count, &e, &arena, nil, &res)
                    if err != KILN_OK { throw Self.errMsg("decode event", err) }
                    return Self.readEv(e)
                }
                var ptr: UnsafeMutablePointer<bench_event_t>?
                var cnt: Int = 0
                let err = kiln_asm_decode_bench_event_batch(src, data.count, &ptr, &cnt, &arena, nil, &res)
                if err != KILN_OK { throw Self.errMsg("decode event batch", err) }
                var out = [Event]()
                out.reserveCapacity(cnt)
                if cnt > 0, let ptr {
                    for i in 0..<cnt { out.append(Self.readEv(ptr[i])) }
                }
                return out
            }
        }
    }

    // MARK: - Tensor set encode/decode (KLNT v2)

    private func encodeTensor(_ fx: Fixture) throws -> Data {
        guard let tm = fx.value as? TensorMatrix else { throw BenchError.unknownType("TensorMatrix") }
        let nbytes = tm.values.count * 4
        let cap = max(wireCap, nbytes + 1024)
        var opts = Self.largeOpts()
        return try tm.values.withUnsafeBytes { vraw in
            var kt = Self.setTensor2D(kilnDtypeF32, UInt64(tm.rows), UInt64(tm.cols), vraw.bindMemory(to: UInt8.self).baseAddress, nbytes)
            return try withUnsafeMutablePointer(to: &kt) { kp in
                var dir = kiln_tensor_dir_t(items: kp, count: 1, block_length: 0, flags: 2, version: 2)
                return try allocOut(cap) { dst, c, res in
                    kiln_asm_encode_tensors(&dir, dst, c, &opts, res)
                }
            }
        }
    }

    private func decodeTensor(_ data: Data, asView: Bool) throws -> Any {
        var opts = Self.largeOpts()
        return try data.withUnsafeBytes { raw in
            let base = raw.bindMemory(to: UInt8.self).baseAddress
            return try arenaBuf.withUnsafeMutableBytes { abuf in
                var arena = kiln_arena_t()
                kiln_arena_init(&arena, abuf.bindMemory(to: UInt8.self).baseAddress!, abuf.count)
                var dir = kiln_tensor_dir_t()
                var res = kiln_result_t()
                let err = kiln_asm_decode_tensors(base, data.count, &dir, &arena, &opts, &res)
                if err != KILN_OK { throw Self.errMsg("decode tensor", err) }
                guard dir.count == 1, let tp = dir.items else {
                    throw BenchError.unsupported("gld-kiln-asm: invalid tensor dir")
                }
                let kt = tp[0]
                let rows = Int32(kt.shape.0)
                let cols = Int32(kt.shape.1)
                let nbytes = Int(kt.data_len)
                if asView {
                    let offset: Int
                    if nbytes > 0 {
                        guard let base, let p = kt.data else {
                            throw BenchError.unsupported("gld-kiln-asm: null tensor_view data")
                        }
                        let b0 = Int(bitPattern: base)
                        let p0 = Int(bitPattern: p)
                        guard p0 >= b0 && p0 - b0 + nbytes <= data.count else {
                            throw BenchError.unsupported("gld-kiln-asm: tensor_view out of range")
                        }
                        offset = p0 - b0
                    } else {
                        offset = 0
                    }
                    return TensorView(rows: rows, cols: cols, storage: data, offset: offset, count: nbytes / 4)
                }
                return TensorMatrix(rows: rows, cols: cols, values: Self.copyF32(kt.data, nbytes / 4))
            }
        }
    }

    private func encodePrompt(_ fx: Fixture) throws -> Data {
        guard let p = fx.value as? Prompt else { throw BenchError.unknownType("Prompt") }
        let nbytes = p.input_ids.count * 8
        let cap = max(wireCap, nbytes * 3 + 2048)
        var opts = Self.largeOpts()
        return try p.input_ids.withUnsafeBytes { r0 in
            try p.attention_mask.withUnsafeBytes { r1 in
                try p.position_ids.withUnsafeBytes { r2 in
                    var ts = [
                        Self.setTensor2D(kilnDtypeI64, UInt64(p.batch), UInt64(p.seq), r0.bindMemory(to: UInt8.self).baseAddress, nbytes),
                        Self.setTensor2D(kilnDtypeI64, UInt64(p.batch), UInt64(p.seq), r1.bindMemory(to: UInt8.self).baseAddress, nbytes),
                        Self.setTensor2D(kilnDtypeI64, UInt64(p.batch), UInt64(p.seq), r2.bindMemory(to: UInt8.self).baseAddress, nbytes),
                    ]
                    return try ts.withUnsafeMutableBufferPointer { tp in
                        var dir = kiln_tensor_dir_t(items: tp.baseAddress, count: 3, block_length: 0, flags: 2, version: 2)
                        return try allocOut(cap) { dst, c, res in
                            kiln_asm_encode_tensors(&dir, dst, c, &opts, res)
                        }
                    }
                }
            }
        }
    }

    private func decodePrompt(_ data: Data) throws -> Any {
        var opts = Self.largeOpts()
        return try data.withUnsafeBytes { raw in
            let src = raw.bindMemory(to: UInt8.self).baseAddress
            return try arenaBuf.withUnsafeMutableBytes { abuf in
                var arena = kiln_arena_t()
                kiln_arena_init(&arena, abuf.bindMemory(to: UInt8.self).baseAddress!, abuf.count)
                var dir = kiln_tensor_dir_t()
                var res = kiln_result_t()
                let err = kiln_asm_decode_tensors(src, data.count, &dir, &arena, &opts, &res)
                if err != KILN_OK { throw Self.errMsg("decode prompt", err) }
                return try Self.readPromptDir(dir)
            }
        }
    }

    private func encodeShard(_ fx: Fixture) throws -> Data {
        guard let s = fx.value as? Shard else { throw BenchError.unknownType("Shard") }
        let cap = max(wireCap, (s.tok_emb.count + s.attn.count + s.ffn_weight.count + s.norm.count) * 4 + 2048)
        var opts = Self.largeOpts()
        return try s.tok_emb.withUnsafeBytes { r0 in
            try s.attn.withUnsafeBytes { r1 in
                try s.ffn_weight.withUnsafeBytes { r2 in
                    try s.norm.withUnsafeBytes { r3 in
                        var ts = [
                            Self.setTensor2D(kilnDtypeF32, UInt64(s.vocab), UInt64(s.hidden), r0.bindMemory(to: UInt8.self).baseAddress, s.tok_emb.count * 4),
                            Self.setTensor2D(kilnDtypeF32, UInt64(s.hidden), UInt64(s.hidden), r1.bindMemory(to: UInt8.self).baseAddress, s.attn.count * 4),
                            Self.setTensor2D(kilnDtypeF32, UInt64(s.ffn), UInt64(s.hidden), r2.bindMemory(to: UInt8.self).baseAddress, s.ffn_weight.count * 4),
                            Self.setTensor1D(kilnDtypeF32, UInt64(s.hidden), r3.bindMemory(to: UInt8.self).baseAddress, s.norm.count * 4),
                        ]
                        return try ts.withUnsafeMutableBufferPointer { tp in
                            var dir = kiln_tensor_dir_t(items: tp.baseAddress, count: 4, block_length: 0, flags: 2, version: 2)
                            return try allocOut(cap) { dst, c, res in
                                kiln_asm_encode_tensors(&dir, dst, c, &opts, res)
                            }
                        }
                    }
                }
            }
        }
    }

    private func decodeShard(_ data: Data) throws -> Any {
        var opts = Self.largeOpts()
        return try data.withUnsafeBytes { raw in
            let src = raw.bindMemory(to: UInt8.self).baseAddress
            return try arenaBuf.withUnsafeMutableBytes { abuf in
                var arena = kiln_arena_t()
                kiln_arena_init(&arena, abuf.bindMemory(to: UInt8.self).baseAddress!, abuf.count)
                var dir = kiln_tensor_dir_t()
                var res = kiln_result_t()
                let err = kiln_asm_decode_tensors(src, data.count, &dir, &arena, &opts, &res)
                if err != KILN_OK { throw Self.errMsg("decode shard", err) }
                guard dir.count == 4, let tp = dir.items else {
                    throw BenchError.unsupported("gld-kiln-asm: invalid shard dir")
                }
                let t0 = tp[0], t1 = tp[1], t2 = tp[2], t3 = tp[3]
                return Shard(
                    vocab: Int32(t0.shape.0),
                    hidden: Int32(t0.shape.1),
                    ffn: Int32(t2.shape.0),
                    tok_emb: Self.copyF32(t0.data, Int(t0.data_len) / 4),
                    attn: Self.copyF32(t1.data, Int(t1.data_len) / 4),
                    ffn_weight: Self.copyF32(t2.data, Int(t2.data_len) / 4),
                    norm: Self.copyF32(t3.data, Int(t3.data_len) / 4)
                )
            }
        }
    }

    private func encodeRequest(_ fx: Fixture) throws -> Data {
        guard let q = fx.value as? Request else { throw BenchError.unknownType("Request") }
        let p = q.inputs
        let nbytes = p.input_ids.count * 8
        strPool.removeAll(keepingCapacity: true)
        let sm = pushStr(q.model)
        let cap = max(wireCap, nbytes * 3 + strPool.count + 2048)
        var opts = Self.largeOpts()
        return try strPool.withUnsafeBufferPointer { pool in
            try p.input_ids.withUnsafeBytes { r0 in
                try p.attention_mask.withUnsafeBytes { r1 in
                    try p.position_ids.withUnsafeBytes { r2 in
                        var ts = [
                            Self.setTensor2D(kilnDtypeI64, UInt64(p.batch), UInt64(p.seq), r0.bindMemory(to: UInt8.self).baseAddress, nbytes),
                            Self.setTensor2D(kilnDtypeI64, UInt64(p.batch), UInt64(p.seq), r1.bindMemory(to: UInt8.self).baseAddress, nbytes),
                            Self.setTensor2D(kilnDtypeI64, UInt64(p.batch), UInt64(p.seq), r2.bindMemory(to: UInt8.self).baseAddress, nbytes),
                        ]
                        return try ts.withUnsafeMutableBufferPointer { tp in
                            var rq = bench_request_t(
                                request_id: q.request_id,
                                model: Self.kstr(pool.baseAddress, sm),
                                temperature: q.temperature,
                                inputs: kiln_tensor_dir_t(items: tp.baseAddress, count: 3, block_length: 0, flags: 2, version: 2)
                            )
                            return try allocOut(cap) { dst, c, res in
                                kiln_asm_encode_bench_request(&rq, dst, c, &opts, res)
                            }
                        }
                    }
                }
            }
        }
    }

    private func decodeRequest(_ data: Data) throws -> Any {
        var opts = Self.largeOpts()
        return try data.withUnsafeBytes { raw in
            let src = raw.bindMemory(to: UInt8.self).baseAddress
            return try arenaBuf.withUnsafeMutableBytes { abuf in
                var arena = kiln_arena_t()
                kiln_arena_init(&arena, abuf.bindMemory(to: UInt8.self).baseAddress!, abuf.count)
                var rq = bench_request_t()
                var res = kiln_result_t()
                let err = kiln_asm_decode_bench_request(src, data.count, &rq, &arena, &opts, &res)
                if err != KILN_OK { throw Self.errMsg("decode request", err) }
                return Request(
                    request_id: rq.request_id,
                    model: Self.fromKstr(rq.model),
                    temperature: rq.temperature,
                    inputs: try Self.readPromptDir(rq.inputs)
                )
            }
        }
    }
}
