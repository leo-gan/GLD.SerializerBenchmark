// Data Model v2 domain types — sole suite payload types for the C# benchmark runner.
// Shape matches schemas/data_catalog_v2.yaml, python data_v2.models, and benchmark_v2.proto.
using System;
using System.Collections.Generic;
using System.Runtime.Serialization;
using Bond;
using MemoryPack;
using Nerdbank.MessagePack;
using PolyType;

namespace GLD.SerializerBenchmark.TestData.V2
{
    [MemoryPackable]
    [GenerateShape]
    [Serializable]
    [DataContract]
    [ProtoBuf.ProtoContract] [LightProto.ProtoContract]
    [Schema]
    public partial class Message
    {
        [DataMember(Order = 1)] [ProtoBuf.ProtoMember(1)] [LightProto.ProtoMember(1)] [Id(0)] [Key(0)]
        public virtual bool FBool { get; set; }
        [DataMember(Order = 2)] [ProtoBuf.ProtoMember(2)] [LightProto.ProtoMember(2)] [Id(1)] [Key(1)]
        public virtual int FInt32 { get; set; }
        [DataMember(Order = 3)] [ProtoBuf.ProtoMember(3)] [LightProto.ProtoMember(3)] [Id(2)] [Key(2)]
        public virtual long FInt64 { get; set; }
        [DataMember(Order = 4)] [ProtoBuf.ProtoMember(4)] [LightProto.ProtoMember(4)] [Id(3)] [Key(3)]
        public virtual double FFloat64 { get; set; }
        [DataMember(Order = 5)] [ProtoBuf.ProtoMember(5)] [LightProto.ProtoMember(5)] [Id(4)] [Key(4)]
        public virtual string FString { get; set; } = "";
        [DataMember(Order = 6)] [ProtoBuf.ProtoMember(6)] [LightProto.ProtoMember(6)] [Id(5)] [Key(5)]
        public virtual bool FBool2 { get; set; }
        [DataMember(Order = 7)] [ProtoBuf.ProtoMember(7)] [LightProto.ProtoMember(7)] [Id(6)] [Key(6)]
        public virtual int FInt322 { get; set; }
        [DataMember(Order = 8)] [ProtoBuf.ProtoMember(8)] [LightProto.ProtoMember(8)] [Id(7)] [Key(7)]
        public virtual string FString2 { get; set; } = "";
    }

    [MemoryPackable]
    [GenerateShape]
    [Serializable]
    [DataContract]
    [ProtoBuf.ProtoContract] [LightProto.ProtoContract]
    [Schema]
    public partial class DocumentMeta
    {
        [DataMember(Order = 1)] [ProtoBuf.ProtoMember(1)] [LightProto.ProtoMember(1)] [Id(0)] [Key(0)]
        public virtual string Region { get; set; } = "";
        [DataMember(Order = 2)] [ProtoBuf.ProtoMember(2)] [LightProto.ProtoMember(2)] [Id(1)] [Key(1)]
        public virtual int Version { get; set; }
    }

    [MemoryPackable]
    [GenerateShape]
    [Serializable]
    [DataContract]
    [ProtoBuf.ProtoContract] [LightProto.ProtoContract]
    [Schema]
    public partial class DocumentItem
    {
        [DataMember(Order = 1)] [ProtoBuf.ProtoMember(1)] [LightProto.ProtoMember(1)] [Id(0)] [Key(0)]
        public virtual string Sku { get; set; } = "";
        [DataMember(Order = 2)] [ProtoBuf.ProtoMember(2)] [LightProto.ProtoMember(2)] [Id(1)] [Key(1)]
        public virtual int Qty { get; set; }
        [DataMember(Order = 3)] [ProtoBuf.ProtoMember(3)] [LightProto.ProtoMember(3)] [Id(2)] [Key(2)]
        public virtual long PriceMinor { get; set; }
    }

