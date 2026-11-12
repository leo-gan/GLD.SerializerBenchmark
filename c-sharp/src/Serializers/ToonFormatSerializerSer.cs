using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Linq.Expressions;
using System.Reflection;
using Toon.Format;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    /// Official .NET TOON codec. Bytes are UTF-8. EncodeToStream / Decode(Stream)
    /// are the library text stream API. A token count is not the byte size.
    /// https://github.com/toon-format/toon-dotnet
    /// </summary>
    internal sealed class ToonFormatSerializerSer : SerDeser
    {
        private Func<object, byte[]> _toBytes;
        private Func<byte[], object> _fromBytes;
        private Action<object, Stream> _toStream;
        private Func<Stream, object> _fromStream;

        public override string Name => "Toon.Format";
        public override string StreamMode => "text_on_stream";

        public override bool Supports(string testDataName) =>
            base.Supports(testDataName) && testDataName != "graph";

        public override void Initialize(Type serializablePrimaryType, List<Type> serializableSecondaryTypes = null)
        {
            base.Initialize(serializablePrimaryType, serializableSecondaryTypes);
            var t = serializablePrimaryType;
            _toBytes = BindToBytes(t);
            _fromBytes = BindFromBytes(t);
            _toStream = BindToStream(t);
            _fromStream = BindFromStream(t);
        }

        public override byte[] SerializeBytes(object serializable) => _toBytes(serializable);

        public override object DeserializeBytes(byte[] serialized) => _fromBytes(serialized);

        public override void Serialize(object serializable, Stream outputStream) =>
            _toStream(serializable, outputStream);

        public override object Deserialize(Stream inputStream)
        {
            if (inputStream.CanSeek)
                inputStream.Seek(0, SeekOrigin.Begin);
            return _fromStream(inputStream);
        }

        private static Expression Options(Type optionType) =>
            optionType.IsValueType
                ? Expression.Default(optionType)
                : Expression.Constant(null, optionType);

        private static Func<object, byte[]> BindToBytes(Type t)
        {
            var method = typeof(ToonEncoder).GetMethods(BindingFlags.Public | BindingFlags.Static)
                .Single(m => m.Name == "EncodeToBytes" && m.IsGenericMethodDefinition
                    && m.GetParameters().Length == 2
                    && m.GetParameters()[1].ParameterType == typeof(ToonEncodeOptions))
                .MakeGenericMethod(t);
            var value = Expression.Parameter(typeof(object), "value");
            var call = Expression.Call(method, Expression.Convert(value, t), Options(typeof(ToonEncodeOptions)));
            return Expression.Lambda<Func<object, byte[]>>(call, value).Compile();
        }

        private static Func<byte[], object> BindFromBytes(Type t)
        {
            var method = typeof(ToonDecoder).GetMethods(BindingFlags.Public | BindingFlags.Static)
                .Single(m => m.Name == "Decode" && m.IsGenericMethodDefinition
                    && m.GetParameters().Length == 2
                    && m.GetParameters()[0].ParameterType == typeof(byte[]))
                .MakeGenericMethod(t);
            var data = Expression.Parameter(typeof(byte[]), "data");
            var call = Expression.Call(method, data, Options(typeof(ToonDecodeOptions)));
            return Expression.Lambda<Func<byte[], object>>(Expression.Convert(call, typeof(object)), data).Compile();
        }

        private static Action<object, Stream> BindToStream(Type t)
        {
            var method = typeof(ToonEncoder).GetMethods(BindingFlags.Public | BindingFlags.Static)
                .Single(m => m.Name == "EncodeToStream" && m.IsGenericMethodDefinition
                    && m.GetParameters().Length == 3
                    && m.GetParameters()[1].ParameterType == typeof(Stream))
                .MakeGenericMethod(t);
            var value = Expression.Parameter(typeof(object), "value");
            var stream = Expression.Parameter(typeof(Stream), "stream");
            var call = Expression.Call(
                method,
                Expression.Convert(value, t),
                stream,
                Options(typeof(ToonEncodeOptions)));
            return Expression.Lambda<Action<object, Stream>>(call, value, stream).Compile();
        }

        private static Func<Stream, object> BindFromStream(Type t)
        {
            var method = typeof(ToonDecoder).GetMethods(BindingFlags.Public | BindingFlags.Static)
                .Single(m => m.Name == "Decode" && m.IsGenericMethodDefinition
                    && m.GetParameters().Length == 2
                    && m.GetParameters()[0].ParameterType == typeof(Stream))
                .MakeGenericMethod(t);
            var stream = Expression.Parameter(typeof(Stream), "stream");
            var call = Expression.Call(method, stream, Options(typeof(ToonDecodeOptions)));
            return Expression.Lambda<Func<Stream, object>>(Expression.Convert(call, typeof(object)), stream).Compile();
        }
    }
}
