using System.IO;

namespace GLD.SerializerBenchmark
{
    internal interface ISerDeser
    {
        string Name { get; }
        string Serialize<T>(object person);
        T Deserialize<T>(string serialized);
        void Serialize<T>(object person, Stream outputStream);
        T Deserialize<T>(Stream inputStream);
    }
}