    [MemoryPackable]
    [GenerateShape]
    [Serializable]
    [DataContract]
    [ProtoBuf.ProtoContract] [LightProto.ProtoContract]
    [Schema]
    public partial class Document
    {
        [DataMember(Order = 1)] [ProtoBuf.ProtoMember(1)] [LightProto.ProtoMember(1)] [Id(0)] [Key(0)]
        public virtual string Id { get; set; } = "";
        [DataMember(Order = 2)] [ProtoBuf.ProtoMember(2)] [LightProto.ProtoMember(2)] [Id(1)] [Key(1)]
        public virtual int Status { get; set; }
        [DataMember(Order = 3)] [ProtoBuf.ProtoMember(3)] [LightProto.ProtoMember(3)] [Id(2)] [Key(2)]
        public virtual DocumentMeta Meta { get; set; } = new DocumentMeta();
        [DataMember(Order = 4)] [ProtoBuf.ProtoMember(4)] [LightProto.ProtoMember(4)] [Id(3)] [Key(3)]
        public virtual List<DocumentItem> Items { get; set; } = new List<DocumentItem>();
    }

    [MemoryPackable]
    [GenerateShape]
    [Serializable]
    [DataContract]
    [ProtoBuf.ProtoContract] [LightProto.ProtoContract]
    [Schema]
    public partial class Telemetry
    {
        [DataMember(Order = 1)] [ProtoBuf.ProtoMember(1)] [LightProto.ProtoMember(1)] [Id(0)] [Key(0)]
        public virtual string Source { get; set; } = "";
        [DataMember(Order = 2)] [ProtoBuf.ProtoMember(2)] [LightProto.ProtoMember(2)] [Id(1)] [Key(1)]
        public virtual long Ts { get; set; }
        [DataMember(Order = 3)] [ProtoBuf.ProtoMember(3)] [LightProto.ProtoMember(3)] [Id(2)] [Key(2)]
        public virtual List<string> Tags { get; set; } = new List<string>();
        [DataMember(Order = 4)] [ProtoBuf.ProtoMember(4)] [LightProto.ProtoMember(4)] [Id(3)] [Key(3)]
        public virtual List<double> Values { get; set; } = new List<double>();
    }

    [MemoryPackable]
    [GenerateShape]
    [Serializable]
    [DataContract]
    [ProtoBuf.ProtoContract] [LightProto.ProtoContract]
    [Schema]
    public partial class Strings
    {
        [DataMember(Order = 1)] [ProtoBuf.ProtoMember(1)] [LightProto.ProtoMember(1)] [Id(0)] [Key(0)]
        public virtual List<string> Items { get; set; } = new List<string>();
    }

    [MemoryPackable]
    [GenerateShape]
    [Serializable]
    [DataContract]
    [ProtoBuf.ProtoContract] [LightProto.ProtoContract]
    [Schema]
    public partial class EventAttr
    {
        [DataMember(Order = 1)] [ProtoBuf.ProtoMember(1)] [LightProto.ProtoMember(1)] [Id(0)] [Key(0)]
        public virtual string Key { get; set; } = "";
        [DataMember(Order = 2)] [ProtoBuf.ProtoMember(2)] [LightProto.ProtoMember(2)] [Id(1)] [Key(1)]
        public virtual string Value { get; set; } = "";
    }

