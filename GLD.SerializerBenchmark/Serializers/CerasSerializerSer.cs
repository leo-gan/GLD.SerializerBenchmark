using System;
using System.IO;

namespace GLD.SerializerBenchmark.Serializers
{
    // Ceras
    internal class CerasSerializerSer : SerDeser
    {
        private static readonly Lazy<Ceras.CerasSerializer> _serializer = new Lazy<Ceras.CerasSerializer>(() => new Ceras.CerasSerializer());
        public override string Name => "Ceras";
        public override string Serialize(object serializable) => Convert.ToBase64String(_serializer.Value.Serialize(serializable));
        public override object Deserialize(string serialized) {
            var bytes = Convert.FromBase64String(serialized);
            return _serializer.Value.Deserialize<object>(bytes);
        }
        public override void Serialize(object serializable, Stream outputStream) {
            var bytes = _serializer.Value.Serialize(serializable);
            outputStream.Write(bytes, 0, bytes.Length);
        }
        public override object Deserialize(Stream inputStream) {
            using var ms = new MemoryStream();
            inputStream.CopyTo(ms);
            return _serializer.Value.Deserialize<object>(ms.ToArray());
        }
    }
}
