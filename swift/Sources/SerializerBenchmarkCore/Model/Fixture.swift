import Foundation

/// Type-erased suite payload. Serializers see only this type — never Message/Document/etc.
public final class Fixture: @unchecked Sendable {
    public let name: String
    /// Canonical suite value (single instance or typed array for N>1).
    public let value: any Encodable
    /// Map-root form for codecs that cannot encode a bare array (BSON, some TOML).
    /// Equal to `value` when `instanceCount == 1`; otherwise `ItemsWrap` over the batch.
    public let mapRootValue: any Encodable
    public let instanceCount: Int
    public let typeConfigHash: String
    public var needsMapRoot: Bool { instanceCount > 1 }

    public protocol GenericDecoder: AnyObject {
        func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T
    }

    private let _applyDecode: (Data, any GenericDecoder) throws -> Any
    private let _applyDecodeMapRoot: (Data, any GenericDecoder) throws -> Any
    private let _equals: (Any) -> Bool

    public init<T: Codable>(
        name: String,
        value: T,
        instanceCount: Int = 1,
        typeConfigHash: String = ""
    ) {
        self.name = name
        self.value = value
        self.instanceCount = instanceCount
        self.typeConfigHash = typeConfigHash
        self.mapRootValue = value
        self._applyDecode = { data, decoder in
            try decoder.decode(T.self, from: data)
        }
        self._applyDecodeMapRoot = { data, decoder in
            try decoder.decode(T.self, from: data)
        }
        self._equals = { other in semanticEqual(value, other) }
    }

    /// Batch fixture: bare array for most codecs; `ItemsWrap` for map-root codecs.
    public init<T: Codable>(
        name: String,
        batch: [T],
        typeConfigHash: String = ""
    ) {
        self.name = name
        self.value = batch
        self.mapRootValue = ItemsWrap(items: batch)
        self.instanceCount = batch.count
        self.typeConfigHash = typeConfigHash
        self._applyDecode = { data, decoder in
            try decoder.decode([T].self, from: data)
        }
        self._applyDecodeMapRoot = { data, decoder in
            let wrap = try decoder.decode(ItemsWrap<T>.self, from: data)
            return wrap.items
        }
        self._equals = { other in semanticEqual(batch, other) }
    }

    public func decode(from data: Data, using decoder: any GenericDecoder) throws -> Any {
        try _applyDecode(data, decoder)
    }

    /// Decode map-root batch form back to the suite array value.
    public func decodeMapRoot(from data: Data, using decoder: any GenericDecoder) throws -> Any {
        try _applyDecodeMapRoot(data, decoder)
    }

    public func fidelity(against other: Any) -> Bool {
        _equals(other)
    }
}

/// Semantic equality with float tolerance (Python fidelity_v2: rel/abs 1e-9).
public func semanticEqual(_ a: Any, _ b: Any) -> Bool {
    if let x = a as? Double, let y = b as? Double {
        return doubleClose(x, y)
    }
    if let x = a as? Float, let y = b as? Float {
        return doubleClose(Double(x), Double(y))
    }
    if let x = a as? Bool, let y = b as? Bool { return x == y }
    if let x = a as? String, let y = b as? String { return x == y }
    if let x = a as? Int32, let y = b as? Int32 { return x == y }
    if let x = a as? Int64, let y = b as? Int64 { return x == y }
    if let x = a as? Int, let y = b as? Int { return x == y }

    if let x = a as? Message, let y = b as? Message {
        return x.f_bool == y.f_bool
            && x.f_int32 == y.f_int32
            && x.f_int64 == y.f_int64
            && doubleClose(x.f_float64, y.f_float64)
            && x.f_string == y.f_string
            && x.f_bool_2 == y.f_bool_2
            && x.f_int32_2 == y.f_int32_2
            && x.f_string_2 == y.f_string_2
    }
    if let x = a as? Document, let y = b as? Document {
        return x.id == y.id && x.status == y.status
            && x.meta.region == y.meta.region && x.meta.version == y.meta.version
            && x.items.count == y.items.count
            && zip(x.items, y.items).allSatisfy { i, j in
                i.sku == j.sku && i.qty == j.qty && i.price_minor == j.price_minor
            }
    }
    if let x = a as? Telemetry, let y = b as? Telemetry {
        return x.source == y.source && x.ts == y.ts && x.tags == y.tags
            && x.values.count == y.values.count
            && zip(x.values, y.values).allSatisfy { doubleClose($0, $1) }
    }
    if let x = a as? Strings, let y = b as? Strings {
        return x.items == y.items
    }
    if let x = a as? Event, let y = b as? Event {
        return x.event_id == y.event_id && x.event_type == y.event_type
            && x.occurred_at == y.occurred_at && x.producer == y.producer
            && x.attrs.count == y.attrs.count
            && zip(x.attrs, y.attrs).allSatisfy { $0.key == $1.key && $0.value == $1.value }
    }
    if let x = a as? [Message], let y = b as? [Message] {
        return x.count == y.count && zip(x, y).allSatisfy { semanticEqual($0, $1) }
    }
    if let x = a as? [Document], let y = b as? [Document] {
        return x.count == y.count && zip(x, y).allSatisfy { semanticEqual($0, $1) }
    }
    if let x = a as? [Telemetry], let y = b as? [Telemetry] {
        return x.count == y.count && zip(x, y).allSatisfy { semanticEqual($0, $1) }
    }
    if let x = a as? [Strings], let y = b as? [Strings] {
        return x.count == y.count && zip(x, y).allSatisfy { semanticEqual($0, $1) }
    }
    if let x = a as? [Event], let y = b as? [Event] {
        return x.count == y.count && zip(x, y).allSatisfy { semanticEqual($0, $1) }
    }
    return false
}

private func doubleClose(_ a: Double, _ b: Double) -> Bool {
    if a == b { return true }
    if a.isNaN && b.isNaN { return true }
    let diff = abs(a - b)
    let scale = max(abs(a), abs(b), 1.0)
    return diff <= 1e-9 * scale || diff <= 1e-9
}
