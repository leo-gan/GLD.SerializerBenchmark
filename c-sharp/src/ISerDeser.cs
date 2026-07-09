using System;
using System.Collections.Generic;
using System.IO;

namespace GLD.SerializerBenchmark
{
    internal interface ISerDeser
    {
        string Name { get; }
        /// <summary>Installed library / package version for CSV SerializerVersion.</summary>
        string Version { get; }
        bool Supports(string testDataName);
        void Initialize(Type serializablePrimaryType, List<Type> serializableSecondaryTypes = null);

        /// <summary>
        /// Untimed preparation of the native value for the timed path (convert to
        /// annotated models, cache formatters, etc.). Called once per fixture after
        /// <see cref="Initialize"/>.
        /// </summary>
        void PrepareData(object data);

        /// <summary>Untimed domain conversion after timed deserialize.</summary>
        object ToDomain(object decoded);

        string Serialize(object serializable);
        object Deserialize(string serialized);

        void Serialize(object serializable, Stream outputStream);
        object Deserialize(Stream inputStream);
    }
}
