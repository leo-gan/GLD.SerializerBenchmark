using System.Collections.Generic;
using FlatSharp.Attributes;

namespace GLD.SerializerBenchmark.Serializers
{
    // Public FlatSharp tables (must be public for FlatSharp runtime code-gen).

    [FlatBufferTable]
    public class FsMessage
    {
        [FlatBufferItem(0)] public virtual bool FBool { get; set; }
        [FlatBufferItem(1)] public virtual int FInt32 { get; set; }
        [FlatBufferItem(2)] public virtual long FInt64 { get; set; }
        [FlatBufferItem(3)] public virtual double FFloat64 { get; set; }
        [FlatBufferItem(4)] public virtual string FString { get; set; }
        [FlatBufferItem(5)] public virtual bool FBool2 { get; set; }
        [FlatBufferItem(6)] public virtual int FInt322 { get; set; }
        [FlatBufferItem(7)] public virtual string FString2 { get; set; }
    }

    [FlatBufferTable]
    public class FsDocumentMeta
    {
        [FlatBufferItem(0)] public virtual string Region { get; set; }
        [FlatBufferItem(1)] public virtual int Version { get; set; }
    }

    [FlatBufferTable]
    public class FsDocumentItem
    {
        [FlatBufferItem(0)] public virtual string Sku { get; set; }
        [FlatBufferItem(1)] public virtual int Qty { get; set; }
        [FlatBufferItem(2)] public virtual long PriceMinor { get; set; }
    }

    [FlatBufferTable]
    public class FsDocument
    {
        [FlatBufferItem(0)] public virtual string Id { get; set; }
        [FlatBufferItem(1)] public virtual int Status { get; set; }
        [FlatBufferItem(2)] public virtual FsDocumentMeta Meta { get; set; }
        [FlatBufferItem(3)] public virtual IList<FsDocumentItem> Items { get; set; }
    }

    [FlatBufferTable]
    public class FsTelemetry
    {
        [FlatBufferItem(0)] public virtual string Source { get; set; }
        [FlatBufferItem(1)] public virtual long Ts { get; set; }
        [FlatBufferItem(2)] public virtual IList<string> Tags { get; set; }
        [FlatBufferItem(3)] public virtual IList<double> Values { get; set; }
    }

    [FlatBufferTable]
    public class FsStrings
    {
        [FlatBufferItem(0)] public virtual IList<string> Items { get; set; }
    }

    [FlatBufferTable]
    public class FsEventAttr
    {
        [FlatBufferItem(0)] public virtual string Key { get; set; }
        [FlatBufferItem(1)] public virtual string Value { get; set; }
    }

    [FlatBufferTable]
    public class FsEvent
    {
        [FlatBufferItem(0)] public virtual string EventId { get; set; }
        [FlatBufferItem(1)] public virtual string EventType { get; set; }
        [FlatBufferItem(2)] public virtual long OccurredAt { get; set; }
        [FlatBufferItem(3)] public virtual string Producer { get; set; }
        [FlatBufferItem(4)] public virtual IList<FsEventAttr> Attrs { get; set; }
    }

    [FlatBufferTable]
    public class FsBatchMessage
    {
        [FlatBufferItem(0)] public virtual IList<FsMessage> Items { get; set; }
    }

    [FlatBufferTable]
    public class FsBatchDocument
    {
        [FlatBufferItem(0)] public virtual IList<FsDocument> Items { get; set; }
    }

    [FlatBufferTable]
    public class FsBatchTelemetry
    {
        [FlatBufferItem(0)] public virtual IList<FsTelemetry> Items { get; set; }
    }

    [FlatBufferTable]
    public class FsBatchStrings
    {
        [FlatBufferItem(0)] public virtual IList<FsStrings> Items { get; set; }
    }

    [FlatBufferTable]
    public class FsBatchEvent
    {
        [FlatBufferItem(0)] public virtual IList<FsEvent> Items { get; set; }
    }
}
