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
            "values": .list(t.values.map { .f64($0) }),
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
        let rawValues = try list(f["values"])
        var values: [Double] = []
        values.reserveCapacity(rawValues.count)
        for item in rawValues {
            values.append(try f64(item))
        }
        return Telemetry(
            source: try str(f["source"]),
            ts: try i64(f["ts"]),
            tags: tags,
            values: values
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
            "input_ids": .list(prompt.input_ids.map { .int($0) }),
            "attention_mask": .list(prompt.attention_mask.map { .int($0) }),
            "position_ids": .list(prompt.position_ids.map { .int($0) }),
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
        var items: [Value] = []
        items.reserveCapacity(values.count)
        for value in values {
            items.append(.f32(value))
        }
        return .list(items)
    }

    private static func f32s(_ value: Value?) throws -> [Float] {
        let raw = try list(value)
        var out: [Float] = []
        out.reserveCapacity(raw.count)
        for item in raw {
            out.append(try f32(item))
        }
        return out
    }

    private static func i64s(_ value: Value?) throws -> [Int64] {
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
