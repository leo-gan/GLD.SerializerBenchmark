namespace GLD.SerializerBenchmark
{
    internal interface ISerDeser
    {
        string Name { get; }
        string Serialize<T>(object person);
        T Deserialize<T>(string serialized);
    }
}