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

        string Serialize(object serializable);
        object Deserialize(string serialized);

        void Serialize(object serializable, Stream outputStream);
        object Deserialize(Stream inputStream);
    }
}