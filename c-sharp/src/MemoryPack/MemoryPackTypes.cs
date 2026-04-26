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
}
