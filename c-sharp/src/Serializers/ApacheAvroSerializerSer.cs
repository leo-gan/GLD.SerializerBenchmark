/// Apache.Avro Reflect binding on suite domain POCOs.
///
/// Optimal path (official Reflect README + local microbench):
///  - Schema + ClassCache once in Initialize
///  - Typed ReflectWriter&lt;T&gt; / ReflectReader&lt;T&gt; (bound via Type, not suite hard-codes)
///  - Reuse BinaryEncoder / BinaryDecoder over fixed MemoryStreams (string/Base64 path)
///  - Pass reuse instance into ReflectReader.Read (avoid root allocation per call)
///  - Stream path: BinaryEncoder/Decoder on the harness Stream (docs example pattern)
///
/// https://avro.apache.org/docs/1.12.0/api/csharp/html/md_src_apache_main_Reflect_README.html
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Linq.Expressions;
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

        // Bound to primary Type in Initialize (suite isolation: no hard-coded Message/…)
        private Action<object, Avro.IO.Encoder> _write;
        private Func<object, Avro.IO.Decoder, object> _read;

        private readonly MemoryStream _serMs = new MemoryStream(4096);
        private readonly MemoryStream _deMs = new MemoryStream(4096);
        private BinaryEncoder _serEnc;
        private BinaryDecoder _deDec;
        private object _reuse;

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

            // Typed ReflectWriter/Reader for primary Type (docs example uses ReflectWriter<T>).
            var writerType = typeof(ReflectWriter<>).MakeGenericType(serializablePrimaryType);
            var readerType = typeof(ReflectReader<>).MakeGenericType(serializablePrimaryType);
            var writer = Activator.CreateInstance(writerType, _schema, _cache);
            var reader = Activator.CreateInstance(readerType, _schema, _schema, _cache);

            // Action<object, Encoder> write = (obj, enc) => ((ReflectWriter<T>)writer).Write((T)obj, enc);
            var writeMi = writerType.GetMethod("Write", new[] { serializablePrimaryType, typeof(Avro.IO.Encoder) });
            var objP = Expression.Parameter(typeof(object), "obj");
            var encP = Expression.Parameter(typeof(Avro.IO.Encoder), "enc");
            var writeBody = Expression.Call(
                Expression.Constant(writer),
                writeMi,
                Expression.Convert(objP, serializablePrimaryType),
                encP);
            _write = Expression.Lambda<Action<object, Avro.IO.Encoder>>(writeBody, objP, encP).Compile();

            // Func<object, Decoder, object> read = (reuse, dec) => ((ReflectReader<T>)reader).Read((T)reuse, dec);
            var readMi = readerType.GetMethod("Read", new[] { serializablePrimaryType, typeof(Avro.IO.Decoder) });
            var reuseP = Expression.Parameter(typeof(object), "reuse");
            var decP = Expression.Parameter(typeof(Avro.IO.Decoder), "dec");
            var reuseCast = Expression.Convert(reuseP, serializablePrimaryType);
            // reuse may be null on first call — ReflectReader accepts null via default for class types.
            var reuseArg = Expression.Condition(
                Expression.Equal(reuseP, Expression.Constant(null, typeof(object))),
                Expression.Default(serializablePrimaryType),
                reuseCast);
            var readBody = Expression.Convert(
                Expression.Call(Expression.Constant(reader), readMi, reuseArg, decP),
                typeof(object));
            _read = Expression.Lambda<Func<object, Avro.IO.Decoder, object>>(readBody, reuseP, decP).Compile();

            // Reuse encoder/decoder only on our MemoryStreams (string/Base64 path).
            // Stream path uses a fresh BinaryEncoder/Decoder on the harness stream —
            // indirection via a redirect Stream was slower for large N payloads.
            _serEnc = new BinaryEncoder(_serMs);
            _deDec = new BinaryDecoder(_deMs);
            _reuse = null;
        }

        public override string Serialize(object serializable)
        {
            _serMs.SetLength(0);
            _write(serializable, _serEnc);
            return Convert.ToBase64String(_serMs.GetBuffer(), 0, (int)_serMs.Length);
        }

        public override object Deserialize(string serialized)
        {
            var bytes = Convert.FromBase64String(serialized);
            _deMs.SetLength(0);
            _deMs.Write(bytes, 0, bytes.Length);
            _deMs.Position = 0;
            _reuse = _read(_reuse, _deDec);
            return _reuse;
        }

        public override void Serialize(object serializable, Stream outputStream)
            => _write(serializable, new BinaryEncoder(outputStream));

        public override object Deserialize(Stream inputStream)
        {
            if (inputStream.CanSeek)
                inputStream.Seek(0, SeekOrigin.Begin);
            _reuse = _read(_reuse, new BinaryDecoder(inputStream));
            return _reuse;
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
