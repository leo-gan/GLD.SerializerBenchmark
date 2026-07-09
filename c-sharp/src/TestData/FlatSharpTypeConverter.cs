using System;
using System.Collections.Generic;
using System.Linq;

namespace GLD.SerializerBenchmark.TestData
{
    public static class FlatSharpTypeConverter
    {
        public static FShrp.SimpleObject ToFlatSharp(SimpleObject obj)
        {
            if (obj == null) return null;
            return new FShrp.SimpleObject
            {
                Id = obj.Id,
                Name = obj.Name,
                Timestamp = obj.Timestamp.ToBinary(),
                IsActive = obj.IsActive
            };
        }

        public static SimpleObject FromFlatSharp(FShrp.SimpleObject obj)
        {
            if (obj == null) return null;
            return new SimpleObject
            {
                Id = obj.Id,
                Name = obj.Name,
                Timestamp = DateTime.FromBinary(obj.Timestamp),
                IsActive = obj.IsActive
            };
        }

        public static FShrp.StringArrayObject ToFlatSharp(StringArrayObject obj)
        {
            if (obj == null) return null;
            return new FShrp.StringArrayObject { Items = obj.Items.ToList() };
        }

        public static StringArrayObject FromFlatSharp(FShrp.StringArrayObject obj)
        {
            if (obj == null) return null;
            return new StringArrayObject { Items = obj.Items.ToList() };
        }

        public static FShrp.IntObject ToFlatSharp(int value)
        {
            return new FShrp.IntObject { Value = value };
        }

        public static int FromFlatSharp(FShrp.IntObject obj)
        {
            return obj?.Value ?? 0;
        }

        public static FShrp.ObjectGraph ToFlatSharp(ObjectGraph obj)
        {
            if (obj == null) return null;
            return new FShrp.ObjectGraph
            {
                Root = obj.Root,
                Nodes = obj.Nodes?.Select(n => new FShrp.GraphNodeData
                {
                    Name = n.Name,
                    Parent = n.Parent,
                    Related = n.Related,
                    Children = n.Children?.ToList() ?? new List<int>()
                }).ToList() ?? new List<FShrp.GraphNodeData>()
            };
        }

        public static ObjectGraph FromFlatSharp(FShrp.ObjectGraph obj)
        {
            if (obj == null) return null;
            return new ObjectGraph
            {
                Root = obj.Root,
                Nodes = obj.Nodes?.Select(n => new GraphNodeData
                {
                    Name = n.Name,
                    Parent = n.Parent,
                    Related = n.Related,
                    Children = n.Children?.ToList() ?? new List<int>()
                }).ToList() ?? new List<GraphNodeData>()
            };
        }
    }
}
