// Data Model v2 domain types. Field names match the catalog / other harnesses.
// Serializers must NOT import concrete payload types — only Fixture (type-erased).

import Foundation
import Fory

@ForyStruct
public struct Message: Codable, Equatable, Sendable {
    public var f_bool: Bool
    public var f_int32: Int32
    public var f_int64: Int64
    public var f_float64: Double
    public var f_string: String
    public var f_bool_2: Bool
    public var f_int32_2: Int32
    public var f_string_2: String

    public init(
        f_bool: Bool, f_int32: Int32, f_int64: Int64, f_float64: Double, f_string: String,
        f_bool_2: Bool, f_int32_2: Int32, f_string_2: String
    ) {
        self.f_bool = f_bool
        self.f_int32 = f_int32
        self.f_int64 = f_int64
        self.f_float64 = f_float64
        self.f_string = f_string
        self.f_bool_2 = f_bool_2
        self.f_int32_2 = f_int32_2
        self.f_string_2 = f_string_2
    }
}

/// Owned row-major float32 matrix. `values.count` is `rows * cols`.
public struct TensorMatrix: Codable, Sendable {
    public var rows: Int32
    public var cols: Int32
    public var values: [Float]

    public init(rows: Int32, cols: Int32, values: [Float]) {
        self.rows = rows
        self.cols = cols
        self.values = values
    }
}

/// `tensor_view` decode. `storage` is the encoded buffer; the f32 payload is a span at `offset`.
public struct TensorView: Sendable {
    public var rows: Int32
    public var cols: Int32
    public var storage: Data
    public var offset: Int
    public var count: Int

    public init(rows: Int32, cols: Int32, storage: Data, offset: Int, count: Int) {
        self.rows = rows
        self.cols = cols
        self.storage = storage
        self.offset = offset
        self.count = count
    }
}

public struct Prompt: Codable, Equatable, Sendable {
    public var batch: Int32
    public var seq: Int32
    public var input_ids: [Int64]
    public var attention_mask: [Int64]
    public var position_ids: [Int64]

    public init(
        batch: Int32, seq: Int32, input_ids: [Int64], attention_mask: [Int64], position_ids: [Int64]
    ) {
        self.batch = batch
        self.seq = seq
        self.input_ids = input_ids
        self.attention_mask = attention_mask
        self.position_ids = position_ids
    }
}

public struct Shard: Codable, Sendable {
    public var vocab: Int32
    public var hidden: Int32
    public var ffn: Int32
    public var tok_emb: [Float]
    public var attn: [Float]
    public var ffn_weight: [Float]
    public var norm: [Float]

    public init(
        vocab: Int32, hidden: Int32, ffn: Int32,
        tok_emb: [Float], attn: [Float], ffn_weight: [Float], norm: [Float]
    ) {
        self.vocab = vocab
        self.hidden = hidden
        self.ffn = ffn
        self.tok_emb = tok_emb
        self.attn = attn
        self.ffn_weight = ffn_weight
        self.norm = norm
    }
}

public struct Request: Codable, Sendable {
    public var request_id: Int64
    public var model: String
    public var temperature: Float
    public var inputs: Prompt

    public init(request_id: Int64, model: String, temperature: Float, inputs: Prompt) {
        self.request_id = request_id
        self.model = model
        self.temperature = temperature
        self.inputs = inputs
    }
}

func f32BitsEqual(_ lhs: [Float], _ rhs: [Float]) -> Bool {
    if lhs.count != rhs.count { return false }
    for i in 0..<lhs.count {
        if lhs[i].bitPattern != rhs[i].bitPattern { return false }
    }
    return true
}

extension TensorMatrix: Equatable {
    public static func == (lhs: TensorMatrix, rhs: TensorMatrix) -> Bool {
        lhs.rows == rhs.rows && lhs.cols == rhs.cols && f32BitsEqual(lhs.values, rhs.values)
    }
}

extension Shard: Equatable {
    public static func == (lhs: Shard, rhs: Shard) -> Bool {
        lhs.vocab == rhs.vocab && lhs.hidden == rhs.hidden && lhs.ffn == rhs.ffn
            && f32BitsEqual(lhs.tok_emb, rhs.tok_emb)
            && f32BitsEqual(lhs.attn, rhs.attn)
            && f32BitsEqual(lhs.ffn_weight, rhs.ffn_weight)
            && f32BitsEqual(lhs.norm, rhs.norm)
    }
}

