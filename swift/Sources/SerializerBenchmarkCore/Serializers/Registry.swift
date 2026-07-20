import Foundation

/// Stable registration order for the Swift harness.
public func allSerializers() -> [any BenchSerializer] {
    [
        // JSON family
        FoundationJSONSerializer(),
        IkigaJSONSerializer(),
        // Native document
        PropertyListBinarySerializer(),
        // Schemaless binary
        MsgPackSerializer(),
        CborSerializer(),
        SwiftBSONSerializer(),
        // Text document formats
        YamsSerializer(),
        XMLCoderSerializer(),
        // Schema / IDL
        SwiftProtobufSerializer(),
        FlatBuffersSerializer(),
        SwiftAvroSerializer(),
        CapnProtoSerializer(),
    ]
}