    [MemoryPackable]
    [GenerateShape]
    [Serializable]
    [DataContract]
    [ProtoBuf.ProtoContract] [LightProto.ProtoContract]
    [Schema]
    public partial class Event
    {
        [DataMember(Order = 1)] [ProtoBuf.ProtoMember(1)] [LightProto.ProtoMember(1)] [Id(0)] [Key(0)]
        public virtual string EventId { get; set; } = "";
        [DataMember(Order = 2)] [ProtoBuf.ProtoMember(2)] [LightProto.ProtoMember(2)] [Id(1)] [Key(1)]
        public virtual string EventType { get; set; } = "";
        [DataMember(Order = 3)] [ProtoBuf.ProtoMember(3)] [LightProto.ProtoMember(3)] [Id(2)] [Key(2)]
        public virtual long OccurredAt { get; set; }
        [DataMember(Order = 4)] [ProtoBuf.ProtoMember(4)] [LightProto.ProtoMember(4)] [Id(3)] [Key(3)]
        public virtual string Producer { get; set; } = "";
        [DataMember(Order = 5)] [ProtoBuf.ProtoMember(5)] [LightProto.ProtoMember(5)] [Id(4)] [Key(4)]
        public virtual List<EventAttr> Attrs { get; set; } = new List<EventAttr>();
    }

    // Batch wrappers for N>1 (root object for codecs that dislike raw List<>)
    [MemoryPackable]
    [GenerateShape]
    [Serializable]
    [DataContract]
    [ProtoBuf.ProtoContract] [LightProto.ProtoContract]
    [Schema]
    public partial class BatchMessage
    {
        [DataMember(Order = 1)] [ProtoBuf.ProtoMember(1)] [LightProto.ProtoMember(1)] [Id(0)] [Key(0)]
        public virtual List<Message> Items { get; set; } = new List<Message>();
    }

    [MemoryPackable]
    [GenerateShape]
    [Serializable]
    [DataContract]
    [ProtoBuf.ProtoContract] [LightProto.ProtoContract]
    [Schema]
    public partial class BatchDocument
    {
        [DataMember(Order = 1)] [ProtoBuf.ProtoMember(1)] [LightProto.ProtoMember(1)] [Id(0)] [Key(0)]
        public virtual List<Document> Items { get; set; } = new List<Document>();
    }

    [MemoryPackable]
    [GenerateShape]
    [Serializable]
    [DataContract]
    [ProtoBuf.ProtoContract] [LightProto.ProtoContract]
    [Schema]
    public partial class BatchTelemetry
    {
        [DataMember(Order = 1)] [ProtoBuf.ProtoMember(1)] [LightProto.ProtoMember(1)] [Id(0)] [Key(0)]
        public virtual List<Telemetry> Items { get; set; } = new List<Telemetry>();
    }

    [MemoryPackable]
    [GenerateShape]
    [Serializable]
    [DataContract]
    [ProtoBuf.ProtoContract] [LightProto.ProtoContract]
    [Schema]
    public partial class BatchStrings
    {
        [DataMember(Order = 1)] [ProtoBuf.ProtoMember(1)] [LightProto.ProtoMember(1)] [Id(0)] [Key(0)]
        public virtual List<Strings> Items { get; set; } = new List<Strings>();
    }

    [MemoryPackable]
    [GenerateShape]
    [Serializable]
    [DataContract]
    [ProtoBuf.ProtoContract] [LightProto.ProtoContract]
    [Schema]
    public partial class BatchEvent
    {
        [DataMember(Order = 1)] [ProtoBuf.ProtoMember(1)] [LightProto.ProtoMember(1)] [Id(0)] [Key(0)]
        public virtual List<Event> Items { get; set; } = new List<Event>();
    }

