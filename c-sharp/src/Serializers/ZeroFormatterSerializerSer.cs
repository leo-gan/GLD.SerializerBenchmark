using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using GLD.SerializerBenchmark.TestData;
using ZeroFormatter;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    /// ZeroFormatter on modern .NET (Core/5+/8) cannot dynamically emit formatters for
    /// <c>[ZeroFormattable]</c> classes (BadImageFormatException / Bad IL). Built-in
    /// formatters (primitives, arrays, lists, <see cref="KeyTuple"/>) still work.
    ///
    /// Strategy: map suite fixtures to built-in-serializable shapes, then convert back
    /// for fidelity comparison against the original POCOs / primitives.
    /// Supported fixtures: Integer, SimpleObject, StringArray, ObjectGraph (flat index edges).
    /// </summary>
    internal class ZeroFormatterSerializerSer : SerDeser
    {
        public override string Name => "ZeroFormatter";

        public override bool Supports(string testDataName) =>
            testDataName is "Integer" or "SimpleObject" or "StringArray" or "ObjectGraph";

        public override string Serialize(object serializable) =>
            Convert.ToBase64String(SerializeBytes(serializable));

        public override object Deserialize(string serialized) =>
            DeserializeBytes(Convert.FromBase64String(serialized));

        public override void Serialize(object serializable, Stream outputStream)
        {
            var bytes = SerializeBytes(serializable);
            outputStream.Write(bytes, 0, bytes.Length);
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            using var ms = new MemoryStream();
            inputStream.CopyTo(ms);
            return DeserializeBytes(ms.ToArray());
        }

        private byte[] SerializeBytes(object serializable)
        {
            if (serializable == null)
                throw new ArgumentNullException(nameof(serializable));

            if (_primaryType == typeof(int))
            {
                // Built-in int formatter (no dynamic object segment).
                return ZeroFormatterSerializer.Serialize((int)serializable);
            }

            if (_primaryType == typeof(SimpleObject))
            {
                var o = (SimpleObject)serializable;
                // KeyTuple uses maintained built-in formatters on net8.
                var tuple = KeyTuple.Create(o.Id, o.Name ?? "", o.Timestamp, o.IsActive);
                return ZeroFormatterSerializer.Serialize(tuple);
            }

            if (_primaryType == typeof(StringArrayObject))
            {
                var o = (StringArrayObject)serializable;
                var items = o.Items != null ? o.Items.ToList() : new List<string>();
                return ZeroFormatterSerializer.Serialize(items);
            }

            if (_primaryType == typeof(ObjectGraph))
            {
                var g = (ObjectGraph)serializable;
                // Built-in formatters only: root + nodes as KeyTuple rows (name, parent, related, children).
                var nodes = (g.Nodes ?? new List<GraphNodeData>())
                    .Select(n => KeyTuple.Create(
                        n.Name ?? "",
                        n.Parent,
                        n.Related,
                        n.Children != null ? n.Children.ToList() : new List<int>()))
                    .ToList();
                var payload = KeyTuple.Create(g.Root, nodes);
                return ZeroFormatterSerializer.Serialize(payload);
            }

            throw new NotSupportedException(
                $"ZeroFormatter does not support primary type {_primaryType?.FullName ?? "(null)"}.");
        }

        private object DeserializeBytes(byte[] bytes)
        {
            if (_primaryType == typeof(int))
                return ZeroFormatterSerializer.Deserialize<int>(bytes);

            if (_primaryType == typeof(SimpleObject))
            {
                var tuple = ZeroFormatterSerializer.Deserialize<KeyTuple<int, string, DateTime, bool>>(bytes);
                return new SimpleObject
                {
                    Id = tuple.Item1,
                    Name = tuple.Item2,
                    Timestamp = tuple.Item3,
                    IsActive = tuple.Item4
                };
            }

            if (_primaryType == typeof(StringArrayObject))
            {
                var items = ZeroFormatterSerializer.Deserialize<List<string>>(bytes);
                return new StringArrayObject { Items = items };
            }

            if (_primaryType == typeof(ObjectGraph))
            {
                var payload = ZeroFormatterSerializer
                    .Deserialize<KeyTuple<int, List<KeyTuple<string, int, int, List<int>>>>>(bytes);
                return new ObjectGraph
                {
                    Root = payload.Item1,
                    Nodes = (payload.Item2 ?? new List<KeyTuple<string, int, int, List<int>>>())
                        .Select(n => new GraphNodeData
                        {
                            Name = n.Item1,
                            Parent = n.Item2,
                            Related = n.Item3,
                            Children = n.Item4 ?? new List<int>()
                        }).ToList()
                };
            }

            throw new NotSupportedException(
                $"ZeroFormatter does not support primary type {_primaryType?.FullName ?? "(null)"}.");
        }
    }
}
