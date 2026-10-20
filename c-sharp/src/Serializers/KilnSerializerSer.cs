using System;
using System.Buffers.Binary;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using Kiln;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    /// gld-kiln 0.2.0 positional wire for the five suite types and the tensor set.
    /// Field order is the wire order (no names). A batch is one list of the struct;
    /// one instance is the struct. Schema and kiln values are built in Initialize /
    /// PrepareData. <see cref="Writer.Encode"/> reuses one buffer.
    /// tensor_view decode returns a span of the payload bytes and does not copy the matrix.
    /// https://github.com/leo-gan/gld-kiln-csharp
    /// </summary>
    internal class KilnSerializerSer : SerDeser
    {
        enum Kind { Bool, I32, I64, F32, F64, Str, Struct, ListStr, ListF64, ListF32, ListI64, ListStruct }

        sealed class Node
        {
            public string Key;
            public string Prop;
            public Kind Kind;
            public Node[] Fields;

            public static Node Scalar(string key, string prop, Kind kind) =>
                new Node { Key = key, Prop = prop, Kind = kind };

            public static Node Struct(string key, string prop, Node[] fields) =>
                new Node { Key = key, Prop = prop, Kind = Kind.Struct, Fields = fields };

            public static Node ListOf(string key, string prop, Kind kind, Node[] fields = null) =>
                new Node { Key = key, Prop = prop, Kind = kind, Fields = fields };
        }

        sealed class Bound
        {
            public string Key;
            public PropertyInfo Prop;
            public Kind Kind;
            public Type ElemType;
            public Bound[] Children;
        }

        static readonly Schema MetaSchema = Schema.Struct(new[]
        {
            new SchemaField("region", Schema.Str),
            new SchemaField("version", Schema.I32),
        });

        static readonly Schema ItemSchema = Schema.Struct(new[]
        {
            new SchemaField("sku", Schema.Str),
            new SchemaField("qty", Schema.I32),
            new SchemaField("price_minor", Schema.I64),
        });

        static readonly Schema AttrSchema = Schema.Struct(new[]
        {
            new SchemaField("key", Schema.Str),
            new SchemaField("value", Schema.Str),
        });

        static readonly Schema MessageSchema = Schema.Struct(new[]
        {
            new SchemaField("f_bool", Schema.Bool),
            new SchemaField("f_int32", Schema.I32),
            new SchemaField("f_int64", Schema.I64),
            new SchemaField("f_float64", Schema.F64),
            new SchemaField("f_string", Schema.Str),
            new SchemaField("f_bool_2", Schema.Bool),
            new SchemaField("f_int32_2", Schema.I32),
            new SchemaField("f_string_2", Schema.Str),
        });

        static readonly Schema DocumentSchema = Schema.Struct(new[]
        {
            new SchemaField("id", Schema.Str),
            new SchemaField("status", Schema.I32),
            new SchemaField("meta", MetaSchema),
            new SchemaField("items", Schema.List(ItemSchema)),
        });

        static readonly Schema TelemetrySchema = Schema.Struct(new[]
        {
            new SchemaField("source", Schema.Str),
            new SchemaField("ts", Schema.I64),
            new SchemaField("tags", Schema.List(Schema.Str)),
            new SchemaField("values", Schema.List(Schema.F64)),
        });

        static readonly Schema StringsSchema = Schema.Struct(new[]
        {
            new SchemaField("items", Schema.List(Schema.Str)),
        });

        static readonly Schema EventSchema = Schema.Struct(new[]
        {
            new SchemaField("event_id", Schema.Str),
            new SchemaField("event_type", Schema.Str),
            new SchemaField("occurred_at", Schema.I64),
            new SchemaField("producer", Schema.Str),
            new SchemaField("attrs", Schema.List(AttrSchema)),
        });

        static readonly Schema TensorSchema = Schema.Struct(new[]
        {
            new SchemaField("rows", Schema.I32),
            new SchemaField("cols", Schema.I32),
            new SchemaField("values", Schema.List(Schema.F32)),
        });

        static readonly Schema PromptSchema = Schema.Struct(new[]
        {
            new SchemaField("batch", Schema.I32),
            new SchemaField("seq", Schema.I32),
            new SchemaField("input_ids", Schema.List(Schema.I64)),
            new SchemaField("attention_mask", Schema.List(Schema.I64)),
            new SchemaField("position_ids", Schema.List(Schema.I64)),
        });

        static readonly Schema ShardSchema = Schema.Struct(new[]
        {
            new SchemaField("vocab", Schema.I32),
            new SchemaField("hidden", Schema.I32),
            new SchemaField("ffn", Schema.I32),
            new SchemaField("tok_emb", Schema.List(Schema.F32)),
            new SchemaField("attn", Schema.List(Schema.F32)),
            new SchemaField("ffn_weight", Schema.List(Schema.F32)),
            new SchemaField("norm", Schema.List(Schema.F32)),
        });

        static readonly Schema RequestSchema = Schema.Struct(new[]
        {
            new SchemaField("request_id", Schema.I64),
            new SchemaField("model", Schema.Str),
            new SchemaField("temperature", Schema.F32),
            new SchemaField("inputs", PromptSchema),
        });

        static readonly Dictionary<string, Schema> StructByName = new Dictionary<string, Schema>(StringComparer.Ordinal)
        {
            ["message"] = MessageSchema,
            ["document"] = DocumentSchema,
            ["telemetry"] = TelemetrySchema,
            ["strings"] = StringsSchema,
            ["event"] = EventSchema,
            ["tensor"] = TensorSchema,
            ["prompt"] = PromptSchema,
            ["shard"] = ShardSchema,
            ["request"] = RequestSchema,
        };

        static readonly Dictionary<string, Schema> ListByName = new Dictionary<string, Schema>(StringComparer.Ordinal)
        {
            ["message"] = Schema.List(MessageSchema),
            ["document"] = Schema.List(DocumentSchema),
            ["telemetry"] = Schema.List(TelemetrySchema),
            ["strings"] = Schema.List(StringsSchema),
            ["event"] = Schema.List(EventSchema),
        };

        static readonly Node[] MetaNodes =
        {
            Node.Scalar("region", "Region", Kind.Str),
            Node.Scalar("version", "Version", Kind.I32),
        };

        static readonly Node[] ItemNodes =
        {
            Node.Scalar("sku", "Sku", Kind.Str),
            Node.Scalar("qty", "Qty", Kind.I32),
            Node.Scalar("price_minor", "PriceMinor", Kind.I64),
        };

        static readonly Node[] AttrNodes =
        {
            Node.Scalar("key", "Key", Kind.Str),
            Node.Scalar("value", "Value", Kind.Str),
        };

        static readonly Node[] PromptNodes =
        {
            Node.Scalar("batch", "Batch", Kind.I32),
            Node.Scalar("seq", "Seq", Kind.I32),
            Node.ListOf("input_ids", "InputIds", Kind.ListI64),
            Node.ListOf("attention_mask", "AttentionMask", Kind.ListI64),
            Node.ListOf("position_ids", "PositionIds", Kind.ListI64),
        };

        static readonly Dictionary<string, Node[]> NodesByName = new Dictionary<string, Node[]>(StringComparer.Ordinal)
        {
            ["message"] = new[]
            {
                Node.Scalar("f_bool", "FBool", Kind.Bool),
                Node.Scalar("f_int32", "FInt32", Kind.I32),
                Node.Scalar("f_int64", "FInt64", Kind.I64),
                Node.Scalar("f_float64", "FFloat64", Kind.F64),
                Node.Scalar("f_string", "FString", Kind.Str),
                Node.Scalar("f_bool_2", "FBool2", Kind.Bool),
                Node.Scalar("f_int32_2", "FInt322", Kind.I32),
                Node.Scalar("f_string_2", "FString2", Kind.Str),
            },
            ["document"] = new[]
            {
                Node.Scalar("id", "Id", Kind.Str),
                Node.Scalar("status", "Status", Kind.I32),
                Node.Struct("meta", "Meta", MetaNodes),
                Node.ListOf("items", "Items", Kind.ListStruct, ItemNodes),
            },
            ["telemetry"] = new[]
            {
                Node.Scalar("source", "Source", Kind.Str),
                Node.Scalar("ts", "Ts", Kind.I64),
                Node.ListOf("tags", "Tags", Kind.ListStr),
                Node.ListOf("values", "Values", Kind.ListF64),
            },
            ["strings"] = new[]
            {
                Node.ListOf("items", "Items", Kind.ListStr),
            },
            ["event"] = new[]
            {
                Node.Scalar("event_id", "EventId", Kind.Str),
                Node.Scalar("event_type", "EventType", Kind.Str),
                Node.Scalar("occurred_at", "OccurredAt", Kind.I64),
                Node.Scalar("producer", "Producer", Kind.Str),
                Node.ListOf("attrs", "Attrs", Kind.ListStruct, AttrNodes),
            },
            ["tensor"] = new[]
            {
                Node.Scalar("rows", "Rows", Kind.I32),
                Node.Scalar("cols", "Cols", Kind.I32),
                Node.ListOf("values", "Values", Kind.ListF32),
            },
            ["prompt"] = PromptNodes,
            ["shard"] = new[]
            {
                Node.Scalar("vocab", "Vocab", Kind.I32),
                Node.Scalar("hidden", "Hidden", Kind.I32),
                Node.Scalar("ffn", "Ffn", Kind.I32),
                Node.ListOf("tok_emb", "TokEmb", Kind.ListF32),
                Node.ListOf("attn", "Attn", Kind.ListF32),
                Node.ListOf("ffn_weight", "FfnWeight", Kind.ListF32),
                Node.ListOf("norm", "Norm", Kind.ListF32),
            },
            ["request"] = new[]
            {
                Node.Scalar("request_id", "RequestId", Kind.I64),
                Node.Scalar("model", "Model", Kind.Str),
                Node.Scalar("temperature", "Temperature", Kind.F32),
                Node.Struct("inputs", "Inputs", PromptNodes),
            },
        };

        readonly Writer _writer = new Writer(4096);

        Schema _schema;
        Bound[] _fields;
        bool _batch;
        bool _borrow;
        PropertyInfo _itemsProp;
        Type _elemType;
        object _native;

        public override string Name => "gld-kiln";

        public override string Version => PackageVersion.Of(typeof(Writer));

        /// <summary>Kiln writes a buffer; the stream row copies those bytes (no Stream writer).</summary>
        public override string StreamMode => "adapted";

        public override bool Supports(string testDataName) =>
            testDataName is "message" or "document" or "telemetry" or "strings" or "event"
                or "tensor" or "tensor_view" or "prompt" or "shard" or "request";

        public override void Initialize(Type serializablePrimaryType, List<Type> serializableSecondaryTypes = null)
        {
            base.Initialize(serializablePrimaryType, serializableSecondaryTypes);
            _borrow = string.Equals(FixtureName, "tensor_view", StringComparison.Ordinal);
            var key = ResolveKey(serializablePrimaryType);
            if (!StructByName.ContainsKey(key) || !NodesByName.TryGetValue(key, out var nodes))
                throw new InvalidOperationException("gld-kiln: unsupported type " + serializablePrimaryType.Name);
            _batch = IsBatch(serializablePrimaryType);
            _schema = _batch ? ListByName[key] : StructByName[key];
            if (_batch)
            {
                _itemsProp = serializablePrimaryType.GetProperty("Items", BindingFlags.Instance | BindingFlags.Public);
                if (_itemsProp == null)
                    throw new InvalidOperationException("gld-kiln: " + serializablePrimaryType.Name + ".Items");
                _elemType = ListElem(_itemsProp.PropertyType);
                _fields = Bind(_elemType, nodes);
            }
            else
            {
                _itemsProp = null;
                _elemType = serializablePrimaryType;
                _fields = Bind(serializablePrimaryType, nodes);
            }
            _native = null;
        }

        public override void PrepareData(object data)
        {
            if (_schema == null)
                throw new InvalidOperationException("gld-kiln Initialize was not called");
            _native = _batch ? BatchTo(data) : ToStruct(data, _fields);
        }

        public override object ToDomain(object decoded)
        {
            if (_schema == null)
                throw new InvalidOperationException("gld-kiln Initialize was not called");
            // tensor_view stays a slice of the wire bytes (no float copy).
            if (_borrow)
                return decoded;
            return _batch ? BatchFrom(decoded) : FromStruct(_elemType, decoded, _fields);
        }

        public override string Serialize(object serializable)
        {
            var mem = Encode(serializable);
            return Convert.ToBase64String(mem.Span);
        }

        public override object Deserialize(string serialized)
        {
            var bytes = Convert.FromBase64String(serialized);
            return Decode(bytes);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            var mem = Encode(serializable);
            outputStream.Write(mem.Span);
        }

        public override object Deserialize(Stream inputStream)
        {
            if (inputStream.CanSeek)
                inputStream.Position = 0;
            if (inputStream is MemoryStream owned && owned.TryGetBuffer(out var seg))
            {
                var len = checked((int)owned.Length);
                return Decode(seg.AsMemory().Slice(0, len));
            }
            using var copy = new MemoryStream();
            inputStream.CopyTo(copy);
            return Decode(copy.GetBuffer().AsMemory(0, (int)copy.Length));
        }

        ReadOnlyMemory<byte> Encode(object serializable)
        {
            if (_schema == null || _native == null)
                throw new InvalidOperationException(
                    "gld-kiln prepare was not called for " + (serializable == null ? "?" : serializable.GetType().Name));
            return _writer.Encode(_schema, _native);
        }

        object Decode(ReadOnlyMemory<byte> bytes)
        {
            if (_schema == null)
                throw new InvalidOperationException("gld-kiln prepare was not called");
            if (_borrow)
                return BorrowMatrix(bytes);
            return KilnCodec.Decode(_schema, bytes);
        }

        /// <summary>
        /// rows, cols, count, then the float32 payload. The returned memory is a slice
        /// of <paramref name="bytes"/>, not a copy of the matrix.
        /// </summary>
        static BorrowedMatrix BorrowMatrix(ReadOnlyMemory<byte> bytes)
        {
            if (bytes.Length < 12)
                throw new InvalidOperationException("gld-kiln tensor_view length");
            var span = bytes.Span;
            var rows = BinaryPrimitives.ReadInt32LittleEndian(span);
            var cols = BinaryPrimitives.ReadInt32LittleEndian(span.Slice(4));
            var n = BinaryPrimitives.ReadInt32LittleEndian(span.Slice(8));
            if (n < 0 || (long)n * 4L != (long)bytes.Length - 12L)
                throw new InvalidOperationException("gld-kiln tensor_view length");
            return new BorrowedMatrix
            {
                Rows = rows,
                Cols = cols,
                Values = bytes.Slice(12, n * 4),
            };
        }

        object BatchTo(object data)
        {
            var raw = _itemsProp.GetValue(data) as IList
                ?? throw new InvalidOperationException("gld-kiln: null Items");
            var list = new List<object>(raw.Count);
            for (var i = 0; i < raw.Count; i++)
                list.Add(ToStruct(raw[i], _fields));
            return list;
        }

        object BatchFrom(object decoded)
        {
            var raw = decoded as IList
                ?? throw new InvalidOperationException("gld-kiln: batch decode was not a list");
            var list = NewList(_elemType, raw.Count);
            for (var i = 0; i < raw.Count; i++)
                list.Add(FromStruct(_elemType, raw[i], _fields));
            var batch = Activator.CreateInstance(_primaryType);
            _itemsProp.SetValue(batch, list);
            return batch;
        }

        static Dictionary<string, object> ToStruct(object src, Bound[] fields)
        {
            if (src == null)
                throw new InvalidOperationException("gld-kiln: null struct");
            var map = new Dictionary<string, object>(fields.Length);
            for (var i = 0; i < fields.Length; i++)
            {
                var f = fields[i];
                map[f.Key] = ToField(f, f.Prop.GetValue(src));
            }
            return map;
        }

        static object ToField(Bound field, object value)
        {
            switch (field.Kind)
            {
                case Kind.Str:
                    return value as string ?? "";
                case Kind.Bool:
                case Kind.I32:
                case Kind.I64:
                case Kind.F32:
                case Kind.F64:
                    if (value == null)
                        throw new InvalidOperationException("gld-kiln: null " + field.Prop.Name);
                    return value;
                case Kind.Struct:
                    return ToStruct(value, field.Children);
                case Kind.ListStr:
                    return value as IList
                        ?? throw new InvalidOperationException("gld-kiln: null " + field.Prop.Name);
                case Kind.ListF64:
                    if (value == null)
                        throw new InvalidOperationException("gld-kiln: null " + field.Prop.Name);
                    return CopyDoubles(value);
                case Kind.ListF32:
                    if (value == null)
                        throw new InvalidOperationException("gld-kiln: null " + field.Prop.Name);
                    if (value is float[] || value is List<float>)
                        return value;
                    return ToFloatArray(value);
                case Kind.ListI64:
                    if (value == null)
                        throw new InvalidOperationException("gld-kiln: null " + field.Prop.Name);
                    if (value is long[] || value is List<long>)
                        return value;
                    return ToInt64Array(value);
                case Kind.ListStruct:
                    var raw = value as IList
                        ?? throw new InvalidOperationException("gld-kiln: null " + field.Prop.Name);
                    var list = new List<object>(raw.Count);
                    for (var i = 0; i < raw.Count; i++)
                        list.Add(ToStruct(raw[i], field.Children));
                    return list;
                default:
                    throw new InvalidOperationException("gld-kiln: field kind");
            }
        }

        static object FromStruct(Type type, object value, Bound[] fields)
        {
            var map = value as IDictionary
                ?? throw new InvalidOperationException("gld-kiln: struct decode was not a map");
            var obj = Activator.CreateInstance(type);
            for (var i = 0; i < fields.Length; i++)
            {
                var f = fields[i];
                if (!map.Contains(f.Key))
                    throw new InvalidOperationException("gld-kiln: missing " + f.Key);
                f.Prop.SetValue(obj, FromField(f, map[f.Key]));
            }
            return obj;
        }

        static object FromField(Bound field, object value)
        {
            switch (field.Kind)
            {
                case Kind.Bool:
                    if (value is bool bit) return bit;
                    throw new InvalidOperationException("gld-kiln: bool");
                case Kind.I32:
                    return AsI32(value);
                case Kind.I64:
                    return AsI64(value);
                case Kind.F32:
                    return AsF32(value);
                case Kind.F64:
                    return AsF64(value);
                case Kind.Str:
                    return value as string ?? "";
                case Kind.Struct:
                    return FromStruct(field.Prop.PropertyType, value, field.Children);
                case Kind.ListStr:
                    return ToStringList(value);
                case Kind.ListF64:
                    return ToDoubleList(value);
                case Kind.ListF32:
                    return ToFloatArray(value);
                case Kind.ListI64:
                    return ToInt64Array(value);
                case Kind.ListStruct:
                    var raw = value as IList
                        ?? throw new InvalidOperationException("gld-kiln: list decode was not a list");
                    var list = NewList(field.ElemType, raw.Count);
                    for (var i = 0; i < raw.Count; i++)
                        list.Add(FromStruct(field.ElemType, raw[i], field.Children));
                    return list;
                default:
                    throw new InvalidOperationException("gld-kiln: field kind");
            }
        }

        static Bound[] Bind(Type type, Node[] nodes)
        {
            var bound = new Bound[nodes.Length];
            for (var i = 0; i < nodes.Length; i++)
            {
                var node = nodes[i];
                var prop = type.GetProperty(node.Prop, BindingFlags.Instance | BindingFlags.Public);
                if (prop == null || !prop.CanRead || !prop.CanWrite)
                    throw new InvalidOperationException("gld-kiln: " + type.Name + "." + node.Prop);
                var b = new Bound { Key = node.Key, Prop = prop, Kind = node.Kind };
                if (node.Kind == Kind.Struct)
                    b.Children = Bind(prop.PropertyType, node.Fields);
                else if (node.Kind == Kind.ListStruct)
                {
                    b.ElemType = ListElem(prop.PropertyType);
                    b.Children = Bind(b.ElemType, node.Fields);
                }
                bound[i] = b;
            }
            return bound;
        }

        static bool IsBatch(Type type)
        {
            if (type == null || !type.Name.StartsWith("Batch", StringComparison.Ordinal))
                return false;
            var items = type.GetProperty("Items", BindingFlags.Instance | BindingFlags.Public);
            return items != null
                && items.PropertyType.IsGenericType
                && items.PropertyType.GetGenericTypeDefinition() == typeof(List<>);
        }

        string ResolveKey(Type type)
        {
            var name = FixtureName;
            if (name is "tensor" or "tensor_view") return "tensor";
            if (name is "prompt" or "shard" or "request") return name;
            return SchemaKey(type);
        }

        static string SchemaKey(Type type)
        {
            var name = type.Name;
            if (name.StartsWith("Batch", StringComparison.Ordinal))
                name = name.Substring("Batch".Length);
            return name.ToLowerInvariant();
        }

        static Type ListElem(Type listType)
        {
            if (listType == null || !listType.IsGenericType || listType.GetGenericTypeDefinition() != typeof(List<>))
                throw new InvalidOperationException("gld-kiln: expected List, got " + (listType == null ? "?" : listType.Name));
            return listType.GetGenericArguments()[0];
        }

        static IList NewList(Type elem, int capacity) =>
            (IList)Activator.CreateInstance(typeof(List<>).MakeGenericType(elem), capacity);

        static double[] CopyDoubles(object value)
        {
            switch (value)
            {
                case double[] arr:
                    return arr;
                case List<double> list:
                    var exact = new double[list.Count];
                    list.CopyTo(exact, 0);
                    return exact;
                case IList raw:
                    var boxed = new double[raw.Count];
                    for (var i = 0; i < raw.Count; i++)
                        boxed[i] = AsF64(raw[i]);
                    return boxed;
                default:
                    throw new InvalidOperationException("gld-kiln: expected f64 list");
            }
        }

        static float[] ToFloatArray(object value)
        {
            switch (value)
            {
                case float[] arr:
                    return arr;
                case double[] ds:
                    var narrowed = new float[ds.Length];
                    for (var i = 0; i < ds.Length; i++)
                        narrowed[i] = (float)ds[i];
                    return narrowed;
                case List<float> list:
                    var exact = new float[list.Count];
                    list.CopyTo(exact, 0);
                    return exact;
                case IList raw:
                    var boxed = new float[raw.Count];
                    for (var i = 0; i < raw.Count; i++)
                        boxed[i] = AsF32(raw[i]);
                    return boxed;
                default:
                    throw new InvalidOperationException("gld-kiln: expected f32 list");
            }
        }

        static long[] ToInt64Array(object value)
        {
            switch (value)
            {
                case long[] arr:
                    return arr;
                case List<long> list:
                    var exact = new long[list.Count];
                    list.CopyTo(exact, 0);
                    return exact;
                case IList raw:
                    var copy = new long[raw.Count];
                    for (var i = 0; i < raw.Count; i++)
                        copy[i] = AsI64(raw[i]);
                    return copy;
                default:
                    throw new InvalidOperationException("gld-kiln: expected i64 list");
            }
        }

        static List<double> ToDoubleList(object value)
        {
            switch (value)
            {
                case double[] arr:
                    return new List<double>(arr);
                case List<double> list:
                    return list;
                case IList raw:
                    var copy = new List<double>(raw.Count);
                    for (var i = 0; i < raw.Count; i++)
                        copy.Add(AsF64(raw[i]));
                    return copy;
                default:
                    throw new InvalidOperationException("gld-kiln: expected f64 list");
            }
        }

        static List<string> ToStringList(object value)
        {
            if (value is List<string> list) return list;
            var raw = value as IList
                ?? throw new InvalidOperationException("gld-kiln: expected string list");
            var copy = new List<string>(raw.Count);
            for (var i = 0; i < raw.Count; i++)
                copy.Add(raw[i] as string ?? "");
            return copy;
        }

        static int AsI32(object value)
        {
            switch (value)
            {
                case int i: return i;
                case long l: return checked((int)l);
                default: throw new InvalidOperationException("gld-kiln: i32");
            }
        }

        static long AsI64(object value)
        {
            switch (value)
            {
                case long l: return l;
                case int i: return i;
                default: throw new InvalidOperationException("gld-kiln: i64");
            }
        }

        static float AsF32(object value)
        {
            switch (value)
            {
                case float f: return f;
                case double d: return (float)d;
                default: throw new InvalidOperationException("gld-kiln: f32");
            }
        }

        static double AsF64(object value)
        {
            switch (value)
            {
                case double d: return d;
                case float f: return f;
                case int i: return i;
                case long l: return l;
                default: throw new InvalidOperationException("gld-kiln: f64");
            }
        }

        /// <summary>tensor_view decode. <see cref="Values"/> aliases the wire bytes.</summary>
        internal sealed class BorrowedMatrix
        {
            public int Rows;
            public int Cols;
            public ReadOnlyMemory<byte> Values;
        }
    }
}
