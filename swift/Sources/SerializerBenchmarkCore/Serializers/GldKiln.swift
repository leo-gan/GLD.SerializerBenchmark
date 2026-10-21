import Foundation
import Kiln

// MARK: - gld-kiln (leo-gan/gld-kiln-swift)
// prepare builds the positional schema once. A batch is one list of the struct.
// Timed encode builds a Value and calls Writer.encode, which clears and reuses
// its buffer. Timed decode is decode, then field reads back into suite structs.
// Field order is the wire order. Names are not written.
// tensor_view decode keeps a span of the encoded f32 bytes and does not copy them.
// https://github.com/leo-gan/gld-kiln-swift
// https://leo-gan.github.io/gld-kiln/spec/

public final class GldKilnSerializer: BenchSerializer {
    public let name = "gld-kiln"
    public let version = kilnVersion
    public let streamMode: StreamMode = .adapted
    public let nativeKind: NativeKind = .schema

    private let writer = Writer(capacity: 256)
    private let buffers = ReusedByteScratch()
    /// Bound in prepare — timed path has no multi-way fixture switch (issue #59).
    private var encodeFn: ((Fixture) throws -> Data)?
    private var decodeFn: ((Data) throws -> Any)?

    public init() {}

    public func supports(testDataName: String) -> Bool {
        switch testDataName {
        case "message", "document", "telemetry", "strings", "event",
             "tensor", "tensor_view", "prompt", "shard", "request":
            return true
        default:
            return false
        }
    }

