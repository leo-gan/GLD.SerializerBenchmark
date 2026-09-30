import Foundation

/// Stable registration order for the Swift harness.
public func allSerializers() -> [any BenchSerializer] {
    [
        // JSON family
        FoundationJSONSerializer(),
        IkigaJSONSerializer(),
        // Native / pure-Swift binary Codable
        PropertyListBinarySerializer(),
        BinaryCodableSerializer(),
        ForySerializer(),
        // Schemaless binary
        MsgPackSerializer(),
        CborSerializer(),
        SwiftBSONSerializer(),
        // Text document formats
        YamsSerializer(),
        XMLCoderSerializer(),
        TOMLSerializer(),
        // Schema / IDL
        SwiftProtobufSerializer(),
        FlatBuffersSerializer(),
        SwiftAvroSerializer(),
        CapnProtoSerializer(),
    ]
}
