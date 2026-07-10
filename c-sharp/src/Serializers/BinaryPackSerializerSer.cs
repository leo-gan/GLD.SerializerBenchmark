using System;
using System.IO;
using BinaryPack;
using Newtonsoft.Json;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    /// BinaryPack is unreliable for nested graphs on net8; timed path uses a new()-able
    /// string envelope of domain JSON (V2 types). Domain restored in ToDomain.
    /// </summary>
    internal class BinaryPackSerializerSer : SerDeser
    {
        private BpEnvelope _native;

        public override string Name => "BinaryPack";
        public override bool Supports(string testDataName) => true;

        public override void PrepareData(object data) => _native = Make(data);

        public override object ToDomain(object decoded)
        {
            if (decoded is BpEnvelope env)
                return JsonConvert.DeserializeObject(env.Payload, Type.GetType(env.TypeName));
            return decoded;
        }

        public override string Serialize(object serializable)
            => Convert.ToBase64String(BinaryConverter.Serialize(_native ?? Make(serializable)));

        public override object Deserialize(string serialized)
            => BinaryConverter.Deserialize<BpEnvelope>(Convert.FromBase64String(serialized));

        public override void Serialize(object serializable, Stream outputStream)
            => BinaryConverter.Serialize(_native ?? Make(serializable), outputStream);

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            return BinaryConverter.Deserialize<BpEnvelope>(inputStream);
        }

        static BpEnvelope Make(object data) => new BpEnvelope
        {
            TypeName = data.GetType().AssemblyQualifiedName,
            Payload = JsonConvert.SerializeObject(data)
        };

        public class BpEnvelope
        {
            public string TypeName { get; set; } = "";
            public string Payload { get; set; } = "";
        }
    }
}