    // Columnar / aligned-record types. Not on the default smoke description list.
    [MemoryPackable]
    [GenerateShape]
    [Serializable]
    [DataContract]
    [ProtoBuf.ProtoContract] [LightProto.ProtoContract]
    [Schema]
    public partial class TableRow
    {
        [DataMember(Order = 1)] [ProtoBuf.ProtoMember(1)] [LightProto.ProtoMember(1)] [Id(0)] [Key(0)]
        public virtual double FFloat0 { get; set; }
        [DataMember(Order = 2)] [ProtoBuf.ProtoMember(2)] [LightProto.ProtoMember(2)] [Id(1)] [Key(1)]
        public virtual double FFloat1 { get; set; }
        [DataMember(Order = 3)] [ProtoBuf.ProtoMember(3)] [LightProto.ProtoMember(3)] [Id(2)] [Key(2)]
        public virtual double FFloat2 { get; set; }
        [DataMember(Order = 4)] [ProtoBuf.ProtoMember(4)] [LightProto.ProtoMember(4)] [Id(3)] [Key(3)]
        public virtual double FFloat3 { get; set; }
        [DataMember(Order = 5)] [ProtoBuf.ProtoMember(5)] [LightProto.ProtoMember(5)] [Id(4)] [Key(4)]
        public virtual double FFloat4 { get; set; }
        [DataMember(Order = 6)] [ProtoBuf.ProtoMember(6)] [LightProto.ProtoMember(6)] [Id(5)] [Key(5)]
        public virtual double FFloat5 { get; set; }
        [DataMember(Order = 7)] [ProtoBuf.ProtoMember(7)] [LightProto.ProtoMember(7)] [Id(6)] [Key(6)]
        public virtual double FFloat6 { get; set; }
        [DataMember(Order = 8)] [ProtoBuf.ProtoMember(8)] [LightProto.ProtoMember(8)] [Id(7)] [Key(7)]
        public virtual double FFloat7 { get; set; }
        [DataMember(Order = 9)] [ProtoBuf.ProtoMember(9)] [LightProto.ProtoMember(9)] [Id(8)] [Key(8)]
        public virtual double FFloat8 { get; set; }
        [DataMember(Order = 10)] [ProtoBuf.ProtoMember(10)] [LightProto.ProtoMember(10)] [Id(9)] [Key(9)]
        public virtual double FFloat9 { get; set; }
        [DataMember(Order = 11)] [ProtoBuf.ProtoMember(11)] [LightProto.ProtoMember(11)] [Id(10)] [Key(10)]
        public virtual double FFloat10 { get; set; }
        [DataMember(Order = 12)] [ProtoBuf.ProtoMember(12)] [LightProto.ProtoMember(12)] [Id(11)] [Key(11)]
        public virtual double FFloat11 { get; set; }
        [DataMember(Order = 13)] [ProtoBuf.ProtoMember(13)] [LightProto.ProtoMember(13)] [Id(12)] [Key(12)]
        public virtual double FFloat12 { get; set; }
        [DataMember(Order = 14)] [ProtoBuf.ProtoMember(14)] [LightProto.ProtoMember(14)] [Id(13)] [Key(13)]
        public virtual double FFloat13 { get; set; }
        [DataMember(Order = 15)] [ProtoBuf.ProtoMember(15)] [LightProto.ProtoMember(15)] [Id(14)] [Key(14)]
        public virtual double FFloat14 { get; set; }
        [DataMember(Order = 16)] [ProtoBuf.ProtoMember(16)] [LightProto.ProtoMember(16)] [Id(15)] [Key(15)]
        public virtual double FFloat15 { get; set; }
        [DataMember(Order = 17)] [ProtoBuf.ProtoMember(17)] [LightProto.ProtoMember(17)] [Id(16)] [Key(16)]
        public virtual long FInt0 { get; set; }
        [DataMember(Order = 18)] [ProtoBuf.ProtoMember(18)] [LightProto.ProtoMember(18)] [Id(17)] [Key(17)]
        public virtual long FInt1 { get; set; }
        [DataMember(Order = 19)] [ProtoBuf.ProtoMember(19)] [LightProto.ProtoMember(19)] [Id(18)] [Key(18)]
        public virtual long FInt2 { get; set; }
        [DataMember(Order = 20)] [ProtoBuf.ProtoMember(20)] [LightProto.ProtoMember(20)] [Id(19)] [Key(19)]
        public virtual long FInt3 { get; set; }
        [DataMember(Order = 21)] [ProtoBuf.ProtoMember(21)] [LightProto.ProtoMember(21)] [Id(20)] [Key(20)]
        public virtual string FStr0 { get; set; } = "";
        [DataMember(Order = 22)] [ProtoBuf.ProtoMember(22)] [LightProto.ProtoMember(22)] [Id(21)] [Key(21)]
        public virtual string FStr1 { get; set; } = "";
    }

