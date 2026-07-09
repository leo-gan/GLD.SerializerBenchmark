using System;
using System.Collections.Generic;
using MemoryPack;

namespace GLD.SerializerBenchmark.MPack
{
    [MemoryPackable]
    public partial class SimpleObject
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public DateTime Timestamp { get; set; }
        public bool IsActive { get; set; }
    }

    [MemoryPackable]
    public partial class StringArrayObject
    {
        public List<string> Items { get; set; }
    }

    [MemoryPackable]
    public partial class IntObject
    {
        public int Value { get; set; }
    }

    [MemoryPackable]
    public partial class GraphNodeData
    {
        public string Name { get; set; }
        public int Parent { get; set; }
        public int Related { get; set; }
        public List<int> Children { get; set; }
    }

    [MemoryPackable]
    public partial class ObjectGraph
    {
        public int Root { get; set; }
        public List<GraphNodeData> Nodes { get; set; }
    }
}
