using System;
using System.Collections.Generic;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>Bond codecs operate on V2 domain types marked [Schema].</summary>
    internal abstract class BondSerDeserBase : SerDeser
    {
        public override void Initialize(Type serializablePrimaryType, List<Type> serializableSecondaryTypes = null)
        {
            base.Initialize(serializablePrimaryType, serializableSecondaryTypes);
            JustInitialized = true;
        }
    }
}
