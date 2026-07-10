using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using GroBuf;
using GroBuf.DataMembersExtracters;
using GLD.SerializerBenchmark.TestData.V2;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    /// GroBuf official usage: single Serializer instance + PropertiesExtractor,
    /// GroBufOptions.WriteEmptyObjects so defaults are not silently dropped.
    /// https://github.com/skbkontur/GroBuf
    /// </summary>
    internal class GroBufSerializerSer : SerDeser
    {
        // Reuse one serializer (docs: "strongly recommended" for max speed / thread-safe).
        private readonly Serializer _serializer = new Serializer(
            new PropertiesExtractor(),
            options: GroBufOptions.WriteEmptyObjects);

        // Cache generic Serialize delegates per runtime type (no reflection in the timed loop).
        private readonly Dictionary<Type, Func<object, byte[]>> _ser =
            new Dictionary<Type, Func<object, byte[]>>();

        public override string Name => "GroBuf";
        public override bool Supports(string testDataName) => true;

        public override void Initialize(Type serializablePrimaryType, List<Type> serializableSecondaryTypes = null)
        {
            base.Initialize(serializablePrimaryType, serializableSecondaryTypes);
            // Warm code-gen for primary (+ secondary) types outside the stopwatch.
            Warm(serializablePrimaryType);
            if (serializableSecondaryTypes != null)
            {
                foreach (var t in serializableSecondaryTypes)
                    Warm(t);
            }
        }

        public override string Serialize(object serializable)
        {
            var bytes = SerializeBytes(serializable);
            return Convert.ToBase64String(bytes);
        }

        public override object Deserialize(string serialized)
        {
            var bytes = Convert.FromBase64String(serialized);
            return _serializer.Deserialize(_primaryType, bytes);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            // Direct binary — do not go through base64 (previous path double-converted).
            var bytes = SerializeBytes(serializable);
            outputStream.Write(bytes, 0, bytes.Length);
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            using var ms = new MemoryStream();
            inputStream.CopyTo(ms);
            return _serializer.Deserialize(_primaryType, ms.ToArray());
        }

        byte[] SerializeBytes(object serializable)
        {
            if (serializable == null) throw new ArgumentNullException(nameof(serializable));
            // Prefer typed generic calls for suite models (source of official Serialize<T> path).
            switch (serializable)
            {
                case Message m: return _serializer.Serialize(m);
                case Document d: return _serializer.Serialize(d);
                case Telemetry tel: return _serializer.Serialize(tel);
                case Strings s: return _serializer.Serialize(s);
                case Event e: return _serializer.Serialize(e);
                case BatchMessage b: return _serializer.Serialize(b);
                case BatchDocument b: return _serializer.Serialize(b);
                case BatchTelemetry b: return _serializer.Serialize(b);
                case BatchStrings b: return _serializer.Serialize(b);
                case BatchEvent b: return _serializer.Serialize(b);
                case DocumentMeta meta: return _serializer.Serialize(meta);
                case DocumentItem item: return _serializer.Serialize(item);
                case EventAttr attr: return _serializer.Serialize(attr);
            }
            var runtimeType = serializable.GetType();
            if (!_ser.TryGetValue(runtimeType, out var fn))
            {
                fn = BuildSerialize(runtimeType);
                _ser[runtimeType] = fn;
            }
            return fn(serializable);
        }

        void Warm(Type t)
        {
            if (t == null || t.IsAbstract) return;
            try
            {
                if (!_ser.ContainsKey(t))
                    _ser[t] = BuildSerialize(t);
                // Force code generation with a default instance when possible.
                object sample = null;
                try { sample = Activator.CreateInstance(t); } catch { /* ignore */ }
                if (sample != null)
                    _ = _ser[t](sample);
            }
            catch
            {
                // Warm is best-effort; real errors surface on timed path.
            }
        }

        Func<object, byte[]> BuildSerialize(Type t)
        {
            var mi = typeof(Serializer).GetMethods(BindingFlags.Instance | BindingFlags.Public)
                .First(m => m.Name == "Serialize" && m.IsGenericMethodDefinition
                            && m.GetParameters().Length == 1);
            var g = mi.MakeGenericMethod(t);
            return obj => (byte[])g.Invoke(_serializer, new[] { obj });
        }
    }
}
