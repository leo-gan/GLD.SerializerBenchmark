using System;
using System.Collections.Generic;
using System.IO;
using System.Linq.Expressions;
using System.Reflection;
using FlatSharp;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    /// FlatSharp timed path on native contracts only. Domain mapping via injected map.
    /// https://github.com/jamescourtney/FlatSharp
    /// </summary>
    internal class FlatSharpSerializerSer : MappedSerDeser
    {
        private readonly FlatBufferSerializer _fb = FlatBufferSerializer.Default;
        private Func<object, byte[]> _ser;
        private Func<byte[], object> _parse;

        public FlatSharpSerializerSer(IDomainNativeMap map) : base(map) { }

        public override string Name => "FlatSharp";
        public override bool Supports(string testDataName) => true;

        protected override void OnNativeTypeReady(Type nativeRoot, List<Type> nativeSecondary)
        {
            // Bind via private generic helpers so Span/generic APIs stay typed (no suite types).
            var serOpen = typeof(FlatSharpSerializerSer).GetMethod(nameof(SerializeNative),
                BindingFlags.NonPublic | BindingFlags.Static);
            var parseOpen = typeof(FlatSharpSerializerSer).GetMethod(nameof(ParseNative),
                BindingFlags.NonPublic | BindingFlags.Static);
            var serClosed = serOpen.MakeGenericMethod(nativeRoot);
            var parseClosed = parseOpen.MakeGenericMethod(nativeRoot);

            var pObj = Expression.Parameter(typeof(object), "o");
            var pFb = Expression.Constant(_fb);
            var serBody = Expression.Call(serClosed, pFb, Expression.Convert(pObj, nativeRoot));
            _ser = Expression.Lambda<Func<object, byte[]>>(serBody, pObj).Compile();

            var pBytes = Expression.Parameter(typeof(byte[]), "b");
            var parseBody = Expression.Convert(
                Expression.Call(parseClosed, pFb, pBytes), typeof(object));
            _parse = Expression.Lambda<Func<byte[], object>>(parseBody, pBytes).Compile();
        }

        static byte[] SerializeNative<T>(FlatBufferSerializer fb, T item) where T : class
        {
            int max = fb.GetMaxSize(item);
            var buf = new byte[max];
            int n = fb.Serialize(item, buf);
            if (n == buf.Length) return buf;
            var exact = new byte[n];
            Buffer.BlockCopy(buf, 0, exact, 0, n);
            return exact;
        }

        static T ParseNative<T>(FlatBufferSerializer fb, byte[] bytes) where T : class
            => fb.Parse<T>(bytes);

        public override string Serialize(object serializable)
            => Convert.ToBase64String(_ser(NativeOf(serializable)));

        public override object Deserialize(string serialized)
            => _parse(Convert.FromBase64String(serialized));

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
            return _parse(ms.ToArray());
        }
    }
}
