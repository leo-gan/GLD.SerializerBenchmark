using System;
using System.Collections.Generic;
using FlatSharp.Attributes;

namespace GLD.SerializerBenchmark.FShrp
{
    [FlatBufferTable]
    public class SimpleObject
    {
        [FlatBufferItem(0)]
        public int Id { get; set; }
        [FlatBufferItem(1)]
        public string Name { get; set; }
        [FlatBufferItem(2)]
        public long Timestamp { get; set; }
        [FlatBufferItem(3)]
        public bool IsActive { get; set; }
    }

    [FlatBufferTable]
    public class StringArrayObject
    {
        [FlatBufferItem(0)]
        public IList<string> Items { get; set; }
    }

    [FlatBufferTable]
    public class IntObject
    {
        [FlatBufferItem(0)]
        public int Value { get; set; }
    }
}
