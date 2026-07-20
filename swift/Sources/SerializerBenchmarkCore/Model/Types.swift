// Data Model v2 domain types. Field names match the catalog / other harnesses.
// Serializers must NOT import concrete payload types — only Fixture (type-erased).

import Foundation

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

public struct DocumentMeta: Codable, Equatable, Sendable {
    public var region: String
    public var version: Int32
    public init(region: String, version: Int32) {
        self.region = region
        self.version = version
    }
}

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

public struct Strings: Codable, Equatable, Sendable {
    public var items: [String]
    public init(items: [String]) { self.items = items }
}

public struct EventAttr: Codable, Equatable, Sendable {
    public var key: String
    public var value: String
    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

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

public let baseTSMS: Int64 = 1_704_067_200_000
