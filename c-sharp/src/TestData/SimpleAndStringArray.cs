// V2 payload proxies: message/event → SimpleObject, strings → StringArrayObject.
// V1 fixture descriptions (SimpleObject / StringArray names) removed.
using System;
using System.Collections.Generic;
using System.Runtime.Serialization;
using ProtoBuf;
using Bond;

namespace GLD.SerializerBenchmark.TestData
{
    [ProtoContract]
    [DataContract]
    [Serializable]
    [Schema]
    public class SimpleObject
    {
        public SimpleObject() { }

        [ProtoMember(1)] [DataMember] [Id(0)] public int Id { get; set; }
        [ProtoMember(2)] [DataMember] [Id(1)] public string Name { get; set; }
        [ProtoMember(3)] [DataMember] [Id(2), Type(typeof(long))] public DateTime Timestamp { get; set; }
        [ProtoMember(4)] [DataMember] [Id(3)] public bool IsActive { get; set; }
    }

    [ProtoContract]
    [DataContract]
    [Serializable]
    [Schema]
    public class StringArrayObject
    {
        public StringArrayObject() { }

        [ProtoMember(1)] [DataMember] [Id(0)] public List<string> Items { get; set; }

        public static StringArrayObject Generate(int count)
        {
            var items = new List<string>(count);
            for (int i = 0; i < count; i++)
                items.Add(Randomizer.Phrase);
            return new StringArrayObject { Items = items };
        }
    }
}
