using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Linq.Expressions;
using System.Reflection;

namespace GLD.SerializerBenchmark.Serializers
{
    // SpanJson — optimal path uses Generic.Utf16/Utf8 with closed generic methods.
    // Caching compiled delegates in Initialize avoids per-call reflection (major win).
    // https://github.com/Tornhoof/SpanJson
    internal class SpanJsonSerializerSer : SerDeser
    {
        private Func<object, string> _serUtf16;
        private Func<string, object> _deserUtf16;
        private Func<object, byte[]> _serUtf8;
        private Func<byte[], object> _deserUtf8;

        public override string Name => "SpanJson";

        public override void Initialize(Type serializablePrimaryType, List<Type> serializableSecondaryTypes = null)
        {
            base.Initialize(serializablePrimaryType, serializableSecondaryTypes);
            _serUtf16 = BuildSerializeUtf16(_primaryType);
            _deserUtf16 = BuildDeserializeUtf16(_primaryType);
            _serUtf8 = BuildSerializeUtf8(_primaryType);
            _deserUtf8 = BuildDeserializeUtf8(_primaryType);
        }

        public override string Serialize(object serializable) => _serUtf16(serializable);

        public override object Deserialize(string serialized) => _deserUtf16(serialized);

        public override void Serialize(object serializable, Stream outputStream)
        {
            var json = _serUtf8(serializable);
            outputStream.Write(json, 0, json.Length);
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            using var ms = new MemoryStream();
            inputStream.CopyTo(ms);
            return _deserUtf8(ms.ToArray());
        }

        private static Func<object, string> BuildSerializeUtf16(Type t)
        {
            // SpanJson.JsonSerializer.Generic.Utf16.Serialize<T>(T)
            var mi = typeof(SpanJson.JsonSerializer.Generic.Utf16).GetMethods(BindingFlags.Public | BindingFlags.Static)
                .First(m => m.Name == "Serialize" && m.IsGenericMethodDefinition
                    && m.GetGenericArguments().Length == 1
                    && m.GetParameters().Length == 1)
                .MakeGenericMethod(t);
            var p = Expression.Parameter(typeof(object), "o");
            var call = Expression.Call(mi, Expression.Convert(p, t));
            return Expression.Lambda<Func<object, string>>(call, p).Compile();
        }

        private static Func<string, object> BuildDeserializeUtf16(Type t)
        {
            var mi = typeof(SpanJson.JsonSerializer.Generic.Utf16).GetMethods(BindingFlags.Public | BindingFlags.Static)
                .First(m => m.Name == "Deserialize" && m.IsGenericMethodDefinition
                    && m.GetGenericArguments().Length == 1
                    && m.GetParameters().Length == 1
                    && m.GetParameters()[0].ParameterType == typeof(string))
                .MakeGenericMethod(t);
            var p = Expression.Parameter(typeof(string), "s");
            var call = Expression.Call(mi, p);
            return Expression.Lambda<Func<string, object>>(Expression.Convert(call, typeof(object)), p).Compile();
        }

        private static Func<object, byte[]> BuildSerializeUtf8(Type t)
        {
            var mi = typeof(SpanJson.JsonSerializer.Generic.Utf8).GetMethods(BindingFlags.Public | BindingFlags.Static)
                .First(m => m.Name == "Serialize" && m.IsGenericMethodDefinition
                    && m.GetGenericArguments().Length == 1
                    && m.GetParameters().Length == 1)
                .MakeGenericMethod(t);
            var p = Expression.Parameter(typeof(object), "o");
            var call = Expression.Call(mi, Expression.Convert(p, t));
            return Expression.Lambda<Func<object, byte[]>>(call, p).Compile();
        }

        private static Func<byte[], object> BuildDeserializeUtf8(Type t)
        {
            var mi = typeof(SpanJson.JsonSerializer.Generic.Utf8).GetMethods(BindingFlags.Public | BindingFlags.Static)
                .First(m => m.Name == "Deserialize" && m.IsGenericMethodDefinition
                    && m.GetGenericArguments().Length == 1
                    && m.GetParameters().Length == 1
                    && m.GetParameters()[0].ParameterType == typeof(byte[]))
                .MakeGenericMethod(t);
            var p = Expression.Parameter(typeof(byte[]), "b");
            var call = Expression.Call(mi, p);
            return Expression.Lambda<Func<byte[], object>>(Expression.Convert(call, typeof(object)), p).Compile();
        }
    }
}
