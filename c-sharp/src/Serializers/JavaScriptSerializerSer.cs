using System;
using System.IO;

namespace GLD.SerializerBenchmark.Serializers
{
    // JavaScriptSerializer is not available in .NET Core.
    // This wrapper is kept as a placeholder or can be removed.
    internal class JavaScriptSerializerSer : SerDeser
    {
        public override string Name => "JavaScriptSerializer (N/A)";
        public override bool Supports(string testDataName) => false;
        public override string Serialize(object serializable) => throw new NotImplementedException();
        public override object Deserialize(string serialized) => throw new NotImplementedException();
        public override void Serialize(object serializable, Stream outputStream) => throw new NotImplementedException();
        public override object Deserialize(Stream inputStream) => throw new NotImplementedException();
    }
}