extension Request: Equatable {
    public static func == (lhs: Request, rhs: Request) -> Bool {
        lhs.request_id == rhs.request_id && lhs.model == rhs.model
            && lhs.temperature.bitPattern == rhs.temperature.bitPattern
            && lhs.inputs == rhs.inputs
    }
}

@ForyStruct
public struct DocumentMeta: Codable, Equatable, Sendable {
    public var region: String
    public var version: Int32
    public init(region: String, version: Int32) {
        self.region = region
        self.version = version
    }
}

@ForyStruct
public struct DocumentItem: Codable, Equatable, Sendable {
    public var sku: String
    public var qty: Int32
    public var price_minor: Int64
    public init(sku: String, qty: Int32, price_minor: Int64) {
        self.sku = sku
        self.qty = qty
        self.price_minor = price_minor
    }
}

@ForyStruct
public struct Document: Codable, Equatable, Sendable {
    public var id: String
    public var status: Int32
    public var meta: DocumentMeta
    public var items: [DocumentItem]
    public init(id: String, status: Int32, meta: DocumentMeta, items: [DocumentItem]) {
        self.id = id
        self.status = status
        self.meta = meta
        self.items = items
    }
}

@ForyStruct
public struct Telemetry: Codable, Equatable, Sendable {
    public var source: String
    public var ts: Int64
    public var tags: [String]
    public var values: [Double]
    public init(source: String, ts: Int64, tags: [String], values: [Double]) {
        self.source = source
        self.ts = ts
        self.tags = tags
        self.values = values
    }
}

@ForyStruct
public struct Strings: Codable, Equatable, Sendable {
    public var items: [String]
    public init(items: [String]) { self.items = items }
}

@ForyStruct
public struct EventAttr: Codable, Equatable, Sendable {
    public var key: String
    public var value: String
    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

@ForyStruct
public struct Event: Codable, Equatable, Sendable {
    public var event_id: String
    public var event_type: String
    public var occurred_at: Int64
    public var producer: String
    public var attrs: [EventAttr]
    public init(
        event_id: String, event_type: String, occurred_at: Int64, producer: String, attrs: [EventAttr]
    ) {
        self.event_id = event_id
        self.event_type = event_type
        self.occurred_at = occurred_at
        self.producer = producer
        self.attrs = attrs
    }
}

/// Map root for codecs that cannot encode a bare array (BSON document root).
public struct ItemsWrap<T: Codable>: Codable {
    public var items: [T]
    public init(items: [T]) { self.items = items }
}

// One graph. Classes so several orders can hold one Region and Person.next can ring.
// Not Equatable: a synthesized == would follow that ring forever.
// Book is Codable only so Fixture can store it. encode/decode throw; tree codecs skip graph.

public final class Region: @unchecked Sendable {
    public let code: String
    public let note: String
    public let version: Int32
    public init(code: String, note: String, version: Int32) {
        self.code = code
        self.note = note
        self.version = version
    }
}

public final class Order: @unchecked Sendable {
    public let sku: String
    public let qty: Int32
    public let region: Region
    public init(sku: String, qty: Int32, region: Region) {
        self.sku = sku
        self.qty = qty
        self.region = region
    }
}

public final class Person: @unchecked Sendable {
    public let name: String
    public var next: Person?
    public init(name: String, next: Person? = nil) {
        self.name = name
        self.next = next
    }
}

public final class Book: @unchecked Sendable, Codable {
    public let orders: [Order]
    public let people: [Person]
    public init(orders: [Order], people: [Person]) {
        self.orders = orders
        self.people = people
    }

    public func encode(to encoder: Encoder) throws {
        throw EncodingError.invalidValue(
            self,
            EncodingError.Context(
                codingPath: encoder.codingPath,
                debugDescription: "graph is a reference cycle"
            )
        )
    }

    public init(from decoder: Decoder) throws {
        self.orders = []
        self.people = []
        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "graph is a reference cycle"
            )
        )
    }
}

public let baseTSMS: Int64 = 1_704_067_200_000
