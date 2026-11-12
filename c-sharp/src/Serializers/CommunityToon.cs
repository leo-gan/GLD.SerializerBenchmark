using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Linq.Expressions;
using System.Reflection;
using System.Text.Json;
using Corvus.Toon;
using ToonNet.Core.Serialization;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    /// ToonNet.Core. Serialize(object, Type) and Deserialize(string, Type) are bound once.
    /// The stream path writes that UTF-8 buffer. Size is the byte length.
    /// https://github.com/selcukgural/ToonNet
    /// </summary>
    internal sealed class ToonNetSerializerSer : SerDeser
    {
        private static readonly ToonSerializerOptions Options = new ToonSerializerOptions();
        private Func<object, string> _encode;
        private Func<string, object> _decode;

        public override string Name => "ToonNet";
        public override string StreamMode => "adapted";

        public override bool Supports(string testDataName) =>
            base.Supports(testDataName) && testDataName != "graph";

        public override void Initialize(Type serializablePrimaryType, List<Type> serializableSecondaryTypes = null)
        {
            base.Initialize(serializablePrimaryType, serializableSecondaryTypes);
            var encode = typeof(ToonSerializer).GetMethods(BindingFlags.Public | BindingFlags.Static)
                .Single(m => m.Name == "Serialize" && !m.IsGenericMethodDefinition
                    && m.GetParameters().Length == 3
                    && m.GetParameters()[0].ParameterType == typeof(object));
            var decode = typeof(ToonSerializer).GetMethods(BindingFlags.Public | BindingFlags.Static)
                .Single(m => m.Name == "Deserialize" && !m.IsGenericMethodDefinition
                    && m.GetParameters().Length == 3
                    && m.GetParameters()[0].ParameterType == typeof(string));
            var value = Expression.Parameter(typeof(object), "value");
            var text = Expression.Parameter(typeof(string), "text");
            var type = Expression.Constant(serializablePrimaryType);
            var options = Expression.Constant(Options);
            _encode = Expression.Lambda<Func<object, string>>(
                Expression.Call(encode, value, type, options), value).Compile();
            _decode = Expression.Lambda<Func<string, object>>(
                Expression.Convert(Expression.Call(decode, text, type, options), typeof(object)), text).Compile();
        }

        public override byte[] SerializeBytes(object serializable) => Utf8Bytes(_encode(serializable));

        public override object DeserializeBytes(byte[] serialized) => _decode(Utf8Text(serialized));

        public override void Serialize(object serializable, Stream outputStream) =>
            WriteAll(outputStream, SerializeBytes(serializable));

        public override object Deserialize(Stream inputStream) =>
            DeserializeBytes(ReadAll(inputStream, true));
    }

    /// <summary>
    /// Corvus.Toon.SystemTextJson converts JSON text and TOON text.
    /// The timed path includes that System.Text.Json pass. Size is UTF-8 bytes.
    /// https://github.com/corvus-dotnet/Corvus.JsonSchema
    /// </summary>
    internal sealed class CorvusToonSerializerSer : SerDeser
    {
        public override string Name => "Corvus.Toon";
        public override string StreamMode => "adapted";

        public override bool Supports(string testDataName) =>
            base.Supports(testDataName) && testDataName != "graph";

        public override byte[] SerializeBytes(object serializable)
        {
            var json = JsonSerializer.Serialize(serializable, _primaryType);
            return Utf8Bytes(ToonDocument.ConvertToToonString(json));
        }

        public override object DeserializeBytes(byte[] serialized)
        {
            var json = ToonDocument.ConvertToJsonString(Utf8Text(serialized));
            return JsonSerializer.Deserialize(json, _primaryType);
        }

        public override void Serialize(object serializable, Stream outputStream) =>
            WriteAll(outputStream, SerializeBytes(serializable));

        public override object Deserialize(Stream inputStream) =>
            DeserializeBytes(ReadAll(inputStream, true));
    }
}
