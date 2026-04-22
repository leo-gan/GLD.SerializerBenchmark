using System;
using System.Collections.Generic;
using FlatSharp.Attributes;

namespace GLD.SerializerBenchmark.FShrp
{
    [FlatBufferTable]
    public class SimpleObject
    {
        [FlatBufferItem(0)]
        public virtual int Id { get; set; }
        [FlatBufferItem(1)]
        public virtual string Name { get; set; }
        [FlatBufferItem(2)]
        public virtual long Timestamp { get; set; }
        [FlatBufferItem(3)]
        public virtual bool IsActive { get; set; }
    }

    [FlatBufferTable]
    public class StringArrayObject
    {
        [FlatBufferItem(0)]
        public virtual IList<string> Items { get; set; }
    }

    [FlatBufferTable]
    public class IntObject
    {
        [FlatBufferItem(0)]
        public virtual int Value { get; set; }
    }
}
