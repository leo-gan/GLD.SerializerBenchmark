using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Linq.Expressions;
using System.Reflection;

namespace GLD.SerializerBenchmark.Serializers
{
    // Utf8Json — cache closed generic Deserialize/Serialize delegates in Initialize.
    // Per-call MakeGenericMethod+Invoke was dominating timed deserialize.
    // https://github.com/neuecc/Utf8Json
    internal class Utf8JsonSerializerSer : SerDeser
    {
        private Func<string, object> _deserString;
        private Func<Stream, object> _deserStream;

        public override string Name => "Utf8Json";

        public override void Initialize(Type serializablePrimaryType, List<Type> serializableSecondaryTypes = null)
        {
            base.Initialize(serializablePrimaryType, serializableSecondaryTypes);
            _deserString = BuildDeserString(_primaryType);
            _deserStream = BuildDeserStream(_primaryType);
        }

        public override string Serialize(object serializable) =>
            Utf8Json.JsonSerializer.ToJsonString(serializable);

        public override object Deserialize(string serialized) =>
            _deserString(serialized);

        public override void Serialize(object serializable, Stream outputStream) =>
            Utf8Json.JsonSerializer.Serialize(outputStream, serializable);

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            return _deserStream(inputStream);
        }

        private static Func<string, object> BuildDeserString(Type t)
        {
            var mi = typeof(Utf8Json.JsonSerializer).GetMethods(BindingFlags.Public | BindingFlags.Static)
                .First(m => m.Name == "Deserialize" && m.IsGenericMethodDefinition
                    && m.GetParameters().Length == 1
                    && m.GetParameters()[0].ParameterType == typeof(string))
                .MakeGenericMethod(t);
            var p = Expression.Parameter(typeof(string));
            return Expression.Lambda<Func<string, object>>(
                Expression.Convert(Expression.Call(mi, p), typeof(object)), p).Compile();
        }

        private static Func<Stream, object> BuildDeserStream(Type t)
        {
            var mi = typeof(Utf8Json.JsonSerializer).GetMethods(BindingFlags.Public | BindingFlags.Static)
                .First(m => m.Name == "Deserialize" && m.IsGenericMethodDefinition
                    && m.GetParameters().Length == 1
                    && m.GetParameters()[0].ParameterType == typeof(Stream))
                .MakeGenericMethod(t);
            var p = Expression.Parameter(typeof(Stream));
            return Expression.Lambda<Func<Stream, object>>(
                Expression.Convert(Expression.Call(mi, p), typeof(object)), p).Compile();
        }
    }
}
