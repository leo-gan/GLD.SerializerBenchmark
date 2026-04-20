using System;
using System.Collections.Generic;
using System.Runtime.Serialization;
using ProtoBuf;
using Bond;

namespace GLD.SerializerBenchmark.TestData
{
    public class SimpleObjectDescription : ITestDataDescription
    {
        private readonly SimpleObject _data = new SimpleObject
        {
            Id = 12345,
            Name = "Simple Benchmark Object",
            Timestamp = DateTime.UtcNow,
            IsActive = true
        };

        public string Name => "SimpleObject";
        public string Description => "Minimal overhead test: a few basic properties.";
        public Type DataType => typeof(SimpleObject);
        public List<Type> SecondaryDataTypes => new List<Type>();
        public object Data => _data;
    }

    [ProtoContract]
    [DataContract]
    [Serializable]
    [Schema]
    public class SimpleObject
    {
        [ProtoMember(1)] [DataMember] [Id(0)] public int Id { get; set; }
        [ProtoMember(2)] [DataMember] [Id(1)] public string Name { get; set; }
        [ProtoMember(3)] [DataMember] [Id(2)] public DateTime Timestamp { get; set; }
        [ProtoMember(4)] [DataMember] [Id(3)] public bool IsActive { get; set; }
    }

    public class StringArrayDescription : ITestDataDescription
    {
        private readonly StringArrayObject _data = StringArrayObject.Generate(100);

        public string Name => "StringArray";
        public string Description => "Tests memory allocation and string handling with an array of many strings.";
        public Type DataType => typeof(StringArrayObject);
        public List<Type> SecondaryDataTypes => new List<Type>();
        public object Data => _data;
    }

    [ProtoContract]
    [DataContract]
    [Serializable]
    [Schema]
    public class StringArrayObject
    {
        [ProtoMember(1)] [DataMember] [Id(0)] public string[] Items { get; set; }

        public static StringArrayObject Generate(int count)
        {
            var items = new string[count];
            for (int i = 0; i < count; i++)
                items[i] = "Item_" + i + "_" + Guid.NewGuid().ToString().Substring(0, 8);
            return new StringArrayObject { Items = items };
        }
    }
}
