using System;
using System.IO;
using Bond;
using GLD.SerializerBenchmark.TestData;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>Common PrepareData/ToDomain for MS Bond codecs using Bond-generated types.</summary>
    internal abstract class BondSerDeserBase : SerDeser
    {
        protected object _native;
        protected Type _bondType;

        public override void Initialize(Type serializablePrimaryType, System.Collections.Generic.List<Type> serializableSecondaryTypes = null)
        {
            base.Initialize(serializablePrimaryType, serializableSecondaryTypes);
            _bondType = BondPayloadConverter.BondTypeFor(serializablePrimaryType);
            _native = null;
            JustInitialized = true;
        }

        public override void PrepareData(object data)
        {
            _native = BondPayloadConverter.ToBond(data);
        }

        public override object ToDomain(object decoded) => BondPayloadConverter.FromBond(decoded);

        protected object Payload(object serializable) => _native ?? BondPayloadConverter.ToBond(serializable);
    }
}
