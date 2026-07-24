/// Apache.Avro Reflect binding on suite domain POCOs.
/// Schema derived once in Initialize; timed path = BinaryEncoder/Decoder + Reflect write/read.
/// https://avro.apache.org/docs/current/api/csharp/html/md_src_apache_main_Reflect_README.html
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text;
using Avro;
using Avro.IO;
using Avro.Reflect;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class ApacheAvroSerializerSer : SerDeser
    {
        private Schema _schema;
        private ClassCache _cache;
        private ReflectDefaultWriter _writer;
        private ReflectDefaultReader _reader;
        private readonly MemoryStream _serMs = new MemoryStream(4096);

        public override string Name => "Apache.Avro";
        public override bool Supports(string testDataName) => true;

        public override void Initialize(Type serializablePrimaryType, List<Type> serializableSecondaryTypes = null)
        {
            base.Initialize(serializablePrimaryType, serializableSecondaryTypes);
            _schema = SchemaBuilder.ForType(serializablePrimaryType);
            _cache = new ClassCache();
            SchemaBuilder.LoadClassCache(_cache, serializablePrimaryType, _schema);
            if (serializableSecondaryTypes != null)
            {
                foreach (var sec in serializableSecondaryTypes)
                {
                    var nested = SchemaBuilder.FindRecord(_schema, sec.Name);
                    if (nested != null)
                        SchemaBuilder.LoadClassCache(_cache, sec, nested);
                }
            }
            _writer = new ReflectDefaultWriter(serializablePrimaryType, _schema, _cache);
            _reader = new ReflectDefaultReader(serializablePrimaryType, _schema, _schema, _cache);
        }

        public override string Serialize(object serializable)
        {
            _serMs.SetLength(0);
            _writer.Write(serializable, new BinaryEncoder(_serMs));
            return Convert.ToBase64String(_serMs.GetBuffer(), 0, (int)_serMs.Length);
        }

        public override object Deserialize(string serialized)
        {
            var bytes = Convert.FromBase64String(serialized);
            using var ms = new MemoryStream(bytes);
            return _reader.Read<object>(null, new BinaryDecoder(ms));
        }

        public override void Serialize(object serializable, Stream outputStream)
            => _writer.Write(serializable, new BinaryEncoder(outputStream));

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            return _reader.Read<object>(null, new BinaryDecoder(inputStream));
        }

        /// <summary>
        /// Build Avro JSON schemas from public read/write properties (PascalCase names match
        /// suite domain POCOs). Nested records and List&lt;T&gt; arrays are supported.
        /// </summary>
        internal static class SchemaBuilder
        {
            public static Schema ForType(Type t) => Schema.Parse(BuildJson(t, new HashSet<Type>()));

            public static void LoadClassCache(ClassCache cache, Type t, Schema schema)
            {
                if (schema is RecordSchema)
                    cache.LoadClassCache(t, schema);

                foreach (var p in PublicProps(t))
                {
                    var pt = UnwrapList(p.PropertyType);
                    if (!IsRecordCandidate(pt)) continue;
                    var nested = FindRecord(schema, pt.Name);
                    if (nested != null)
                        LoadClassCache(cache, pt, nested);
                }
            }

            public static Schema FindRecord(Schema s, string name)
            {
                switch (s)
                {
                    case RecordSchema rs:
                        if (string.Equals(rs.Name, name, StringComparison.Ordinal))
                            return rs;
                        foreach (var f in rs.Fields)
                        {
                            var found = FindRecord(f.Schema, name);
                            if (found != null) return found;
                        }
                        return null;
                    case ArraySchema ar:
                        return FindRecord(ar.ItemSchema, name);
                    default:
                        return null;
                }
            }

            static string BuildJson(Type t, HashSet<Type> seen)
            {
                t = Nullable.GetUnderlyingType(t) ?? t;
                if (t == typeof(bool)) return "\"boolean\"";
                if (t == typeof(int)) return "\"int\"";
                if (t == typeof(long)) return "\"long\"";
                if (t == typeof(float)) return "\"float\"";
                if (t == typeof(double)) return "\"double\"";
                if (t == typeof(string)) return "\"string\"";
                if (t == typeof(byte[])) return "\"bytes\"";

                if (t.IsGenericType && t.GetGenericTypeDefinition() == typeof(List<>))
                {
                    var el = t.GetGenericArguments()[0];
                    return "{\"type\":\"array\",\"items\":" + BuildJson(el, seen) + "}";
                }

                if (seen.Contains(t))
                    return "\"" + t.Name + "\"";
                seen.Add(t);

                var props = PublicProps(t).ToArray();
                var sb = new StringBuilder(256);
                sb.Append("{\"type\":\"record\",\"name\":\"").Append(t.Name).Append("\",\"fields\":[");
                for (var i = 0; i < props.Length; i++)
                {
                    if (i > 0) sb.Append(',');
                    sb.Append("{\"name\":\"").Append(props[i].Name).Append("\",\"type\":")
                        .Append(BuildJson(props[i].PropertyType, seen)).Append('}');
                }
                sb.Append("]}");
                return sb.ToString();
            }

            static IEnumerable<PropertyInfo> PublicProps(Type t)
                => t.GetProperties(BindingFlags.Public | BindingFlags.Instance)
                    .Where(p => p.CanRead && p.CanWrite && p.GetIndexParameters().Length == 0);

            static Type UnwrapList(Type t)
            {
                if (t.IsGenericType && t.GetGenericTypeDefinition() == typeof(List<>))
                    return t.GetGenericArguments()[0];
                return t;
            }

            static bool IsRecordCandidate(Type t)
                => t.IsClass && t != typeof(string) && t != typeof(byte[]);
        }
    }
}