    [MemoryPackable]
    [GenerateShape]
    [Serializable]
    [DataContract]
    [ProtoBuf.ProtoContract] [LightProto.ProtoContract]
    [Schema]
    public partial class BatchTable
    {
        [DataMember(Order = 1)] [ProtoBuf.ProtoMember(1)] [LightProto.ProtoMember(1)] [Id(0)] [Key(0)]
        public virtual List<TableRow> Items { get; set; } = new List<TableRow>();
    }

    [MemoryPackable]
    [GenerateShape]
    [Serializable]
    [DataContract]
    [ProtoBuf.ProtoContract] [LightProto.ProtoContract]
    [Schema]
    public partial class NestedMeta
    {
        [DataMember(Order = 1)] [ProtoBuf.ProtoMember(1)] [LightProto.ProtoMember(1)] [Id(0)] [Key(0)]
        public virtual string Region { get; set; } = "";
        [DataMember(Order = 2)] [ProtoBuf.ProtoMember(2)] [LightProto.ProtoMember(2)] [Id(1)] [Key(1)]
        public virtual int Version { get; set; }
    }

    [MemoryPackable]
    [GenerateShape]
    [Serializable]
    [DataContract]
    [ProtoBuf.ProtoContract] [LightProto.ProtoContract]
    [Schema]
    public partial class NestedItem
    {
        [DataMember(Order = 1)] [ProtoBuf.ProtoMember(1)] [LightProto.ProtoMember(1)] [Id(0)] [Key(0)]
        public virtual string Sku { get; set; } = "";
        [DataMember(Order = 2)] [ProtoBuf.ProtoMember(2)] [LightProto.ProtoMember(2)] [Id(1)] [Key(1)]
        public virtual int Qty { get; set; }
        [DataMember(Order = 3)] [ProtoBuf.ProtoMember(3)] [LightProto.ProtoMember(3)] [Id(2)] [Key(2)]
        public virtual long PriceMinor { get; set; }
    }

    [MemoryPackable]
    [GenerateShape]
    [Serializable]
    [DataContract]
    [ProtoBuf.ProtoContract] [LightProto.ProtoContract]
    [Schema]
    public partial class NestedRow
    {
        [DataMember(Order = 1)] [ProtoBuf.ProtoMember(1)] [LightProto.ProtoMember(1)] [Id(0)] [Key(0)]
        public virtual string Id { get; set; } = "";
        [DataMember(Order = 2)] [ProtoBuf.ProtoMember(2)] [LightProto.ProtoMember(2)] [Id(1)] [Key(1)]
        public virtual int Status { get; set; }
        [DataMember(Order = 3)] [ProtoBuf.ProtoMember(3)] [LightProto.ProtoMember(3)] [Id(2)] [Key(2)]
        public virtual NestedMeta Meta { get; set; } = new NestedMeta();
        [DataMember(Order = 4)] [ProtoBuf.ProtoMember(4)] [LightProto.ProtoMember(4)] [Id(3)] [Key(3)]
        public virtual List<NestedItem> Items { get; set; } = new List<NestedItem>();
    }

    [MemoryPackable]
    [GenerateShape]
    [Serializable]
    [DataContract]
    [ProtoBuf.ProtoContract] [LightProto.ProtoContract]
    [Schema]
    public partial class BatchNestedRow
    {
        [DataMember(Order = 1)] [ProtoBuf.ProtoMember(1)] [LightProto.ProtoMember(1)] [Id(0)] [Key(0)]
        public virtual List<NestedRow> Items { get; set; } = new List<NestedRow>();
    }

