// Data Model v2 domain types — sole suite payload types for the C# benchmark runner.
// Shape matches schemas/data_catalog_v2.yaml, python data_v2.models, and benchmark_v2.proto.
using System;
using System.Collections.Generic;
using System.Runtime.Serialization;
using Bond;
using MemoryPack;
using ProtoBuf;

namespace GLD.SerializerBenchmark.TestData.V2
{
    [MemoryPackable]
    [Serializable]
    [DataContract]
    [ProtoContract]
    [Schema]
    public partial class Message
    {
        [DataMember(Order = 1)] [ProtoMember(1)] [Id(0)]
        public virtual bool FBool { get; set; }
        [DataMember(Order = 2)] [ProtoMember(2)] [Id(1)]
        public virtual int FInt32 { get; set; }
        [DataMember(Order = 3)] [ProtoMember(3)] [Id(2)]
        public virtual long FInt64 { get; set; }
        [DataMember(Order = 4)] [ProtoMember(4)] [Id(3)]
        public virtual double FFloat64 { get; set; }
        [DataMember(Order = 5)] [ProtoMember(5)] [Id(4)]
        public virtual string FString { get; set; } = "";
        [DataMember(Order = 6)] [ProtoMember(6)] [Id(5)]
        public virtual bool FBool2 { get; set; }
        [DataMember(Order = 7)] [ProtoMember(7)] [Id(6)]
        public virtual int FInt322 { get; set; }
        [DataMember(Order = 8)] [ProtoMember(8)] [Id(7)]
        public virtual string FString2 { get; set; } = "";
    }

    [MemoryPackable]
    [Serializable]
    [DataContract]
    [ProtoContract]
    [Schema]
    public partial class DocumentMeta
    {
        [DataMember(Order = 1)] [ProtoMember(1)] [Id(0)]
        public virtual string Region { get; set; } = "";
        [DataMember(Order = 2)] [ProtoMember(2)] [Id(1)]
        public virtual int Version { get; set; }
    }

    [MemoryPackable]
    [Serializable]
    [DataContract]
    [ProtoContract]
    [Schema]
    public partial class DocumentItem
    {
        [DataMember(Order = 1)] [ProtoMember(1)] [Id(0)]
        public virtual string Sku { get; set; } = "";
        [DataMember(Order = 2)] [ProtoMember(2)] [Id(1)]
        public virtual int Qty { get; set; }
        [DataMember(Order = 3)] [ProtoMember(3)] [Id(2)]
        public virtual long PriceMinor { get; set; }
    }

    [MemoryPackable]
    [Serializable]
    [DataContract]
    [ProtoContract]
    [Schema]
    public partial class Document
    {
        [DataMember(Order = 1)] [ProtoMember(1)] [Id(0)]
        public virtual string Id { get; set; } = "";
        [DataMember(Order = 2)] [ProtoMember(2)] [Id(1)]
        public virtual int Status { get; set; }
        [DataMember(Order = 3)] [ProtoMember(3)] [Id(2)]
        public virtual DocumentMeta Meta { get; set; } = new DocumentMeta();
        [DataMember(Order = 4)] [ProtoMember(4)] [Id(3)]
        public virtual List<DocumentItem> Items { get; set; } = new List<DocumentItem>();
    }

    [MemoryPackable]
    [Serializable]
    [DataContract]
    [ProtoContract]
    [Schema]
    public partial class Telemetry
    {
        [DataMember(Order = 1)] [ProtoMember(1)] [Id(0)]
        public virtual string Source { get; set; } = "";
        [DataMember(Order = 2)] [ProtoMember(2)] [Id(1)]
        public virtual long Ts { get; set; }
        [DataMember(Order = 3)] [ProtoMember(3)] [Id(2)]
        public virtual List<string> Tags { get; set; } = new List<string>();
        [DataMember(Order = 4)] [ProtoMember(4)] [Id(3)]
        public virtual List<double> Values { get; set; } = new List<double>();
    }

    [MemoryPackable]
    [Serializable]
    [DataContract]
    [ProtoContract]
    [Schema]
    public partial class Strings
    {
        [DataMember(Order = 1)] [ProtoMember(1)] [Id(0)]
        public virtual List<string> Items { get; set; } = new List<string>();
    }

    [MemoryPackable]
    [Serializable]
    [DataContract]
    [ProtoContract]
    [Schema]
    public partial class EventAttr
    {
        [DataMember(Order = 1)] [ProtoMember(1)] [Id(0)]
        public virtual string Key { get; set; } = "";
        [DataMember(Order = 2)] [ProtoMember(2)] [Id(1)]
        public virtual string Value { get; set; } = "";
    }

    [MemoryPackable]
    [Serializable]
    [DataContract]
    [ProtoContract]
    [Schema]
    public partial class Event
    {
        [DataMember(Order = 1)] [ProtoMember(1)] [Id(0)]
        public virtual string EventId { get; set; } = "";
        [DataMember(Order = 2)] [ProtoMember(2)] [Id(1)]
        public virtual string EventType { get; set; } = "";
        [DataMember(Order = 3)] [ProtoMember(3)] [Id(2)]
        public virtual long OccurredAt { get; set; }
        [DataMember(Order = 4)] [ProtoMember(4)] [Id(3)]
        public virtual string Producer { get; set; } = "";
        [DataMember(Order = 5)] [ProtoMember(5)] [Id(4)]
        public virtual List<EventAttr> Attrs { get; set; } = new List<EventAttr>();
    }

    // Batch wrappers for N>1 (root object for codecs that dislike raw List<>)
    [MemoryPackable]
    [Serializable]
    [DataContract]
    [ProtoContract]
    [Schema]
    public partial class BatchMessage
    {
        [DataMember(Order = 1)] [ProtoMember(1)] [Id(0)]
        public virtual List<Message> Items { get; set; } = new List<Message>();
    }

    [MemoryPackable]
    [Serializable]
    [DataContract]
    [ProtoContract]
    [Schema]
    public partial class BatchDocument
    {
        [DataMember(Order = 1)] [ProtoMember(1)] [Id(0)]
        public virtual List<Document> Items { get; set; } = new List<Document>();
    }

    [MemoryPackable]
    [Serializable]
    [DataContract]
    [ProtoContract]
    [Schema]
    public partial class BatchTelemetry
    {
        [DataMember(Order = 1)] [ProtoMember(1)] [Id(0)]
        public virtual List<Telemetry> Items { get; set; } = new List<Telemetry>();
    }

    [MemoryPackable]
    [Serializable]
    [DataContract]
    [ProtoContract]
    [Schema]
    public partial class BatchStrings
    {
        [DataMember(Order = 1)] [ProtoMember(1)] [Id(0)]
        public virtual List<Strings> Items { get; set; } = new List<Strings>();
    }

    [MemoryPackable]
    [Serializable]
    [DataContract]
    [ProtoContract]
    [Schema]
    public partial class BatchEvent
    {
        [DataMember(Order = 1)] [ProtoMember(1)] [Id(0)]
        public virtual List<Event> Items { get; set; } = new List<Event>();
    }
}
