using System;
using System.Collections.Generic;
using ZeroFormatter;

namespace GLD.SerializerBenchmark.ZFmt
{
    [ZeroFormattable]
    public class SimpleObject
    {
        [Index(0)]
        public virtual int Id { get; set; }
        [Index(1)]
        public virtual string Name { get; set; }
        [Index(2)]
        public virtual DateTime Timestamp { get; set; }
        [Index(3)]
        public virtual bool IsActive { get; set; }
    }

    [ZeroFormattable]
    public class StringArrayObject
    {
        [Index(0)]
        public virtual IList<string> Items { get; set; }
    }

    [ZeroFormattable]
    public class IntObject
    {
        [Index(0)]
        public virtual int Value { get; set; }
    }

    [ZeroFormattable]
    public class GraphNodeData
    {
        [Index(0)]
        public virtual string Name { get; set; }
        [Index(1)]
        public virtual int Parent { get; set; }
        [Index(2)]
        public virtual int Related { get; set; }
        [Index(3)]
        public virtual IList<int> Children { get; set; }
    }

    [ZeroFormattable]
    public class ObjectGraph
    {
        [Index(0)]
        public virtual int Root { get; set; }
        [Index(1)]
        public virtual IList<GraphNodeData> Nodes { get; set; }
    }
}
