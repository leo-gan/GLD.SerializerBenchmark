using System;
using System.Collections.Generic;
using System.IO;

namespace GLD.SerializerBenchmark
{
    internal interface ISerDeser
    {
        string Name { get; }
        void Initialize(Type serializablePrimaryType, List<Type> serializableSecondaryTypes = null);
        string Serialize(object serializable);
        object Deserialize(string serialized);
        void Serialize(object serializable, Stream outputStream);
        object Deserialize(Stream inputStream);
    }
}