    [MemoryPackable]
    [GenerateShape]
    [Serializable]
    [DataContract]
    [ProtoBuf.ProtoContract] [LightProto.ProtoContract]
    [Schema]
    public partial class SignalLeg
    {
        [DataMember(Order = 1)] [ProtoBuf.ProtoMember(1)] [LightProto.ProtoMember(1)] [Id(0)] [Key(0)]
        public virtual long LegId { get; set; }
        [DataMember(Order = 2)] [ProtoBuf.ProtoMember(2)] [LightProto.ProtoMember(2)] [Id(1)] [Key(1)]
        public virtual int LegQty { get; set; }
        [DataMember(Order = 3)] [ProtoBuf.ProtoMember(3)] [LightProto.ProtoMember(3)] [Id(2)] [Key(2)]
        public virtual int LegPad { get; set; }
    }

    [MemoryPackable]
    [GenerateShape]
    [Serializable]
    [DataContract]
    [ProtoBuf.ProtoContract] [LightProto.ProtoContract]
    [Schema]
    public partial class Signal
    {
        [DataMember(Order = 1)] [ProtoBuf.ProtoMember(1)] [LightProto.ProtoMember(1)] [Id(0)] [Key(0)]
        public virtual long Seq { get; set; }
        [DataMember(Order = 2)] [ProtoBuf.ProtoMember(2)] [LightProto.ProtoMember(2)] [Id(1)] [Key(1)]
        public virtual long Ts { get; set; }
        [DataMember(Order = 3)] [ProtoBuf.ProtoMember(3)] [LightProto.ProtoMember(3)] [Id(2)] [Key(2)]
        public virtual long PriceMantissa { get; set; }
        [DataMember(Order = 4)] [ProtoBuf.ProtoMember(4)] [LightProto.ProtoMember(4)] [Id(3)] [Key(3)]
        public virtual int Qty { get; set; }
        [DataMember(Order = 5)] [ProtoBuf.ProtoMember(5)] [LightProto.ProtoMember(5)] [Id(4)] [Key(4)]
        public virtual int Flags { get; set; }
        [DataMember(Order = 6)] [ProtoBuf.ProtoMember(6)] [LightProto.ProtoMember(6)] [Id(5)] [Key(5)]
        public virtual string Symbol { get; set; } = "";
        [DataMember(Order = 7)] [ProtoBuf.ProtoMember(7)] [LightProto.ProtoMember(7)] [Id(6)] [Key(6)]
        public virtual string Venue { get; set; } = "";
        [DataMember(Order = 8)] [ProtoBuf.ProtoMember(8)] [LightProto.ProtoMember(8)] [Id(7)] [Key(7)]
        public virtual List<SignalLeg> Legs { get; set; } = new List<SignalLeg>();
    }

    [MemoryPackable]
    [GenerateShape]
    [Serializable]
    [DataContract]
    [ProtoBuf.ProtoContract] [LightProto.ProtoContract]
    [Schema]
    public partial class BatchSignal
    {
        [DataMember(Order = 1)] [ProtoBuf.ProtoMember(1)] [LightProto.ProtoMember(1)] [Id(0)] [Key(0)]
        public virtual List<Signal> Items { get; set; } = new List<Signal>();
    }

    /// <summary>Dense float64 array. Values are catalog order, index y * nx + x.</summary>
    public sealed class Grid
    {
        public int Nx { get; set; }
        public int Ny { get; set; }
        public int X0 { get; set; }
        public int Y0 { get; set; }
        public int Wx { get; set; }
        public int Wy { get; set; }
        public double[] Values { get; set; } = System.Array.Empty<double>();

        public double[] WindowValues()
        {
            var outv = new double[Wx * Wy];
            var i = 0;
            for (var y = Y0; y < Y0 + Wy; y++)
            {
                var row = y * Nx;
                for (var x = X0; x < X0 + Wx; x++)
                    outv[i++] = Values[row + x];
            }
            return outv;
        }
    }
}
