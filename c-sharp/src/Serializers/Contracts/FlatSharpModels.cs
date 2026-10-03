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

    // Hand-written tables matching python schema_flatbuffers slot order.
    // table: floats 0-15, int64 16-19, strings 20-21.
    [FlatBufferTable]
    public class FsTable
    {
        [FlatBufferItem(0)] public virtual double FFloat0 { get; set; }
        [FlatBufferItem(1)] public virtual double FFloat1 { get; set; }
        [FlatBufferItem(2)] public virtual double FFloat2 { get; set; }
        [FlatBufferItem(3)] public virtual double FFloat3 { get; set; }
        [FlatBufferItem(4)] public virtual double FFloat4 { get; set; }
        [FlatBufferItem(5)] public virtual double FFloat5 { get; set; }
        [FlatBufferItem(6)] public virtual double FFloat6 { get; set; }
        [FlatBufferItem(7)] public virtual double FFloat7 { get; set; }
        [FlatBufferItem(8)] public virtual double FFloat8 { get; set; }
        [FlatBufferItem(9)] public virtual double FFloat9 { get; set; }
        [FlatBufferItem(10)] public virtual double FFloat10 { get; set; }
        [FlatBufferItem(11)] public virtual double FFloat11 { get; set; }
        [FlatBufferItem(12)] public virtual double FFloat12 { get; set; }
        [FlatBufferItem(13)] public virtual double FFloat13 { get; set; }
        [FlatBufferItem(14)] public virtual double FFloat14 { get; set; }
        [FlatBufferItem(15)] public virtual double FFloat15 { get; set; }
        [FlatBufferItem(16)] public virtual long FInt0 { get; set; }
        [FlatBufferItem(17)] public virtual long FInt1 { get; set; }
        [FlatBufferItem(18)] public virtual long FInt2 { get; set; }
        [FlatBufferItem(19)] public virtual long FInt3 { get; set; }
        [FlatBufferItem(20)] public virtual string FStr0 { get; set; }
        [FlatBufferItem(21)] public virtual string FStr1 { get; set; }
    }

    [FlatBufferTable]
    public class FsBatchTable
    {
        [FlatBufferItem(0)] public virtual IList<FsTable> Items { get; set; }
    }

    [FlatBufferTable]
    public class FsNestedMeta
    {
        [FlatBufferItem(0)] public virtual string Region { get; set; }
        [FlatBufferItem(1)] public virtual int Version { get; set; }
    }

    [FlatBufferTable]
    public class FsNestedItem
    {
        [FlatBufferItem(0)] public virtual string Sku { get; set; }
        [FlatBufferItem(1)] public virtual int Qty { get; set; }
        [FlatBufferItem(2)] public virtual long PriceMinor { get; set; }
    }

    [FlatBufferTable]
    public class FsNestedRow
    {
        [FlatBufferItem(0)] public virtual string Id { get; set; }
        [FlatBufferItem(1)] public virtual int Status { get; set; }
        [FlatBufferItem(2)] public virtual FsNestedMeta Meta { get; set; }
        [FlatBufferItem(3)] public virtual IList<FsNestedItem> Items { get; set; }
    }

    [FlatBufferTable]
    public class FsBatchNestedRow
    {
        [FlatBufferItem(0)] public virtual IList<FsNestedRow> Items { get; set; }
    }

    [FlatBufferTable]
    public class FsSignalLeg
    {
        [FlatBufferItem(0)] public virtual long LegId { get; set; }
        [FlatBufferItem(1)] public virtual int LegQty { get; set; }
        [FlatBufferItem(2)] public virtual int LegPad { get; set; }
    }

    [FlatBufferTable]
    public class FsSignal
    {
        [FlatBufferItem(0)] public virtual long Seq { get; set; }
        [FlatBufferItem(1)] public virtual long Ts { get; set; }
        [FlatBufferItem(2)] public virtual long PriceMantissa { get; set; }
        [FlatBufferItem(3)] public virtual int Qty { get; set; }
        [FlatBufferItem(4)] public virtual int Flags { get; set; }
        [FlatBufferItem(5)] public virtual string Symbol { get; set; }
        [FlatBufferItem(6)] public virtual string Venue { get; set; }
        [FlatBufferItem(7)] public virtual IList<FsSignalLeg> Legs { get; set; }
    }

    [FlatBufferTable]
    public class FsBatchSignal
    {
        [FlatBufferItem(0)] public virtual IList<FsSignal> Items { get; set; }
    }
}
