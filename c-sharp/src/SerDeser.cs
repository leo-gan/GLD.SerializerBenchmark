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

        /// <summary>Installed package version for CSV (resolved from the library assembly).</summary>
        public virtual string Version => SerializerVersionRegistry.Resolve(Name);

        public virtual bool Supports(string testDataName) => true;

        public virtual void Initialize(Type serializablePrimaryType, List<Type> serializableSecondaryTypes = null)
        {
            _primaryType = serializablePrimaryType;
            _secondaryTypes = serializableSecondaryTypes;
            JustInitialized = true;
        }

        /// <summary>
        /// Untimed: convert suite fixtures to library-native forms / cache formatters.
        /// Called once per fixture after <see cref="Initialize"/>.
        /// </summary>
        public virtual void PrepareData(object data)
        {
        }

        public virtual object ToDomain(object decoded) => decoded;

        public abstract string Serialize(object serializable);
        public abstract object Deserialize(string serialized);

        public abstract void Serialize(object serializable, Stream outputStream);
        public abstract object Deserialize(Stream inputStream);
    }
}
