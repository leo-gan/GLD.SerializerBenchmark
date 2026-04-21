using System;
using System.Collections.Generic;
using System.Runtime.Serialization;
using ProtoBuf;
// Bond doesn't support circular references well, so we might exclude it from Bond using attributes if needed, 
// but for standard POCOs we keep it simple.

namespace GLD.SerializerBenchmark.TestData
{
    public class ObjectGraphDescription : ITestDataDescription
    {
        private readonly GraphNode _data;

        public ObjectGraphDescription()
        {
            // Build a small graph with a circular reference
            var root = new GraphNode { Name = "Root" };
            var child1 = new GraphNode { Name = "Child1", Parent = root };
            var child2 = new GraphNode { Name = "Child2", Parent = root };
            root.Children.Add(child1);
            root.Children.Add(child2);
            
            // Circularity: Child points back to root (already done) 
            // and Child1 points to Child2 and vice versa
            child1.Related = child2;
            child2.Related = child1;

            _data = root;
        }

        public string Name => "ObjectGraph";
        public string Description => "Tests handling of circular references and complex object graphs.";
        public Type DataType => typeof(GraphNode);
        public List<Type> SecondaryDataTypes => new List<Type> { typeof(List<GraphNode>) };
        public object Data => _data;
    }

    [ProtoContract(AsReferenceDefault = true)]
    [DataContract(IsReference = true)]
    [Serializable]
    public class GraphNode
    {
        [ProtoMember(1)] [DataMember] public string Name { get; set; }
        
        [ProtoMember(2)] [DataMember] public GraphNode Parent { get; set; }
        
        [ProtoMember(3)] [DataMember] public List<GraphNode> Children { get; set; } = new List<GraphNode>();
        
        [ProtoMember(4)] [DataMember] public GraphNode Related { get; set; }
    }
}
