using System;
using System.IO;

namespace GLD.SerializerBenchmark.Serializers
{
    // FlatSharp
    internal class FlatSharpSerializerSer : SerDeser
    {
        public override string Name => "FlatSharp";
        public override string Serialize(object serializable) {
            return ""; // Needs schema / interface
        }
        public override object Deserialize(string serialized) {
            return null;
        }
        public override void Serialize(object serializable, Stream outputStream) {
        }
        public override object Deserialize(Stream inputStream) {
            return null;
        }
    }
}
