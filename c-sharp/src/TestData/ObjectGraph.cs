using System;
using System.Collections.Generic;
using System.Runtime.Serialization;
using Bond;
using ProtoBuf;

namespace GLD.SerializerBenchmark.TestData
{
    /// <summary>
    /// Portable ObjectGraph: flat node table + integer edges (same model as C/Rust/JS/Python/Go).
    /// Cycles are encoded as indices, not live parent pointers — every capable codec can serialize it.
    /// </summary>
    public class ObjectGraphDescription : ITestDataDescription
    {
        public const int GraphNull = -1;

        private readonly ObjectGraph _data;

        public ObjectGraphDescription()
        {
            _data = new ObjectGraph
            {
                Root = 0,
                Nodes = new List<GraphNodeData>
                {
                    new GraphNodeData
                    {
                        Name = "Root",
                        Parent = GraphNull,
                        Related = GraphNull,
                        Children = new List<int> { 1, 2 }
                    },
                    new GraphNodeData
                    {
                        Name = "Child1",
                        Parent = 0,
                        Related = 2,
                        Children = new List<int>()
                    },
                    new GraphNodeData
                    {
                        Name = "Child2",
                        Parent = 0,
                        Related = 1,
                        Children = new List<int>()
                    }
                }
            };
        }

        public string Name => "ObjectGraph";
        public string Description =>
            "Flat object graph with circular topology encoded via integer node indices (portable).";
        public Type DataType => typeof(ObjectGraph);
        public List<Type> SecondaryDataTypes => new List<Type> { typeof(GraphNodeData), typeof(List<GraphNodeData>), typeof(List<int>) };
        public object Data => _data;
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class GraphNodeData
    {
        [ProtoMember(1)]
        [DataMember]
        [Id(0)]
        public string Name { get; set; }

        /// <summary>Parent node index, or <see cref="ObjectGraphDescription.GraphNull"/>.</summary>
        [ProtoMember(2)]
        [DataMember]
        [Id(1)]
        public int Parent { get; set; } = ObjectGraphDescription.GraphNull;

        /// <summary>Related node index, or <see cref="ObjectGraphDescription.GraphNull"/>.</summary>
        [ProtoMember(3)]
        [DataMember]
        [Id(2)]
        public int Related { get; set; } = ObjectGraphDescription.GraphNull;

        [ProtoMember(4)]
        [DataMember]
        [Id(3)]
        public List<int> Children { get; set; } = new List<int>();
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class ObjectGraph
    {
        [ProtoMember(1)]
        [DataMember]
        [Id(0)]
        public int Root { get; set; }

        [ProtoMember(2)]
        [DataMember]
        [Id(1)]
        public List<GraphNodeData> Nodes { get; set; } = new List<GraphNodeData>();
    }
}
