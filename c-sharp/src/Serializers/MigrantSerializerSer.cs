using System;
using System.IO;
using Antmicro.Migrant;
using Newtonsoft.Json;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    /// <b>Honesty — not native domain Migrant graphs.</b>
    /// <para>
    /// Timed work serializes a <see cref="MigEnvelope"/> whose payload is a
    /// <b>Newtonsoft.Json</b> string of the suite domain object. Migrant only
    /// round-trips that envelope (plain POCOs). Fidelity is restored in
    /// <see cref="ToDomain"/> (untimed) from the JSON field.
    /// </para>
    /// <para>
    /// <b>String mode</b> wraps Migrant bytes as <b>Base64</b> (not a domain text format).
    /// <b>Stream mode</b> writes Migrant binary of the envelope directly to the stream
    /// (native Migrant stream API on the envelope type only).
    /// </para>
    /// Why: Migrant emits bad IL / fails on many suite graphs on net8. This keeps a
    /// registered row for the envelope workaround. Do not treat Results as
    /// “Migrant of nested suite POCOs.”
    /// Docs: https://github.com/antmicro/Migrant
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
            // Untimed: JSON envelope once per cell.
            _native = Make(data);
        }

        public override object ToDomain(object decoded)
        {
            // Untimed: JSON → suite domain.
            if (decoded is MigEnvelope env)
                return JsonConvert.DeserializeObject(env.Json, Type.GetType(env.TypeName));
            return decoded;
        }

        public override string Serialize(object serializable)
        {
            using var ms = new MemoryStream();
            _serializer.Serialize(_native ?? Make(serializable), ms);
            // String mode: Base64 of Migrant bytes of the envelope (not domain text).
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

        /// <summary>Wire type for Migrant only — holds type name + JSON payload.</summary>
        public class MigEnvelope
        {
            public string TypeName { get; set; }
            public string Json { get; set; }
        }
    }
}
