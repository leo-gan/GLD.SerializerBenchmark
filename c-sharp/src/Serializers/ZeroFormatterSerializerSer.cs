using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using ZeroFormatter;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    /// ZeroFormatter timed path on KeyTuple/List wires only. Domain mapping via
    /// <see cref="IDomainNativeMap"/> — no suite type imports.
    /// </summary>
    internal class ZeroFormatterSerializerSer : MappedSerDeser
    {
        private Func<object, byte[]> _ser;
        private Func<byte[], object> _deser;

        public ZeroFormatterSerializerSer(IDomainNativeMap map) : base(map) { }

        public override string Name => "ZeroFormatter";
        public override bool Supports(string testDataName) => true;

        protected override void OnNativeTypeReady(Type nativeRoot, List<Type> nativeSecondary)
        {
            // ZeroFormatterSerializer.Serialize<T>(T obj) / Deserialize<T>(byte[] bytes)
            var serOpen = typeof(ZeroFormatterSerializer).GetMethods(BindingFlags.Public | BindingFlags.Static)
                .First(m => m.Name == "Serialize" && m.IsGenericMethodDefinition
                            && m.ReturnType == typeof(byte[]) && m.GetParameters().Length == 1);
            var deserOpen = typeof(ZeroFormatterSerializer).GetMethods(BindingFlags.Public | BindingFlags.Static)
                .First(m => m.Name == "Deserialize" && m.IsGenericMethodDefinition
                            && m.GetParameters().Length == 1
                            && m.GetParameters()[0].ParameterType == typeof(byte[]));
            _ser = TypedSer.BindSerializeBytes(nativeRoot, serOpen);
            _deser = TypedSer.BindDeserializeBytes(nativeRoot, deserOpen);
        }

        public override string Serialize(object serializable)
            => Convert.ToBase64String(_ser(NativeOf(serializable)));

        public override object Deserialize(string serialized)
            => _deser(Convert.FromBase64String(serialized));

        public override void Serialize(object serializable, Stream outputStream)
        {
            var bytes = _ser(NativeOf(serializable));
            outputStream.Write(bytes, 0, bytes.Length);
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            using var ms = new MemoryStream();
            inputStream.CopyTo(ms);
            return _deser(ms.ToArray());
        }
    }
}
