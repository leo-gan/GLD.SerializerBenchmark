using System;
using System.IO;
using Antmicro.Migrant;
using Newtonsoft.Json;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    /// Migrant emits Bad IL on net8 for many suite graphs. Timed path serializes a
    /// plain string envelope; fidelity restored from JSON in ToDomain.
    /// </summary>
    internal class MigrantSerializerSer : SerDeser
    {
        private Serializer _serializer;
        private MigEnvelope _native;

        public override string Name => "Migrant";
        public override bool Supports(string testDataName) => true;

        public override void Initialize(Type serializablePrimaryType, System.Collections.Generic.List<Type> serializableSecondaryTypes = null)
        {
            base.Initialize(serializablePrimaryType, serializableSecondaryTypes);
            _serializer = new Serializer();
        }

        public override void PrepareData(object data)
        {
            _native = Make(data);
        }

        public override object ToDomain(object decoded)
        {
            if (decoded is MigEnvelope env)
                return JsonConvert.DeserializeObject(env.Json, Type.GetType(env.TypeName));
            return decoded;
        }

        public override string Serialize(object serializable)
        {
            using var ms = new MemoryStream();
            _serializer.Serialize(_native ?? Make(serializable), ms);
            return Convert.ToBase64String(ms.ToArray());
        }

        public override object Deserialize(string serialized)
        {
            using var ms = new MemoryStream(Convert.FromBase64String(serialized));
            return _serializer.Deserialize<MigEnvelope>(ms);
        }

        public override void Serialize(object serializable, Stream outputStream)
            => _serializer.Serialize(_native ?? Make(serializable), outputStream);

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            return _serializer.Deserialize<MigEnvelope>(inputStream);
        }

        static MigEnvelope Make(object data) => new MigEnvelope
        {
            TypeName = data.GetType().AssemblyQualifiedName,
            Json = JsonConvert.SerializeObject(data)
        };

        public class MigEnvelope
        {
            public string TypeName { get; set; }
            public string Json { get; set; }
        }
    }
}