    public func prepare(_ fixture: Fixture) throws {
        let batch = fixture.instanceCount > 1
        let schema = try GldKilnBridge.schema(named: fixture.name, batch: batch)
        let writer = self.writer
        let buffers = self.buffers
        switch fixture.name {
        case "message":
            encodeFn = GldKilnBridge.bindEncode(
                typeName: fixture.name, batch: batch, schema: schema,
                writer: writer, buffers: buffers, write: GldKilnBridge.messageValue
            )
            decodeFn = GldKilnBridge.bindDecode(
                batch: batch, schema: schema, buffers: buffers, read: GldKilnBridge.message
            )
        case "document":
            encodeFn = GldKilnBridge.bindEncode(
                typeName: fixture.name, batch: batch, schema: schema,
                writer: writer, buffers: buffers, write: GldKilnBridge.documentValue
            )
            decodeFn = GldKilnBridge.bindDecode(
                batch: batch, schema: schema, buffers: buffers, read: GldKilnBridge.document
            )
        case "telemetry":
            encodeFn = GldKilnBridge.bindEncode(
                typeName: fixture.name, batch: batch, schema: schema,
                writer: writer, buffers: buffers, write: GldKilnBridge.telemetryValue
            )
            decodeFn = GldKilnBridge.bindDecode(
                batch: batch, schema: schema, buffers: buffers, read: GldKilnBridge.telemetry
            )
        case "strings":
            encodeFn = GldKilnBridge.bindEncode(
                typeName: fixture.name, batch: batch, schema: schema,
                writer: writer, buffers: buffers, write: GldKilnBridge.stringsValue
            )
            decodeFn = GldKilnBridge.bindDecode(
                batch: batch, schema: schema, buffers: buffers, read: GldKilnBridge.strings
            )
        case "event":
            encodeFn = GldKilnBridge.bindEncode(
                typeName: fixture.name, batch: batch, schema: schema,
                writer: writer, buffers: buffers, write: GldKilnBridge.eventValue
            )
            decodeFn = GldKilnBridge.bindDecode(
                batch: batch, schema: schema, buffers: buffers, read: GldKilnBridge.event
            )
        case "tensor":
            encodeFn = GldKilnBridge.bindEncode(
                typeName: fixture.name, batch: batch, schema: schema,
                writer: writer, buffers: buffers, write: GldKilnBridge.tensorValue
            )
            decodeFn = GldKilnBridge.bindDecode(
                batch: batch, schema: schema, buffers: buffers, read: GldKilnBridge.tensor
            )
        case "tensor_view":
            encodeFn = GldKilnBridge.bindEncode(
                typeName: fixture.name, batch: batch, schema: schema,
                writer: writer, buffers: buffers, write: GldKilnBridge.tensorValue
            )
            decodeFn = { data in try GldKilnBridge.tensorView(data) }
        case "prompt":
            encodeFn = GldKilnBridge.bindEncode(
                typeName: fixture.name, batch: batch, schema: schema,
                writer: writer, buffers: buffers, write: GldKilnBridge.promptValue
            )
            decodeFn = GldKilnBridge.bindDecode(
                batch: batch, schema: schema, buffers: buffers, read: GldKilnBridge.prompt
            )
        case "shard":
            encodeFn = GldKilnBridge.bindEncode(
                typeName: fixture.name, batch: batch, schema: schema,
                writer: writer, buffers: buffers, write: GldKilnBridge.shardValue
            )
            decodeFn = GldKilnBridge.bindDecode(
                batch: batch, schema: schema, buffers: buffers, read: GldKilnBridge.shard
            )
        case "request":
            encodeFn = GldKilnBridge.bindEncode(
                typeName: fixture.name, batch: batch, schema: schema,
                writer: writer, buffers: buffers, write: GldKilnBridge.requestValue
            )
            decodeFn = GldKilnBridge.bindDecode(
                batch: batch, schema: schema, buffers: buffers, read: GldKilnBridge.request
            )
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
}

enum GldKilnBridge {
    private static let messageSchema = Schema.structure([
        ("f_bool", .bool),
        ("f_int32", .i32),
        ("f_int64", .i64),
        ("f_float64", .f64),
        ("f_string", .str),
        ("f_bool_2", .bool),
        ("f_int32_2", .i32),
        ("f_string_2", .str),
    ])
    private static let documentSchema = Schema.structure([
        ("id", .str),
        ("status", .i32),
        ("meta", Schema.structure([
            ("region", .str),
            ("version", .i32),
        ])),
        ("items", .list(Schema.structure([
            ("sku", .str),
            ("qty", .i32),
            ("price_minor", .i64),
        ]))),
    ])
    private static let telemetrySchema = Schema.structure([
        ("source", .str),
        ("ts", .i64),
        ("tags", .list(.str)),
        ("values", .list(.f64)),
    ])
    private static let stringsSchema = Schema.structure([
        ("items", .list(.str)),
    ])
    private static let eventSchema = Schema.structure([
        ("event_id", .str),
        ("event_type", .str),
        ("occurred_at", .i64),
        ("producer", .str),
        ("attrs", .list(Schema.structure([
            ("key", .str),
            ("value", .str),
        ]))),
    ])
    private static let tensorSchema = Schema.structure([
        ("rows", .i32),
        ("cols", .i32),
        ("values", .list(.f32)),
    ])
    private static let promptSchema = Schema.structure([
        ("batch", .i32),
        ("seq", .i32),
        ("input_ids", .list(.i64)),
        ("attention_mask", .list(.i64)),
        ("position_ids", .list(.i64)),
    ])
    private static let shardSchema = Schema.structure([
        ("vocab", .i32),
        ("hidden", .i32),
        ("ffn", .i32),
        ("tok_emb", .list(.f32)),
        ("attn", .list(.f32)),
        ("ffn_weight", .list(.f32)),
        ("norm", .list(.f32)),
    ])
    private static let requestSchema = Schema.structure([
        ("request_id", .i64),
        ("model", .str),
        ("temperature", .f32),
        ("inputs", promptSchema),
    ])

    static func schema(named name: String, batch: Bool) throws -> Schema {
        let base: Schema
        switch name {
        case "message": base = messageSchema
        case "document": base = documentSchema
        case "telemetry": base = telemetrySchema
        case "strings": base = stringsSchema
        case "event": base = eventSchema
        case "tensor", "tensor_view": base = tensorSchema
        case "prompt": base = promptSchema
        case "shard": base = shardSchema
        case "request": base = requestSchema
        default: throw BenchError.unknownType(name)
        }
        return batch ? .list(base) : base
    }

    static func bindEncode<T>(
        typeName: String,
        batch: Bool,
        schema: Schema,
        writer: Writer,
        buffers: ReusedByteScratch,
        write: @escaping (T) -> Value
    ) -> (Fixture) throws -> Data {
        if batch {
            return { fx in
                guard let rows = fx.value as? [T] else {
                    throw BenchError.unsupported("gld-kiln batch \(typeName)")
                }
                let slice = try writer.encode(schema, .list(rows.map(write)))
                return buffers.store(slice)
            }
        }
        return { fx in
            guard let row = fx.value as? T else {
                throw BenchError.unsupported("gld-kiln \(typeName)")
            }
            let slice = try writer.encode(schema, write(row))
            return buffers.store(slice)
        }
    }

    static func bindDecode<T>(
        batch: Bool,
        schema: Schema,
        buffers: ReusedByteScratch,
        read: @escaping (Value) throws -> T
    ) -> (Data) throws -> Any {
        if batch {
            return { data in
                let value = try decode(schema, buffers.copyIn(data))
                let items = try list(value)
                var rows: [T] = []
                rows.reserveCapacity(items.count)
                for item in items {
                    rows.append(try read(item))
                }
                return rows
            }
        }
        return { data in
            try read(try decode(schema, buffers.copyIn(data)))
        }
    }

    static func messageValue(_ m: Message) -> Value {
        .object([
            "f_bool": .bool(m.f_bool),
            "f_int32": .int(Int64(m.f_int32)),
            "f_int64": .int(m.f_int64),
            "f_float64": .f64(m.f_float64),
            "f_string": .string(m.f_string),
            "f_bool_2": .bool(m.f_bool_2),
            "f_int32_2": .int(Int64(m.f_int32_2)),
            "f_string_2": .string(m.f_string_2),
        ])
    }

    static func message(_ value: Value) throws -> Message {
        let f = try object(value)
        return Message(
            f_bool: try bool(f["f_bool"]),
            f_int32: try i32(f["f_int32"]),
            f_int64: try i64(f["f_int64"]),
            f_float64: try f64(f["f_float64"]),
            f_string: try str(f["f_string"]),
            f_bool_2: try bool(f["f_bool_2"]),
            f_int32_2: try i32(f["f_int32_2"]),
            f_string_2: try str(f["f_string_2"])
        )
    }

    static func documentValue(_ d: Document) -> Value {
        .object([
            "id": .string(d.id),
            "status": .int(Int64(d.status)),
            "meta": .object([
                "region": .string(d.meta.region),
                "version": .int(Int64(d.meta.version)),
            ]),
            "items": .list(d.items.map { item in
                .object([
                    "sku": .string(item.sku),
                    "qty": .int(Int64(item.qty)),
                    "price_minor": .int(item.price_minor),
                ])
            }),
        ])
    }

    static func document(_ value: Value) throws -> Document {
        let f = try object(value)
        let meta = try object(f["meta"])
        let rawItems = try list(f["items"])
        var items: [DocumentItem] = []
        items.reserveCapacity(rawItems.count)
        for raw in rawItems {
            let item = try object(raw)
            items.append(DocumentItem(
                sku: try str(item["sku"]),
                qty: try i32(item["qty"]),
                price_minor: try i64(item["price_minor"])
            ))
        }
        return Document(
            id: try str(f["id"]),
            status: try i32(f["status"]),
            meta: DocumentMeta(
                region: try str(meta["region"]),
                version: try i32(meta["version"])
            ),
            items: items
        )
    }

    static func telemetryValue(_ t: Telemetry) -> Value {
        .object([
            "source": .string(t.source),
            "ts": .int(t.ts),
            "tags": .list(t.tags.map { .string($0) }),
            "values": .f64s(t.values),
        ])
    }

    static func telemetry(_ value: Value) throws -> Telemetry {
        let f = try object(value)
        let rawTags = try list(f["tags"])
        var tags: [String] = []
        tags.reserveCapacity(rawTags.count)
        for tag in rawTags {
            tags.append(try str(tag))
        }
        return Telemetry(
            source: try str(f["source"]),
            ts: try i64(f["ts"]),
            tags: tags,
            values: try f64s(f["values"])
        )
    }

    static func stringsValue(_ s: Strings) -> Value {
        .object([
            "items": .list(s.items.map { .string($0) }),
        ])
    }

    static func strings(_ value: Value) throws -> Strings {
        let f = try object(value)
        let raw = try list(f["items"])
        var items: [String] = []
        items.reserveCapacity(raw.count)
        for item in raw {
            items.append(try str(item))
        }
        return Strings(items: items)
    }

    static func eventValue(_ event: Event) -> Value {
        .object([
            "event_id": .string(event.event_id),
            "event_type": .string(event.event_type),
            "occurred_at": .int(event.occurred_at),
            "producer": .string(event.producer),
            "attrs": .list(event.attrs.map { attr in
                .object([
                    "key": .string(attr.key),
                    "value": .string(attr.value),
                ])
            }),
        ])
    }

    static func appendU32(_ data: inout Data, _ value: UInt32) {
        var le = value.littleEndian
        withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
    }

    static func appendI32(_ data: inout Data, _ value: Int32) {
        appendU32(&data, UInt32(bitPattern: value))
    }

    static func appendI64(_ data: inout Data, _ value: Int64) {
        var le = value.littleEndian
        withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
    }

    static func appendF32(_ data: inout Data, _ value: Float) {
        var bits = value.bitPattern.littleEndian
        withUnsafeBytes(of: &bits) { data.append(contentsOf: $0) }
    }

    static func appendF32s(_ data: inout Data, _ values: [Float]) {
        appendU32(&data, UInt32(values.count))
        values.withUnsafeBufferPointer { buf in
            data.append(contentsOf: UnsafeRawBufferPointer(buf))
        }
    }

    static func appendI64s(_ data: inout Data, _ values: [Int64]) {
        appendU32(&data, UInt32(values.count))
        values.withUnsafeBufferPointer { buf in
            data.append(contentsOf: UnsafeRawBufferPointer(buf))
        }
    }

    static var byteScratch: UnsafeMutableRawPointer?
    static var byteScratchCount = 0
    static var floatPool: [[Float]] = []
    static var floatUsed = 0

    static func ownedBytes(_ count: Int, _ fill: (UnsafeMutableRawPointer) -> Void) -> Data {
        if byteScratch == nil || byteScratchCount < count {
            byteScratch?.deallocate()
            byteScratch = .allocate(byteCount: count, alignment: 16)
            byteScratchCount = count
        }
        let raw = byteScratch!
        fill(raw)
        // The runner finishes fidelity before the next encode, so this storage stays stable.
        return Data(bytesNoCopy: raw, count: count, deallocator: .custom { _, _ in })
    }

    static func takeFloats(_ count: Int) -> Int {
        if floatUsed >= floatPool.count {
            floatPool.append([])
        }
        if floatPool[floatUsed].count != count {
            floatPool[floatUsed] = [Float](repeating: 0, count: count)
        }
        let index = floatUsed
        floatUsed += 1
        return index
    }

    static func storeU32(_ raw: UnsafeMutableRawPointer, _ offset: Int, _ value: UInt32) {
        raw.advanced(by: offset).storeBytes(of: value.littleEndian, as: UInt32.self)
    }

    static func storeI32(_ raw: UnsafeMutableRawPointer, _ offset: Int, _ value: Int32) {
        storeU32(raw, offset, UInt32(bitPattern: value))
    }

    static func copyF32(_ raw: UnsafeMutableRawPointer, _ offset: inout Int, _ values: [Float]) {
        storeU32(raw, offset, UInt32(values.count))
        offset += 4
        values.withUnsafeBytes { src in
            if src.count > 0 {
                raw.advanced(by: offset).copyMemory(from: src.baseAddress!, byteCount: src.count)
            }
        }
        offset += values.count * 4
    }

    static func tensorData(_ row: TensorMatrix) -> Data {
        let n = 12 + row.values.count * 4
        return ownedBytes(n) { raw in
            storeI32(raw, 0, row.rows)
            storeI32(raw, 4, row.cols)
            var offset = 8
            copyF32(raw, &offset, row.values)
        }
    }

    static func promptData(_ row: Prompt) -> Data {
        var data = Data()
        data.reserveCapacity(20 + (row.input_ids.count + row.attention_mask.count + row.position_ids.count) * 8)
        appendI32(&data, row.batch)
        appendI32(&data, row.seq)
        appendI64s(&data, row.input_ids)
        appendI64s(&data, row.attention_mask)
        appendI64s(&data, row.position_ids)
        return data
    }

    static func shardData(_ row: Shard) -> Data {
        let n = 28 + 4 * (row.tok_emb.count + row.attn.count + row.ffn_weight.count + row.norm.count)
        return ownedBytes(n) { raw in
            storeI32(raw, 0, row.vocab)
            storeI32(raw, 4, row.hidden)
            storeI32(raw, 8, row.ffn)
            var offset = 12
            copyF32(raw, &offset, row.tok_emb)
            copyF32(raw, &offset, row.attn)
            copyF32(raw, &offset, row.ffn_weight)
            copyF32(raw, &offset, row.norm)
        }
    }

    static func requestData(_ row: Request) -> Data {
        var data = Data()
        let utf = Array(row.model.utf8)
        let body = promptData(row.inputs)
        data.reserveCapacity(12 + utf.count + body.count)
        appendI64(&data, row.request_id)
        appendU32(&data, UInt32(utf.count))
        data.append(contentsOf: utf)
        appendF32(&data, row.temperature)
        data.append(body)
        return data
    }

    static func readF32s(_ data: Data, _ i: inout Int) throws -> [Float] {
        let count = Int(loadU32LE(data, i))
        i += 4
        let bytes = count * 4
        if count < 0 || i + bytes > data.count { throw BenchError.unsupported("gld-kiln EOF") }
        if count == 0 { return [] }
        let index = takeFloats(count)
        floatPool[index].withUnsafeMutableBytes { dst in
            data.withUnsafeBytes { raw in
                dst.baseAddress!.copyMemory(from: raw.baseAddress!.advanced(by: i), byteCount: bytes)
            }
        }
        i += bytes
        return floatPool[index]
    }

    static func readI64s(_ data: Data, _ i: inout Int) throws -> [Int64] {
        let count = Int(loadU32LE(data, i))
        i += 4
        let bytes = count * 8
        if count < 0 || i + bytes > data.count { throw BenchError.unsupported("gld-kiln EOF") }
        if count == 0 { return [] }
        var out = [Int64](repeating: 0, count: count)
        out.withUnsafeMutableBytes { dst in
            data.withUnsafeBytes { raw in
                dst.baseAddress!.copyMemory(from: raw.baseAddress!.advanced(by: i), byteCount: bytes)
            }
        }
        i += bytes
        return out
    }

    static func readTensor(_ data: Data) throws -> TensorMatrix {
        floatUsed = 0
        if data.count < 12 { throw BenchError.unsupported("gld-kiln EOF") }
        let rows = Int32(bitPattern: loadU32LE(data, 0))
        let cols = Int32(bitPattern: loadU32LE(data, 4))
        var i = 8
        let values = try readF32s(data, &i)
        if i != data.count { throw BenchError.unsupported("gld-kiln TRAILING") }
        return TensorMatrix(rows: rows, cols: cols, values: values)
    }

    static func readPrompt(_ data: Data) throws -> Prompt {
        if data.count < 8 { throw BenchError.unsupported("gld-kiln EOF") }
        let batch = Int32(bitPattern: loadU32LE(data, 0))
        let seq = Int32(bitPattern: loadU32LE(data, 4))
        var i = 8
        let input = try readI64s(data, &i)
        let mask = try readI64s(data, &i)
        let pos = try readI64s(data, &i)
        if i != data.count { throw BenchError.unsupported("gld-kiln TRAILING") }
        return Prompt(batch: batch, seq: seq, input_ids: input, attention_mask: mask, position_ids: pos)
    }

    static func readShard(_ data: Data) throws -> Shard {
        floatUsed = 0
        if data.count < 12 { throw BenchError.unsupported("gld-kiln EOF") }
        let vocab = Int32(bitPattern: loadU32LE(data, 0))
        let hidden = Int32(bitPattern: loadU32LE(data, 4))
        let ffn = Int32(bitPattern: loadU32LE(data, 8))
        var i = 12
        let tok = try readF32s(data, &i)
        let attn = try readF32s(data, &i)
        let ffnW = try readF32s(data, &i)
        let norm = try readF32s(data, &i)
        if i != data.count { throw BenchError.unsupported("gld-kiln TRAILING") }
        return Shard(vocab: vocab, hidden: hidden, ffn: ffn, tok_emb: tok, attn: attn, ffn_weight: ffnW, norm: norm)
    }

    static func readRequest(_ data: Data) throws -> Request {
        if data.count < 12 { throw BenchError.unsupported("gld-kiln EOF") }
        var i = 0
        let id = Int64(bitPattern: loadU64(data, &i))
        let n = Int(loadU32LE(data, i))
        i += 4
        if i + n > data.count { throw BenchError.unsupported("gld-kiln EOF") }
        let model = String(decoding: data[i..<(i + n)], as: UTF8.self)
        i += n
        let temp = Float(bitPattern: loadU32LE(data, i))
        i += 4
        let inputs = try readPrompt(Data(data[i...]))
        return Request(request_id: id, model: model, temperature: temp, inputs: inputs)
    }

    static func loadU64(_ data: Data, _ i: inout Int) -> UInt64 {
        let v = UInt64(loadU32LE(data, i)) | (UInt64(loadU32LE(data, i + 4)) << 32)
        i += 8
        return v
    }

    static func tensorValue(_ tensor: TensorMatrix) -> Value {
        .object([
            "rows": .int(Int64(tensor.rows)),
            "cols": .int(Int64(tensor.cols)),
            "values": f32List(tensor.values),
        ])
    }

    static func tensor(_ value: Value) throws -> TensorMatrix {
        let f = try object(value)
        return TensorMatrix(
            rows: try i32(f["rows"]),
            cols: try i32(f["cols"]),
            values: try f32s(f["values"])
        )
    }

    /// Borrow the f32 payload. Does not allocate a float array.
    static func tensorView(_ data: Data) throws -> TensorView {
        if data.count < 12 {
            throw BenchError.unsupported("gld-kiln tensor_view")
        }
        let rows = Int32(bitPattern: loadU32LE(data, 0))
        let cols = Int32(bitPattern: loadU32LE(data, 4))
        let count = loadU32LE(data, 8)
        let payload = UInt64(count) * 4
        if payload != UInt64(data.count - 12) {
            throw BenchError.unsupported("gld-kiln tensor_view length")
        }
        return TensorView(rows: rows, cols: cols, storage: data, offset: 12, count: Int(count))
    }

    static func promptValue(_ prompt: Prompt) -> Value {
        .object([
            "batch": .int(Int64(prompt.batch)),
            "seq": .int(Int64(prompt.seq)),
            "input_ids": .i64s(prompt.input_ids),
            "attention_mask": .i64s(prompt.attention_mask),
            "position_ids": .i64s(prompt.position_ids),
        ])
    }

    static func prompt(_ value: Value) throws -> Prompt {
        let f = try object(value)
        return Prompt(
            batch: try i32(f["batch"]),
            seq: try i32(f["seq"]),
            input_ids: try i64s(f["input_ids"]),
            attention_mask: try i64s(f["attention_mask"]),
            position_ids: try i64s(f["position_ids"])
        )
    }

    static func shardValue(_ shard: Shard) -> Value {
        .object([
            "vocab": .int(Int64(shard.vocab)),
            "hidden": .int(Int64(shard.hidden)),
            "ffn": .int(Int64(shard.ffn)),
            "tok_emb": f32List(shard.tok_emb),
            "attn": f32List(shard.attn),
            "ffn_weight": f32List(shard.ffn_weight),
            "norm": f32List(shard.norm),
        ])
    }

    static func shard(_ value: Value) throws -> Shard {
        let f = try object(value)
        return Shard(
            vocab: try i32(f["vocab"]),
            hidden: try i32(f["hidden"]),
            ffn: try i32(f["ffn"]),
            tok_emb: try f32s(f["tok_emb"]),
            attn: try f32s(f["attn"]),
            ffn_weight: try f32s(f["ffn_weight"]),
            norm: try f32s(f["norm"])
        )
    }

    static func requestValue(_ request: Request) -> Value {
        .object([
            "request_id": .int(request.request_id),
            "model": .string(request.model),
            "temperature": .f32(request.temperature),
            "inputs": promptValue(request.inputs),
        ])
    }

    static func request(_ value: Value) throws -> Request {
        let f = try object(value)
        return Request(
            request_id: try i64(f["request_id"]),
            model: try str(f["model"]),
            temperature: try f32(f["temperature"]),
            inputs: try prompt(f["inputs"] ?? .null)
        )
    }

    static func event(_ value: Value) throws -> Event {
        let f = try object(value)
        let rawAttrs = try list(f["attrs"])
        var attrs: [EventAttr] = []
        attrs.reserveCapacity(rawAttrs.count)
        for raw in rawAttrs {
            let attr = try object(raw)
            attrs.append(EventAttr(
                key: try str(attr["key"]),
                value: try str(attr["value"])
            ))
        }
        return Event(
            event_id: try str(f["event_id"]),
            event_type: try str(f["event_type"]),
            occurred_at: try i64(f["occurred_at"]),
            producer: try str(f["producer"]),
            attrs: attrs
        )
    }

    private static func object(_ value: Value?) throws -> [String: Value] {
        guard case .object(let map)? = value else {
            throw BenchError.unsupported("gld-kiln struct")
        }
        return map
    }

    private static func list(_ value: Value?) throws -> [Value] {
        guard case .list(let items)? = value else {
            throw BenchError.unsupported("gld-kiln list")
        }
        return items
    }

    private static func bool(_ value: Value?) throws -> Bool {
        guard case .bool(let flag)? = value else {
            throw BenchError.unsupported("gld-kiln bool")
        }
        return flag
    }

    private static func i32(_ value: Value?) throws -> Int32 {
        let raw = try i64(value)
        guard let n = Int32(exactly: raw) else {
            throw BenchError.unsupported("gld-kiln int32")
        }
        return n
    }

    private static func i64(_ value: Value?) throws -> Int64 {
        guard case .int(let n)? = value else {
            throw BenchError.unsupported("gld-kiln int64")
        }
        return n
    }

    private static func f64(_ value: Value?) throws -> Double {
        guard case .f64(let n)? = value else {
            throw BenchError.unsupported("gld-kiln float64")
        }
        return n
    }

    private static func str(_ value: Value?) throws -> String {
        guard case .string(let text)? = value else {
            throw BenchError.unsupported("gld-kiln string")
        }
        return text
    }

    private static func f32(_ value: Value?) throws -> Float {
        guard case .f32(let number)? = value else {
            throw BenchError.unsupported("gld-kiln float32")
        }
        return number
    }

    private static func f32List(_ values: [Float]) -> Value {
        .f32s(values)
    }

    private static func f32s(_ value: Value?) throws -> [Float] {
        if case .f32s(let items)? = value { return items }
        let raw = try list(value)
        var out: [Float] = []
        out.reserveCapacity(raw.count)
        for item in raw {
            out.append(try f32(item))
        }
        return out
    }

    private static func f64s(_ value: Value?) throws -> [Double] {
        if case .f64s(let items)? = value { return items }
        let raw = try list(value)
        var out: [Double] = []
        out.reserveCapacity(raw.count)
        for item in raw {
            out.append(try f64(item))
        }
        return out
    }

    private static func i64s(_ value: Value?) throws -> [Int64] {
        if case .i64s(let items)? = value { return items }
        let raw = try list(value)
        var out: [Int64] = []
        out.reserveCapacity(raw.count)
        for item in raw {
            out.append(try i64(item))
        }
        return out
    }

    private static func loadU32LE(_ data: Data, _ offset: Int) -> UInt32 {
        let i = data.startIndex + offset
        return UInt32(data[i])
            | (UInt32(data[i + 1]) << 8)
            | (UInt32(data[i + 2]) << 16)
            | (UInt32(data[i + 3]) << 24)
    }
}
