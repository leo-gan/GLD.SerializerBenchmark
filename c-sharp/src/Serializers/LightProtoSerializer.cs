/// https://github.com/dameng324/LightProto

namespace GLD.SerializerBenchmark.Serializers
{
    internal class LightProtoSerializer : SerDeser
    {
        private readonly MemoryStream _serMs = new MemoryStream(4096);
        public override string Name => "LightProto";

        public override bool Supports(string testDataName) => true;

        public override string Serialize(object serializable)
        {
            _serMs.SetLength(0);
            LightProto.Serializer.SerializeNonGeneric(_serMs,serializable, LightProto.Serializer.GetProtoWriter(_primaryType));
            return Convert.ToBase64String(_serMs.GetBuffer(), 0, (int)_serMs.Length);
        }

        public override object Deserialize(string serialized)
        {
            var b = Convert.FromBase64String(serialized);
            return LightProto.Serializer.DeserializeNonGeneric(b, LightProto.Serializer.GetProtoReader(_primaryType));
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            LightProto.Serializer.SerializeNonGeneric(outputStream,serializable, LightProto.Serializer.GetProtoWriter(_primaryType));
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            return LightProto.Serializer.DeserializeNonGeneric(inputStream, LightProto.Serializer.GetProtoReader(_primaryType));
        }
    }
}
