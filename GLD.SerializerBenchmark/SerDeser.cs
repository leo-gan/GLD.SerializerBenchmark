using System;
using System.Collections.Generic;
using System.IO;

namespace GLD.SerializerBenchmark
{
    public abstract class SerDeser : ISerDeser
    {
        protected Type _primaryType;
        protected List<Type> _secondaryTypes;
        public bool JustInitialized;

        public abstract string Name { get; }

        public virtual void Initialize(Type serializablePrimaryType, List<Type> serializableSecondaryTypes = null)
        {
            _primaryType = serializablePrimaryType;
            _secondaryTypes = serializableSecondaryTypes;
            JustInitialized = true;
        }

        public abstract string Serialize(object serializable);
        public abstract object Deserialize(string serialized);
        public abstract void Serialize(object serializable, Stream outputStream);
        public abstract object Deserialize(Stream inputStream);
    }
}